# Validate config.yml File Structure

Validates that a config.yml file has the correct structure, required
fields, and that sensitive credentials (user, password,
connectionString) use !expr instead of plain text values. Checks each
config block for consistency and DBMS-specific requirements.

## Usage

``` r
validateConfigYaml(configFilePath = NULL)
```

## Arguments

- configFilePath:

  Character. Path to the config.yml file. If NULL, looks for config.yml
  in the current working directory.

## Value

Logical. Returns TRUE if valid. Stops with informative error messages if
validation fails.

## Details

A valid config.yml must have:

- Top-level version field (e.g., "version: 1.0.0")

- Top-level projectName field (character)

- One or more config blocks with required fields:

  - dbms: Database management system type (snowflake, postgresql, sql
    server, etc.)

  - user: !expr expression for credentials

  - password: !expr expression for credentials

  - cdmDatabaseSchema: OMOP CDM schema name

  - workDatabaseSchema: Schema for writing results

  - cohortTable: Name of cohort table

  - databaseName: Human-readable database name

DBMS-specific requirements:

- Snowflake: Must have connectionString (!expr)

- PostgreSQL/SQL Server: Must have server and port

Security check:

- user, password, connectionString fields MUST use !expr (not plain
  values)
