#!/bin/bash
# SOORENA New 3M PubMed Predictions Flow
# Runs: Predict mechanisms (3M dataset), Filter to autoregulatory, Enrich with PubTator

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "=================================="
echo "New 3M PubMed Predictions"
echo "=================================="
echo ""

if [ ! -f "data/pred/abstracts-authors-date.tsv" ]; then
    echo "Error: data/pred/abstracts-authors-date.tsv not found"
    echo "Download from: https://drive.google.com/drive/folders/1cHp6lodUptxHGtIgj3Cnjd7nNBYWHItM"
    exit 1
fi

if [ ! -f "models/stage1_best.pt" ] || [ ! -f "models/stage2_best.pt" ]; then
    echo "Error: Model checkpoints not found"
    echo "Run ./scripts/run_training.sh first."
    exit 1
fi

echo "[1/3] Running predictions on 3M dataset..."
echo "Note: Checkpoints saved every 10,000 predictions. Can resume if interrupted."
if [ -f "results/new_predictions_checkpoint.csv" ]; then
    echo "Checkpoint found - resuming from previous run."
fi
echo ""

python scripts/python/prediction/predict_new_data.py \
  --input data/pred/abstracts-authors-date.tsv \
  --output results/new_predictions.csv \
  --checkpoint-interval 10000
echo "Complete."
echo ""

echo "[2/3] Filtering to autoregulatory papers..."
python scripts/python/data_processing/filter_non_autoregulatory.py \
  --input results/new_predictions.csv \
  --output results/new_predictions_autoregulatory_only.csv
echo "Complete."
echo ""

echo "[3/3] Enriching with PubTator annotations..."
python scripts/python/data_processing/enrich_pubtator_csv.py \
  --input results/new_predictions_autoregulatory_only.csv \
  --output results/new_predictions_autoregulatory_only_enriched.csv
echo "Complete."
echo ""

echo "=================================="
echo "3M predictions flow complete."
echo "=================================="
echo ""
echo "Generated files:"
echo "  results/new_predictions.csv"
echo "  results/new_predictions_autoregulatory_only.csv"
echo "  results/new_predictions_autoregulatory_only_enriched.csv"
echo ""
