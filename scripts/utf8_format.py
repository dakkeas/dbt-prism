import codecs

input_file = "/Users/jdaquis/Documents/Repositories/dbt-prism/seeds/pcc_data/seed_pcc_availments_raw_data.csv"
output_file = "/Users/jdaquis/Documents/Repositories/dbt-prism/seeds/pcc_data/seed_pcc_availments_raw_data_utf8.csv"

# encodings to try
encodings = [
    "utf-8",
    "utf-8-sig",
    "cp1252",       # Windows ANSI
    "latin-1",
    "iso-8859-1"
]

content = None

for enc in encodings:
    try:
        with codecs.open(input_file, "r", encoding=enc) as f:
            content = f.read()
        print(f"Successfully read using: {enc}")
        break
    except UnicodeDecodeError:
        print(f"Failed decoding with: {enc}")

if content is None:
    raise Exception("Could not decode file with known encodings.")

# write clean UTF-8
with open(output_file, "w", encoding="utf-8", newline="") as f:
    f.write(content)

print(f"Saved UTF-8 file as: {output_file}")