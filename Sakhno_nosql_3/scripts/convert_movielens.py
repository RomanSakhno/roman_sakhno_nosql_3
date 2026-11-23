"""Convert MovieLens 1M .dat files (Latin-1, :: delimiter) to UTF-8 CSV."""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATASET_DIR = ROOT / "ml-1m"
IMPORT_DIR = ROOT / "import"


def convert(source_name, target_name, headers, expected_columns, keep_columns=None):
    source, target = DATASET_DIR / source_name, IMPORT_DIR / target_name
    if not source.exists():
        raise FileNotFoundError(f"Place {source_name} in {IMPORT_DIR}")
    count = 0
    with source.open(encoding="latin-1", newline="") as src, target.open(
        "w", encoding="utf-8", newline=""
    ) as dst:
        writer = csv.writer(dst)
        writer.writerow(headers)
        for line_no, line in enumerate(src, 1):
            parts = line.rstrip("\r\n").split("::")
            if len(parts) != expected_columns:
                raise ValueError(f"{source_name}:{line_no}: expected {expected_columns} fields, got {len(parts)}")
            writer.writerow(parts[:keep_columns] if keep_columns else parts)
            count += 1
    print(f"{source_name} -> {target_name}: {count:,} rows")


if __name__ == "__main__":
    convert("movies.dat", "movies.csv", ["movieId", "title", "genres"], 3)
    convert("ratings.dat", "ratings.csv", ["userId", "movieId", "rating", "timestamp"], 4)
    convert("users.dat", "users.csv", ["userId", "gender", "age", "occupation"], 5, 4)
    print("Conversion completed.")
