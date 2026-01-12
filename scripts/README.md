# SOORENA Automation Scripts

This directory contains shell scripts that automate the complete SOORENA pipeline.

## Quick Start

Run the entire pipeline end-to-end:

```bash
./scripts/run_full_pipeline.sh
```

## Individual Scripts

### 1. Training Pipeline

```bash
./scripts/run_training.sh
```

**What it does:**

- Prepares data from raw .rds files
- Trains Stage 1 model (binary classification)
- Trains Stage 2 model (7-class mechanism classification)
- Evaluates both models on test set
- Generates predictions on unused unlabeled data

**Runtime:** 1 hour (GPU) | 5 hours (CPU)

**Outputs:**

- `models/stage1_best.pt`
- `models/stage2_best.pt`
- `data/processed/stage1_test_eval.csv`
- `data/processed/stage2_test_eval.csv`
- `results/unused_unlabeled_predictions.csv`

---

### 2. Unused Unlabeled Flow

```bash
./scripts/run_unused_predictions.sh
```

**What it does:**

- Filters predictions to autoregulatory only
- Merges with labeled training data
- Enriches with PubTator/UniProt metadata

**Runtime:** 30 minutes (GPU) | 2 hours (CPU)

**Outputs:**

- `results/unused_predictions_autoregulatory_only_metadata_enriched.csv`

---

### 3. New 3M Predictions

```bash
./scripts/run_new_predictions.sh
```

**What it does:**

- Runs predictions on 3M PubMed dataset
- Filters to autoregulatory only
- Enriches with PubTator/UniProt metadata

**Runtime:** 2-3 days (GPU) | 1-2 weeks (CPU)

**Features:**

- Automatic checkpointing every 10,000 predictions
- Resume support (just re-run if interrupted)

**Outputs:**

- `results/new_predictions_autoregulatory_only_enriched.csv`

---

### 4. Merge & Deploy

```bash
./scripts/run_merge_and_deploy.sh
```

**What it does:**

- Merges unused + 3M enriched datasets
- Enriches external resources with Title, Abstract, Journal, Authors, Date, Protein Name (cached)
- Integrates external resources (OmniPath, SIGNOR, TRRUST)
- Builds SQLite database for Shiny app
- Optionally deploys to DigitalOcean

**Runtime:** 10-15 minutes (first run with enrichment), 10 minutes (subsequent runs with cache)

**Outputs:**

- `shiny_app/data/predictions.csv` (includes external resources)
- `shiny_app/data/predictions.db`
- `others/OtherResources_enriched.csv` (cached enriched external resources)

**External Resources (optional):**

Place this file in `others/` directory to include curated self-loop data:

- `others/OtherResources.xlsx` (preprocessed OmniPath, SIGNOR, TRRUST data)

The script will automatically enrich this file with metadata on first run and cache the results.
To re-enrich from scratch, delete `others/OtherResources_enriched.csv`.

If the file is missing, the script continues without external resources.

---

### 5. Full Pipeline (Orchestrator)

```bash
./scripts/run_full_pipeline.sh
```

**What it does:**

Runs all 4 scripts in sequence with:

- Interactive prompts
- Prerequisite checking
- GPU detection
- Runtime estimates
- Progress tracking
- Final summary

**Runtime:** Varies (see individual script runtimes)

---

## Common Workflows

### First-time Setup

```bash
./scripts/run_full_pipeline.sh
```

### Resume 3M Predictions

```bash
# If 3M predictions were interrupted, just re-run
./scripts/run_new_predictions.sh
# Automatically resumes from checkpoint
```

### Update Database Only

```bash
# If you already have enriched CSVs and just need to rebuild DB
./scripts/run_merge_and_deploy.sh
```

### Deploy to Production

```bash
# Deploy without rebuilding database
rsync -avz shiny_app/data/predictions.db root@143.198.38.37:/srv/shiny-server/soorena/data/predictions.db
ssh root@143.198.38.37 "chown -R shiny:shiny /srv/shiny-server/soorena && systemctl restart shiny-server"
```

---

## Environment Variables

**DO_HOST** - DigitalOcean droplet IP (default: 143.198.38.37)

```bash
export DO_HOST="your.server.ip"
./scripts/run_merge_and_deploy.sh
```

---

## Error Handling

All scripts use `set -e` to exit immediately on errors. This ensures:

- Failed steps don't cascade
- You can identify exactly which step failed
- Resume from the failed step after fixing

Example:

```bash
# If run_full_pipeline.sh fails during Phase 2
./scripts/run_unused_predictions.sh  # Fix and re-run Phase 2 only
./scripts/run_new_predictions.sh     # Then continue with Phase 3
./scripts/run_merge_and_deploy.sh    # Then finish with Phase 4
```

---

## Prerequisites

**Required files:**

- `data/raw/autoregulatoryDB.rds` (from Git LFS)
- `data/raw/pubmed.rds` (from Git LFS)

**Optional (for 3M predictions):**

- `data/pred/abstracts-authors-date.tsv` (from Google Drive)

**Download 3M dataset:**

<https://drive.google.com/drive/folders/1cHp6lodUptxHGtIgj3Cnjd7nNBYWHItM>

---

## Monitoring Progress

### Check GPU usage

```bash
watch -n 1 nvidia-smi
```

### Check checkpoint progress

```bash
wc -l results/new_predictions_checkpoint.csv
```

---

## Troubleshooting

### Script won't run (Permission denied)

```bash
chmod +x scripts/run_*.sh
```

### Missing prerequisites

The scripts will tell you exactly which files are missing. Download from Git LFS or Google Drive as indicated.

### Out of memory during training

- Reduce batch size in config.py
- Close other applications
- Consider using CPU if GPU memory is limited

### Checkpoint file corrupted

```bash
rm results/new_predictions_checkpoint.csv
./scripts/run_new_predictions.sh
```

---

## Script Architecture

```text
run_full_pipeline.sh (orchestrator)
    |
    +-> run_training.sh
    |   +-> prepare_data.py
    |   +-> train_stage1.py
    |   +-> train_stage2.py
    |   +-> evaluate.py
    |   +-> predict_unused_unlabeled.py
    |
    +-> run_unused_predictions.sh
    |   +-> filter_non_autoregulatory.py
    |   +-> merge_final_shiny_data.py
    |   +-> enrich_pubtator_csv.py
    |
    +-> run_new_predictions.sh
    |   +-> predict_new_data.py
    |   +-> filter_non_autoregulatory.py
    |   +-> enrich_pubtator_csv.py
    |
    +-> run_merge_and_deploy.sh
        +-> merge_enriched_predictions.py
        +-> enrich_external_resources.py  <-- NEW (enrich OtherResources.xlsx)
        +-> integrate_external_resources.py  <-- NEW (OmniPath, SIGNOR, TRRUST)
        +-> create_sqlite_db.py
        +-> rsync + ssh (deploy)
```

---

For detailed documentation on each Python script, see [docs/README.md](../docs/README.md).
