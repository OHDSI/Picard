# Classify a pipeline version string as production or test

A `pipelineVersion` string carries its own mode: the sentinel `"prod"`
and any `MAJOR.MINOR.PATCH` string mean a production run against the
configured cohort table; every other value (`"dev"`, `"develop_ml"`, …)
is a test namespace. This is the single classifier used by
[`newExecutionContext()`](https://ohdsi.github.io/Picard/reference/newExecutionContext.md),
[`createExecutionSettingsFromConfig()`](https://ohdsi.github.io/Picard/reference/createExecutionSettingsFromConfig.md),
and the results-path helpers.

## Usage

``` r
isProductionPipelineVersion(pipelineVersion)
```

## Arguments

- pipelineVersion:

  Character.

## Value

Logical. `TRUE` for a production version.
