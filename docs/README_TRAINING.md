# Model Training Pipeline

This document explains the two-stage training process for autoregulatory mechanism prediction.

## Overview

Training uses a **two-stage approach**:

1. **Stage 1:** Binary classification (has mechanism vs. no mechanism)
2. **Stage 2:** Multiclass classification (7 mechanism types)

This cascading approach improves accuracy by first filtering papers likely to have mechanisms, then classifying the specific type.

## Prerequisites

✅ Data preparation completed ([README_DATA_PREPARATION.md](README_DATA_PREPARATION.md))
✅ Files exist: `train.csv`, `val.csv`, `test.csv`, `modeling_dataset.csv`
✅ GPU recommended (but not required)

## Stage 1: Binary Classification

### Purpose
Identify papers that discuss autoregulatory mechanisms vs. those that don't.

### Running Stage 1

```bash
python scripts/python/training/train_stage1.py
```

**Runtime:** ~20-40 minutes (GPU) | ~2-4 hours (CPU)

### What It Does

**Step 1: Prepare Training Data**

Creates balanced dataset with 2:1 negative:positive ratio:

```
Positive samples: 1,332 labeled papers (has mechanism = Yes)
Negative samples: 2,664 unlabeled papers (assumed no mechanism)
―――――――――――――――――――――――――――――――――――――――――――――――――――――――――
Total: 3,996 papers
```

**Why 2:1 ratio?**
- Reflects real-world distribution (most papers don't have mechanisms)
- Prevents overfitting to positive class
- Maintains enough positive examples for learning

**Step 2: Automatically Save Sampled Data** ✨

The script now **automatically saves** the sampled datasets:

- `data/processed/stage1_unlabeled_negatives.csv` - 2,664 papers used as negatives
- `data/processed/stage1_unlabeled_unused.csv` - 250,216 papers NOT used (for prediction)

**Why save these files?**
- ✅ **Reproducibility:** Document exactly which papers were used in training
- ✅ **No data leakage:** Predict only on truly unseen papers
- ✅ **Transparency:** Others can verify your training process

**Step 3: Train Binary Classifier**

- **Base Model:** PubMedBERT (`microsoft/BiomedNLP-PubMedBERT-base-uncased-abstract-fulltext`)
- **Architecture:** BERT + linear classification head
- **Loss:** Binary cross-entropy
- **Optimizer:** AdamW (learning rate: 2e-5)
- **Batch Size:** 16
- **Max Epochs:** 5 (with early stopping)

**Step 4: Validation & Early Stopping**

Monitors validation F1 score:
- Saves best model checkpoint
- Stops if no improvement for 2 epochs
- Prevents overfitting

### Output

**Model Checkpoint:**
- `models/stage1_best.pt` - Best model weights

**Saved Datasets:**
- `data/processed/stage1_unlabeled_negatives.csv` - Papers used as training negatives
- `data/processed/stage1_unlabeled_unused.csv` - Papers for prediction (never seen during training)

**Console Output:**
```
Epoch 1/5:
  Train Loss: 0.423  |  Train F1: 0.81
  Val Loss: 0.312    |  Val F1: 0.88
  ✓ New best model saved!

Epoch 2/5:
  Train Loss: 0.287  |  Train F1: 0.89
  Val Loss: 0.298    |  Val F1: 0.90
  ✓ New best model saved!

Training complete! Best Val F1: 0.90
```

## Stage 2: Multiclass Classification

### Purpose
Classify papers WITH mechanisms into 7 specific mechanism types.

### Running Stage 2

```bash
python scripts/python/training/train_stage2.py
```

**Runtime:** ~15-30 minutes (GPU) | ~1-3 hours (CPU)

### What It Does

**Step 1: Filter Positive Papers**

Uses only papers WITH mechanisms (from train/val/test splits):

```
Train: 932 papers
Val:   200 papers
Test:  200 papers
```

**Step 2: Train Multiclass Classifier**

- **Base Model:** Same PubMedBERT
- **Architecture:** BERT + 7-way classification head
- **Loss:** Cross-entropy
- **Optimizer:** AdamW (learning rate: 2e-5)
- **Batch Size:** 16
- **Max Epochs:** 10 (with early stopping)

**7 Mechanism Types:**
1. Transcription
2. Translation
3. Protein stability
4. Alternative splicing
5. DNA binding
6. Localization
7. Post-translational modification

**Step 3: Validation & Early Stopping**

Monitors validation accuracy:
- Saves best model checkpoint
- Stops if no improvement for 3 epochs
- Handles class imbalance with weighted loss

### Output

**Model Checkpoint:**
- `models/stage2_best.pt` - Best model weights

**Console Output:**
```
Epoch 1/10:
  Train Loss: 1.823  |  Train Acc: 0.45
  Val Loss: 1.456    |  Val Acc: 0.62
  ✓ New best model saved!

Training complete! Best Val Acc: 0.78
```

## Model Evaluation

After training both stages, evaluate performance:

```bash
python scripts/python/training/evaluate.py
```

### Outputs

**Stage 1 Results:**
- `data/processed/stage1_test_eval.csv` - Predictions on test set
- Confusion matrix
- Precision, Recall, F1 scores

**Stage 2 Results:**
- `data/processed/stage2_test_eval.csv` - Predictions on test set
- Per-class metrics
- Overall accuracy

**Console Output:**
```
Stage 1 Binary Classification:
  Precision: 0.92
  Recall: 0.88
  F1 Score: 0.90
  Accuracy: 0.89

Stage 2 Multiclass Classification:
  Overall Accuracy: 0.78

  Per-class Performance:
    Transcription:     F1 = 0.85
    Translation:       F1 = 0.82
    Protein stability: F1 = 0.76
    ...
```

## Hyperparameters

Located in `config.py`:

```python
# Model settings
MODEL_NAME = "microsoft/BiomedNLP-PubMedBERT-base-uncased-abstract-fulltext"
MAX_LENGTH = 512  # Maximum sequence length
BATCH_SIZE = 16

# Training settings
LEARNING_RATE = 2e-5
WEIGHT_DECAY = 0.01
NUM_EPOCHS_STAGE1 = 5
NUM_EPOCHS_STAGE2 = 10

# Reproducibility
RANDOM_SEED = 42
```

## GPU vs CPU Training

| Hardware | Stage 1 | Stage 2 | Total |
|----------|---------|---------|-------|
| **GPU (CUDA)** | 20-40 min | 15-30 min | ~1 hour |
| **CPU** | 2-4 hours | 1-3 hours | ~5 hours |

**Check GPU availability:**
```python
import torch
print(torch.cuda.is_available())  # True if GPU available
```

## Reproducibility

All training is **fully reproducible** with:

✅ **Fixed random seed:** `RANDOM_SEED = 42`
✅ **Deterministic operations:** `torch.use_deterministic_algorithms(True)`
✅ **Saved training samples:** `stage1_unlabeled_negatives.csv` documents exact negatives used
✅ **Stratified splits:** Same papers in train/val/test every time

**To reproduce results:**
1. Use same `RANDOM_SEED`
2. Use same input data files
3. Run from repository root
4. Use same hyperparameters

## Training Data Flow

```
modeling_dataset.csv (254,212 papers)
    │
    ├─> Labeled (1,332 papers)
    │   ├─> train.csv (932)  ──────────┐
    │   ├─> val.csv (200)   ──────────┤
    │   └─> test.csv (200)  ──────────┤
    │                                   │
    └─> Unlabeled (252,880 papers)     │
        │                               │
        ├─> Sample 2,664 (negatives) ─>│──> Stage 1 Training
        │   → stage1_unlabeled_negatives.csv
        │
        └─> Remaining 250,216 (unused)
            → stage1_unlabeled_unused.csv
            → Used for prediction (NO data leakage!)
```

## Common Issues

**Issue:** "CUDA out of memory"
**Solution:** Reduce `BATCH_SIZE` in `config.py` (try 8 or 4)

**Issue:** "No module named transformers"
**Solution:** Install dependencies: `pip install -r requirements.txt`

**Issue:** Training very slow on CPU
**Solution:** Expected! Consider using GPU or reducing dataset size for testing

**Issue:** Val loss not improving
**Solution:** Normal! Early stopping will handle this automatically

## Model Architecture

```
PubMedBERT (110M parameters)
    │
    ├─> [CLS] token embedding (768 dims)
    │
    ├─> Dropout (0.1)
    │
    └─> Linear layer
         │
         ├─> Stage 1: 2 outputs (has mechanism / no mechanism)
         └─> Stage 2: 7 outputs (mechanism types)
```

## Next Steps

After training:

1. **Evaluate models:**
   ```bash
   python scripts/python/training/evaluate.py
   ```

2. **Run predictions on unseen data:**
   ```bash
   bash scripts/shell/run_complete_pipeline.sh
   ```

3. **Test single-paper prediction:**
   ```bash
   python scripts/python/prediction/predict.py
   ```

See [README_PREDICTION.md](README_PREDICTION.md) for details.

## File Locations

```
models/
├── stage1_best.pt              # Output: Stage 1 model
└── stage2_best.pt              # Output: Stage 2 model

data/processed/
├── train.csv                   # Input: Training data
├── val.csv                     # Input: Validation data
├── test.csv                    # Input: Test data
├── stage1_unlabeled_negatives.csv  # Output: Training negatives
├── stage1_unlabeled_unused.csv     # Output: Papers for prediction
├── stage1_test_eval.csv        # Output: Stage 1 evaluation
└── stage2_test_eval.csv        # Output: Stage 2 evaluation
```

## Performance Expectations

**Stage 1 (Binary):**
- Precision: 0.90-0.95
- Recall: 0.85-0.92
- F1 Score: 0.88-0.93

**Stage 2 (Multiclass):**
- Overall Accuracy: 0.75-0.82
- Per-class F1: 0.70-0.90 (varies by mechanism type)

---

**Questions?** See main [README.md](../README.md) or [docs/README_DATA_PREPARATION.md](README_DATA_PREPARATION.md)
