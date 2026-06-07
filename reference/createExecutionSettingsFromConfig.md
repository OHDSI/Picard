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
  pipelineVersion = "prod"
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

  Character. Pipeline version ("prod" for production table, "dev" or
  "0.0.1" etc.).

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
