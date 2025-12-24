#!/usr/bin/env python3
"""
Enrich rows missing AC using PubTator + UniProt mapping.

Steps:
1) Find rows with missing AC and valid PMID in the SQLite DB.
2) Fetch gene IDs/names from PubTator (PMID-based).
3) Map gene IDs -> UniProt accessions (AC) via UniProt ID mapping.
4) Fetch UniProt details for accessions (Protein ID, Protein Name, Gene Name).
5) Update predictions table with AC / Protein_ID / Protein_Name / Gene_Name.
6) Store raw PubTator gene IDs in a separate table (optional).
"""

import argparse
import json
import os
import sqlite3
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime

PUBTATOR_URL = "https://www.ncbi.nlm.nih.gov/research/pubtator3-api/publications/export/biocjson?pmids="
UNIPROT_RUN_URL = "https://rest.uniprot.org/idmapping/run"
UNIPROT_STATUS_URL = "https://rest.uniprot.org/idmapping/status/"
UNIPROT_RESULTS_URL = "https://rest.uniprot.org/idmapping/results/"
UNIPROT_SEARCH_URL = "https://rest.uniprot.org/uniprotkb/search"
PUBMED_ESUMMARY_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi"


# ----------------------------
# HTTP helpers
# ----------------------------

def http_get_json(url, retries=3, sleep=1.0):
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(url, timeout=30) as resp:
                return json.load(resp)
        except Exception:
            if attempt == retries - 1:
                raise
            time.sleep(sleep * (2 ** attempt))
    return {}


def http_post_json(url, data_dict, retries=3, sleep=1.0):
    data = urllib.parse.urlencode(data_dict).encode("utf-8")
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, data=data, method="POST")
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.load(resp)
        except Exception:
            if attempt == retries - 1:
                raise
            time.sleep(sleep * (2 ** attempt))
    return {}


# ----------------------------
# PubTator
# ----------------------------

def normalize_gene_ids(gene_ids):
    cleaned = set()
    for gene_id in gene_ids:
        if gene_id is None:
            continue
        raw = str(gene_id).strip()
        if not raw:
            continue
        for part in raw.replace("|", ",").replace(";", ",").split(","):
            part = part.strip()
            if not part:
                continue
            lower = part.lower()
            if lower.startswith("geneid:"):
                part = part.split(":", 1)[1].strip()
            if ":" in part and not part.isdigit():
                tail = part.rsplit(":", 1)[-1].strip()
                if tail.isdigit():
                    part = tail
            if part.isdigit():
                cleaned.add(part)
    return sorted(cleaned)


def fetch_pubtator(pmids, retries=3, sleep=1.0):
    url = PUBTATOR_URL + ",".join(pmids)
    data = http_get_json(url, retries=retries, sleep=sleep)
    return data.get("PubTator3", [])


def extract_genes(doc):
    pmid = str(doc.get("id", "")).strip()
    gene_ids = set()
    gene_names = set()

    for passage in doc.get("passages", []):
        for ann in passage.get("annotations", []):
            inf = ann.get("infons", {})
            if inf.get("type") != "Gene":
                continue

            ident = inf.get("identifier") or inf.get("normalized_id")
            if ident is not None:
                for part in str(ident).replace(";", ",").split(","):
                    part = part.strip()
                    if part:
                        gene_ids.add(part)

            name = inf.get("name") or ann.get("text")
            if name:
                gene_names.add(name.strip())

    return pmid, gene_ids, gene_names


# ----------------------------
# UniProt mapping + details
# ----------------------------

def run_uniprot_idmapping(gene_ids, retries=3, sleep=1.0):
    gene_ids = normalize_gene_ids(gene_ids)
    if not gene_ids:
        return {}

    def run_chunk(ids):
        mapping = {gid: set() for gid in ids}
        payload = {
            "from": "GeneID",
            "to": "UniProtKB",
            "ids": " ".join(ids)
        }
        try:
            run_resp = http_post_json(UNIPROT_RUN_URL, payload, retries=retries, sleep=sleep)
            job_id = run_resp.get("jobId")
            if not job_id:
                return mapping

            status_url = UNIPROT_STATUS_URL + job_id
            job_status = None
            for _ in range(60):
                status = http_get_json(status_url, retries=retries, sleep=sleep)
                job_status = status.get("jobStatus")
                if job_status in (None, "FINISHED", "FAILED"):
                    break
                time.sleep(1)
            if job_status == "FAILED":
                if len(ids) > 1:
                    mid = len(ids) // 2
                    left = run_chunk(ids[:mid])
                    right = run_chunk(ids[mid:])
                    left.update(right)
                    return left
                return mapping

            results_url = UNIPROT_RESULTS_URL + job_id + "?format=json"
            results = http_get_json(results_url, retries=retries, sleep=sleep)
        except urllib.error.HTTPError as exc:
            if exc.code == 400 and len(ids) > 1:
                mid = len(ids) // 2
                left = run_chunk(ids[:mid])
                right = run_chunk(ids[mid:])
                left.update(right)
                return left
            return mapping
        except Exception:
            if len(ids) > 1:
                mid = len(ids) // 2
                left = run_chunk(ids[:mid])
                right = run_chunk(ids[mid:])
                left.update(right)
                return left
            return mapping

        for row in results.get("results", []):
            gene_id = str(row.get("from", "")).strip()
            acc = str(row.get("to", "")).strip()
            if not gene_id or not acc:
                continue
            mapping.setdefault(gene_id, set()).add(acc)
        return mapping

    return run_chunk(gene_ids)


def fetch_uniprot_details(accessions, batch_size=50, retries=3, sleep=1.0):
    details = {}
    accessions = [a for a in accessions if a]
    for i in range(0, len(accessions), batch_size):
        batch = accessions[i:i + batch_size]
        query = " OR ".join([f"accession:{a}" for a in batch])
        params = {
            "query": f"({query})",
            "format": "json",
            "fields": "accession,id,protein_name,gene_primary",
            "size": str(len(batch))
        }
        url = UNIPROT_SEARCH_URL + "?" + urllib.parse.urlencode(params)
        data = http_get_json(url, retries=retries, sleep=sleep)

        for item in data.get("results", []):
            acc = item.get("primaryAccession")
            uniprot_id = item.get("uniProtkbId")

            protein_name = None
            protein_desc = item.get("proteinDescription", {})
            if "recommendedName" in protein_desc:
                protein_name = protein_desc.get("recommendedName", {}).get("fullName", {}).get("value")
            if not protein_name and "submissionNames" in protein_desc:
                names = protein_desc.get("submissionNames", [])
                if names:
                    protein_name = names[0].get("fullName", {}).get("value")

            gene_name = None
            genes = item.get("genes", [])
            if genes:
                gene_name = genes[0].get("geneName", {}).get("value")

            if acc:
                details[acc] = {
                    "uniprot_id": uniprot_id or "",
                    "protein_name": protein_name or "",
                    "gene_name": gene_name or ""
                }

        time.sleep(sleep)

    return details


# ----------------------------
# Cache DB
# ----------------------------

def ensure_cache_db(cache_conn):
    cur = cache_conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS gene_to_uniprot (
            gene_id TEXT PRIMARY KEY,
            accessions TEXT
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS uniprot_details (
            accession TEXT PRIMARY KEY,
            uniprot_id TEXT,
            protein_name TEXT,
            gene_name TEXT
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS pubmed_metadata (
            pmid TEXT PRIMARY KEY,
            publication_date TEXT,
            year INTEGER,
            month TEXT,
            journal TEXT,
            authors TEXT,
            fetched_at TEXT
        )
        """
    )
    cache_conn.commit()


def get_cached_gene_map(cache_conn, gene_ids):
    if not gene_ids:
        return {}
    cur = cache_conn.cursor()
    placeholders = ",".join(["?"] * len(gene_ids))
    cur.execute(
        f"SELECT gene_id, accessions FROM gene_to_uniprot WHERE gene_id IN ({placeholders})",
        gene_ids
    )
    mapping = {}
    for gene_id, accessions in cur.fetchall():
        if accessions:
            mapping[gene_id] = set([a.strip() for a in accessions.split(",") if a.strip()])
        else:
            mapping[gene_id] = set()
    return mapping


def store_gene_map(cache_conn, mapping):
    if not mapping:
        return
    cur = cache_conn.cursor()
    rows = []
    for gene_id, accessions in mapping.items():
        acc_str = ",".join(sorted(accessions)) if accessions else ""
        rows.append((gene_id, acc_str))
    cur.executemany(
        "INSERT OR REPLACE INTO gene_to_uniprot (gene_id, accessions) VALUES (?, ?)",
        rows
    )
    cache_conn.commit()


def get_cached_uniprot_details(cache_conn, accessions):
    if not accessions:
        return {}
    cur = cache_conn.cursor()
    placeholders = ",".join(["?"] * len(accessions))
    cur.execute(
        f"SELECT accession, uniprot_id, protein_name, gene_name FROM uniprot_details WHERE accession IN ({placeholders})",
        accessions
    )
    details = {}
    for acc, uniprot_id, protein_name, gene_name in cur.fetchall():
        details[acc] = {
            "uniprot_id": uniprot_id or "",
            "protein_name": protein_name or "",
            "gene_name": gene_name or ""
        }
    return details


def store_uniprot_details(cache_conn, details):
    if not details:
        return
    cur = cache_conn.cursor()
    rows = []
    for acc, info in details.items():
        rows.append((acc, info.get("uniprot_id", ""), info.get("protein_name", ""), info.get("gene_name", "")))
    cur.executemany(
        "INSERT OR REPLACE INTO uniprot_details (accession, uniprot_id, protein_name, gene_name) VALUES (?, ?, ?, ?)",
        rows
    )
    cache_conn.commit()


# ----------------------------
# PubMed metadata (E-utilities)
# ----------------------------

_MONTH_MAP = {
    "jan": "Jan",
    "feb": "Feb",
    "mar": "Mar",
    "apr": "Apr",
    "may": "May",
    "jun": "Jun",
    "jul": "Jul",
    "aug": "Aug",
    "sep": "Sep",
    "sept": "Sep",
    "oct": "Oct",
    "nov": "Nov",
    "dec": "Dec",
}


def _parse_year_month(pubdate: str):
    if not pubdate:
        return None, ""
    s = str(pubdate).strip()
    year = None
    for token in s.replace("/", " ").replace("-", " ").split():
        if len(token) == 4 and token.isdigit():
            year = int(token)
            break
    month = ""
    lower = s.lower()
    for key, val in _MONTH_MAP.items():
        if f" {key} " in f" {lower} ":
            month = val
            break
    return year, month


def get_cached_pubmed_metadata(cache_conn, pmids):
    pmids = [str(p).strip() for p in (pmids or []) if str(p).strip()]
    if not pmids:
        return {}
    cur = cache_conn.cursor()
    placeholders = ",".join(["?"] * len(pmids))
    cur.execute(
        f"""
        SELECT pmid, publication_date, year, month, journal, authors
        FROM pubmed_metadata
        WHERE pmid IN ({placeholders})
        """,
        pmids,
    )
    out = {}
    for pmid, publication_date, year, month, journal, authors in cur.fetchall():
        out[str(pmid)] = {
            "PublicationDate": publication_date or "",
            "Year": int(year) if year is not None else None,
            "Month": month or "",
            "Journal": journal or "",
            "Authors": authors or "",
        }
    return out


def store_pubmed_metadata(cache_conn, meta):
    if not meta:
        return
    cur = cache_conn.cursor()
    fetched_at = datetime.utcnow().isoformat(timespec="seconds") + "Z"
    rows = []
    for pmid, info in meta.items():
        pmid = str(pmid).strip()
        if not pmid:
            continue
        publication_date = (info.get("PublicationDate") or "").strip()
        year = info.get("Year")
        month = (info.get("Month") or "").strip()
        journal = (info.get("Journal") or "").strip()
        authors = (info.get("Authors") or "").strip()
        rows.append((pmid, publication_date, year, month, journal, authors, fetched_at))
    if not rows:
        return
    cur.executemany(
        """
        INSERT OR REPLACE INTO pubmed_metadata
          (pmid, publication_date, year, month, journal, authors, fetched_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        rows,
    )
    cache_conn.commit()


def fetch_pubmed_metadata(pmids, retries=3, sleep=0.34):
    """Fetch publication metadata for PMIDs via NCBI ESummary.

    Returns dict keyed by PMID with keys: PublicationDate, Year, Month, Journal, Authors.
    """
    pmids = [str(p).strip() for p in (pmids or []) if str(p).strip()]
    if not pmids:
        return {}

    params = {
        "db": "pubmed",
        "id": ",".join(pmids),
        "retmode": "json",
    }
    url = PUBMED_ESUMMARY_URL + "?" + urllib.parse.urlencode(params)
    data = http_get_json(url, retries=retries, sleep=sleep)
    result = data.get("result", {})
    out = {}
    for pmid in pmids:
        item = result.get(str(pmid), {}) if isinstance(result, dict) else {}
        pubdate = (item.get("pubdate") or "").strip()
        journal = (item.get("fulljournalname") or item.get("source") or "").strip()
        authors_list = item.get("authors") or []
        names = []
        for a in authors_list:
            name = (a.get("name") if isinstance(a, dict) else "") or ""
            name = name.strip()
            if name:
                names.append(name)
        authors = "; ".join(names)
        year, month = _parse_year_month(pubdate)
        out[str(pmid)] = {
            "PublicationDate": pubdate,
            "Year": year,
            "Month": month,
            "Journal": journal,
            "Authors": authors,
        }
    time.sleep(sleep)
    return out

# ----------------------------
# SQLite helpers
# ----------------------------

def ensure_gene_map_table(conn, table_name):
    cur = conn.cursor()
    cur.execute(
        f"""
        CREATE TABLE IF NOT EXISTS {table_name} (
            PMID TEXT PRIMARY KEY,
            Gene_IDs TEXT,
            Gene_Names TEXT,
            Updated_At TEXT
        )
        """
    )
    conn.commit()


def iter_pmids_missing_ac(conn, table, pmid_col, ac_col):
    cur = conn.cursor()
    query = (
        f"SELECT DISTINCT {pmid_col} "
        f"FROM {table} "
        f"WHERE ({ac_col} IS NULL OR trim({ac_col}) = '' OR {ac_col} = 'Unknown') "
        f"AND {pmid_col} IS NOT NULL AND trim({pmid_col}) != ''"
    )
    cur.execute(query)
    while True:
        rows = cur.fetchmany(10000)
        if not rows:
            break
        for (pmid,) in rows:
            pmid = str(pmid).strip()
            if pmid:
                yield pmid


def count_missing_ac(conn, table, pmid_col, ac_col):
    cur = conn.cursor()
    query = (
        f"SELECT COUNT(DISTINCT {pmid_col}) "
        f"FROM {table} "
        f"WHERE ({ac_col} IS NULL OR trim({ac_col}) = '' OR {ac_col} = 'Unknown') "
        f"AND {pmid_col} IS NOT NULL AND trim({pmid_col}) != ''"
    )
    cur.execute(query)
    row = cur.fetchone()
    return int(row[0]) if row and row[0] is not None else 0


def update_predictions(conn, table, pmid_col, ac_col, updates):
    if not updates:
        return 0
    cur = conn.cursor()
    sql = (
        f"UPDATE {table} "
        f"SET {ac_col} = COALESCE(NULLIF(?, ''), {ac_col}), "
        f"    Protein_ID = COALESCE(NULLIF(?, ''), Protein_ID), "
        f"    Protein_Name = COALESCE(NULLIF(?, ''), Protein_Name), "
        f"    Gene_Name = COALESCE(NULLIF(?, ''), Gene_Name) "
        f"WHERE {pmid_col} = ? "
        f"AND ({ac_col} IS NULL OR trim({ac_col}) = '' OR {ac_col} = 'Unknown')"
    )
    cur.executemany(sql, updates)
    conn.commit()
    return cur.rowcount


def upsert_gene_map(conn, table_name, rows):
    if not rows:
        return
    cur = conn.cursor()
    cur.executemany(
        f"INSERT OR REPLACE INTO {table_name} (PMID, Gene_IDs, Gene_Names, Updated_At) VALUES (?, ?, ?, ?)",
        rows
    )
    conn.commit()


# ----------------------------
# Main
# ----------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", required=True, help="SQLite DB path (e.g., shiny_app/data/predictions.db)")
    ap.add_argument("--table", default="predictions", help="SQLite table name")
    ap.add_argument("--pmid-col", default="PMID", help="PMID column name")
    ap.add_argument("--ac-col", default="AC", help="AC column name")
    ap.add_argument("--batch", type=int, default=50, help="PMIDs per PubTator request")
    ap.add_argument("--sleep", type=float, default=0.4, help="Seconds between PubTator requests")
    ap.add_argument("--limit", type=int, default=0, help="Stop after N PMIDs (for testing)")
    ap.add_argument("--commit-every", type=int, default=200, help="Commit updates every N PMIDs")
    ap.add_argument("--cache-db", default=".cache/uniprot_cache.sqlite", help="Cache DB for UniProt mapping")
    ap.add_argument("--uniprot-batch", type=int, default=200, help="Gene IDs per UniProt mapping request")
    ap.add_argument("--uniprot-sleep", type=float, default=0.4, help="Seconds between UniProt requests")
    ap.add_argument("--store-gene-map", action="store_true", help="Store PubTator gene IDs in a separate table")
    ap.add_argument("--gene-map-table", default="pubtator_gene_map", help="Gene map table name")
    args = ap.parse_args()

    conn = sqlite3.connect(args.db)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")

    cache_dir = os.path.dirname(args.cache_db)
    if cache_dir and not os.path.isdir(cache_dir):
        os.makedirs(cache_dir, exist_ok=True)

    cache_conn = sqlite3.connect(args.cache_db)
    ensure_cache_db(cache_conn)

    if args.store_gene_map:
        ensure_gene_map_table(conn, args.gene_map_table)

    total_missing = count_missing_ac(conn, args.table, args.pmid_col, args.ac_col)
    total_target = min(total_missing, args.limit) if args.limit else total_missing

    pmid_iter = iter_pmids_missing_ac(conn, args.table, args.pmid_col, args.ac_col)

    batch = []
    processed = 0
    updated = 0
    pmid_seen = 0
    limit_reached = False
    gene_map_rows = []
    update_rows = []
    start_time = time.monotonic()
    last_print = 0.0

    def format_duration(seconds):
        seconds = int(seconds)
        mins, sec = divmod(seconds, 60)
        hrs, mins = divmod(mins, 60)
        if hrs > 0:
            return f"{hrs}h {mins}m {sec}s"
        if mins > 0:
            return f"{mins}m {sec}s"
        return f"{sec}s"

    def print_progress(force=False):
        nonlocal last_print
        now = time.monotonic()
        if not force and now - last_print < 1.0:
            return
        last_print = now
        elapsed = now - start_time
        rate = processed / elapsed if elapsed > 0 else 0.0
        if total_target > 0:
            pct = (processed / total_target) * 100
            remaining = max(total_target - processed, 0)
            eta = (remaining / rate) if rate > 0 else 0
            msg = (
                f"Processed {processed}/{total_target} ({pct:5.1f}%) | "
                f"Updated {updated} | "
                f"Rate {rate:,.1f} pmid/s | "
                f"Elapsed {format_duration(elapsed)} | "
                f"ETA {format_duration(eta)}"
            )
        else:
            msg = (
                f"Processed {processed} | Updated {updated} | "
                f"Rate {rate:,.1f} pmid/s | Elapsed {format_duration(elapsed)}"
            )
        print(msg, end="\n" if force else "\r", flush=True)

    for pmid in pmid_iter:
        pmid_seen += 1
        batch.append(pmid)
        if args.limit and pmid_seen >= args.limit:
            limit_reached = True

        if len(batch) < args.batch and not limit_reached:
            continue

        docs = fetch_pubtator(batch, sleep=args.sleep)
        pmid_to_genes = {}
        all_gene_ids = set()

        for doc in docs:
            pmid_doc, gene_ids, gene_names = extract_genes(doc)
            if not pmid_doc:
                continue
            normalized_gene_ids = normalize_gene_ids(gene_ids)
            pmid_to_genes[pmid_doc] = {
                "gene_ids": sorted(gene_ids),
                "gene_ids_norm": normalized_gene_ids,
                "gene_names": sorted(gene_names)
            }
            all_gene_ids.update(normalized_gene_ids)

        # Map gene IDs -> UniProt accessions (with cache)
        all_gene_ids_list = sorted(all_gene_ids)
        cached_map = get_cached_gene_map(cache_conn, all_gene_ids_list)
        missing_gene_ids = [gid for gid in all_gene_ids_list if gid not in cached_map]

        if missing_gene_ids:
            for i in range(0, len(missing_gene_ids), args.uniprot_batch):
                chunk = missing_gene_ids[i:i + args.uniprot_batch]
                new_map = run_uniprot_idmapping(chunk, sleep=args.uniprot_sleep)
                store_gene_map(cache_conn, new_map)
                cached_map.update(new_map)
                time.sleep(args.uniprot_sleep)

        # Collect accessions for this batch
        all_accessions = set()
        for gene_id, accs in cached_map.items():
            all_accessions.update(accs)

        # Fetch UniProt details (with cache)
        all_accessions_list = sorted(all_accessions)
        cached_details = get_cached_uniprot_details(cache_conn, all_accessions_list)
        missing_accs = [acc for acc in all_accessions_list if acc not in cached_details]

        if missing_accs:
            new_details = fetch_uniprot_details(missing_accs, batch_size=50, sleep=args.uniprot_sleep)
            store_uniprot_details(cache_conn, new_details)
            cached_details.update(new_details)

        # Build updates for each PMID
        for pmid_doc, info in pmid_to_genes.items():
            gene_ids = info["gene_ids"]
            gene_ids_norm = info.get("gene_ids_norm", [])
            gene_names_pt = info["gene_names"]

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

            update_rows.append((ac_value, protein_id_value, protein_name_value, gene_name_value, pmid_doc))

            if args.store_gene_map:
                gene_map_rows.append((
                    pmid_doc,
                    ";".join(gene_ids),
                    ";".join(gene_names_pt),
                    datetime.utcnow().isoformat()
                ))

        processed += len(batch)
        print_progress()

        if len(update_rows) >= args.commit_every:
            updated += update_predictions(conn, args.table, args.pmid_col, args.ac_col, update_rows)
            update_rows = []
            if args.store_gene_map:
                upsert_gene_map(conn, args.gene_map_table, gene_map_rows)
                gene_map_rows = []

            print_progress(force=True)

        batch = []
        time.sleep(args.sleep)
        if limit_reached:
            break

    # Flush remaining
    if batch:
        docs = fetch_pubtator(batch, sleep=args.sleep)
        pmid_to_genes = {}
        all_gene_ids = set()

        for doc in docs:
            pmid_doc, gene_ids, gene_names = extract_genes(doc)
            if not pmid_doc:
                continue
            normalized_gene_ids = normalize_gene_ids(gene_ids)
            pmid_to_genes[pmid_doc] = {
                "gene_ids": sorted(gene_ids),
                "gene_ids_norm": normalized_gene_ids,
                "gene_names": sorted(gene_names)
            }
            all_gene_ids.update(normalized_gene_ids)

        all_gene_ids_list = sorted(all_gene_ids)
        cached_map = get_cached_gene_map(cache_conn, all_gene_ids_list)
        missing_gene_ids = [gid for gid in all_gene_ids_list if gid not in cached_map]

        if missing_gene_ids:
            for i in range(0, len(missing_gene_ids), args.uniprot_batch):
                chunk = missing_gene_ids[i:i + args.uniprot_batch]
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
            gene_ids = info["gene_ids"]
            gene_ids_norm = info.get("gene_ids_norm", [])
            gene_names_pt = info["gene_names"]

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

            update_rows.append((ac_value, protein_id_value, protein_name_value, gene_name_value, pmid_doc))

            if args.store_gene_map:
                gene_map_rows.append((
                    pmid_doc,
                    ";".join(gene_ids),
                    ";".join(gene_names_pt),
                    datetime.utcnow().isoformat()
                ))

        processed += len(batch)
        print_progress()

    if update_rows:
        updated += update_predictions(conn, args.table, args.pmid_col, args.ac_col, update_rows)
    if args.store_gene_map and gene_map_rows:
        upsert_gene_map(conn, args.gene_map_table, gene_map_rows)

    print_progress(force=True)
    print(f"Done. Processed {processed} PMIDs. Updated {updated} rows.")

    conn.close()
    cache_conn.close()


if __name__ == "__main__":
    main()
