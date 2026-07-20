# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

## What this repository is

`picard` is an R package (OHDSI/Boehringer Ingelheim) for building and
running reproducible, pipeline-based real-world evidence (RWE) studies.
It does two distinct things:

1.  **Scaffolds study repositories** (“Ulysses” repos) — a standardized
    folder structure, config files, manifests, and starter scripts for
    an individual research study.
2.  **Provides the runtime library** those generated study repos depend
    on — manifest management, execution settings, task
    tracking/validation, post-processing, and dissemination helpers.

This repo is the *package* — not a study repo. Study repos are what
`UlyssesStudy$initUlyssesRepo()` generates elsewhere on disk (see
`tests/testthat/helper-init.R` for the pattern used in tests).

Note: the files under `inst/agent/` (`AGENTS.md`, the numbered reference
docs, and `skills/`) are **templates copied into generated study
repos**, not documentation of this package itself — they’re written as
instructions for an AI agent helping an analyst inside a study repo
(with `{{placeholder}}` variables, a restricted code-execution policy,
OMOP CDM guidance, etc.). Don’t confuse those constraints (e.g. “never
execute the pipeline”) with constraints on working in *this* repo.
`initUlyssesRepo()`/[`initAgentMode()`](https://ohdsi.github.io/Picard/reference/initAgentMode.md)
install them as `AGENTS.md` + `.agent/` in the study repo, alongside the
Capr package’s `capr-cohort-generation` skill bundle when Capr is
installed.

## Common commands

This is a standard R package using `devtools`/`testthat`/`roxygen2`.
There is no CI workflow for R CMD check/tests (only
`.github/workflows/pkgdown.yml` for docs) — validate locally.

``` r
devtools::load_all()          # load package for interactive dev
devtools::document()          # regenerate NAMESPACE/man/*.Rd from roxygen comments — run after any @export or param change
devtools::test()              # run full testthat suite
devtools::test_active_file()  # run just the currently open test file
testthat::test_file("tests/testthat/test-CohortManifest-query.R")  # run one test file directly
devtools::check()             # full R CMD check
pkgdown::build_site()         # rebuild docs/ site (vignettes + reference)
```

Roxygen uses markdown (`Roxygen: list(markdown = TRUE)` in DESCRIPTION)
— always run `devtools::document()` after touching roxygen comments,
never hand-edit `man/*.Rd` or `NAMESPACE`.

## Architecture

### R6 classes are the core abstraction

Almost all stateful behavior lives in R6 classes (`R/*.R`), with plain
exported functions as thin, user-facing constructors/wrappers around
them
(e.g. [`makeStudyMeta()`](https://ohdsi.github.io/Picard/reference/makeStudyMeta.md)
wraps `StudyMeta$new()`,
[`makeBlock()`](https://ohdsi.github.io/Picard/reference/makeBlock.md)
wraps `DbConfigBlock$new()`). When adding a feature, check whether it
belongs as a method on an existing class before adding a free function.

- **`UlyssesStudy`** (`R/Ulysses.R`) — orchestrates `initUlyssesRepo()`:
  creates the folder structure, README/NEWS/config.yml, Quarto study hub
  scaffold, `main.R`, agent-skill files, and initializes git. This is
  the entry point for “create a new study.”
- **`ExecutionSettings`** (`R/ExecutionSettings.R`) — wraps a DB
  connection (or `ConnectionDetails`) plus schema/table names
  (`cdmDatabaseSchema`, `workDatabaseSchema`, `tempEmulationSchema`,
  `cohortTable`, `databaseName`). Must provide exactly one of
  `connectionDetails` or `connection`, never both. Built either directly
  ([`createExecutionSettings()`](https://ohdsi.github.io/Picard/reference/createExecutionSettings.md))
  or from a `config.yml` block
  ([`createExecutionSettingsFromConfig()`](https://ohdsi.github.io/Picard/reference/createExecutionSettingsFromConfig.md)).
- **`DbConfigBlock`** — one database’s worth of config (feeds into
  `config.yml` blocks and `ExecutionSettings`).
- **`CohortManifest`** / **`ConceptSetManifest`** (`R/CohortManifest.R`,
  `R/ConceptSetManifest.R` — the two largest files, 4500 and 2200 lines)
  — track cohort/concept-set definitions as rows in a SQLite database
  (`inputs/cohorts/cohortManifest.sqlite`,
  `inputs/conceptSets/conceptSetManifest.sqlite`). Each entry has an id,
  label, tags, file path, content hash (for change detection), type,
  timestamp, and soft-delete status. `CohortDef`/`ConceptSetDef` are the
  corresponding single-item value objects. `R/manifest_helpers.R`
  provides top-level wrapper functions
  ([`initCohortManifest()`](https://ohdsi.github.io/Picard/reference/initCohortManifest.md),
  [`loadCohortManifest()`](https://ohdsi.github.io/Picard/reference/loadCohortManifest.md),
  etc.) plus query/visualization utilities over these classes.
  `R/migrateCohortManifest.R` / `R/migrateConceptSetManifest.R` handle
  schema migrations for the sqlite files across package versions.
- **`R/cohort_builders.R`** — dependency-graph logic for derived cohorts
  (subset/union/complement) that depend on other cohorts in the
  manifest.
- **Task execution** (`R/execute.R`, `R/taskTracking.R`,
  `R/validation.R`) — a study’s `analysis/tasks/*.R` files follow a
  mandatory 5-section format (A. Meta, B. Dependencies, C. Connection
  Settings, D. Task Settings, E. Script) enforced by
  [`validateStudyTask()`](https://ohdsi.github.io/Picard/reference/validateStudyTask.md).
  [`shouldRerunTask()`](https://ohdsi.github.io/Picard/reference/shouldRerunTask.md)
  decides whether to re-run a task based on file hash, dependency
  hashes, manifest hash, and version changes, recording history in
  `exec/logs/task_run_history.csv`. Tasks are numbered (`01_`, `02_`…)
  and executed in order by
  [`execStudyPipeline()`](https://ohdsi.github.io/Picard/reference/execStudyPipeline.md)/[`testStudyPipeline()`](https://ohdsi.github.io/Picard/reference/testStudyPipeline.md).
- **Post-processing/dissemination** (`R/postProcess.R`,
  `R/disseminate.R`, `R/studyHub.R`) —
  [`importAndBind()`](https://ohdsi.github.io/Picard/reference/importAndBind.md)/`orchestratePipelineExport()`
  merge per-database, per-version, per-task result CSVs from
  `exec/results/` into `dissemination/export/merge/`; migration scripts
  then reshape into `dissemination/export/pretty/` or `studyHubOutput/`.
  `studyHub.R` builds the Quarto-based “Study Hub” website from
  README/NEWS + exported result files.
- **`R/secrets.R`** — all DB/Atlas credentials live in a *user-level*
  `secrets.yml` (default `~/.picard/secrets.yml`), never in the study
  repo. Supports `!expr` YAML tags
  (e.g. [`Sys.getenv()`](https://rdrr.io/r/base/Sys.getenv.html),
  `keyring::key_get()`) resolved via `resolveSecretValue()`.
- **`R/git.R`** — git workflow helpers
  ([`saveWork()`](https://ohdsi.github.io/Picard/reference/saveWork.md),
  [`agentSaveWork()`](https://ohdsi.github.io/Picard/reference/agentSaveWork.md),
  [`createAgentBranch()`](https://ohdsi.github.io/Picard/reference/createAgentBranch.md),
  [`createPullRequest()`](https://ohdsi.github.io/Picard/reference/createPullRequest.md),
  [`validateCodeState()`](https://ohdsi.github.io/Picard/reference/validateCodeState.md))
  built on `gert`, used both by humans and by agent-driven workflows to
  enforce branch discipline (never commit/push directly to `main`).
- **`R/renv.R`** — renv setup/snapshot/restore helpers for reproducible
  study environments.
- **`R/WebApi.R`** — `WebApiConnection` R6 class + helpers for importing
  cohorts/concept sets from an OHDSI ATLAS instance.
- **`R/make.R`** — the bulk of the file-generation helpers
  ([`makeTaskFile()`](https://ohdsi.github.io/Picard/reference/makeTaskFile.md),
  [`makeSrcFile()`](https://ohdsi.github.io/Picard/reference/makeSrcFile.md),
  [`makeBlock()`](https://ohdsi.github.io/Picard/reference/makeBlock.md),
  [`makeDisseminationScript()`](https://ohdsi.github.io/Picard/reference/makeDisseminationScript.md),
  etc.) used both during `initUlyssesRepo()` and afterward as analysts
  add new tasks/cohorts.

### Manifest storage pattern (important when touching CohortManifest/ConceptSetManifest)

Both manifests follow the same shape: an R6 class wraps a SQLite table,
connections are opened/closed per-operation
([`DBI::dbConnect`](https://dbi.r-dbi.org/reference/dbConnect.html) …
`on.exit(DBI::dbDisconnect(conn))`), rows carry a content hash used to
detect drift between the manifest and the on-disk cohort/concept-set
files, and soft-deletes use a `status`/`deleted_at` column rather than
row removal. Tags are stored as a single serialized string
(`"key: value | key2: value2"`) and parsed back out via
[`expandManifestTags()`](https://ohdsi.github.io/Picard/reference/expandManifestTags.md)/`parseTagsString()`.
If you add a column or behavior to one manifest, check whether the
parallel manifest needs the same change — they’re maintained in
lockstep, including their migration files.

### Coding conventions used throughout `R/`

- Task-level/user-facing functions: camelCase (`generateCohorts`,
  `validateStudyTask`). Internal snake_case helpers exist too
  (e.g. `check_git_status`, `build_dependency_graph`) — snake_case
  signals “internal implementation detail,” camelCase signals “public
  API.”
- Package functions are namespaced explicitly
  ([`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html),
  [`checkmate::assert_string()`](https://mllg.github.io/checkmate/reference/checkString.html))
  rather than attached via
  [`library()`](https://rdrr.io/r/base/library.html).
- Input validation via `checkmate::assert_*()` at the top of exported
  functions; user-facing errors/progress via `cli::cli_alert_*`,
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html),
  [`cli::cli_bullets()`](https://cli.r-lib.org/reference/cli_bullets.html)
  rather than base
  [`warning()`](https://rdrr.io/r/base/warning.html)/[`message()`](https://rdrr.io/r/base/message.html).
- R6 private fields are prefixed with a leading dot (`private$.dbPath`,
  `private[[".repoName"]]`).

## Tests

Tests live in `tests/testthat/`, run via
`testthat::test_check("picard")` (see `tests/testthat.R`). Helpers: -
`helper-init.R` — `make_test_repo_for_file_creation()` builds a full
temp Ulysses repo (via the real `initUlyssesRepo()` flow) for tests that
need a realistic repo on disk. - `helper-Manifest.R` —
`cm_test_make_manifest_paths()` / `cm_test_new_manifest()` build an
isolated temp `inputs/cohorts` tree + fresh `CohortManifest` for
manifest tests, avoiding cross-test state. - `test_files/` — fixture
cohort/concept-set JSON and SQL files used by manifest tests.

Test files are split by class/concern (`test-CohortManifest-builders.R`,
`-lifecycle.R`, `-management.R`, `-query.R`, `-review.R`), not one file
per source file — follow that split (by behavior, not by file) when
adding cohort-manifest tests rather than creating a new
`test-CohortManifest-<newfeature>.R` per source file.

## Documentation source of truth

The vignettes in `vignettes/*.Rmd` are the authoritative long-form docs
(repository structure, launching a study, loading inputs,
developing/running the pipeline, post-processing, EGP).
`inst/agent/*.md` files are auto-generated from these vignettes for
consumption inside generated study repos — note the
`<!-- AUTO-GENERATED FILE. DO NOT EDIT DIRECTLY -->` header in files
like `inst/agent/01-repository-structure.md`. If you need to update
guidance that’s duplicated between a vignette and an `inst/agent/` file,
edit the vignette and regenerate, not the other way around.
