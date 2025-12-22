# Shiny App Deployment Guide - SQLite + shinyapps.io

This guide walks you through deploying the SOORENA Shiny app with SQLite database to shinyapps.io.

---

## Prerequisites

1. **R and RStudio** installed
2. **shinyapps.io account** (free tier available at https://www.shinyapps.io/admin/#/signup)
3. **SQLite database created** from enriched CSV data

---

## Step 1: Create SQLite Database

Convert the 4.6GB enriched CSV to ~500MB SQLite database:

```bash
python create_sqlite_database.py
```

**Expected output:**
```
================================================================================
CREATE SQLITE DATABASE FOR SHINY APP
================================================================================

Step 1: Loading CSV in chunks and writing to database...
Chunk size: 50,000 rows

  Chunk 1: Processed 50,000 rows...
  Chunk 2: Processed 100,000 rows...
  ...
  Chunk 72: Processed 3,587,038 rows...

✓ Imported 3,587,038 total rows

Step 2: Creating indexes for fast querying...
  Creating index on PMID...
  Creating index on Has_Mechanism...
  Creating index on Year...
  Creating index on Source...
  Creating index on Autoregulatory_Type...
  Creating index on Journal...
  Creating index on OS...

✓ Created 7 indexes

Step 3: Optimizing database...
✓ Database optimized

================================================================================
DATABASE CREATION COMPLETE!
================================================================================

Database file: shiny_app/data/predictions.db
Database size: 487.3 MB
Total rows:    3,587,038
Indexes:       7

✓ Fits in shinyapps.io free tier (1GB storage limit)

================================================================================
NEXT STEPS:
================================================================================

1. Test locally:
   cd shiny_app
   Rscript -e "shiny::runApp('app.R')"

2. Deploy to shinyapps.io:
   - Database file will be included automatically
   - See DEPLOYMENT_GUIDE.md for instructions

================================================================================
```

**What this does:**
- Reads CSV in 50K row chunks (avoids memory issues)
- Creates SQLite database at `shiny_app/data/predictions.db`
- Creates 7 indexes for fast filtering
- Compresses 4.6GB → ~500MB

---

## Step 2: Update app.R to Use SQLite

Replace `shiny_app/app.R` with the SQLite version:

```bash
cd shiny_app
cp app_sqlite.R app.R
```

**What changed:**
- ✓ Loads data from SQLite database instead of CSV
- ✓ Builds SQL queries dynamically based on user filters
- ✓ Returns only filtered results (not full dataset)
- ✓ Handles 3.6M rows without memory issues
- ✓ **UI is exactly the same** - no user-facing changes

---

## Step 3: Test Locally

Before deploying, test that the app works with the database:

```bash
cd shiny_app
Rscript -e "shiny::runApp('app.R')"
```

You should see:
```
Connecting to SQLite database...
Connected to database with 3,587,038 rows
Loading filter options from database...
Database ready!

Listening on http://127.0.0.1:XXXX
```

**Test these features:**
- ✓ All filters work (Journal, OS, Type, Year, etc.)
- ✓ Search works (PMID, Author, Title/Abstract)
- ✓ Statistics tab loads
- ✓ Download CSV works
- ✓ No performance lag when filtering

If everything works, proceed to deployment!

---

## Step 4: Install Required R Packages

Open RStudio and install all required packages:

```r
install.packages(c(
  "shiny",
  "DT",
  "dplyr",
  "DBI",
  "RSQLite",
  "shinyjs",
  "htmltools",
  "plotly",
  "ggplot2",
  "shinycssloaders",
  "rsconnect"
))
```

**Important:** The `rsconnect` package is required for deployment to shinyapps.io.

---

## Step 5: Configure shinyapps.io Account

### 5.1: Get your authentication token

1. Log in to https://www.shinyapps.io
2. Click your name (top right) → **Tokens**
3. Click **Show** on your token
4. Click **Show Secret**
5. Copy the full command (looks like this):

```r
rsconnect::setAccountInfo(
  name='your-username',
  token='XXXXXXXXX',
  secret='XXXXXXXXX'
)
```

### 5.2: Authenticate in RStudio

1. Open RStudio
2. Paste the command from step 5.1 into the R console
3. Press Enter

You should see:
```
Account registered: your-username (shinyapps.io)
```

---

## Step 6: Deploy to shinyapps.io

### Option A: Deploy from RStudio (Recommended)

1. Open `shiny_app/app.R` in RStudio
2. Click the **Publish** button (blue icon in top right of editor)
3. Select **Publish Application**
4. Choose **shinyapps.io**
5. Select files to deploy:
   - ✅ `app.R`
   - ✅ `data/predictions.db` (CRITICAL - must include!)
   - ✅ `www/` folder (logo images)
6. Click **Publish**

### Option B: Deploy from R Console

```r
library(rsconnect)

# Deploy from shiny_app directory
setwd("shiny_app")

deployApp(
  appName = "soorena",
  appFiles = c(
    "app.R",
    "data/predictions.db",
    "www/"
  ),
  launch.browser = TRUE
)
```

**Deployment will take 5-10 minutes** - it needs to upload the 500MB database file.

You'll see output like:
```
Preparing to deploy application...
Uploading bundle for application: 123456...
Deploying bundle: 789012 for application: 123456...
Waiting for task: 345678...
Building R source package...
Installing packages...
Application successfully deployed to https://your-username.shinyapps.io/soorena/
```

---

## Step 7: Verify Deployment

### 7.1: Check if app loads

1. Open the URL: `https://your-username.shinyapps.io/soorena/`
2. Wait 30-60 seconds for first load (database initialization)
3. You should see the SOORENA app homepage

### 7.2: Test functionality

- ✓ All tabs load (Search, Statistics, Ontology, Patch Notes, About Us)
- ✓ Filters work correctly
- ✓ Search returns results
- ✓ Statistics charts display
- ✓ Download CSV works

### 7.3: Check logs (if issues)

1. Go to https://www.shinyapps.io/admin/#/applications
2. Click on your app
3. Click **Logs** tab
4. Look for errors (should see "Connected to database with 3,587,038 rows")

---

## Database Size Check

**Free Tier Limits:**
- Storage: 1GB
- RAM: 1GB
- Active hours: 25 hours/month

**Your database:**
- Size: ~500MB ✓ (fits in 1GB limit)
- Memory usage: ~700MB ✓ (fits in 1GB RAM)
- Expected users: Low (well within active hours)

**You're good to go with the free tier!**

---

## Troubleshooting

### Error: "Database not found"

**Problem:** `predictions.db` wasn't uploaded during deployment.

**Solution:**
```r
# Re-deploy with explicit file list
deployApp(
  appFiles = c("app.R", "data/predictions.db", "www/")
)
```

### Error: "Memory limit exceeded"

**Problem:** Database too large for free tier RAM.

**Solution:**
- Check database size: `ls -lh shiny_app/data/predictions.db`
- If >500MB, re-run `create_sqlite_database.py` to verify compression
- Consider upgrading to shinyapps.io Starter plan ($9/mo, 2GB RAM)

### App loads slowly

**Normal behavior:**
- First load: 30-60 seconds (database initialization)
- Subsequent loads: 5-10 seconds
- Filters/search: <1 second

**If slower:**
- Check indexes were created (re-run `create_sqlite_database.py`)
- Verify `ANALYZE` and `VACUUM` ran

### Error: "Cannot connect to database"

**Problem:** Database path incorrect.

**Solution:**
In `app.R`, verify:
```r
DB_PATH <- "data/predictions.db"  # Relative to shiny_app/
```

---

## Performance Comparison

### Before (CSV loading):
- Initial load: 100K rows only (to prevent browser freeze)
- Memory usage: 800MB+ (constant)
- Filter speed: Slow (re-filters 100K rows each time)
- Full dataset: **NOT ACCESSIBLE**

### After (SQLite):
- Initial load: Connects to database (instant)
- Memory usage: 500MB database + 200MB app = 700MB
- Filter speed: Fast (SQL indexes, returns only matches)
- Full dataset: **ALL 3.6M ROWS SEARCHABLE**

**Result:** 35x more data, faster performance!

---

## Updating the App

### Update data only:
```bash
# 1. Re-create database with new data
python create_sqlite_database.py

# 2. Re-deploy
rsconnect::deployApp(appFiles = c("app.R", "data/predictions.db", "www/"))
```

### Update app code only:
```bash
# Just re-deploy app.R (database stays the same)
rsconnect::deployApp(appFiles = c("app.R", "data/predictions.db", "www/"))
```

---

## shinyapps.io Free Tier Monitoring

Monitor your usage at: https://www.shinyapps.io/admin/#/dashboard

**What to watch:**
- **Active hours:** 25/month (resets monthly)
  - Each user session counts toward active hours
  - App goes to sleep after 15 minutes of inactivity
- **Storage:** Should stay at ~500MB
- **Memory:** Should stay at ~700MB

**If you exceed limits:**
- Free tier: App will be suspended until next month
- Upgrade to Starter ($9/mo): 175 hours, 3GB storage, 2GB RAM

---

## Advanced: Custom Domain (Optional)

To use your own domain (e.g., `soorena.yourdomain.com`):

1. Upgrade to shinyapps.io Starter plan ($9/mo minimum)
2. Go to https://www.shinyapps.io/admin/#/applications
3. Click your app → Settings → Custom URL
4. Follow instructions to configure DNS

**Not required** - the default URL works perfectly!

---

## Summary

✅ **What you deployed:**
- SQLite database: 487MB with 3.6M rows
- Shiny app: Full-featured search interface
- All filters, statistics, and downloads working

✅ **Performance:**
- Handles all 3.6M rows without memory issues
- Fast filtering with SQL indexes
- Fits in shinyapps.io free tier

✅ **Next steps:**
- Share URL: `https://your-username.shinyapps.io/soorena/`
- Monitor usage in shinyapps.io dashboard
- Update data by re-running `create_sqlite_database.py`

---

## Need Help?

**shinyapps.io documentation:** https://docs.posit.co/shinyapps.io/

**Common issues:**
- App not loading: Check logs in shinyapps.io dashboard
- Database errors: Verify `predictions.db` uploaded correctly
- Memory errors: Database might be too large for free tier

**Support:**
- shinyapps.io support: support@posit.co
- Shiny community: https://community.rstudio.com/c/shiny/8
