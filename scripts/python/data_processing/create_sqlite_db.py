#!/usr/bin/env python3
"""
Create SQLite database from a CSV dataset.

This script:
1. Loads the CSV file
2. Creates a SQLite database with optimized schema
3. Creates indexes for fast filtering
4. Validates the database

Default output: shiny_app/data/predictions.db
"""
import sys
import argparse
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

import pandas as pd
import sqlite3
import os
from tqdm import tqdm


def create_database(csv_file, db_file, keep_non_autoregulatory=False):
    """Create SQLite database from CSV file."""

    print("="*80)
    print("CREATE SQLITE DATABASE")
    print("="*80)
    print()

    # Step 1: Load CSV
    print(f"Step 1: Loading CSV file: {csv_file}")
    df = pd.read_csv(csv_file, dtype={'PMID': str}, low_memory=False)
    print(f"  ✓ Loaded {len(df):,} rows")
    print(f"  Columns: {df.columns.tolist()}")
    print()

    # Step 2: Delete existing database
    if os.path.exists(db_file):
        print(f"Step 2: Removing existing database: {db_file}")
        os.remove(db_file)
        print("  ✓ Old database removed")
    else:
        print(f"Step 2: No existing database found")
    print()

    # Step 3: Create database connection
    print(f"Step 3: Creating new database: {db_file}")
    conn = sqlite3.connect(db_file)
    cursor = conn.cursor()
    print("  ✓ Database connection created")
    print()

    # Step 4: Create table schema
    print("Step 4: Creating table schema...")

    # Drop table if exists
    cursor.execute("DROP TABLE IF EXISTS predictions")

    # Create table with all columns
    create_table_sql = """
    CREATE TABLE predictions (
        PMID TEXT,
        AC TEXT,
        Has_Mechanism TEXT,
        Mechanism_Probability REAL,
        Source TEXT,
        Autoregulatory_Type TEXT,
        Type_Confidence REAL,
        Title TEXT,
        Abstract TEXT,
        Journal TEXT,
        Authors TEXT,
        Year INTEGER,
        Month TEXT,
        UniProtKB_accessions TEXT,
        OS TEXT,
        Protein_ID TEXT,
        Protein_Name TEXT,
        Gene_Name TEXT
    )
    """
    cursor.execute(create_table_sql)
    print("  ✓ Table schema created")
    print()

    # Step 5: Normalize columns (accept prediction-style or app-style)
    print("Step 5: Normalizing columns...")

    def map_has_mechanism(val):
        if pd.isna(val):
            return pd.NA
        if isinstance(val, bool):
            return "Yes" if val else "No"
        s = str(val).strip().lower()
        if s in {"true", "yes", "1", "y", "t"}:
            return "Yes"
        if s in {"false", "no", "0", "n", "f"}:
            return "No"
        return pd.NA

    # Coalesce duplicate naming variants before rename
    if "Protein ID" in df.columns and "Protein_ID" in df.columns:
        df["Protein ID"] = df["Protein ID"].combine_first(df["Protein_ID"])
        df.drop(columns=["Protein_ID"], inplace=True)
    if "Protein Name" in df.columns and "Protein_Name" in df.columns:
        df["Protein Name"] = df["Protein Name"].combine_first(df["Protein_Name"])
        df.drop(columns=["Protein_Name"], inplace=True)
    if "Gene Name" in df.columns and "Gene_Name" in df.columns:
        df["Gene Name"] = df["Gene Name"].combine_first(df["Gene_Name"])
        df.drop(columns=["Gene_Name"], inplace=True)

    # Normalize UniProtKB accessions column (legacy AC previously meant UniProt accessions)
    if "UniProtKB accession numbers" in df.columns and "UniProtKB_accessions" not in df.columns:
        df.rename(columns={"UniProtKB accession numbers": "UniProtKB_accessions"}, inplace=True)

    def looks_like_uniprot_accessions(series: pd.Series) -> bool:
        s = series.dropna().astype(str).str.strip()
        s = s[s != ""]
        if s.empty:
            return False
        sample = s.head(500)
        if (sample.str.startswith("SOORENA_").mean() > 0.5) or (sample.str.contains("_").mean() > 0.5):
            return False
        # Basic "comma-separated accessions" shape check.
        pattern = r"^[A-Za-z0-9]+(?:,\\s*[A-Za-z0-9]+)*$"
        return sample.str.match(pattern).mean() > 0.8

    if "UniProtKB_accessions" not in df.columns and "AC" in df.columns and looks_like_uniprot_accessions(df["AC"]):
        df["UniProtKB_accessions"] = df["AC"].fillna("")
        df.drop(columns=["AC"], inplace=True)

    # Ensure a unique per-row AC exists; if missing (or duplicated), generate deterministically from PMID.
    if "AC" not in df.columns or df["AC"].isna().all() or df["AC"].duplicated().any():
        pmid = df["PMID"].astype(str).fillna("")
        df["_orig_order"] = range(len(df))
        df = df.sort_values(["PMID", "_orig_order"], kind="mergesort")
        df["_pmid_rank"] = df.groupby("PMID").cumcount() + 1
        df["AC"] = "SOORENA_" + pmid + "_" + df["_pmid_rank"].astype(str)
        df.drop(columns=["_orig_order", "_pmid_rank"], inplace=True)

    # Map prediction-style columns to app-style if needed
    if "has_mechanism" in df.columns:
        mapped = df["has_mechanism"].apply(map_has_mechanism)
        if "Has Mechanism" in df.columns:
            df["Has Mechanism"] = df["Has Mechanism"].combine_first(mapped)
        else:
            df["Has Mechanism"] = mapped

    if "stage1_confidence" in df.columns:
        if "Mechanism Probability" in df.columns:
            df["Mechanism Probability"] = df["Mechanism Probability"].combine_first(df["stage1_confidence"])
        else:
            df["Mechanism Probability"] = df["stage1_confidence"]

    if "mechanism_type" in df.columns:
        mech = df["mechanism_type"].replace("none", "non-autoregulatory")
        if "Autoregulatory Type" in df.columns:
            df["Autoregulatory Type"] = df["Autoregulatory Type"].combine_first(mech)
        else:
            df["Autoregulatory Type"] = mech

    if "stage2_confidence" in df.columns:
        if "Type Confidence" in df.columns:
            df["Type Confidence"] = df["Type Confidence"].combine_first(df["stage2_confidence"])
        else:
            df["Type Confidence"] = df["stage2_confidence"]

    if "Source" not in df.columns:
        df["Source"] = "Non-UniProt"
    else:
        df["Source"] = df["Source"].fillna("Non-UniProt")

    # Rename columns to match database schema (replace spaces with underscores)
    df_renamed = df.rename(columns={
        "Has Mechanism": "Has_Mechanism",
        "Mechanism Probability": "Mechanism_Probability",
        "Autoregulatory Type": "Autoregulatory_Type",
        "Type Confidence": "Type_Confidence",
        "Protein ID": "Protein_ID",
        "Protein Name": "Protein_Name",
        "Gene Name": "Gene_Name"
    })

    print("  ✓ Columns normalized")
    print()

    if not keep_non_autoregulatory:
        # Enforce autoregulatory-only invariant for the Shiny app.
        before = len(df_renamed)
        has_yes = df_renamed["Has_Mechanism"].astype(str).str.strip().str.lower() == "yes"
        autoreg = df_renamed["Autoregulatory_Type"].fillna("").astype(str).str.strip().str.lower()
        is_autoreg = (autoreg != "") & (autoreg != "none") & (autoreg != "non-autoregulatory")
        df_renamed = df_renamed[has_yes & is_autoreg].copy()
        removed = before - len(df_renamed)
        if removed:
            print(f"Step 5b: Filtered out {removed:,} non-autoregulatory / no-mechanism rows")
            print()

    # Step 6: Insert data in batches
    print("Step 6: Inserting data...")

    # Define column order
    db_columns = [
        'PMID', 'AC', 'Has_Mechanism', 'Mechanism_Probability', 'Source',
        'Autoregulatory_Type', 'Type_Confidence', 'Title', 'Abstract',
        'Journal', 'Authors', 'Year', 'Month', 'UniProtKB_accessions', 'OS',
        'Protein_ID', 'Protein_Name', 'Gene_Name'
    ]

    # Ensure all columns exist
    for col in db_columns:
        if col not in df_renamed.columns:
            df_renamed[col] = None

    # Insert data in batches
    batch_size = 10000
    total_rows = len(df_renamed)

    with tqdm(total=total_rows, desc="  Inserting rows") as pbar:
        for start_idx in range(0, total_rows, batch_size):
            end_idx = min(start_idx + batch_size, total_rows)
            batch = df_renamed.iloc[start_idx:end_idx]

            # Convert to records and insert
            batch[db_columns].to_sql(
                'predictions',
                conn,
                if_exists='append',
                index=False,
                method='multi'
            )

            pbar.update(len(batch))

    print("  ✓ Data inserted")
    print()

    # Step 7: Create indexes
    print("Step 7: Creating indexes for fast queries...")

    indexes = [
        ("idx_pmid", "PMID"),
        ("idx_ac", "AC"),
        ("idx_source", "Source"),
        ("idx_has_mechanism", "Has_Mechanism"),
        ("idx_autoregulatory_type", "Autoregulatory_Type"),
        ("idx_year", "Year"),
        ("idx_protein_id", "Protein_ID"),
        ("idx_uniprot_accessions", "UniProtKB_accessions"),
    ]

    for idx_name, column in indexes:
        cursor.execute(f"CREATE INDEX {idx_name} ON predictions({column})")
        print(f"  ✓ Created index: {idx_name} on {column}")

    print()

    # Step 8: Commit and validate
    print("Step 8: Committing changes...")
    conn.commit()
    print("  ✓ Changes committed")
    print()

    # Step 9: Validate
    print("Step 9: Validating database...")

    # Count rows
    cursor.execute("SELECT COUNT(*) FROM predictions")
    db_row_count = cursor.fetchone()[0]
    print(f"  Total rows in database: {db_row_count:,}")

    # Check row count matches
    if db_row_count == len(df):
        print("  ✓ Row count matches CSV!")
    else:
        print(f"  ✗ WARNING: Row count mismatch! CSV: {len(df):,}, DB: {db_row_count:,}")

    # Sample query
    cursor.execute("SELECT Source, COUNT(*) as count FROM predictions GROUP BY Source")
    source_counts = cursor.fetchall()
    print("\n  Source breakdown:")
    for source, count in source_counts:
        print(f"    {source}: {count:,}")

    print()

    # Close connection
    conn.close()

    # Get file size
    db_size_mb = os.path.getsize(db_file) / (1024 * 1024)

    print("="*80)
    print("✓ DATABASE CREATION COMPLETE!")
    print("="*80)
    print(f"Database file: {db_file}")
    print(f"Database size: {db_size_mb:.1f} MB")
    print(f"Total rows: {db_row_count:,}")
    print()
    print("Next step:")
    print("  Launch Shiny app: cd shiny_app && Rscript -e \"shiny::runApp('app.R')\"")
    print("="*80)


def main():
    """Main execution."""
    parser = argparse.ArgumentParser(description="Create SQLite DB from CSV.")
    parser.add_argument(
        "--input",
        default="shiny_app/data/predictions_for_app.csv",
        help="Input CSV path",
    )
    parser.add_argument(
        "--output",
        default="shiny_app/data/predictions.db",
        help="Output SQLite DB path",
    )
    parser.add_argument(
        "--keep-non-autoregulatory",
        action="store_true",
        help="Do not filter out rows with no mechanism / non-autoregulatory type",
    )
    args = parser.parse_args()

    # Check CSV exists
    if not os.path.exists(args.input):
        print(f"ERROR: CSV file not found: {args.input}")
        print("Please provide --input or build the CSV first.")
        sys.exit(1)

    # Create database
    create_database(args.input, args.output, keep_non_autoregulatory=args.keep_non_autoregulatory)


if __name__ == "__main__":
    main()
