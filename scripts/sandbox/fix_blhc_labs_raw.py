import csv

input_file = "seeds/bestlife_health_outcomes/seed_blhc_labs_raw.csv"
output_file = "seeds/bestlife_health_outcomes/seed_blhc_labs_raw_fixed.csv"

TARGET_COLUMN = "List of Tests"

with open(input_file, "r", encoding="utf-8-sig", newline="") as infile:
    reader = csv.DictReader(infile)

    fieldnames = reader.fieldnames

    if TARGET_COLUMN not in fieldnames:
        raise ValueError(f"Column '{TARGET_COLUMN}' not found.")

    with open(output_file, "w", encoding="utf-8", newline="") as outfile:
        writer = csv.DictWriter(
            outfile,
            fieldnames=fieldnames,
            quoting=csv.QUOTE_MINIMAL
        )

        writer.writeheader()

        for row in reader:
            value = row[TARGET_COLUMN]

            if value is None:
                value = ""

            # force-wrap in quotes
            row[TARGET_COLUMN] = f'"{value.strip()}"'

            writer.writerow(row)
print(f"Fixed file written to: {output_file}")