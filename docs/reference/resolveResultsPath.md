# Resolve a task results path

Returns the absolute
`exec/results/<database>/<pipelineVersion>/<taskName>` path for a run.
When an `ExecutionContext` is supplied it is used directly; otherwise an
equivalent one is derived from the `ExecutionSettings` object and the
pipeline version. This keeps every results-folder path in the package
flowing through
[ExecutionContext](https://ohdsi.github.io/Picard/reference/ExecutionContext.md)'s
`getResultsPath()` rather than being hand-assembled at each call site.

## Usage

``` r
resolveResultsPath(
  executionSettings,
  pipelineVersion,
  taskName = NULL,
  executionContext = NULL,
  execPath = here::here("exec/results")
)
```

## Arguments

- executionSettings:

  An `ExecutionSettings` object; supplies the database name.

- pipelineVersion:

  Character. Test namespace (e.g. `"develop_ml"`) or semantic version
  (e.g. `"1.0.2"`). Ignored when `executionContext` is supplied.

- taskName:

  Character or `NULL`. Task folder name appended to the path.

- executionContext:

  Optional `ExecutionContext` for the current run.

- execPath:

  Character. Base results path. Defaults to `exec/results` in the
  current study project. Ignored when `executionContext` is supplied.

## Value

Character. The absolute results path (not created).
