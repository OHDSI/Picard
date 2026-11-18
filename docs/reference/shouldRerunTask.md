# Check if Task Needs to be Rerun

Determines whether a task needs to be rerun by checking:

1.  Task file modifications (file hash comparison)

2.  Dependency file modifications (extracted from source() calls)

3.  Cohort manifest changes — compares
    [CohortManifest\$getManifestHash()](https://ohdsi.github.io/Picard/reference/CohortManifest.md)
    (definitions plus label, category, and tags) against the hash
    recorded on the previous run. A rerun is forced when the hash
    differs, when no hash was recorded (first run, or a legacy history
    row), or when the current hash cannot be computed at all.

4.  Concept set manifest changes — compares
    [ConceptSetManifest\$getManifestHash()](https://ohdsi.github.io/Picard/reference/ConceptSetManifest.md)
    (definitions plus label, category, and tags) against the hash
    recorded on the previous run, with the same fail-safe rules as the
    cohort manifest check.

5.  renv lockfile changes — any change to the R version or to a package
    recorded in `renv.lock` forces a rerun (see
    [`.getRenvLockHash()`](https://ohdsi.github.io/Picard/reference/dot-getRenvLockHash.md)).

6.  Previous run errors (checked in logs and history)

7.  Version changes. History is scoped by task, config block, and
    `pipeline_version`, so separate test namespaces do not reuse one
    another's run state.

## Usage

``` r
shouldRerunTask(
  taskFile,
  configBlock,
  executionSettings,
  pipelineVersion,
  tasksFolderPath = here::here("analysis/tasks"),
  cohortManifestHash = NULL,
  conceptSetManifestHash = NULL,
  renvLockHash = NULL
)
```

## Arguments

- taskFile:

  Character. Name or path of the task file (e.g., "task1.R")

- configBlock:

  Character. The config block name (e.g., "optum_dod")

- executionSettings:

  ExecutionSettings object

- pipelineVersion:

  Character. Current pipeline version (e.g., "1.0.0")

- tasksFolderPath:

  Character. Path to tasks folder (default:
  here::here("analysis/tasks"))

- cohortManifestHash:

  Character or NULL. A pre-computed cohort manifest hash (see
  [`.getCohortManifestHash()`](https://ohdsi.github.io/Picard/reference/dot-getCohortManifestHash.md)).
  When NULL (default) it is computed here; callers that check many tasks
  in one run pass it in to avoid re-loading the manifest per task.

- conceptSetManifestHash:

  Character or NULL. A pre-computed concept set manifest hash (see
  [`.getConceptSetManifestHash()`](https://ohdsi.github.io/Picard/reference/dot-getConceptSetManifestHash.md)).
  Computed here when NULL.

- renvLockHash:

  Character or NULL. A pre-computed renv lockfile hash (see
  [`.getRenvLockHash()`](https://ohdsi.github.io/Picard/reference/dot-getRenvLockHash.md)).
  Computed here when NULL.

## Value

List with elements:

- should_rerun: Logical. TRUE if task should be rerun

- reasons: Character vector. Why task should be rerun

- last_run_info: List with previous run details (time, version, status)

- task_file_hash: Current hash of task file

- cohort_manifest_hash: Current hash of cohort manifest definitions

- concept_set_manifest_hash: Current hash of concept set manifest

- renv_lock_hash: Current hash of renv.lock

## Details

Creates/updates exec/logs/task_run_history.csv tracking:

- task_name, config_block, last_run_time, pipeline_version

- task_file_hash, cohort_manifest_hash, concept_set_manifest_hash,
  renv_lock_hash, status, error_message
