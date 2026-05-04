# Test Study Pipeline

Executes the full study pipeline in test mode using the "dev" pipeline
version. Skips all git validation, renv checks, and version management.
Useful for iterative testing during development.

## Usage

``` r
testStudyPipeline(configBlock, env = rlang::caller_env())
```

## Arguments

- configBlock:

  Character or character vector. Name(s) of config block(s) to use.

- env:

  The execution environment. Defaults to caller environment.

## Value

Invisibly returns task results list

## Examples

``` r
if (FALSE) { # \dontrun{
# Test full pipeline on develop branch
testStudyPipeline(configBlock = "myConfig")
} # }
```
