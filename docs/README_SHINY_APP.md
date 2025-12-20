# Shiny App - Interactive Data Exploration

This document explains how to use the R Shiny web application for exploring autoregulatory mechanism predictions.

## Overview

The Shiny app provides an interactive interface to:
- Browse all predictions (~3.25M papers)
- Filter by mechanism type, confidence, year, journal
- Search by PMID, protein, gene, keyword
- View detailed paper information
- Export filtered results
- Visualize prediction statistics

## Quick Start

### Launch the App

```bash
cd shiny_app
Rscript -e "shiny::runApp('app.R')"
```

**OR** from repository root:

```bash
cd shiny_app && Rscript -e "shiny::runApp('app.R')"
```

The app will open in your default web browser at: `http://127.0.0.1:XXXX`

### Stop the App

Press `Ctrl+C` in the terminal where the app is running.

## Prerequisites

### R Installation

**Required R version:** ≥ 4.0.0

Check your R version:
```bash
R --version
```

### Required R Packages

Install dependencies:

```r
install.packages(c(
  "shiny",
  "DT",
  "dplyr",
  "ggplot2",
  "plotly",
  "shinythemes",
  "shinyWidgets"
))
```

### Data File

**Required:** `shiny_app/data/predictions_for_app.csv`

If this file doesn't exist, run:
```bash
bash scripts/shell/run_complete_pipeline.sh
```

## App Features

### 1. Data Table (Main View)

**Interactive table with:**
- Sortable columns (click column headers)
- Search box (searches all columns)
- Pagination (10/25/50/100 rows per page)
- Column filtering

**Columns displayed:**
- PMID (clickable link to PubMed)
- Title
- Has Mechanism (Yes/No)
- Mechanism Probability
- Autoregulatory Type
- Source (Ground Truth / Training Negatives / Model Predictions)
- Year
- Journal

### 2. Filters Panel (Sidebar)

**Filter by:**

**Mechanism Status:**
- ☑️ With mechanism
- ☑️ Without mechanism

**Autoregulatory Type:**
- All types
- Transcription
- Translation
- Protein stability
- Alternative splicing
- DNA binding
- Localization
- Post-translational modification
- Non-autoregulatory

**Confidence Threshold:**
- Slider: 0.0 - 1.0
- Only show predictions above threshold

**Publication Year:**
- Range slider
- Filter by year range

**Source:**
- UniProt (Ground Truth)
- Training Negatives
- Model Predictions (Unused)
- New PubMed Predictions

**Search:**
- Search by PMID, keywords, protein name, gene name
- Case-insensitive
- Searches Title, Abstract, Protein Name, Gene Name columns

### 3. Statistics Tab

**Summary statistics:**
- Total papers loaded
- Papers with mechanisms
- Papers without mechanisms
- Breakdown by mechanism type
- Breakdown by source
- Year distribution
- Confidence score distribution

**Visualizations:**
- Bar charts for mechanism type distribution
- Pie charts for source breakdown
- Histograms for confidence scores
- Timeline of publication years

### 4. Export Functionality

**Export filtered results:**
- Button: "Download Filtered Data (CSV)"
- Downloads current filtered view
- Includes all columns

**Export formats:**
- CSV (default)
- Can be opened in Excel, Google Sheets, etc.

## Data Sources

The app displays data from 4 sources:

| Source | Papers | Description | Color Code |
|--------|--------|-------------|------------|
| **UniProt (Ground Truth)** | 1,332 | Manually curated autoregulatory proteins | 🟢 Green |
| **Training Negatives** | 2,664 | Papers used as negative examples in training | 🔵 Blue |
| **Model Predictions (Unused)** | ~250K | Predictions on unused PubMed papers | 🟡 Yellow |
| **New PubMed Predictions** | ~3M | Predictions on new PubMed data | 🟠 Orange |

## Understanding the Data

### Has Mechanism

- **Yes:** Paper discusses autoregulatory mechanisms
- **No:** Paper does not discuss autoregulatory mechanisms

### Mechanism Probability

**Confidence score (0-1) for "Has Mechanism" prediction:**

- `0.9-1.0`: Very confident (has mechanism)
- `0.7-0.9`: Confident
- `0.5-0.7`: Moderate confidence
- `0.0-0.5`: Likely no mechanism

**Note:** Ground Truth papers have probability = 1.0 (100% confident)

### Autoregulatory Type

**7 mechanism types:**

1. **Transcription** - Transcriptional auto-regulation
2. **Translation** - Translational auto-regulation
3. **Protein Stability** - Protein stability regulation
4. **Alternative Splicing** - Splicing-mediated regulation
5. **DNA Binding** - DNA binding-mediated regulation
6. **Localization** - Localization-based regulation
7. **Post-translational Modification** - PTM-mediated regulation

**Special value:**
- **non-autoregulatory** - Papers without mechanisms

### Type Confidence

**Confidence score (0-1) for mechanism type prediction:**

- `0.8-1.0`: High confidence
- `0.6-0.8`: Moderate confidence
- `0.4-0.6`: Low confidence (uncertain)
- `< 0.4`: Very uncertain

**Note:** Ground Truth and Training Negatives have fixed confidence values.

### Protein ID

**Format:** `AC_PMID`

Examples:
- `P12345_38000001` - UniProt accession P12345, PMID 38000001
- `NA_38000002` - No UniProt accession, PMID 38000002

**Only Ground Truth papers have UniProt accessions.**

## Common Use Cases

### Find High-Confidence Transcription Papers

1. Set "Mechanism Probability" slider to 0.8-1.0
2. Select "Transcription" in Autoregulatory Type
3. Click "Has Mechanism: Yes"

### Browse New Predictions from 2024

1. Set "Year" slider to 2024-2024
2. Select "New PubMed Predictions" in Source
3. Browse results

### Search for Specific Protein

1. Enter protein name in Search box (e.g., "p53")
2. Results show papers mentioning that protein
3. Export results if needed

### Find Papers Similar to Known Mechanism

1. Filter by "UniProt (Ground Truth)" source
2. Find paper with mechanism of interest
3. Note the mechanism type
4. Clear source filter
5. Filter by same mechanism type
6. Browse model predictions

## Performance

### Loading Time

| Dataset Size | Initial Load | Filter/Search |
|--------------|-------------|---------------|
| 10K papers | 1-2 seconds | Instant |
| 100K papers | 5-10 seconds | < 1 second |
| 1M papers | 30-60 seconds | 1-2 seconds |
| 3M papers | 90-180 seconds | 2-5 seconds |

**Tip:** Loading 3.25M rows takes ~2-3 minutes. Be patient on first load!

### Memory Usage

| Dataset Size | RAM Required |
|--------------|-------------|
| 100K papers | ~100 MB |
| 1M papers | ~500 MB |
| 3M papers | ~1.5 GB |

**Tip:** Close other applications if experiencing slowness.

## Troubleshooting

**Issue:** App won't start - "Error: file not found"
**Solution:** Ensure `shiny_app/data/predictions_for_app.csv` exists. Run `bash scripts/shell/run_complete_pipeline.sh`

**Issue:** App very slow to load
**Solution:** Normal for large datasets (3M+ rows). Wait 2-3 minutes for initial load.

**Issue:** Browser shows "Disconnected from server"
**Solution:** R crashed. Check terminal for error messages. May need more RAM.

**Issue:** Search not working
**Solution:** Wait for initial data load to complete. Loading indicator should disappear.

**Issue:** Export button downloads empty file
**Solution:** Apply at least one filter first, then export.

**Issue:** Can't filter by protein name
**Solution:** Ensure enrichment was run: `bash scripts/shell/enrich_existing_data.sh`

## Advanced: Running on Server

### Deploy to shinyapps.io

```r
# Install rsconnect
install.packages("rsconnect")

# Configure account (one-time)
rsconnect::setAccountInfo(
  name = "your-account",
  token = "your-token",
  secret = "your-secret"
)

# Deploy app
rsconnect::deployApp(appDir = "shiny_app")
```

**Note:** Free tier has limits:
- 5 applications
- 25 active hours/month
- 1 GB RAM

### Run on Custom Server

```r
# Install shiny-server
# See: https://posit.co/download/shiny-server/

# Copy app to server
cp -r shiny_app /srv/shiny-server/autoreg

# App accessible at:
# http://your-server.com:3838/autoreg/
```

## Customization

### Change App Theme

Edit `shiny_app/app.R`:

```r
ui <- fluidPage(
  theme = shinythemes::shinytheme("cerulean"),  # Change theme here
  ...
)
```

**Available themes:**
- cerulean (default)
- flatly
- darkly
- united
- cosmo
- lumen

### Add Custom Filters

Edit `shiny_app/app.R` to add new filter widgets in the `sidebarPanel()` section.

### Modify Table Columns

Edit the `DT::renderDataTable()` section to show/hide columns.

## Data Privacy

**Important:** The Shiny app loads data client-side (in your browser). No data is sent to external servers unless you deploy to shinyapps.io or similar.

**If deploying publicly:**
- Consider data sensitivity
- May want to exclude abstracts or full text
- Comply with PubMed data usage policies

## File Structure

```
shiny_app/
├── app.R                    # Main application file
├── data/
│   ├── predictions_for_app.csv          # Main dataset (3.25M rows)
│   └── predictions_for_app_enriched.csv # With protein names (optional)
└── www/                     # Static assets (logos, CSS)
```

## Next Steps

After exploring data in the app:

1. **Export interesting subsets** for further analysis
2. **Identify high-confidence predictions** for experimental validation
3. **Compare mechanism types** across different sources
4. **Track publication trends** over time

## Example Workflows

### Workflow 1: Find Novel Autoregulatory Proteins

1. Filter: "Has Mechanism: Yes"
2. Filter: "Source: New PubMed Predictions"
3. Set confidence > 0.8
4. Export results
5. Manually review abstracts

### Workflow 2: Validate Model Predictions

1. Filter: "Source: UniProt (Ground Truth)"
2. Note mechanism types
3. Clear source filter
4. Select same mechanism type
5. Compare model predictions to known examples

### Workflow 3: Publication Trend Analysis

1. Go to Statistics tab
2. View "Year Distribution" chart
3. Filter by mechanism type
4. Compare trends across types

---

**Questions?** See main [README.md](../README.md) or other documentation files.
