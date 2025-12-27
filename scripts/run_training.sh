#!/bin/bash
# SOORENA Training Pipeline
# Runs: Data preparation, Stage 1 training, Stage 2 training, Evaluation, Unused predictions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "=================================="
echo "SOORENA Training Pipeline"
echo "=================================="
echo ""

echo "[1/5] Data preparation..."
python scripts/python/data_processing/prepare_data.py
echo "Complete."
echo ""

echo "[2/5] Training Stage 1 (binary classification)..."
python scripts/python/training/train_stage1.py
echo "Complete."
echo ""

echo "[3/5] Training Stage 2 (multiclass classification)..."
python scripts/python/training/train_stage2.py
echo "Complete."
echo ""

echo "[4/5] Evaluating models..."
python scripts/python/training/evaluate.py
echo "Complete."
echo ""

echo "[5/5] Predicting on unused unlabeled data..."
python scripts/python/prediction/predict_unused_unlabeled.py
echo "Complete."
echo ""

echo "=================================="
echo "Training pipeline complete."
echo "=================================="
echo ""
echo "Generated files:"
echo "  models/stage1_best.pt"
echo "  models/stage2_best.pt"
echo "  data/processed/stage1_test_eval.csv"
echo "  data/processed/stage2_test_eval.csv"
echo "  results/unused_unlabeled_predictions.csv"
echo ""
