# Create ExecutionSettings from Config Block

Load database connection details and execution parameters from a
config.yml file and create both connectionDetails and ExecutionSettings
objects. Supports multiple DBMS types including Snowflake with
connectionString, PostgreSQL with server/port, and others.

## Usage

``` r
createExecutionSettingsFromConfig(
  configBlock,
  configFilePath = here::here("config.yml"),
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

  Character. Path to the config.yml file. If NULL, looks for config.yml
  in the current directory.

- cdmDatabaseSchema:

  Character. The schema containing the OMOP CDM (overrides config value
  if provided)

- workDatabaseSchema:

  Character. The schema for writing results (overrides config value if
  provided)

- tempEmulationSchema:

  Character. Schema for temp table emulation (overrides config value if
  provided)

- cohortTable:

  Character. The name of the cohort table (overrides config value if
  provided)

- databaseName:

  Character. Human-readable database name (overrides config value if
  provided)

## Value

An ExecutionSettings object with populated connectionDetails

## Details

The config.yml file supports multiple DBMS connection styles:

For Snowflake (using connectionString):

    optum_dod:
      dbms: snowflake
      connectionString: !expr Sys.getenv('dbConnectionString')
      user: !expr Sys.getenv('dbUser')
      password: !expr Sys.getenv('dbPassword')
      cdmDatabaseSchema: my_schema
      workDatabaseSchema: results_schema
      tempEmulationSchema: temp_schema
      cohortTable: cohort
      databaseName: Optum DOD

For PostgreSQL (using server/port):

    database1:
      dbms: postgresql
      server: localhost
      port: 5432
      user: dbuser
      password: dbpass
      cdmDatabaseSchema: public
      workDatabaseSchema: results
      cohortTable: cohort
      databaseName: My Database

The config package automatically evaluates !expr blocks using
Sys.getenv() for environment variables.
