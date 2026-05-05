# Production Study Pipeline Execution

Executes the full study pipeline in production mode with full
validation, version management, and reproducibility tracking. Creates a
release branch, runs the complete pipeline, provides PR instructions,
and saves reference to PENDING_PR.md.

## Usage

``` r
execStudyPipeline(
  configBlock,
  updateType,
  skipRenv = FALSE,
  skipConnectivityCheck = TRUE,
  env = rlang::caller_env()
)
```

## Arguments

- configBlock:

  Character or character vector. Name(s) of config block(s) to use.

- updateType:

  Character. Type of version increment: 'major', 'minor', or 'patch'.

  - MAJOR: Breaking changes

  - MINOR: New features, backward compatible

  - PATCH: Bug fixes, no new features

- skipRenv:

  Logical. If TRUE, skips renv validation. Defaults to FALSE. Useful for
  testing issues. Default: FALSE

- skipConnectivityCheck:

  Logical. If TRUE (default), skips the optional database connectivity
  pre-flight check. Set to FALSE to attempt a test connection to each
  config block before execution begins.

- env:

  The execution environment. Defaults to caller environment.

## Value

Invisibly returns task results list

## Examples

``` r
if (FALSE) { # \dontrun{
# Run production pipeline with patch version increment
execStudyPipeline(configBlock = "myConfig", updateType = "patch")
} # }
```
