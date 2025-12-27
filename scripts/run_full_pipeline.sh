#!/bin/bash
# SOORENA Full End-to-End Pipeline
# Orchestrates: Training, Unused predictions, 3M predictions, Merge & Deploy

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "=================================="
echo "SOORENA Full Pipeline"
echo "=================================="
echo ""
echo "This will run:"
echo "  [Phase 1] Training & Evaluation"
echo "  [Phase 2] Unused Unlabeled Predictions"
echo "  [Phase 3] New 3M PubMed Predictions"
echo "  [Phase 4] Merge & Deploy"
echo ""

# Check prerequisites
echo "Checking prerequisites..."
echo ""

MISSING_PREREQS=0

if ! command -v python &> /dev/null; then
    echo "Error: Python not found"
    MISSING_PREREQS=1
fi

if [ ! -f "data/raw/autoregulatoryDB.rds" ]; then
    echo "Error: data/raw/autoregulatoryDB.rds not found"
    MISSING_PREREQS=1
fi

if [ ! -f "data/raw/pubmed.rds" ]; then
    echo "Error: data/raw/pubmed.rds not found"
    MISSING_PREREQS=1
fi

SKIP_3M=0
if [ ! -f "data/pred/abstracts-authors-date.tsv" ]; then
    echo "Warning: data/pred/abstracts-authors-date.tsv not found (3M dataset)"
    echo "Download from: https://drive.google.com/drive/folders/1cHp6lodUptxHGtIgj3Cnjd7nNBYWHItM"
    echo ""
    read -p "Continue without 3M dataset? (will skip Phase 3) (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    SKIP_3M=1
fi

if [ $MISSING_PREREQS -eq 1 ]; then
    exit 1
fi

echo ""

# Check GPU availability
GPU_AVAILABLE=$(python -c "import torch; print(torch.cuda.is_available())" 2>/dev/null || echo "False")

if [ "$GPU_AVAILABLE" = "True" ]; then
    echo "GPU detected - using accelerated training"
else
    echo "No GPU detected - using CPU"
fi

echo ""
read -p "Start full pipeline? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

START_TIME=$(date +%s)

# Phase 1: Training
echo ""
echo "=================================="
echo "PHASE 1: TRAINING"
echo "=================================="
echo ""

./scripts/run_training.sh

# Phase 2: Unused Unlabeled
echo ""
echo "=================================="
echo "PHASE 2: UNUSED UNLABELED FLOW"
echo "=================================="
echo ""

./scripts/run_unused_predictions.sh

# Phase 3: New 3M Predictions (optional)
if [ $SKIP_3M -eq 0 ]; then
    echo ""
    echo "=================================="
    echo "PHASE 3: NEW 3M PREDICTIONS"
    echo "=================================="
    echo ""

    ./scripts/run_new_predictions.sh
else
    echo ""
    echo "Skipping Phase 3 (3M dataset not found)"
fi

# Phase 4: Merge & Deploy
echo ""
echo "=================================="
echo "PHASE 4: MERGE & DEPLOY"
echo "=================================="
echo ""

./scripts/run_merge_and_deploy.sh

# Summary
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
HOURS=$((ELAPSED / 3600))
MINUTES=$(((ELAPSED % 3600) / 60))

echo ""
echo "=================================="
echo "PIPELINE COMPLETE"
echo "=================================="
echo ""
echo "Total runtime: ${HOURS}h ${MINUTES}m"
echo ""
echo "Generated files:"
echo "  models/stage1_best.pt"
echo "  models/stage2_best.pt"
echo "  data/processed/stage1_test_eval.csv"
echo "  data/processed/stage2_test_eval.csv"
echo "  shiny_app/data/predictions.csv"
echo "  shiny_app/data/predictions.db"
echo ""
