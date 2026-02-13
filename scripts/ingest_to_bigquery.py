import pandas as pd
from sqlalchemy import create_engine
from google.oauth2 import service_account
import sys

# --- CONSTANTS (Defaults) ---
PG_USER = 'postgres'
PG_PASS = 'prism'
PG_HOST = 'localhost'
PG_PORT = '5432'
PG_DB   = 'prism_db'

PROJECT_ID = 'zinc-anvil-486507-v3'
DEFAULT_DATASET_ID = 'prism_mlv'
SERVICE_ACCOUNT_FILE = r'C:\Users\justi\Documents\coding-projects\medgrocer\prism_dbt\secret\justine-prism-mg-service-account.json'


def run_ingestion():
    print("\n=== Postgres to BigQuery Ingestor ===")

    # 1. Ask for user input
    source_table = input("Enter source Postgres table (e.g., dev_mlv.physicianinfo): ").strip()
    if not source_table:
        print("Error: Source table cannot be empty.")
        return

    # Ask for BigQuery dataset
    dataset_id = input(f"Enter destination BigQuery dataset [Default: {DEFAULT_DATASET_ID}]: ").strip()
    if not dataset_id:
        dataset_id = DEFAULT_DATASET_ID

    # Suggest a BQ table name
    suggested_bq_name = source_table.split('.')[-1]
    dest_table = input(f"Enter destination BQ table name [Default: {suggested_bq_name}]: ").strip()
    if not dest_table:
        dest_table = suggested_bq_name

    try:
        # 2. Authenticate
        credentials = service_account.Credentials.from_service_account_file(SERVICE_ACCOUNT_FILE)
        pg_engine = create_engine(f'postgresql://{PG_USER}:{PG_PASS}@{PG_HOST}:{PG_PORT}/{PG_DB}')

        # 3. Extract
        print(f"\n[1/3] Extracting {source_table} from Postgres...")
        df = pd.read_sql(f"SELECT * FROM {source_table}", pg_engine)

        if df.empty:
            print("Warning: The source table is empty. Nothing to ingest.")
            return

        # 4. Load
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
    while True:
        run_ingestion()
        cont = input("\nIngest another table? (y/n): ").lower()
        if cont != 'y':
            print("Exiting ...")
            break
