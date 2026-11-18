# Create an Input Builder Environment Object

Builds the `inputBuilderEnv` object that input builder scripts in
`inputs/cohorts/R/` and `inputs/conceptSets/R/` can use to build
execution settings without hard-coding a config block or pipeline
version.
[`sourceInputBuilderScripts`](https://ohdsi.github.io/Picard/reference/sourceInputBuilderScripts.md)
creates this object automatically before sourcing those scripts; call
this function to build it standalone while running a builder script
interactively.

## Usage

``` r
createInputBuilderEnv(
  configBlock = NULL,
  pipelineVersion = "prod",
  verbose = TRUE
)
```

## Arguments

- configBlock:

  Character. A single config block name from `config.yml`. Defaults to
  NULL.

- pipelineVersion:

  Character. Pipeline version. Defaults to `"prod"`, matching
  [`createExecutionSettingsFromConfig`](https://ohdsi.github.io/Picard/reference/createExecutionSettingsFromConfig.md).

- verbose:

  Logical. If TRUE (default), prints the resolved metadata.

## Value

A list with `configBlock` and `pipelineVersion`.

## Examples

``` r
if (FALSE) { # \dontrun{
inputBuilderEnv <- createInputBuilderEnv(configBlock = "my_database")

executionSettings <- createExecutionSettingsFromConfig(
  configBlock = inputBuilderEnv$configBlock,
  pipelineVersion = inputBuilderEnv$pipelineVersion
)
} # }
```
