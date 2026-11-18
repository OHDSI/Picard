# Get Cohort Manifest Hash

Loads the cohort manifest and returns
[CohortManifest\$getManifestHash()](https://ohdsi.github.io/Picard/reference/CohortManifest.md),
a SHA256 digest over every registered (`active`/`stale`) cohort's
definition and metadata (label, category, tags). Used by
[`shouldRerunTask()`](https://ohdsi.github.io/Picard/reference/shouldRerunTask.md)
to detect cohort changes that require a task rerun.

## Usage

``` r
.getCohortManifestHash(projectPath = here::here())
```

## Arguments

- projectPath:

  Character. A path inside the study repository. Defaults to the current
  project
  ([`here::here()`](https://here.r-lib.org/reference/here.html)).

## Value

Character. SHA256 hex digest, or `NA_character_` if the manifest cannot
be read.

## Details

A thin wrapper around the manifest method, which is the single source of
truth for what "the cohorts changed" means. The load is read-only
(`autoSync = FALSE`), so this has no side effects. Any failure to load
or hash the manifest returns `NA_character_`;
[`shouldRerunTask()`](https://ohdsi.github.io/Picard/reference/shouldRerunTask.md)
treats that as "cannot prove unchanged" and forces the rerun.
