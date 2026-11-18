# Create a Dissemination Environment Object

Builds the `disseminationEnv` object that dissemination scripts in
`dissemination/pretty/R/` rely on.
[`sourceDisseminationScripts`](https://ohdsi.github.io/Picard/reference/sourceDisseminationScripts.md)
creates this object automatically before sourcing those scripts, but
while authoring a script you often want the same metadata at the console
so the code can be tested line by line. Call this function to build it
standalone.

## Usage

``` r
createDisseminationEnv(
  projectPath = here::here(),
  pipelineVersion = NULL,
  databaseIds = NULL,
  outputPath = here::here("dissemination/pretty"),
  verbose = TRUE
)
```

## Arguments

- projectPath:

  Character. Path to the project root directory. Defaults to
  [`here::here()`](https://here.r-lib.org/reference/here.html).

- pipelineVersion:

  Character. The pipeline/study version being disseminated (e.g.,
  "1.0.0"). If NULL (default), attempts to auto-detect from config.yml.

- databaseIds:

  Character vector. Database IDs that were included in postprocessing
  (e.g., c("database_1", "database_2")). If NULL (default), the
  corresponding element is NULL and can be set manually by the user.

- outputPath:

  Character. Base output directory for dissemination scripts. Defaults
  to `here::here("dissemination/pretty")`.

- verbose:

  Logical. If TRUE (default), reports the metadata that was built.

## Value

A list with elements:

- `pipelineVersion`: The version string (or NULL when unknown)

- `databaseIds`: Vector of database IDs (or NULL)

- `outputPath`: Base output directory for results

- `resultsPath`: Merged results path for the version
  (`dissemination/export/merge/v{version}`), or `NA_character_` when the
  version is unknown

## Details

Use this while developing a dissemination script: assign the result to a
variable named `disseminationEnv` in the global environment so the
script body behaves exactly as it will when
[`sourceDisseminationScripts`](https://ohdsi.github.io/Picard/reference/sourceDisseminationScripts.md)
runs it.

## Examples

``` r
if (FALSE) { # \dontrun{
# Build the object interactively while writing a dissemination script
disseminationEnv <- createDisseminationEnv(
  pipelineVersion = "1.0.0",
  databaseIds = c("database_1", "database_2")
)

# Now the script code can be run line by line
results <- readr::read_csv(
  fs::path(disseminationEnv$resultsPath, "cohort_counts.csv")
)
} # }
```
