# Make Study Meta for Ulysses

Make Study Meta for Ulysses

## Usage

``` r
makeStudyMeta(
  studyTitle,
  therapeuticArea,
  studyType,
  contributors,
  studyLinks = NULL,
  studyTags = NULL
)
```

## Arguments

- studyTitle:

  the title of the study as a character string

- therapeuticArea:

  the TA as a character string

- studyType:

  the study type (typically characterization)

- studyLinks:

  a list of study links

- studyTags:

  a list of study tags

## Value

A StudyMeta R6 class with the study meta
