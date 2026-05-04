# Generate Cohorts for Pipeline Execution

Loads the cohort manifest, displays the cohorts to be generated,
optionally prompts for user confirmation, and then generates the cohorts
and retrieves their counts. This function serves as the foundational
step for all subsequent analytical tasks in the pipeline.

## Usage

``` r
generateCohorts(executionSettings, pipelineVersion, override = FALSE)
```

## Arguments

- executionSettings:

  An ExecutionSettings object containing database configuration for
  cohort generation. When created via
  [`createExecutionSettingsFromConfig()`](https://ohdsi.github.io/Picard/reference/createExecutionSettingsFromConfig.md)
  with a non-semver `pipelineVersion` (e.g. "dev", "test"), the cohort
  table name will already have a `_dev` suffix applied, keeping dev runs
  isolated from the production cohort table.

- pipelineVersion:

  Character. The pipeline version used to organize the output folder
  structure. Output will be saved to
  `exec/results/{databaseName}/{pipelineVersion}/00_buildCohorts/`.
  Non-semver values (e.g. "dev") also trigger dev cohort table routing
  via
  [`createExecutionSettingsFromConfig()`](https://ohdsi.github.io/Picard/reference/createExecutionSettingsFromConfig.md).

- override:

  Logical. If TRUE, skips the user confirmation prompt and proceeds
  directly with cohort generation. Defaults to FALSE.

## Value

Invisibly returns the cohort counts data frame (id, label, tags,
cohort_entries, cohort_subjects). Also saves counts to cohortCounts.csv
in the output folder.
