# Make a database config block

Make a database config block

## Usage

``` r
makeBlock(
  configBlockName,
  cdmDatabaseSchema,
  cohortTable,
  databaseName = NULL,
  databaseLabel = NULL,
  dbServer = NULL,
  workDatabaseSchema = NULL,
  tempEmulationSchema = NULL
)
```

## Arguments

- configBlockName:

  the name of the config block

- cdmDatabaseSchema:

  the cdmDatabaseSchema specified as a character string

- cohortTable:

  a character string specifying the way you want to name your cohort
  table

- databaseName:

  the name of the database, typically uses the db name and id. For
  example optum_dod_202501

- databaseLabel:

  the labelling name of the database, typically a common name for a db.
  For example Optum DOD

- dbServer:

  the name of the database server in secrets.yml (defaults to
  configBlockName)

- workDatabaseSchema:

  Character string. Optional working schema for temp tables (per-block).

- tempEmulationSchema:

  Character string. Optional temp table emulation schema (per-block).

## Value

A DbConfigBlock R6 class with the config details
