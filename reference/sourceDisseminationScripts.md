# Source Dissemination Scripts

Dissemination scripts are sourced from `dissemination/pretty/R/` in
alphabetical order. Each script is sourced in the global environment, so
any variables, functions, or file outputs are available at the console
level. A `disseminationEnv` object is automatically created and injected
into the global environment for use by dissemination scripts.

## Usage

``` r
sourceDisseminationScripts(
  projectPath = here::here(),
  pipelineVersion = NULL,
  databaseIds = NULL,
  outputPath = here::here("dissemination/pretty"),
  verbose = TRUE,
  warnMissing = TRUE
)
```

## Arguments

- projectPath:

  Character. Path to the project root directory. Defaults to
  [`here::here()`](https://here.r-lib.org/reference/here.html).

- pipelineVersion:

  Character. The pipeline/study version being disseminated (e.g.,
  "1.0.0"). Available to scripts via `disseminationEnv$pipelineVersion`.
  If NULL (default), attempts to auto-detect from config.yml.

- databaseIds:

  Character vector. Database IDs that were included in postprocessing
  (e.g., c("database_1", "database_2")). Available to scripts via
  `disseminationEnv$databaseIds`. If NULL (default), can be set manually
  by user.

- outputPath:

  Character. Base output directory for dissemination scripts. Available
  to scripts via `disseminationEnv$outputPath`. Defaults to
  `here::here("dissemination/pretty")`.

- verbose:

  Logical. If TRUE (default), displays which scripts are being sourced.

- warnMissing:

  Logical. If TRUE (default), warns when the dissemination scripts
  directory doesn't exist.

## Value

Invisibly returns a list with:

- `sourced_files`: Character vector of sourced files (absolute paths)

- `directories_checked`: Character vector of directories checked

- `error_summary`: List of any errors encountered

- `disseminationEnv`: List containing pipelineVersion, databaseIds,
  outputPath

## Details

A convenience function that sources all R scripts from the dissemination
scripts directory in alphabetical order. After the pipeline runs and
[`runPostProcessing`](https://ohdsi.github.io/Picard/reference/runPostProcessing.md)
merges results, this function allows users to source custom
dissemination/formatting scripts to prepare results for Excel export,
StudyHub submission, or other dissemination targets.

Typical workflow:

1.  Run
    [`sourceInputBuilderScripts`](https://ohdsi.github.io/Picard/reference/sourceInputBuilderScripts.md)
    to load input definitions

2.  Run
    [`execStudyPipeline`](https://ohdsi.github.io/Picard/reference/execStudyPipeline.md)
    to execute the analysis

3.  Run
    [`runPostProcessing`](https://ohdsi.github.io/Picard/reference/runPostProcessing.md)
    to merge results across databases

4.  Use
    [`makeDisseminationScript`](https://ohdsi.github.io/Picard/reference/makeDisseminationScript.md)
    to create a template for formatting

5.  Edit the template script with your custom formatting/export logic

6.  Run
    `sourceDisseminationScripts(pipelineVersion = "1.0.0", databaseIds = c("db1", "db2"))`
    to execute your dissemination scripts with metadata

The `disseminationEnv` object is made available to all sourced scripts
and contains:

- `pipelineVersion`: The version string

- `databaseIds`: Vector of database IDs

- `outputPath`: Base output directory for results

- `resultsPath`: Inferred merged results path based on version
