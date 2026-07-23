import os
import argparse
from dotenv import load_dotenv

# Load environment variables from secret/.env, looking for it relative to this script
script_dir = os.path.dirname(os.path.abspath(__file__))
dotenv_path = os.path.abspath(os.path.join(script_dir, "..", "secret", ".env"))
if not os.path.exists(dotenv_path):
    dotenv_path = "secret/.env"
load_dotenv(dotenv_path=dotenv_path)

import pandas as pd
from google.cloud import bigquery
from sqlalchemy import create_engine, inspect

# --- CONSTANTS (Defaults) ---

PG_USER = os.getenv("PG_USER")
PG_PASS = os.getenv("PG_PASS")
PG_HOST = os.getenv("PG_HOST")
PG_PORT = os.getenv("PG_PORT")
PG_DB = os.getenv("PG_DB")

PROJECT_ID = os.getenv("BQ_PROJECT_ID") or os.getenv("PRISM_BQ_PROJECT_ID")


def create_bigquery_dataset_if_needed(dataset_id):
    client = bigquery.Client(project=PROJECT_ID)
    dataset_ref = bigquery.Dataset(f"{PROJECT_ID}.{dataset_id}")
    client.create_dataset(dataset_ref, exists_ok=True)


def get_postgres_tables(pg_engine, source_schema):
    inspector = inspect(pg_engine)
    return inspector.get_table_names(schema=source_schema)


def run_schema_ingestion(source_schema, dataset_id):
    print("\n=== Postgres Schema to BigQuery Ingestor ===")

    try:
        pg_engine = create_engine(f"postgresql://{PG_USER}:{PG_PASS}@{PG_HOST}:{PG_PORT}/{PG_DB}")
        preparer = pg_engine.dialect.identifier_preparer

        print(f"\n[1/4] Ensuring BigQuery dataset exists: {PROJECT_ID}.{dataset_id}")
        create_bigquery_dataset_if_needed(dataset_id)

        print(f"[2/4] Finding tables in Postgres schema: {source_schema}")
        tables = get_postgres_tables(pg_engine, source_schema)

        if not tables:
            print(f"Warning: No tables found in Postgres schema '{source_schema}'.")
            return

        print(f"[3/4] Found {len(tables)} table(s).")

        for index, table_name in enumerate(tables, start=1):
            quoted_schema = preparer.quote_schema(source_schema)
            quoted_table = preparer.quote(table_name)
            source_table = f"{quoted_schema}.{quoted_table}"

            print(f"\n[{index}/{len(tables)}] Extracting {source_schema}.{table_name} from Postgres...")
            df = pd.read_sql(f"SELECT * FROM {source_table}", pg_engine)

            if df.empty:
                print("Warning: The source table is empty. Skipping.")
                continue

            print(f"Loading {len(df)} rows into BigQuery ({dataset_id}.{table_name})...")
            df.to_gbq(
                destination_table=f"{dataset_id}.{table_name}",
                project_id=PROJECT_ID,
                if_exists="replace",
                progress_bar=True,
            )

            print(f"Success: {dataset_id}.{table_name} updated.")

        print(f"\n[4/4] Done. Loaded Postgres schema {source_schema} into BigQuery dataset {dataset_id}.")

    except Exception as e:
        print(f"\nERROR: {str(e)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingest all tables from a Postgres schema to BigQuery")
    parser.add_argument("source_schema", help="Source Postgres schema (e.g., dev_bestlife)")
    parser.add_argument("dataset_id", help="Destination BigQuery dataset (e.g., prism_bestlife)")

    args = parser.parse_args()

    run_schema_ingestion(args.source_schema, args.dataset_id)
