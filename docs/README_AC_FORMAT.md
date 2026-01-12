# SOORENA AC (Accession) Identifier Format

## Overview

Every row in the SOORENA database has a unique **AC (Accession)** identifier that serves as the primary record ID. The AC format is designed to be:
- **Human-readable**: Shows source and PMID at a glance
- **Unique**: Handles duplicate PMIDs gracefully
- **Sortable**: Groups entries by source and PMID

## Format Specification

```
AC = SOORENA-{SourceCode}-{PMID}-{Counter}
```

### Components

| Component | Description | Example |
|-----------|-------------|---------|
| `SOORENA` | Fixed prefix identifying SOORENA database | SOORENA |
| `SourceCode` | Single letter identifying data source | U, P, O, S, T |
| `PMID` | PubMed identifier (or "UNKNOWN") | 12345678 |
| `Counter` | Sequential number for duplicate PMIDs | 1, 2, 3... |

### Separator

Components are separated by **dashes** (`-`), not underscores.

## Source Codes

| Code | Source | Description | Example AC |
|------|--------|-------------|------------|
| **U** | UniProt | Training data from UniProt curated entries | SOORENA-U-10023074-1 |
| **P** | Predicted | ML predictions from PubMed abstracts | SOORENA-P-12345678-1 |
| **O** | OmniPath | Protein-protein interactions database | SOORENA-O-UNKNOWN-1 |
| **S** | SIGNOR | Signaling network database | SOORENA-S-10037717-1 |
| **T** | TRRUST | Transcription factor database | SOORENA-T-11032029-1 |

**Note**: The code also supports R (ORegAnno) and H (HTRIdb) for potential future external databases, but these are not currently used.

## Counter Explanation

The **counter** is a sequential number (1, 2, 3...) that handles duplicate PMIDs.

### Why Duplicate PMIDs Exist

The same PMID can appear multiple times because:

1. **Multiple protein mentions** - One paper discusses several autoregulatory proteins
2. **Multiple sources** - Same PMID found in both predictions and external databases
3. **Multiple mechanism types** - Same protein has different autoregulatory mechanisms in one paper

### How Counters Work

**Example: PMID 10064595**

This PMID appears in multiple sources:

```
SOORENA-U-10064595-1  ← UniProt entry (1st occurrence)
SOORENA-U-10064595-2  ← UniProt entry (2nd occurrence, different protein)
SOORENA-U-10064595-3  ← UniProt entry (3rd occurrence)
SOORENA-S-10064595-1  ← SIGNOR entry (1st in SIGNOR)
SOORENA-S-10064595-2  ← SIGNOR entry (2nd in SIGNOR)
```

**Key Points:**
- Counter is **per-PMID**, not global
- Each PMID starts counting from 1
- Different sources have independent counters
- Counter ensures every AC is unique

## Complete Examples

### Predicted Entry
```
AC: SOORENA-P-23456789-1
  ├─ Source: Predicted (P)
  ├─ PMID: 23456789
  └─ Counter: 1 (first entry with this PMID)
```

### UniProt Entry with Duplicate PMID
```
AC: SOORENA-U-10037737-2
  ├─ Source: UniProt (U)
  ├─ PMID: 10037737
  └─ Counter: 2 (second entry with this PMID)
```

### SIGNOR Entry
```
AC: SOORENA-S-10075701-1
  ├─ Source: SIGNOR (S)
  ├─ PMID: 10075701
  └─ Counter: 1 (first SIGNOR entry with this PMID)
```

### OmniPath with Invalid PMID
```
AC: SOORENA-O-UNKNOWN-1
  ├─ Source: OmniPath (O)
  ├─ PMID: UNKNOWN (original PMID was invalid/missing)
  └─ Counter: 1
```

## Special Cases

### Invalid or Missing PMIDs

When a PMID is invalid, missing, or empty (like OmniPath entries with "-"), it is replaced with **"UNKNOWN"**:

```
SOORENA-O-UNKNOWN-1
SOORENA-O-UNKNOWN-2
```

**Why not exclude these entries?**
- They still contain valuable gene/protein information
- Users can filter them if needed: `WHERE PMID != 'UNKNOWN'`
- Preserves completeness of external database data

### Filtering by Source

To find all entries from a specific source:

```sql
-- All predicted entries
SELECT * FROM predictions WHERE AC LIKE 'SOORENA-P-%';

-- All UniProt entries
SELECT * FROM predictions WHERE AC LIKE 'SOORENA-U-%';

-- All external database entries
SELECT * FROM predictions WHERE AC LIKE 'SOORENA-O-%'
   OR AC LIKE 'SOORENA-S-%'
   OR AC LIKE 'SOORENA-T-%';
```

### Finding Duplicate PMIDs

To find all entries for a specific PMID:

```sql
SELECT AC, Source, Gene_Name, Autoregulatory_Type
FROM predictions
WHERE PMID = '10064595'
ORDER BY AC;
```

## Implementation Notes

### Where ACs are Generated

ACs are generated in two places during the pipeline:

1. **`merge_enriched_predictions.py`**
   - Generates ACs when merging unused + 3M predictions
   - Before external resources are added

2. **`integrate_external_resources.py`**
   - Regenerates ALL ACs after adding external resources
   - Ensures consistent format across all sources
   - Handles invalid PMIDs (replaces with "UNKNOWN")

### Reproducibility

**ACs are deterministic** - running the pipeline multiple times produces identical ACs:
- Sorted by PMID and Source before generation
- Counter increments consistently
- Same input data → same ACs

### Database Validation

The database creation script validates ACs:
- Checks for missing ACs (errors if found)
- Checks for duplicate ACs (errors if found)
- Forces upstream fixes rather than patching

## Frequently Asked Questions

**Q: Why use dashes instead of underscores?**

A: Dashes are more readable and avoid confusion with legacy formats that used underscores.

**Q: Can I rely on the counter for ordering?**

A: No - the counter only indicates uniqueness. Use other fields (like Title, Date) for ordering.

**Q: What if I see an old AC format like `SOORENA_12345678_1`?**

A: This is a legacy format. Rebuild the database to get the new format.

**Q: Can I change the AC format?**

A: Not recommended - many tools and queries rely on the current format. If needed, update both generation scripts and documentation.

## Related Documentation

- Main workflow: [docs/README.md](README.md)
- External resources: [docs/README_EXTERNAL_RESOURCES.md](README_EXTERNAL_RESOURCES.md)
- Shiny app usage: [docs/README_SHINY_APP.md](README_SHINY_APP.md)
