import argparse
import os
import tempfile
from pathlib import Path

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
import yaml
from dotenv import load_dotenv
from google.cloud import storage
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.engine import URL


# Load environment variables from secret/.env, looking for it relative to this script.
script_dir = Path(__file__).resolve().parent
dotenv_path = script_dir.parent / "secret" / ".env"
if not dotenv_path.exists():
    dotenv_path = Path("secret/.env")
load_dotenv(dotenv_path=dotenv_path)


PG_USER = os.getenv("PG_USER")
PG_PASS = os.getenv("PG_PASS")
PG_HOST = os.getenv("PG_HOST")
PG_PORT = os.getenv("PG_PORT")
PG_DB = os.getenv("PG_DB")

PROJECT_ID = os.getenv("BQ_PROJECT_ID") or os.getenv("PRISM_BQ_PROJECT_ID")
DEFAULT_SOURCE_SCHEMA = "mxc_raw_claims"
DEFAULT_BUCKET_NAME = "prism_mxc_raw_claims"
DEFAULT_CHUNKSIZE = 100_000

# Map Postgres data types directly to PyArrow types to lock down schema upfront
PG_TO_ARROW_TYPES = {
    # Integers
    "smallint": pa.int64(),
    "integer": pa.int64(),
    "bigint": pa.int64(),
    # Floats / Decimals
    "real": pa.float64(),
    "double precision": pa.float64(),
    "numeric": pa.float64(),
    "decimal": pa.float64(),
    # Booleans
    "boolean": pa.bool_(),
    # Dates & Timestamps
    "date": pa.date32(),
    "timestamp without time zone": pa.timestamp("us"),
    "timestamp with time zone": pa.timestamp("us"),
}


def create_postgres_engine():
    url = URL.create(
        "postgresql",
        username=PG_USER,
        password=PG_PASS,
        host=PG_HOST,
        port=PG_PORT,
        database=PG_DB,
    )
    return create_engine(url)


def validate_env():
    missing = [
        name
        for name, value in {
            "PG_USER": PG_USER,
            "PG_PASS": PG_PASS,
            "PG_HOST": PG_HOST,
            "PG_PORT": PG_PORT,
            "PG_DB": PG_DB,
            "BQ_PROJECT_ID or PRISM_BQ_PROJECT_ID": PROJECT_ID,
        }.items()
        if not value
    ]
    if missing:
        raise RuntimeError(f"Missing required environment variable(s): {', '.join(missing)}")


def get_postgres_tables(pg_engine, source_schema):
    inspector = inspect(pg_engine)
    return inspector.get_table_names(schema=source_schema)


def get_source_yml_tables(source_name, source_yml_path):
    with open(source_yml_path, "r", encoding="utf-8") as file:
        sources_yml = yaml.safe_load(file)

    for source in sources_yml.get("sources", []):
        if source.get("name") == source_name:
            return [table["name"] for table in source.get("tables", [])]

    raise RuntimeError(f"Source '{source_name}' was not found in {source_yml_path}.")


def get_schema_from_postgres(pg_engine, source_schema, table_name):
    """
    Queries Postgres metadata directly to build an exact PyArrow schema upfront.
    Prevents PyArrow from guessing types per chunk (which breaks on NULL-only chunks).
    """
    query = text("""
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_schema = :schema AND table_name = :table
        ORDER BY ordinal_position;
    """)

    with pg_engine.connect() as conn:
        result = conn.execute(query, {"schema": source_schema, "table": table_name})
        cols = result.fetchall()

    arrow_fields = []
    for col_name, data_type in cols:
        # Exclude Source.Name variants so BigQuery auto-load jobs don't crash
        if col_name.lower() in ("source.name", "sourcename"):
            continue

        # Map Postgres type to Arrow type (defaulting to string for unknown/text/varchar types)
        pa_type = PG_TO_ARROW_TYPES.get(data_type.lower(), pa.string())
        arrow_fields.append(pa.field(col_name, pa_type, nullable=True))

    return pa.schema(arrow_fields)


def table_to_parquet(pg_engine, source_schema, table_name, output_path, chunksize, compression):
    # Lock down target schema from DB metadata upfront
    target_schema = get_schema_from_postgres(pg_engine, source_schema, table_name)

    preparer = pg_engine.dialect.identifier_preparer
    quoted_schema = preparer.quote_schema(source_schema)
    quoted_table = preparer.quote(table_name)
    query_sql = f"SELECT * FROM {quoted_schema}.{quoted_table}"
    query = text(query_sql)

    rows_written = 0
    writer = None

    try:
        for chunk in pd.read_sql_query(query, pg_engine, chunksize=chunksize):
            # Drop invalid BigQuery metadata column if present
            cols_to_drop = [c for c in chunk.columns if c.lower() in ("source.name", "sourcename")]
            if cols_to_drop:
                chunk = chunk.drop(columns=cols_to_drop)

            # Safely stringify text columns to prevent mixed object type casting errors
            for field in target_schema:
                col_name = field.name
                if col_name in chunk.columns and field.type == pa.string():
                    chunk[col_name] = chunk[col_name].apply(
                        lambda x: str(x) if (x is not None and pd.notna(x)) else None
                    )

            # Convert Pandas chunk strictly using the pre-built target_schema
            arrow_table = pa.Table.from_pandas(chunk, schema=target_schema, preserve_index=False)

            if writer is None:
                writer = pq.ParquetWriter(output_path, target_schema, compression=compression)

            writer.write_table(arrow_table)
            rows_written += len(chunk)

    finally:
        if writer is not None:
            writer.close()

    # Handle 0-row empty tables gracefully
    if writer is None:
        empty_df = pd.DataFrame(columns=[f.name for f in target_schema])
        arrow_table = pa.Table.from_pandas(empty_df, schema=target_schema, preserve_index=False)
        pq.write_table(arrow_table, output_path, compression=compression)

    return rows_written


def upload_file(bucket, local_path, destination_blob_name):
    blob = bucket.blob(destination_blob_name)
    blob.upload_from_filename(local_path, content_type="application/octet-stream")
    return f"gs://{bucket.name}/{destination_blob_name}"


def normalize_prefix(prefix):
    return prefix.strip("/") if prefix else ""


def build_blob_name(prefix, table_name):
    filename = f"{table_name}.parquet"
    return f"{prefix}/{filename}" if prefix else filename


def run_upload(
    source_schema,
    bucket_name,
    prefix,
    table_names,
    chunksize,
    compression,
    dry_run,
):
    validate_env()

    print("\n=== mxc_raw_claims Postgres to GCS Parquet Uploader ===")
    print(f"Project: {PROJECT_ID}")
    print(f"Source schema: {source_schema}")
    print(f"Bucket: gs://{bucket_name}")

    pg_engine = create_postgres_engine()

    available_tables = get_postgres_tables(pg_engine, source_schema)
    selected_tables = table_names or available_tables
    missing_tables = sorted(set(selected_tables) - set(available_tables))
    if missing_tables:
        raise RuntimeError(
            f"Table(s) not found in Postgres schema '{source_schema}': {', '.join(missing_tables)}"
        )

    if not selected_tables:
        print(f"No tables found in Postgres schema '{source_schema}'.")
        return

    prefix = normalize_prefix(prefix)
    print(f"Tables: {len(selected_tables)}")
    if prefix:
        print(f"Prefix: {prefix}")

    if dry_run:
        print("\nDry run only. These objects would be uploaded:")
        for table_name in selected_tables:
            print(f"- gs://{bucket_name}/{build_blob_name(prefix, table_name)}")
        return

    storage_client = storage.Client(project=PROJECT_ID)
    bucket = storage_client.bucket(bucket_name)

    with tempfile.TemporaryDirectory(prefix="mxc_raw_claims_parquet_") as temp_dir:
        temp_dir_path = Path(temp_dir)

        for index, table_name in enumerate(selected_tables, start=1):
            parquet_path = temp_dir_path / f"{table_name}.parquet"
            blob_name = build_blob_name(prefix, table_name)

            print(f"\n[{index}/{len(selected_tables)}] Converting {source_schema}.{table_name} to parquet...")
            rows_written = table_to_parquet(
                pg_engine=pg_engine,
                source_schema=source_schema,
                table_name=table_name,
                output_path=parquet_path,
                chunksize=chunksize,
                compression=compression,
            )

            print(f"Uploading {rows_written} rows to gs://{bucket_name}/{blob_name}...")
            uri = upload_file(bucket, parquet_path, blob_name)
            print(f"Uploaded: {uri}")
            parquet_path.unlink(missing_ok=True)

    print("\nDone.")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Convert Postgres mxc_raw_claims tables to parquet and upload them to GCS."
    )
    parser.add_argument(
        "--source-schema",
        default=DEFAULT_SOURCE_SCHEMA,
        help=f"Source Postgres schema [default: {DEFAULT_SOURCE_SCHEMA}]",
    )
    parser.add_argument(
        "--bucket",
        default=DEFAULT_BUCKET_NAME,
        help=f"Destination GCS bucket [default: {DEFAULT_BUCKET_NAME}]",
    )
    parser.add_argument(
        "--prefix",
        default="",
        help="Optional GCS object prefix, for example raw/2026-08-02",
    )
    parser.add_argument(
        "--tables",
        nargs="+",
        help="Specific table names to upload. Defaults to every table in the source schema.",
    )
    parser.add_argument(
        "--from-sources-yml",
        action="store_true",
        help="Use the mxc_raw_claims table list in models/sources.yml instead of all discovered tables.",
    )
    parser.add_argument(
        "--sources-yml-path",
        default=str(script_dir.parent / "models" / "sources.yml"),
        help="Path to sources.yml when using --from-sources-yml.",
    )
    parser.add_argument(
        "--chunksize",
        type=int,
        default=DEFAULT_CHUNKSIZE,
        help=f"Rows per Postgres read chunk [default: {DEFAULT_CHUNKSIZE}]",
    )
    parser.add_argument(
        "--compression",
        default="snappy",
        choices=["none", "snappy", "gzip", "brotli", "lz4", "zstd"],
        help="Parquet compression codec [default: snappy]",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the GCS objects that would be written without converting or uploading tables.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()

    tables = args.tables
    if args.from_sources_yml:
        tables = get_source_yml_tables("mxc_raw_claims", args.sources_yml_path)

    compression = None if args.compression == "none" else args.compression

    run_upload(
        source_schema=args.source_schema,
        bucket_name=args.bucket,
        prefix=args.prefix,
        table_names=tables,
        chunksize=args.chunksize,
        compression=compression,
        dry_run=args.dry_run,
    )