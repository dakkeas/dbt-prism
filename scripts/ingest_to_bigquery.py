import os
import argparse
from dotenv import load_dotenv

# specify the full path
load_dotenv(dotenv_path="secret/.env")

import pandas as pd
from sqlalchemy import create_engine
from google.oauth2 import service_account

# --- CONSTANTS (Defaults) ---

PG_USER = os.getenv("PG_USER")
PG_PASS = os.getenv("PG_PASS")
PG_HOST = os.getenv("PG_HOST")
PG_PORT = os.getenv("PG_PORT")
PG_DB   = os.getenv("PG_DB")

PROJECT_ID = os.getenv("BQ_PROJECT_ID")
DEFAULT_DATASET_ID = os.getenv("BQ_DATASET_ID")
SERVICE_ACCOUNT_FILE = os.getenv("SERVICE_ACCOUNT_FILE")

def run_ingestion(source_table, dataset_id, dest_table):
    print("\n=== Postgres to BigQuery Ingestor ===")

    try:
        # 1. Authenticate
        credentials = service_account.Credentials.from_service_account_file(SERVICE_ACCOUNT_FILE)
        pg_engine = create_engine(f'postgresql://{PG_USER}:{PG_PASS}@{PG_HOST}:{PG_PORT}/{PG_DB}')

        # 2. Extract
        print(f"\n[1/3] Extracting {source_table} from Postgres...")
        df = pd.read_sql(f"SELECT * FROM {source_table}", pg_engine)

        if df.empty:
            print("Warning: The source table is empty. Nothing to ingest.")
            return

        # 3. Load
        print(f"[2/3] Ingesting {len(df)} rows into BigQuery ({dataset_id}.{dest_table})...")
        df.to_gbq(
            destination_table=f"{dataset_id}.{dest_table}",
            project_id=PROJECT_ID,
            credentials=credentials,
            if_exists='replace',
            progress_bar=True
        )

        print(f"[3/3] Success! {dest_table} is now updated in BigQuery.")

    except Exception as e:
        print(f"\n❌ ERROR: {str(e)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingest table from Postgres to BigQuery")
    parser.add_argument("source_table", help="Source Postgres table (e.g., dev_mlv.physicianinfo)")
    parser.add_argument("--dataset_id", "-d", default=DEFAULT_DATASET_ID, help=f"Destination BigQuery dataset [Default: {DEFAULT_DATASET_ID}]")
    parser.add_argument("--dest_table", "-t", help="Destination BQ table name [Default: last part of source table]")
    
    args = parser.parse_args()
    
    dest_table = args.dest_table
    if not dest_table:
        dest_table = args.source_table.split('.')[-1]
        
    run_ingestion(args.source_table, args.dataset_id, dest_table)
