import re
import pandas as pd

from rapidfuzz import process, fuzz
from sqlalchemy import create_engine, text
from collections import defaultdict

# =========================================================
# POSTGRES CONNECTION
# =========================================================

DB_USER = "jdaquis"
DB_PASSWORD = "prism"
DB_HOST = "localhost"
DB_PORT = "5432"
DB_NAME = "prism_db"

engine = create_engine(
    f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

# =========================================================
# CONFIG
# =========================================================

BROKEN_TABLE = "dev_sandbox.broken_physiciannames"
GOOD_TABLE = "dev_staging.physicianinfo"

OUTPUT_TABLE = "dev_acn.physician_name_matching_results"

BROKEN_COLUMN = "physicianname"
GOOD_COLUMN = "physicianname"

MATCH_THRESHOLD = 70 

# =========================================================
# WORDS TO REMOVE
# =========================================================

STOPWORDS = {
    "DR",
    "MD",
    "DOCTOR",
    "PHYSICIAN",
    "PROVIDER",
    "CLINIC",
    "HOSPITAL",
    "MEDICAL",
    "CENTER",
    "HEALTH",
    "CARE",
    "CORPORATION",
    "INC",
    "LLC",
    "THE"
}

# =========================================================
# CLEANING
# =========================================================

def clean_name(name):

    if pd.isna(name):
        return ""

    name = str(name).upper()

    # REMOVE PARENTHESIS CONTENT
    name = re.sub(r"\(.*?\)", " ", name)

    # REMOVE SPECIAL CHARS
    name = re.sub(r"[^A-Z\s]", " ", name)

    # NORMALIZE SPACES
    name = re.sub(r"\s+", " ", name).strip()

    # TOKENIZE
    parts = name.split()

    # REMOVE STOPWORDS
    parts = [p for p in parts if p not in STOPWORDS]

    return " ".join(parts)

# =========================================================
# TOKEN CANONICALIZATION
# =========================================================

def canonical_tokens(name):

    if not name:
        return ""

    tokens = sorted(set(name.split()))

    return " ".join(tokens)

# =========================================================
# BLOCK KEY
# =========================================================

def block_key(name):

    if not name:
        return ""

    tokens = name.split()

    if len(tokens) == 1:
        return tokens[0]

    return tokens[0][0] + "_" + tokens[-1][0]

# =========================================================
# TOKEN OVERLAP SCORE
# =========================================================

def token_overlap_score(a, b):

    set_a = set(a.split())
    set_b = set(b.split())

    if not set_a or not set_b:
        return 0

    overlap = len(set_a & set_b)

    return overlap / max(len(set_a), len(set_b)) * 100

# =========================================================
# LOAD DATA
# =========================================================

print("Loading broken names...")

broken_df = pd.read_sql(f"""
SELECT DISTINCT {BROKEN_COLUMN}
FROM {BROKEN_TABLE}
WHERE {BROKEN_COLUMN} IS NOT NULL
""", engine)

print("Loading clean names...")

good_df = pd.read_sql(f"""
SELECT DISTINCT {GOOD_COLUMN}
FROM {GOOD_TABLE}
WHERE {GOOD_COLUMN} IS NOT NULL
""", engine)

broken_df["row_id"] = broken_df.index

# =========================================================
# CLEAN + FEATURES
# =========================================================

broken_df["cleaned"] = broken_df[BROKEN_COLUMN].apply(clean_name)
good_df["cleaned"] = good_df[GOOD_COLUMN].apply(clean_name)

broken_df["canon"] = broken_df["cleaned"].apply(canonical_tokens)
good_df["canon"] = good_df["cleaned"].apply(canonical_tokens)

broken_df["block"] = broken_df["canon"].apply(block_key)
good_df["block"] = good_df["canon"].apply(block_key)

# =========================================================
# BUILD LOOKUPS
# =========================================================

print("Building indexes...")

block_lookup = defaultdict(list)
canon_to_original = {}

for _, row in good_df.iterrows():

    canon = row["canon"]
    block = row["block"]

    block_lookup[block].append(canon)

    canon_to_original[canon] = row[GOOD_COLUMN]

all_candidates = list(canon_to_original.keys())

# =========================================================
# MATCHING
# =========================================================

results = []

total = len(broken_df)

print("Starting matching...")

for idx, row in broken_df.iterrows():

    if idx % 1000 == 0:
        print(f"{idx:,} / {total:,}")

    original = row[BROKEN_COLUMN]
    canon = row["canon"]
    block = row["block"]

    candidates = block_lookup.get(block)

    if not candidates:
        candidates = all_candidates

    # =====================================================
    # TOKEN-BASED FUZZY MATCH
    # =====================================================

    match = process.extractOne(
        canon,
        candidates,
        scorer=fuzz.token_set_ratio
    )

    matched_canon = None
    fuzzy_score = 0

    if match:
        matched_canon = match[0]
        fuzzy_score = match[1]

    overlap_score = 0

    if matched_canon:
        overlap_score = token_overlap_score(
            canon,
            matched_canon
        )

    # =====================================================
    # FINAL HYBRID SCORE
    # =====================================================

    final_score = (
        fuzzy_score * 0.7
        + overlap_score * 0.3
    )

    formatted = None

    if final_score >= MATCH_THRESHOLD:
        formatted = canon_to_original.get(matched_canon)

    results.append({
        "broken_physicianname_original": original,
        "cleaned_broken": canon,
        "matched_cleaned": matched_canon,
        "formatted_physicianname": formatted,
        "fuzzy_score": round(fuzzy_score, 2),
        "overlap_score": round(overlap_score, 2),
        "final_score": round(final_score, 2)
    })

# =========================================================
# SAVE
# =========================================================

results_df = pd.DataFrame(results)

print(f"Saving {len(results_df):,} rows...")

with engine.begin() as conn:
    conn.execute(text(f"DROP TABLE IF EXISTS {OUTPUT_TABLE}"))

results_df.to_sql(
    "physician_name_matching_results",
    schema="dev_acn",
    con=engine,
    if_exists="replace",
    index=False
)

print("Done.")