# New Data Prediction Guide

This guide explains how to run predictions on the large 3M PubMed dataset,
filter to autoregulatory papers, enrich with PubTator, and merge with the
existing enriched app dataset.

---

## 1) Download Required Files (Google Drive)

Download required files (Google Drive):
https://drive.google.com/drive/folders/1cHp6lodUptxHGtIgj3Cnjd7nNBYWHItM?usp=sharing

Place the files here:
- `data/pred/abstracts-authors-date.tsv`
- `models/stage1_best.pt`
- `models/stage2_best.pt`

---

## 2) Create Environment

```bash
conda env create -f environment.yml
conda activate autoregulatory
pip install torch --index-url https://download.pytorch.org/whl/cpu
```

---

## 3) Run Predictions

This runs the 3M prediction step:

```bash
python scripts/python/prediction/predict_new_data.py \
  --input data/pred/abstracts-authors-date.tsv \
  --output results/new_predictions.csv \
  --checkpoint-interval 10000
```

---

## 4) Filter to Autoregulatory Only

After predictions, filter to keep only rows with autoregulatory mechanisms:

```bash
python scripts/python/data_processing/filter_non_autoregulatory.py \
  --input results/new_predictions.csv \
  --output results/new_predictions_autoregulatory_only.csv
```

---

## 5) PubTator Enrichment (CSV)

After filtering, enrich the CSV with protein and gene info using PubTator + UniProt.

```bash
python scripts/python/data_processing/enrich_pubtator_csv.py \
  --input results/new_predictions_autoregulatory_only.csv \
  --output results/new_predictions_autoregulatory_only_enriched.csv
```

**Output columns added:**
- `AC`
- `Protein_ID`
- `Protein_Name`
- `Gene_Name`

---

## 6) Merge with Existing Enriched Dataset

Once the 3M predictions are enriched, merge them with the enriched metadata
dataset from the unused unlabeled flow.

### Script
`scripts/python/data_processing/merge_enriched_predictions.py`

### Inputs
**Base (unused unlabeled metadata, enriched):**
- `results/unused_predictions_autoregulatory_only_metadata_enriched.csv`

**New (3M predictions enriched):**
- `results/new_predictions_autoregulatory_only_enriched.csv`

### Output
- `shiny_app/data/predictions.csv`

### Recommended Command
```bash
python scripts/python/data_processing/merge_enriched_predictions.py \
  --base results/unused_predictions_autoregulatory_only_metadata_enriched.csv \
  --new results/new_predictions_autoregulatory_only_enriched.csv \
  --output shiny_app/data/predictions.csv

```



---

## 7) Build SQLite DB (from merged enriched CSV)

Create the Shiny app database directly from the merged enriched CSV:

```bash
python scripts/python/data_processing/create_sqlite_db.py \
  --input shiny_app/data/predictions.csv \
  --output shiny_app/data/predictions.db
```

---


## Notes

- This step can take days on CPU.
- Checkpointing lets you resume from `results/new_predictions_checkpoint.csv`.
