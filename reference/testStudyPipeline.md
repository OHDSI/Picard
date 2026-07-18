# Test Study Pipeline

Executes the full study pipeline in test mode using the "dev" pipeline
version. Skips all git validation, renv checks, and version management.
Useful for iterative testing during development.

## Usage

``` r
testStudyPipeline(configBlock, testLabel = "dev", env = rlang::caller_env())
```

## Arguments

- configBlock:

  Character or character vector. Name(s) of config block(s) to use.

- testLabel:

  Character. Label used for test output folder and cohort table suffix.
  Defaults to `"dev"`. Label is normalized to lowercase snake_case and
  truncated to 24 characters.

- env:

  The execution environment. Defaults to caller environment.

## Value

Invisibly returns task results list

## Examples

``` r
if (FALSE) { # \dontrun{
# Test full pipeline on develop branch
testStudyPipeline(configBlock = "myConfig")
# Test full pipeline with a custom namespace
testStudyPipeline(configBlock = "myConfig", testLabel = "feature_ml_test")
} # }
```
