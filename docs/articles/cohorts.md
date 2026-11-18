# Managing Cohorts with picard

## Managing Cohorts with picard

Cohorts are groups of patients that meet specific criteria. picard
provides tools to define, organize, and manage cohorts throughout your
study lifecycle.

### What is a Cohort?

A cohort definition specifies the inclusion and exclusion criteria for a
patient population. Examples include: - All patients diagnosed with Type
2 Diabetes - All patients aged 65+ with chronic kidney disease - All
patients receiving a specific medication during a time window

### Creating Cohort Definitions

#### Loading Base Cohorts from ATLAS

``` r
library(picard)

# First, export cohort definitions from ATLAS and save to inputs/cohorts/json/

# Load a cohort definition from file
type2dm_cohort <- CohortDef$new(
  label = "Type 2 Diabetes",
  tags = list(category = "condition", domain = "endocrine", source = "atlas"),
  filePath = "inputs/cohorts/json/type2dm.json"
)

# Access properties
type2dm_cohort$label               # User-friendly name
type2dm_cohort$tags                # Metadata tags
type2dm_cohort$getHash()           # Hash of current definition (for change detection)
type2dm_cohort$getSql()            # Generated SQL from CIRCE JSON
type2dm_cohort$getFilePath()       # Relative path to file
```

#### Importing Cohorts from ATLAS

``` r
# Import multiple cohort definitions from ATLAS directly
importAtlasCohorts(
  atlasIds = c(1, 2, 3, 4),
  outputPath = "inputs/cohorts/json"
)

# After import, create CohortDef objects for each
cohort1 <- CohortDef$new(
  label = "Base Cohort 1",
  tags = list(source = "atlas", import_date = Sys.Date()),
  filePath = "inputs/cohorts/json/cohort_1.json"
)
```

### Organizing Cohorts with Manifests

#### Creating and Using the Cohort Manifest

``` r
# Create CohortDef objects for your cohorts
base_cohort <- CohortDef$new(
  label = "Type 2 Diabetes Base",
  tags = list(category = "base", domain = "condition"),
  filePath = "inputs/cohorts/json/type2dm.json"
)

hypertension <- CohortDef$new(
  label = "Hypertension",
  tags = list(category = "base", domain = "condition"),
  filePath = "inputs/cohorts/json/hypertension.json"
)

ckd <- CohortDef$new(
  label = "Chronic Kidney Disease",
  tags = list(category = "base", domain = "condition"),
  filePath = "inputs/cohorts/json/ckd.json"
)

# Create manifest with all cohorts
exec_settings <- createExecutionSettings(
  connectionDetails = connection_details,
  cdmDatabaseSchema = "cdm.dbo",
  workDatabaseSchema = "results.dbo",
  tempEmulationSchema = NULL,
  cohortTable = "cohort",
  databaseName = "optum_dod"
)

cohort_manifest <- CohortManifest$new(
  cohortEntries = list(base_cohort, hypertension, ckd),
  executionSettings = exec_settings,
  dbPath = "inputs/cohorts/cohort_manifest.sqlite"
)

# View all cohorts in manifest
manifest_df <- cohort_manifest$tabulateManifest()
print(manifest_df)
```

### Building Dependent Cohorts

picard supports building new cohorts from existing ones using temporal
and demographic filters.

#### Building Demographic Subsets

``` r
# Create cohort subset based on age and gender
type2dm_females_40_65 <- buildSubsetCohortDemographic(
  label = "Type 2 Diabetes - Females 40-65",
  baseCohortId = 1,
  minAge = 40,
  maxAge = 65,
  genderConceptIds = c(8532),  # 8532 = Female in OMOP CDM
  manifest = cohort_manifest
)

# Add to manifest for tracking
cohort_manifest$addCohort(type2dm_females_40_65)

# Gender concept IDs in OMOP CDM:
# 8507 = Male
# 8532 = Female
# 8521 = Ambiguous
# 8551 = Unknown
```

#### Building Temporal Subsets

``` r
# Create subset of patients where one cohort occurs before another
ckd_with_prior_diabetes <- buildSubsetCohortTemporal(
  label = "CKD with Prior Diabetes (1-5 years before)",
  baseCohortId = 3,           # CKD cohort
  filterCohortId = 1,         # Type 2 Diabetes cohort
  temporalOperator = "before",
  temporalStartOffset = -1825L,  # 5 years before CKD
  temporalEndOffset = -365L,     # 1 year before CKD
  manifest = cohort_manifest
)

# Temporal operators: 'during', 'before', 'after', 'overlapping'
# Temporal offsets: negative = before, positive = after relative to base cohort
```

#### Building Union Cohorts

``` r
# Combine multiple cohorts - patients in any of them
hypertension_or_diabetes <- buildUnionCohort(
  label = "Hypertension OR Diabetes",
  baseCohortIds = c(1, 2),      # Type2DM and Hypertension
  unionType = "any",            # Any cohort
  cohortsDirectory = "inputs/cohorts",
  manifest = cohort_manifest
)

# Union types: 'any', 'all', 'at_least_n'
```

#### Building Complement Cohorts

``` r
# Exclude patients - patients in base but NOT in exclude cohort
hypertension_without_diabetes <- buildComplementCohort(
  label = "Hypertension without Diabetes",
  baseCohortIds = 2,            # Hypertension
  excludeCohortIds = 1,         # Exclude Type 2 Diabetes
  cohortsDirectory = "inputs/cohorts",
  manifest = cohort_manifest
)
```

### Directory Structure

picard expects cohorts organized as follows:

    study_repo/
    ├── inputs/
    │   ├── cohorts/
    │   │   ├── json/               # ATLAS JSON definitions
    │   │   │   ├── type2dm.json
    │   │   │   ├── hypertension.json
    │   │   │   └── ckd.json
    │   │   ├── derived/            # Auto-generated derived cohorts
    │   │   │   ├── subset/
    │   │   │   ├── subset_demo/
    │   │   │   ├── union/
    │   │   │   └── complement/
    │   │   └── cohort_manifest.sqlite

### Loading Existing Manifests

``` r
# Load a previously saved cohort manifest
cohort_manifest <- loadCohortManifest(
  manifestPath = "inputs/cohorts/cohort_manifest.sqlite"
)

# View cohorts
manifest_df <- cohort_manifest$getManifest()
print(manifest_df)

# Get specific cohort
cohort_1 <- cohort_manifest$getCohortById(1)
```

### Handling Cohort Changes

#### Detecting Definition Changes

``` r
# Cohort definitions are hashed to detect changes
new_hash <- type2dm_cohort$getHash()

# If JSON file changes, hash changes, triggering regeneration
# This ensures results stay in sync with definitions
```

#### Resetting Manifests

``` r
# Clear manifest if starting fresh
resetCohortManifest(
  manifestPath = "inputs/cohorts/cohort_manifest.sqlite"
)

# This removes the database without deleting the JSON source files
```

### Best Practices

1.  **Version control definitions** - Store JSON files in Git
2.  **Use descriptive labels** - Help analysts understand cohort purpose
3.  **Document inclusion/exclusion** - Add tags explaining criteria
4.  **Validate definitions** - Test cohort logic before execution
5.  **Track dependencies** - Use manifest to track cohort relationships
6.  **Export regularly** - Save working cohort definitions from ATLAS
7.  **Archive versions** - Keep historical versions for reproducibility

### Common Patterns

#### Stepped care cohort building

``` r
# Build progression: base → demographics → temporal → combination

# 1. Base conditions
diabetes_base <- CohortDef$new(...)
hypertension_base <- CohortDef$new(...)

# 2. Add age/gender restrictions
diabetes_adults <- buildSubsetCohortDemographic(
  label = "Diabetes Adults",
  baseCohortId = 1,
  minAge = 18
)

# 3. Add temporal logic
on_therapy <- buildSubsetCohortTemporal(
  label = "Diabetes with recent therapy",
  baseCohortId = diabetes_adults$getId(),
  filterCohortId = therapy_cohort_id,
  temporalOperator = "during"
)
```

### Troubleshooting

**Issue: Cohort definition not loading** - Verify JSON file exists at
specified path - Check JSON is valid CIRCE format exported from ATLAS -
Verify file permissions are readable

**Issue: Hash mismatch detected** - Check if JSON source file was
modified - Compare current vs. stored hash to find differences -
Regenerate cohort if intentional changes made

**Issue: Dependencies not resolved** - Verify base cohort IDs exist in
manifest - Use `manifest` parameter in build functions to validate -
Check cohort ID assignments are sequential

### Resources

- OHDSI CIRCE: Cohort definition tool in ATLAS
- OMOP CDM: Common Data Model documentation
- picard GitHub: Full API documentation and examples

For more information, see
[`?CohortDef`](https://ohdsi.github.io/Picard/reference/CohortDef.md)
and
[`?CohortManifest`](https://ohdsi.github.io/Picard/reference/CohortManifest.md).
