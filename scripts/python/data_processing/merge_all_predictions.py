import pandas as pd
import pyreadr
import os

def main():
    """Merge old predictions with new predictions and update Shiny app data."""

    print("=" * 80)
    print("MERGE PREDICTIONS - Combine Old + New Data")
    print("=" * 80)
    print()

    # Step 1: Load existing app data (old predictions without dates)
    print("Step 1: Loading existing Shiny app data...")
    existing_file = 'shiny_app/data/predictions_for_app.csv'

    if os.path.exists(existing_file):
        existing_df = pd.read_csv(existing_file)
        print(f"   Loaded {len(existing_df):,} existing papers")

        # Add date columns if they don't exist
        if 'Year' not in existing_df.columns:
            print("   Adding Year and Month columns to existing data...")
            existing_df['Year'] = 'Unknown'
            existing_df['Month'] = 'Unknown'
        else:
            print("   Year and Month columns already exist")

        # Ensure PMID is string type for comparison
        existing_df['PMID'] = existing_df['PMID'].astype(str)
    else:
        print("    No existing data found, will create new file")
        existing_df = None

    # Step 2: Load new predictions
    print("\nStep 2: Loading new predictions...")
    new_predictions_file = 'results/new_predictions.csv'

    if not os.path.exists(new_predictions_file):
        print(f"   Error: {new_predictions_file} not found")
        print(f"  Please run predict_new_data.py first to generate predictions.")
        return

    new_df = pd.read_csv(new_predictions_file, dtype={'PMID': str})
    print(f"   Loaded {len(new_df):,} new predictions")

    # Step 3: Load PubMed and AutoregDB metadata
    print("\nStep 3: Loading metadata...")

    # Load AutoregDB
    autoreg = pyreadr.read_r('data/raw/autoregulatoryDB.rds')
    autoreg_df = list(autoreg.values())[0]
    print(f"   Loaded AutoregDB: {len(autoreg_df):,} entries")

    # Extract PMID from RX column
    autoreg_df['PMID'] = pd.to_numeric(
        autoreg_df['RX'].str.extract(r'PubMed=(\d+)')[0],
        errors='coerce'
    )

    # Aggregate by PMID
    autoreg_agg = autoreg_df.groupby('PMID', as_index=False).agg({
        'AC': lambda x: ', '.join(x.dropna().astype(str).unique()),
        'OS': 'first'
    })
    autoreg_agg['PMID'] = autoreg_agg['PMID'].astype(str)
    print(f"   Aggregated to {len(autoreg_agg):,} unique PMIDs")

    # Step 4: Process new predictions
    print("\nStep 4: Processing new predictions...")

    # Merge with AutoregDB
    new_df = new_df.merge(autoreg_agg, on='PMID', how='left')
    print(f"   Merged with AutoregDB")

    # Create Protein ID column
    new_df['Protein ID'] = new_df.apply(
        lambda row: f"{row['AC'].split(', ')[0]}_{row['PMID']}" if pd.notna(row['AC']) else f"NA_{row['PMID']}",
        axis=1
    )

    # Map boolean to Yes/No
    new_df['Has Mechanism'] = new_df['has_mechanism'].map({True: 'Yes', False: 'No'})
    new_df['Mechanism Probability'] = new_df['stage1_confidence']
    new_df['Source'] = 'Non-UniProt'  # New predictions are from PubMed

    # Map mechanism_type to Autoregulatory Type
    new_df['Autoregulatory Type'] = new_df['mechanism_type'].replace('none', 'non-autoregulatory')
    new_df['Type Confidence'] = new_df['stage2_confidence']

    # Select final columns (match existing schema + new date columns)
    new_final_df = new_df[[
        'Protein ID', 'AC', 'OS', 'PMID', 'Title', 'Abstract', 'Journal', 'Authors',
        'Year', 'Month',
        'Has Mechanism', 'Mechanism Probability', 'Source', 'Autoregulatory Type', 'Type Confidence'
    ]]

    print(f"   Formatted {len(new_final_df):,} new predictions")

    # Step 5: Combine old and new data
    print("\nStep 5: Combining datasets...")

    if existing_df is not None:
        # Remove duplicates (new data takes precedence)
        new_pmids = set(new_final_df['PMID'])
        existing_df_filtered = existing_df[~existing_df['PMID'].isin(new_pmids)]
        print(f"   Removed {len(existing_df) - len(existing_df_filtered):,} duplicate PMIDs from old data")

        # Combine
        combined_df = pd.concat([existing_df_filtered, new_final_df], ignore_index=True)
    else:
        combined_df = new_final_df

    print(f"   Combined dataset: {len(combined_df):,} total papers")

    # Step 6: Save updated data
    print("\nStep 6: Saving updated data...")
    os.makedirs('shiny_app/data', exist_ok=True)
    combined_df.to_csv(existing_file, index=False)
    print(f"   Saved to: {existing_file}")

    # Print summary
    print("\n" + "=" * 80)
    print("MERGE COMPLETE")
    print("=" * 80)
    print(f"\nFinal Dataset Summary:")
    print(f"  Total papers: {len(combined_df):,}")
    print(f"  Papers with known dates: {(combined_df['Year'] != 'Unknown').sum():,}")
    print(f"  Papers with unknown dates: {(combined_df['Year'] == 'Unknown').sum():,}")
    print(f"\nMechanism Distribution:")
    print(f"  With mechanisms: {(combined_df['Has Mechanism'] == 'Yes').sum():,}")
    print(f"  Without mechanisms: {(combined_df['Has Mechanism'] == 'No').sum():,}")
    print(f"\nSource Distribution:")
    print(combined_df['Source'].value_counts().to_string())
    print(f"\nYear Distribution (top 10):")
    print(combined_df['Year'].value_counts().head(10).to_string())
    print("\n" + "=" * 80)
    print(" Shiny app data updated successfully")
    print("=" * 80)
    print("\nNext steps:")
    print("  1. (Optional) Enrich with protein names:")
    print("     python enrich_protein_names.py \\")
    print("       --input shiny_app/data/predictions_for_app.csv \\")
    print("       --output shiny_app/data/predictions_for_app_enriched.csv \\")
    print("       --cache data/protein_cache.json")
    print("")
    print("  2. Launch Shiny app:")
    print("     cd shiny_app && R -e 'shiny::runApp()'")
    print("=" * 80)


if __name__ == "__main__":
    main()
