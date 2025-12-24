# SOORENA Architecture Documentation

## Table of Contents

1. [System Overview](#system-overview)
2. [Data Flow](#data-flow)
3. [Model Architecture](#model-architecture)
4. [Module Documentation](#module-documentation)
5. [Configuration](#configuration)
6. [Database Schema](#database-schema)
7. [API Interfaces](#api-interfaces)

---

## System Overview

SOORENA is a two-stage deep learning system for identifying autoregulatory mechanisms in biological literature.

### High-Level Architecture

```
┌─────────────────┐
│  PubMed Data    │
│  UniProt Data   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Data Processing │  ← prepare_data.py
│  & Cleaning     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Stage 1 Model  │  ← Binary Classification
│  (PubMedBERT)   │     Has mechanism? Yes/No
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Stage 2 Model  │  ← Multi-class Classification
│  (PubMedBERT)   │     Which mechanism type?
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Predictions    │
│  Database       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Shiny Web App  │  ← Interactive Interface
└─────────────────┘
```

### Technology Stack

- **Machine Learning**: PyTorch, Transformers (HuggingFace)
- **Pre-trained Model**: PubMedBERT (microsoft/BiomedNLP-PubMedBERT-base-uncased-abstract-fulltext)
- **Data Processing**: pandas, numpy, pyreadr
- **Web Interface**: R Shiny
- **Database**: SQLite
- **Deployment**: Shiny Server (Ubuntu)

---

## Data Flow

### 1. Data Preparation Phase

**Input:**
- `data/raw/pubmed.rds` - PubMed metadata (262,819 papers)
- `data/raw/autoregulatoryDB.rds` - UniProt annotations (1,323,976 entries)

**Process:**
1. Load and parse RDS files
2. Extract PMIDs from UniProt references
3. Merge datasets on PMID
4. Aggregate duplicate PMIDs
5. Clean and normalize text
6. Filter mechanism terms (min 35 examples)
7. Create train/test splits

**Output:**
- `data/processed/modeling_dataset.csv` - Final dataset (254,197 papers, 1,332 labeled)
- `data/processed/train.csv` - Training set
- `data/processed/test.csv` - Test set

### 2. Training Phase

**Stage 1 - Binary Classification:**

```python
Input: Paper text (title + abstract)
Output: [No mechanism, Has mechanism]
Model: PubMedBERT + Classification Head
Loss: Cross Entropy
Optimizer: AdamW
```

**Stage 2 - Multi-class Classification:**

```python
Input: Paper text (filtered to only positive Stage 1)
Output: [autophosphorylation, autoregulation, autocatalytic,
         autoinhibition, autoubiquitination, autolysis, autoinducer]
Model: PubMedBERT + Classification Head
Loss: Cross Entropy
Optimizer: AdamW
```

### 3. Prediction Phase

**Complete Pipeline:**

1. **Extract unused data** - Identify papers not used in training
2. **Run Stage 1** - Binary classification on all papers
3. **Filter positives** - Keep papers predicted to have mechanisms
4. **Run Stage 2** - Multi-class classification on positives
5. **Merge results** - Combine predictions with metadata
6. **Enrich (optional)** - Add protein and gene names (PubTator + UniProt)
7. **Create database** - Convert to SQLite for Shiny app

**Output:**
- `results/new_predictions.csv` - 3.6M+ predictions
- `shiny_app/data/predictions.db` - SQLite database
- `shiny_app/data/predictions.csv` - CSV version

---

## Model Architecture

### PubMedBERT Configuration

```python
Model: microsoft/BiomedNLP-PubMedBERT-base-uncased-abstract-fulltext
Architecture: BERT-base
Hidden Size: 768
Attention Heads: 12
Hidden Layers: 12
Max Sequence Length: 512 tokens
Vocabulary Size: 30,522
```

### Custom Classification Heads

**Stage 1 (Binary):**
```python
BERTClassifier(
  bert: PubMedBERT (109M params)
  dropout: 0.3
  classifier: Linear(768 → 2)
)
```

**Stage 2 (Multi-class):**
```python
BERTClassifier(
  bert: PubMedBERT (109M params)
  dropout: 0.3
  classifier: Linear(768 → 7)
)
```

### Training Hyperparameters

```python
# Common settings
BATCH_SIZE = 16
MAX_LENGTH = 512
RANDOM_SEED = 42

# Stage 1
LEARNING_RATE_STAGE1 = 2e-5
EPOCHS_STAGE1 = 10
WEIGHT_DECAY = 0.01

# Stage 2
LEARNING_RATE_STAGE2 = 2e-5
EPOCHS_STAGE2 = 10
WEIGHT_DECAY = 0.01
```

---

## Module Documentation

### Core Modules

#### config.py

Central configuration file containing all paths, hyperparameters, and constants.

**Key Variables:**
- `DATA_DIR`, `MODELS_DIR`, `RESULTS_DIR` - Directory paths
- `STAGE1_MODEL_PATH`, `STAGE2_MODEL_PATH` - Model checkpoints
- `BATCH_SIZE`, `MAX_LENGTH` - Training parameters
- `MECHANISM_LABELS` - List of 7 mechanism types
- `RANDOM_SEED` - Reproducibility seed (42)

#### utils/dataset.py

PyTorch Dataset classes for mechanism classification.

**Classes:**
- `MechanismDataset` - Dataset for binary classification (Stage 1)
- `MechanismDatasetMulticlass` - Dataset for multi-class classification (Stage 2)

**Features:**
- Automatic tokenization with PubMedBERT tokenizer
- Padding and truncation to MAX_LENGTH
- Label encoding for both binary and multi-class tasks

#### utils/metrics.py

Evaluation metrics for both classification stages.

**Functions:**
- `calculate_binary_metrics(y_true, y_pred)` - Precision, recall, F1, accuracy
- `calculate_multiclass_metrics(y_true, y_pred)` - Macro/micro F1, per-class metrics
- `plot_confusion_matrix(cm, labels, title)` - Visualization

---

### Scripts Directory Structure

```
scripts/
├── python/
│   ├── data_processing/
│   │   ├── prepare_data.py              # Main data preparation
│   │   ├── enrich_pubtator_csv.py       # PubTator enrichment (CSV)
│   │   ├── create_sqlite_db.py          # CSV → SQLite conversion
│   │   ├── merge_final_shiny_data.py    # Merge autoregulatory datasets
│   │   ├── merge_enriched_predictions.py # Merge enriched prediction CSVs
│   │   └── (removed)                    # Legacy rebuild script removed
│   │
│   ├── training/
│   │   ├── train_stage1.py              # Binary classification training
│   │   ├── train_stage2.py              # Multi-class training
│   │   └── evaluate.py                  # Model evaluation
│   │
│   └── prediction/
│       ├── (removed)                    # Legacy single-paper test removed
│       ├── predict_unused_unlabeled.py  # Predict unused training data
│       └── predict_new_data.py          # Predict new PubMed data
│
└── shell/
    ├── (removed)                        # Legacy pipeline scripts removed
    ├── (removed)                        # Legacy new predictions scripts removed
    ├── (removed)                        # Legacy Windows script removed
    └── (removed)                        # Legacy enrichment removed
```

---

### Script Descriptions

#### Data Processing Scripts

**prepare_data.py**
- Loads PubMed and UniProt data
- Merges on PMID
- Normalizes mechanism terms
- Filters rare terms (< 35 examples)
- Splits into train/test sets
- Output: `data/processed/modeling_dataset.csv`

**enrich_pubtator_csv.py**
- Enriches prediction CSVs using PubTator + UniProt
- Adds AC / Protein / Gene fields
- Uses PMID → GeneID → UniProt mapping

**create_sqlite_db.py**
- Converts CSV predictions to SQLite
- Optimizes for Shiny app queries
- Creates indexes for performance

**merge_final_shiny_data.py**
- Combines training data + predictions
- Adds metadata (journal, authors)
- Creates final Shiny app dataset

#### Training Scripts

**train_stage1.py**
- Binary classification training
- Uses weighted loss for imbalance
- Saves best model based on validation F1
- Checkpoints every epoch
- Output: `models/stage1_best.pt`

**train_stage2.py**
- Multi-class classification training
- Only trains on papers with mechanisms
- Handles multi-label cases (paper can have multiple mechanisms)
- Output: `models/stage2_best.pt`

**evaluate.py**
- Loads trained models
- Runs inference on test set
- Generates confusion matrices
- Calculates all metrics
- Outputs: `reports/stage1_confusion_matrix.png`, `reports/stage2_confusion_matrix.png`

#### Prediction Scripts

**predict_new_data.py**
- Main prediction entry point for new data

**predict_unused_unlabeled.py**
- Predicts on papers not used in training
- Extracts unlabeled negatives from training
- Useful for expanding dataset

**predict_new_data.py**
- Main prediction script for new data
- Runs two-stage pipeline
- Batched processing for efficiency
- Progress tracking and checkpointing

---

## Configuration

### config.py Structure

```python
# Paths
BASE_DIR = Path(__file__).parent
DATA_DIR = BASE_DIR / "data"
MODELS_DIR = BASE_DIR / "models"
RESULTS_DIR = BASE_DIR / "results"

# Model paths
STAGE1_MODEL_PATH = MODELS_DIR / "stage1_best.pt"
STAGE2_MODEL_PATH = MODELS_DIR / "stage2_best.pt"

# Training hyperparameters
BATCH_SIZE = 16
MAX_LENGTH = 512
LEARNING_RATE_STAGE1 = 2e-5
LEARNING_RATE_STAGE2 = 2e-5
EPOCHS_STAGE1 = 10
EPOCHS_STAGE2 = 10
WEIGHT_DECAY = 0.01
RANDOM_SEED = 42

# Model configuration
MODEL_NAME = "microsoft/BiomedNLP-PubMedBERT-base-uncased-abstract-fulltext"
DROPOUT = 0.3

# Mechanism labels
MECHANISM_LABELS = [
    "autophosphorylation",
    "autoregulation",
    "autocatalytic",
    "autoinhibition",
    "autoubiquitination",
    "autolysis",
    "autoinducer"
]
```

### Environment Variables

None required. All configuration is in `config.py`.

---

## Database Schema

### SQLite Database (predictions.db)

**Table: predictions**

```sql
CREATE TABLE predictions (
    PMID INTEGER PRIMARY KEY,
    Title TEXT,
    Abstract TEXT,
    Journal TEXT,
    Authors TEXT,
    has_mechanism BOOLEAN,
    stage1_confidence REAL,
    mechanism_type TEXT,
    stage2_confidence REAL,
    protein_names TEXT,
    protein_ids TEXT
);

CREATE INDEX idx_mechanism ON predictions(has_mechanism);
CREATE INDEX idx_mechanism_type ON predictions(mechanism_type);
CREATE INDEX idx_confidence ON predictions(stage1_confidence);
```

**Columns:**
- `PMID` - PubMed ID (unique)
- `Title` - Paper title
- `Abstract` - Paper abstract
- `Journal` - Publication journal
- `Authors` - Author list
- `has_mechanism` - Boolean (Stage 1 prediction)
- `stage1_confidence` - Confidence score [0-1]
- `mechanism_type` - One of 7 types or "none"
- `stage2_confidence` - Confidence score [0-1]
- `protein_names` - Comma-separated protein names (enriched)
- `protein_ids` - Comma-separated UniProt IDs (enriched)

---

## API Interfaces

### Model Inference API

```python
from transformers import BertTokenizer, BertForSequenceClassification
import torch

# Load model
tokenizer = BertTokenizer.from_pretrained(MODEL_NAME)
model = BertForSequenceClassification.from_pretrained(
    MODEL_NAME,
    num_labels=2  # or 7 for stage 2
)
model.load_state_dict(torch.load(model_path))
model.eval()

# Inference
def predict(text):
    inputs = tokenizer(
        text,
        max_length=512,
        padding='max_length',
        truncation=True,
        return_tensors='pt'
    )

    with torch.no_grad():
        outputs = model(**inputs)
        logits = outputs.logits
        probs = torch.softmax(logits, dim=1)
        pred = torch.argmax(probs, dim=1)

    return pred.item(), probs.max().item()
```

### UniProt Enrichment API

```python
import requests

def get_protein_info(pmid):
    """
    Query UniProt API for protein information

    Args:
        pmid (int): PubMed ID

    Returns:
        dict: Protein names and IDs
    """
    url = f"https://rest.uniprot.org/uniprotkb/search"
    params = {
        'query': f'citation:{pmid}',
        'format': 'json',
        'fields': 'accession,protein_name'
    }

    response = requests.get(url, params=params)
    if response.status_code == 200:
        data = response.json()
        return parse_uniprot_response(data)
    return None
```

---

## Performance Optimization

### Training Optimizations

1. **Mixed Precision Training** - Use `torch.cuda.amp` for faster training
2. **Gradient Accumulation** - Effective larger batch sizes
3. **Learning Rate Scheduling** - Warmup + linear decay
4. **Early Stopping** - Based on validation F1

### Inference Optimizations

1. **Batch Processing** - Process multiple papers simultaneously
2. **GPU Utilization** - Use CUDA when available
3. **Model Quantization** - Reduce model size (optional)
4. **Caching** - Cache protein enrichment results

### Database Optimizations

1. **Indexes** - On mechanism_type, has_mechanism, confidence
2. **SQLite Pragmas**:
   ```sql
   PRAGMA journal_mode = WAL;
   PRAGMA synchronous = NORMAL;
   PRAGMA cache_size = -64000;  -- 64MB
   ```

---

## Reproducibility

### Random Seed Management

All random operations use `RANDOM_SEED = 42`:

```python
import random
import numpy as np
import torch

random.seed(RANDOM_SEED)
np.random.seed(RANDOM_SEED)
torch.manual_seed(RANDOM_SEED)
torch.cuda.manual_seed_all(RANDOM_SEED)
torch.backends.cudnn.deterministic = True
```

### Dataset Splits

- Training: 70% of labeled data
- Validation: 15% of labeled data
- Test: 15% of labeled data

Splits are deterministic based on RANDOM_SEED.

---

## Error Handling

### Common Issues and Solutions

**Issue: CUDA Out of Memory**
```python
# Solution: Reduce batch size
BATCH_SIZE = 8  # instead of 16
```

**Issue: UniProt API Rate Limiting**
```python
# Solution: Add delays between requests
import time
time.sleep(0.5)  # 500ms delay
```

**Issue: Long Abstracts Truncated**
```python
# Expected behavior: Max 512 tokens
# Solution: Already handled by tokenizer truncation
```

---

## Deployment Architecture

### Shiny Server Deployment

```
┌─────────────────────┐
│   Nginx (Optional)  │  Port 80/443 → 3838
│   Reverse Proxy     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   Shiny Server      │  Port 3838
│   (Ubuntu Service)  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   R Shiny App       │
│   app.R             │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   SQLite Database   │
│   predictions.db    │
│   (6.1 GB)          │
└─────────────────────┘
```

### System Requirements

**Minimum (Oracle Cloud Free Tier):**
- 1 GB RAM
- 1 vCPU
- 50 GB Storage
- Ubuntu 22.04

**Recommended (DigitalOcean):**
- 4 GB RAM
- 2 vCPUs
- 80 GB Storage
- Ubuntu 22.04/24.04

---

## Monitoring and Logging

### Application Logs

**Shiny Server Logs:**
```bash
/var/log/shiny-server.log
/var/log/shiny-server/soorena-shiny-*.log
```

**Training Logs:**
- Console output (stdout)
- Saved in training scripts with timestamps

**Prediction Logs:**
- Progress bars via tqdm
- Checkpoint files for resuming

---

## Future Enhancements

### Potential Improvements

1. **Model Fine-tuning**
   - Use larger models (BERT-large, PubMedBERT-large)
   - Ensemble methods
   - Active learning for edge cases

2. **Feature Additions**
   - Real-time predictions via API
   - Batch upload interface
   - Export functionality (CSV, JSON, BibTeX)

3. **Performance**
   - Model distillation for faster inference
   - Distributed training for larger datasets
   - GraphQL API for flexible queries

4. **Data Quality**
   - Manual curation interface
   - User feedback collection
   - Semi-supervised learning

---

## References

- [PubMedBERT Paper](https://arxiv.org/abs/2007.15779)
- [BERT Original Paper](https://arxiv.org/abs/1810.04805)
- [PyTorch Documentation](https://pytorch.org/docs/)
- [HuggingFace Transformers](https://huggingface.co/docs/transformers/)
- [R Shiny Documentation](https://shiny.rstudio.com/)

---

**Last Updated:** December 2024
