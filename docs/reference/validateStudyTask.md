# Validate Study Task Script

Validates that a study task R script has all required components to work
in the pipeline. Checks for required sections, template variables,
executionSettings creation, output folder setup, and non-empty script
section.

## Usage

``` r
validateStudyTask(taskFilePath)
```

## Arguments

- taskFilePath:

  Character. The full path to the task R script to validate.

## Value

Logical. Returns TRUE if valid. Stops with an error message if
validation fails.

## Details

A valid study task must contain:

- Section headers: A. Meta, B. Dependencies, C. Connection Settings, D.
  Task Settings, E. Script

- Template variables: !\|\|configBlock\|\|! and
  !\|\|pipelineVersion\|\|!

- ExecutionSettings creation (assignment to executionSettings object)

- Output folder creation (assignment to outputFolder object)

- Non-empty E. Script section (more than just the template comment)
