#!/usr/bin/env python3
"""
Enrich External Resources (OtherResources.xlsx) with metadata.

This script enriches the external resources dataset with:
- Title, Abstract (from PubTator)
- Journal, Authors, Date Published (from PubMed E-utilities)
- Protein Name, Protein ID (from UniProt, queried by Gene Name)

Usage:
    python scripts/python/data_processing/enrich_external_resources.py \
        --input others/OtherResources.xlsx \
        --output others/OtherResources_enriched.csv

The enriched file is then used by integrate_external_resources.py instead of the raw file.
"""

import argparse
import sys
import time
import sqlite3
from pathlib import Path

import pandas as pd

# Add repository root to Python path
REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

from pubtator_enrich import (  # noqa: E402
    fetch_pubtator,
    fetch_pubmed_metadata,
    fetch_uniprot_details,
    ensure_cache_db,
    get_cached_pubmed_metadata,
    store_pubmed_metadata,
    get_cached_uniprot_details,
    store_uniprot_details,
    http_get_json,
)

import urllib.parse


def fetch_title_abstract_from_pubtator(pmids, batch_size=50, sleep=0.4):
    """Fetch Title and Abstract from PubTator for given PMIDs.

    Returns dict keyed by PMID with keys: Title, Abstract
    """
    results = {}

    for i in range(0, len(pmids), batch_size):
        batch = pmids[i:i + batch_size]

        try:
            docs = fetch_pubtator(batch, sleep=sleep)
        except Exception as e:
            # If batch fails, try smaller batches or individual PMIDs
            print(f"    Warning: Batch failed ({e}), trying individual PMIDs...")
            for pmid in batch:
                try:
                    docs = fetch_pubtator([pmid], sleep=sleep)
                    for doc in docs:
                        pmid_doc = str(doc.get("id", "")).strip()
                        if not pmid_doc:
                            continue

                        title = ""
                        abstract = ""

                        for passage in doc.get("passages", []):
                            passage_type = passage.get("infons", {}).get("type", "")
                            text = passage.get("text", "").strip()

                            if passage_type == "title":
                                title = text
                            elif passage_type == "abstract":
                                abstract = text

                        results[pmid_doc] = {
                            "Title": title,
                            "Abstract": abstract
                        }
                except Exception as e2:
                    print(f"      Skipping PMID {pmid}: {e2}")
                    continue
            continue

        for doc in docs:
            pmid = str(doc.get("id", "")).strip()
            if not pmid:
                continue

            title = ""
            abstract = ""

            for passage in doc.get("passages", []):
                passage_type = passage.get("infons", {}).get("type", "")
                text = passage.get("text", "").strip()

                if passage_type == "title":
                    title = text
                elif passage_type == "abstract":
                    abstract = text

            results[pmid] = {
                "Title": title,
                "Abstract": abstract
            }

    return results


def fetch_uniprot_by_gene_name(gene_names, batch_size=50, retries=3, sleep=0.4):
    """Query UniProt by gene name to get Protein ID and Protein Name.

    Returns dict keyed by gene_name with keys: Protein_ID, Protein_Name, UniProtKB_accessions
    """
    UNIPROT_SEARCH_URL = "https://rest.uniprot.org/uniprotkb/search"

    results = {}
    gene_names = [g for g in gene_names if g]

    for i in range(0, len(gene_names), batch_size):
        batch = gene_names[i:i + batch_size]

        # Query by gene name (prefer reviewed entries)
        query = " OR ".join([f"gene:{g}" for g in batch])
        params = {
            "query": f"({query}) AND reviewed:true",
            "format": "json",
            "fields": "accession,id,protein_name,gene_primary",
            "size": str(len(batch) * 5)  # May have multiple results per gene
        }
        url = UNIPROT_SEARCH_URL + "?" + urllib.parse.urlencode(params)

        try:
            data = http_get_json(url, retries=retries, sleep=sleep)

            for item in data.get("results", []):
                # Get gene name from result
                genes = item.get("genes", [])
                if not genes:
                    continue
                gene_name = genes[0].get("geneName", {}).get("value")
                if not gene_name or gene_name not in batch:
                    continue

                # Skip if already found (prefer first result)
                if gene_name in results:
                    continue

                # Get accession
                acc = item.get("primaryAccession", "")

                # Get Protein ID
                protein_id = item.get("uniProtkbId", "")

                # Get Protein Name
                protein_name = None
                protein_desc = item.get("proteinDescription", {})
                if "recommendedName" in protein_desc:
                    protein_name = protein_desc.get("recommendedName", {}).get("fullName", {}).get("value")
                if not protein_name and "submissionNames" in protein_desc:
                    names = protein_desc.get("submissionNames", [])
                    if names:
                        protein_name = names[0].get("fullName", {}).get("value")

                results[gene_name] = {
                    "Protein_ID": protein_id or "",
                    "Protein_Name": protein_name or "",
                    "UniProtKB_accessions": acc or ""
                }

            time.sleep(sleep)

        except Exception as e:
            print(f"  Warning: Failed to query UniProt for batch: {e}")
            continue

    # If reviewed:true didn't find all genes, try without restriction
    missing_genes = [g for g in gene_names if g not in results]
    if missing_genes:
        print(f"  Querying {len(missing_genes)} missing genes without reviewed restriction...")

        for i in range(0, len(missing_genes), batch_size):
            batch = missing_genes[i:i + batch_size]

            query = " OR ".join([f"gene:{g}" for g in batch])
            params = {
                "query": f"({query})",
                "format": "json",
                "fields": "accession,id,protein_name,gene_primary",
                "size": str(len(batch) * 5)
            }
            url = UNIPROT_SEARCH_URL + "?" + urllib.parse.urlencode(params)

            try:
                data = http_get_json(url, retries=retries, sleep=sleep)

                for item in data.get("results", []):
                    genes = item.get("genes", [])
                    if not genes:
                        continue
                    gene_name = genes[0].get("geneName", {}).get("value")
                    if not gene_name or gene_name not in batch:
                        continue
                    if gene_name in results:
                        continue

                    acc = item.get("primaryAccession", "")
                    protein_id = item.get("uniProtkbId", "")
                    protein_name = None
                    protein_desc = item.get("proteinDescription", {})
                    if "recommendedName" in protein_desc:
                        protein_name = protein_desc.get("recommendedName", {}).get("fullName", {}).get("value")
                    if not protein_name and "submissionNames" in protein_desc:
                        names = protein_desc.get("submissionNames", [])
                        if names:
                            protein_name = names[0].get("fullName", {}).get("value")

                    results[gene_name] = {
                        "Protein_ID": protein_id or "",
                        "Protein_Name": protein_name or "",
                        "UniProtKB_accessions": acc or ""
                    }

                time.sleep(sleep)

            except Exception as e:
                print(f"  Warning: Failed to query UniProt for batch: {e}")
                continue

    return results


def main():
    parser = argparse.ArgumentParser(
        description='Enrich external resources with PubTator + PubMed + UniProt metadata'
    )
    parser.add_argument(
        '--input', '-i',
        default='others/OtherResources.xlsx',
        help='Input external resources Excel file'
    )
    parser.add_argument(
        '--output', '-o',
        default='others/OtherResources_enriched.csv',
        help='Output enriched CSV file'
    )
    parser.add_argument(
        '--cache-db',
        default='.cache/uniprot_cache.sqlite',
        help='Cache database path for API results'
    )
    parser.add_argument(
        '--batch-size',
        type=int,
        default=50,
        help='Batch size for API requests'
    )
    parser.add_argument(
        '--sleep',
        type=float,
        default=0.4,
        help='Seconds to sleep between API requests'
    )
    args = parser.parse_args()

    print("=" * 80)
    print("SOORENA: Enriching External Resources")
    print("=" * 80)

    # Load input file
    print(f"\nLoading external resources: {args.input}")
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"  Error: {args.input} not found")
        return 1

    df = pd.read_excel(args.input)
    print(f"  Loaded {len(df):,} rows")
    print(f"  Columns: {list(df.columns)}")

    # Setup cache
    cache_path = Path(args.cache_db)
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    cache_conn = sqlite3.connect(str(cache_path))
    ensure_cache_db(cache_conn)

    # Extract unique PMIDs and Gene Names
    pmids = df['PMID'].dropna().astype(str).str.strip().unique().tolist()
    pmids = [p for p in pmids if p]

    gene_names = df['Gene Name'].dropna().astype(str).str.strip().unique().tolist()
    gene_names = [g for g in gene_names if g]

    print(f"\n  Unique PMIDs: {len(pmids):,}")
    print(f"  Unique Gene Names: {len(gene_names):,}")

    # ============================
    # Step 1: Enrich Title + Abstract from PubTator
    # ============================
    print("\n" + "=" * 80)
    print("Step 1: Fetching Title + Abstract from PubTator")
    print("=" * 80)

    print(f"  Fetching for {len(pmids):,} PMIDs (batch size: {args.batch_size})...")
    start_time = time.time()

    title_abstract_map = fetch_title_abstract_from_pubtator(
        pmids,
        batch_size=args.batch_size,
        sleep=args.sleep
    )

    elapsed = time.time() - start_time
    print(f"  ✓ Fetched {len(title_abstract_map):,} entries in {elapsed:.1f}s")

    # ============================
    # Step 2: Enrich Journal + Authors + Date from PubMed
    # ============================
    print("\n" + "=" * 80)
    print("Step 2: Fetching Journal + Authors + Date from PubMed")
    print("=" * 80)

    # Check cache first
    cached_pubmed = get_cached_pubmed_metadata(cache_conn, pmids)
    print(f"  Found {len(cached_pubmed):,} cached entries")

    missing_pmids = [p for p in pmids if p not in cached_pubmed]
    print(f"  Fetching {len(missing_pmids):,} missing PMIDs (batch size: {args.batch_size})...")

    start_time = time.time()
    new_pubmed = {}

    for i in range(0, len(missing_pmids), args.batch_size):
        batch = missing_pmids[i:i + args.batch_size]
        try:
            batch_meta = fetch_pubmed_metadata(batch, sleep=args.sleep)
            new_pubmed.update(batch_meta)
        except Exception as e:
            print(f"    Warning: Failed to fetch PubMed batch {i}-{i+len(batch)}: {e}")
            continue

        if (i + args.batch_size) % 500 == 0:
            print(f"    Processed {i + args.batch_size:,}/{len(missing_pmids):,}...")

    if new_pubmed:
        store_pubmed_metadata(cache_conn, new_pubmed)

    # Combine cached + new
    pubmed_map = {**cached_pubmed, **new_pubmed}

    elapsed = time.time() - start_time
    print(f"  ✓ Fetched {len(pubmed_map):,} entries in {elapsed:.1f}s")

    # ============================
    # Step 3: Enrich Protein Name + Protein ID from UniProt (by Gene Name)
    # ============================
    print("\n" + "=" * 80)
    print("Step 3: Fetching Protein Name + Protein ID from UniProt (by Gene Name)")
    print("=" * 80)

    print(f"  Querying {len(gene_names):,} gene names (batch size: {args.batch_size})...")
    start_time = time.time()

    uniprot_map = fetch_uniprot_by_gene_name(
        gene_names,
        batch_size=args.batch_size,
        sleep=args.sleep
    )

    elapsed = time.time() - start_time
    print(f"  ✓ Found {len(uniprot_map):,} UniProt entries in {elapsed:.1f}s")

    # ============================
    # Step 4: Merge enriched data into dataframe
    # ============================
    print("\n" + "=" * 80)
    print("Step 4: Merging enriched data")
    print("=" * 80)

    # Add Title + Abstract
    df['Title'] = df['PMID'].astype(str).map(lambda p: title_abstract_map.get(p, {}).get('Title', ''))
    df['Abstract'] = df['PMID'].astype(str).map(lambda p: title_abstract_map.get(p, {}).get('Abstract', ''))

    # Add Journal + Authors + Date Published
    df['Journal'] = df['PMID'].astype(str).map(lambda p: pubmed_map.get(p, {}).get('Journal', ''))
    df['Authors'] = df['PMID'].astype(str).map(lambda p: pubmed_map.get(p, {}).get('Authors', ''))
    df['Date Published'] = df['PMID'].astype(str).map(lambda p: pubmed_map.get(p, {}).get('PublicationDate', ''))

    # Add Protein Name + Protein ID
    df['Protein Name'] = df['Gene Name'].astype(str).map(lambda g: uniprot_map.get(g, {}).get('Protein_Name', ''))
    df['Protein ID'] = df['Gene Name'].astype(str).map(lambda g: uniprot_map.get(g, {}).get('Protein_ID', ''))
    df['UniProtKB_accessions'] = df['Gene Name'].astype(str).map(lambda g: uniprot_map.get(g, {}).get('UniProtKB_accessions', ''))

    # Calculate enrichment percentages
    total_rows = len(df)
    title_pct = (df['Title'].astype(bool).sum() / total_rows) * 100
    abstract_pct = (df['Abstract'].astype(bool).sum() / total_rows) * 100
    journal_pct = (df['Journal'].astype(bool).sum() / total_rows) * 100
    authors_pct = (df['Authors'].astype(bool).sum() / total_rows) * 100
    date_pct = (df['Date Published'].astype(bool).sum() / total_rows) * 100
    protein_name_pct = (df['Protein Name'].astype(bool).sum() / total_rows) * 100
    protein_id_pct = (df['Protein ID'].astype(bool).sum() / total_rows) * 100

    print(f"\n  Enrichment results:")
    print(f"    Title: {title_pct:.1f}% ({df['Title'].astype(bool).sum():,}/{total_rows:,})")
    print(f"    Abstract: {abstract_pct:.1f}% ({df['Abstract'].astype(bool).sum():,}/{total_rows:,})")
    print(f"    Journal: {journal_pct:.1f}% ({df['Journal'].astype(bool).sum():,}/{total_rows:,})")
    print(f"    Authors: {authors_pct:.1f}% ({df['Authors'].astype(bool).sum():,}/{total_rows:,})")
    print(f"    Date Published: {date_pct:.1f}% ({df['Date Published'].astype(bool).sum():,}/{total_rows:,})")
    print(f"    Protein Name: {protein_name_pct:.1f}% ({df['Protein Name'].astype(bool).sum():,}/{total_rows:,})")
    print(f"    Protein ID: {protein_id_pct:.1f}% ({df['Protein ID'].astype(bool).sum():,}/{total_rows:,})")

    # ============================
    # Step 5: Save enriched file
    # ============================
    print("\n" + "=" * 80)
    print("Step 5: Saving enriched file")
    print("=" * 80)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    df.to_csv(output_path, index=False)
    print(f"  ✓ Saved to: {output_path}")
    print(f"  Total rows: {len(df):,}")

    # Close cache connection
    cache_conn.close()

    print("\n" + "=" * 80)
    print("External resources enrichment complete!")
    print("=" * 80)
    print(f"\nNext step:")
    print(f"  The enriched file will be automatically used by integrate_external_resources.py")
    print(f"  Run: python scripts/python/data_processing/integrate_external_resources.py")

    return 0


if __name__ == '__main__':
    sys.exit(main())
