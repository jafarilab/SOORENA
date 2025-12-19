import sys
from pathlib import Path

# Add repository root to Python path (4 levels up from scripts/python/prediction/)
REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

import pandas as pd
import os
import re
import argparse
from tqdm import tqdm
from scripts.python.prediction.predict import MechanismPredictor
from scripts.python.data_processing.prepare_data import clean_text

def parse_publication_date(date_str):
    """
    Parse PublicationDate into Year and Month.
    Handles formats like: '1950-Feb', '1961-Jan', '1966-Apr-10', etc.

    Args:
        date_str: Publication date string

    Returns:
        Tuple of (year, month) as strings
    """
    if pd.isna(date_str) or str(date_str).strip() == '':
        return 'Unknown', 'Unknown'

    date_str = str(date_str).strip()

    # Extract year (first 4 consecutive digits)
    year_match = re.search(r'(\d{4})', date_str)
    year = year_match.group(1) if year_match else 'Unknown'

    # Month name mapping (handle various formats)
    month_names = {
        'jan': 'Jan', 'january': 'Jan',
        'feb': 'Feb', 'february': 'Feb',
        'mar': 'Mar', 'march': 'Mar',
        'apr': 'Apr', 'april': 'Apr',
        'may': 'May',
        'jun': 'Jun', 'june': 'Jun',
        'jul': 'Jul', 'july': 'Jul',
        'aug': 'Aug', 'august': 'Aug',
        'sep': 'Sep', 'sept': 'Sep', 'september': 'Sep',
        'oct': 'Oct', 'october': 'Oct',
        'nov': 'Nov', 'november': 'Nov',
        'dec': 'Dec', 'december': 'Dec'
    }

    # Try to extract month
    month = 'Unknown'
    date_lower = date_str.lower()
    for month_pattern, month_abbr in month_names.items():
        if month_pattern in date_lower:
            month = month_abbr
            break

    return year, month


def main():
    """Predict mechanism types for new PubMed data."""

    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Run predictions on new PubMed data')
    parser.add_argument('--input', type=str, required=True,
                       help='Path to input TSV file')
    parser.add_argument('--output', type=str, default='results/new_predictions.csv',
                       help='Path to output CSV file')
    parser.add_argument('--checkpoint-interval', type=int, default=10000,
                       help='Save checkpoint every N predictions')
    parser.add_argument('--test-mode', action='store_true',
                       help='Test mode: only process first 100 rows')

    args = parser.parse_args()

    print("=" * 80)
    print("SOORENA Prediction Pipeline")
    print("=" * 80)
    print(f"\nInput file: {args.input}")
    print(f"Output file: {args.output}")
    print(f"Checkpoint interval: {args.checkpoint_interval:,} predictions")
    if args.test_mode:
        print("\n  TEST MODE: Processing only first 100 rows")
    print()

    # Create output directory
    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    checkpoint_file = args.output.replace('.csv', '_checkpoint.csv')

    # Load data
    print("Loading data...")
    try:
        df = pd.read_csv(args.input, sep='\t', dtype={'PMID': str})
    except Exception as e:
        print(f" Error loading data: {e}")
        print("\nTrying with error handling (on_bad_lines='skip')...")
        try:
            df = pd.read_csv(args.input, sep='\t', dtype={'PMID': str}, on_bad_lines='skip')
        except Exception as e2:
            print(f" Still failing: {e2}")
            print("\nTrying with quoting and error handling...")
            df = pd.read_csv(
                args.input,
                sep='\t',
                dtype={'PMID': str},
                on_bad_lines='skip',
                encoding='latin-1',
                quoting=3  # QUOTE_NONE
            )

    print(f" Loaded {len(df):,} papers")

    # Test mode: only first 100 rows
    if args.test_mode:
        df = df.head(100)
        print(f" Test mode: Processing {len(df):,} papers\n")

    # Check for existing checkpoint
    if os.path.exists(checkpoint_file):
        print(f"\n Found checkpoint file: {checkpoint_file}")
        existing_df = pd.read_csv(checkpoint_file, dtype={'PMID': str})
        already_predicted = set(existing_df['PMID'].astype(str))
        df = df[~df['PMID'].astype(str).isin(already_predicted)]
        print(f"  Already predicted: {len(already_predicted):,}")
        print(f"  Remaining: {len(df):,}\n")
        results = existing_df.to_dict('records')
    else:
        results = []
        print()

    # Initialize predictor
    print("Loading models...")
    predictor = MechanismPredictor()
    print()

    # Process each paper
    print("Starting predictions...")
    print("-" * 80)

    for idx, row in tqdm(df.iterrows(), total=len(df), desc="Predicting"):
        # Parse publication date
        year, month = parse_publication_date(row.get('PublicationDate', ''))

        # Clean and combine title + abstract
        title = str(row.get('Title', ''))
        abstract = str(row.get('Abstract', ''))
        text = f"{title}. {abstract}"
        cleaned_text = clean_text(text)

        # Make prediction
        pred = predictor.predict(title, abstract)

        # Store result
        results.append({
            'PMID': str(row['PMID']),
            'Title': title,
            'Abstract': abstract,
            'Journal': str(row.get('Journal', '')),
            'Authors': str(row.get('Authors', '')),
            'PublicationDate': str(row.get('PublicationDate', '')),
            'Year': year,
            'Month': month,
            'has_mechanism': pred['has_mechanism'],
            'stage1_confidence': pred['stage1_confidence'],
            'mechanism_type': pred['mechanism_type'] if pred['mechanism_type'] else 'none',
            'stage2_confidence': pred['stage2_confidence'] if pred['stage2_confidence'] else 0.0
        })

        # Save checkpoint
        if len(results) % args.checkpoint_interval == 0:
            pd.DataFrame(results).to_csv(checkpoint_file, index=False)
            print(f"\n Checkpoint saved at {len(results):,} predictions")

    print("\n" + "-" * 80)
    print("Saving final results...")

    # Save final predictions
    results_df = pd.DataFrame(results)
    results_df.to_csv(args.output, index=False)

    # Remove checkpoint
    if os.path.exists(checkpoint_file):
        os.remove(checkpoint_file)
        print(f" Removed checkpoint file")

    # Print summary
    print("\n" + "=" * 80)
    print("PREDICTION COMPLETE")
    print("=" * 80)
    print(f"\n Saved {len(results_df):,} predictions to: {args.output}")
    print(f"\nSummary:")
    print(f"  Papers with mechanisms: {results_df['has_mechanism'].sum():,}")
    print(f"  Papers without mechanisms: {(~results_df['has_mechanism']).sum():,}")

    # Show mechanism type breakdown
    if results_df['has_mechanism'].sum() > 0:
        print("\nMechanism type distribution:")
        mechanism_counts = results_df[results_df['has_mechanism']]['mechanism_type'].value_counts()
        for mech_type, count in mechanism_counts.items():
            print(f"  {mech_type}: {count:,}")

    # Show year distribution
    print("\nPublication years:")
    year_counts = results_df['Year'].value_counts().head(10)
    for year, count in year_counts.items():
        print(f"  {year}: {count:,}")

    print("\n" + "=" * 80)
    print("Next step: Run merge_all_predictions.py to combine with existing data")
    print("=" * 80)


if __name__ == "__main__":
    main()
