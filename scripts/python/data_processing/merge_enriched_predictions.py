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


def ensure_uniprot_accessions_column(df: pd.DataFrame) -> pd.DataFrame:
    """Ensure UniProtKB_accessions exists; accept common legacy names."""
    df = df.copy()
    if "UniProtKB_accessions" in df.columns:
        return df

    if "UniProtKB accession numbers" in df.columns:
        return df.rename(columns={"UniProtKB accession numbers": "UniProtKB_accessions"})

    # Legacy: AC previously meant UniProt accessions in this project.
    if "AC" in df.columns:
        return df.rename(columns={"AC": "UniProtKB_accessions"})

    df["UniProtKB_accessions"] = ""
    return df


def ensure_source_column(df: pd.DataFrame, default_value: str) -> pd.DataFrame:
    df = df.copy()
    if "Source" not in df.columns:
        df["Source"] = default_value
    else:
        df["Source"] = df["Source"].fillna(default_value)
    return df


def generate_unique_row_ac(df: pd.DataFrame, pmid_col: str, prefix: str) -> pd.DataFrame:
    """Create a deterministic, unique per-row AC column.

    AC is generated as: {prefix}_{PMID}_{n} where n is the 1-based row index within each PMID group
    after stable sorting. This guarantees uniqueness even when duplicate PMIDs exist.
    """
    df = df.copy()
    df[pmid_col] = df[pmid_col].astype(str)

    sort_cols = [pmid_col]
    for candidate in ["Source", "UniProtKB_accessions", "Protein_ID", "Autoregulatory Type", "Autoregulatory_Type"]:
        if candidate in df.columns:
            sort_cols.append(candidate)

    df["_orig_order"] = range(len(df))
    df = df.sort_values(sort_cols + ["_orig_order"], kind="mergesort")
    df["_pmid_rank"] = df.groupby(pmid_col).cumcount() + 1
    df["AC"] = prefix + "_" + df[pmid_col].astype(str) + "_" + df["_pmid_rank"].astype(str)
    df = df.drop(columns=["_orig_order", "_pmid_rank"])
    return df


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
    parser.add_argument(
        "--ac-prefix",
        default="SOORENA",
        help="Prefix for generated per-row AC identifiers (default: SOORENA)",
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

    base_df = ensure_source_column(base_df, default_value="Non-UniProt")
    new_df = ensure_source_column(new_df, default_value="Non-UniProt")

    base_df = ensure_uniprot_accessions_column(base_df)
    new_df = ensure_uniprot_accessions_column(new_df)

    combined = pd.concat([base_df, new_df], ignore_index=True)

    combined = generate_unique_row_ac(combined, pmid_col=args.pmid_col, prefix=args.ac_prefix)

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
