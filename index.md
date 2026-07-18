# picard ![logo](reference/figures/picardLogo.png)

picard is an R package for building and running reproducible,
pipeline-based RWE studies using OHDSI tools. It provides a standardized
study repository structure, manifest-driven input management, and
execution workflows from development through production.

## What picard Helps You Do

picard helps analysts manage the full lifecycle of an RWE pipeline, from
study bootstrap through execution and dissemination.

### 1. Launch a Standard Study Repository (Ulysses)

picard initializes a consistent repository structure and project
scaffolding via the Ulysses setup flow.

- Defines study metadata and contributors
- Configures one or more database blocks
- Creates standard folders, config files, and starter scripts
- Supports Git and reproducibility setup during initialization

### 2. Maintain Execution Settings

picard centralizes DBMS connection and execution configuration through
ExecutionSettings.

- Builds execution settings directly or from config blocks
- Separates schema settings from credential storage
- Supports environment-specific runs and cohort table naming conventions

### 3. Manage Inputs with Manifest Tools

picard uses manifest objects to register and track cohort and concept
set inputs as durable study assets.

- Imports from ATLAS or adds programmatic definitions
- Registers custom SQL and derived cohorts
- Tracks metadata, hashes, dependencies, and status
- Supports mid-cycle maintenance (check, update, delete, reset)

### 4. Create Pipeline Files and Scripts

picard provides file-generation helpers to reduce manual setup and
enforce project conventions.

- Creates task scripts and reusable source utility files
- Creates SQL templates for analysis logic
- Creates pre-pipeline builder scripts for cohorts and concept sets
- Creates dissemination scripts for downstream reporting workflows

### 5. Execute and Monitor the Pipeline

picard supports consistent pipeline execution across study tasks and
database targets.

- Runs cohort generation and task pipelines with execution settings
- Tracks task execution state, rerun logic, and summaries
- Supports structured workflow from development to production runs

### 6. Post-Processing and Dissemination

picard includes tools for combining and formatting outputs into
analyst-ready deliverables.

- Binds results across database runs
- Standardizes outputs for comparison and downstream consumption
- Supports dissemination pipelines and print-friendly output generation

## Install

``` r
# install.packages("remotes")
remotes::install_github("OHDSI/Picard")
library(picard)
```

## Quick Start (Minimal)

``` r
library(picard)

sm <- makeStudyMeta(
  studyTitle = "OMOP Characterization Study",
  therapeuticArea = "Endocrinology",
  studyType = "Characterization",
  contributors = list(
    setContributor(
      name = "Jane Doe",
      email = "jane.doe@institution.org",
      role = "developer"
    )
  )
)

db <- makeBlock(
  configBlockName = "my_cdm",
  cdmDatabaseSchema = "omop_cdm_schema",
  cohortTable = "study_cohorts",
  databaseName = "my_database_v1",
  databaseLabel = "Primary CDM"
)

ulySt <- makeUlyssesStudySettings(
  repoName = "my_study_project",
  repoFolder = "~/studies",
  studyMeta = sm,
  dbConnectionBlocks = list(db)
)

ulySt$initUlyssesRepo(verbose = TRUE, openProject = FALSE)
```

For detailed usage examples and end-to-end workflows, see the package
site and vignettes.

## Documentation

1.  Package site and articles:
    [Articles](https://ohdsi.github.io/Picard/articles/index.md)
2.  Full function reference:
    [Reference](https://ohdsi.github.io/Picard/reference/index.md)
3.  Changelog: [NEWS](https://ohdsi.github.io/Picard/NEWS.md)

## Project Status

picard is under active development. APIs may evolve as pipeline and
manifest workflows mature. Review NEWS before upgrading long-running
studies.

## Contributing

Contributions, issues, and suggestions are welcome. Open an issue or
pull request in the repository.
