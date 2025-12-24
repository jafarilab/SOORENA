#!/usr/bin/env python3
"""
Enrich a CSV with protein/gene info using PubTator + UniProt.

This script uses PMIDs to fetch gene IDs/names from PubTator, maps GeneID -> UniProt,
and writes UniProtKB_accessions / Protein_ID / Protein_Name / Gene_Name columns into a new CSV.
"""
import argparse
import sys
import time
from pathlib import Path

import pandas as pd

# Add repository root to Python path
REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

from pubtator_enrich import (  # noqa: E402
    fetch_pubtator,
    extract_genes,
    normalize_gene_ids,
    run_uniprot_idmapping,
    fetch_uniprot_details,
    ensure_cache_db,
    get_cached_gene_map,
    store_gene_map,
    get_cached_uniprot_details,
    store_uniprot_details,
    fetch_pubmed_metadata,
    get_cached_pubmed_metadata,
    store_pubmed_metadata,
)


def format_duration(seconds):
    seconds = int(seconds)
    mins, sec = divmod(seconds, 60)
    hrs, mins = divmod(mins, 60)
    if hrs > 0:
        return f"{hrs}h {mins}m {sec}s"
    if mins > 0:
        return f"{mins}m {sec}s"
    return f"{sec}s"


def main():
    parser = argparse.ArgumentParser(description="Enrich a CSV using PubTator + UniProt.")
    parser.add_argument("--input", required=True, help="Input CSV (must include PMID)")
    parser.add_argument("--output", required=True, help="Output CSV path")
    parser.add_argument("--pmid-col", default="PMID", help="PMID column name")
    parser.add_argument("--batch", type=int, default=50, help="PMIDs per PubTator request")
    parser.add_argument("--sleep", type=float, default=0.4, help="Seconds between PubTator requests")
    parser.add_argument("--limit", type=int, default=0, help="Limit number of PMIDs (for testing)")
    parser.add_argument("--uniprot-batch", type=int, default=200, help="Gene IDs per UniProt request")
    parser.add_argument("--uniprot-sleep", type=float, default=0.4, help="Seconds between UniProt requests")
    parser.add_argument(
        "--fill-pubmed",
        action="store_true",
        help="Fill missing PublicationDate/Year/Month/Journal/Authors via PubMed E-utilities (cached)",
    )
    parser.add_argument("--pubmed-batch", type=int, default=200, help="PMIDs per PubMed request")
    parser.add_argument("--pubmed-sleep", type=float, default=0.34, help="Seconds between PubMed requests")
    parser.add_argument("--pubmed-retries", type=int, default=3, help="Retries for PubMed requests")
    parser.add_argument("--cache-db", default=".cache/uniprot_cache.sqlite", help="Cache DB for UniProt mapping")
    args = parser.parse_args()

    df = pd.read_csv(args.input, dtype={args.pmid_col: str})
    if args.pmid_col not in df.columns:
        raise SystemExit(f"ERROR: PMID column not found: {args.pmid_col}")

    pmids = df[args.pmid_col].dropna().astype(str).str.strip()
    pmids = [p for p in pmids if p]
    if args.limit:
        pmids = pmids[: args.limit]

    if not pmids:
        raise SystemExit("ERROR: No PMIDs found in input.")

    cache_path = Path(args.cache_db)
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    import sqlite3

    cache_conn = sqlite3.connect(str(cache_path))
    ensure_cache_db(cache_conn)

    results = {}
    processed = 0
    start_time = time.monotonic()

    for i in range(0, len(pmids), args.batch):
        batch = pmids[i:i + args.batch]
        docs = fetch_pubtator(batch, sleep=args.sleep)
        pmid_to_genes = {}
        all_gene_ids = set()

        for doc in docs:
            pmid_doc, gene_ids, gene_names = extract_genes(doc)
            if not pmid_doc:
                continue
            normalized_gene_ids = normalize_gene_ids(gene_ids)
            pmid_to_genes[pmid_doc] = {
                "gene_ids_norm": normalized_gene_ids,
                "gene_names": sorted(gene_names),
            }
            all_gene_ids.update(normalized_gene_ids)

        all_gene_ids_list = sorted(all_gene_ids)
        cached_map = get_cached_gene_map(cache_conn, all_gene_ids_list)
        missing_gene_ids = [gid for gid in all_gene_ids_list if gid not in cached_map]

        if missing_gene_ids:
            for j in range(0, len(missing_gene_ids), args.uniprot_batch):
                chunk = missing_gene_ids[j:j + args.uniprot_batch]
                new_map = run_uniprot_idmapping(chunk, sleep=args.uniprot_sleep)
                store_gene_map(cache_conn, new_map)
                cached_map.update(new_map)
                time.sleep(args.uniprot_sleep)

        all_accessions = set()
        for gene_id, accs in cached_map.items():
            all_accessions.update(accs)

        all_accessions_list = sorted(all_accessions)
        cached_details = get_cached_uniprot_details(cache_conn, all_accessions_list)
        missing_accs = [acc for acc in all_accessions_list if acc not in cached_details]

        if missing_accs:
            new_details = fetch_uniprot_details(missing_accs, batch_size=50, sleep=args.uniprot_sleep)
            store_uniprot_details(cache_conn, new_details)
            cached_details.update(new_details)

        for pmid_doc, info in pmid_to_genes.items():
            gene_ids_norm = info.get("gene_ids_norm", [])
            gene_names_pt = info.get("gene_names", [])

            accessions = set()
            for gid in gene_ids_norm:
                accessions.update(cached_map.get(gid, set()))

            ac_value = ", ".join(sorted(accessions)) if accessions else ""

            uniprot_ids = set()
            protein_names = set()
            gene_names_uniprot = set()
            for acc in accessions:
                detail = cached_details.get(acc, {})
                if detail.get("uniprot_id"):
                    uniprot_ids.add(detail["uniprot_id"])
                if detail.get("protein_name"):
                    protein_names.add(detail["protein_name"])
                if detail.get("gene_name"):
                    gene_names_uniprot.add(detail["gene_name"])

            protein_id_value = " | ".join(sorted(uniprot_ids)) if uniprot_ids else ""
            protein_name_value = " | ".join(sorted(protein_names)) if protein_names else ""

            gene_names_final = gene_names_uniprot if gene_names_uniprot else set(gene_names_pt)
            gene_name_value = " | ".join(sorted(gene_names_final)) if gene_names_final else ""

            results[pmid_doc] = {
                "UniProtKB_accessions": ac_value,
                "Protein_ID": protein_id_value,
                "Protein_Name": protein_name_value,
                "Gene_Name": gene_name_value,
            }

        processed += len(batch)
        elapsed = time.monotonic() - start_time
        rate = processed / elapsed if elapsed > 0 else 0.0
        eta = ((len(pmids) - processed) / rate) if rate > 0 else 0
        msg = (
            f"Processed {processed}/{len(pmids)} | Rate {rate:,.1f} pmid/s | "
            f"Elapsed {format_duration(elapsed)} | ETA {format_duration(eta)}"
        )
        print("\r" + msg.ljust(120), end="", flush=True)

        time.sleep(args.sleep)

    print()
    for col in ["UniProtKB_accessions", "Protein_ID", "Protein_Name", "Gene_Name"]:
        if col not in df.columns:
            df[col] = ""
        mapped = df[args.pmid_col].astype(str).map(
            lambda p: results.get(str(p), {}).get(col, "")
        ).fillna("")
        existing = df[col].fillna("").astype(str)
        # Only overwrite when we have a non-empty enrichment value.
        df[col] = existing.where(mapped == "", mapped)

    if args.fill_pubmed:
        # Ensure columns exist
        for col in ["PublicationDate", "Year", "Month", "Journal", "Authors"]:
            if col not in df.columns:
                df[col] = pd.NA

        def _is_missing(x):
            if x is None:
                return True
            if isinstance(x, float) and pd.isna(x):
                return True
            s = str(x).strip()
            return s == "" or s.lower() == "nan"

        missing_mask = df.apply(
            lambda r: _is_missing(r.get("Year")) or _is_missing(r.get("Month")) or _is_missing(r.get("PublicationDate")),
            axis=1,
        )
        pmids_need = (
            df.loc[missing_mask, args.pmid_col]
            .dropna()
            .astype(str)
            .str.strip()
        )
        pmids_need = [p for p in pmids_need.tolist() if p]
        pmids_need = list(dict.fromkeys(pmids_need))  # preserve order, unique

        if pmids_need:
            print(f"Filling PubMed metadata for {len(pmids_need):,} PMIDs (cached)...")
            filled = 0
            start_meta = time.monotonic()
            for i in range(0, len(pmids_need), args.pubmed_batch):
                batch = pmids_need[i:i + args.pubmed_batch]
                cached = get_cached_pubmed_metadata(cache_conn, batch)
                missing = [p for p in batch if p not in cached]
                fetched = {}
                if missing:
                    fetched = fetch_pubmed_metadata(missing, retries=args.pubmed_retries, sleep=args.pubmed_sleep)
                    store_pubmed_metadata(cache_conn, fetched)
                meta = {}
                meta.update(cached)
                meta.update(fetched)

                # Apply fills only where missing
                for pmid, info in meta.items():
                    idx = df[args.pmid_col].astype(str) == str(pmid)
                    if not idx.any():
                        continue
                    if "PublicationDate" in df.columns:
                        df.loc[idx, "PublicationDate"] = df.loc[idx, "PublicationDate"].apply(
                            lambda v: info.get("PublicationDate") if _is_missing(v) and info.get("PublicationDate") else v
                        )
                    if "Year" in df.columns:
                        df.loc[idx, "Year"] = df.loc[idx, "Year"].apply(
                            lambda v: info.get("Year") if _is_missing(v) and info.get("Year") is not None else v
                        )
                    if "Month" in df.columns:
                        df.loc[idx, "Month"] = df.loc[idx, "Month"].apply(
                            lambda v: info.get("Month") if _is_missing(v) and info.get("Month") else v
                        )
                    if "Journal" in df.columns:
                        df.loc[idx, "Journal"] = df.loc[idx, "Journal"].apply(
                            lambda v: info.get("Journal") if _is_missing(v) and info.get("Journal") else v
                        )
                    if "Authors" in df.columns:
                        df.loc[idx, "Authors"] = df.loc[idx, "Authors"].apply(
                            lambda v: info.get("Authors") if _is_missing(v) and info.get("Authors") else v
                        )

                filled += len(batch)
                elapsed = time.monotonic() - start_meta
                rate = filled / elapsed if elapsed > 0 else 0.0
                eta = ((len(pmids_need) - filled) / rate) if rate > 0 else 0
                msg = (
                    f"PubMed {filled}/{len(pmids_need)} | Rate {rate:,.1f} pmid/s | "
                    f"Elapsed {format_duration(elapsed)} | ETA {format_duration(eta)}"
                )
                print("\r" + msg.ljust(120), end="", flush=True)
            print()

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(output_path, index=False)
    print(f"Saved: {output_path}")

    cache_conn.close()


if __name__ == "__main__":
    main()
