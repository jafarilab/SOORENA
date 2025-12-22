#!/usr/bin/env python3
"""
COMPREHENSIVE REBUILD OF FINAL SHINY APP DATASET

This script properly rebuilds predictions_for_app.csv from scratch by:
1. Loading A, B, C, D separately
2. Merging each with correct PubMed data for Title/Abstract
3. Preserving all predictions and enrichment data
4. Applying correct Source labels
5. Removing only invalid rows from D

Data Sources:
A: Labeled AutoregDB (train+val+test) → 1,332 rows → Source: "UniProt"
B: Training Negatives → 2,664 rows → Source: "UniProt"
C: Predictions on Unused → 250,216 rows → Source: "Non-UniProt"
D: New 3M Predictions → 3,332,826 rows → Source: "Non-UniProt"

TOTAL: ~3.59M rows
"""
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

import pandas as pd
import pyreadr
import os


def load_source_a():
    """A: Labeled AutoregDB (Ground Truth) - train + val + test."""
    print("="*80)
    print("LOADING SOURCE A: Labeled AutoregDB (Ground Truth)")
    print("="*80)

    train_df = pd.read_csv('data/processed/train.csv')
    val_df = pd.read_csv('data/processed/val.csv')
    test_df = pd.read_csv('data/processed/test.csv')

    # Combine all
    df = pd.concat([train_df, val_df, test_df], ignore_index=True)

    print(f"  ✓ Loaded {len(df):,} rows")
    print(f"  Columns: {df.columns.tolist()}")

    # Format for final dataset
    df['PMID'] = df['PMID'].astype(str)
    df['Source'] = 'UniProt'
    df['Has Mechanism'] = 'Yes'
    df['Mechanism Probability'] = 1.0

    # Map Terms to Autoregulatory Type
    def get_primary_type(terms):
        if pd.isna(terms) or terms == '':
            return 'non-autoregulatory'
        return terms.split(',')[0].strip()

    df['Autoregulatory Type'] = df['Terms'].apply(get_primary_type)
    df['Type Confidence'] = 1.0

    return df[['PMID', 'Source', 'Has Mechanism', 'Mechanism Probability',
               'Autoregulatory Type', 'Type Confidence']]


def load_source_b():
    """B: Training Negatives."""
    print("\n" + "="*80)
    print("LOADING SOURCE B: Training Negatives")
    print("="*80)

    df = pd.read_csv('data/processed/stage1_unlabeled_negatives.csv')

    print(f"  ✓ Loaded {len(df):,} rows")
    print(f"  Columns: {df.columns.tolist()}")

    # Format for final dataset
    df['PMID'] = df['PMID'].astype(str)
    df['Source'] = 'UniProt'
    df['Has Mechanism'] = 'No'
    df['Mechanism Probability'] = 0.0
    df['Autoregulatory Type'] = 'non-autoregulatory'
    df['Type Confidence'] = 0.0

    return df[['PMID', 'Source', 'Has Mechanism', 'Mechanism Probability',
               'Autoregulatory Type', 'Type Confidence']]


def load_source_c():
    """C: Predictions on Unused Papers."""
    print("\n" + "="*80)
    print("LOADING SOURCE C: Predictions on Unused Papers")
    print("="*80)

    df = pd.read_csv('results/unused_unlabeled_predictions.csv')

    print(f"  ✓ Loaded {len(df):,} rows")
    print(f"  Columns: {df.columns.tolist()}")

    # Format for final dataset
    df['PMID'] = df['PMID'].astype(str)
    df['Source'] = 'Non-UniProt'
    df['Has Mechanism'] = df['has_mechanism'].map({True: 'Yes', False: 'No'})
    df['Mechanism Probability'] = df['stage1_confidence']
    df['Autoregulatory Type'] = df['mechanism_type'].replace('none', 'non-autoregulatory')
    df['Type Confidence'] = df['stage2_confidence']

    return df[['PMID', 'Source', 'Has Mechanism', 'Mechanism Probability',
               'Autoregulatory Type', 'Type Confidence']]


def load_source_d():
    """D: New 3M PubMed Predictions (already has Title/Abstract)."""
    print("\n" + "="*80)
    print("LOADING SOURCE D: New 3M PubMed Predictions")
    print("="*80)

    df = pd.read_csv('results/new_predictions.csv', dtype={'PMID': str})

    print(f"  ✓ Loaded {len(df):,} rows")
    print(f"  Columns: {df.columns.tolist()}")

    # Format for final dataset
    df['Source'] = 'Non-UniProt'
    df['Has Mechanism'] = df['has_mechanism'].map({True: 'Yes', False: 'No'})
    df['Mechanism Probability'] = df['stage1_confidence']
    df['Autoregulatory Type'] = df['mechanism_type'].replace('none', 'non-autoregulatory')
    df['Type Confidence'] = df['stage2_confidence']

    # Remove rows with BOTH Title AND Abstract missing
    missing_both = ((df['Title'].isna() | (df['Title'] == '')) &
                   (df['Abstract'].isna() | (df['Abstract'] == '')))

    print(f"  ✗ Removing {missing_both.sum():,} rows with missing Title AND Abstract")
    df = df[~missing_both].copy()
    print(f"  ✓ Kept {len(df):,} rows")

    cols_to_keep = ['PMID', 'Source', 'Has Mechanism', 'Mechanism Probability',
                    'Autoregulatory Type', 'Type Confidence',
                    'Title', 'Abstract', 'Journal', 'Authors', 'Year', 'Month']

    return df[[col for col in cols_to_keep if col in df.columns]]


def merge_with_pubmed(df, source_name):
    """Merge A, B, C with pubmed.rds for Title/Abstract."""
    print(f"\n  Merging {source_name} with pubmed.rds...")

    # Load raw PubMed data
    pubmed = pyreadr.read_r('data/raw/pubmed.rds')
    pubmed_df = list(pubmed.values())[0]
    pubmed_df['PMID'] = pubmed_df['PMID'].astype(str)

    # Merge
    original_cols = df.columns.tolist()
    merged_df = df.merge(
        pubmed_df[['PMID', 'Title', 'Abstract', 'Journal', 'Authors']],
        on='PMID',
        how='left'
    )

    # Check coverage
    has_title = merged_df['Title'].notna() & (merged_df['Title'] != '')
    has_abstract = merged_df['Abstract'].notna() & (merged_df['Abstract'] != '')

    print(f"    ✓ Title coverage: {has_title.sum():,}/{len(merged_df):,} ({has_title.sum()/len(merged_df)*100:.1f}%)")
    print(f"    ✓ Abstract coverage: {has_abstract.sum():,}/{len(merged_df):,} ({has_abstract.sum()/len(merged_df)*100:.1f}%)")

    # Reorder columns
    new_cols = original_cols + ['Title', 'Abstract', 'Journal', 'Authors']
    return merged_df[new_cols]


def merge_with_autoreg_metadata(df):
    """Merge with AutoregDB for AC, OS, Protein ID."""
    print("\n  Merging with AutoregDB metadata...")

    autoreg = pyreadr.read_r('data/raw/autoregulatoryDB.rds')
    autoreg_df = list(autoreg.values())[0]

    # Extract PMID
    autoreg_df['PMID'] = pd.to_numeric(
        autoreg_df['RX'].str.extract(r'PubMed=(\d+)')[0],
        errors='coerce'
    )

    # Aggregate by PMID
    autoreg_agg = autoreg_df.groupby('PMID', as_index=False).agg({
        'AC': lambda x: ', '.join(x.dropna().astype(str).unique()),
        'OS': 'first'
    })
    autoreg_agg['PMID'] = autoreg_agg['PMID'].astype('Int64').astype(str)

    # Merge
    df = df.merge(autoreg_agg, on='PMID', how='left')

    # Create Protein ID
    df['Protein ID'] = df.apply(
        lambda row: f"{row['AC'].split(', ')[0]}_{row['PMID']}" if pd.notna(row['AC']) else f"NA_{row['PMID']}",
        axis=1
    )

    # Check coverage
    has_ac = df['AC'].notna() & (df['AC'] != '')
    print(f"    ✓ AC coverage: {has_ac.sum():,}/{len(df):,} ({has_ac.sum()/len(df)*100:.1f}%)")

    return df


def merge_enrichment_data(df):
    """Merge with enrichment data (Protein Name, Gene Name)."""
    print("\n" + "="*80)
    print("MERGING ENRICHMENT DATA")
    print("="*80)

    # Load enriched file
    enriched = pd.read_csv('shiny_app/data/predictions_for_app_enriched.csv',
                          dtype={'PMID': str},
                          usecols=['PMID', 'Protein Name', 'Gene Name'],
                          low_memory=False)

    print(f"  ✓ Loaded enrichment data for {len(enriched):,} rows")
    print(f"  Unique PMIDs: {enriched['PMID'].nunique():,}")

    # Deduplicate - keep first occurrence (prioritize rows with data)
    # Sort so rows with Protein Name come first
    enriched = enriched.sort_values(
        by=['PMID', 'Protein Name', 'Gene Name'],
        na_position='last'
    )
    enriched = enriched.drop_duplicates(subset=['PMID'], keep='first')

    print(f"  ✓ After deduplication: {len(enriched):,} rows")

    # Count enriched rows
    has_protein = enriched['Protein Name'].notna() & (enriched['Protein Name'] != '')
    has_gene = enriched['Gene Name'].notna() & (enriched['Gene Name'] != '')
    print(f"    - Protein Name: {has_protein.sum():,} rows")
    print(f"    - Gene Name: {has_gene.sum():,} rows")

    # Merge
    df = df.merge(enriched, on='PMID', how='left')

    # Check coverage after merge
    has_protein_after = df['Protein Name'].notna() & (df['Protein Name'] != '')
    has_gene_after = df['Gene Name'].notna() & (df['Gene Name'] != '')

    print(f"\n  After merge:")
    print(f"    ✓ Protein Name: {has_protein_after.sum():,} rows")
    print(f"    ✓ Gene Name: {has_gene_after.sum():,} rows")

    return df


def main():
    """Main execution."""
    print("="*80)
    print("COMPREHENSIVE REBUILD OF FINAL DATASET")
    print("="*80)
    print()

    # Load all 4 sources
    df_a = load_source_a()
    df_b = load_source_b()
    df_c = load_source_c()
    df_d = load_source_d()  # Already has Title/Abstract

    # Merge A, B, C with PubMed data
    print("\n" + "="*80)
    print("MERGING WITH PUBMED DATA")
    print("="*80)

    df_a = merge_with_pubmed(df_a, "Source A")
    df_b = merge_with_pubmed(df_b, "Source B")
    df_c = merge_with_pubmed(df_c, "Source C")

    # Combine A+B+C (old data - needs AutoregDB metadata)
    print("\n" + "="*80)
    print("COMBINING A, B, C")
    print("="*80)
    old_data = pd.concat([df_a, df_b, df_c], ignore_index=True)
    print(f"  ✓ Combined {len(old_data):,} rows")

    # Merge A+B+C with AutoregDB metadata
    old_data = merge_with_autoreg_metadata(old_data)

    # D already has all metadata except AC/OS/Protein ID
    # Add empty AC, OS, Protein ID columns to D
    print("\n  Adding metadata columns to Source D...")
    df_d['AC'] = None
    df_d['OS'] = None
    df_d['Protein ID'] = df_d['PMID'].apply(lambda x: f"NA_{x}")

    # Ensure both have same columns before combining
    all_cols = list(set(old_data.columns) | set(df_d.columns))
    for col in all_cols:
        if col not in old_data.columns:
            old_data[col] = None
        if col not in df_d.columns:
            df_d[col] = None

    # Combine all 4 sources
    print("\n" + "="*80)
    print("COMBINING ALL SOURCES (A + B + C + D)")
    print("="*80)
    final_df = pd.concat([old_data, df_d], ignore_index=True)
    print(f"  ✓ Total rows before dedup: {len(final_df):,}")

    # Remove duplicates - keep UniProt over Non-UniProt
    # (Some PMIDs appear in both old 262K and new 3M datasets)
    print("\n  Removing duplicate PMIDs (keeping UniProt over Non-UniProt)...")
    final_df = final_df.sort_values(by=['PMID', 'Source'])  # 'Non-UniProt' comes before 'UniProt' alphabetically
    final_df = final_df.drop_duplicates(subset=['PMID'], keep='last')  # Keep UniProt (last alphabetically)
    print(f"  ✓ Total rows after dedup: {len(final_df):,}")

    # Merge with enrichment data
    final_df = merge_enrichment_data(final_df)

    # Summary
    print("\n" + "="*80)
    print("FINAL DATASET SUMMARY")
    print("="*80)
    print(f"Total rows: {len(final_df):,}")
    print()

    print("By Source:")
    print(final_df['Source'].value_counts().to_string())
    print()

    print("By Has Mechanism:")
    print(final_df['Has Mechanism'].value_counts().to_string())
    print()

    print("Missing Data Check:")
    for source in sorted(final_df['Source'].unique()):
        source_df = final_df[final_df['Source'] == source]
        missing_title = (source_df['Title'].isna() | (source_df['Title'] == '')).sum()
        missing_abstract = (source_df['Abstract'].isna() | (source_df['Abstract'] == '')).sum()
        missing_both = ((source_df['Title'].isna() | (source_df['Title'] == '')) &
                       (source_df['Abstract'].isna() | (source_df['Abstract'] == ''))).sum()

        print(f"  {source}:")
        print(f"    Total: {len(source_df):,}")
        print(f"    Missing Title: {missing_title:,}")
        print(f"    Missing Abstract: {missing_abstract:,}")
        print(f"    Missing BOTH: {missing_both:,}")

    print()
    print("Enrichment Coverage:")
    has_protein = (final_df['Protein Name'].notna() & (final_df['Protein Name'] != '')).sum()
    has_gene = (final_df['Gene Name'].notna() & (final_df['Gene Name'] != '')).sum()
    has_ac = (final_df['AC'].notna() & (final_df['AC'] != '')).sum()
    print(f"  Rows with AC: {has_ac:,}")
    print(f"  Rows with Protein Name: {has_protein:,}")
    print(f"  Rows with Gene Name: {has_gene:,}")

    # Save
    print("\n" + "="*80)
    print("SAVING FINAL DATASET")
    print("="*80)

    output_file = 'shiny_app/data/predictions_for_app.csv'
    backup_file = 'shiny_app/data/predictions_for_app_old.csv'

    # Backup existing file
    if os.path.exists(output_file):
        print(f"  ✓ Backing up old file to: {backup_file}")
        os.rename(output_file, backup_file)

    # Save new file
    final_df.to_csv(output_file, index=False)
    print(f"  ✓ Saved to: {output_file}")

    print("\n" + "="*80)
    print("✓ REBUILD COMPLETE!")
    print("="*80)
    print("\nNext step:")
    print("  Create SQLite database: python scripts/python/data_processing/create_sqlite_db.py")
    print("="*80)


if __name__ == "__main__":
    main()
