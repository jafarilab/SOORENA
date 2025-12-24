#!/usr/bin/env python3
"""
Filter out rows with no autoregulatory mechanism.

Default behavior keeps only rows where has_mechanism is truthy (True/Yes/1).
"""
import argparse
import sys
from pathlib import Path

import pandas as pd


TRUTHY = {"true", "1", "yes", "y", "t"}


def is_truthy(value):
    if pd.isna(value):
        return False
    return str(value).strip().lower() in TRUTHY


def main():
    parser = argparse.ArgumentParser(description="Filter rows with no mechanism.")
    parser.add_argument("--input", required=True, help="Input CSV path")
    parser.add_argument("--output", required=True, help="Output CSV path")
    parser.add_argument(
        "--column",
        default="has_mechanism",
        help="Column that indicates mechanism presence (default: has_mechanism)",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    if not input_path.exists():
        print(f"ERROR: Input file not found: {input_path}")
        sys.exit(1)

    df = pd.read_csv(input_path)
    if args.column not in df.columns:
        print(f"ERROR: Column not found: {args.column}")
        sys.exit(1)

    filtered = df[df[args.column].apply(is_truthy)].copy()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    filtered.to_csv(output_path, index=False)

    print(f"Input rows: {len(df):,}")
    print(f"Kept rows (has mechanism): {len(filtered):,}")
    print(f"Saved: {output_path}")


if __name__ == "__main__":
    main()
