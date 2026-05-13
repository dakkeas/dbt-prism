import csv
import re
import os

files_to_clean = [
    "seeds/bestlife_health_outcomes/seed_blhc_bp_raw.csv",
    "seeds/bestlife_health_outcomes/seed_blhc_labs_raw.csv"
]

def clean_column(name):
    name = name.lower()
    name = name.replace("\n", " ")
    name = re.sub(r"[^a-z0-9\s_]", "", name)
    name = re.sub(r"\s+", "_", name)
    name = re.sub(r"_+", "_", name)
    return name.strip("_")

for input_file in files_to_clean:
    output_file = input_file + ".tmp"
    print(f"Processing {input_file}...")
    
    with open(input_file, "r", encoding="utf-8-sig", newline="") as infile:
        reader = csv.DictReader(infile)
        original_fields = reader.fieldnames
        new_fields = [clean_column(f) for f in original_fields]
        mapping = dict(zip(original_fields, new_fields))
        
        with open(output_file, "w", encoding="utf-8", newline="") as outfile:
            writer = csv.DictWriter(outfile, fieldnames=new_fields)
            writer.writeheader()
            for row in reader:
                new_row = {mapping[k]: v for k, v in row.items()}
                writer.writerow(new_row)
                
    os.replace(output_file, input_file)
    print(f"Successfully cleaned and overwritten {input_file}")

print("Done cleaning both files!")