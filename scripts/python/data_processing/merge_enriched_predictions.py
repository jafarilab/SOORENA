#!/usr/bin/env python3
"""
Merge enriched prediction CSVs into a single file.

Defaults:
- Base: shiny_app/data/predictions_for_app_enriched.csv
  (unused unlabeled predictions enriched)
- New: results/new_predictions_autoregulatory_only_enriched.csv
  (3M predictions enriched)
"""
import argparse
import sys
from pathlib import Path

import pandas as pd


def main():
    parser = argparse.ArgumentParser(description="Merge enriched prediction CSVs.")
    parser.add_argument(
        "--base",
        default="shiny_app/data/predictions_for_app_enriched.csv",
        help="Base enriched CSV (default: shiny_app/data/predictions_for_app_enriched.csv)",
    )
    parser.add_argument(
        "--new",
        default="results/new_predictions_autoregulatory_only_enriched.csv",
        help="New enriched CSV to append (default: results/new_predictions_autoregulatory_only_enriched.csv)",
    )
    parser.add_argument(
        "--output",
        default="shiny_app/data/predictions_for_app_enriched_merged.csv",
        help="Output CSV path",
    )
    parser.add_argument(
        "--dedupe",
        action="store_true",
        help="Drop duplicate PMIDs (keeps first by default)",
    )
    parser.add_argument(
        "--prefer-new",
        action="store_true",
        help="When deduping, keep rows from the new file",
    )
    parser.add_argument(
        "--pmid-col",
        default="PMID",
        help="PMID column name (default: PMID)",
    )
    args = parser.parse_args()

    base_path = Path(args.base)
    new_path = Path(args.new)
    output_path = Path(args.output)

    if not base_path.exists():
        print(f"ERROR: Base file not found: {base_path}")
        sys.exit(1)
    if not new_path.exists():
        print(f"ERROR: New file not found: {new_path}")
        sys.exit(1)

    base_df = pd.read_csv(base_path, dtype={args.pmid_col: str})
    new_df = pd.read_csv(new_path, dtype={args.pmid_col: str})

    combined = pd.concat([base_df, new_df], ignore_index=True)

    if args.dedupe:
        keep = "last" if args.prefer_new else "first"
        combined = combined.drop_duplicates(subset=[args.pmid_col], keep=keep)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    combined.to_csv(output_path, index=False)

    print(f"Base rows: {len(base_df):,}")
    print(f"New rows:  {len(new_df):,}")
    print(f"Total rows: {len(combined):,}")
    print(f"Saved: {output_path}")


if __name__ == "__main__":
    main()
