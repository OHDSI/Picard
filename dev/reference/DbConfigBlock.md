# DbConfigBlock R6 Class

Represents a database configuration block for connecting to a specific
database. Encapsulates database connection parameters and naming
conventions used during study execution.

## Details

DbConfigBlock manages configuration for a single database connection
within the Ulysses framework. This includes CDM schema specifications,
cohort table references, and database labeling. Used within ExecOptions
to manage multiple database connections.

### Active Fields

- `configBlockName`: Unique identifier for this config block
  (read/write)

- `cdmDatabaseSchema`: Schema name containing the CDM (read/write)

- `cohortTable`: Table name for study cohorts (read/write)

- `databaseName`: Database identifier (read/write, defaults to
  configBlockName)

- `databaseLabel`: Human-readable database label (read/write)

### Methods

- `initialize()`: Create and configure a new DbConfigBlock instance

- `writeBlockSection()`: Generate formatted configuration block text

## Active bindings

- `configBlockName`:

  Unique identifier for this configuration block. Can be read or set
  with validation.

- `cdmDatabaseSchema`:

  Schema name containing the CDM data. Can be read or set with
  validation.

- `cohortTable`:

  Table name for study cohorts. Can be read or set with validation.

- `databaseName`:

  Database identifier. Can be read or set with validation. Defaults to
  configBlockName.

- `databaseLabel`:

  Human-readable database label for display. Can be read or set with
  validation.

## Methods

### Public methods

- [`DbConfigBlock$new()`](#method-DbConfigBlock-new)

- [`DbConfigBlock$writeBlockSection()`](#method-DbConfigBlock-writeBlockSection)

- [`DbConfigBlock$clone()`](#method-DbConfigBlock-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize a new DbConfigBlock instance with database configuration.

#### Usage

    DbConfigBlock$new(
      configBlockName,
      cdmDatabaseSchema,
      cohortTable,
      databaseName = NULL,
      databaseLabel = NULL
    )

#### Arguments

- `configBlockName`:

  Character string. Unique identifier for this configuration block.

- `cdmDatabaseSchema`:

  Character string. Schema containing CDM data.

- `cohortTable`:

  Character string. Table name for study cohorts.

- `databaseName`:

  Character string. Optional database identifier (defaults to
  configBlockName).

- `databaseLabel`:

  Character string. Optional human-readable database label (defaults to
  databaseName).

#### Returns

Invisibly returns self.

------------------------------------------------------------------------

### Method `writeBlockSection()`

Generate a formatted configuration block section for the config file.

#### Usage

    DbConfigBlock$writeBlockSection(repoName, dbms, workSchema, tempSchema)

#### Arguments

- `repoName`:

  Character string. Repository name.

- `dbms`:

  Character string. Database management system type.

- `workSchema`:

  Character string. Working schema for temp tables.

- `tempSchema`:

  Character string. Temporary table emulation schema.

#### Returns

Character string with formatted configuration block.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    DbConfigBlock$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
