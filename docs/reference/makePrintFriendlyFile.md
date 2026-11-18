# Generate Print-Friendly Cohort Documentation from JSON

Converts CIRCE-based JSON cohort definitions to human-readable R
Markdown files using CirceR print-friendly formatting. Preserves
category subdirectories (e.g., target/, comparator/) in output
structure.

## Usage

``` r
makePrintFriendlyFile(
  cohorts_dir = "inputs/cohorts",
  output_base = "AI_translation",
  verbose = TRUE
)
```

## Arguments

- cohorts_dir:

  Character. Path to cohorts folder containing json/ subdirectory.
  Default: "inputs/cohorts" (Ulysses standard structure)

- output_base:

  Character. Path to base output directory where printFriendly/
  subdirectory will be created. Default: "AI_translation" (created at
  repo root, separate from inputs/)

- verbose:

  Logical. Print progress messages. Default: TRUE

## Value

Invisibly returns character vector of generated file paths

## Details

Input folder structure expected:

    inputs/cohorts/
      └── json/
          ├── target/
          │   ├── cohort1.json
          │   └── cohort2.json
          └── comparator/
              └── cohort3.json

Output folder structure created:

    AI_translation/
      └── printFriendly/
          ├── target/
          │   ├── cohort1 - cohort_print_friendly.Rmd
          │   └── cohort2 - cohort_print_friendly.Rmd
          └── comparator/
              └── cohort3 - cohort_print_friendly.Rmd

Each generated Rmd file contains a human-readable specification of the
cohort definition suitable for publication or documentation. CirceR must
be installed.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Generate print-friendly files with defaults
  makePrintFriendlyFile()

  # Custom locations
  makePrintFriendlyFile(
    cohorts_dir = "path/to/cohorts",
    output_base = "path/to/output"
  )
} # }
```
