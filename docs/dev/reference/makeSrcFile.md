# Create a Source Utility File

Creates a new R script in the analysis/src folder for storing reusable
utility functions. Unlike task files, source files have no naming
conventions or execution order requirements.

## Usage

``` r
makeSrcFile(
  fileName,
  author = NULL,
  description = NULL,
  projectPath = here::here(),
  openFile = TRUE
)
```

## Arguments

- fileName:

  The name of the source file (e.g., "custom_analysis_functions")

- author:

  The name of the author. Defaults to template text if NULL

- description:

  A brief description of what the utilities in this file do. Defaults to
  template text if NULL

- projectPath:

  The path to the project (defaults to current project)

- openFile:

  Whether to open the file after creating it (default TRUE)

## Value

Invisible character string containing the template content

## Details

Source files are utility files that contain reusable functions sourced
by one or more task files. They have no naming convention requirements
and execute in no particular order. Create them as you need utility
functions to avoid code duplication across tasks.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a source file for custom analysis functions
makeSrcFile(
  fileName = "custom_analysis_functions",
  author = "Jane Doe",
  description = "Helper functions for cohort calculations and data validation"
)

# Create with minimal arguments (uses template defaults)
makeSrcFile(fileName = "plotting_utilities")
} # }
```
