import pandas as pd
import re
import numpy as np

input_file = "/Users/jdaquis/Documents/Repositories/dbt-prism/seeds/bestlife_health_outcomes/seed_blhc_labs_raw.csv"
output_file = "/Users/jdaquis/Documents/Repositories/dbt-prism/seeds/bestlife_health_outcomes/seed_blhc_labs_clean.csv"



cols = [
    "hba1c_ngsp",
    "glucose_fastingfbs_mgdl",
    "creatinine_mgdl",
    "ldl_cholesterol_mgdl"
]

def clean_value(val):
    if pd.isna(val):
        return np.nan

    val = str(val).strip()

    # remove known invalid markers
    if val.upper() in ["N/A", "NA", "", ">14.0"]:
        return np.nan

    # remove all non-numeric except dot
    val = re.sub(r"[^0-9\.]", "", val)

    # fix multiple dots (e.g. 14..0 -> 14.0)
    val = re.sub(r"\.+", ".", val)

    # edge case: leading or trailing dot
    val = val.strip(".")

    # if empty after cleaning
    if val == "":
        return np.nan

    try:
        return float(val)
    except:
        return np.nan


df = pd.read_csv(input_file)

for c in cols:
    df[c] = df[c].apply(clean_value)

df.to_csv(output_file, index=False)

print("Cleaning complete!")
print("Saved to:", output_file)