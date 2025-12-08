# Protein Name Enrichment Guide

## Overview
This guide explains how to enrich SOORENA predictions with protein names and gene names from UniProt.

## First-Time Setup (One-Time)

### 1. Install Dependencies
```bash
pip install requests tqdm
```

### 2. Enrich Existing Data
This will take 50-70 hours for the initial 254k rows (can run overnight):

```bash
bash enrich_existing_data.sh
```

**Progress tracking:**
- Progress bar shows current status
- Checkpoint saved every 1000 rows
- Safe to interrupt (Ctrl+C) and resume later
- Cache file stores already-fetched proteins

### 3. Update Shiny App
Edit `shiny_app/app.R` line 13:
```r
preview_df <- read.csv("data/predictions_for_app_enriched.csv", stringsAsFactors = FALSE)
```

### 4. Launch App
```r
# In R/RStudio:
setwd("shiny_app")
shiny::runApp()
```

---

## For New Predictions (Ongoing Use)

When your friend sends new data, follow this workflow:

### 1. Run Prediction Pipeline (as usual)
```bash
python predict_new_data.py --input data/pred/new_abstracts.tsv
python merge_all_predictions.py
```

This creates/updates: `shiny_app/data/predictions_for_app.csv`

### 2. Enrich with Protein Names
```bash
python enrich_protein_names.py \
  --input shiny_app/data/predictions_for_app.csv \
  --output shiny_app/data/predictions_for_app_enriched.csv \
  --cache data/protein_cache.json
```

**Note**: This will be MUCH faster than initial run due to caching!
- ~80% cache hit rate (most proteins already cached)
- Only fetches new/unseen proteins
- Typical time for 10k new rows: 1-2 hours

### 3. Launch Shiny App
Your app will now show updated data with protein names.

---

## Understanding the Output

### New Columns

**Protein Name**: Recommended protein name from UniProt
- Example: `"Mitogen-activated protein kinase 6"`
- Multiple proteins: `"ERK3; MK5"` (semicolon-separated)
- API failure fallback: Shows AC code (e.g., `"P12345"`)

**Gene Name**: Primary gene name from UniProt
- Example: `"MAPK6"`
- Multiple genes: `"MAPK6; MAPKAPK5"` (semicolon-separated)
- Empty if not available: `""`

### Edge Cases

1. **Multiple ACs per row**: All protein/gene names shown, separated by `"; "`
2. **Missing AC (NA_{PMID})**: Both columns show empty string
3. **API failure**: Protein Name shows AC code, Gene Name empty
4. **Protein not found**: Same as API failure

---

## Cache Management

### Cache File
- **Location**: `data/protein_cache.json`
- **Purpose**: Stores previous UniProt lookups to avoid re-fetching
- **Size**: ~10-50 MB for 180k proteins
- **Format**: JSON with accession → {protein_name, gene_name, timestamp}

### Operations

**View cache stats:**
```bash
python -c "import json; c=json.load(open('data/protein_cache.json')); print(f'Cached: {len(c)} proteins')"
```

**Clear cache (force re-fetch):**
```bash
rm data/protein_cache.json
```

**Backup cache:**
```bash
cp data/protein_cache.json data/protein_cache_backup_$(date +%Y%m%d).json
```

---

## Troubleshooting

### Script Interrupted
**Solution**: Just re-run the command. It will resume from last checkpoint.

### Rate Limit Errors
**Solution**: Script handles this automatically with exponential backoff. If persistent:
- Wait 1 hour and retry
- Check UniProt status: https://www.uniprot.org/help/technical

### Memory Issues
**Solution**: Process in smaller batches by splitting the CSV into chunks.

### API Changes
**Solution**: Check error log `predictions_for_app_enriched_errors.log` for patterns

---

## Performance Estimates

### Initial Enrichment (254k rows)
- **Unique ACs**: ~180k (estimate)
- **Time**: ~50 hours (with 1 req/sec rate limit)
- **Can run overnight**: Yes, with checkpoint system

### Incremental Updates (10k new rows)
- **Cache hit rate**: ~80% (most proteins seen before)
- **New ACs to fetch**: ~2k
- **Time**: ~1-2 hours

### Optimization Tips
1. **Don't clear cache** unless necessary
2. **Run overnight** for large batches
3. **Check error log** to identify systematic issues

---

## Advanced Options

### Run without checkpoint (small datasets)
```bash
python enrich_protein_names.py \
  --input input.csv \
  --output output.csv \
  --cache data/protein_cache.json \
  --checkpoint-interval 999999999
```

### Use separate cache for testing
```bash
python enrich_protein_names.py \
  --input test.csv \
  --output test_enriched.csv \
  --cache test_cache.json
```

---

## Maintenance

### Re-enrichment Schedule
- **Existing rows**: Not needed (protein names rarely change)
- **New predictions**: Always (automatic via workflow)
- **Optional**: Annual refresh to catch UniProt updates

### Backup Strategy
```bash
# Backup enriched CSV monthly
cp shiny_app/data/predictions_for_app_enriched.csv \
   backups/predictions_$(date +%Y%m%d).csv

# Backup cache monthly
cp data/protein_cache.json \
   backups/cache_$(date +%Y%m%d).json
```

---

## Support

### Error Logs
- **Enrichment errors**: `shiny_app/data/predictions_for_app_enriched_errors.log`
- **Format**: `accession,error_type,message`

### Common Issues
1. **Network timeout**: Retry automatically, no action needed
2. **404 not found**: Normal for obsolete ACs, uses AC as fallback
3. **429 rate limit**: Handled automatically with backoff

### Contact
- UniProt API docs: https://www.uniprot.org/help/api
- Rate limit info: https://www.uniprot.org/help/api_queries
