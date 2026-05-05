# StudyMeta R6 Class

Comprehensive metadata container for a research study. Manages study
information including title, therapeutic area, type, contributors,
links, and tags.

## Details

StudyMeta serves as the primary data container for study-level metadata.
It coordinates with the ContributorLine class to maintain contributor
information and provides methods for generating formatted output of
study components.

### Active Fields

- `studyTitle`: Title of the study (read/write)

- `therapeuticArea`: Therapeutic area of the study (read/write)

- `studyType`: Type of study conducted (read/write)

- `studyLinks`: Character vector of relevant study links (read/write)

- `studyTags`: Character vector of tags describing the study
  (read/write)

- `contributors`: List of ContributorLine objects (read/write)

### Methods

- `initialize()`: Create and configure a new StudyMeta instance

- `listContributors()`: Generate formatted markdown list of contributors

- `listStudyTags()`: Generate formatted markdown list of study tags

- `listStudyLinks()`: Generate formatted markdown section of study
  resources

## Active bindings

- `studyTitle`:

  Title of the study. Can be read or set with validation.

- `therapeuticArea`:

  Therapeutic area focus of the study. Can be read or set with
  validation.

- `studyType`:

  Type of study conducted. Can be read or set with validation.

- `studyTags`:

  Character vector of tags describing study topics and characteristics.
  Can be read or set with validation.

- `studyLinks`:

  Character vector of relevant study resource links and URLs. Can be
  read or set with validation.

- `contributors`:

  List of ContributorLine objects representing study team members. Can
  be read or set with class validation.

## Methods

### Public methods

- [`StudyMeta$new()`](#method-StudyMeta-new)

- [`StudyMeta$listContributors()`](#method-StudyMeta-listContributors)

- [`StudyMeta$listStudyTags()`](#method-StudyMeta-listStudyTags)

- [`StudyMeta$listStudyLinks()`](#method-StudyMeta-listStudyLinks)

- [`StudyMeta$clone()`](#method-StudyMeta-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize a new StudyMeta instance with study metadata.

#### Usage

    StudyMeta$new(
      studyTitle,
      therapeuticArea,
      studyType,
      contributors,
      studyLinks = NULL,
      studyTags = NULL
    )

#### Arguments

- `studyTitle`:

  Character string. Title of the study.

- `therapeuticArea`:

  Character string. Therapeutic area focus of the study.

- `studyType`:

  Character string. Type of study (e.g., observational, interventional).

- `contributors`:

  List of ContributorLine objects. Study team members.

- `studyLinks`:

  Character vector. Optional URLs and references for the study.

- `studyTags`:

  Character vector. Optional tags describing the study
  topics/characteristics.

#### Returns

Invisibly returns self.

------------------------------------------------------------------------

### Method `listContributors()`

Generate a formatted markdown list of all contributors.

#### Usage

    StudyMeta$listContributors()

#### Returns

Character string with markdown-formatted contributor list.

------------------------------------------------------------------------

### Method `listStudyTags()`

Generate a formatted markdown list of study tags.

#### Usage

    StudyMeta$listStudyTags()

#### Returns

Character string with markdown-formatted tag list.

------------------------------------------------------------------------

### Method `listStudyLinks()`

Generate a formatted markdown section of study resources and links.

#### Usage

    StudyMeta$listStudyLinks()

#### Returns

Character string with markdown-formatted section of study resources.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    StudyMeta$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
