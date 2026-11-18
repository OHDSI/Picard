# Test Study Pipeline

Executes the full study pipeline in test mode. The pipelineVersion value
is interpreted as the test namespace and is used for test cohort tables
and output folders. Test runs are allowed on development branches but
rejected on the main branch.

## Usage

``` r
testStudyPipeline(
  configBlock,
  pipelineVersion = "dev",
  env = rlang::caller_env(),
  forceRerun = FALSE,
  skipInputBuilders = TRUE
)
```

## Arguments

- configBlock:

  Character or character vector. Name(s) of config block(s) to use.

- pipelineVersion:

  Character. Test namespace used for output folders and cohort table
  suffix. Defaults to `"dev"`. The value is normalized to lowercase
  snake_case; an over-long namespace is rejected rather than truncated.

- env:

  The execution environment. Defaults to caller environment.

- forceRerun:

  Logical or character. `TRUE` reruns every task, bypassing change
  detection
  ([`shouldRerunTask()`](https://ohdsi.github.io/Picard/reference/shouldRerunTask.md));
  a character vector of task file names (e.g.
  `"05_baseline_medicines.R"`) reruns only those. Forced runs are still
  recorded in `exec/logs/task_run_history.csv`. Default: `FALSE`

- skipInputBuilders:

  Logical. If TRUE (default), the input builder scripts are not sourced;
  call
  [`sourceInputBuilderScripts()`](https://ohdsi.github.io/Picard/reference/sourceInputBuilderScripts.md)
  before the pipeline instead. If FALSE, they are sourced for each
  config block before that block's cohorts are generated.

## Value

Invisibly returns task results list

## Details

For each config block in turn, the pipeline generates that block's
cohorts and runs its tasks, before moving to the next block. With
`skipInputBuilders = FALSE`, it first sources the input builder scripts
(see
[`sourceInputBuilderScripts`](https://ohdsi.github.io/Picard/reference/sourceInputBuilderScripts.md))
for the block, so builders can make database-specific changes (e.g.
concept ids in custom SQL) without the next block's builders overwriting
them.

## Examples

``` r
if (FALSE) { # \dontrun{
# Test full pipeline on develop branch
testStudyPipeline(configBlock = "myConfig")
# Rerun every task, ignoring change detection
testStudyPipeline(configBlock = "myConfig", forceRerun = TRUE)
# Test full pipeline with a custom namespace
testStudyPipeline(configBlock = "myConfig", pipelineVersion = "feature_ml_test")
} # }
```
