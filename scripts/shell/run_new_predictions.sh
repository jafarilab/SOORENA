#/bin/bash
# ================================================================================
# SOORENA - New Predictions Pipeline
# ================================================================================
# This script runs predictions on new PubMed data and merges results with
# existing predictions for the Shiny app.
#
# Usage:
#   bash scripts/shell/run_new_predictions.sh [--test]
#
# Options:
#   --test    Run in test mode (only process first 100 rows)
#
# Requirements:
#   - Conda environment 'autoregulatory' activated
#   - Input file: data/pred/abstracts-authors-date.tsv
#   - Models trained: models/stage1_best.pt, models/stage2_best.pt
# ================================================================================

set -e  # Exit on error

# Change to repository root (2 levels up from scripts/shell/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
TEST_MODE=""
if [ "$1" == "--test" ]; then
    TEST_MODE="--test-mode"
    echo -e "${YELLOW}  Running in TEST MODE (first 100 rows only)${NC}"
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}SOORENA - New Predictions Pipeline${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Check environment
echo -e "${BLUE}[Step 1/4] Checking environment...${NC}"

if  command -v python &> /dev/null; then
    echo -e "${RED} Error: Python not found${NC}"
    echo "Please activate the conda environment:"
    echo "  conda activate autoregulatory"
    exit 1
fi

echo -e "${GREEN} Python found: $(python --version)${NC}"

# Check if input file exists
if [  -f "data/pred/abstracts-authors-date.tsv" ]; then
    echo -e "${RED} Error: Input file not found${NC}"
    echo "Expected: data/pred/abstracts-authors-date.tsv"
    exit 1
fi

echo -e "${GREEN} Input file found${NC}"

# Check if models exist
if [  -f "models/stage1_best.pt" ] || [  -f "models/stage2_best.pt" ]; then
    echo -e "${RED} Error: Model files not found${NC}"
    echo "Expected: models/stage1_best.pt and models/stage2_best.pt"
    exit 1
fi

echo -e "${GREEN} Model files found${NC}"
echo ""

# Step 2: Run predictions
echo -e "${BLUE}[Step 2/4] Running predictions...${NC}"
echo "This may take several hours for large datasets."
echo "Checkpoints are saved every 10,000 predictions."
echo ""

python scripts/python/prediction/predict_new_data.py \
    --input data/pred/abstracts-authors-date.tsv \
    --output results/new_predictions.csv \
    --checkpoint-interval 10000 \
    $TEST_MODE

if [ $? -ne 0 ]; then
    echo -e "${RED} Prediction failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN} Predictions complete${NC}"
echo ""

# Step 3: Merge with existing data
echo -e "${BLUE}[Step 3/4] Merging with existing predictions...${NC}"

python scripts/python/data_processing/merge_final_shiny_data.py

if [ $? -ne 0 ]; then
    echo -e "${RED} Merge failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN} Merge complete${NC}"
echo ""

# Step 4: Summary
echo -e "${BLUE}[Step 4/4] Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Pipeline completed successfully${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Output files:"
echo "  - results/new_predictions.csv (new predictions)"
echo "  - shiny_app/data/predictions_for_app.csv (merged data for Shiny app)"
echo ""
echo "Next steps:"
echo "  1. Launch the Shiny app to view results:"
echo "     cd shiny_app && Rscript -e \"shiny::runApp('app.R')\""
echo ""
echo "  2. Or commit changes to git and share results"
echo ""
echo -e "${GREEN}Done${NC}"
