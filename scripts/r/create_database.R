#!/usr/bin/env Rscript
# Create SQLite database from CSV for efficient Shiny app queries

library(RSQLite)
library(DBI)

cat("=" * 80, "\n")
cat("SOORENA SQLite Database Creation\n")
cat("=" * 80, "\n\n")

# Paths
db_path <- "shiny_app/data/predictions.db"
csv_path <- "shiny_app/data/predictions_for_app.csv"

# Validate CSV exists
if (!file.exists(csv_path)) {
  stop("Error: CSV file not found at: ", csv_path)
}

cat("Input CSV:", csv_path, "\n")
cat("Output database:", db_path, "\n\n")

# Remove existing database if it exists
if (file.exists(db_path)) {
  cat("Removing existing database...\n")
  file.remove(db_path)
}

# Create database connection
cat("Creating database connection...\n")
con <- dbConnect(RSQLite::SQLite(), db_path)

# Read and insert in chunks to avoid memory issues
chunk_size <- 100000
offset <- 0

cat("Reading first chunk to create table structure...\n")
first_chunk <- read.csv(csv_path, nrows=chunk_size, stringsAsFactors=FALSE)
cat(sprintf("  Columns: %d\n", ncol(first_chunk)))
cat(sprintf("  First chunk rows: %d\n", nrow(first_chunk)))

# Create table
dbWriteTable(con, "predictions", first_chunk, overwrite=TRUE)
cat("✓ Table created\n\n")

# Calculate total rows
cat("Calculating total rows in CSV...\n")
total_rows <- as.numeric(system(paste("wc -l <", csv_path), intern=TRUE)) - 1
cat(sprintf("  Total rows to import: %s\n\n", format(total_rows, big.mark=",")))

# Read remaining chunks
cat("Importing data in chunks...\n")
rows_imported <- nrow(first_chunk)

while (offset < total_rows) {
  offset <- offset + chunk_size

  chunk <- read.csv(csv_path,
                    nrows=chunk_size,
                    skip=offset,
                    header=FALSE,
                    col.names=names(first_chunk),
                    stringsAsFactors=FALSE)

  if (nrow(chunk) > 0) {
    dbWriteTable(con, "predictions", chunk, append=TRUE)
    rows_imported <- rows_imported + nrow(chunk)
    cat(sprintf("\r  Progress: %s / %s rows (%.1f%%)",
                format(rows_imported, big.mark=","),
                format(total_rows, big.mark=","),
                (rows_imported/total_rows)*100))
    flush.console()
  }
}

cat("\n✓ All data imported\n\n")

# Create indexes for fast searching
cat("Creating indexes for optimized queries...\n")

dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_pmid ON predictions(PMID)")
cat("  ✓ Index on PMID\n")

dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_has_mechanism ON predictions(`Has.Mechanism`)")
cat("  ✓ Index on Has.Mechanism\n")

dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_year ON predictions(Year)")
cat("  ✓ Index on Year\n")

dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_type ON predictions(`Autoregulatory.Type`)")
cat("  ✓ Index on Autoregulatory.Type\n")

dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_journal ON predictions(Journal)")
cat("  ✓ Index on Journal\n")

dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_os ON predictions(OS)")
cat("  ✓ Index on OS\n\n")

# Verify database
cat("Verifying database...\n")
row_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM predictions")$count
cat(sprintf("  Rows in database: %s\n", format(row_count, big.mark=",")))

if (row_count == total_rows) {
  cat("✓ Row count matches!\n\n")
} else {
  cat("⚠ Warning: Row count mismatch!\n")
  cat(sprintf("  Expected: %s\n", format(total_rows, big.mark=",")))
  cat(sprintf("  Got: %s\n\n", format(row_count, big.mark=",")))
}

# Get database size
db_size_mb <- file.size(db_path) / (1024^2)
cat(sprintf("Database size: %.1f MB\n\n", db_size_mb))

# Disconnect
dbDisconnect(con)

cat("=" * 80, "\n")
cat("✓ Database created successfully!\n")
cat("=" * 80, "\n\n")

cat("Next steps:\n")
cat("  1. Update shiny_app/app.R to use the database\n")
cat("  2. Test the app locally\n")
cat("  3. Deploy to shinyapps.io\n\n")
