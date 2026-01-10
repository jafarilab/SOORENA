#!/bin/bash
# SOORENA Merge & Deploy
# Runs: Merge enriched datasets, Integrate external resources, Build SQLite database, Deploy to production

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "=================================="
echo "Merge & Deploy"
echo "=================================="
echo ""

# Check prerequisites
MISSING_FILES=0

if [ ! -f "results/unused_predictions_autoregulatory_only_metadata_enriched.csv" ]; then
    echo "Error: results/unused_predictions_autoregulatory_only_metadata_enriched.csv not found"
    echo "Run ./scripts/run_unused_predictions.sh first."
    MISSING_FILES=1
fi

if [ ! -f "results/new_predictions_autoregulatory_only_enriched.csv" ]; then
    echo "Error: results/new_predictions_autoregulatory_only_enriched.csv not found"
    echo "Run ./scripts/run_new_predictions.sh first."
    MISSING_FILES=1
fi

if [ $MISSING_FILES -eq 1 ]; then
    exit 1
fi

# Check for external resources (optional, warn if missing)
EXTERNAL_RESOURCES=0
if [ -d "others" ]; then
    if [ -f "others/OmniAll.xlsx" ] || [ -f "others/Signor.xlsx" ] || [ -f "others/TRUST.xlsx" ]; then
        EXTERNAL_RESOURCES=1
    fi
fi

echo "[1/4] Merging enriched datasets..."
python scripts/python/data_processing/merge_enriched_predictions.py \
  --base results/unused_predictions_autoregulatory_only_metadata_enriched.csv \
  --new results/new_predictions_autoregulatory_only_enriched.csv \
  --output shiny_app/data/predictions.csv
echo "Complete."
echo ""

echo "[2/4] Integrating external resources (OmniPath, SIGNOR, TRRUST)..."
if [ $EXTERNAL_RESOURCES -eq 1 ]; then
    python scripts/python/data_processing/integrate_external_resources.py \
      --input shiny_app/data/predictions.csv \
      --output shiny_app/data/predictions.csv \
      --others-dir others/
    echo "Complete."
else
    echo "Warning: No external resources found in others/ directory. Skipping."
    echo "To add external resources, place OmniAll.xlsx, Signor.xlsx, and TRUST.xlsx in others/"
fi
echo ""

echo "[3/4] Building SQLite database..."
python scripts/python/data_processing/create_sqlite_db.py \
  --input shiny_app/data/predictions.csv \
  --output shiny_app/data/predictions.db

DB_SIZE=$(du -h shiny_app/data/predictions.db | cut -f1)
echo "Complete. Database size: $DB_SIZE"
echo ""

echo "[4/4] Deploy to production?"
echo "Target: 143.198.38.37"
echo ""
read -p "Deploy now? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Uploading database..."
    rsync -avz shiny_app/data/predictions.db root@143.198.38.37:/srv/shiny-server/soorena/data/predictions.db

    echo "Restarting Shiny Server..."
    ssh root@143.198.38.37 "chown -R shiny:shiny /srv/shiny-server/soorena && systemctl restart shiny-server"

    echo "Deployment complete."
    echo "App URL: http://143.198.38.37:3838/soorena/"
else
    echo "Deployment skipped."
    echo ""
    echo "To deploy manually:"
    echo "  rsync -avz shiny_app/data/predictions.db root@143.198.38.37:/srv/shiny-server/soorena/data/predictions.db"
    echo "  ssh root@143.198.38.37 \"chown -R shiny:shiny /srv/shiny-server/soorena && systemctl restart shiny-server\""
fi

echo ""
echo "=================================="
echo "Process complete."
echo "=================================="
echo ""
