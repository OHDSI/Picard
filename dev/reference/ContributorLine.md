# ContributorLine R6 Class

Represents a contributor to a study with associated contact and role
information. This class stores metadata about individuals contributing
to a research study.

## Details

ContributorLine encapsulates contributor information including name,
email, and role. Used within StudyMeta to maintain a structured list of
study contributors.

### Active Fields

- `name`: Contributor's name (read/write)

- `email`: Contributor's email address (read/write)

- `role`: Contributor's role in the study (read/write)

### Methods

- `initialize()`: Create and configure a new ContributorLine instance

- `printContributorLine()`: Generate formatted contributor information
  string

## Active bindings

- `name`:

  Contributor's full name. Can be read or set with validation.

- `email`:

  Contributor's email address. Can be read or set with validation.

- `role`:

  Contributor's role in the study. Can be read or set with validation.

## Methods

### Public methods

- [`ContributorLine$new()`](#method-ContributorLine-new)

- [`ContributorLine$printContributorLine()`](#method-ContributorLine-printContributorLine)

- [`ContributorLine$clone()`](#method-ContributorLine-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize a new ContributorLine instance.

#### Usage

    ContributorLine$new(name, email, role)

#### Arguments

- `name`:

  Character string. Contributor's full name.

- `email`:

  Character string. Contributor's email address.

- `role`:

  Character string. Contributor's role in the study.

#### Returns

Invisibly returns self.

------------------------------------------------------------------------

### Method `printContributorLine()`

Generate a formatted string representation of the contributor.

#### Usage

    ContributorLine$printContributorLine()

#### Returns

Character string with formatted contributor information.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    ContributorLine$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
