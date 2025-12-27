# Shiny App (SOORENA)

This document explains how to run and use the SOORENA Shiny dashboard.

The app reads from a local SQLite database:
- `shiny_app/data/predictions.db`

---

## 1) Run Locally

### Requirements

- R ≥ 4.0
- A built database: `shiny_app/data/predictions.db`

### Install R packages

```r
install.packages(c(
  "shiny", "DT", "dplyr", "DBI", "RSQLite",
  "shinyjs", "htmltools", "plotly", "ggplot2",
  "shinycssloaders", "rsconnect"
))
```

### Build the SQLite database (if missing)

From repo root:

```bash
python scripts/python/data_processing/create_sqlite_db.py \
  --input shiny_app/data/predictions.csv \
  --output shiny_app/data/predictions.db
```

For the full workflow (training → prediction → merge → DB), see `docs/README.md`.

### Launch the app

```bash
cd shiny_app
Rscript -e "shiny::runApp('app.R')"
```

Stop the app with `Ctrl+C` in the terminal.

---

## 2) What’s in the database?

The Shiny app database is **autoregulatory-only** (no “non-autoregulatory” rows).

Two accession concepts exist:

- `AC` = **SOORENA record ID** (unique per row): `SOORENA_<PMID>_<n>`
- `UniProtKB_accessions` = **UniProtKB accession number(s)** (comma-separated when available)

Polarity is derived directly from the mechanism type:
- `+` = positive (e.g., autophosphorylation, autocatalytic, autoinducer)
- `–` = negative (e.g., autoinhibition, autoubiquitination, autolysis)
- `±` = mixed/depends (autoregulation)

---

## 3) Search Tab

### A) Fast search (Title/Abstract)

- **Title/Abstract search** field supports:
  - **Contains** (partial match)
  - **Exact match**

### B) Core filters (top row)

- `Autoregulatory Type`
- `Polarity` (`+`, `–`, `±`)
- `Year range` (From/To)
- `Data Source` (`All`, `UniProt`, `Non-UniProt`)

Polarity behavior:
- If none are selected, the app treats it as **no polarity filtering** (shows all).
- Selecting a subset restricts results to that subset.

### C) More filters (collapsible)

**Publication & Metadata**
- `Journal`
- `OS` (organism)
- `Author`
- `Publication Month`

**Proteins & IDs**
- `Protein Name`
- `Gene Name`
- `Protein ID`
- `PMID`
- `UniProt AC` (search within `UniProtKB_accessions`)
- `AC (Record ID)`

### D) Table sorting + pagination

- Clicking a column header sorts the **entire filtered dataset** (not just the current page).
- Pagination controls the SQL query (`LIMIT/OFFSET`), so filtering and sorting stay consistent across pages.

---

## 4) Statistics Tab

The Statistics tab updates based on the **current Search filters** and includes:
- Total matching papers
- Source mix (UniProt vs Non‑UniProt)
- Autoregulatory type distribution
- Publication timeline
- Top journals
- Model benchmark tables

---

## 5) Ontology Tab

The ontology tab provides definitions and related terms for each mechanism type.
Polarity annotations (`+ / – / ±`) are displayed alongside mechanisms for clarity.

---

## 6) Troubleshooting

**App fails with “Database not found”**
- Build `shiny_app/data/predictions.db` using `scripts/python/data_processing/create_sqlite_db.py`

**App feels slow**
- First load depends on DB size and disk speed.
- Filtering/sorting is SQL-backed; adding indexes is handled by `create_sqlite_db.py`.

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
**Solution:** Ensure `shiny_app/data/predictions.db` exists by running the prediction workflow in `docs/README_PREDICTION_NEW_DATA.md`.

**Issue:** App very slow to load
**Solution:** Normal for large datasets (3M+ rows). Wait 2-3 minutes for initial load.

**Issue:** Browser shows "Disconnected from server"
**Solution:** R crashed. Check terminal for error messages. May need more RAM.

**Issue:** Search not working
**Solution:** Wait for initial data load to complete. Loading indicator should disappear.

**Issue:** Export button downloads empty file
**Solution:** Apply at least one filter first, then export.

**Issue:** Can't filter by protein name
**Solution:** Ensure PubTator enrichment was run on the dataset before building the DB.

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
│   ├── predictions.csv                  # Main dataset (CSV)
│   └── predictions.db                   # SQLite DB used by the app
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
