import pandas as pd
import numpy as np
from sqlalchemy import create_engine
import hdbscan
import jellyfish
from collections import Counter
import re

# ------------------------
# Postgres connection
# ------------------------
PG_USER = 'postgres'
PG_PASS = 'prism'
PG_HOST = 'localhost'
PG_PORT = '5432'
PG_DB   = 'prism_db'

pg_engine = create_engine(f'postgresql://{PG_USER}:{PG_PASS}@{PG_HOST}:{PG_PORT}/{PG_DB}')

source_table = 'dev_marts.ocr_cleaned_012126'
target_schema = 'dev_ocr'
target_table = 'clustering_test'

# Extract
print(f"Extracting {source_table} from Postgres...")
df = pd.read_sql(f'SELECT * FROM {source_table}', pg_engine)

if df.empty:
    print("Warning: The source table is empty.")
    exit()

# ------------------------
# Preprocessing & cleaning
# ------------------------
line_items_col = 'item_name'
df[line_items_col] = df[line_items_col].astype(str)

# Clean characters but keep numbers (critical for dosage/leads)
df[line_items_col] = df[line_items_col].apply(lambda x: re.sub(r"[‘•■*,;:<'„>_]", "", x))
df[line_items_col] = df[line_items_col].str.lower().str.strip()

# ------------------------
# Jaro-Winkler Distance Matrix
# ------------------------
print("Calculating Jaro-Winkler distance matrix...")
names = df[line_items_col].tolist()

# Generate distance matrix (1.0 = completely different, 0.0 = identical)
matrix = np.array([
    [1 - jellyfish.jaro_winkler_similarity(s1, s2) for s1 in names] 
    for s2 in names
])

# ------------------------
# HDBSCAN Clustering
# ------------------------
print("Running HDBSCAN...")
# cluster_selection_epsilon: 0.1 means items must be ~90% similar to cluster
clusterer = hdbscan.HDBSCAN(
    metric='precomputed', 
    min_cluster_size=2, 
    min_samples=1, 
    cluster_selection_epsilon=0.1 
)

df['cluster_id'] = clusterer.fit_predict(matrix)

# ------------------------
# Representative Name (The "Longest" String Logic)
# ------------------------
# We use the longest string because medical OCR usually truncates (e.g., "POTASSIU" vs "POTASSIUM")
representative_names = {}
for cluster in df['cluster_id'].unique():
    if cluster == -1:
        representative_names[cluster] = "Outlier/Noise"
        continue
    
    items = df[df['cluster_id'] == cluster][line_items_col].unique()
    # Sort by length descending and pick the top one
    representative_names[cluster] = sorted(items, key=len, reverse=True)[0]

df['cluster_rep_name'] = df['cluster_id'].map(representative_names)

# ------------------------
# Export to Postgres
# ------------------------
df.to_csv('ocr_lineitems_clustered_cleaned.csv', index=False) # ќiprint("\nSaved clustered line items to 'ocr_lineitems_clustered_cleaned.csv'")
# print(f"Exporting results to {target_schema}.{target_table}...")

# # Create schema if it doesn't exist
# with pg_engine.connect() as conn:
#     conn.execute(f"CREATE SCHEMA IF NOT EXISTS {target_schema};")

# df.to_sql(
#     target_table, 
#     pg_engine, 
#     schema=target_schema, 
#     if_exists='replace', 
#     index=False
# )

# print("Process complete.")