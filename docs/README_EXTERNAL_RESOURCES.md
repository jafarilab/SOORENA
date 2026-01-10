# External Resources Integration

This document explains how to integrate external biological databases (OmniPath, SIGNOR, TRRUST) into the SOORENA prediction dataset.

---

## Overview

SOORENA predictions are enhanced with curated self-loop/autoregulation data from established biological databases. These external resources provide experimentally validated or literature-curated evidence for autoregulatory mechanisms.

**Why integrate external resources?**

- Adds curated, high-confidence entries to complement ML predictions
- Provides cross-validation with established databases
- Increases coverage of known autoregulatory mechanisms
- Allows users to filter by data source (predicted vs. curated)

---

## Supported External Resources

### 1. OmniPath

**Description:** Comprehensive collection of signaling pathway resources, including protein-protein interactions with self-loops.

**Source:** https://omnipathdb.org/

**Data extraction:**
- Self-loops identified where `source_genesymbol == target_genesymbol`
- PMIDs extracted from `references` column
- Includes kinase-substrate relationships

**File:** `others/OmniAll.xlsx`

**Columns used:**
- `source_genesymbol`, `target_genesymbol` (gene names)
- `references` (contains PMIDs in format `DB:PMID`)
- `is_stimulation`, `is_inhibition` (polarity)

---

### 2. SIGNOR

**Description:** Signaling Network Open Resource - curated database of signaling pathways with detailed mechanism annotations.

**Source:** https://signor.uniroma2.it/

**Data extraction:**
- Self-loops identified where `ENTITYA == ENTITYB`
- Direct PMID column available
- Rich mechanism annotations (phosphorylation, ubiquitination, etc.)

**File:** `others/Signor.xlsx`

**Columns used:**
- `ENTITYA`, `ENTITYB` (entity names)
- `PMID` (direct PubMed ID)
- `MECHANISM` (e.g., phosphorylation)
- `EFFECT` (up-regulates, down-regulates)
- `origin` (organism)

---

### 3. TRRUST

**Description:** Transcriptional Regulatory Relationships Unraveled by Sentence-based Text mining - database of transcription factor regulatory relationships.

**Source:** https://www.grnpedia.org/trrust/

**Data extraction:**
- Self-loops identified where `V1 == V2` (TF regulates itself)
- PMIDs in `V4` column
- Includes activation/repression annotations

**File:** `others/TRUST.xlsx`

**Columns used:**
- `V1`, `V2` (gene symbols)
- `V3` (effect: Activation/Repression)
- `V4` (PMID)
- `origin` (mouse/human)

---

## Mechanism Type Mapping

External database mechanisms are mapped to SOORENA's 7 autoregulatory categories:

| External Mechanism | SOORENA Type |
|-------------------|--------------|
| phosphorylation, autophosphorylation | Autophosphorylation |
| ubiquitination | Autoubiquitination |
| cleavage, proteolysis | Autolysis |
| catalytic, catalysis | Autocatalytic |
| Activation (TRRUST) | Autoregulation |
| Repression (TRRUST) | Autoregulation |
| inhibition | Autoinhibition |
| (default) | Autoregulation |

---

## Polarity Mapping

Effects are mapped to SOORENA polarity symbols:

| Effect | Polarity |
|--------|----------|
| up-regulates, activation, stimulation | + |
| down-regulates, repression, inhibition | – |
| unknown/context-dependent | ± |

---

## Running the Integration

### Prerequisites

1. External resource files in `others/` directory:
   - `others/OmniAll.xlsx`
   - `others/Signor.xlsx`
   - `others/TRUST.xlsx`

2. Merged predictions file exists:
   - `shiny_app/data/predictions.csv`

### Command

```bash
python scripts/python/data_processing/integrate_external_resources.py \
  --input shiny_app/data/predictions.csv \
  --output shiny_app/data/predictions.csv \
  --others-dir others/
```

### Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `--input` | Input predictions CSV | Required |
| `--output` | Output predictions CSV (can be same as input) | Required |
| `--others-dir` | Directory containing Excel files | `others/` |

---

## Output

The script adds new rows to the predictions dataset with:

| Column | Value |
|--------|-------|
| `Source` | "OmniPath", "SIGNOR", or "TRRUST" |
| `Mechanism_Probability` | 1.0 (curated, not predicted) |
| `Type_Confidence` | 1.0 (curated, not predicted) |
| `Has_Mechanism` | "Yes" |
| `Autoregulatory_Type` | Mapped mechanism type |
| `Polarity` | Mapped polarity symbol |
| `Gene_Name` | Gene symbol from external DB |
| `AC` | `SOORENA-<SourceCode>-<PMID>-<n>` |

**Source codes in AC:**
- `O` = OmniPath
- `S` = SIGNOR
- `T` = TRRUST
- `U` = UniProt (original training data)
- `P` = Predicted (Non-UniProt)

---

## Updating External Resources

To update external resources with newer versions:

### OmniPath

```r
library(OmnipathR)
library(dplyr)
library(writexl)

# Get all interactions
all_data <- all_interactions(dorothea_levels = c("A", "B"))

# Filter self-loops
self_loops <- all_data %>%
  filter(source_genesymbol == target_genesymbol)

# Save
write_xlsx(self_loops, "others/OmniAll.xlsx")
```

### SIGNOR

1. Download from https://signor.uniroma2.it/downloads.php
2. Filter for self-loops where ENTITYA == ENTITYB
3. Save as `others/Signor.xlsx`

### TRRUST

1. Download from https://www.grnpedia.org/trrust/downloadnetwork.php
2. Filter for self-loops where column 1 == column 2
3. Save as `others/TRUST.xlsx`

---

## Pipeline Integration

The external resources integration is part of the merge & deploy pipeline:

```
1. merge_enriched_predictions.py    → shiny_app/data/predictions.csv
2. integrate_external_resources.py  → shiny_app/data/predictions.csv (updated)
3. create_sqlite_db.py              → shiny_app/data/predictions.db
```

### Using the Shell Script

The `run_merge_and_deploy.sh` script automatically runs the integration:

```bash
./scripts/run_merge_and_deploy.sh
```

This will:
1. Merge enriched datasets
2. Integrate external resources (if files exist in `others/`)
3. Build SQLite database
4. Optionally deploy to production

---

## Data Statistics

Approximate counts from each external resource:

| Database | Total Self-Loops | With PMIDs |
|----------|-----------------|------------|
| OmniPath | ~76 | ~70+ |
| SIGNOR | ~3,274 | ~3,200+ |
| TRRUST | ~59 | ~59 |

Note: Some entries may share PMIDs with existing predictions. These are kept as separate rows to show both the prediction and the external validation.

---

## Troubleshooting

**Issue:** "Warning: others/OmniAll.xlsx not found, skipping"

**Solution:** Ensure Excel files are in the `others/` directory with exact filenames.

---

**Issue:** Missing columns in output

**Solution:** The script aligns columns with the existing predictions. Missing columns are filled with `None`.

---

**Issue:** Duplicate entries

**Solution:** The script removes duplicates within each external resource (same PMID + Source + Gene), but keeps entries that exist in both predictions and external resources as separate rows.

---

## Related Documentation

- Main workflow: `docs/README.md`
- Prediction guide: `docs/README_PREDICTION_NEW_DATA.md`
- Architecture: `docs/README_ARCHITECTURE.md`