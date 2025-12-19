#!/usr/bin/env python3
"""
Enrich CSV with protein names and gene names from UniProt API.

Usage:
    python enrich_protein_names.py --input shiny_app/data/predictions_for_app.csv \
                                   --output shiny_app/data/predictions_for_app_enriched.csv \
                                   --cache data/protein_cache.json
"""

import pandas as pd
import requests
import json
import time
import argparse
import os
from pathlib import Path
from tqdm import tqdm
from datetime import datetime

# UniProt REST API configuration
UNIPROT_API_BASE = "https://rest.uniprot.org/uniprotkb"
RATE_LIMIT_SECONDS = 1.0  # UniProt recommends 1 request/second without auth
REQUEST_TIMEOUT = 10  # seconds
MAX_RETRIES = 3


def load_cache(cache_path):
    """Load existing protein info cache from JSON."""
    if os.path.exists(cache_path):
        with open(cache_path, 'r') as f:
            cache = json.load(f)
        print(f"Loaded cache with {len(cache)} entries from {cache_path}")
        return cache
    else:
        print(f"No cache found at {cache_path}, starting fresh")
        return {}


def save_cache(cache, cache_path):
    """Save protein info cache to JSON."""
    os.makedirs(os.path.dirname(cache_path) or '.', exist_ok=True)
    with open(cache_path, 'w') as f:
        json.dump(cache, f, indent=2)
    print(f"Saved cache with {len(cache)} entries to {cache_path}")


def fetch_uniprot_info(accession, cache, log_file=None):
    """
    Fetch protein name and gene name from UniProt API.

    Args:
        accession: UniProt accession code (e.g., "P12345")
        cache: Dictionary cache of previous lookups
        log_file: File handle for logging errors

    Returns:
        Tuple of (protein_name, gene_name)
    """
    # Clean accession code
    accession = accession.strip()

    # Check cache first
    if accession in cache:
        return cache[accession]['protein_name'], cache[accession]['gene_name']

    # Make API request with retries
    for attempt in range(MAX_RETRIES):
        try:
            url = f"{UNIPROT_API_BASE}/{accession}.json"
            response = requests.get(url, timeout=REQUEST_TIMEOUT)

            if response.status_code == 200:
                data = response.json()

                # Extract protein name (recommended name preferred)
                protein_name = accession  # fallback to AC code
                if 'proteinDescription' in data:
                    desc = data['proteinDescription']
                    if 'recommendedName' in desc:
                        protein_name = desc['recommendedName']['fullName']['value']
                    elif 'submittedName' in desc and len(desc['submittedName']) > 0:
                        protein_name = desc['submittedName'][0]['fullName']['value']

                # Extract gene name (primary gene name)
                gene_name = ''
                if 'genes' in data and len(data['genes']) > 0:
                    if 'geneName' in data['genes'][0]:
                        gene_name = data['genes'][0]['geneName']['value']

                # Cache result
                cache[accession] = {
                    'protein_name': protein_name,
                    'gene_name': gene_name,
                    'fetched_at': datetime.now().isoformat()
                }

                # Rate limiting
                time.sleep(RATE_LIMIT_SECONDS)

                return protein_name, gene_name

            elif response.status_code == 404:
                # Protein not found - use AC as fallback
                cache[accession] = {
                    'protein_name': accession,
                    'gene_name': '',
                    'error': 'not_found',
                    'fetched_at': datetime.now().isoformat()
                }
                if log_file:
                    log_file.write(f"{accession},not_found,Protein not found in UniProt\n")
                return accession, ''

            elif response.status_code == 429:
                # Rate limited - exponential backoff
                wait_time = (2 ** attempt) * RATE_LIMIT_SECONDS
                print(f"\nRate limited, waiting {wait_time}s before retry...")
                time.sleep(wait_time)
                continue

            else:
                # Other error
                if log_file:
                    log_file.write(f"{accession},http_error,Status code {response.status_code}\n")
                if attempt == MAX_RETRIES - 1:
                    cache[accession] = {
                        'protein_name': accession,
                        'gene_name': '',
                        'error': f'http_{response.status_code}',
                        'fetched_at': datetime.now().isoformat()
                    }
                    return accession, ''
                time.sleep(2 ** attempt)

        except requests.exceptions.Timeout:
            if log_file:
                log_file.write(f"{accession},timeout,Request timeout\n")
            if attempt == MAX_RETRIES - 1:
                cache[accession] = {
                    'protein_name': accession,
                    'gene_name': '',
                    'error': 'timeout',
                    'fetched_at': datetime.now().isoformat()
                }
                return accession, ''
            time.sleep(2 ** attempt)

        except Exception as e:
            if log_file:
                log_file.write(f"{accession},exception,{str(e)}\n")
            if attempt == MAX_RETRIES - 1:
                cache[accession] = {
                    'protein_name': accession,
                    'gene_name': '',
                    'error': str(e),
                    'fetched_at': datetime.now().isoformat()
                }
                return accession, ''
            time.sleep(2 ** attempt)

    # All retries failed
    return accession, ''


def process_ac_column(ac_str, cache, log_file=None):
    """
    Process AC column which may contain multiple comma-separated accessions.

    Args:
        ac_str: AC column value (e.g., "P12345" or "P12345, Q67890")
        cache: Dictionary cache
        log_file: File handle for logging

    Returns:
        Tuple of (protein_names, gene_names) with semicolon separators
    """
    # Handle NA or empty cases
    if pd.isna(ac_str) or str(ac_str).strip() == '' or str(ac_str).strip().upper().startswith('NA'):
        return '', ''

    # Split by comma+space (UniProt convention)
    accessions = [ac.strip() for ac in str(ac_str).split(',')]

    # Fetch info for each accession
    protein_names = []
    gene_names = []

    for accession in accessions:
        if accession:  # Skip empty strings
            p_name, g_name = fetch_uniprot_info(accession, cache, log_file)
            protein_names.append(p_name)
            if g_name:  # Only add non-empty gene names
                gene_names.append(g_name)

    # Join with semicolon separator
    protein_names_str = '; '.join(protein_names) if protein_names else ''
    gene_names_str = '; '.join(gene_names) if gene_names else ''

    return protein_names_str, gene_names_str


def enrich_csv(input_csv, output_csv, cache_path, checkpoint_interval=1000):
    """
    Main function to enrich CSV with protein names and gene names.

    Args:
        input_csv: Path to input CSV
        output_csv: Path to output enriched CSV
        cache_path: Path to cache JSON file
        checkpoint_interval: Save checkpoint every N rows
    """
    print("=" * 80)
    print("UniProt Protein Name Enrichment")
    print("=" * 80)
    print()

    # Load cache
    cache = load_cache(cache_path)

    # Setup logging
    log_path = output_csv.replace('.csv', '_errors.log')
    log_file = open(log_path, 'w')
    log_file.write("accession,error_type,message\n")

    # Check for existing checkpoint
    checkpoint_path = output_csv.replace('.csv', '_checkpoint.csv')
    if os.path.exists(checkpoint_path):
        print(f"Found checkpoint file: {checkpoint_path}")
        print("Resuming from checkpoint...")
        existing_df = pd.read_csv(checkpoint_path)
        processed_pmids = set(existing_df['PMID'].astype(str))
        print(f"Already processed: {len(processed_pmids):,} rows")
        print()
    else:
        existing_df = None
        processed_pmids = set()

    # Load input CSV
    print(f"Loading input CSV: {input_csv}")
    df = pd.read_csv(input_csv, dtype={'PMID': str})
    print(f"Loaded {len(df):,} rows")
    print()

    # Filter to unprocessed rows
    if processed_pmids:
        df = df[~df['PMID'].astype(str).isin(processed_pmids)]
        print(f"Remaining to process: {len(df):,} rows")
        print()

    # Process each row
    print("Fetching protein information from UniProt...")
    print("This may take several hours depending on dataset size")
    print(f"Rate limit: {RATE_LIMIT_SECONDS} seconds per request")
    print()

    protein_names = []
    gene_names = []

    for idx, row in tqdm(df.iterrows(), total=len(df), desc="Enriching"):
        p_name, g_name = process_ac_column(row['AC'], cache, log_file)
        protein_names.append(p_name)
        gene_names.append(g_name)

        # Save checkpoint periodically
        if (len(protein_names) % checkpoint_interval == 0):
            df_partial = df.iloc[:len(protein_names)].copy()
            df_partial.insert(2, 'Protein Name', protein_names)
            df_partial.insert(3, 'Gene Name', gene_names)

            if existing_df is not None:
                df_combined = pd.concat([existing_df, df_partial], ignore_index=True)
            else:
                df_combined = df_partial

            df_combined.to_csv(checkpoint_path, index=False)
            save_cache(cache, cache_path)
            print(f"\nCheckpoint saved at {len(protein_names) + len(processed_pmids):,} rows")

    # Add new columns to dataframe
    df.insert(2, 'Protein Name', protein_names)
    df.insert(3, 'Gene Name', gene_names)

    # Combine with existing processed rows if resuming
    if existing_df is not None:
        df = pd.concat([existing_df, df], ignore_index=True)

    # Save final output
    print()
    print("Saving enriched CSV...")
    df.to_csv(output_csv, index=False)
    print(f"Saved to: {output_csv}")

    # Save final cache
    save_cache(cache, cache_path)

    # Clean up
    log_file.close()
    if os.path.exists(checkpoint_path):
        os.remove(checkpoint_path)
        print(f"Removed checkpoint file")

    # Print summary
    print()
    print("=" * 80)
    print("ENRICHMENT COMPLETE")
    print("=" * 80)
    print(f"\nTotal rows processed: {len(df):,}")
    print(f"Unique proteins cached: {len(cache):,}")
    print(f"Error log: {log_path}")
    print()


def main():
    parser = argparse.ArgumentParser(
        description='Enrich CSV with protein names from UniProt API'
    )
    parser.add_argument('--input', type=str, required=True,
                       help='Path to input CSV file')
    parser.add_argument('--output', type=str, required=True,
                       help='Path to output enriched CSV file')
    parser.add_argument('--cache', type=str, default='data/protein_cache.json',
                       help='Path to cache JSON file (default: data/protein_cache.json)')
    parser.add_argument('--checkpoint-interval', type=int, default=1000,
                       help='Save checkpoint every N rows (default: 1000)')

    args = parser.parse_args()

    enrich_csv(args.input, args.output, args.cache, args.checkpoint_interval)


if __name__ == "__main__":
    main()
