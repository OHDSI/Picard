# ExecOptions R6 Class

Manages execution options and database connection configurations for
study pipeline. Coordinates multiple database connections and stores
execution environment settings.

## Details

ExecOptions serves as the configuration hub for study execution,
managing database connections through DbConfigBlock objects and
maintaining DBMS specifications. Used within UlyssesStudy to configure
the execution environment.

### Active Fields

- `dbms`: Database management system type (read/write)

- `workDatabaseSchema`: Schema for working/staging tables (read/write)

- `tempEmulationSchema`: Schema for temporary table emulation
  (read/write)

- `dbConnectionBlocks`: List of DbConfigBlock objects (read/write)

### Methods

- `initialize()`: Create and configure a new ExecOptions instance

- `makeConfigFile()`: Generate and write configuration file for the
  study

## Active bindings

- `dbms`:

  Database management system type (e.g., "postgresql", "sql-server").
  Can be read or set with validation.

- `workDatabaseSchema`:

  Schema for working and staging tables. Can be read or set with
  validation.

- `tempEmulationSchema`:

  Schema for temporary table emulation across different DBMS platforms.
  Can be read or set with validation.

- `dbConnectionBlocks`:

  List of DbConfigBlock objects managing multiple database connections.
  Can be read or set with class validation.

## Methods

### Public methods

- [`ExecOptions$new()`](#method-ExecOptions-new)

- [`ExecOptions$makeConfigFile()`](#method-ExecOptions-makeConfigFile)

- [`ExecOptions$clone()`](#method-ExecOptions-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize a new ExecOptions instance with execution configuration.

#### Usage

    ExecOptions$new(
      dbms = NULL,
      workDatabaseSchema = NULL,
      tempEmulationSchema = NULL,
      dbConnectionBlocks = NULL
    )

#### Arguments

- `dbms`:

  Character string. Optional DBMS type (e.g., "postgresql",
  "sql-server").

- `workDatabaseSchema`:

  Character string. Optional schema for working tables.

- `tempEmulationSchema`:

  Character string. Optional schema for temp table emulation.

- `dbConnectionBlocks`:

  List of DbConfigBlock objects. Optional database configurations.

#### Returns

Invisibly returns self.

------------------------------------------------------------------------

### Method `makeConfigFile()`

Generate and write the configuration file for the study repository.

#### Usage

    ExecOptions$makeConfigFile(repoName, repoPath, toolType)

#### Arguments

- `repoName`:

  Character string. Repository name.

- `repoPath`:

  Character string. Path to repository directory.

- `toolType`:

  Character string. Tool type - determines config structure.

#### Returns

Invisibly returns the generated configuration file content.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    ExecOptions$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
