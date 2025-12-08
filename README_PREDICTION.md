# SOORENA Prediction Pipeline Guide

This guide explains how to run predictions on new PubMed data using the SOORENA pipeline.

## Table of Contents

1. [Overview](#overview)
2. [System Requirements](#system-requirements)
3. [Environment Setup](#environment-setup)
4. [Input Data Format](#input-data-format)
5. [Running Predictions](#running-predictions)
6. [Output Files](#output-files)
7. [Platform-Specific Instructions](#platform-specific-instructions)
8. [Troubleshooting](#troubleshooting)

---

## Overview

The SOORENA prediction pipeline processes PubMed abstracts to identify autoregulatory mechanisms using a two-stage deep learning model:

- **Stage 1**: Binary classification (has mechanism vs no mechanism)
- **Stage 2**: Multi-class classification (7 mechanism types)

The pipeline is designed to be **reusable** and can process millions of papers with:
- Automatic checkpoint saving (every 10,000 predictions)
- Resume capability if interrupted
- Cross-platform compatibility (Windows/macOS/Linux)
- GPU support (optional, CPU fallback)

---

## System Requirements

### Minimum Requirements

- **RAM**: 8 GB (16 GB+ recommended for large datasets)
- **Disk Space**: 10 GB free
- **Python**: 3.11
- **R**: 4.x (for Shiny app)

### Recommended for Large Datasets (3M+ papers)

- **RAM**: 32 GB+
- **GPU**: NVIDIA GPU with 8 GB+ VRAM (CUDA support)
- **Disk Space**: 50 GB+ free

### Operating Systems

- macOS (Apple Silicon or Intel)
- Linux (Ubuntu 20.04+, CentOS 7+)
- Windows 10/11

---

## Environment Setup

### Option 1: Using Conda (Recommended)

```bash
# Clone/navigate to repository
cd SOORENA_2

# Create environment
conda env create -f environment.yml

# Activate environment
conda activate autoregulatory

# Install PyTorch
# For CPU only (all platforms):
pip install torch --index-url https://download.pytorch.org/whl/cpu

# For GPU (CUDA 11.8):
pip install torch --index-url https://download.pytorch.org/whl/cu118

# For GPU (CUDA 12.1):
pip install torch --index-url https://download.pytorch.org/whl/cu121
```

### Option 2: Using pip

```bash
# Create virtual environment
python -m venv venv

# Activate environment
# On macOS/Linux:
source venv/bin/activate
# On Windows:
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Install PyTorch (see above for platform-specific versions)
```

### Verify Installation

```bash
python -c "import torch; print(f'PyTorch: {torch.__version__}')"
python -c "import transformers; print(f'Transformers: {transformers.__version__}')"
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
```

---

## Input Data Format

### Getting the Data to Your Friend

**Option 1: Cloud Transfer (Recommended for Large Files)**
- Upload `data/pred/abstracts-authors-date.tsv` to Google Drive, Dropbox, or similar
- Share the link with your friend
- They download and place it at: `SOORENA_2/data/pred/abstracts-authors-date.tsv`

**Option 2: Direct Transfer**
- If on same network, use `scp` or file sharing
- Example: `scp data/pred/abstracts-authors-date.tsv friend@computer:/path/to/SOORENA_2/data/pred/`

**Option 3: External Drive**
- Copy file to USB/external drive
- Friend copies to their `SOORENA_2/data/pred/` directory

**Important:** The TSV file must be placed at exactly: `data/pred/abstracts-authors-date.tsv` relative to the repository root.

### Expected TSV Format

The pipeline expects a **TSV file** with the following columns:

| Column | Description | Required |
|--------|-------------|----------|
| `PMID` | PubMed ID (unique identifier) | Yes |
| `Title` | Paper title | Yes |
| `Abstract` | Paper abstract | Yes |
| `Journal` | Journal name | No |
| `PublicationDate` | Publication date (any format) | No |
| `Authors` | Author list | No |

### Example Input File

```tsv
PMID	Title	Abstract	Journal	PublicationDate	Authors
19994476	Reversible enzymatic synthesis...	An enzyme has been...	The Journal of biological chemistry	1950-Feb	SCHRECKER AW; KORNBERG A
16721999	Studies on respiratory enzymes...	On the basis of his observations...	The Journal of biological chemistry	1961-Jan	Spiro MJ; Ball EG
```

### Date Format

The `PublicationDate` column can have various formats:
- `YYYY-MMM` (e.g., `1950-Feb`)
- `YYYY-MMM-DD` (e.g., `1966-Apr-10`)
- `YYYY` (e.g., `2023`)

The pipeline will automatically parse:
- **Year**: 4-digit year
- **Month**: 3-letter abbreviation (Jan, Feb, Mar, etc.)

Missing or malformed dates will be labeled as `Unknown`.

---

## Running Predictions

### Quick Start (Automated)

**macOS/Linux:**
```bash
./run_new_predictions.sh
```

**Windows:**
```cmd
run_new_predictions.bat
```

### Manual Step-by-Step

#### Step 1: Prepare Input Data

Place your TSV file at:
```
data/pred/abstracts-authors-date.tsv
```

#### Step 2: Run Predictions

```bash
python predict_new_data.py \
  --input data/pred/abstracts-authors-date.tsv \
  --output results/new_predictions.csv \
  --checkpoint-interval 10000
```

**Options:**
- `--input`: Path to input TSV file (required)
- `--output`: Path to output CSV file (default: `results/new_predictions.csv`)
- `--checkpoint-interval`: Save checkpoint every N predictions (default: 10000)
- `--test-mode`: Process only first 100 rows (for testing)

#### Step 3: Merge with Existing Data

```bash
python merge_all_predictions.py
```

This script:
1. Loads existing Shiny app data
2. Adds "No Date" / "Unknown" to old predictions
3. Merges with new predictions
4. Removes duplicates (new data takes precedence)
5. Saves updated file to `shiny_app/data/predictions_for_app.csv`

#### Step 4: Launch Shiny App

```bash
cd shiny_app
Rscript -e "shiny::runApp('app.R')"
```

---

## Output Files

### 1. `results/new_predictions.csv`

Contains predictions for all papers in the input file:

```csv
PMID,Title,Abstract,Journal,Authors,PublicationDate,Year,Month,has_mechanism,stage1_confidence,mechanism_type,stage2_confidence
19994476,"Reversible...","An enzyme...","JBC","SCHRECKER AW...","1950-Feb","1950","Feb",False,0.9947,none,0.0
```

**Columns:**
- `PMID, Title, Abstract, Journal, Authors, PublicationDate`: From input
- `Year, Month`: Parsed from PublicationDate
- `has_mechanism`: Boolean (True/False)
- `stage1_confidence`: Confidence score (0-1) for Stage 1
- `mechanism_type`: One of 7 types or "none"
- `stage2_confidence`: Confidence score (0-1) for Stage 2

### 2. `shiny_app/data/predictions_for_app.csv`

Merged dataset for the Shiny app, with additional columns:
- `Protein ID, AC, OS`: From AutoregDB (if available)
- `Has Mechanism`: "Yes" or "No"
- `Mechanism Probability`: Stage 1 confidence as percentage
- `Source`: "UniProt" or "Non-UniProt"
- `Autoregulatory Type`: Mechanism type or "non-autoregulatory"
- `Type Confidence`: Stage 2 confidence as percentage

---

## Platform-Specific Instructions

### macOS (Apple Silicon M1/M2/M3)

```bash
# PyTorch CPU (optimized for Apple Silicon)
pip install torch

# Test GPU acceleration (MPS)
python -c "import torch; print(f'MPS available: {torch.backends.mps.is_available()}')"
```

### macOS (Intel)

```bash
# PyTorch CPU
pip install torch --index-url https://download.pytorch.org/whl/cpu
```

### Linux (with NVIDIA GPU)

```bash
# Check CUDA version
nvidia-smi

# Install PyTorch for CUDA 11.8
pip install torch --index-url https://download.pytorch.org/whl/cu118

# Or for CUDA 12.1
pip install torch --index-url https://download.pytorch.org/whl/cu121
```

### Windows

```cmd
# Check if NVIDIA GPU is available
nvidia-smi

# For CPU only
pip install torch --index-url https://download.pytorch.org/whl/cpu

# For GPU (CUDA 11.8)
pip install torch --index-url https://download.pytorch.org/whl/cu118
```

---

## Troubleshooting

### Issue: Out of Memory Error

**Symptoms:**
```
RuntimeError: CUDA out of memory
```

**Solutions:**
1. Use CPU instead of GPU:
   ```bash
   # Force CPU usage
   export CUDA_VISIBLE_DEVICES=""
   python predict_new_data.py ...
   ```

2. Process in smaller batches (edit `config.py`):
   ```python
   BATCH_SIZE = 8  # Reduce from 16
   ```

### Issue: PyTorch Not Found

**Symptoms:**
```
ModuleNotFoundError: No module named 'torch'
```

**Solution:**
```bash
pip install torch --index-url https://download.pytorch.org/whl/cpu
```

### Issue: Checkpoint File Exists

**Symptoms:**
```
Found checkpoint file: results/new_predictions_checkpoint.csv
```

**Solution:**
The script will automatically resume from the checkpoint. To start fresh:
```bash
rm results/new_predictions_checkpoint.csv
```

### Issue: Model Files Not Found

**Symptoms:**
```
FileNotFoundError: models/stage1_best.pt
```

**Solution:**
Ensure you have the trained models. Contact the repository owner or train the models using:
```bash
python train_stage1.py
python train_stage2.py
```

### Issue: Slow Performance

**Solutions:**

1. **Use GPU** (if available):
   ```bash
   # Verify GPU is detected
   python -c "import torch; print(torch.cuda.is_available())"
   ```

2. **Increase batch size** (if you have enough RAM/VRAM):
   Edit `config.py`:
   ```python
   BATCH_SIZE = 32  # Increase from 16
   ```

3. **Use test mode** to verify setup first:
   ```bash
   python predict_new_data.py --test-mode --input data/pred/abstracts-authors-date.tsv --output test_output.csv
   ```

### Issue: Date Parsing Issues

**Symptoms:**
Most dates appear as "Unknown"

**Solution:**
Check the `PublicationDate` column format in your input file:
```bash
head -5 data/pred/abstracts-authors-date.tsv
```

Supported formats:
- `1950-Feb`, `1961-Jan`, `1966-Apr-10`
- `February 1950`, `Jan 1961`

If your format is different, modify the `parse_publication_date()` function in `predict_new_data.py`.

---

## Performance Estimates

| Dataset Size | CPU (8 cores) | GPU (NVIDIA RTX 3080) |
|--------------|---------------|----------------------|
| 1,000 papers | ~5 minutes | ~1 minute |
| 10,000 papers | ~45 minutes | ~8 minutes |
| 100,000 papers | ~7 hours | ~1.5 hours |
| 1,000,000 papers | ~3 days | ~15 hours |
| 3,300,000 papers | ~9 days | ~45 hours |

*Note: Times are approximate and depend on hardware, text length, and system load.*

---

## Getting Help

If you encounter issues not covered here:

1. Check the [main README](README.md) for general setup
2. Verify environment with:
   ```bash
   python -c "from predict import MechanismPredictor; print(' Predictor can be imported')"
   ```
3. Run in test mode first:
   ```bash
   ./run_new_predictions.sh --test
   ```
4. Contact the repository maintainers with:
   - Error message
   - Operating system
   - Python version (`python --version`)
   - PyTorch version (`python -c "import torch; print(torch.__version__)"`)

---

## Citation

If you use this pipeline in your research, please cite:

```
[SOORENA preprint citation]
bioRxiv, November 2025
```

---

**Last Updated**: December 7, 2025
**Pipeline Version**: 0.0.9
