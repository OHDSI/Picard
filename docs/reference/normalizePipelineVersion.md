# Normalize a test pipeline version (namespace)

Canonical normalization for a test-mode `pipelineVersion`: the value is
lowercased and every run of non-alphanumeric characters collapses to a
single underscore, with leading and trailing underscores removed. The
result is used verbatim as the cohort-table suffix, the results-folder
segment, and the task-history namespace, so all three always agree.

This does **not** truncate. An over-long namespace fails loudly (via the
[ExecutionContext](https://ohdsi.github.io/Picard/reference/ExecutionContext.md)
cohort-table length check) rather than being silently shortened into a
name that no longer matches the folder it was derived alongside.

## Usage

``` r
normalizePipelineVersion(pipelineVersion)
```

## Arguments

- pipelineVersion:

  Character. The user-supplied test namespace.

## Value

Character. The normalized namespace.
