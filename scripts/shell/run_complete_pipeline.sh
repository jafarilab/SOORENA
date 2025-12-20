#!/bin/bash
# ================================================================================
# SOORENA - Complete Clean Data Pipeline
# ================================================================================
# This script runs the complete pipeline to create a clean Shiny app dataset:
#
# 1. Extract training samples (identify which unlabeled papers were used)
# 2. Predict on unused unlabeled papers (~250K papers NOT in training)
# 3. Merge all data sources for Shiny app
#
# NOTE: This does NOT retrain models or predict on the 3M new papers.
# The 3M predictions are optional and can be added separately.
#
# Usage:
#   bash scripts/shell/run_complete_pipeline.sh
# ================================================================================

set -e  # Exit on error

# Change to repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}SOORENA - Complete Clean Data Pipeline${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Predict on unused unlabeled papers
echo -e "${BLUE}[Step 1/2] Predicting on ~250K unused unlabeled papers...${NC}"
echo "This runs predictions on papers that were NOT used during training"
echo "Note: The stage1_unlabeled_unused.csv file is automatically created during Stage 1 training"
echo ""
echo "This may take several hours depending on your hardware"
echo "Progress will be saved with checkpoints every 10,000 predictions"
echo "You can safely interrupt (Ctrl+C) and resume later"
echo ""

python scripts/python/prediction/predict_unused_unlabeled.py

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to run predictions${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Step 1 complete${NC}"
echo ""

# Step 2: Merge all data for Shiny app
echo -e "${BLUE}[Step 2/2] Merging all data sources for Shiny app...${NC}"
echo "This combines:"
echo "  - Labeled ground truth (1,332 papers)"
echo "  - Training negatives (2,664 papers)"
echo "  - Predictions on unused papers (~250K)"
echo "  - New 3M predictions (if available)"
echo ""

python scripts/python/data_processing/merge_final_shiny_data.py

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to merge data${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Step 2 complete${NC}"
echo ""

# Final summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ PIPELINE COMPLETE!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Output files created:"
echo "  1. data/processed/stage1_unlabeled_negatives.csv"
echo "  2. data/processed/stage1_unlabeled_unused.csv"
echo "  3. results/unused_unlabeled_predictions.csv"
echo "  4. shiny_app/data/predictions_for_app.csv (FINAL)"
echo ""
echo "Next steps:"
echo "  1. (Optional) Run predictions on new 3M PubMed data:"
echo "     bash scripts/shell/run_new_predictions.sh"
echo ""
echo "  2. (Optional) Enrich with protein names:"
echo "     bash scripts/shell/enrich_existing_data.sh"
echo ""
echo "  3. Launch Shiny app:"
echo "     cd shiny_app && Rscript -e \"shiny::runApp('app.R')\""
echo ""
echo -e "${GREEN}Done!${NC}"
