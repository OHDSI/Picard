# Source Pre-Pipeline Input Builder Scripts

Auto-discovers and sources builder scripts from pre-pipeline directories
in a MANDATORY dependency order. Designed to be called from main.R
before the production pipeline. This ensures concept sets are available
before cohorts, and dependent cohorts can reference already-loaded
cohort definitions.

## Usage

``` r
sourceInputBuilderScripts(
  projectPath = here::here(),
  verbose = TRUE,
  warnMissing = TRUE
)
```

## Arguments

- projectPath:

  Character. Path to the project root. Defaults to current project.

- verbose:

  Logical. If TRUE (default), displays which scripts are being sourced.

- warnMissing:

  Logical. If TRUE (default), warns when directories don't exist.

## Value

Invisibly returns a list with:

- `sourced_files`: Character vector of sourced files (absolute paths)

- `directories_checked`: Character vector of directories checked

- `error_summary`: List of any errors encountered

## Details

Scripts are sourced in the following FIXED order (skipping any that
don't exist):

1.  `inputs/conceptSets/R/import_atlas_concept_set.R`

2.  `inputs/conceptSets/R/import_capr_concept_set.R`

3.  `inputs/cohorts/R/import_atlas_cohort.R`

4.  `inputs/cohorts/R/import_capr_cohort.R`

5.  `inputs/cohorts/R/import_sql_cohort.R`

6.  `inputs/cohorts/R/build_dependent_cohorts.R`

This order is enforced to guarantee dependencies are satisfied:

- Concept sets load first (may be needed by cohort definitions)

- Base cohorts load next (may be needed by dependent cohorts)

- Dependent cohorts load last (can reference base cohorts)

Use
[`makeInputBuilderScript`](https://ohdsi.github.io/Picard/reference/makeInputBuilderScript.md)
to create scripts with the correct naming convention. Missing scripts
are silently skipped, allowing flexible configurations.
