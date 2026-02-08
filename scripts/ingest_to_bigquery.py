


import pandas as pd
from sqlalchemy import create_engine
from google.oauth2 import service_account

# 1. SETTINGS - POSTGRES
PG_USER = 'postgres'
PG_PASS = 'prism'
PG_HOST = 'localhost'
PG_PORT = '5432'
PG_DB   = 'prism_db'
PG_TABLE = 'dev_mlv.mlv'

# 2. SETTINGS - BIGQUERY
PROJECT_ID = 'zinc-anvil-486507-v3'
DATASET_ID = 'prism_mlv'
BQ_TABLE   = 'mlv'
SERVICE_ACCOUNT_FILE = r'C:\Users\justi\Documents\coding-projects\medgrocer\prism_dbt\secret\justine-prism-mg-service-account.json'

def ingest_postgres_to_bq():
    # Authenticate with Google
    credentials = service_account.Credentials.from_service_account_file(SERVICE_ACCOUNT_FILE)
    
    # Create Postgres Connection
    pg_engine = create_engine(f'postgresql://{PG_USER}:{PG_PASS}@{PG_HOST}:{PG_PORT}/{PG_DB}')
    
    print(f"--- Extracting {PG_TABLE} from Postgres ---")
    # Read data from Postgres into a DataFrame
    # Using a chunking strategy if the table is very large
    df = pd.read_sql(f'SELECT * FROM {PG_TABLE}', pg_engine)
    
    print(f"--- Ingesting {len(df)} rows into BigQuery ({DATASET_ID}.{BQ_TABLE}) ---")
    
    # Load to BigQuery
    # if_exists='replace' will overwrite the table; use 'append' if adding to it
    df.to_gbq(
        destination_table=f"{DATASET_ID}.{BQ_TABLE}",
        project_id=PROJECT_ID,
        credentials=credentials,
        if_exists='replace', 
        progress_bar=True
    )
    
    print("--- Ingestion Complete! ---")

if __name__ == "__main__":
    ingest_postgres_to_bq()