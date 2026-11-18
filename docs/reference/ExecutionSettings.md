# ExecutionSettings

An R6 class to define an ExecutionSettings object

## Active bindings

- `cdmDatabaseSchema`:

  the schema containing the OMOP CDM

- `workDatabaseSchema`:

  the schema containing the cohort table

- `tempEmulationSchema`:

  the schema needed for temp tables

- `cohortTable`:

  the table containing the cohorts

- `databaseName`:

  the name of the source data of the cdm

## Methods

### Public methods

- [`ExecutionSettings$new()`](#method-ExecutionSettings-initialize)

- [`ExecutionSettings$getDbms()`](#method-ExecutionSettings-getDbms)

- [`ExecutionSettings$connect()`](#method-ExecutionSettings-connect)

- [`ExecutionSettings$disconnect()`](#method-ExecutionSettings-disconnect)

- [`ExecutionSettings$getConnection()`](#method-ExecutionSettings-getConnection)

- [`ExecutionSettings$reviewConnectionDetails()`](#method-ExecutionSettings-reviewConnectionDetails)

- [`ExecutionSettings$clone()`](#method-ExecutionSettings-clone)

------------------------------------------------------------------------

### `ExecutionSettings$new()`

#### Usage

    ExecutionSettings$new(
      connectionDetails = NULL,
      connection = NULL,
      cdmDatabaseSchema = NULL,
      workDatabaseSchema = NULL,
      tempEmulationSchema = NULL,
      cohortTable = NULL,
      databaseName = NULL
    )

#### Arguments

- `connectionDetails`:

  a connectionDetails object

- `connection`:

  a connection to a dbms

- `cdmDatabaseSchema`:

  The schema of the OMOP CDM database

- `workDatabaseSchema`:

  The schema to which results will be written

- `tempEmulationSchema`:

  Some database platforms like Oracle and Snowflake do not truly support
  temp tables. To emulate temp tables, provide a schema with write
  privileges where temp tables can be created.

- `cohortTable`:

  The name of the table where the cohort(s) are stored

- `databaseName`:

  A human-readable name for the OMOP CDM database

------------------------------------------------------------------------

### `ExecutionSettings$getDbms()`

Extract the DBMS dialect

#### Usage

    ExecutionSettings$getDbms()

#### Details

Prioritizes active connection DBMS over connectionDetails DBMS

#### Returns

Character. The DBMS type (e.g., "postgresql", "snowflake")

------------------------------------------------------------------------

### `ExecutionSettings$connect()`

Connect to DBMS using connectionDetails

#### Usage

    ExecutionSettings$connect()

#### Details

Creates a new connection if one doesn't exist. If a connection already
exists, validates it and returns a message. If validation fails,
attempts to reconnect.

#### Returns

Invisible NULL

------------------------------------------------------------------------

### `ExecutionSettings$disconnect()`

Disconnect from DBMS

#### Usage

    ExecutionSettings$disconnect()

#### Details

Closes the active connection and clears the connection object. Safe to
call even if no connection exists.

#### Returns

Invisible NULL

------------------------------------------------------------------------

### `ExecutionSettings$getConnection()`

Retrieve the active connection object

#### Usage

    ExecutionSettings$getConnection()

#### Details

Returns the connection if it exists and is valid. Otherwise returns NULL
with an informative message. Use this to check connection status before
database operations.

#### Returns

DatabaseConnectorConnection or NULL

------------------------------------------------------------------------

### `ExecutionSettings$reviewConnectionDetails()`

Return the configured connectionDetails object

#### Usage

    ExecutionSettings$reviewConnectionDetails()

#### Returns

A DatabaseConnector connectionDetails object or NULL.

------------------------------------------------------------------------

### `ExecutionSettings$clone()`

The objects of this class are cloneable with this method.

#### Usage

    ExecutionSettings$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
