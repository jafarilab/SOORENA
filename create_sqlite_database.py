#!/usr/bin/env python3
"""
Create SQLite database from enriched CSV for Shiny app.

Converts 4.6GB CSV to ~500MB SQLite database with indexes for fast querying.
All 3.6M rows will be searchable and filterable in the Shiny app.

Usage:
    python create_sqlite_database.py

Output:
    shiny_app/data/predictions.db (~500MB)
"""
import pandas as pd
import sqlite3
import os
from pathlib import Path

# Configuration
INPUT_CSV = "shiny_app/data/predictions_for_app_enriched.csv"
OUTPUT_DB = "shiny_app/data/predictions.db"
CHUNK_SIZE = 50000  # Process 50K rows at a time to avoid memory issues

def main():
    print("=" * 80)
    print("CREATE SQLITE DATABASE FOR SHINY APP")
    print("=" * 80)
    print()

    # Check input file
    if not os.path.exists(INPUT_CSV):
        print(f"ERROR: Input file not found: {INPUT_CSV}")
        return

    # Remove existing database
    if os.path.exists(OUTPUT_DB):
        print(f"Removing existing database: {OUTPUT_DB}")
        os.remove(OUTPUT_DB)

    # Connect to SQLite
    print(f"Creating database: {OUTPUT_DB}")
    conn = sqlite3.connect(OUTPUT_DB)
    cursor = conn.cursor()

    print()
    print("Step 1: Loading CSV in chunks and writing to database...")
    print(f"Chunk size: {CHUNK_SIZE:,} rows")
    print()

    # Read and process CSV in chunks
    total_rows = 0
    for chunk_num, chunk in enumerate(pd.read_csv(INPUT_CSV,
                                                    dtype=str,  # All columns as strings
                                                    chunksize=CHUNK_SIZE,
                                                    low_memory=False), 1):

        # Standardize column names (spaces → underscores)
        chunk.columns = [col.replace(' ', '_').replace('.', '_') for col in chunk.columns]

        # Convert empty strings to NULL for consistency
        chunk = chunk.replace('', None)
        chunk = chunk.replace('nan', None)

        # Write to database
        chunk.to_sql('predictions', conn, if_exists='append', index=False)

        total_rows += len(chunk)
        print(f"  Chunk {chunk_num}: Processed {total_rows:,} rows...")

    print()
    print(f"✓ Imported {total_rows:,} total rows")
    print()

    # Create indexes for fast filtering
    print("Step 2: Creating indexes for fast querying...")

    indexes = [
        ("idx_pmid", "PMID"),
        ("idx_has_mechanism", "Has_Mechanism"),
        ("idx_year", "Year"),
        ("idx_source", "Source"),
        ("idx_type", "Autoregulatory_Type"),
        ("idx_journal", "Journal"),
        ("idx_os", "OS"),
    ]

    for idx_name, column in indexes:
        print(f"  Creating index on {column}...")
        cursor.execute(f"CREATE INDEX {idx_name} ON predictions({column})")

    print()
    print("✓ Created 7 indexes")
    print()

    # Optimize database
    print("Step 3: Optimizing database...")
    cursor.execute("ANALYZE")
    cursor.execute("VACUUM")
    print("✓ Database optimized")
    print()

    # Get database size
    conn.close()
    db_size_mb = os.path.getsize(OUTPUT_DB) / (1024**2)

    # Final summary
    print("=" * 80)
    print("DATABASE CREATION COMPLETE!")
    print("=" * 80)
    print()
    print(f"Database file: {OUTPUT_DB}")
    print(f"Database size: {db_size_mb:.1f} MB")
    print(f"Total rows:    {total_rows:,}")
    print(f"Indexes:       7")
    print()

    # Check if fits in shinyapps.io free tier
    if db_size_mb < 1000:  # 1GB = 1000MB
        print("✓ Fits in shinyapps.io free tier (1GB storage limit)")
    else:
        print("⚠ Database is larger than shinyapps.io free tier (1GB)")
        print(f"  You'll need shinyapps.io Starter plan ($9/mo, 3GB limit)")

    print()
    print("=" * 80)
    print("NEXT STEPS:")
    print("=" * 80)
    print()
    print("1. Test locally:")
    print("   cd shiny_app")
    print("   Rscript -e \"shiny::runApp('app.R')\"")
    print()
    print("2. Deploy to shinyapps.io:")
    print("   - Database file will be included automatically")
    print("   - See DEPLOYMENT_GUIDE.md for instructions")
    print()
    print("=" * 80)


if __name__ == "__main__":
    main()
