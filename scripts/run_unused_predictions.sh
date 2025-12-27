#!/bin/bash
# SOORENA Unused Unlabeled Predictions Flow
# Runs: Filter to autoregulatory, Merge with labeled data, Enrich with PubTator

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "=================================="
echo "Unused Unlabeled Predictions Flow"
echo "=================================="
echo ""

if [ ! -f "results/unused_unlabeled_predictions.csv" ]; then
    echo "Error: results/unused_unlabeled_predictions.csv not found"
    echo "Run ./scripts/run_training.sh first."
    exit 1
fi

echo "[1/3] Filtering to autoregulatory papers..."
python scripts/python/data_processing/filter_non_autoregulatory.py \
  --input results/unused_unlabeled_predictions.csv \
  --output results/unused_unlabeled_predictions_autoregulatory_only.csv
echo "Complete."
echo ""

echo "[2/3] Merging with labeled data and adding metadata..."
python scripts/python/data_processing/merge_final_shiny_data.py \
  --unused-predictions-file results/unused_unlabeled_predictions_autoregulatory_only.csv
echo "Complete."
echo ""

echo "[3/3] Enriching with PubTator annotations..."
python scripts/python/data_processing/enrich_pubtator_csv.py \
  --input results/unused_predictions_autoregulatory_only_metadata.csv \
  --output results/unused_predictions_autoregulatory_only_metadata_enriched.csv \
  --fill-pubmed
echo "Complete."
echo ""

echo "=================================="
echo "Unused unlabeled flow complete."
echo "=================================="
echo ""
echo "Generated files:"
echo "  results/unused_unlabeled_predictions_autoregulatory_only.csv"
echo "  results/unused_predictions_autoregulatory_only_metadata.csv"
echo "  results/unused_predictions_autoregulatory_only_metadata_enriched.csv"
echo ""
