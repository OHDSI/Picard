# Create ExecutionSettings from Config Block

Load database connection details and execution parameters from
config.yml and secrets.yml. Schema info (CDM schema, work schema, cohort
table, etc.) comes from config.yml. Credentials (dbms, user, password,
server, port, connectionString) come from secrets.yml, keyed by the
`dbServer` field in each config block.

## Usage

``` r
createExecutionSettingsFromConfig(
  configBlock,
  configFilePath = here::here("config.yml"),
  secretsFilePath = "~/.picard/secrets.yml",
  cdmDatabaseSchema = NULL,
  workDatabaseSchema = NULL,
  tempEmulationSchema = NULL,
  cohortTable = NULL,
  databaseName = NULL,
  pipelineVersion = "prod",
  cohortTableSuffix = NULL,
  executionContext = NULL
)
```

## Arguments

- configBlock:

  Character. The name of the config block to load (e.g., "optum_dod")

- configFilePath:

  Character. Path to the config.yml file. Defaults to config.yml in
  working directory.

- secretsFilePath:

  Character. Path to the secrets.yml file. Default
  `"~/.picard/secrets.yml"`.

- cdmDatabaseSchema:

  Character. Override for CDM database schema.

- workDatabaseSchema:

  Character. Override for work database schema.

- tempEmulationSchema:

  Character. Override for temp emulation schema.

- cohortTable:

  Character. Override for cohort table name.

- databaseName:

  Character. Override for human-readable database name.

- pipelineVersion:

  Character. `"prod"` (the default) or a `MAJOR.MINOR.PATCH` version
  means "use the configured production cohort table unchanged". Any
  other value (e.g. `"dev"`, `"develop_ml"`) is treated as a test
  namespace and routes to a suffixed cohort table. Ignored when
  `executionContext` is supplied.

- cohortTableSuffix:

  Character. Optional suffix for cohort table names in non-semver (test)
  runs. Normalized to lowercase snake_case via
  [`normalizePipelineVersion()`](https://ohdsi.github.io/Picard/reference/normalizePipelineVersion.md).
  If NULL, the non-semver `pipelineVersion` is used as the suffix. The
  derived table name is rejected if it exceeds
  `MAX_TEST_COHORT_TABLE_NAME_LENGTH` characters.

- executionContext:

  An optional `ExecutionContext` for the current run. When supplied, its
  mode and normalized `pipelineVersion` control cohort table routing.
  The legacy `pipelineVersion` and `cohortTableSuffix` arguments remain
  available for direct callers.

## Value

An ExecutionSettings object with populated connectionDetails

## Details

Credentials are loaded from secrets.yml (default
`~/.picard/secrets.yml`). The config block's `dbServer` field is used to
look up the server entry in secrets.yml. Schema fields continue to come
from config.yml, with parameter overrides taking precedence.

secrets.yml supports two value formats:

- Plain strings: `user: "myuser"`

- R expressions:
  `password: !expr keyring::key_get("picard", "server_pw")`
