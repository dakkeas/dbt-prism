import csv

input_file = "seeds/bestlife_health_outcomes/seed_blhc_labs_raw_removed_cols.csv"
output_file = "seeds/bestlife_health_outcomes/seed_blhc_labs_raw_removed_cols_v2.csv"

# columns to remove
DROP_COLUMNS = {
    "List of Tests"
}

with open(input_file, "r", encoding="utf-8-sig", newline="") as infile:
    reader = csv.DictReader(infile)

    # keep only columns NOT in DROP_COLUMNS
    fieldnames = [f for f in reader.fieldnames if f not in DROP_COLUMNS]

    with open(output_file, "w", encoding="utf-8", newline="") as outfile:
        writer = csv.DictWriter(outfile, fieldnames=fieldnames)

        writer.writeheader()

        for row in reader:
            cleaned_row = {k: v for k, v in row.items() if k in fieldnames}
            writer.writerow(cleaned_row)

print("Done!")
print("Saved to:", output_file)