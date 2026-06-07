# Run Post-Processing Pipeline for test mode

Executes post-processing in test mode. QC checks are non-fatal (errors
become warnings) and qcStatus is set to "DevMode". Enforces that the
call is made from a non-main branch to prevent accidental exports on
main.

## Usage

``` r
runTestPostProcessing(
  dbIds,
  pipelineVersion = "dev",
  resultsPath = here::here("exec/results"),
  exportPath = here::here("dissemination/export/merge"),
  cohortsFolderPath = here::here("inputs/cohorts")
)
```

## Arguments

- dbIds:

  Character vector of database configuration IDs from config.yml.

- pipelineVersion:

  Character. Pipeline version label (e.g. "dev").

- resultsPath:

  Character. Path to results root folder. Defaults to "exec/results".

- exportPath:

  Character. Path where combined results will be saved. Defaults to
  "dissemination/export/merge".

- cohortsFolderPath:

  Character. Path to cohorts folder for the CohortManifest. Defaults to
  "inputs/cohorts".

## Value

Invisibly returns the merge summary data frame from runPostProcessing().
