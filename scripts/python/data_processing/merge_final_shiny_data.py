#!/usr/bin/env python3
"""
Create the final comprehensive dataset for the Shiny app by combining:

1. Labeled papers (has mechanism) - 1,332 papers from AutoregDB
2. Unlabeled used in training (no mechanism) - 2,664 papers
3. Predictions on unused unlabeled - ~250K papers
4. Predictions on new 3M PubMed papers (if available)

This ensures the Shiny app shows:
- Ground truth labeled data
- Training negatives (explicitly labeled as no mechanism)
- Model predictions on unseen data
- New predictions
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
    """Load and combine all labeled papers (ground truth)."""
    import config

    train_df = pd.read_csv(config.TRAIN_FILE)
    val_df = pd.read_csv(config.VAL_FILE)
    test_df = pd.read_csv(config.TEST_FILE)

    # Combine all labeled papers
    labeled_df = pd.concat([train_df, val_df, test_df], ignore_index=True)

    # Add source and format for Shiny app
    labeled_df['Source'] = 'UniProt (Ground Truth)'
    labeled_df['Has Mechanism'] = 'Yes'
    labeled_df['Mechanism Probability'] = 1.0  # Ground truth = 100% confidence

    # Map terms to autoregulatory type
    def get_primary_type(terms):
        if pd.isna(terms) or terms == '':
            return 'non-autoregulatory'
        return terms.split(',')[0].strip()

    labeled_df['Autoregulatory Type'] = labeled_df['Terms'].apply(get_primary_type)
    labeled_df['Type Confidence'] = 1.0  # Ground truth = 100% confidence

    return labeled_df[['PMID', 'Has Mechanism', 'Mechanism Probability',
                       'Source', 'Autoregulatory Type', 'Type Confidence']]


def load_unlabeled_training_samples():
    """Load unlabeled papers used in training (explicit negatives)."""
    unlabeled_file = 'data/processed/stage1_unlabeled_negatives.csv'

    if not os.path.exists(unlabeled_file):
        print(f"WARNING: {unlabeled_file} not found!")
        print("Run: python scripts/python/training/train_stage1.py")
        return None

    unlabeled_df = pd.read_csv(unlabeled_file)

    # These are explicitly labeled as no mechanism
    unlabeled_df['Source'] = 'Training Negatives'
    unlabeled_df['Has Mechanism'] = 'No'
    unlabeled_df['Mechanism Probability'] = 0.0
    unlabeled_df['Autoregulatory Type'] = 'non-autoregulatory'
    unlabeled_df['Type Confidence'] = 0.0

    return unlabeled_df[['PMID', 'Has Mechanism', 'Mechanism Probability',
                         'Source', 'Autoregulatory Type', 'Type Confidence']]


def load_unused_predictions():
    """Load predictions on unused unlabeled papers."""
    pred_file = 'results/unused_unlabeled_predictions.csv'

    if not os.path.exists(pred_file):
        print(f"WARNING: {pred_file} not found!")
        print("Run: python scripts/python/prediction/predict_unused_unlabeled.py")
        return None

    pred_df = pd.read_csv(pred_file)

    # Format predictions
    pred_df['Source'] = 'Model Predictions (Unused)'
    pred_df['Has Mechanism'] = pred_df['has_mechanism'].map({True: 'Yes', False: 'No'})
    pred_df['Mechanism Probability'] = pred_df['stage1_confidence']
    pred_df['Autoregulatory Type'] = pred_df['mechanism_type'].replace('none', 'non-autoregulatory')
    pred_df['Type Confidence'] = pred_df['stage2_confidence']

    return pred_df[['PMID', 'Has Mechanism', 'Mechanism Probability',
                    'Source', 'Autoregulatory Type', 'Type Confidence']]


def load_new_predictions():
    """Load predictions on new 3M PubMed papers (if available)."""
    new_pred_file = 'results/new_predictions.csv'

    if not os.path.exists(new_pred_file):
        print(f"INFO: {new_pred_file} not found (skipping new predictions)")
        return None

    new_df = pd.read_csv(new_pred_file, dtype={'PMID': str})

    # Format predictions
    new_df['Source'] = 'New PubMed Predictions'
    new_df['Has Mechanism'] = new_df['has_mechanism'].map({True: 'Yes', False: 'No'})
    new_df['Mechanism Probability'] = new_df['stage1_confidence']
    new_df['Autoregulatory Type'] = new_df['mechanism_type'].replace('none', 'non-autoregulatory')
    new_df['Type Confidence'] = new_df['stage2_confidence']

    # Keep other columns from new predictions
    cols = ['PMID', 'Title', 'Abstract', 'Journal', 'Authors', 'Year', 'Month',
            'Has Mechanism', 'Mechanism Probability', 'Source',
            'Autoregulatory Type', 'Type Confidence']

    return new_df[[col for col in cols if col in new_df.columns]]


def merge_with_metadata(df, autoreg_df):
    """Merge predictions with AutoregDB metadata."""
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
    autoreg_agg['PMID'] = autoreg_agg['PMID'].astype(str)

    # Merge
    df = df.merge(autoreg_agg, on='PMID', how='left')

    # Create Protein ID
    df['Protein ID'] = df.apply(
        lambda row: f"{row['AC'].split(', ')[0]}_{row['PMID']}" if pd.notna(row['AC']) else f"NA_{row['PMID']}",
        axis=1
    )

    return df


def main():
    """Create final comprehensive Shiny app dataset."""

    print("=" * 80)
    print("CREATE FINAL SHINY APP DATASET")
    print("=" * 80)
    print()

    # Load all components
    print("Step 1: Loading labeled papers (ground truth)...")
    labeled_df = load_labeled_papers()
    print(f"   ✓ Loaded {len(labeled_df):,} labeled papers")
    print()

    print("Step 2: Loading unlabeled papers used in training...")
    training_neg_df = load_unlabeled_training_samples()
    if training_neg_df is not None:
        print(f"   ✓ Loaded {len(training_neg_df):,} training negatives")
    else:
        print("   ✗ Skipped (file not found)")
    print()

    print("Step 3: Loading predictions on unused unlabeled papers...")
    unused_pred_df = load_unused_predictions()
    if unused_pred_df is not None:
        print(f"   ✓ Loaded {len(unused_pred_df):,} predictions")
    else:
        print("   ✗ Skipped (file not found)")
    print()

    print("Step 4: Loading predictions on new 3M PubMed papers...")
    new_pred_df = load_new_predictions()
    if new_pred_df is not None:
        print(f"   ✓ Loaded {len(new_pred_df):,} new predictions")
    else:
        print("   ✗ Skipped (file not found)")
    print()

    # Combine all dataframes
    print("Step 5: Combining all datasets...")
    dfs_to_combine = [df for df in [labeled_df, training_neg_df, unused_pred_df] if df is not None]

    if not dfs_to_combine:
        print("ERROR: No data to combine!")
        return

    combined_df = pd.concat(dfs_to_combine, ignore_index=True)
    print(f"   ✓ Combined {len(combined_df):,} papers (old data)")

    # Add new predictions if available
    if new_pred_df is not None:
        # New predictions already have Title, Abstract, etc., so handle differently
        # For now, just combine and fill missing columns
        combined_df = pd.concat([combined_df, new_pred_df], ignore_index=True)
        print(f"   ✓ Added {len(new_pred_df):,} new predictions")
        print(f"   ✓ Total: {len(combined_df):,} papers")

    print()

    # Load AutoregDB for metadata
    print("Step 6: Loading AutoregDB metadata...")
    autoreg = pyreadr.read_r('data/raw/autoregulatoryDB.rds')
    autoreg_df = list(autoreg.values())[0]
    print(f"   ✓ Loaded AutoregDB ({len(autoreg_df):,} entries)")
    print()

    # Merge with metadata (only for old data that doesn't have Protein ID yet)
    print("Step 7: Merging with metadata...")
    combined_df = merge_with_metadata(combined_df, autoreg_df)
    print("   ✓ Metadata merged")
    print()

    # Ensure all required columns exist
    required_cols = ['Protein ID', 'AC', 'OS', 'PMID',
                     'Has Mechanism', 'Mechanism Probability', 'Source',
                     'Autoregulatory Type', 'Type Confidence']

    for col in required_cols:
        if col not in combined_df.columns:
            combined_df[col] = None

    # Save final dataset
    output_file = 'shiny_app/data/predictions_for_app.csv'
    os.makedirs('shiny_app/data', exist_ok=True)

    print("Step 8: Saving final dataset...")
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
