#!/usr/bin/env python3
"""
Integrate External Resources (OmniPath, SIGNOR, TRRUST) into SOORENA predictions.

This script adds curated self-loop/autoregulation data from external databases
as additional rows in the predictions dataset, marked with their respective sources.

Usage:
    python scripts/python/data_processing/integrate_external_resources.py \
        --input shiny_app/data/predictions.csv \
        --output shiny_app/data/predictions.csv \
        --others-dir others/

External Resources:
    - OmniPath: Protein-protein interactions with self-loops
    - SIGNOR: Signaling network with phosphorylation data
    - TRRUST: Transcriptional regulatory relationships
"""

import argparse
import pandas as pd
import re
import os
from pathlib import Path


def extract_pmids_from_references(ref_string):
    """Extract PMIDs from OmniPath references column (format: 'KEA:15964845;KEA:18691976')."""
    if pd.isna(ref_string):
        return []
    pmids = re.findall(r':(\d{7,8})', str(ref_string))
    return list(set(pmids))  # Remove duplicates


def map_mechanism_to_type(mechanism, effect=None, db_type=None):
    """Map external database mechanism to SOORENA autoregulatory type."""
    mechanism_lower = str(mechanism).lower() if pd.notna(mechanism) else ""
    effect_lower = str(effect).lower() if pd.notna(effect) else ""
    db_type_lower = str(db_type).lower() if pd.notna(db_type) else ""

    # Phosphorylation (exclude dephosphorylation)
    if 'phosphorylation' in mechanism_lower and 'dephosphorylation' not in mechanism_lower:
        return 'Autophosphorylation'

    # Dephosphorylation (NEW)
    if 'dephosphorylation' in mechanism_lower:
        return 'Autodephosphorylation'

    # Ubiquitination (includes polyubiquitination)
    if 'ubiquitination' in mechanism_lower:
        return 'Autoubiquitination'

    # Acetylation (NEW - exclude deacetylation)
    if 'acetylation' in mechanism_lower and 'deacetylation' not in mechanism_lower:
        return 'Autoacetylation'

    # Demethylation (NEW)
    if 'demethylation' in mechanism_lower:
        return 'Autodemethylation'

    # Cleavage/proteolysis
    if 'cleavage' in mechanism_lower or 'proteolysis' in mechanism_lower:
        return 'Autolysis'

    # Catalytic
    if 'catalytic' in mechanism_lower or 'catalysis' in mechanism_lower:
        return 'Autocatalytic'

    # Transcriptional regulation
    if 'transcriptional' in mechanism_lower or 'transcriptional' in db_type_lower:
        return 'Autoregulation'

    # Binding (protein-protein interaction)
    if 'binding' in mechanism_lower:
        return 'Autoregulation'

    # Post-translational modification (general)
    if 'post' in mechanism_lower and 'translational' in mechanism_lower:
        return 'Autoregulation'

    # Transcriptional regulation from effect (TRRUST)
    if 'repression' in effect_lower or 'activation' in effect_lower:
        return 'Autoregulation'

    # Inhibition
    if 'inhibition' in mechanism_lower or 'inhibit' in effect_lower:
        return 'Autoinhibition'

    # Default to general autoregulation
    return 'Autoregulation'


def map_effect_to_polarity(effect, is_stimulation=None, is_inhibition=None):
    """Map effect/stimulation/inhibition to polarity symbol."""
    effect_lower = str(effect).lower() if pd.notna(effect) else ""

    # Check explicit flags first
    if is_stimulation == 1 or is_stimulation == True:
        return '+'
    if is_inhibition == 1 or is_inhibition == True:
        return '–'

    # Check effect string
    if 'up-regulates' in effect_lower or 'activation' in effect_lower or 'stimulat' in effect_lower:
        return '+'
    if 'down-regulates' in effect_lower or 'repression' in effect_lower or 'inhibit' in effect_lower:
        return '–'

    return '±'  # Unknown/context-dependent


def process_omnipath(filepath):
    """Process OmniPath Excel file."""
    print(f"  Processing OmniPath: {filepath}")
    df = pd.read_excel(filepath)

    rows = []
    for _, row in df.iterrows():
        pmids = extract_pmids_from_references(row.get('references', ''))
        if not pmids:
            continue

        gene_symbol = row.get('source_genesymbol', '')
        db_type = row.get('type', '')  # post_translational, transcriptional, etc.
        mechanism_type = map_mechanism_to_type(None, None, db_type)
        polarity = map_effect_to_polarity(
            None,
            row.get('is_stimulation'),
            row.get('is_inhibition')
        )

        for pmid in pmids:
            rows.append({
                'PMID': pmid,
                'Source': 'OmniPath',
                'Gene_Name': gene_symbol,
                'Autoregulatory Type': mechanism_type,
                'Polarity': polarity,
                'Has Mechanism': 'Yes',
                'Mechanism Probability': 1.0,
                'Type Confidence': 1.0,
            })

    print(f"    Found {len(rows)} entries with PMIDs")
    return pd.DataFrame(rows)


def process_signor(filepath):
    """Process SIGNOR Excel file."""
    print(f"  Processing SIGNOR: {filepath}")
    df = pd.read_excel(filepath)

    rows = []
    for _, row in df.iterrows():
        pmid = row.get('PMID')
        if pd.isna(pmid):
            continue

        gene_symbol = row.get('ENTITYA', '')
        mechanism = row.get('MECHANISM', '')
        effect = row.get('EFFECT', '')
        organism = row.get('origin', '')

        mechanism_type = map_mechanism_to_type(mechanism, effect)
        polarity = map_effect_to_polarity(effect)

        rows.append({
            'PMID': str(int(pmid)) if isinstance(pmid, float) else str(pmid),
            'Source': 'SIGNOR',
            'Gene_Name': gene_symbol,
            'Autoregulatory Type': mechanism_type,
            'Polarity': polarity,
            'Has Mechanism': 'Yes',
            'Mechanism Probability': 1.0,
            'Type Confidence': 1.0,
            'OS': organism,
        })

    print(f"    Found {len(rows)} entries with PMIDs")
    return pd.DataFrame(rows)


def process_trrust(filepath):
    """Process TRRUST Excel file."""
    print(f"  Processing TRRUST: {filepath}")
    df = pd.read_excel(filepath)

    rows = []
    for _, row in df.iterrows():
        pmid = row.get('V4')  # PMID is in V4 column
        if pd.isna(pmid):
            continue

        gene_symbol = row.get('V1', '')  # Gene name
        effect = row.get('V3', '')  # Repression/Activation
        organism = row.get('origin', '')

        mechanism_type = 'Autoregulation'  # TRRUST is transcriptional regulation
        polarity = map_effect_to_polarity(effect)

        # Map organism
        os_map = {'mouse': 'Mus musculus (Mouse)', 'human': 'Homo sapiens (Human)'}
        organism_full = os_map.get(organism.lower(), organism) if organism else ''

        rows.append({
            'PMID': str(int(pmid)) if isinstance(pmid, float) else str(pmid),
            'Source': 'TRRUST',
            'Gene_Name': gene_symbol,
            'Autoregulatory Type': mechanism_type,
            'Polarity': polarity,
            'Has Mechanism': 'Yes',
            'Mechanism Probability': 1.0,
            'Type Confidence': 1.0,
            'OS': organism_full,
        })

    print(f"    Found {len(rows)} entries with PMIDs")
    return pd.DataFrame(rows)


def main():
    parser = argparse.ArgumentParser(
        description='Integrate external resources into SOORENA predictions'
    )
    parser.add_argument(
        '--input', '-i',
        required=True,
        help='Input predictions CSV file'
    )
    parser.add_argument(
        '--output', '-o',
        required=True,
        help='Output predictions CSV file (can be same as input)'
    )
    parser.add_argument(
        '--others-dir', '-d',
        default='others/',
        help='Directory containing external resource Excel files'
    )
    args = parser.parse_args()

    print("=" * 60)
    print("SOORENA: Integrating External Resources")
    print("=" * 60)

    # Load existing predictions
    print(f"\nLoading existing predictions: {args.input}")
    predictions_df = pd.read_csv(args.input, low_memory=False)
    original_count = len(predictions_df)
    print(f"  Existing rows: {original_count:,}")

    # Rename Non-UniProt → Predicted for clarity
    if 'Source' in predictions_df.columns:
        non_uniprot_count = (predictions_df['Source'] == 'Non-UniProt').sum()
        if non_uniprot_count > 0:
            predictions_df['Source'] = predictions_df['Source'].replace('Non-UniProt', 'Predicted')
            print(f"  Renamed 'Non-UniProt' → 'Predicted' ({non_uniprot_count:,} rows)")

    # Remove any existing external resource entries to prevent duplicates on re-run
    # Include all possible variations (with/without versions, case variations)
    external_sources = ['OmniPath', 'SIGNOR', 'SIGNOR 3.0', 'Signor', 'TRRUST', 'TRRUST v2', 'ORegAnno', 'HTRIdb']
    if 'Source' in predictions_df.columns:
        existing_external = predictions_df['Source'].isin(external_sources).sum()
        if existing_external > 0:
            predictions_df = predictions_df[~predictions_df['Source'].isin(external_sources)]
            print(f"  Removed {existing_external:,} existing external resource entries")
            print(f"  Rows after cleanup: {len(predictions_df):,}")

    # Get existing columns for alignment
    existing_columns = predictions_df.columns.tolist()

    # Read preprocessed external resources file (prefer enriched CSV if available)
    print("\nReading external resources...")
    others_dir = Path(args.others_dir)
    enriched_file = others_dir / 'OtherResources_enriched.csv'
    raw_file = others_dir / 'OtherResources.xlsx'

    if enriched_file.exists():
        print(f"  Using enriched file: {enriched_file}")
        external_df = pd.read_csv(enriched_file)
    elif raw_file.exists():
        print(f"  Using raw file: {raw_file}")
        print(f"  (Run enrich_external_resources.py to add Title, Abstract, etc.)")
        external_df = pd.read_excel(raw_file)
    else:
        print(f"  Error: No external resources file found")
        print(f"  Expected: {enriched_file} or {raw_file}")
        return

    print(f"  Loaded {len(external_df):,} external resource entries")

    # Map Term Probability to Polarity
    def map_term_probability_to_polarity(term_prob):
        if pd.isna(term_prob):
            return '±'
        term_lower = str(term_prob).lower()
        if 'activation' in term_lower or 'up-regulates' in term_lower or 'stimulat' in term_lower:
            return '+'
        elif 'repression' in term_lower or 'down-regulates' in term_lower or 'inhibit' in term_lower:
            return '–'
        else:
            return '±'

    # Clean up dashes and empty values in Autoregulatory Type
    def clean_autoregulatory_type(raw_type):
        if pd.isna(raw_type):
            return 'Unknown'
        raw_str = str(raw_type).strip()
        if raw_str == '-' or raw_str == '':
            return 'Unknown'
        return raw_str

    # Process and rename columns to match predictions format
    external_combined = pd.DataFrame({
        'PMID': external_df['PMID'].astype(str),
        'Source': external_df['Source'],
        'Gene_Name': external_df['Gene Name'],
        'Autoregulatory Type': external_df['Autoregulatory Type'].apply(clean_autoregulatory_type),
        'Polarity': external_df['Term Probability'].apply(map_term_probability_to_polarity),
        'Has Mechanism': 'Yes',
        'Mechanism Probability': float(1.0),
        'Type Confidence': float(1.0),
        'OS': external_df['OS'],
        # Add enriched metadata (if available in enriched CSV)
        'Title': external_df.get('Title', pd.Series([None] * len(external_df))),
        'Abstract': external_df.get('Abstract', pd.Series([None] * len(external_df))),
        'Journal': external_df.get('Journal', pd.Series([None] * len(external_df))),
        'Authors': external_df.get('Authors', pd.Series([None] * len(external_df))),
        'PublicationDate': external_df.get('Date Published', pd.Series([None] * len(external_df))),
        'Protein_Name': external_df.get('Protein Name', pd.Series([None] * len(external_df))),
        'Protein_ID': external_df.get('Protein ID', pd.Series([None] * len(external_df))),
        'UniProtKB_accessions': external_df.get('UniProtKB_accessions', pd.Series([None] * len(external_df))),
    })

    # Ensure float columns are explicitly float type
    external_combined['Mechanism Probability'] = external_combined['Mechanism Probability'].astype(float)
    external_combined['Type Confidence'] = external_combined['Type Confidence'].astype(float)

    # Clean up source names (TRRUST v2 → TRRUST, SIGNOR 3.0 → SIGNOR, etc.)
    external_combined['Source'] = external_combined['Source'].str.replace(r'\s+v?\d+(\.\d+)?', '', regex=True).str.strip()

    print(f"  Total external entries: {len(external_combined):,}")

    # Remove completely identical rows only (keep meaningful variants like different species/mechanisms)
    before_dedup = len(external_combined)
    external_combined = external_combined.drop_duplicates(keep='first')
    print(f"  After removing true duplicates: {len(external_combined):,} (removed {before_dedup - len(external_combined):,} identical copies)")

    # Check for PMIDs already in predictions
    existing_pmids = set(predictions_df['PMID'].astype(str))
    external_combined['PMID'] = external_combined['PMID'].astype(str)

    new_entries = external_combined[~external_combined['PMID'].isin(existing_pmids)]
    overlapping = external_combined[external_combined['PMID'].isin(existing_pmids)]

    print(f"\n  New PMIDs (not in predictions): {len(new_entries):,}")
    print(f"  Overlapping PMIDs (already in predictions): {len(overlapping):,}")

    # For overlapping PMIDs, we still add them as separate entries with external source
    # This allows users to see that both SOORENA predicted it AND external DBs confirm it

    # Add Polarity column to predictions if it doesn't exist
    # This allows external resources to contribute polarity values
    if 'Polarity' not in existing_columns:
        predictions_df['Polarity'] = None
        existing_columns = predictions_df.columns.tolist()

    # Align columns with existing predictions
    for col in existing_columns:
        if col not in external_combined.columns:
            external_combined[col] = None

    # Keep only columns that exist in original (plus any new ones we added)
    external_combined = external_combined[existing_columns]

    # Concatenate
    print("\nMerging with existing predictions...")
    merged_df = pd.concat([predictions_df, external_combined], ignore_index=True)

    # Regenerate AC (accession) IDs for all entries
    print("Regenerating AC IDs...")
    merged_df['PMID'] = merged_df['PMID'].astype(str)
    merged_df = merged_df.sort_values(['PMID', 'Source']).reset_index(drop=True)

    # Helper function to sanitize PMIDs for AC generation
    def sanitize_pmid(pmid):
        """Sanitize PMID for AC generation.

        Converts invalid/missing PMIDs to 'UNKNOWN' to ensure valid AC format.
        Examples: '-', 'nan', '', None → 'UNKNOWN'
        """
        pmid_str = str(pmid).strip()
        if not pmid_str or pmid_str == '-' or pmid_str == 'nan' or pmid_str == 'None':
            return 'UNKNOWN'
        return pmid_str

    # Generate new AC with source indicator
    ac_list = []
    pmid_counts = {}
    for _, row in merged_df.iterrows():
        pmid = sanitize_pmid(row['PMID'])  # Sanitize PMID
        source = row.get('Source', 'Unknown')

        # Source code: U=UniProt, P=Predicted, external sources use first letter
        source_codes = {
            'UniProt': 'U',
            'Predicted': 'P',
            'Non-UniProt': 'P',  # Legacy support
            'OmniPath': 'O',
            'SIGNOR': 'S',
            'TRRUST': 'T',
            'Signor': 'S',
            'ORegAnno': 'R',
            'HTRIdb': 'H'
        }
        source_code = source_codes.get(source, source[0] if source and source != 'Unknown' else 'X')

        pmid_counts[pmid] = pmid_counts.get(pmid, 0) + 1
        ac = f"SOORENA-{source_code}-{pmid}-{pmid_counts[pmid]}"
        ac_list.append(ac)

    merged_df['AC'] = ac_list

    # Summary by source
    print("\nFinal dataset summary:")
    print(f"  Total rows: {len(merged_df):,}")
    print("\n  By Source:")
    for source, count in merged_df['Source'].value_counts().items():
        print(f"    {source}: {count:,}")

    # Save
    print(f"\nSaving to: {args.output}")
    merged_df.to_csv(args.output, index=False)
    print(f"  Saved {len(merged_df):,} rows")

    print("\n" + "=" * 60)
    print("External resource integration complete!")
    print("=" * 60)


if __name__ == '__main__':
    main()