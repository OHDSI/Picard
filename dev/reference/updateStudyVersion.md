# Function to update the study version

Updates the version across the project including config.yml, README.md,
and NEWS.md. Prompts the user to document changes from the pipeline run
as bullet points which are added to NEWS.

## Usage

``` r
updateStudyVersion(versionNumber, projectPath = here::here())
```

## Arguments

- versionNumber:

  the semantic version number to set as the new project version: 1.0.0

- projectPath:

  the path of the project, defaults to the directory of the active
  Ulysses project

## Value

Invisibly returns the version number
