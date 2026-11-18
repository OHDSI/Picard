# Production Study Pipeline Execution

Executes the full study pipeline in production mode with full
validation, version management, and reproducibility tracking. Creates a
release branch, runs the complete pipeline, provides PR instructions,
and saves reference to PENDING_PR.md.

## Usage

``` r
execStudyPipeline(
  configBlock,
  updateType,
  skipRenv = FALSE,
  skipConnectivityCheck = TRUE,
  ignoreUncommittedPaths = NULL,
  skipCodeStateCheck = FALSE,
  env = rlang::caller_env(),
  forceRerun = FALSE,
  skipInputBuilders = TRUE
)
```

## Arguments

- configBlock:

  Character or character vector. Name(s) of config block(s) to use.

- updateType:

  Character. Type of version increment: 'major', 'minor', or 'patch'.

  - MAJOR: Breaking changes

  - MINOR: New features, backward compatible

  - PATCH: Bug fixes, no new features

- skipRenv:

  Logical. If TRUE, skips renv validation. Defaults to FALSE. Useful for
  testing issues. Default: FALSE

- skipConnectivityCheck:

  Logical. If TRUE (default), skips the optional database connectivity
  pre-flight check. Set to FALSE to attempt a test connection to each
  config block before execution begins.

- ignoreUncommittedPaths:

  Character vector or NULL. Repo-relative paths (e.g. `"inputs"`) whose
  uncommitted changes should not fail the code-state pre-flight check.
  Changes anywhere else — notably `analysis/` — still fail it. When NULL
  (default) the list is read from `ignoreUncommittedPaths` in the
  `default:` block of config.yml, which itself defaults to ignoring
  nothing, so behaviour is unchanged unless a study opts in. Pass
  `character(0)` to force strict checking regardless of config.yml.

- skipCodeStateCheck:

  Logical. If TRUE, skips the code-state check entirely — a last resort
  when `ignoreUncommittedPaths` cannot express the churn. The run
  proceeds, but the pre-flight checklist raises a warning and the run
  history records the tree as `"unverified-skipped"`. Defaults to FALSE.
  Deliberately not settable from config.yml, so it cannot be baked
  permanently into a study.

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
# Run production pipeline with patch version increment
execStudyPipeline(configBlock = "myConfig", updateType = "patch")

# Tolerate manifest/ATLAS churn under inputs/ for this run only
execStudyPipeline(
  configBlock = "myConfig",
  updateType = "patch",
  ignoreUncommittedPaths = "inputs"
)

# Last resort: do not check the working tree at all
execStudyPipeline(
  configBlock = "myConfig",
  updateType = "patch",
  skipCodeStateCheck = TRUE
)
} # }
```
