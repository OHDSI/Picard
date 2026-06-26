# Post-Processing and Dissemination

## Introduction

After your pipeline completes via `execStudyPipeline()`, raw analytical outputs are stored in `exec/results/[database]/[version]/` organized by task. The post-processing phase merges these results across databases and prepares them for dissemination.

Post-processing occurs in three stages:

1. **Merge & Export** — Combine results across databases via `runPostProcessing()`
2. **Schema Review** — Inspect data types and structure
3. **Quality Control** — Validate cohort completeness and generate metadata

Results are saved to `dissemination/export/merge/v{version}/` with reference files, QC reports, and optional dissemination scripts for final formatting.

## Stage 1: Merge & Export Results

After your production pipeline completes, call `runPostProcessing()` to orchestrate the merge:

```r
library(picard)

# Merge results for version 1.0.0 across databases
runPostProcessing(
  pipelineVersion = "1.0.0",
  dbIds = c("database_1", "database_2"),
  resultsPath = here::here("exec/results"),
  exportPath = here::here("dissemination/export/merge"),
  cohortsFolderPath = here::here("inputs/cohorts"),
  testMode = FALSE
)
```

This function:

- **Auto-discovers all tasks** for the specified version across databases
- **Merges results** across databases for each task via `importAndBind()`
- **Adds databaseId column** to all results to track data source
- **Creates reference files**: cohortManifestSnapshot.csv, databaseInfo.csv
- **Reviews file schemas** with `reviewExportSchema()`
- **Validates cohorts** with `validateCohortResults()`
- **Generates execution metadata** with QC status
- **Supports test mode** (non-fatal QC checks) for development versions

### Test Mode

Pass `testMode = TRUE` for development versions (e.g., "dev", "test") to skip non-fatal QC checks:

```r
runPostProcessing(
  pipelineVersion = "dev",
  dbIds = c("database_1"),
  testMode = TRUE  # Non-fatal QC checks
)
```

By default, test mode is auto-enabled for non-semver version strings.

### Output Folder Structure

After processing, results are organized in `dissemination/export/merge/v{version}/`:

```
v1.0.0/
├── cohort_counts.csv              # Cohort counts merged across databases
├── characterization.csv           # Task results merged across databases
├── primary_analysis.csv           # Task results merged across databases
├── cohortManifestSnapshot.csv     # Reference: cohort metadata at execution
├── databaseInfo.csv               # Reference: database details
├── schema_review.csv              # Schema inspection results
├── qc_cohortValidation.csv        # QC: cohort completeness validation
└── qc_processMeta.csv             # QC: execution metadata
```

## Reference Files

### cohortManifestSnapshot.csv

Point-in-time snapshot of your cohort manifest at execution:

```
id,label,category,tags,file_path,hash,cohort_type,status,created_at,updated_at
1,Type 2 Diabetes,phenotype,high-priority,json/cohort_001.json,abc123...,circe,active,2025-01-15 10:30:00,2025-01-15 10:30:00
2,CVD Outcome,outcome,,json/cohort_002.json,def456...,sql,active,2025-01-15 10:30:00,2025-01-15 10:30:00
```

Enables recovery via git history: `git log -- <file_path>`

### databaseInfo.csv

Documents which databases were included in the merge:

```
databaseId,databaseName,databaseLabel,cohortTable
database_1,database_1,OMOP CDM - Site A,cohort
database_2,database_2,OMOP CDM - Site B,cohort_table
```

### schema_review.csv

Inspects the structure of all exported CSV files. Useful for identifying:

- Column naming inconsistencies
- Unexpected data types
- Columns that need transformation

```
fileName,columnName,dataType,rowCount
cohort_counts.csv,cohort_id,numeric,500
cohort_counts.csv,cohort_subjects,numeric,500
cohort_counts.csv,databaseId,character,500
```

## Quality Control (QC) Reports

### qc_cohortValidation.csv

Validates that all cohorts in your manifest generated results:

```
cohortId,label,validationStatus,details
1,Type 2 Diabetes,OK,nonzero results found
2,CVD Outcome,ZeroCount,generated 0 subjects
3,CVD Comparator,Missing,not enumerated
```

Statuses:
- **OK** — Cohort has non-zero results
- **ZeroCount** — Cohort exists but generated zero entries/subjects
- **Missing** — Cohort in manifest but not found in results

### qc_processMeta.csv

Execution metadata for reproducibility:

```
executionTimestamp,pipelineVersion,codeCommitSha,lockfileHash,databasesIncluded,databaseCount,tasksProcessed,totalFilesExported,totalRowsMerged,qcStatus
2025-01-15 10:35:00,1.0.0,abc123def456,renv-lock-hash,OMOP CDM - Site A | OMOP CDM - Site B,2,3,9,45000,OK
```

Tracks:
- **When** export ran
- **What version** was processed
- **Code state** (git commit SHA for reproducibility)
- **Environment** (renv lockfile hash)
- **Scope** (databases and tasks included)
- **Results** (files and rows merged)
- **QC Status** (OK, HasWarnings, DevMode)

## Stage 2: Dissemination Scripts

After results are merged, format them for dissemination using numbered scripts in `dissemination/pretty/R/`:

```r
# Create a new dissemination script
makeDisseminationScript(
  name = "format_results",
  projectPath = here::here(),
  open = TRUE
)
```

This creates `01_format_results.R` with a template structure. Each script receives `disseminationEnv` containing:

- `pipelineVersion` — Version from merge step
- `databaseIds` — Database IDs included
- `outputPath` — Dissemination output root
- `resultsPath` — Merged results folder path

### Example Dissemination Script

```r
# Access metadata from disseminationEnv
cat("Pipeline version:", disseminationEnv$pipelineVersion, "\n")
cat("Databases:", paste(disseminationEnv$databaseIds, collapse = ", "), "\n")

# Load merged results
results <- readr::read_csv(
  fs::path(disseminationEnv$resultsPath, "cohort_counts.csv")
)

# Format and export
formatted <- results |>
  picard::prepareDisseminationData() |>
  readr::write_csv(
    fs::path(disseminationEnv$outputPath, "formatted_results.csv")
  )
```

### Run Dissemination Scripts

After creating scripts, source them all:

```r
sourceDisseminationScripts(
  projectPath = here::here(),
  pipelineVersion = "1.0.0",
  databaseIds = c("database_1", "database_2"),
  outputPath = here::here("dissemination/pretty"),
  verbose = TRUE
)
```

Scripts are numbered (01_, 02_, etc.) and sourced in alphabetical order.

## Advanced: Manual Import and Binding

If you need to merge results for a specific task only, use `importAndBind()`:

```r
library(picard)

# Merge just the characterization task across all databases
importAndBind(
  version = "1.0.0",
  taskName = "characterization",
  dbIds = c("database_1", "database_2"),
  resultsPath = here::here("exec/results"),
  exportPath = here::here("dissemination/export/merge")
)
```

This combines all CSV files from that task across databases and adds a `databaseId` column to identify the source.

## Advanced: Schema Review

To examine file structure without full orchestration:

```r
library(picard)

# Review schema of exported files
schema <- reviewExportSchema(
  exportPath = here::here("dissemination/export/merge/v1.0.0")
)

# Check for specific data types
character_cols <- schema[schema$dataType == "character", ]
```

## Advanced: Cohort Validation

To validate cohort results independently:

```r
library(picard)

# Validate cohorts in exported results
validation <- validateCohortResults(
  exportPath = here::here("dissemination/export/merge/v1.0.0"),
  resultsFileName = "cohort_counts.csv"
)

# View validation results
print(validation)

# Check for issues
issues <- validation[validation$validationStatus != "OK", ]
```

## Integration into main.R

The typical workflow in `main.R`:

```r
# Phase 2: Execute pipeline
execStudyPipeline(pipelineVersion = "1.0.0", ...)

# Phase 3: Post-processing
runPostProcessing(
  pipelineVersion = "1.0.0",
  dbIds = c("database_1", "database_2"),
  resultsPath = here::here("exec/results"),
  exportPath = here::here("dissemination/export/merge"),
  cohortsFolderPath = here::here("inputs/cohorts")
)

# Phase 4: Dissemination
sourceDisseminationScripts(
  projectPath = here::here(),
  pipelineVersion = "1.0.0",
  databaseIds = c("database_1", "database_2")
)
```

## Next Steps

1. **Run orchestration:** Call `runPostProcessing()` after production pipeline completes
2. **Review QC reports:** Check qc_cohortValidation.csv and qc_processMeta.csv
3. **Examine schema:** Use schema_review.csv to understand data structure
4. **Create dissemination scripts:** Use `makeDisseminationScript()` for custom formatting
5. **Source scripts:** Call `sourceDisseminationScripts()` to run all dissemination scripts
6. **Handle issues:** If cohorts are missing or zero, investigate in analysis tasks
7. **Prepare dissemination:** Use exported results for publication or further analysis
