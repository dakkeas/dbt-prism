import csv

input_file = "seeds/bestlife_health_outcomes/seed_blhc_labs_raw_fixed.csv"
output_file = "seeds/bestlife_health_outcomes/seed_blhc_labs_raw_clean.csv"

with open(input_file, "r", encoding="utf-8") as infile:
    # detect tab or comma automatically
    sample = infile.readline()
    delimiter = "\t" if "\t" in sample else ","

with open(input_file, "r", encoding="utf-8") as infile, \
     open(output_file, "w", encoding="utf-8", newline="") as outfile:

    reader = csv.reader(infile, delimiter=delimiter)
    writer = csv.writer(outfile)

    for row in reader:
        writer.writerow(row)

print("Converted to clean CSV:", output_file)