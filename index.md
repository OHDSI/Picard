# picard ![logo](reference/figures/picardLogo.png)

This R package is designed to be an RWE Pipelining Tool favoring OHDSI
tools. Like its namesake, the picard package will allow RWE researchers
to explore strange new worlds within their data, seeking out new
patterns and analyses, and boldly going where no researcher has gone
before!

# Quick Start

Install and load the picard package:

``` r
library(picard)
```

## Begin a new Ulysses Repo

The `picard` package begins by initializing a Ulysses Repo. This is a
standard repo structure to conduct an RWE pipeline using OHDSI tools.
This is a maturation of the `Ulysses` package which was retired due to
the technical advances and reframing of the use-case as a pipeline tool.

### Create Study Metadata

Define your study with contributors and basic information:

``` r
sm <- makeStudyMeta(
  studyTitle = "OMOP Characterization Study",
  therapeuticArea = "Inflamation",
  studyType = "Characterization",
  contributors = list(
    setContributor(
      name = "Jean-Luc Picard",
      email = "jeanluc.picard@ussenterprise.com",
      role = "lead"
    ),
    setContributor(
      name = "Data Spiner",
      email = "data.spiner@ussenterprise.com",
      role = "analyst"
    )
  ),
  studyTags = c("OMOP", "OHDSI", "Analysis")
)
```

### Configure Database Connection

Set up your OMOP CDM database configuration:

``` r
db <- setDbConfigBlock(
  configBlockName = "omop_cdm",
  cdmDatabaseSchema = "public_omop_cdm",
  databaseName = "omop_database",
  cohortTable = "study_cohort",
  databaseLabel = "OMOP CDM Instance"
)
```

### Initialize Project

Create and initialize your study repository (the `dbConnectionBlocks`
carry all DBMS/schema info from your config blocks):

``` r
ulySt <- makeUlyssesStudySettings(
  repoName = "my_study_project",
  repoFolder = "~/studies/my_study_project",
  studyMeta = sm,
  dbConnectionBlocks = list(db)
)

# Initialize the repository structure
ulySt$initUlyssesRepo(verbose = TRUE, openProject = FALSE)
```

This will create a standardized directory structure for your study with
all necessary configuration files and folders.

## Cohort Management and Generation

Once your study environment is initialized, you can manage and generate
cohorts using the CohortManifest.

### Load Execution Settings

Load your database configuration from the config file:

``` r
settings <- createExecutionSettingsFromConfig(configBlock = "omop_cdm")
```

### Import Cohorts from ATLAS

Before importing cohorts, create a load list by running:

``` r
createBlankCohortsLoadFile()
```

Edit `inputs/cohorts/cohortsLoad.csv` in Excel to add your ATLAS cohort
IDs and metadata. Then import:

``` r
cohortManifest <- CohortManifest$new(dbPath = here::here("inputs/cohorts/manifest.sqlite"))
importAtlasCohorts(
  manifest = cohortManifest,
  atlasConnection = setAtlasConnection(),
  cohortsLoadPath = here::here("inputs/cohorts/cohortsLoad.csv")
)
```

For you to set up the atlas connection you need to provide your
credentials for logging into webApi. Follow this template to add
credentials to .Renviron file:

``` r
templateAtlasCredentials()
```

### Load and View Cohort Manifest

Create a CohortManifest and examine available cohorts:

``` r
cm <- loadCohortManifest(executionSettings = settings)
cm$getManifest()
```

### Create Cohort Tables

Initialize the necessary database tables for cohort storage:

``` r
cm$createCohortTables()
```

### Generate Cohorts

Execute the cohort generation process:

``` r
cm$generateCohorts()
```

### Retrieve Cohort Counts

Get summary statistics for all generated cohorts:

``` r
counts <- cm$retrieveCohortCounts()
```

This will return a data frame with: - `cohort_id`: The cohort definition
ID - `label`: The cohort label - `tags`: Associated cohort tags -
`cohort_entries`: Total number of cohort records - `cohort_subjects`:
Number of distinct subjects in each cohort
