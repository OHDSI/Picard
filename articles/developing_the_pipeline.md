# Developing the Pipeline

> **Note:** This vignette is currently in development and subject to
> change.

## Introduction

Once your repository is initialized (see [Launching a Picard
Study](https://ohdsi.github.io/Picard/articles/launching_a_study.md)),
the next phase is to develop your analysis pipeline. This vignette walks
you through the complete development workflow on the `develop` branch,
from defining inputs through testing your code.

## Development Workflow Overview

The typical workflow is:

1.  Finalize Git and renv setup
2.  Create your development branch
3.  Define your inputs (cohorts and concept sets)
4.  Create analysis tasks and supporting code
5.  Commit your changes with
    [`saveWork()`](https://ohdsi.github.io/Picard/reference/saveWork.md)
6.  Test individual tasks and the full pipeline
7.  Iterate until your analysis is complete

## Step 1: Finalize Git and renv Setup

**Git:** You already have a local repository. If you provided
`gitRemote` during setup, your code is already synced. If not, see
[Setting Up Git Version
Control](https://ohdsi.github.io/Picard/articles/launching_a_study.html#setting-up-git-version-control)
in the launching vignette to push your code to a remote.

**renv:** This is your responsibility. It’s **highly encouraged** to set
this up immediately:

``` r
renv::init() # done in the project root directory
```

This captures your current R environment, ensuring reproducibility for
your team. You should set up renv on main before switching to develop,
so that your development branch inherits the same environment. After
running `renv::init()`, commit the changes to Git:

## Step 2: Create Your Development Branch

All development work happens on the `develop` branch (never on `main`):

``` bash
# Create and switch to develop branch
git checkout -b develop
git push -u origin develop
```

All subsequent work will be done here and tested before any production
execution.

## Step 3: Define Your Inputs (Cohorts and Concept Sets)

Before writing analysis code, you need to define the populations and
phenotypes. This happens in the `inputs/` folder:

**For Cohorts:** Use the interactive editor to add your study
populations:

``` r
launchCohortsLoadEditor(cohortsFolderPath = here::here("inputs/cohorts"))
```

This opens a Shiny app where you can add cohort metadata without editing
CSV files directly.

**For Concept Sets:** Similarly, define your phenotypes:

``` r
launchConceptSetsLoadEditor(conceptSetsFolderPath = here::here("inputs/conceptSets"))
```

See [Loading
Inputs](https://ohdsi.github.io/Picard/articles/loading_inputs.md) for
detailed guidance on importing from ATLAS and managing manifests.

## Step 4: Create Analysis Tasks and Supporting Code

Analysis happens in the `analysis/` folder, which has two key
subdirectories:

**Tasks** (`analysis/tasks/`) - Main workflow files executed by the
pipeline **Source** (`analysis/src/`) - Supporting functions and
utilities used by tasks

### Creating a Task

Use
[`makeTaskFile()`](https://ohdsi.github.io/Picard/reference/makeTaskFile.md)
to scaffold a new task:

``` r
makeTaskFile(
  nameOfTask = "DescriptiveStats",
  author = "Jane Doe",
  description = "Generate descriptive statistics for primary cohort",
  projectPath = here::here(),
  openFile = TRUE
)
```

This creates a standardized R script in `analysis/tasks/` with a
template structure. The filename is automatically generated as
`01_descriptive_stats.R`.

**Task Naming Convention:**
[`makeTaskFile()`](https://ohdsi.github.io/Picard/reference/makeTaskFile.md)
automatically handles the numbering based on existing files in your
`analysis/tasks/` folder. You simply provide the task name (e.g.,
`"DescriptiveStats"`), and
[`makeTaskFile()`](https://ohdsi.github.io/Picard/reference/makeTaskFile.md)
will: - Count existing task files - Generate the next sequential number
(01, 02, 03, etc.) - Convert your task name to snake_case - Create the
file as `NN_task_name.R`

Tasks execute in alphabetical order, so the automatic numbering controls
the execution sequence.

### Creating Supporting Source Files

For reusable utility functions, create files in `analysis/src/` using
[`makeSrcFile()`](https://ohdsi.github.io/Picard/reference/makeSrcFile.md):

``` r
makeSrcFile(
  fileName = "custom_analysis_functions",
  author = "Jane Doe",
  description = "Helper functions for cohort calculations and data validation"
)
```

This creates a standardized R script in
`analysis/src/custom_analysis_functions.R` with a template structure for
your utility functions.

**File Naming Convention:** Use `snake_case` for the `fileName`
parameter. The function will convert your input to snake_case
automatically, so `"customAnalysisFunctions"`,
`"CustomAnalysisFunctions"`, or `"custom_analysis_functions"` will all
become `custom_analysis_functions.R`.

**Important:** Treat source files like R package development:

- **Use `package::function()` notation** instead of
  [`library()`](https://rdrr.io/r/base/library.html) calls:

  ``` r
  # Good: Use explicit namespace
  result <- dplyr::filter(data, age > 18)

  # Avoid: Loading entire library
  # library(dplyr)
  # result <- filter(data, age > 18)
  ```

  This makes dependencies explicit and avoids namespace conflicts.

- **Document each function** with a clear comment block describing:

  - What the function does
  - What inputs it expects
  - What it returns

  Example:

  ``` r
  # Purpose: Calculate age in years from birth date
  # Inputs: birth_date (Date or character in YYYY-MM-DD format)
  # Returns: Numeric age in years
  calculate_age <- function(birth_date) {
    birth_date <- as.Date(birth_date)
    age <- as.numeric(lubridate::interval(birth_date, Sys.Date()), "years")
    return(floor(age))
  }
  ```

Then source these files from your tasks in the **B. Dependencies**
section at the top of the task file:

``` r
# B. Dependencies ---------------

library(picard)
library(DatabaseConnector)
library(tidyverse)

# Source utility functions
source(here::here("analysis/src/custom_analysis_functions.R"))
```

### Creating SqlRender SQL Queries

For parameterized SQL queries used with SqlRender, create files in
`analysis/src/sql/` using
[`makeSrcSqlFile()`](https://ohdsi.github.io/Picard/reference/makeSrcSqlFile.md):

``` r
makeSrcSqlFile(
  fileName = "drug_exposure_summary",
  author = "Jane Doe",
  description = "Create a summary table of drug exposure by observation period"
)
```

This creates a standardized SQL file in
`analysis/src/sql/drug_exposure_summary.sql` with placeholders for
SqlRender parameters.

**Important:** SqlRender uses `@paramName` notation for substitution.
Here’s a realistic example that builds an intermediate work table with
multi-step logic:

``` sql
/* 
Document your parameters at the top:
  @cdmDatabaseSchema - Schema containing OMOP CDM tables
  @workDatabaseSchema - Schema for output tables
  @workTableName - Name of the intermediate work table to create
  @studyStartDate - Start date for filtering
  @studyEndDate - End date for filtering
*/

-- Create intermediate table of drug exposures by observation period
CREATE TABLE @workDatabaseSchema.@workTableName AS

WITH obs_periods AS (
  -- Get all observation periods for study participants
  SELECT 
    person_id,
    observation_period_start_date,
    observation_period_end_date
  FROM @cdmDatabaseSchema.observation_period
  WHERE observation_period_start_date >= '@studyStartDate'
    AND observation_period_start_date <= '@studyEndDate'
),

drug_exp AS (
  -- Get drug exposures during these observation periods
  SELECT
    d.person_id,
    op.observation_period_start_date,
    op.observation_period_end_date,
    d.drug_concept_id,
    d.drug_exposure_start_date,
    COALESCE(d.drug_exposure_end_date, d.drug_exposure_start_date) AS drug_exposure_end_date,
    COALESCE(d.days_supply, 1) AS days_supply
  FROM @cdmDatabaseSchema.drug_exposure d
  JOIN obs_periods op
    ON d.person_id = op.person_id
    AND d.drug_exposure_start_date >= op.observation_period_start_date
    AND d.drug_exposure_start_date <= op.observation_period_end_date
),

person_summary AS (
  -- Aggregate to person-level summaries
  SELECT
    person_id,
    observation_period_start_date,
    observation_period_end_date,
    COUNT(DISTINCT drug_concept_id) AS num_unique_drugs,
    COUNT(DISTINCT drug_exposure_start_date) AS num_drug_exposures,
    SUM(days_supply) AS total_days_supply,
    AVG(days_supply) AS avg_days_supply,
    MIN(drug_exposure_start_date) AS first_drug_date,
    MAX(drug_exposure_end_date) AS last_drug_date
  FROM drug_exp
  GROUP BY person_id, observation_period_start_date, observation_period_end_date
)

SELECT * FROM person_summary;
```

**Best Practice:** Wrap your SQL queries in utility functions stored in
`analysis/src/` files, then call those functions from your tasks. This
keeps SQL execution logic organized and reusable:

``` r
# Example utility function in analysis/src/execute_sql_queries.R

get_drug_exposure_summary <- function(executionSettings,
                                      workTableName = "drug_exposure_summary",
                                      studyStartDate = "2020-01-01",
                                      studyEndDate = "2023-12-31") {
  # Read the SQL file
  sql <- readr::read_file(here::here("analysis/src/sql/drug_exposure_summary.sql"))
  
  # Step 1: Render parameters using SqlRender
  rendered_drug_sql <- SqlRender::render(
    sql,
    cdmDatabaseSchema = executionSettings$cdmDatabaseSchema,
    workDatabaseSchema = executionSettings$workDatabaseSchema,
    workTableName = workTableName,
    studyStartDate = studyStartDate,
    studyEndDate = studyEndDate
  )
  
  # Step 2: Translate to DBMS dialect
  # The ExecutionSettings object knows your DBMS type and tempEmulationSchema
  translated_drug_sql <- SqlRender::translate(
    rendered_drug_sql,
    targetDialect = executionSettings$getDbms(),
    tempEmulationSchema = executionSettings$tempEmulationSchema
  )
  
  # Get the connection from ExecutionSettings
  connection <- executionSettings$getConnection()
  
  # If connection is null, establish one
  if (is.null(connection)) {
    executionSettings$connect()
    connection <- executionSettings$getConnection()
  }
  
  # Step 3: Execute the query to create the work table
  DatabaseConnector::executeSql(connection, translated_drug_sql)
  
  # Step 4: Query the created table to retrieve results
  # Use SqlRender and translate for the SELECT query as well
  select_query <- "SELECT * FROM @workDatabaseSchema.@workTableName"
  
  rendered_select <- SqlRender::render(
    select_query,
    workDatabaseSchema = executionSettings$workDatabaseSchema,
    workTableName = workTableName
  )
  
  translated_select <- SqlRender::translate(
    rendered_select,
    targetDialect = executionSettings$getDbms(),
    tempEmulationSchema = executionSettings$tempEmulationSchema
  )
  
  results <- DatabaseConnector::querySql(connection, translated_select)
  
  # Disconnect from the database
  executionSettings$disconnect()
  
  cli::cli_alert_success("Drug exposure summary retrieved successfully")
  
  return(results)
}
```

Then call this function from your task file:

``` r
# In your task file (e.g., 02_drug_exposure_analysis.R)
source(here::here("analysis/src/execute_sql_queries.R"))

# Execute the SQL query and collect results
drug_summary <- get_drug_exposure_summary(
  executionSettings = executionSettings,
  workTableName = "drug_exp_summary",
  studyStartDate = "2020-01-01",
  studyEndDate = "2023-12-31"
)

# Now work with results in R
head(drug_summary)
```

**Workflow Summary:** 1. SQL file creates the intermediate work table
with computed values 2. R function orchestrates render → translate →
execute → collect 3. Task file sources the utility function and gets
back a dataframe 4. All database configuration comes from
`ExecutionSettings`

## Step 5: Commit Changes with `saveWork()`

After creating your analysis code, commit your changes to track them in
Git. Picard provides
[`saveWork()`](https://ohdsi.github.io/Picard/reference/saveWork.md) to
make Git commits easy for new users:

``` r
saveWork("Add descriptive statistics task")
```

[`saveWork()`](https://ohdsi.github.io/Picard/reference/saveWork.md) is
a convenience wrapper around Git operations that handles the common
workflow for you:

1.  **Show what changed** - Displays all modified, new, and deleted
    files
2.  **Confirm commit** - Asks you to approve the changes before
    proceeding
3.  **Stage files** - Automatically stages all changes
4.  **Commit** - Creates a commit with your message
5.  **Pull from remote** - Gets the latest changes from your team
6.  **Push to remote** - Syncs your commit to the shared repository

**Key features:**

- **Protection from mistakes:** Prevents you from accidentally
  committing to the `main` branch
- **Interactive confirmation:** Shows exactly which files changed and
  asks you to confirm before committing
- **Work-in-progress commits:** Use `push = FALSE` to commit locally
  without pushing (useful for saving work mid-session):

``` r
saveWork("WIP: Testing new validation logic", push = FALSE)
```

- **Automatic branch creation:** If your feature branch doesn’t exist,
  [`saveWork()`](https://ohdsi.github.io/Picard/reference/saveWork.md)
  creates it for you
- **Syncs with team:** Pulls remote changes before pushing your work,
  reducing merge conflicts

**Full function signature:**

``` r
saveWork(
  commitMessage,                    # Required: Descriptive message
  branch = get_current_branch(),    # Current branch (or specify new one)
  push = TRUE,                      # FALSE for local-only commits
  gitRemoteName = "origin"          # Remote repository name
)
```

**For new Git users:** Use
[`saveWork()`](https://ohdsi.github.io/Picard/reference/saveWork.md)
regularly as you develop. It simplifies the entire commit workflow and
protects you from common Git mistakes.

**For advanced users:** You can use Git directly if you prefer. Many
developers commit changes as they go using:

``` bash
git add analysis/tasks/01_DescriptiveStats.R
git commit -m "Add descriptive statistics task"
git pull origin develop
git push origin develop
```

Either approach works—use what’s comfortable for your workflow.

## Step 6: Test Your Development Work

Picard provides two testing modalities on the `develop` branch:

### Test Single Task with `testStudyTask()`

Test a specific task file in isolation:

``` r
testStudyTask(
  taskFile = "01_descriptive_stats.R",
  configBlock = "omop_cdm"
)
```

**Parameters:** - `taskFile`: The base name of your task file (just the
filename, no path) - `configBlock`: The name of your config block (e.g.,
the database config you want to use)

This executes only the specified task, allowing rapid iteration on
specific tasks without running the entire pipeline. The function
automatically uses “dev” version for testing and prevents running on the
`main` branch.

### Test Full Pipeline with `testStudyPipeline()`

Once individual tasks work, test the complete pipeline:

``` r
testStudyPipeline(configBlock = "omop_cdm")
```

**Parameters:** - `configBlock`: The name of your config block (can be a
single value or vector of multiple configs)

This runs all tasks in sequence (in alphabetical order) with the same
configuration as production, helping you catch integration issues.

**Testing Workflow:** 1. Edit a task file 2. Run
`testStudyTask(taskFile = "01_your_task.R", configBlock = "omop_cdm")`
to verify changes to that specific task 3. Once satisfied, run
`testStudyPipeline(configBlock = "omop_cdm")` to verify the full
workflow 4. Commit your changes with
[`saveWork()`](https://ohdsi.github.io/Picard/reference/saveWork.md)

### Commit and Push to Develop

After testing successfully, commit your changes using either
[`saveWork()`](https://ohdsi.github.io/Picard/reference/saveWork.md) or
Git commands directly (see [Commit Changes with
`saveWork()`](#step-5-commit-changes-with-savework) earlier in this
vignette for details).

## Next Steps: Production Execution

Once your analysis is tested and validated on `develop`, see [Running
the
Pipeline](https://ohdsi.github.io/Picard/articles/running_the_pipeline.md)
for instructions on production execution, which involves creating a
release branch and running the full validated pipeline.

## Quick Reference: Key Functions by Phase

| Phase           | Function                                                                               | Purpose                                        |
|-----------------|----------------------------------------------------------------------------------------|------------------------------------------------|
| **Setup**       | `launchCohortsLoadEditor()`                                                            | Interactive cohort metadata editor             |
| **Setup**       | `launchConceptSetsLoadEditor()`                                                        | Interactive concept set editor                 |
| **Development** | [`makeTaskFile()`](https://ohdsi.github.io/Picard/reference/makeTaskFile.md)           | Create new analysis task                       |
| **Development** | [`makeSrcFile()`](https://ohdsi.github.io/Picard/reference/makeSrcFile.md)             | (optional) Create utility/helper function file |
| **Development** | [`makeSrcSqlFile()`](https://ohdsi.github.io/Picard/reference/makeSrcSqlFile.md)       | (optional) Create parameterized SQL query file |
| **Development** | [`saveWork()`](https://ohdsi.github.io/Picard/reference/saveWork.md)                   | Commit and push code changes to remote         |
| **Testing**     | [`testStudyTask()`](https://ohdsi.github.io/Picard/reference/testStudyTask.md)         | Test single task file                          |
| **Testing**     | [`testStudyPipeline()`](https://ohdsi.github.io/Picard/reference/testStudyPipeline.md) | Test full pipeline end-to-end                  |
| **Production**  | See Running the Pipeline                                                               | Execute on release branch                      |

## See Also

- [Launching a Picard
  Study](https://ohdsi.github.io/Picard/articles/launching_a_study.md) -
  Repository initialization and setup
- [Loading
  Inputs](https://ohdsi.github.io/Picard/articles/loading_inputs.md) -
  Setting up cohorts and concept sets
- [Running the
  Pipeline](https://ohdsi.github.io/Picard/articles/running_the_pipeline.md) -
  Production pipeline execution
