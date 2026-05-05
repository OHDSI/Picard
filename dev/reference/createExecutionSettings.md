# Create an ExecutionSettings object and set its attributes

Create an ExecutionSettings object and set its attributes

## Usage

``` r
createExecutionSettings(
  connectionDetails,
  connection = NULL,
  cdmDatabaseSchema,
  workDatabaseSchema,
  tempEmulationSchema,
  cohortTable,
  databaseName
)
```

## Arguments

- connectionDetails:

  A DatabaseConnector connectionDetails object (optional if connection
  is specified)

- connection:

  A DatabaseConnector connection object (optional if connectionDetails
  is specified)

- cdmDatabaseSchema:

  The schema of the OMOP CDM database

- workDatabaseSchema:

  The schema to which results will be written

- tempEmulationSchema:

  Some database platforms like Oracle and Snowflake do not truly support
  temp tables. To emulate temp tables, provide a schema with write
  privileges where temp tables can be created.

- cohortTable:

  The name of the table where the cohort(s) are stored

- databaseName:

  A human-readable name for the OMOP CDM database

## Value

An ExecutionSettings object
