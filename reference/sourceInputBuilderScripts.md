# Source Pre-Pipeline Input Builder Scripts

Auto-discovers and sources builder scripts from pre-pipeline directories
in a MANDATORY dependency order.
[`execStudyPipeline`](https://ohdsi.github.io/Picard/reference/execStudyPipeline.md)
and
[`testStudyPipeline`](https://ohdsi.github.io/Picard/reference/testStudyPipeline.md)
call this for each config block, right before generating that block's
cohorts, so builders can make database-specific changes; call it
directly to build inputs while developing. The order ensures concept
sets are available before cohorts, and dependent cohorts can reference
already-loaded cohort definitions.

## Usage

``` r
sourceInputBuilderScripts(
  projectPath = here::here(),
  configBlock = NULL,
  pipelineVersion = "prod",
  verbose = TRUE,
  stopOnError = TRUE
)
```

## Arguments

- projectPath:

  Character. Path to the project root. Defaults to current project.

- configBlock:

  Character vector. Config block name(s) from `config.yml`. Scripts are
  sourced once per block, with the current block available as
  `inputBuilderEnv$configBlock`. Defaults to NULL (source once).

- pipelineVersion:

  Character. Pipeline version made available to builder scripts as
  `inputBuilderEnv$pipelineVersion`. Defaults to `"prod"`, matching
  [`createExecutionSettingsFromConfig`](https://ohdsi.github.io/Picard/reference/createExecutionSettingsFromConfig.md);
  pass the test namespace (e.g. `"dev"`) when building inputs for a test
  run.

- verbose:

  Logical. If TRUE (default), displays which scripts are being sourced.

- stopOnError:

  Logical. If TRUE (default), stop at the first builder script that
  errors. If FALSE, warn and continue with the remaining scripts.

## Value

Invisibly returns a list with:

- `sourced_files`: Character vector of sourced files (absolute paths)

- `config_blocks`: Character vector of config blocks processed (NULL
  when `configBlock` is NULL)

- `directories_checked`: Character vector of directories checked

- `error_summary`: Named list of error messages from failed scripts
  (only non-empty when `stopOnError = FALSE`)

## Details

All six scripts are required and are sourced in the following FIXED
order:

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
to create scripts with the correct naming convention. The function
aborts before sourcing anything if a required script is missing or if
`inputs/conceptSets/R/` or `inputs/cohorts/R/` contain any other `.R`
file, since such a file would otherwise never run. Unused builders
should be left in place: the templates run without error when they have
not been populated. Put helper code in a subfolder (e.g.
`inputs/cohorts/R/src/`), which is not checked.

When `configBlock` is supplied, the full set of scripts is sourced once
per config block, in order, the same way
[`execStudyPipeline()`](https://ohdsi.github.io/Picard/reference/execStudyPipeline.md)
runs tasks once per database. Before each pass, an `inputBuilderEnv`
object (see
[`createInputBuilderEnv`](https://ohdsi.github.io/Picard/reference/createInputBuilderEnv.md))
holding the current config block and the pipeline version is assigned
into the global environment, so builder scripts can build execution
settings without hard-coding either value, e.g.
`createExecutionSettingsFromConfig(configBlock = inputBuilderEnv$configBlock, pipelineVersion = inputBuilderEnv$pipelineVersion)`.
When `configBlock` is NULL, scripts are sourced once with
`inputBuilderEnv$configBlock` set to NULL.

By default, an error inside a builder script stops the run immediately:
input building is a hard precondition of pipeline execution, and later
builders may depend on earlier ones, so a failed script must stop
`main.R` before
[`execStudyPipeline()`](https://ohdsi.github.io/Picard/reference/execStudyPipeline.md)
can be reached. Set `stopOnError = FALSE` to instead warn and continue
with the remaining scripts; the errors are then returned in
`error_summary`.
