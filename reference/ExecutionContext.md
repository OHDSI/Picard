# ExecutionContext

Describes one Picard pipeline execution and derives the names used to
isolate its database and filesystem outputs. This R6 class owns
execution mode and pipeline version (the namespace).

Internal: constructed by the pipeline
([`execute_pipeline()`](https://ohdsi.github.io/Picard/reference/execute_pipeline.md))
and by the settings/path helpers
([`createExecutionSettingsFromConfig()`](https://ohdsi.github.io/Picard/reference/createExecutionSettingsFromConfig.md),
[`setOutputFolder()`](https://ohdsi.github.io/Picard/reference/setOutputFolder.md),
[`resolveResultsPath()`](https://ohdsi.github.io/Picard/reference/resolveResultsPath.md)).
Study code and task files never construct it directly.

## Methods

### Public methods

- [`ExecutionContext$new()`](#method-ExecutionContext-initialize)

- [`ExecutionContext$getMode()`](#method-ExecutionContext-getMode)

- [`ExecutionContext$getPipelineVersion()`](#method-ExecutionContext-getPipelineVersion)

- [`ExecutionContext$getStudyVersion()`](#method-ExecutionContext-getStudyVersion)

- [`ExecutionContext$getCohortTable()`](#method-ExecutionContext-getCohortTable)

- [`ExecutionContext$deriveCohortTable()`](#method-ExecutionContext-deriveCohortTable)

- [`ExecutionContext$getResultsPath()`](#method-ExecutionContext-getResultsPath)

- [`ExecutionContext$clone()`](#method-ExecutionContext-clone)

------------------------------------------------------------------------

### `ExecutionContext$new()`

#### Usage

    ExecutionContext$new(
      mode = c("test", "production"),
      pipelineVersion = "dev",
      studyVersion = NULL,
      baseCohortTable = NULL,
      databaseName = NULL,
      execPath = here::here("exec/results"),
      maxTableNameLength = MAX_TEST_COHORT_TABLE_NAME_LENGTH
    )

#### Arguments

- `mode`:

  Character. Either `"test"` or `"production"`.

- `pipelineVersion`:

  Character. The complete execution pipeline version. Defaults to
  `"dev"` for test executions. Test pipeline versions are normalized to
  lowercase snake case. Production pipeline versions are semantic
  versions, or the literal `"prod"` for a production run against the
  configured table whose version is not tracked.

- `studyVersion`:

  Character or `NULL`. The study version associated with the execution.
  Required for a semantic-version production run; `NULL` for test runs
  and for `pipelineVersion = "prod"`.

- `baseCohortTable`:

  Character or `NULL`. The configured, unsuffixed cohort table. Optional
  for a run-scoped context shared by multiple database config blocks.

- `databaseName`:

  Character or `NULL`. Human-readable database name used in result
  paths. Optional for a run-scoped context shared by multiple database
  config blocks.

- `execPath`:

  Character. Base path for execution results. Defaults to `exec/results`
  in the current study project.

- `maxTableNameLength`:

  Integer. Maximum permitted length of the derived cohort table name.
  Defaults to 60, a practical cross-database limit for test-derived
  names. Set to `NULL` to disable this package-level check.

------------------------------------------------------------------------

### `ExecutionContext$getMode()`

#### Usage

    ExecutionContext$getMode()

#### Returns

Character. Execution mode, either `"test"` or `"production"`.

------------------------------------------------------------------------

### `ExecutionContext$getPipelineVersion()`

#### Usage

    ExecutionContext$getPipelineVersion()

#### Returns

Character. Normalized execution pipelineVersion.

------------------------------------------------------------------------

### `ExecutionContext$getStudyVersion()`

#### Usage

    ExecutionContext$getStudyVersion()

#### Returns

Character or `NULL`. Associated production study version.

------------------------------------------------------------------------

### `ExecutionContext$getCohortTable()`

#### Usage

    ExecutionContext$getCohortTable()

#### Returns

Character or `NULL`. Effective cohort table name for this execution, or
`NULL` for a run-scoped context without a base table.

------------------------------------------------------------------------

### `ExecutionContext$deriveCohortTable()`

Apply this run's mode and namespace to a configured base cohort table.
Production returns the base table unchanged; test appends the normalized
pipeline version and enforces the table-name length ceiling before any
database work.

#### Usage

    ExecutionContext$deriveCohortTable(baseCohortTable)

#### Arguments

- `baseCohortTable`:

  Character. The configured, unsuffixed cohort table.

#### Returns

Character. The effective cohort table name for this execution.

------------------------------------------------------------------------

### `ExecutionContext$getResultsPath()`

#### Usage

    ExecutionContext$getResultsPath(
      taskName = NULL,
      databaseName = private$.databaseName
    )

#### Arguments

- `taskName`:

  Character. Task folder or file name.

- `databaseName`:

  Character or `NULL`. Database name to use when the context is shared
  across multiple config blocks.

#### Returns

Character. Absolute result path for the supplied task.

------------------------------------------------------------------------

### `ExecutionContext$clone()`

The objects of this class are cloneable with this method.

#### Usage

    ExecutionContext$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
