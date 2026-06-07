# Post-Processing Steps

## Introduction

After your pipeline runs successfully, raw analytical outputs are saved in `exec/results/[database]/[version]/` organized by task. Post-processing orchestrates the merge and quality control of these results across multiple databases and exports them to `dissemination/export/merge/v{version}/`.

The main post-processing step is **orchestrating the pipeline export**, which:

1. Merges result files across all databases for each task
2. Generates reference files (cohortKey, databaseInfo)
3. Reviews the schema of all exported files
4. Validates cohort result completeness
5. Generates execution metadata and QC reports

## The Post-Processing Workflow

### Step 1: Run the Post-Processing Pipeline

After your production pipeline completes, call `runPostProcessing()` to merge and validate all results:

```r
library(picard)

# Orchestrate export for version 1.0.0 across two databases
runPostProcessing(
  pipelineVersion = "1.0.0",
  dbIds = c("omop_cdm", "another_cdm"),
  resultsPath = here::here("exec/results"),
  exportPath = here::here("dissemination/export/merge"),
  cohortsFolderPath = here::here("inputs/cohorts")
)
```

This function:

- **Discovers all tasks** for the specified version
- **Calls `importAndBind()`** for each task to merge results across databases
- **Creates reference files**: cohortKey.csv, databaseInfo.csv
- **Reviews file schemas** with `reviewExportSchema()`
- **Validates cohorts** with `validateCohortResults()`
- **Generates QC reports**: qc_cohortValidation.csv, qc_processMeta.csv

### Output Folder Structure

After orchestration completes, results are organized in:

```
dissemination/export/merge/v1.0.0/
├── 00_buildCohorts.csv          # Cohort counts merged across databases
├── 01_descriptiveStats.csv      # Task 1 results merged
├── 02_primaryAnalysis.csv       # Task 2 results merged
├── cohortKey.csv                # Reference: cohort IDs and labels
├── databaseInfo.csv             # Reference: which databases included
├── schema_review.csv            # Column-level schema of all files
├── qc_cohortValidation.csv      # QC: completeness check
└── qc_processMeta.csv           # QC: execution metadata
```

## Reference Files

### cohortKey.csv

Maps cohort IDs to labels for interpretation. Pulled from your cohort manifest if available:

```
cohortId,cohortLabel,cohortTags
1,Type 2 Diabetes,phenotype
2,CVD Comparator,phenotype
3,MI Outcome,outcome
```

### databaseInfo.csv

Documents which databases were included in the merge:

```
databaseId,databaseName,databaseLabel,cohortTable
omop_cdm,database_1,OMOP CDM - Site A,cohort
uk_biobank,database_2,UK Biobank Linked EHR,cohort_table
```

This helps identify which databases contributed to each result.

### schema_review.csv

Inspects the structure of all exported CSV files. Useful for identifying:

- Column naming inconsistencies
- Unexpected data types
- Columns that need transformation

```
fileName,columnName,dataType,rowCount
cohortCounts.csv,databaseId,character,5
cohortCounts.csv,cohortId,numeric,5
cohortCounts.csv,cohortEntries,numeric,5
descriptiveStats.csv,databaseId,character,120
descriptiveStats.csv,cohortId,numeric,120
descriptiveStats.csv,ageGroup,character,120
```

## Quality Assurance

### qc_cohortValidation.csv

Validates that all cohorts in your cohort key have corresponding results. Flags:

- **OK:** Cohort found in results with non-zero counts
- **ZeroCount:** Cohort found but has zero entries or subjects (non-enumerated)
- **Missing:** Cohort in manifest but not found in results

```
cohortId,label,validationStatus,details
1,Type 2 Diabetes,OK,entries: 245897, subjects: 123456
2,CVD Comparator,OK,entries: 189234, subjects: 98765
3,MI Outcome,ZeroCount,entries: 0, subjects: 0
```

Use this to identify:

- Cohorts that need investigation (why zero?)
- Cohorts that didn't enumerate (possible definition issues)

### qc_processMeta.csv

Records execution metadata for reproducibility:

```
executionTimestamp,pipelineVersion,codeCommitSha,lockfileHash,databasesIncluded,databaseCount,tasksProcessed,totalFilesExported,totalRowsMerged,qcStatus
2024-03-15 14:32:00,1.0.0,abc1234def5678,hash123,OMOP CDM | UK Biobank,2,3,9,542870,OK
```

Tracks:

- **When** the export ran
- **What version** was exported
- **Code state** (git commit SHA for reproducibility)
- **Environment** (renv lockfile hash for dependency reproducibility)
- **Scope** (which databases, how many tasks)
- **Results** (files and rows merged)
- **QC Status** (OK, HasWarnings, or other)

## Advanced: Manual Import and Binding

If you need to merge results for a specific task only, use `importAndBind()`:

```r
library(picard)

# Merge just the descriptive statistics task across all databases
importAndBind(
  version = "1.0.0",
  taskName = "01_descriptiveStats",
  dbIds = c("omop_cdm", "another_cdm"),
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
  resultsFileName = "cohortCounts.csv"
)

# View validation results
print(validation)

# Check for issues
issues <- validation[validation$validationStatus != "OK", ]
```

## Next Steps

1. **Run orchestration:** Call `runPostProcessing()` after production pipeline completes
2. **Review QC reports:** Check qc_cohortValidation.csv and qc_processMeta.csv
3. **Examine schema:** Use schema_review.csv to understand data structure
4. **Handle issues:** If cohorts are missing or zero, investigate in analysis tasks
5. **Prepare dissemination:** Use exported results for publication or further analysis
