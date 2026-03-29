import os 
from dotenv import load_dotenv
import pandas as pd
import requests
from google.cloud import bigquery
from google.oauth2 import service_account

load_dotenv(dotenv_path="secret/.env")
# ==========================
# BIGQUERY SETTINGS
# ==========================
PROJECT_ID = os.getenv("PRISM_BQ_PROJECT_ID")
SERVICE_ACCOUNT_FILE = os.getenv("SERVICE_ACCOUNT_FILE")



def prompt_user_inputs():
    print("\n=== BIGQUERY CONFIGURATION ===")
    dataset_id = input("Enter BigQuery Dataset ID (default: prism_mlv_marts): ").strip()
    if not dataset_id:
        dataset_id = "prism_mlv_marts"
    bq_table_id = input("Enter BigQuery Table Name (source): ").strip()

    print("\n=== AIRTABLE CONFIGURATION ===")
    # base_id = input("Enter Airtable Base ID: ").strip()
    sync_id = input("Enter Airtable Sync ID API: ")
    

    return dataset_id, bq_table_id, sync_id


def fetch_bigquery_data(dataset_id: str, bq_table_id: str) -> pd.DataFrame:
    print("\nFetching data from BigQuery...")

    credentials = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE
    )
    client = bigquery.Client(credentials=credentials, project=PROJECT_ID)

    query = f"SELECT * FROM `{PROJECT_ID}.{dataset_id}.{bq_table_id}`"
    df = client.query(query).to_dataframe()

    if df.empty:
        raise ValueError("BigQuery table returned 0 rows.")

    print(f"Fetched {len(df)} rows from BigQuery.")
    return df


def make_csv_safe(df: pd.DataFrame) -> pd.DataFrame:
    """
    Converts dataframe to Airtable CSV-safe format:
    - Decimal -> float
    - NaN / inf / -inf / extreme floats -> None
    - pd.Timestamp -> ISO string
    """
    import numpy as np
    from decimal import Decimal

    df = df.astype(object)  # prevent automatic coercion
    for col in df.columns:
        def clean_value(x):
            # Convert Decimal / numpy numbers
            if isinstance(x, Decimal):
                x = float(x)
            elif isinstance(x, (np.integer, np.floating)):
                x = float(x)
            # Convert datetime
            elif pd.api.types.is_datetime64_any_dtype(type(x)):
                return x.isoformat()
            # Handle NaN / inf / extreme floats
            if isinstance(x, float):
                if np.isnan(x) or np.isinf(x) or abs(x) > 1e308:
                    return None
            # Other pandas nulls
            if pd.isna(x):
                return None
            return x

        df[col] = df[col].apply(clean_value)
    return df


def sync_csv_to_airtable(df: pd.DataFrame, sync_id: str):
    """
    Upload dataframe as CSV to Airtable Sync API (mirrors the curl example).
    """
    csv_data = df.to_csv(index=False)

    url = f"https://api.airtable.com/v0/{sync_id}"

    headers = {
        "Authorization": f"Bearer {config.AIRTABLE_API_KEY}",
        "Content-Type": "text/csv"
    }

    response = requests.post(url, headers=headers, data=csv_data)

    if response.status_code == 200:
        print("CSV synced successfully!")
    else:
        print("Failed to sync CSV:", response.status_code, response.text)


def main():
    dataset_id, bq_table_id, sync_id = prompt_user_inputs()

    df = fetch_bigquery_data(dataset_id, bq_table_id)
    df = make_csv_safe(df)

    print("\nPreview of Data:")
    print(df.head())

    confirm = input("\nProceed with Airtable Sync? (y/n): ").strip()
    if confirm.lower() == "y":
        sync_csv_to_airtable(df, sync_id)
    else:
        print("Sync cancelled.")


if __name__ == "__main__":
    main()