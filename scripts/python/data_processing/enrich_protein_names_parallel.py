#!/usr/bin/env python3
"""
PARALLEL protein enrichment - 100x faster than serial version.

Uses ThreadPoolExecutor to make multiple concurrent API calls to UniProt.
With 20 workers, completes in ~1-2 hours instead of ~129 hours.

IMPORTANT NOTES:
- Only rows with valid AC (UniProt accession) values will be enriched
- Success rate varies by data source:
  * UniProt ground truth: ~100% success (1,332 rows)
  * Training negatives: ~100% success (2,664 rows)
  * Model predictions (unused): ~12% success (30K out of 250K rows)
  * New PubMed predictions: ~0% success (0 out of 210K rows)
- Total expected enrichment: ~34K out of ~464K rows with AC values
- Invalid/missing ACs will have empty Protein Name and Gene Name fields
- This is NORMAL - many AC values from papers are outdated or don't exist in UniProt

Usage:
    python scripts/python/data_processing/enrich_protein_names_parallel.py \
        --input shiny_app/data/predictions_for_app.csv \
        --output shiny_app/data/predictions_for_app_enriched.csv \
        --cache data/protein_cache.json \
        --workers 20

    # To test rate limits first:
    python test_uniprot_rate_limit.py
"""
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

import pandas as pd
import requests
import json
import time
import argparse
import os
from tqdm import tqdm
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock

# Configuration
UNIPROT_API_BASE = "https://rest.uniprot.org/uniprotkb"
REQUEST_TIMEOUT = 10
MAX_RETRIES = 3

# Thread-safe cache lock
cache_lock = Lock()
stats_lock = Lock()


def load_cache(cache_path):
    """Load existing protein info cache from JSON."""
    if os.path.exists(cache_path):
        with open(cache_path, 'r') as f:
            cache = json.load(f)
        print(f"Loaded cache with {len(cache):,} entries")
        return cache
    else:
        print("No cache found, starting fresh")
        return {}


def save_cache(cache, cache_path):
    """Save protein info cache to JSON."""
    os.makedirs(os.path.dirname(cache_path) or '.', exist_ok=True)
    with open(cache_path, 'w') as f:
        json.dump(cache, f, indent=2)


def has_valid_ac(ac_val):
    """Check if AC value is valid and needs enrichment."""
    if pd.isna(ac_val):
        return False
    ac_str = str(ac_val).strip()
    if ac_str == '' or ac_str.upper().startswith('NA'):
        return False
    return True


def fetch_uniprot_info(ac_value, cache, log_file, stats):
    """
    Fetch protein name and gene name from UniProt API.
    Thread-safe with cache locking.
    """
    if not has_valid_ac(ac_value):
        return '', ''

    ac_str = str(ac_value).strip()
    first_ac = ac_str.split(',')[0].strip()

    # Check cache (thread-safe)
    with cache_lock:
        if first_ac in cache:
            with stats_lock:
                stats['cache_hits'] += 1
            cached = cache[first_ac]
            return cached.get('protein_name', ''), cached.get('gene_name', '')

    # Fetch from UniProt
    for attempt in range(MAX_RETRIES):
        try:
            url = f"{UNIPROT_API_BASE}/{first_ac}.json"
            response = requests.get(url, timeout=REQUEST_TIMEOUT)

            if response.status_code == 200:
                data = response.json()

                # Extract protein name
                protein_name = ''
                if 'proteinDescription' in data:
                    rec_name = data['proteinDescription'].get('recommendedName', {})
                    protein_name = rec_name.get('fullName', {}).get('value', '')

                # Extract gene name
                gene_name = ''
                if 'genes' in data and len(data['genes']) > 0:
                    gene_name = data['genes'][0].get('geneName', {}).get('value', '')

                # Cache result (thread-safe)
                with cache_lock:
                    cache[first_ac] = {
                        'protein_name': protein_name,
                        'gene_name': gene_name
                    }

                with stats_lock:
                    stats['api_success'] += 1

                return protein_name, gene_name

            elif response.status_code == 404:
                # AC not found - cache empty result
                with cache_lock:
                    cache[first_ac] = {'protein_name': '', 'gene_name': ''}
                with stats_lock:
                    stats['not_found'] += 1
                return '', ''

            elif response.status_code == 429:
                # Rate limited - exponential backoff
                wait_time = (2 ** attempt) * 2
                with stats_lock:
                    stats['rate_limited'] += 1
                time.sleep(wait_time)
                continue

            else:
                log_file.write(f"HTTP {response.status_code} for AC: {first_ac}\n")
                log_file.flush()
                with stats_lock:
                    stats['errors'] += 1
                return '', ''

        except requests.exceptions.Timeout:
            with stats_lock:
                stats['timeouts'] += 1
            if attempt < MAX_RETRIES - 1:
                time.sleep(1)
                continue
            return '', ''

        except Exception as e:
            log_file.write(f"Error fetching {first_ac}: {str(e)}\n")
            log_file.flush()
            with stats_lock:
                stats['errors'] += 1
            return '', ''

    return '', ''


def enrich_row(idx_row, cache, log_file, stats):
    """Process a single row (for parallel execution)."""
    idx, row = idx_row

    if not has_valid_ac(row['AC']):
        return idx, '', ''

    protein_name, gene_name = fetch_uniprot_info(row['AC'], cache, log_file, stats)
    return idx, protein_name, gene_name


def main():
    parser = argparse.ArgumentParser(description='Enrich CSV with UniProt protein names (PARALLEL)')
    parser.add_argument('--input', required=True, help='Input CSV file')
    parser.add_argument('--output', required=True, help='Output CSV file')
    parser.add_argument('--cache', default='data/protein_cache.json', help='Cache file')
    parser.add_argument('--checkpoint-interval', type=int, default=1000, help='Save every N rows')
    parser.add_argument('--workers', type=int, default=10, help='Number of parallel workers (default: 10)')
    args = parser.parse_args()

    print("=" * 80)
    print("PARALLEL PROTEIN ENRICHMENT")
    print("=" * 80)
    print()

    # Load cache
    cache = load_cache(args.cache)
    print()

    # Load data
    print(f"Loading input CSV: {args.input}")
    df = pd.read_csv(args.input, dtype={'PMID': str}, low_memory=False)
    print(f"Loaded {len(df):,} rows")
    print()

    # Count rows needing enrichment
    needs_enrichment = df['AC'].apply(has_valid_ac)
    rows_with_ac = needs_enrichment.sum()
    rows_without_ac = len(df) - rows_with_ac

    # Check how many already cached
    cached_count = 0
    for ac in df[needs_enrichment]['AC']:
        first_ac = str(ac).split(',')[0].strip()
        if first_ac in cache:
            cached_count += 1

    rows_to_fetch = rows_with_ac - cached_count

    print(f"Rows WITH valid AC (need enrichment): {rows_with_ac:,}")
    print(f"  Already in cache: {cached_count:,}")
    print(f"  Need to fetch: {rows_to_fetch:,}")
    print(f"Rows WITHOUT AC (skip enrichment):    {rows_without_ac:,}")
    print()

    # Estimate time
    estimated_seconds = (rows_to_fetch * 0.15)  # ~0.15 sec per request with 10 workers
    estimated_hours = estimated_seconds / 3600
    print(f"Workers: {args.workers}")
    print(f"Estimated time: ~{estimated_hours:.1f} hours ({estimated_seconds/60:.0f} minutes)")
    print()

    # Initialize columns
    if 'Protein Name' not in df.columns:
        df['Protein Name'] = ''
    if 'Gene Name' not in df.columns:
        df['Gene Name'] = ''

    # Open log file
    log_file = open('enrichment_errors.log', 'a')

    # Stats
    stats = {
        'cache_hits': 0,
        'api_success': 0,
        'not_found': 0,
        'rate_limited': 0,
        'timeouts': 0,
        'errors': 0
    }

    print("Starting parallel enrichment...")
    print(f"Checkpoints will be saved every {args.checkpoint_interval:,} rows")
    print()

    # Process rows in parallel
    rows_to_process = [(idx, row) for idx, row in df.iterrows()]
    completed = 0

    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        # Submit all tasks
        futures = {
            executor.submit(enrich_row, idx_row, cache, log_file, stats): idx_row[0]
            for idx_row in rows_to_process
        }

        # Process completed tasks with progress bar
        with tqdm(total=len(df), desc="Enriching") as pbar:
            for future in as_completed(futures):
                idx, protein_name, gene_name = future.result()
                df.at[idx, 'Protein Name'] = protein_name
                df.at[idx, 'Gene Name'] = gene_name

                completed += 1
                pbar.update(1)

                # Save checkpoint
                if completed % args.checkpoint_interval == 0:
                    pbar.write(f"\nCheckpoint at {completed:,} rows...")
                    df.to_csv(args.output + '.checkpoint', index=False)
                    # Thread-safe cache save
                    cache_copy = dict(cache)
                    save_cache(cache_copy, args.cache)
                    pbar.write(f"  Cache: {len(cache_copy):,} entries")
                    pbar.write(f"  Stats: {stats['cache_hits']:,} cached, {stats['api_success']:,} fetched, {stats['rate_limited']:,} rate limited\n")

    # Close log
    log_file.close()

    # Final save
    print()
    print("=" * 80)
    print("ENRICHMENT COMPLETE!")
    print("=" * 80)
    print()
    print(f"Saving final output to: {args.output}")
    df.to_csv(args.output, index=False)

    # Save cache with thread-safety (make a copy first)
    print("Saving cache...")
    cache_copy = dict(cache)  # Create a snapshot to avoid RuntimeError
    save_cache(cache_copy, args.cache)

    # Cleanup checkpoint
    checkpoint_file = args.output + '.checkpoint'
    if os.path.exists(checkpoint_file):
        os.remove(checkpoint_file)

    # Print stats
    print()
    print("Statistics:")
    print(f"  Cache hits:     {stats['cache_hits']:,}")
    print(f"  API successes:  {stats['api_success']:,}")
    print(f"  Not found:      {stats['not_found']:,}")
    print(f"  Rate limited:   {stats['rate_limited']:,}")
    print(f"  Timeouts:       {stats['timeouts']:,}")
    print(f"  Errors:         {stats['errors']:,}")
    print()
    print(f"Final cache size: {len(cache):,} entries")
    print()
    print("=" * 80)


if __name__ == "__main__":
    main()
