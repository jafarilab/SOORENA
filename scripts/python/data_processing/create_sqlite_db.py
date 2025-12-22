#!/usr/bin/env python3
"""
Create SQLite database from predictions_for_app.csv

This script:
1. Loads the final CSV file
2. Creates a SQLite database with optimized schema
3. Creates indexes for fast filtering
4. Validates the database

Output: shiny_app/data/predictions.db
"""
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

import pandas as pd
import sqlite3
import os
from tqdm import tqdm


def create_database(csv_file, db_file):
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
        AC TEXT,
        OS TEXT,
        Protein_ID TEXT,
        Protein_Name TEXT,
        Gene_Name TEXT
    )
    """
    cursor.execute(create_table_sql)
    print("  ✓ Table schema created")
    print()

    # Step 5: Insert data in batches
    print("Step 5: Inserting data...")

    # Rename columns to match database schema (replace spaces with underscores)
    df_renamed = df.rename(columns={
        'Has Mechanism': 'Has_Mechanism',
        'Mechanism Probability': 'Mechanism_Probability',
        'Autoregulatory Type': 'Autoregulatory_Type',
        'Type Confidence': 'Type_Confidence',
        'Protein ID': 'Protein_ID',
        'Protein Name': 'Protein_Name',
        'Gene Name': 'Gene_Name'
    })

    # Define column order
    db_columns = [
        'PMID', 'Has_Mechanism', 'Mechanism_Probability', 'Source',
        'Autoregulatory_Type', 'Type_Confidence', 'Title', 'Abstract',
        'Journal', 'Authors', 'Year', 'Month', 'AC', 'OS',
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

    # Step 6: Create indexes
    print("Step 6: Creating indexes for fast queries...")

    indexes = [
        ("idx_pmid", "PMID"),
        ("idx_source", "Source"),
        ("idx_has_mechanism", "Has_Mechanism"),
        ("idx_autoregulatory_type", "Autoregulatory_Type"),
        ("idx_year", "Year"),
        ("idx_protein_id", "Protein_ID"),
        ("idx_ac", "AC")
    ]

    for idx_name, column in indexes:
        cursor.execute(f"CREATE INDEX {idx_name} ON predictions({column})")
        print(f"  ✓ Created index: {idx_name} on {column}")

    print()

    # Step 7: Commit and validate
    print("Step 7: Committing changes...")
    conn.commit()
    print("  ✓ Changes committed")
    print()

    # Step 8: Validate
    print("Step 8: Validating database...")

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
    csv_file = 'shiny_app/data/predictions_for_app.csv'
    db_file = 'shiny_app/data/predictions.db'

    # Check CSV exists
    if not os.path.exists(csv_file):
        print(f"ERROR: CSV file not found: {csv_file}")
        print("Please run rebuild_final_dataset.py first")
        sys.exit(1)

    # Create database
    create_database(csv_file, db_file)


if __name__ == "__main__":
    main()
