
import pandas as pd
from sqlalchemy import create_engine
from google.oauth2 import service_account
import sys

# --- CONSTANTS (Things that don't change often) ---
PG_USER = 'postgres'
PG_PASS = 'prism'
PG_HOST = 'localhost'
PG_PORT = '5432'
PG_DB   = 'prism_db'

PROJECT_ID = 'zinc-anvil-486507-v3'
DATASET_ID = 'prism_mlv'
SERVICE_ACCOUNT_FILE = r'C:\Users\justi\Documents\coding-projects\medgrocer\prism_dbt\secret\justine-prism-mg-service-account.json'

def run_ingestion():
    # 1. Ask for user input
    print("\n=== Postgres to BigQuery Ingestor ===")
    
    source_table = input(f"Enter source Postgres table (e.g., dev_mlv.physicianinfo): ").strip()
    if not source_table:
        print("Error: Source table cannot be empty.")
        return

    # Suggest a BQ name based on the source (stripping schema prefix)
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
        df = pd.read_sql(f'SELECT * FROM {source_table}', pg_engine)
        
        if df.empty:
            print("Warning: The source table is empty. Nothing to ingest.")
            return

        # 4. Load
        print(f"[2/3] Ingesting {len(df)} rows into BigQuery ({DATASET_ID}.{dest_table})...")
        df.to_gbq(
            destination_table=f"{DATASET_ID}.{dest_table}",
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
            print("Goodbye!")
            break