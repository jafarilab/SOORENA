#!/bin/bash
# One-time enrichment of existing 254k rows
# Expected runtime: 50-70 hours (can run overnight)

# Change to repository root (2 levels up from scripts/shell/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

echo "=========================================="
echo "UniProt Protein Name Enrichment"
echo "=========================================="
echo ""
echo "This will enrich existing data with protein names from UniProt"
echo "Expected runtime: 50-70 hours for initial run"
echo "Subsequent runs will be much faster due to caching"
echo ""
echo "You can safely interrupt (Ctrl+C) and resume later"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

python scripts/python/data_processing/enrich_protein_names.py \
  --input shiny_app/data/predictions_for_app.csv \
  --output shiny_app/data/predictions_for_app_enriched.csv \
  --cache data/protein_cache.json \
  --checkpoint-interval 1000

echo ""
echo "=========================================="
echo "Enrichment complete!"
echo "=========================================="
echo ""
echo "Enriched data saved to:"
echo "  shiny_app/data/predictions_for_app_enriched.csv"
echo ""
echo "Next step: Update app.R to use enriched CSV"
echo "  Edit line 13 in shiny_app/app.R:"
echo "  read.csv(\"data/predictions_for_app_enriched.csv\")"
echo ""
