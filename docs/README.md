# SOORENA Documentation (End-to-End Guide)

This page is the **single starting point** for reproducing the SOORENA pipeline end‑to‑end:

1. Prepare data
2. Train Stage 1 + Stage 2 models
3. Generate predictions (unused unlabeled + new PubMed data)
4. Enrich predictions with PubTator/UniProt (+ optional PubMed metadata fill)
5. Merge datasets for the Shiny app
6. Integrate external resources (OmniPath, SIGNOR, TRRUST)
7. Build the SQLite database
8. Run locally and deploy to DigitalOcean

---

## Documentation Map

- **Data prep:** `docs/README_DATA_PREPARATION.md`
- **Training:** `docs/README_TRAINING.md`
- **Unused unlabeled workflow:** `docs/README_UNUSED_UNLABELED.md`
- **New 3M workflow:** `docs/README_PREDICTION_NEW_DATA.md`
- **External resources:** `docs/README_EXTERNAL_RESOURCES.md`
- **Shiny app usage:** `docs/README_SHINY_APP.md`
- **Architecture reference:** `docs/README_ARCHITECTURE.md`
- **DigitalOcean deployment (detailed):** `deployment/README.md`

---

## 0) Requirements

**Software**
- Git + Git LFS
- Python (Conda recommended)
- R (≥ 4.0)

**Hardware**
- Training/prediction is faster with GPU but works on CPU.
- PubTator enrichment is network-bound and can take hours for large runs.

---

## 1) Clone + Git LFS

```bash
git clone https://github.com/halaarar/SOORENA_2.git
cd SOORENA_2

git lfs install
git lfs pull
```

Git LFS is used for large files (e.g., raw `.rds` data and model checkpoints when tracked).

---

## 2) Download Required External Files (if not present)

Some large inputs may be hosted outside Git (for LFS quota/size reasons). Download from the Google Drive folder and place them exactly here:

https://drive.google.com/drive/folders/1cHp6lodUptxHGtIgj3Cnjd7nNBYWHItM

- `data/pred/abstracts-authors-date.tsv` (new PubMed corpus for 3M predictions)
- `models/stage1_best.pt` (Stage 1 checkpoint)
- `models/stage2_best.pt` (Stage 2 checkpoint)

If `models/*.pt` already exist after `git lfs pull`, you do not need to download them.

---

## 3) Create the Python Environment

**Conda (recommended)**
```bash
conda env create -f environment.yml
conda activate autoregulatory
```

If you are on CPU and need a CPU wheel for PyTorch:
```bash
pip install torch --index-url https://download.pytorch.org/whl/cpu
```

---

## 4) Data Preparation (Raw → Processed)

Inputs (Git LFS):
- `data/raw/autoregulatoryDB.rds`
- `data/raw/pubmed.rds`

Run:
```bash
python scripts/python/data_processing/prepare_data.py
```

Outputs (generated locally in `data/processed/`):
- `modeling_dataset.csv`
- `train.csv`, `val.csv`, `test.csv`

Notes:
- These processed files are **generated outputs** and may not be committed to Git due to size.
- If you don’t see `data/processed/` outputs, re-run the preparation step.

More detail: `docs/README_DATA_PREPARATION.md`

---

## 5) Train Models (Stage 1 + Stage 2) + Evaluate

Stage 1:
```bash
python scripts/python/training/train_stage1.py
```

Stage 2:
```bash
python scripts/python/training/train_stage2.py
```

Evaluation:
```bash
python scripts/python/training/evaluate.py
```

Expected outputs:
- `models/stage1_best.pt`
- `models/stage2_best.pt`
- `data/processed/stage1_unlabeled_negatives.csv`
- `data/processed/stage1_unlabeled_unused.csv`
- `data/processed/stage1_test_eval.csv`
- `data/processed/stage2_test_eval.csv`

More detail: `docs/README_TRAINING.md`

---

## 6) Predictions + Enrichment + Merge (Build the app dataset)

There are two prediction flows that eventually converge:

### A) Unused unlabeled flow (small/medium)

This produces the **base** dataset (UniProt ground truth + unused unlabeled predictions), including PubMed/UniProt metadata.

Follow: `docs/README_UNUSED_UNLABELED.md`

Final output of that flow:
- `results/unused_predictions_autoregulatory_only_metadata_enriched.csv`

### B) New PubMed flow (large ~3M)

This produces the **new** predicted dataset from `data/pred/abstracts-authors-date.tsv`.

Follow: `docs/README_PREDICTION_NEW_DATA.md`

Final output of that flow:
- `results/new_predictions_autoregulatory_only_enriched.csv`

### C) Merge enriched datasets (keeps duplicate PMIDs)

Merge the two enriched CSVs into the final app dataset:

```bash
python scripts/python/data_processing/merge_enriched_predictions.py \
  --base results/unused_predictions_autoregulatory_only_metadata_enriched.csv \
  --new results/new_predictions_autoregulatory_only_enriched.csv \
  --output shiny_app/data/predictions.csv
```

What this produces:
- `shiny_app/data/predictions.csv` (the final CSV for the app)
- A **database-specific unique row identifier**:
  - `AC = SOORENA-<SourceCode>-<PMID>-<n>` (duplicate PMIDs are kept as separate rows)
  - Source codes: `U`=UniProt, `P`=Predicted (Non-UniProt), `O`=OmniPath, `S`=SIGNOR, `T`=TRRUST
  - For detailed explanation of the AC format, see [AC Format Documentation](README_AC_FORMAT.md)
- `UniProtKB_accessions` remains as the comma-separated UniProtKB accession numbers (when available).

### D) Integrate external resources (OmniPath, SIGNOR, TRRUST)

Add curated self-loop data from external databases as additional entries:

```bash
python scripts/python/data_processing/integrate_external_resources.py \
  --input shiny_app/data/predictions.csv \
  --output shiny_app/data/predictions.csv \
  --others-dir others/
```

**External resources included:**

| Database | Description | Entries |
|----------|-------------|---------|
| OmniPath | Protein-protein interactions with self-loops | ~76 |
| SIGNOR | Phosphorylation and signaling self-loops | ~3,274 |
| TRRUST | Transcriptional autoregulation | ~59 |

These entries are marked with their respective `Source` values (OmniPath, SIGNOR, TRRUST) and have `Mechanism_Probability = 1.0` since they are curated, not predicted.

More detail: `docs/README_EXTERNAL_RESOURCES.md`

---

## 7) Build the SQLite Database (CSV → `predictions.db`)

```bash
python scripts/python/data_processing/create_sqlite_db.py \
  --input shiny_app/data/predictions.csv \
  --output shiny_app/data/predictions.db
```

This creates the SQLite database the Shiny app reads at runtime:
- `shiny_app/data/predictions.db`

---

## 8) Run the Shiny App Locally

Install R packages (first time only):
```r
install.packages(c(
  "shiny", "DT", "dplyr", "DBI", "RSQLite", "shinyjs", "htmltools",
  "plotly", "ggplot2", "shinycssloaders"
))
```

Run:
```bash
cd shiny_app
Rscript -e "shiny::runApp('app.R')"
```

More detail: `docs/README_SHINY_APP.md`

---

## 9) Deploy to DigitalOcean (Shiny Server)

### CI/CD deploy (GitHub Actions)

The workflow `.github/workflows/deploy.yml` deploys **only**:
- `shiny_app/app.R`
- `shiny_app/www/`

It **does not upload** the SQLite DB. You must update the DB on the droplet separately.

After you merge to `main`, GitHub Actions will sync files and restart Shiny Server.

If you want a staging deployment, create a dedicated branch (e.g., `staging`) and update the workflow trigger
to also run on that branch, or deploy manually via `rsync` (see below).

### Upload the database to the droplet

Copy the DB to the app directory on the droplet (example path used by the workflow):

```bash
rsync -avz shiny_app/data/predictions.db root@<DO_HOST>:/srv/shiny-server/soorena/data/predictions.db
ssh root@<DO_HOST> "chown -R shiny:shiny /srv/shiny-server/soorena && systemctl restart shiny-server"
```

Detailed server setup and troubleshooting:
- `deployment/README.md`

---

## 10) Git LFS Guidance (recommended practice)

Git LFS storage/bandwidth is limited on GitHub. For a research repo, the usual practice is:

**Keep in Git LFS (high value / hard to regenerate)**
- `models/*.pt` (trained checkpoints)
- `data/raw/*.rds` (raw curated datasets)

**Avoid committing (regeneratable intermediates)**
- `data/processed/*.csv` (can be regenerated from `data/raw` via `prepare_data.py`)
- Large prediction outputs in `results/` (can be regenerated if inputs + models exist)

If LFS quota becomes an issue, move large intermediates (and the 3M input TSV) to Drive/OSF/Zenodo
and document the exact download locations (as done above).

### Check what is currently in LFS

```bash
git lfs ls-files --size
```

### Practical recommendation for this repo

- Keep `models/stage1_best.pt` and `models/stage2_best.pt` in **Git LFS** *only if* your GitHub org/user has enough LFS quota.
- Prefer **not** tracking large, regeneratable CSVs in LFS (e.g., processed splits, intermediate prediction outputs). Keep the scripts + raw sources so others can rebuild.
- For paper/review reproducibility, archive large artifacts in a *data release* (Drive/OSF/Zenodo) and pin the URL in `docs/README.md`.
