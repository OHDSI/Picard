# Validate config.yml File Structure

Validates that a config.yml file has the correct schema-only structure.
Credentials (dbms, user, password, connectionString, server, port) are
NOT expected in config.yml — they live in secrets.yml and are validated
separately via
[`validateSecretsYaml()`](https://ohdsi.github.io/Picard/reference/validateSecretsYaml.md).

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

- One or more config blocks with schema-only fields:

  - dbServer: Server name for secrets.yml lookup

  - cdmDatabaseSchema: OMOP CDM schema name

  - workDatabaseSchema: Schema for writing results

  - cohortTable: Name of cohort table

  - databaseName: Human-readable database name

  - databaseLabel (optional): Human-readable label

  - tempEmulationSchema (optional): Temp table emulation schema

Credentials are managed in secrets.yml — see
[`validateSecretsYaml()`](https://ohdsi.github.io/Picard/reference/validateSecretsYaml.md)
and
[`editSecrets()`](https://ohdsi.github.io/Picard/reference/editSecrets.md).
