# UlyssesStudy R6 Class

Configuration and initialization class for Ulysses study repositories.
This class manages the creation and setup of a new study repository,
including directory structure, configuration files, and version control
initialization.

## Details

UlyssesStudy encapsulates the configuration needed to set up a new
Ulysses-based study environment. It manages study metadata and database
connection blocks. Database schema and credential details are held
per-block in DbConfigBlock.

### Active Fields

- `repoName`: Study repository name (read/write)

- `repoFolder`: Parent directory for the repository (read/write)

- `studyMeta`: StudyMeta object containing metadata (read/write)

- `dbConnectionBlocks`: List of DbConfigBlock objects (read/write)

- `gitRemote`: Optional git remote URL (read/write)

- `renvLockFile`: Optional path to renv lock file (read/write)

### Methods

- `initialize()`: Create and configure a new UlyssesStudy instance

- `initUlyssesRepo()`: Initialize the full repository structure

## Active bindings

- `repoName`:

  Study repository name. Can be read or set with validation.

- `repoFolder`:

  Parent directory for the repository. Can be read or set with
  validation.

- `dbConnectionBlocks`:

  List of DbConfigBlock objects managing multiple database connections.
  Can be read or set with class validation.

- `studyMeta`:

  StudyMeta object containing study metadata and configuration. Can be
  read or set with class validation.

- `gitRemote`:

  Optional URL for git remote repository. Can be read or set with
  validation.

- `renvLockFile`:

  Optional path to renv lock file for reproducibility. Can be read or
  set with validation.

## Methods

### Public methods

- [`UlyssesStudy$new()`](#method-UlyssesStudy-new)

- [`UlyssesStudy$initUlyssesRepo()`](#method-UlyssesStudy-initUlyssesRepo)

- [`UlyssesStudy$clone()`](#method-UlyssesStudy-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize a new UlyssesStudy instance with configuration parameters.

#### Usage

    UlyssesStudy$new(
      repoName,
      repoFolder,
      studyMeta,
      dbConnectionBlocks = NULL,
      gitRemote = NULL,
      renvLockFile = NULL
    )

#### Arguments

- `repoName`:

  Character string. Name of the study repository.

- `repoFolder`:

  Character string. Parent directory where the repository will be
  created.

- `studyMeta`:

  StudyMeta object. Contains study metadata and configuration.

- `dbConnectionBlocks`:

  List of DbConfigBlock objects. Optional database configurations.

- `gitRemote`:

  Character string. Optional URL for git remote repository.

- `renvLockFile`:

  Character string. Optional path to renv lock file for reproducibility.

#### Returns

Invisibly returns self for method chaining.

------------------------------------------------------------------------

### Method `initUlyssesRepo()`

Initialize the complete Ulysses repository structure and configuration.

This method performs the following initialization steps:

1.  Creates the R project directory and Rproj file

2.  Establishes the standard directory structure

3.  Creates initialization files (README, NEWS, configuration files)

4.  Sets up Quarto documentation

5.  Creates main execution file

6.  Initializes agent skills configuration

7.  Initializes git repository

#### Usage

    UlyssesStudy$initUlyssesRepo(verbose = TRUE, openProject = FALSE)

#### Arguments

- `verbose`:

  Logical. If TRUE (default), displays informative messages during
  initialization.

- `openProject`:

  Logical. If TRUE, opens the project in a new RStudio session after
  initialization.

#### Returns

Invisibly returns the path to the initialized repository.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    UlyssesStudy$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
