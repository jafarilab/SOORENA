# Unused Unlabeled Dataset Guide

This guide documents everything that happens to the **unused unlabeled** dataset after Stage 1 training.
It mirrors the level of detail in the training documentation and is intended to be followed step-by-step.

---

## Overview

The unused unlabeled workflow turns a large pool of unseen papers into an **autoregulatory‑only** dataset
for the Shiny app.

High-level flow:
1. Generate predictions on the unused unlabeled pool
2. Filter to keep only autoregulatory papers
3. Merge with labeled autoregulatory training data

---

## Prerequisites

✅ Stage 1 training has been run (`train_stage1.py`)  
✅ File exists: `data/processed/stage1_unlabeled_unused.csv`  
✅ Models exist: `models/stage1_best.pt` and `models/stage2_best.pt`

---

## Step 1: Predict on the Unused Unlabeled Pool

### Script
`scripts/python/prediction/predict_unused_unlabeled.py`

### Purpose
Run Stage 1 + Stage 2 predictions on papers that were **never seen** during training.

### Input Dataset
`data/processed/stage1_unlabeled_unused.csv`

What it contains:
- **PMID**: PubMed ID
- **text**: Combined text used for prediction (title + abstract)
- Additional columns from the raw dataset (may vary)

### Output Dataset
`results/unused_unlabeled_predictions.csv`

What it contains:
- `PMID`
- `has_mechanism` (True/False)
- `stage1_confidence` (0–1)
- `mechanism_type` (one of 7 types or `none`)
- `stage2_confidence` (0–1)

### Command
```bash
python scripts/python/prediction/predict_unused_unlabeled.py
```

Optional flags:
```bash
--input data/processed/stage1_unlabeled_unused.csv
--output results/unused_unlabeled_predictions.csv
--checkpoint-interval 10000
```

### Checkpointing
During the run, the script writes:
- `results/unused_unlabeled_predictions_checkpoint.csv`

If the run stops, re-run the script and it will resume automatically.

---

## Step 2: Filter to Autoregulatory Only

### Script
`scripts/python/data_processing/filter_non_autoregulatory.py`

### Purpose
Remove rows where the model predicts **no mechanism**, leaving only autoregulatory papers.

### Input Dataset
`results/unused_unlabeled_predictions.csv`

### Output Dataset
`results/unused_unlabeled_predictions_autoregulatory_only.csv`

This output:
- Keeps the **same columns** as the input
- Contains **only** rows where `has_mechanism` is True/Yes/1

### Command
```bash
python scripts/python/data_processing/filter_non_autoregulatory.py \
  --input results/unused_unlabeled_predictions.csv \
  --output results/unused_unlabeled_predictions_autoregulatory_only.csv
```

---

## Step 3: Merge with Labeled Autoregulatory Data

### Script
`scripts/python/data_processing/merge_final_shiny_data.py`

### Purpose
Create the final Shiny app dataset containing **only autoregulatory papers** from:
1) Ground-truth labeled training data
2) Filtered predictions from the unused unlabeled pool

### Inputs (Detailed)

**1) Labeled training data (autoregulatory ground truth)**
- `data/processed/train.csv`
- `data/processed/val.csv`
- `data/processed/test.csv`

These come from AutoregDB and are **manually labeled**.
Only autoregulatory entries are kept in the merge output.

**2) Filtered unused predictions**
- `results/unused_unlabeled_predictions_autoregulatory_only.csv`

These are model predictions on unseen papers, filtered to autoregulatory only.

**3) AutoregDB metadata**
- `data/raw/autoregulatoryDB.rds`

Used to add:
- `AC` (UniProt accession)
- `OS` (organism)
- `Protein ID`

**4) PubMed metadata**
- `data/raw/pubmed.rds`

Used to add:
- `Title`
- `Abstract`

### Output
`results/unused_predictions_autoregulatory_only_metadata.csv`

This is the merged dataset with metadata (AC/OS/Title/Abstract) before enrichment and SQLite conversion.

### Command
```bash
python scripts/python/data_processing/merge_final_shiny_data.py \
  --unused-predictions-file results/unused_unlabeled_predictions_autoregulatory_only.csv
```

---

## Step 4: Enrich with UniProt (Optional)

After merging, enrich the final dataset with UniProt protein and gene names.

### Script
`scripts/python/data_processing/enrich_pubtator_csv.py`

### Input
- `results/unused_predictions_autoregulatory_only_metadata.csv`

### Output
- `results/unused_predictions_autoregulatory_only_metadata_enriched.csv`

### Command
```bash
python scripts/python/data_processing/enrich_pubtator_csv.py \
  --input results/unused_predictions_autoregulatory_only_metadata.csv \
  --output results/unused_predictions_autoregulatory_only_metadata_enriched.csv
```

---

## Dataset Glossary

**stage1_unlabeled_unused.csv**  
Unlabeled papers not used in training; input to prediction.

**unused_unlabeled_predictions.csv**  
Raw model predictions for the unused pool (includes both autoregulatory and non‑autoregulatory).

**unused_unlabeled_predictions_autoregulatory_only.csv**  
Filtered predictions (autoregulatory only).

**unused_predictions_autoregulatory_only_metadata.csv**  
Merged dataset with metadata (AC/OS/Title/Abstract) before enrichment.

---

## Notes

- This workflow can take a long time depending on hardware.
- Always run Step 1 after Stage 1 training so the unused file exists.
- If `stage1_unlabeled_unused.csv` is regenerated, you must re-run Steps 1–3.
