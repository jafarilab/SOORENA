# External Resources Integration

This document explains how to integrate external biological databases (OmniPath, SIGNOR, TRRUST) into the SOORENA prediction dataset.

---

## Overview

SOORENA predictions are enhanced with curated self-loop/autoregulation data from established biological databases. These external resources provide experimentally validated or literature-curated evidence for autoregulatory mechanisms.

**Why integrate external resources?**

- Adds curated, high-confidence entries to complement ML predictions
- Provides cross-validation with established databases
- Increases coverage of known autoregulatory mechanisms
- Allows users to filter by data source (Predicted vs. UniProt vs. curated databases)

---

## Supported External Resources

### 1. OmniPath

**Description:** Comprehensive collection of signaling pathway resources, including protein-protein interactions with self-loops.

**Source:** https://omnipathdb.org/

**Entries in SOORENA:** ~20 self-loops

---

### 2. SIGNOR

**Description:** Signaling Network Open Resource - curated database of signaling pathways with detailed mechanism annotations.

**Source:** https://signor.uniroma2.it/

**Entries in SOORENA:** ~995 self-loops (phosphorylation, ubiquitination, etc.)

---

### 3. TRRUST

**Description:** Transcriptional Regulatory Relationships Unraveled by Sentence-based Text mining - database of transcription factor regulatory relationships.

**Source:** https://www.grnpedia.org/trrust/

**Entries in SOORENA:** 61 transcriptional autoregulation entries

---

## Data Files

**Current Approach (Recommended):**

All external resources are preprocessed and combined into a single file:

- **File:** `others/OtherResources.xlsx`
- **Format:** Pre-deduplicated, standardized columns
- **Columns:** PMID, Gene Name, OS, Source, Autoregulatory Type, Term Probability

This file is then **enriched** with metadata (Title, Abstract, Journal, Authors, Date, Protein Name) using PubTator, PubMed, and UniProt APIs.

---

## Enrichment Pipeline

**Step 1: Enrich External Resources**

Before integration, external resources are enriched with publication and protein metadata:

```bash
python scripts/python/data_processing/enrich_external_resources.py \
  --input others/OtherResources.xlsx \
  --output others/OtherResources_enriched.csv
```

**What this does:**
- Fetches **Title + Abstract** from PubTator (96.5% coverage)
- Fetches **Journal + Authors + Date** from PubMed E-utilities (96.5% coverage)
- Fetches **Protein Name + Protein ID** from UniProt by gene name (98.9% coverage)
- Caches results in `.cache/uniprot_cache.sqlite` for fast re-runs

**Output:** `others/OtherResources_enriched.csv` (cached, reused on subsequent runs)

**To re-enrich from scratch:** Delete `others/OtherResources_enriched.csv`

---

**Step 2: Integrate into Predictions**

After enrichment, external resources are merged with SOORENA predictions:

```bash
python scripts/python/data_processing/integrate_external_resources.py \
  --input shiny_app/data/predictions.csv \
  --output shiny_app/data/predictions.csv \
  --others-dir others/
```

**What this does:**
- Reads enriched CSV if available, otherwise falls back to raw XLSX
- Renames "Non-UniProt" → "Predicted" for clarity
- Removes only true duplicate entries (identical across all columns) to preserve species and mechanism variants
- Maps external mechanism types to SOORENA ontology categories
- Maps Term Probability (Activation/Repression/Unknown) → Polarity (+/–/±)
- Cleans empty autoregulatory types → "Unknown"
- Regenerates AC identifiers for all entries

---

## Mechanism Type Handling

External database mechanisms are **mapped** to SOORENA's ontology categories to ensure consistent classification across all data sources. The mapping preserves biological specificity while integrating with SOORENA's hierarchical ontology structure.

### Mechanism Type Mappings

| External Mechanism | SOORENA Ontology Term | Count (approx.) | Sources |
|-------------------|----------------------|-----------------|---------|
| phosphorylation | Autophosphorylation | ~800 | SIGNOR, OmniPath |
| dephosphorylation | Autodephosphorylation | ~20 | SIGNOR |
| acetylation | Autoacetylation | ~5 | SIGNOR |
| demethylation | Autodemethylation | ~3 | SIGNOR |
| ubiquitination | Autoubiquitination | ~18 | SIGNOR |
| sumoylation | Autosumoylation | ~5 | SIGNOR |
| methylation | Automethylation | <5 | SIGNOR |
| cleavage | Autocleavage | ~10 | SIGNOR |
| transcriptional regulation | Transcriptional Autoregulation | ~69 | TRRUST, OmniPath |
| binding | Protein Binding | ~62 | OmniPath |
| (others) | Unknown | ~12 | Various |

### New Ontology Terms Added

To accommodate external resource data, three new terms were added to the SOORENA ontology under "Enzymatic Self-Modification":

1. **Autodephosphorylation** - The process by which a protein removes phosphate groups from itself (intrinsic phosphatase activity)
2. **Autoacetylation** - The process by which a protein acetylates itself (intrinsic acetyltransferase activity)
3. **Autodemethylation** - The process by which a protein demethylates itself (intrinsic demethylase activity)

These complement existing ontology terms (Autophosphorylation, Autoubiquitination, etc.) to provide comprehensive coverage of post-translational modification mechanisms found in curated databases.

---

## Polarity Mapping

### From Term Probability Field

Term Probability values from external databases are mapped to polarity symbols:

| Term Probability | Polarity Symbol | Meaning |
|-----------------|----------------|---------|
| Activation, up-regulates, stimulation | + | Positive/activating |
| Repression, down-regulates, inhibition | – | Negative/inhibiting |
| Unknown, empty | ± | Context-dependent |

### By Mechanism Type

When Term Probability is not specified, polarity is inferred from the mechanism type:

| Mechanism Type | Polarity | Rationale |
|---------------|----------|-----------|
| Autophosphorylation | + | Generally activating |
| Autodephosphorylation | – | Generally inhibiting (removes activating phosphates) |
| Autoacetylation | + | Generally activating |
| Autodemethylation | ± | Context-dependent (can be activating or inhibiting) |
| Autoubiquitination | – | Generally leads to degradation |
| Autosumoylation | ± | Context-dependent |
| Automethylation | + | Generally activating |
| Autocleavage | + | Generally activating (proteolytic activation) |
| Transcriptional Autoregulation | ± | Can be positive or negative feedback |
| Protein Binding | ± | Context-dependent |
| Unknown | ± | No information available |

---

## Running the Full Pipeline

The recommended way to integrate external resources is through the automated pipeline:

```bash
./scripts/run_merge_and_deploy.sh
```

This runs:
1. **Merge enriched datasets** → `shiny_app/data/predictions.csv`
2. **Enrich external resources** (cached) → `others/OtherResources_enriched.csv`
3. **Integrate external resources** → `shiny_app/data/predictions.csv` (updated)
4. **Build SQLite database** → `shiny_app/data/predictions.db`
5. **Optionally deploy** to production server

---

## Output Format

External resource entries are added with:

| Column | Value |
|--------|-------|
| `Source` | "OmniPath", "SIGNOR", or "TRRUST" |
| `Mechanism Probability` | 1.0 (curated, not predicted) |
| `Type Confidence` | 1.0 (curated, not predicted) |
| `Has Mechanism` | "Yes" |
| `Autoregulatory Type` | Raw mechanism (phosphorylation, transcriptional, etc.) |
| `Polarity` | + / – / ± |
| `Gene_Name` | Gene symbol from external DB |
| `Title` | Publication title (enriched) |
| `Abstract` | Publication abstract (enriched) |
| `Journal` | Journal name (enriched) |
| `Authors` | Author list (enriched) |
| `Protein_Name` | Protein name (enriched) |
| `AC` | `SOORENA-<SourceCode>-<PMID>-<n>` |

**Source codes in AC:**
- `U` = UniProt (original training data)
- `P` = Predicted (ML predictions from PubMed)
- `O` = OmniPath
- `S` = SIGNOR
- `T` = TRRUST

---

## Enrichment Results

After running the enrichment pipeline:

| Metadata Field | Coverage | Source |
|---------------|----------|--------|
| Title | 96.5% | PubTator |
| Abstract | 96.2% | PubTator |
| Journal | 96.5% | PubMed E-utilities |
| Authors | 96.5% | PubMed E-utilities |
| Date Published | 96.5% | PubMed E-utilities |
| Protein Name | 98.9% | UniProt (by gene name) |
| Protein ID | 98.9% | UniProt (by gene name) |

**Note:** OmniPath entries have invalid PMIDs ("-"), so they lack publication metadata but retain gene and protein information.

---

## Data Statistics

Current external resource entries in SOORENA:

| Database | Total Self-Loops (Raw) | Deduplicated Entries | With Enriched Metadata |
|----------|----------------------|---------------------|----------------------|
| OmniPath | 68 | ~20 | 0 (invalid PMIDs) |
| SIGNOR | 1,813 | ~995 | ~995 (100%) |
| TRRUST | 61 | 61 | 61 (100%) |
| **Total** | **1,942** | **~1,076** | **~1,056 (98.1%)** |

**Deduplication Strategy (Updated):** The integration process now removes **only true duplicates** (entries identical across all columns). Previous versions used aggressive deduplication by PMID+Source+Gene, which incorrectly removed valid species variants (e.g., human vs mouse) and mechanism variants (e.g., phosphorylation vs dephosphorylation). The new approach preserves these important biological distinctions while eliminating redundant entries.

**Impact of Deduplication Change:**

- SIGNOR: Increased from 394 to ~995 entries (+601 entries restored, representing species and mechanism variants)
- OmniPath: Increased from 10 to ~20 entries (+10 entries restored)
- TRRUST: Unchanged at 61 entries (no species/mechanism variants)

**Overlap with predictions:** External entries may share PMIDs with existing SOORENA predictions. These are kept as separate rows to show both ML predictions and external database validation for the same publications.

---

## Updating External Resources

To update `OtherResources.xlsx` with newer data:

### Using the R preprocessing script

See `others/OtherResources.Rmd` for the data extraction pipeline:

1. **OmniPath** - Uses OmnipathR package to fetch all interactions, filters self-loops
2. **SIGNOR** - Downloads TSV files from SIGNOR website, filters self-loops
3. **TRRUST** - Downloads TSV files, filters self-loops

The script combines all sources into `OtherResources.xlsx` with standardized columns.

### Manual update

1. Download latest data from each source
2. Filter for self-loops (source == target)
3. Combine into single Excel file with columns:
   - PMID, Gene Name, OS, Source, Autoregulatory Type, Term Probability
4. Save as `others/OtherResources.xlsx`
5. Delete cached enriched file: `rm others/OtherResources_enriched.csv`
6. Re-run pipeline to enrich and integrate

---

## Troubleshooting

### Issue: "No external resources found"

**Solution:** Ensure `others/OtherResources.xlsx` exists in the repository.

---

### Issue: "HTTP Error 400: Bad Request" during enrichment

**Solution:** The script automatically handles invalid PMIDs by trying individual fetches. Some entries (like OmniPath with "-" PMIDs) will be skipped for publication metadata but retain gene/protein information.

---

### Issue: Low enrichment coverage

**Solution:**
1. Check internet connection
2. Check PubTator/PubMed API status
3. Delete cache and re-run: `rm -rf .cache/uniprot_cache.sqlite`

---

### Issue: "Non-UniProt" still showing instead of "Predicted"

**Solution:** The integration script automatically renames on every run. If you see "Non-UniProt" in the app, rebuild the database:

```bash
python scripts/python/data_processing/create_sqlite_db.py \
  --input shiny_app/data/predictions.csv \
  --output shiny_app/data/predictions.db
```

---

## Advanced Usage

### Enrich only (without integration)

```bash
python scripts/python/data_processing/enrich_external_resources.py \
  --input others/OtherResources.xlsx \
  --output others/OtherResources_enriched.csv \
  --batch-size 50 \
  --sleep 0.4
```

### Use raw data (skip enrichment)

Delete the enriched cache file before running integration:

```bash
rm others/OtherResources_enriched.csv
```

The integration script will fall back to raw `OtherResources.xlsx` (0% metadata coverage).

---

## Related Documentation

- Main workflow: `docs/README.md`
- Prediction guide: `docs/README_PREDICTION_NEW_DATA.md`
- Scripts overview: `scripts/README.md`
- Architecture: `docs/README_ARCHITECTURE.md`
