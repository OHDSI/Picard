# Build an ExecutionContext from a pipeline version string

The single place that turns a raw `pipelineVersion` into an
[ExecutionContext](https://ohdsi.github.io/Picard/reference/ExecutionContext.md):
it classifies the mode (unless `testMode` forces it) and derives
`studyVersion`, so callers never hand-roll `mode = ` /
`studyVersion = `.

## Usage

``` r
newExecutionContext(
  pipelineVersion,
  testMode = NULL,
  databaseName = NULL,
  execPath = here::here("exec/results")
)
```

## Arguments

- pipelineVersion:

  Character. A semantic version, `"prod"`, or a test namespace.

- testMode:

  Logical or `NULL`. `NULL` (default) infers the mode from
  `pipelineVersion` via
  [`isProductionPipelineVersion()`](https://ohdsi.github.io/Picard/reference/isProductionPipelineVersion.md);
  `TRUE`/`FALSE` forces it (used by the pipeline, which already knows).

- databaseName:

  Character or `NULL`. Passed through to `ExecutionContext`.

- execPath:

  Character. Base results path. Passed through.

## Value

An `ExecutionContext`.
