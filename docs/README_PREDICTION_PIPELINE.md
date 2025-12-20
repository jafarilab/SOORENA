# Prediction Pipeline

This document explains how to use the trained models to predict autoregulatory mechanisms on new papers.

## Overview

The prediction pipeline uses the two trained models to:
1. **Stage 1:** Identify papers that likely have mechanisms (binary classification)
2. **Stage 2:** Classify mechanism type for positive papers (multiclass classification)

## Prerequisites

✅ Models trained: `models/stage1_best.pt` and `models/stage2_best.pt`
✅ See [README_TRAINING.md](README_TRAINING.md) if models don't exist

## Quick Start

### Test on a Single Paper

```bash
python scripts/python/prediction/predict.py
```

This runs a quick test on a sample abstract to verify models work correctly.

**Example Output:**
```
Testing prediction on sample abstract...

Abstract:
"The transcription factor regulates its own expression through
a negative feedback loop..."

Prediction:
  Has Mechanism: Yes (confidence: 0.94)
  Mechanism Type: Transcription (confidence: 0.89)
```

## Complete Prediction Pipeline

Run predictions on all unused unlabeled data + merge with labeled data:

```bash
bash scripts/shell/run_complete_pipeline.sh
```

### What This Does

**Step 1: Predict on Unused Papers (~250K papers)**
- Loads `data/processed/stage1_unlabeled_unused.csv`
- These are papers that were NOT used during Stage 1 training (no data leakage!)
- Runs both Stage 1 and Stage 2 predictions
- Saves checkpoints every 10,000 predictions
- **Runtime:** 2-8 hours (depending on hardware)

**Step 2: Merge All Data Sources**
- Combines 4 data sources for Shiny app:
  1. Labeled ground truth (1,332 papers)
  2. Training negatives (2,664 papers)
  3. Predictions on unused papers (~250K)
  4. New 3M predictions (if available)
- **Output:** `shiny_app/data/predictions_for_app.csv`

### Resumable Predictions

The pipeline supports **checkpointing**:

```
✓ Checkpoint saved at 10,000 predictions
✓ Checkpoint saved at 20,000 predictions
...
```

**If interrupted:**
- Press Ctrl+C to stop
- Re-run the same command
- Automatically resumes from last checkpoint

## Predicting on New 3M PubMed Data

If you have new PubMed data to predict on:

```bash
bash scripts/shell/run_new_predictions.sh
```

### Input Format

Place your new data in `data/pred/abstracts-authors-date.tsv`:

**Required columns:**
- `PMID`: PubMed ID
- `Title`: Paper title
- `Abstract`: Paper abstract
- `Journal`: Journal name (optional)
- `Authors`: Author list (optional)
- `Year`: Publication year (optional)
- `Month`: Publication month (optional)

**Example:**
```tsv
PMID	Title	Abstract	Journal	Authors	Year	Month
38000001	Novel protein regulation	The protein...	Nature	Smith J	2024	Jan
38000002	Gene expression study	We studied...	Science	Lee K	2024	Feb
```

### What It Does

**Step 1: Load New Data**
- Reads `data/pred/abstracts-authors-date.tsv`
- Validates required columns
- Shows data summary

**Step 2: Run Predictions**
- Processes papers in batches
- Saves checkpoints every 10,000 predictions
- **Runtime:** ~5-15 hours for 3M papers

**Step 3: Merge with Existing Data**
- Combines new predictions with existing dataset
- Updates `shiny_app/data/predictions_for_app.csv`

**Step 4: Summary**
- Shows prediction statistics
- Papers with mechanisms found
- Mechanism type distribution

## Prediction Output Format

All prediction CSVs contain:

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `PMID` | str | PubMed ID | `"38000001"` |
| `has_mechanism` | bool | Has autoregulatory mechanism? | `True` |
| `stage1_confidence` | float | Confidence in has_mechanism (0-1) | `0.94` |
| `mechanism_type` | str | Predicted mechanism type | `"Transcription"` |
| `stage2_confidence` | float | Confidence in mechanism_type (0-1) | `0.89` |
| `Title` | str | Paper title (if available) | `"Novel protein..."` |
| `Abstract` | str | Paper abstract (if available) | `"The protein..."` |
| `Year` | int | Publication year (if available) | `2024` |

## Understanding Predictions

### Stage 1: Has Mechanism (Binary)

**Decision threshold:** 0.5

- `has_mechanism = True` → Stage 1 confidence ≥ 0.5
- `has_mechanism = False` → Stage 1 confidence < 0.5

**Confidence interpretation:**
- `0.9-1.0`: Very confident (has mechanism)
- `0.7-0.9`: Confident
- `0.5-0.7`: Moderate confidence
- `0.3-0.5`: Moderate confidence (no mechanism)
- `0.1-0.3`: Confident (no mechanism)
- `0.0-0.1`: Very confident (no mechanism)

### Stage 2: Mechanism Type (Multiclass)

Only runs if `has_mechanism = True`.

**7 Possible Types:**
1. Transcription
2. Translation
3. Protein stability
4. Alternative splicing
5. DNA binding
6. Localization
7. Post-translational modification

**Confidence interpretation:**
- `0.8-1.0`: High confidence in type
- `0.6-0.8`: Moderate confidence
- `0.4-0.6`: Low confidence (uncertain between types)
- `< 0.4`: Very uncertain (manual review recommended)

## File Outputs

```
results/
├── unused_unlabeled_predictions.csv  # Predictions on 250K unused papers
└── new_predictions.csv               # Predictions on 3M new papers

shiny_app/data/
└── predictions_for_app.csv          # FINAL combined dataset for Shiny app
```

## Performance

### Prediction Speed

| Hardware | Papers/minute | 250K papers | 3M papers |
|----------|---------------|-------------|-----------|
| **GPU (CUDA)** | 500-800 | ~5-8 hours | ~60-100 hours |
| **CPU** | 50-100 | ~40-80 hours | ~500-1000 hours |

### Accuracy

Based on test set evaluation:

**Stage 1 (Binary):**
- Overall accuracy: ~90%
- False positives: ~8% (papers incorrectly predicted to have mechanisms)
- False negatives: ~10% (papers with mechanisms missed)

**Stage 2 (Multiclass):**
- Overall accuracy: ~78%
- Per-type accuracy varies (70-90%)

## Data Sources in Final Dataset

The final `predictions_for_app.csv` combines:

| Source | Count | Has Mechanism | Origin | Has AC? |
|--------|-------|---------------|--------|---------|
| **UniProt (Ground Truth)** | 1,332 | Yes | AutoregDB (manually curated) | ✅ Yes |
| **Training Negatives** | 2,664 | No | PubMed (assumed negatives) | ❌ No |
| **Model Predictions (Unused)** | ~250,000 | Yes/No | PubMed (model predicted) | ❌ No |
| **New PubMed Predictions** | ~3,000,000 | Yes/No | PubMed (model predicted) | ❌ No |

**Total:** ~3.25M papers

## Common Issues

**Issue:** "Input file not found: stage1_unlabeled_unused.csv"
**Solution:** Run Stage 1 training first: `python scripts/python/training/train_stage1.py`

**Issue:** Predictions very slow
**Solution:** Normal on CPU. Use GPU for faster predictions or reduce batch size

**Issue:** "CUDA out of memory"
**Solution:** Reduce batch size in prediction script

**Issue:** Checkpoint file not resuming
**Solution:** Ensure you're running from the same directory

## Advanced Usage

### Predict on Custom Data

```python
from scripts.python.prediction.predict import MechanismPredictor

# Initialize predictor
predictor = MechanismPredictor()

# Predict on custom text
text = "Your abstract text here..."
result = predictor.predict(text, "")

print(f"Has mechanism: {result['has_mechanism']}")
print(f"Stage 1 confidence: {result['stage1_confidence']:.2f}")
print(f"Mechanism type: {result['mechanism_type']}")
print(f"Stage 2 confidence: {result['stage2_confidence']:.2f}")
```

### Batch Prediction with Custom Input

```python
import pandas as pd
from scripts.python.prediction.predict import MechanismPredictor
from tqdm import tqdm

# Load your data
df = pd.read_csv("your_data.csv")

# Initialize predictor
predictor = MechanismPredictor()

# Predict
results = []
for idx, row in tqdm(df.iterrows(), total=len(df)):
    pred = predictor.predict(row['text'], '')
    results.append(pred)

# Save results
results_df = pd.DataFrame(results)
results_df.to_csv("custom_predictions.csv", index=False)
```

## Next Steps

After predictions complete:

1. **(Optional) Enrich with protein names:**
   ```bash
   bash scripts/shell/enrich_existing_data.sh
   ```

2. **Launch Shiny app:**
   ```bash
   cd shiny_app
   Rscript -e "shiny::runApp('app.R')"
   ```

See [README_SHINY_APP.md](README_SHINY_APP.md) for Shiny app details.

## Pipeline Visualization

```
┌─────────────────────────────────────────┐
│ Data Sources                            │
├─────────────────────────────────────────┤
│ 1. Labeled (train/val/test)            │
│ 2. Training negatives                  │
│ 3. Unused unlabeled (250K)             │
│ 4. New PubMed (3M)                     │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│ Prediction Models                       │
├─────────────────────────────────────────┤
│ Stage 1: Binary (has mechanism?)       │
│ Stage 2: Multiclass (mechanism type)   │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│ Merge & Combine                         │
├─────────────────────────────────────────┤
│ predictions_for_app.csv                 │
│ (~3.25M papers)                         │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│ Shiny App (Interactive Exploration)     │
└─────────────────────────────────────────┘
```

---

**Questions?** See main [README.md](../README.md) or other documentation files.
