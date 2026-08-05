import argparse
import os
import re
from pathlib import Path
from typing import Optional

from dotenv import load_dotenv
from google.cloud import bigquery
from google.cloud import storage


script_dir = Path(__file__).resolve().parent
dotenv_path = script_dir.parent / "secret" / ".env"
if not dotenv_path.exists():
    dotenv_path = Path("secret/.env")
load_dotenv(dotenv_path=dotenv_path)


PROJECT_ID = os.getenv("BQ_PROJECT_ID") or os.getenv("PRISM_BQ_PROJECT_ID")
DEFAULT_BUCKET_NAME = os.getenv("GCS_BUCKET_NAME") or "prism_mxc_raw_claims"
DEFAULT_DATASET_ID = "mxc_raw_claims"
PRISM_BLOB_RE = re.compile(r"(^|/)(prism_[^/]+)\.parquet$", re.IGNORECASE)


def validate_env():
    missing = [
        name
        for name, value in {
            "BQ_PROJECT_ID or PRISM_BQ_PROJECT_ID": PROJECT_ID,
        }.items()
        if not value
    ]
    if missing:
        raise RuntimeError(f"Missing required environment variable(s): {', '.join(missing)}")


def create_bigquery_dataset_if_needed(project_id: str, dataset_id: str):
    client = bigquery.Client(project=project_id)
    dataset_ref = bigquery.Dataset(f"{project_id}.{dataset_id}")
    client.create_dataset(dataset_ref, exists_ok=True)


def list_prism_parquet_blobs(storage_client, bucket_name: str, prefix: Optional[str] = None):
    bucket = storage_client.bucket(bucket_name)
    blobs = storage_client.list_blobs(bucket, prefix=prefix)

    selected = []
    for blob in blobs:
        if not blob.name.lower().endswith(".parquet"):
            continue
        if not PRISM_BLOB_RE.search(blob.name):
            continue
        selected.append(blob)

    return sorted(selected, key=lambda blob: blob.name)


def load_blob_to_bigquery(bq_client, bucket_name: str, blob_name: str, dataset_id: str, write_disposition: str):
    table_name = Path(blob_name).stem
    table_id = f"{dataset_id}.{table_name}"
    uri = f"gs://{bucket_name}/{blob_name}"

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.PARQUET,
        write_disposition=write_disposition,
    )

    job = bq_client.load_table_from_uri(uri, table_id, job_config=job_config)
    job.result()

    table = bq_client.get_table(table_id)
    return table_name, table.num_rows


def run_ingestion(bucket_name: str, dataset_id: str, prefix: Optional[str], write_disposition: str):
    validate_env()

    print("\n=== GCS Parquet to BigQuery Ingestor ===")
    print(f"Project: {PROJECT_ID}")
    print(f"Bucket: gs://{bucket_name}")
    print(f"Dataset: {dataset_id}")
    if prefix:
        print(f"Prefix: {prefix}")
    print("Filter: prism_*.parquet only")

    storage_client = storage.Client(project=PROJECT_ID)
    bq_client = bigquery.Client(project=PROJECT_ID)

    create_bigquery_dataset_if_needed(PROJECT_ID, dataset_id)

    blobs = list_prism_parquet_blobs(storage_client, bucket_name, prefix=prefix)
    if not blobs:
        print("No prism parquet files found. Nothing to do.")
        return

    print(f"Found {len(blobs)} prism parquet file(s).")

    for index, blob in enumerate(blobs, start=1):
        table_name = Path(blob.name).stem
        print(f"\n[{index}/{len(blobs)}] Loading gs://{bucket_name}/{blob.name} -> {dataset_id}.{table_name}")
        loaded_table_name, row_count = load_blob_to_bigquery(
            bq_client=bq_client,
            bucket_name=bucket_name,
            blob_name=blob.name,
            dataset_id=dataset_id,
            write_disposition=write_disposition,
        )
        print(f"Loaded {loaded_table_name}: {row_count} rows.")

    print("\nDone.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Ingest prism parquet files from GCS into BigQuery dataset mxc_raw_claims"
    )
    parser.add_argument(
        "--bucket",
        default=DEFAULT_BUCKET_NAME,
        help=f"GCS bucket name [default: {DEFAULT_BUCKET_NAME}]",
    )
    parser.add_argument(
        "--dataset_id",
        default=DEFAULT_DATASET_ID,
        help=f"Destination BigQuery dataset [default: {DEFAULT_DATASET_ID}]",
    )
    parser.add_argument(
        "--prefix",
        default=None,
        help="Optional GCS prefix to limit scan before prism_ filter",
    )
    parser.add_argument(
        "--write_disposition",
        default="WRITE_TRUNCATE",
        choices=["WRITE_TRUNCATE", "WRITE_APPEND"],
        help="BigQuery write mode per table [default: WRITE_TRUNCATE]",
    )

    args = parser.parse_args()
    run_ingestion(
        bucket_name=args.bucket,
        dataset_id=args.dataset_id,
        prefix=args.prefix,
        write_disposition=args.write_disposition,
    )
