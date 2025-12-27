# Data Preparation Pipeline

This document explains the data preparation process that transforms raw PubMed and AutoregDB data into clean, modeling-ready datasets.

## Overview

The data preparation pipeline takes raw data and creates:
- Clean, normalized text data
- Stratified train/validation/test splits
- A master modeling dataset with all papers

## Input Files

Located in `data/raw/`:

| File | Size | Description | Source |
|------|------|-------------|--------|
| `autoregulatoryDB.rds` | R data | AutoregDB database with known autoregulatory mechanisms | Manual curation |
| `pubmed.rds` | R data | PubMed papers (titles + abstracts) | PubMed API |

## Running Data Preparation

```bash
python scripts/python/data_processing/prepare_data.py
```

**Runtime:** ~2-5 minutes

## What It Does

### Step 1: Load Raw Data

- Loads AutoregDB (known mechanisms)
- Loads PubMed metadata (titles, abstracts)
- Extracts PMIDs and mechanism types

### Step 2: Data Cleaning

**Text Normalization:**
- Combines **Title + Abstract** into a single `text` field (`Title. Abstract`)
- Decodes HTML entities
- Removes URLs and email addresses
- Normalizes whitespace (collapses repeated spaces)

**Term Normalization:**
- Standardizes spelling/variants to common labels:
  - `autoregulatory` → `autoregulation`
  - `autoinhibitory` → `autoinhibition`
  - `autocatalysis` → `autocatalytic`
  - `autoinduction` → `autoinducer`
- Lowercases all terms
- Removes rare mechanism types with fewer than `config.STAGE2_MIN_EXAMPLES` examples (default: 35)
- Creates binary `has_mechanism` flag (`Terms != ""`)

### Step 3: Create Train/Val/Test Splits

Uses **stratified splitting** to maintain class balance:

```
70% Train  (932 papers)   →  data/processed/train.csv
15% Val    (200 papers)   →  data/processed/val.csv
15% Test   (200 papers)   →  data/processed/test.csv
```

**Stratification ensures:**
- Each mechanism type proportionally represented
- Rare mechanism types appear in all splits
- Consistent class distribution for training

**Random Seed:** `42` (for reproducibility)

### Step 4: Create Master Modeling Dataset

Combines labeled + unlabeled papers:

```
1,332 labeled papers (has mechanism = True)
252,880 unlabeled papers (has mechanism = False)
―――――――――――――――――――――――――――――――――――――――――――
254,212 total papers  →  data/processed/modeling_dataset.csv
```

## Output Files

All files saved to `data/processed/`:

| File | Papers | Description |
|------|--------|-------------|
| `train.csv` | 932 | Training set (labeled papers only) |
| `val.csv` | 200 | Validation set (labeled papers only) |
| `test.csv` | 200 | Test set (labeled papers only) |
| `modeling_dataset.csv` | 254,212 | **Master dataset** (all papers) |

## Column Descriptions

### Core Columns (all files)

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `PMID` | int | PubMed ID (unique identifier) | `12345678` |
| `text` | str | Combined title + abstract (cleaned) | `"protein regulation mechanism..."` |
| `Terms` | str | Mechanism types (comma-separated) | `"autophosphorylation, autoregulation"` |
| `has_mechanism` | bool | Has autoregulatory mechanism? | `True` / `False` |

### Additional Columns

**In labeled splits (train/val/test):**
- `label`: Primary mechanism type for stratification

## Data Quality Checks

The script performs automatic validation:

✅ **No duplicate PMIDs**

✅ **No missing text fields**

✅ **Mechanism types normalized**

✅ **Split sizes correct (70/15/15)**

✅ **All papers accounted for**

## Mechanism Type Distribution

After filtering (≥ `config.STAGE2_MIN_EXAMPLES` occurrences), the pipeline keeps 7 mechanism types:

1. autophosphorylation
2. autoregulation
3. autocatalytic
4. autoinhibition
5. autoubiquitination
6. autolysis
7. autoinducer

## Reproducibility

**Key Settings:**
- `RANDOM_SEED = 42` (in `config.py`)
- `STAGE2_MIN_EXAMPLES = 35` (minimum examples per mechanism type)
- Stratified splitting enabled

**To reproduce exact splits:**
1. Use same random seed
2. Use same input data files
3. Run `prepare_data.py` from repository root

## Troubleshooting

**Issue:** "No such file: data/raw/autoregulatoryDB.rds"
**Solution:** Ensure raw data files are downloaded (see main README)

**Issue:** "ImportError: No module named pyreadr"
**Solution:** Install dependencies: `pip install -r requirements.txt`

**Issue:** Different split sizes than expected
**Solution:** Check that raw data files are up-to-date

## Next Steps

After data preparation:

1. **Train Stage 1:** Binary classification (has mechanism vs. no mechanism)
   ```bash
   python scripts/python/training/train_stage1.py
   ```

2. **Train Stage 2:** Multiclass classification (7 mechanism types)
   ```bash
   python scripts/python/training/train_stage2.py
   ```

See [README_TRAINING.md](README_TRAINING.md) for details.

## File Locations

```
data/
├── raw/
│   ├── autoregulatoryDB.rds    # Input: Known mechanisms
│   └── pubmed.rds               # Input: PubMed metadata
└── processed/
    ├── train.csv                # Output: Training split
    ├── val.csv                  # Output: Validation split
    ├── test.csv                 # Output: Test split
    └── modeling_dataset.csv     # Output: Master dataset
```

## Technical Details

**Libraries Used:**
- `pandas`: Data manipulation
- `pyreadr`: Reading R .rds files
- `scikit-learn`: Stratified train/test split

**Memory Usage:**
- Peak memory: ~500 MB
- Output file size: 331 MB (modeling_dataset.csv)

---

**Questions?** See main [README.md](../README.md) or [data/processed/README.md](../data/processed/README.md)
