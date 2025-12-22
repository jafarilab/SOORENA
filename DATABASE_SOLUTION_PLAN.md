# Database Solution for Shiny App - 3.6M Rows

## Current Situation

- **Dataset:** `predictions_for_app_enriched.csv`
- **Size:** 4.6GB
- **Rows:** 3,587,038
- **Columns:** 17 (PMID, Has Mechanism, Mechanism Probability, Source, Autoregulatory Type, Type Confidence, Title, Abstract, Journal, Authors, Year, Month, AC, OS, Protein ID, Protein Name, Gene Name)
- **Problem:** Too large to load into memory for Shiny app
- **Goal:** Filter ALL data, run stats on ALL data

---

## Recommended Solution: SQLite + Supabase (Hybrid Approach)

### Architecture:

```
┌─────────────────────────────────────────────┐
│  OPTION 1: Local Development (SQLite)      │
│  - Fast local testing                       │
│  - No cost                                  │
│  - ~500MB database                          │
└─────────────────────────────────────────────┘
                    │
                    ↓
┌─────────────────────────────────────────────┐
│  OPTION 2: Production (Supabase)            │
│  - Cloud PostgreSQL database                │
│  - Fast remote access                       │
│  - Built-in API                             │
│  - Free tier: 500MB database, unlimited API│
└─────────────────────────────────────────────┘
```

---

## Option 1: SQLite (Local/Self-Hosted) ✓ RECOMMENDED FOR START

### Pros:
- ✓ **FREE** - No cost
- ✓ **Fast** - Local queries in 50-500ms
- ✓ **Simple** - Single file database
- ✓ **Works everywhere** - R, Python, any language
- ✓ **Small** - 4.6GB CSV → ~500MB database
- ✓ **No internet required**

### Cons:
- ✗ Single file (can't collaborate)
- ✗ Need to host Shiny app somewhere
- ✗ Database needs to be deployed with app

### Setup Steps:

1. **Create SQLite database** (~10 minutes)
2. **Modify Shiny app** to use database (~30 minutes)
3. **Test locally** (~10 minutes)
4. **Deploy** to hosting platform

### Hosting Options for SQLite + Shiny:

| Platform | Cost | Database Size Limit | RAM | Notes |
|----------|------|---------------------|-----|-------|
| **Shinyapps.io Free** | $0 | 1GB | 1GB | May need to compress DB |
| **Shinyapps.io Starter** | $9/mo | 3GB | 2GB | Plenty of space |
| **Oracle Cloud Free** | $0 | 200GB | 24GB | Best free option, requires setup |
| **AWS Lightsail** | $3.50/mo | 20GB | 512MB | Cheapest paid |

---

## Option 2: Supabase (Cloud PostgreSQL) ✓ RECOMMENDED FOR PRODUCTION

### Pros:
- ✓ **FREE tier** - 500MB database, unlimited API requests
- ✓ **Fast** - Optimized PostgreSQL with connection pooling
- ✓ **Built-in API** - Auto-generated REST API
- ✓ **Scalable** - Can upgrade to paid tier ($25/mo for 8GB)
- ✓ **Collaborative** - Multiple people can access
- ✓ **Real-time** - WebSocket support
- ✓ **Dashboard** - Web UI to query data

### Cons:
- ✗ Requires internet connection
- ✗ Need Supabase account
- ✗ Database size limit (500MB free, 8GB paid)

### Database Size Check:

4.6GB CSV will compress to approximately:
- **SQLite:** ~500MB (fits in free tier!)
- **PostgreSQL:** ~600MB (slightly over free tier, need paid $25/mo)

### Setup Steps:

1. **Create Supabase project** (5 minutes)
2. **Upload data to Supabase** (30 minutes)
3. **Create indexes** (5 minutes)
4. **Modify Shiny app** to use Supabase API (1 hour)
5. **Deploy** anywhere (shinyapps.io, Oracle Cloud, etc.)

---

## Recommended Workflow

### Phase 1: Start with SQLite (Local)

**Why:** Fast, free, works immediately

```bash
# 1. Create database (10 minutes)
python scripts/python/data_processing/create_sqlite_database.py

# 2. Test locally (instant)
cd shiny_app
Rscript -e "shiny::runApp('app.R')"

# 3. Deploy to shinyapps.io or Oracle Cloud
```

**Cost:** $0 if using Oracle Cloud Free, $9/mo if using shinyapps.io

### Phase 2: Migrate to Supabase (Production)

**When:** If you need:
- Multiple collaborators
- Remote access
- Better performance
- Built-in API for other tools

**Cost:** $0 if database <500MB, $25/mo if >500MB

---

## Database Comparison

| Feature | SQLite | Supabase (PostgreSQL) |
|---------|--------|----------------------|
| **Setup Time** | 10 min | 30 min |
| **Cost (Free Tier)** | $0 | $0 |
| **Cost (Paid)** | $0 (just hosting) | $25/mo |
| **Query Speed** | 50-500ms | 100-800ms (network) |
| **Database Size** | ~500MB | ~600MB |
| **Concurrent Users** | Limited | Unlimited |
| **Hosting** | Need to deploy with app | Cloud-hosted |
| **API Access** | No | Yes (REST + GraphQL) |
| **Collaboration** | No | Yes |
| **Backup** | Manual | Automatic |

---

## Compression Strategy (If Needed)

If database is too large for free tiers:

### Option A: Remove Abstract column
- **Saves:** ~2GB (reduces to 2.6GB CSV → 300MB DB)
- **Downside:** Can't search abstracts in app

### Option B: Compress Text Fields
- Store Title/Abstract in separate table
- **Saves:** ~40% size
- **Downside:** Slightly slower queries

### Option C: Use Parquet instead of CSV
- **Saves:** ~70% size (4.6GB → 1.4GB)
- **Downside:** Needs different loading script

---

## My Recommendation

### Start Here (Fastest & Free):

1. **Create SQLite database** with all data
2. **Deploy to Oracle Cloud Always Free**
   - 24GB RAM (plenty for SQLite)
   - 200GB storage
   - $0/month forever

### Migrate Later (If Needed):

If you need collaboration or remote access:
1. **Upgrade to Supabase paid tier** ($25/mo)
2. Keep Shiny app on Oracle Cloud Free ($0/mo)
3. Total cost: $25/mo

---

## Files I'll Create

1. `create_sqlite_database.py` - Converts CSV to SQLite
2. `upload_to_supabase.py` - Uploads data to Supabase
3. `app_sqlite.R` - Shiny app using SQLite
4. `app_supabase.R` - Shiny app using Supabase
5. `DEPLOYMENT_GUIDE.md` - Step-by-step deployment

---

## Next Steps - Choose Your Path:

### Path A: SQLite Only (Simplest)
```bash
python create_sqlite_database.py
cd shiny_app && Rscript -e "shiny::runApp('app.R')"
# Deploy to Oracle Cloud Free or shinyapps.io
```
**Time:** 1 hour total
**Cost:** $0

### Path B: Supabase Only (Cloud)
```bash
python upload_to_supabase.py
cd shiny_app && Rscript -e "shiny::runApp('app.R')"
# Deploy anywhere
```
**Time:** 2 hours total
**Cost:** $0 (if <500MB) or $25/mo (if >500MB)

### Path C: Both (Recommended)
```bash
# Start with SQLite for testing
python create_sqlite_database.py
# Test locally
cd shiny_app && Rscript -e "shiny::runApp('app.R')"
# Then migrate to Supabase for production
python upload_to_supabase.py
```
**Time:** 3 hours total
**Cost:** $0-25/mo depending on database size

---

## Which do you want to do?

Tell me and I'll create all the necessary scripts and guide you through setup!
