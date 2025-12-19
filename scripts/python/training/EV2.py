import sys
from pathlib import Path

# Add repository root to Python path (4 levels up from scripts/python/training/)
REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

import pandas as pd
import torch
import numpy as np
from torch.utils.data import DataLoader
from transformers import AutoTokenizer, AutoModelForSequenceClassification
import matplotlib.pyplot as plt
import seaborn as sns
import config
from utils.dataset import MechanismDataset
from utils.metrics import get_confusion_matrix, get_classification_report


def evaluate_model(
    model_path,
    test_file,
    num_labels,
    label_column,
    label_names=None,
    stage="stage1"
):
    """Evaluate a trained model and plot confusion matrix with formatting changes."""

    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

    # Load model and tokenizer
    tokenizer = AutoTokenizer.from_pretrained(config.MODEL_NAME)
    model = AutoModelForSequenceClassification.from_pretrained(
        config.MODEL_NAME,
        num_labels=num_labels,
        use_safetensors=True
    )
    model.load_state_dict(torch.load(model_path, map_location=device))
    model = model.to(device)
    model.eval()

    # Load test data
    test_df = pd.read_csv(test_file)
    test_dataset = MechanismDataset(test_df, tokenizer, label_column=label_column)
    test_loader = DataLoader(test_dataset, batch_size=16)

    # Get predictions
    all_preds, all_labels = [], []

    with torch.no_grad():
        for batch in test_loader:
            input_ids = batch['input_ids'].to(device)
            attention_mask = batch['attention_mask'].to(device)
            labels = batch['labels']

            outputs = model(input_ids=input_ids, attention_mask=attention_mask)
            preds = torch.argmax(outputs.logits, dim=1)

            all_preds.extend(preds.cpu().numpy())
            all_labels.extend(labels.numpy())

    all_preds = np.array(all_preds)
    all_labels = np.array(all_labels)

    print("\nClassification Report:")
    print(get_classification_report(all_preds, all_labels, label_names))

    # Generate confusion matrix
    cm = get_confusion_matrix(all_preds, all_labels)

    # === CHANGES BELOW ===
    plt.figure(figsize=(10, 8))
    ax = sns.heatmap(
        cm,
        annot=True,
        fmt='d',
        cmap='Blues',
        xticklabels=label_names if label_names else range(num_labels),
        yticklabels=label_names if label_names else range(num_labels),
        annot_kws={"size": 14}  # CHANGE: larger text inside boxes
    )

    # CHANGE: improve font sizes
    ax.set_xlabel("Predicted", fontsize=16)
    ax.set_ylabel("True", fontsize=16)

    # Stage-specific tweaks
    if stage == "stage1":
        # For Stage 1: bigger fonts (already applied above)
        plt.xticks(fontsize=14)
        plt.yticks(fontsize=14)
    elif stage == "stage2":
        # For Stage 2: rotate x-axis labels, keep y horizontal
        plt.xticks(rotation=45, ha='right', fontsize=14)
        plt.yticks(rotation=0, fontsize=14)
        # CHANGE: remove title from inside plot
        plt.title("")  # clears any title
    # === END CHANGES ===

    plt.tight_layout()
    return all_preds, all_labels, cm


def main():
    """Quick visualization for Stage 1 and Stage 2 confusion matrices only."""
    import os
    os.makedirs('reports', exist_ok=True)

    # Stage 1
    print("=" * 50)
    print("STAGE 1 CONFUSION MATRIX")
    print("=" * 50)
    preds1, labels1, cm1 = evaluate_model(
        config.STAGE1_MODEL_PATH,
        'data/processed/stage1_test_eval.csv',
        config.STAGE1_NUM_LABELS,
        'binary_label',
        ['No Mechanism', 'Has Mechanism'],
        stage="stage1"
    )
    plt.savefig('reports/stage1_confusion_matrix_EV2.png', dpi=300, bbox_inches='tight')
    print("✓ Saved Stage 1 matrix (EV2)\n")

    # Stage 2
    print("=" * 50)
    print("STAGE 2 CONFUSION MATRIX")
    print("=" * 50)
    preds2, labels2, cm2 = evaluate_model(
        config.STAGE2_MODEL_PATH,
        'data/processed/stage2_test_eval.csv',
        config.STAGE2_NUM_LABELS,
        'label_id',
        list(config.LABEL_TO_ID.keys()),
        stage="stage2"
    )
    plt.savefig('reports/stage2_confusion_matrix_EV2.png', dpi=300, bbox_inches='tight')
    print("✓ Saved Stage 2 matrix (EV2)\n")


if __name__ == "__main__":
    main()
