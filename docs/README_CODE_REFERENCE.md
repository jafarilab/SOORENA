# SOORENA Code Reference

Complete reference documentation for all Python modules and scripts.

## Table of Contents

1. [Configuration Module](#configuration-module)
2. [Utility Modules](#utility-modules)
3. [Data Processing Scripts](#data-processing-scripts)
4. [Training Scripts](#training-scripts)
5. [Prediction Scripts](#prediction-scripts)
6. [Shell Scripts](#shell-scripts)

---

## Configuration Module

### config.py

Central configuration file for the entire project.

#### Directory Paths

```python
BASE_DIR = Path(__file__).parent
DATA_DIR = BASE_DIR / "data"
RAW_DATA_DIR = DATA_DIR / "raw"
PROCESSED_DATA_DIR = DATA_DIR / "processed"
PRED_DATA_DIR = DATA_DIR / "pred"
MODELS_DIR = BASE_DIR / "models"
RESULTS_DIR = BASE_DIR / "results"
REPORTS_DIR = BASE_DIR / "reports"
SHINY_DATA_DIR = BASE_DIR / "shiny_app" / "data"
```

#### Model Paths

```python
STAGE1_MODEL_PATH = MODELS_DIR / "stage1_best.pt"
STAGE2_MODEL_PATH = MODELS_DIR / "stage2_best.pt"
MODEL_NAME = "microsoft/BiomedNLP-PubMedBERT-base-uncased-abstract-fulltext"
```

#### Hyperparameters

```python
# Training
BATCH_SIZE = 16
MAX_LENGTH = 512
LEARNING_RATE_STAGE1 = 2e-5
LEARNING_RATE_STAGE2 = 2e-5
EPOCHS_STAGE1 = 10
EPOCHS_STAGE2 = 10
WEIGHT_DECAY = 0.01
DROPOUT = 0.3

# Reproducibility
RANDOM_SEED = 42
```

#### Mechanism Labels

```python
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

---

## Utility Modules

### utils/dataset.py

PyTorch Dataset classes for loading and preprocessing text data.

#### Class: MechanismDataset

Binary classification dataset (Stage 1).

```python
class MechanismDataset(Dataset):
    """
    PyTorch Dataset for binary mechanism classification

    Args:
        texts (list): List of paper texts (title + abstract)
        labels (list): Binary labels (0 or 1)
        tokenizer: HuggingFace tokenizer
        max_length (int): Maximum sequence length

    Returns:
        dict: {
            'input_ids': torch.Tensor,
            'attention_mask': torch.Tensor,
            'labels': torch.Tensor
        }
    """

    def __init__(self, texts, labels, tokenizer, max_length=512):
        self.texts = texts
        self.labels = labels
        self.tokenizer = tokenizer
        self.max_length = max_length

    def __len__(self):
        return len(self.texts)

    def __getitem__(self, idx):
        text = str(self.texts[idx])
        label = self.labels[idx]

        encoding = self.tokenizer(
            text,
            max_length=self.max_length,
            padding='max_length',
            truncation=True,
            return_tensors='pt'
        )

        return {
            'input_ids': encoding['input_ids'].flatten(),
            'attention_mask': encoding['attention_mask'].flatten(),
            'labels': torch.tensor(label, dtype=torch.long)
        }
```

**Usage:**
```python
from transformers import BertTokenizer
from utils.dataset import MechanismDataset

tokenizer = BertTokenizer.from_pretrained(MODEL_NAME)
dataset = MechanismDataset(texts, labels, tokenizer, max_length=512)
```

#### Class: MechanismDatasetMulticlass

Multi-class classification dataset (Stage 2).

```python
class MechanismDatasetMulticlass(Dataset):
    """
    PyTorch Dataset for multi-class mechanism classification

    Args:
        texts (list): List of paper texts
        labels (list): Multi-class labels (0-6)
        tokenizer: HuggingFace tokenizer
        max_length (int): Maximum sequence length

    Returns:
        dict: {
            'input_ids': torch.Tensor,
            'attention_mask': torch.Tensor,
            'labels': torch.Tensor
        }
    """

    # Implementation similar to MechanismDataset
    # Handles 7-class classification
```

**Usage:**
```python
dataset = MechanismDatasetMulticlass(
    texts,
    labels,
    tokenizer,
    max_length=512
)
```

---

### utils/metrics.py

Evaluation metrics for model performance.

#### Function: calculate_binary_metrics

```python
def calculate_binary_metrics(y_true, y_pred):
    """
    Calculate binary classification metrics

    Args:
        y_true (array-like): Ground truth labels
        y_pred (array-like): Predicted labels

    Returns:
        dict: {
            'accuracy': float,
            'precision': float,
            'recall': float,
            'f1': float,
            'confusion_matrix': np.ndarray
        }
    """
    from sklearn.metrics import (
        accuracy_score,
        precision_score,
        recall_score,
        f1_score,
        confusion_matrix
    )

    return {
        'accuracy': accuracy_score(y_true, y_pred),
        'precision': precision_score(y_true, y_pred, average='binary'),
        'recall': recall_score(y_true, y_pred, average='binary'),
        'f1': f1_score(y_true, y_pred, average='binary'),
        'confusion_matrix': confusion_matrix(y_true, y_pred)
    }
```

**Usage:**
```python
from utils.metrics import calculate_binary_metrics

metrics = calculate_binary_metrics(y_true, y_pred)
print(f"F1 Score: {metrics['f1']:.4f}")
```

#### Function: calculate_multiclass_metrics

```python
def calculate_multiclass_metrics(y_true, y_pred):
    """
    Calculate multi-class classification metrics

    Args:
        y_true (array-like): Ground truth labels
        y_pred (array-like): Predicted labels

    Returns:
        dict: {
            'accuracy': float,
            'macro_f1': float,
            'micro_f1': float,
            'weighted_f1': float,
            'per_class_f1': list,
            'confusion_matrix': np.ndarray
        }
    """
    from sklearn.metrics import (
        accuracy_score,
        f1_score,
        confusion_matrix
    )

    return {
        'accuracy': accuracy_score(y_true, y_pred),
        'macro_f1': f1_score(y_true, y_pred, average='macro'),
        'micro_f1': f1_score(y_true, y_pred, average='micro'),
        'weighted_f1': f1_score(y_true, y_pred, average='weighted'),
        'per_class_f1': f1_score(y_true, y_pred, average=None),
        'confusion_matrix': confusion_matrix(y_true, y_pred)
    }
```

#### Function: plot_confusion_matrix

```python
def plot_confusion_matrix(cm, labels, title, save_path=None):
    """
    Plot confusion matrix heatmap

    Args:
        cm (np.ndarray): Confusion matrix
        labels (list): Class labels
        title (str): Plot title
        save_path (str, optional): Path to save figure

    Returns:
        None (displays or saves plot)
    """
    import seaborn as sns
    import matplotlib.pyplot as plt

    plt.figure(figsize=(10, 8))
    sns.heatmap(
        cm,
        annot=True,
        fmt='d',
        cmap='Blues',
        xticklabels=labels,
        yticklabels=labels
    )
    plt.title(title)
    plt.ylabel('True Label')
    plt.xlabel('Predicted Label')

    if save_path:
        plt.savefig(save_path, dpi=300, bbox_inches='tight')
    else:
        plt.show()
```

---

## Data Processing Scripts

### scripts/python/data_processing/prepare_data.py

Main data preparation script.

#### Purpose

Loads PubMed and UniProt data, merges them, cleans text, filters rare terms, and creates train/test splits.

#### Inputs

- `data/raw/pubmed.rds` - PubMed metadata
- `data/raw/autoregulatoryDB.rds` - UniProt annotations

#### Outputs

- `data/processed/modeling_dataset.csv` - Complete dataset
- `data/processed/train.csv` - Training set (70%)
- `data/processed/test.csv` - Test set (15%)
- `data/processed/val.csv` - Validation set (15%)

#### Key Functions

```python
def merge_terms(row):
    """Merge terms from RP, RT, RC columns"""
    cols = ['Term_in_RP', 'Term_in_RT', 'Term_in_RC']
    terms = []
    for col in cols:
        val = row[col]
        if pd.notna(val):
            terms.extend([t.strip() for t in str(val).split(',') if t.strip()])
    return ', '.join(sorted(set(terms))) if terms else ''

def clean_text(text):
    """Clean and normalize text"""
    if pd.isna(text):
        return ""

    text = str(text)
    text = unescape(text)               # Fix HTML entities
    text = re.sub(r'http\S+', '', text) # Remove URLs
    text = re.sub(r'\S+@\S+', '', text) # Remove emails
    text = re.sub(r'\s+', ' ', text)    # Normalize whitespace

    return text.strip()

def normalize_terms(terms):
    """Normalize spelling variations"""
    normalization_rules = {
        'autoregulatory': 'autoregulation',
        'autoinhibitory': 'autoinhibition',
        'autocatalysis': 'autocatalytic',
        'autoinduction': 'autoinducer'
    }

    normalized = []
    for term in terms.split(','):
        term = term.strip().lower()
        normalized.append(normalization_rules.get(term, term))

    return ', '.join(sorted(set(normalized)))
```

#### Usage

```bash
python scripts/python/data_processing/prepare_data.py
```

---

### scripts/python/data_processing/enrich_protein_names.py

Enriches predictions with protein names from UniProt.

#### Purpose

Queries UniProt API to add protein information to predictions.

#### Inputs

- `shiny_app/data/predictions_for_app.csv` - Predictions without protein info

#### Outputs

- `shiny_app/data/predictions_for_app.csv` - Updated with protein names
- `data/protein_cache.json` - Cache of UniProt queries

#### Key Functions

```python
def query_uniprot(pmid):
    """
    Query UniProt API for protein information

    Args:
        pmid (int): PubMed ID

    Returns:
        tuple: (protein_names, protein_ids) or (None, None)
    """
    url = "https://rest.uniprot.org/uniprotkb/search"
    params = {
        'query': f'citation:{pmid}',
        'format': 'json',
        'fields': 'accession,protein_name'
    }

    try:
        response = requests.get(url, params=params, timeout=10)
        if response.status_code == 200:
            data = response.json()
            return parse_protein_data(data)
    except Exception as e:
        print(f"Error querying PMID {pmid}: {e}")

    return None, None
```

#### Usage

```bash
python scripts/python/data_processing/enrich_protein_names.py
```

---

### scripts/python/data_processing/enrich_protein_names_parallel.py

Parallel version of protein enrichment (faster).

#### Differences from Sequential Version

- Uses `multiprocessing.Pool` for parallel requests
- Requires careful rate limiting
- Faster but higher API load

#### Usage

```bash
python scripts/python/data_processing/enrich_protein_names_parallel.py
```

---

### scripts/python/data_processing/create_sqlite_db.py

Converts CSV predictions to SQLite database.

#### Purpose

Creates optimized SQLite database for Shiny app queries.

#### Inputs

- `shiny_app/data/predictions_for_app.csv`

#### Outputs

- `shiny_app/data/predictions.db`

#### Key Functions

```python
def create_database(csv_path, db_path):
    """
    Create SQLite database from CSV

    Args:
        csv_path (str): Path to CSV file
        db_path (str): Path to output database

    Returns:
        None
    """
    import sqlite3
    import pandas as pd

    # Read CSV
    df = pd.read_csv(csv_path)

    # Create database
    conn = sqlite3.connect(db_path)

    # Write data
    df.to_sql('predictions', conn, if_exists='replace', index=False)

    # Create indexes
    conn.execute('CREATE INDEX idx_mechanism ON predictions(has_mechanism)')
    conn.execute('CREATE INDEX idx_type ON predictions(mechanism_type)')
    conn.execute('CREATE INDEX idx_conf ON predictions(stage1_confidence)')

    conn.close()
```

#### Usage

```bash
python scripts/python/data_processing/create_sqlite_db.py
```

---

### scripts/python/data_processing/merge_final_shiny_data.py

Merges all datasets for Shiny app.

#### Purpose

Combines training data with predictions and metadata.

#### Inputs

- `data/processed/modeling_dataset.csv` - Training data
- `results/unused_unlabeled_predictions.csv` - Predictions on unused data
- `results/new_predictions.csv` - Predictions on new data

#### Outputs

- `shiny_app/data/predictions_for_app.csv`

#### Usage

```bash
python scripts/python/data_processing/merge_final_shiny_data.py
```

---

### scripts/python/data_processing/rebuild_final_dataset.py

Rebuilds complete dataset from scratch.

#### Purpose

Utility to regenerate final dataset if source files change.

#### Usage

```bash
python scripts/python/data_processing/rebuild_final_dataset.py
```

---

## Training Scripts

### scripts/python/training/train_stage1.py

Trains binary classification model (Stage 1).

#### Purpose

Trains PubMedBERT to identify papers with autoregulatory mechanisms.

#### Inputs

- `data/processed/train.csv`
- `data/processed/val.csv`

#### Outputs

- `models/stage1_best.pt` - Best model checkpoint
- `models/stage1_epoch_X.pt` - Epoch checkpoints

#### Key Components

```python
class BERTClassifier(nn.Module):
    """Binary BERT classifier"""

    def __init__(self, model_name, num_labels=2, dropout=0.3):
        super().__init__()
        self.bert = BertModel.from_pretrained(model_name)
        self.dropout = nn.Dropout(dropout)
        self.classifier = nn.Linear(768, num_labels)

    def forward(self, input_ids, attention_mask):
        outputs = self.bert(
            input_ids=input_ids,
            attention_mask=attention_mask
        )
        pooled = outputs.pooler_output
        dropped = self.dropout(pooled)
        logits = self.classifier(dropped)
        return logits

def train_epoch(model, dataloader, optimizer, device):
    """Train for one epoch"""
    model.train()
    total_loss = 0

    for batch in tqdm(dataloader, desc="Training"):
        input_ids = batch['input_ids'].to(device)
        attention_mask = batch['attention_mask'].to(device)
        labels = batch['labels'].to(device)

        optimizer.zero_grad()

        logits = model(input_ids, attention_mask)
        loss = nn.CrossEntropyLoss()(logits, labels)

        loss.backward()
        optimizer.step()

        total_loss += loss.item()

    return total_loss / len(dataloader)

def evaluate(model, dataloader, device):
    """Evaluate model"""
    model.eval()
    all_preds = []
    all_labels = []

    with torch.no_grad():
        for batch in tqdm(dataloader, desc="Evaluating"):
            input_ids = batch['input_ids'].to(device)
            attention_mask = batch['attention_mask'].to(device)
            labels = batch['labels'].to(device)

            logits = model(input_ids, attention_mask)
            preds = torch.argmax(logits, dim=1)

            all_preds.extend(preds.cpu().numpy())
            all_labels.extend(labels.cpu().numpy())

    return all_preds, all_labels
```

#### Usage

```bash
python scripts/python/training/train_stage1.py
```

---

### scripts/python/training/train_stage2.py

Trains multi-class classification model (Stage 2).

#### Purpose

Trains PubMedBERT to classify mechanism types (7 classes).

#### Inputs

- `data/processed/train.csv` (filtered to only positive samples)
- `data/processed/val.csv` (filtered to only positive samples)

#### Outputs

- `models/stage2_best.pt` - Best model checkpoint
- `models/stage2_epoch_X.pt` - Epoch checkpoints

#### Key Differences from Stage 1

- Only trains on papers with mechanisms
- 7-class output instead of binary
- Different class weights for imbalance

#### Usage

```bash
python scripts/python/training/train_stage2.py
```

---

### scripts/python/training/evaluate.py

Evaluates trained models on test set.

#### Purpose

Generates comprehensive evaluation metrics and visualizations.

#### Inputs

- `models/stage1_best.pt`
- `models/stage2_best.pt`
- `data/processed/test.csv`

#### Outputs

- `reports/stage1_confusion_matrix.png`
- `reports/stage2_confusion_matrix.png`
- Console output with all metrics

#### Metrics Computed

**Stage 1:**
- Accuracy
- Precision
- Recall
- F1 Score
- Confusion Matrix

**Stage 2:**
- Accuracy
- Macro F1
- Micro F1
- Weighted F1
- Per-class F1
- Confusion Matrix

#### Usage

```bash
python scripts/python/training/evaluate.py
```

---

## Prediction Scripts

### scripts/python/prediction/predict.py

Single paper test utility.

#### Purpose

Demonstrates end-to-end inference on a single paper.

#### Usage

```python
python scripts/python/prediction/predict.py

# Example output:
# Input: "This paper describes autophosphorylation of protein X..."
# Stage 1: Has mechanism (confidence: 0.98)
# Stage 2: autophosphorylation (confidence: 0.95)
```

---

### scripts/python/prediction/predict_unused_unlabeled.py

Predicts on papers not used in training.

#### Purpose

Generates predictions on unused unlabeled data to expand dataset.

#### Inputs

- `data/processed/stage1_unlabeled_unused.csv`

#### Outputs

- `results/unused_unlabeled_predictions.csv`

#### Usage

```bash
python scripts/python/prediction/predict_unused_unlabeled.py
```

---

### scripts/python/prediction/predict_new_data.py

Main prediction script for new PubMed data.

#### Purpose

Runs two-stage pipeline on new data with batched processing.

#### Inputs

- `data/pred/new_pubmed_data.csv`

#### Outputs

- `results/new_predictions.csv`
- `results/stage1_predictions.csv` (intermediate)
- `results/stage2_predictions.csv` (intermediate)

#### Key Features

- Batched processing for efficiency
- Progress tracking with tqdm
- Checkpointing for resuming
- Memory-efficient processing

#### Usage

```bash
python scripts/python/prediction/predict_new_data.py
```

---

## Shell Scripts

### scripts/shell/run_complete_pipeline.sh

Complete prediction pipeline.

#### Purpose

Runs entire workflow from data extraction to Shiny app dataset creation.

#### Steps

1. Extract unused unlabeled data
2. Run predictions on unused data
3. Merge with training data
4. Create final Shiny dataset

#### Usage

```bash
bash scripts/shell/run_complete_pipeline.sh
```

---

### scripts/shell/run_new_predictions.sh

New data prediction pipeline (Linux/Mac).

#### Purpose

Runs predictions on new PubMed data.

#### Steps

1. Run Stage 1 predictions
2. Filter positives
3. Run Stage 2 predictions
4. Merge results

#### Usage

```bash
bash scripts/shell/run_new_predictions.sh
```

---

### scripts/shell/run_new_predictions.bat

New data prediction pipeline (Windows).

#### Purpose

Windows version of `run_new_predictions.sh`.

#### Usage

```cmd
run_new_predictions.bat
```

---

### scripts/shell/enrich_existing_data.sh

Protein enrichment pipeline.

#### Purpose

Adds protein names to existing predictions.

#### Steps

1. Run protein enrichment script
2. Update Shiny dataset
3. Recreate SQLite database

#### Usage

```bash
bash scripts/shell/enrich_existing_data.sh
```

---

## Best Practices

### Code Style

- Follow PEP 8 for Python code
- Use type hints where appropriate
- Document all functions with docstrings
- Keep functions focused and modular

### Error Handling

```python
try:
    result = risky_operation()
except SpecificException as e:
    logger.error(f"Operation failed: {e}")
    # Handle gracefully
finally:
    # Cleanup
    pass
```

### Logging

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)
logger.info("Processing started")
```

### Testing

```python
# Add unit tests for critical functions
import unittest

class TestDataProcessing(unittest.TestCase):
    def test_clean_text(self):
        input_text = "Hello&nbsp;World"
        expected = "Hello World"
        self.assertEqual(clean_text(input_text), expected)
```

---

**Last Updated:** December 2024
