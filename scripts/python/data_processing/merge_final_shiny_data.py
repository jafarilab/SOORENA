#!/usr/bin/env python3
"""
Create the final dataset for the Shiny app by combining:

1. Labeled autoregulatory papers from training data
2. Predictions on unused unlabeled papers (filtered to autoregulatory only)

This ensures the Shiny app shows only autoregulatory papers.
"""
import sys
from pathlib import Path

# Add repository root to Python path
REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

import pandas as pd
import pyreadr
import os


def load_labeled_papers():
    """Load and combine labeled autoregulatory papers (ground truth)."""
    import config

    train_df = pd.read_csv(config.TRAIN_FILE)
    val_df = pd.read_csv(config.VAL_FILE)
    test_df = pd.read_csv(config.TEST_FILE)

    # Combine all labeled papers
    labeled_df = pd.concat([train_df, val_df, test_df], ignore_index=True)

    # Add source and format for Shiny app
    labeled_df['Source'] = 'UniProt'
    labeled_df['Has Mechanism'] = 'Yes'
    labeled_df['Mechanism Probability'] = 1.0  # Ground truth = 100% confidence

    # Map terms to autoregulatory type
    def get_primary_type(terms):
        if pd.isna(terms) or terms == '':
            return 'non-autoregulatory'
        return terms.split(',')[0].strip()

    labeled_df['Autoregulatory Type'] = labeled_df['Terms'].apply(get_primary_type)
    labeled_df['Type Confidence'] = 1.0  # Ground truth = 100% confidence

    labeled_df = labeled_df[labeled_df['Has Mechanism'] == 'Yes']

    return labeled_df[['PMID', 'Has Mechanism', 'Mechanism Probability',
                       'Source', 'Autoregulatory Type', 'Type Confidence']]


def load_unused_predictions(pred_file):
    """Load predictions on unused unlabeled papers (autoregulatory only)."""
    if not os.path.exists(pred_file):
        print(f"WARNING: {pred_file} not found!")
        print("Run: python scripts/python/prediction/predict_unused_unlabeled.py")
        return None

    pred_df = pd.read_csv(pred_file)

    # Format predictions
    pred_df['Source'] = 'Non-UniProt'
    pred_df['Has Mechanism'] = pred_df['has_mechanism'].map({True: 'Yes', False: 'No'})
    pred_df['Mechanism Probability'] = pred_df['stage1_confidence']
    pred_df['Autoregulatory Type'] = pred_df['mechanism_type'].replace('none', 'non-autoregulatory')
    pred_df['Type Confidence'] = pred_df['stage2_confidence']

    pred_df = pred_df[pred_df['Has Mechanism'] == 'Yes']

    return pred_df[['PMID', 'Has Mechanism', 'Mechanism Probability',
                    'Source', 'Autoregulatory Type', 'Type Confidence']]


def merge_with_metadata(df, autoreg_df):
    """Merge predictions with AutoregDB metadata."""
    # Ensure input df PMID is string
    df['PMID'] = df['PMID'].astype(str)

    # Extract PMID from AutoregDB
    autoreg_df['PMID'] = pd.to_numeric(
        autoreg_df['RX'].str.extract(r'PubMed=(\d+)')[0],
        errors='coerce'
    )

    # Aggregate by PMID
    autoreg_agg = autoreg_df.groupby('PMID', as_index=False).agg({
        'AC': lambda x: ', '.join(x.dropna().astype(str).unique()),
        'OS': 'first'
    })
    # FIX: Convert float PMID to Int64 first (removes .0), then to string
    autoreg_agg['PMID'] = autoreg_agg['PMID'].astype('Int64').astype(str)

    # Merge
    df = df.merge(autoreg_agg, on='PMID', how='left')

    # Create Protein ID
    df['Protein ID'] = df.apply(
        lambda row: f"{row['AC'].split(', ')[0]}_{row['PMID']}" if pd.notna(row['AC']) else f"NA_{row['PMID']}",
        axis=1
    )

    return df


def merge_with_pubmed(df, pubmed_df):
    """Add Title and Abstract columns from raw PubMed data."""
    df['PMID'] = df['PMID'].astype(str)
    pubmed_df['PMID'] = pubmed_df['PMID'].astype(str)

    cols = ['PMID', 'Title', 'Abstract']
    pubmed_trim = pubmed_df[cols].copy()

    merged = df.merge(pubmed_trim, on='PMID', how='left', suffixes=('', '_pubmed'))
    for col in ['Title', 'Abstract']:
        pubmed_col = f"{col}_pubmed"
        if col in merged.columns and pubmed_col in merged.columns:
            merged[col] = merged[col].fillna(merged[pubmed_col])
            merged.drop(columns=[pubmed_col], inplace=True)
    return merged


def main():
    """Create final comprehensive Shiny app dataset."""
    import argparse

    parser = argparse.ArgumentParser(description="Merge datasets for Shiny app.")
    parser.add_argument(
        "--unused-predictions-file",
        default="results/unused_unlabeled_predictions_autoregulatory_only.csv",
        help="Filtered predictions on unused unlabeled papers (default: results/unused_unlabeled_predictions_autoregulatory_only.csv)",
    )
    args = parser.parse_args()

    print("=" * 80)
    print("CREATE FINAL SHINY APP DATASET")
    print("=" * 80)
    print()

    # Load all components
    print("Step 1: Loading labeled papers (ground truth)...")
    labeled_df = load_labeled_papers()
    print(f"   ✓ Loaded {len(labeled_df):,} labeled papers")
    print()

    print("Step 2: Loading predictions on unused unlabeled papers...")
    unused_pred_df = load_unused_predictions(args.unused_predictions_file)
    if unused_pred_df is not None:
        print(f"   ✓ Loaded {len(unused_pred_df):,} predictions")
    else:
        print("   ✗ Skipped (file not found)")
    print()

    # Combine all dataframes
    print("Step 3: Combining all datasets...")
    dfs_to_combine = [df for df in [labeled_df, unused_pred_df] if df is not None]

    if not dfs_to_combine:
        print("ERROR: No data to combine!")
        return

    combined_df = pd.concat(dfs_to_combine, ignore_index=True)
    print(f"   ✓ Combined {len(combined_df):,} papers")

    print()

    # Load AutoregDB for metadata
    print("Step 4: Loading AutoregDB metadata...")
    autoreg = pyreadr.read_r('data/raw/autoregulatoryDB.rds')
    autoreg_df = list(autoreg.values())[0]
    print(f"   ✓ Loaded AutoregDB ({len(autoreg_df):,} entries)")
    print()

    # Merge with metadata (only for old data that doesn't have Protein ID yet)
    print("Step 5: Merging with metadata...")
    combined_df = merge_with_metadata(combined_df, autoreg_df)
    print("   ✓ Metadata merged")
    print()

    # Add Title/Abstract from raw PubMed data
    print("Step 6: Merging Title/Abstract from PubMed...")
    pubmed = pyreadr.read_r('data/raw/pubmed.rds')
    pubmed_df = list(pubmed.values())[0]
    combined_df = merge_with_pubmed(combined_df, pubmed_df)
    print("   ✓ PubMed fields merged")
    print()

    # Ensure all required columns exist
    required_cols = ['Protein ID', 'AC', 'OS', 'PMID',
                     'Has Mechanism', 'Mechanism Probability', 'Source',
                     'Autoregulatory Type', 'Type Confidence',
                     'Title', 'Abstract']

    for col in required_cols:
        if col not in combined_df.columns:
            combined_df[col] = None

    # Save final dataset
    output_file = 'results/unused_predictions_autoregulatory_only_metadata.csv'
    os.makedirs('results', exist_ok=True)

    print("Step 7: Saving final dataset...")
    combined_df.to_csv(output_file, index=False)
    print(f"   ✓ Saved to: {output_file}")
    print()

    # Print summary
    print("=" * 80)
    print("FINAL DATASET SUMMARY")
    print("=" * 80)
    print(f"Total papers: {len(combined_df):,}")
    print()
    print("By Source:")
    print(combined_df['Source'].value_counts().to_string())
    print()
    print("By Mechanism:")
    print(f"  With mechanism:    {(combined_df['Has Mechanism'] == 'Yes').sum():,}")
    print(f"  Without mechanism: {(combined_df['Has Mechanism'] == 'No').sum():,}")
    print()
    print("Autoregulatory Type Distribution (with mechanism only):")
    mech_types = combined_df[combined_df['Has Mechanism'] == 'Yes']['Autoregulatory Type'].value_counts()
    for mech_type, count in mech_types.items():
        print(f"  {mech_type:25s}: {count:,}")
    print()
    print("=" * 80)
    print("✓ SHINY APP DATA READY!")
    print("=" * 80)
    print()
    print("Launch the Shiny app:")
    print("  cd shiny_app && Rscript -e \"shiny::runApp('app.R')\"")
    print("=" * 80)


if __name__ == "__main__":
    main()
