# Load Cohort Manifest from SQLite Database

Loads a CohortManifest R6 object from an existing
`cohortManifest.sqlite` database. This is a pure read from SQLite — it
does not scan directories or auto-add new files. If new files exist on
disk that aren't in the manifest, a warning is printed suggesting the
appropriate `$add*()` method.

## Usage

``` r
loadCohortManifest(
  cohortsFolderPath = here::here("inputs/cohorts"),
  executionSettings = NULL,
  autoSync = TRUE,
  verbose = TRUE
)
```

## Arguments

- cohortsFolderPath:

  Character. Path to the cohorts folder, or anywhere inside the study
  repository. Defaults to `here::here("inputs/cohorts")`. The repository
  root is discovered with
  [`findStudyProjectRoot()`](https://ohdsi.github.io/Picard/reference/findStudyProjectRoot.md)
  and the manifest is always read from
  `<root>/inputs/cohorts/cohortManifest.sqlite`.

- executionSettings:

  An ExecutionSettings object containing database configuration for
  cohort generation. Optional; can be added later using
  `$setExecutionSettings()`.

- autoSync:

  Logical. If TRUE (default), reconcile the manifest against the files
  on disk after loading (see `$syncManifest()`). This only affects
  file/row reconciliation — it is **not** related to path resolution,
  and setting it to FALSE is not a workaround for a manifest that fails
  to load.

- verbose:

  Logical. If TRUE, prints informative messages. Defaults to TRUE.

## Value

A CohortManifest R6 object.

## Details

If no SQLite database exists at the expected path, the function stops
with an error directing the user to
[`initCohortManifest()`](https://ohdsi.github.io/Picard/reference/initCohortManifest.md).

After loading, the function checks for new files in `json/`, `sql/`, and
`derived/` directories that are not tracked in the manifest. These are
reported as warnings but NOT auto-added (because `category` is required
and cannot be guessed).

### File paths

Cohort file paths are stored **relative to the study repository root**
(e.g. `inputs/cohorts/json/mycohort.json`). Loading resolves them
against that root, so a manifest loads identically on any machine and
from any working directory — you do not need to
[`setwd()`](https://rdrr.io/r/base/getwd.html) into the study repo
first.

Manifests created before this convention may hold
working-directory-relative, manifest-folder-relative, or absolute paths.
Those still resolve through a compatibility fallback, but you can
rewrite them to the current convention once with
[`normalizeCohortManifestPaths()`](https://ohdsi.github.io/Picard/reference/normalizeCohortManifestPaths.md).
Ordinary loads never modify the SQLite file.

## See also

[`normalizeCohortManifestPaths()`](https://ohdsi.github.io/Picard/reference/normalizeCohortManifestPaths.md),
[`findStudyProjectRoot()`](https://ohdsi.github.io/Picard/reference/findStudyProjectRoot.md)
