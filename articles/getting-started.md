# Getting Started with picard

## Getting Started with picard

picard is an R package designed as an RWE Pipelining Tool favoring OHDSI
tools. Like its namesake, picard will allow RWE researchers to explore
strange new worlds within their data, seeking out new patterns and
analyses, and boldly going where no researcher has gone before!

### Installation and Setup

Install and load the picard package:

``` r
library(picard)
```

### Begin a new Ulysses Repo

The `picard` package begins by initializing a Ulysses Repo. This is a
standard repo structure to conduct an RWE pipeline using OHDSI tools.
This is a maturation of the `Ulysses` package which was retired due to
technical advances and reframing of the use-case as a pipeline tool.

#### Create Study Metadata

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

#### Configure Database Connection

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

#### Define Execution Options

Specify how and where to execute your analysis:

``` r
eo <- makeExecOptions(
  dbms = "snowflake",
  workDatabaseSchema = "work_schema",
  tempEmulationSchema = "work_schema",
  dbConnectionBlocks = list(db)
)
```

#### Initialize Project

Create and initialize your study repository:

``` r
ulySt <- makeUlyssesStudySettings(
  repoName = "my_study_project",
  toolType = "dbms",
  repoFolder = "~/studies/my_study_project",
  studyMeta = sm,
  execOptions = eo
)

# Initialize the repository structure
ulySt$initUlyssesRepo(verbose = TRUE, openProject = FALSE)
```

This will create a standardized directory structure for your study with
all necessary configuration files and folders.

### Cohort Management and Generation

Once your study environment is initialized, you can manage and generate
cohorts using the CohortManifest.

#### Load Execution Settings

Load your database configuration from the config file:

``` r
settings <- createExecutionSettingsFromConfig(configBlock = "omop_cdm")
```

#### Import Cohorts from ATLAS

Before importing our cohorts we need to provide a load list. This can be
done interactively:

``` r
launchCohortsLoadEditor()
```

Import cohort definitions from your ATLAS instance:

``` r
importAtlasCohorts(
  cohortsFolderPath = here::here("inputs/cohorts"),
  atlasConnection = setAtlasConnection()
)
```

For you to set up the atlas connection you need to provide your
credentials for logging into webApi. Follow this template to add
credentials to .Renviron file:

``` r
templateAtlasCredentials()
```

#### Load and View Cohort Manifest

Create a CohortManifest and examine available cohorts:

``` r
cm <- loadCohortManifest(executionSettings = settings)
cm$getManifest()
```

#### Create Cohort Tables

Initialize the necessary database tables for cohort storage:

``` r
cm$createCohortTables()
```

#### Generate Cohorts

Execute the cohort generation process:

``` r
cm$generateCohorts()
```

#### Retrieve Cohort Counts

Get summary statistics for all generated cohorts:

``` r
counts <- cm$retrieveCohortCounts()
```

This will return a data frame with: - `cohort_id`: The cohort definition
ID - `label`: The cohort label - `tags`: Associated cohort tags -
`cohort_entries`: Total number of cohort records - `cohort_subjects`:
Number of distinct subjects in each cohort
