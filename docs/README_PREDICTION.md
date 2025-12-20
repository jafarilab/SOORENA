# SOORENA Prediction Pipeline

Run predictions on new PubMed data using the trained SOORENA models.

---

## Quick Start

```bash
# 1. Clone and get data files
git clone https://github.com/HalaO/SOORENA_2.git
cd SOORENA_2
git lfs install
git lfs pull

# 2. Get TSV file 
# Place at: data/pred/abstracts-authors-date.tsv

# 3. Setup environment
conda env create -f environment.yml
conda activate autoregulatory
pip install torch --index-url https://download.pytorch.org/whl/cpu  # or GPU version

# 4. Run predictions
./run_new_predictions.sh          # macOS/Linux
run_new_predictions.bat           # Windows
```

---

## Requirements

**Minimum:**
- RAM: 8 GB (16 GB+ recommended)
- Disk: 10 GB free
- Python 3.11, R 4.x

**For GPU:** NVIDIA GPU with 8 GB+ VRAM

---

## Input Format

TSV file at `data/pred/abstracts-authors-date.tsv`:

| Column | Required | Description |
|--------|----------|-------------|
| PMID | Yes | PubMed ID |
| Title | Yes | Paper title |
| Abstract | Yes | Paper abstract |
| Journal | No | Journal name |
| PublicationDate | No | e.g., `1950-Feb`, `1961-Jan-15` |
| Authors | No | Author list |

**Example:**
```tsv
PMID	Title	Abstract	Journal	PublicationDate	Authors
19994476	Reversible enzymatic...	An enzyme has...	JBC	1950-Feb	SCHRECKER AW; KORNBERG A
```

---

## Output Files

### `results/new_predictions.csv`
Raw predictions with confidence scores:
- `Year, Month`: Parsed dates (or "Unknown")
- `has_mechanism`: True/False
- `stage1_confidence`: 0-1 score
- `mechanism_type`: One of 7 types or "none"
- `stage2_confidence`: 0-1 score

### `shiny_app/data/predictions_for_app.csv`
Merged data for Shiny app (old + new predictions)

---

## Platform Setup

### macOS (Apple Silicon)
```bash
pip install torch  # Optimized for M1/M2/M3
```

### Linux/macOS (Intel) - CPU only
```bash
pip install torch --index-url https://download.pytorch.org/whl/cpu
```

### GPU (CUDA)
```bash
nvidia-smi  # Check CUDA version first
pip install torch --index-url https://download.pytorch.org/whl/cu118  # CUDA 11.8
pip install torch --index-url https://download.pytorch.org/whl/cu121  # CUDA 12.1
```

---

## Troubleshooting

### Out of Memory
```bash
export CUDA_VISIBLE_DEVICES=""  # Force CPU
```
Or reduce `BATCH_SIZE = 8` in `config.py`

### Model Files Not Found
Models should be included in the repo. Contact maintainer if missing.

### Git LFS Error
```bash
git lfs install
git lfs pull
```

### Resume Interrupted Job
Automatically resumes from checkpoint. To start fresh:
```bash
rm results/new_predictions_checkpoint.csv
```

---

## Manual Execution

```bash
# Run predictions
python predict_new_data.py \
  --input data/pred/abstracts-authors-date.tsv \
  --output results/new_predictions.csv \
  --checkpoint-interval 10000

# Merge with existing data
python scripts/python/data_processing/merge_final_shiny_data.py

# Launch Shiny app
cd shiny_app && Rscript -e "shiny::runApp('app.R')"
```

**Options:**
- `--test-mode`: Process only first 100 rows
- `--checkpoint-interval N`: Save every N predictions (default: 10,000)

---

## Performance

| Papers | CPU (8 cores) | GPU (RTX 3080) |
|--------|---------------|----------------|
| 1K | ~5 min | ~1 min |
| 10K | ~45 min | ~8 min |
| 100K | ~7 hrs | ~1.5 hrs |
| 1M | ~3 days | ~15 hrs |
| 3.3M | ~9 days | ~45 hrs |

---

## Help

Run in test mode first: `./run_new_predictions.sh --test`

Verify setup:
```bash
python -c "from predict import MechanismPredictor; print('OK')"
```

