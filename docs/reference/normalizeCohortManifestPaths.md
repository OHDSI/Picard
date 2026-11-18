# Normalize Legacy Cohort Manifest File Paths

A one-time cleanup that rewrites the `file_path` of every active/stale
row in `cohortManifest.sqlite` so it is stored **relative to the study
repository root** (the current convention). Manifests created before
this convention may hold working-directory-relative,
manifest-folder-relative, or absolute paths; those still load through a
compatibility resolver, but normalizing makes the stored values stable
and portable across machines and working directories.

## Usage

``` r
normalizeCohortManifestPaths(
  cohortsFolderPath = here::here("inputs/cohorts"),
  dryRun = FALSE
)
```

## Arguments

- cohortsFolderPath:

  Character. Path to the cohorts folder (or anywhere inside the study
  repository). Defaults to `here::here("inputs/cohorts")`.

- dryRun:

  Logical. When `TRUE`, report what would change without writing.
  Defaults to `FALSE`.

## Value

Invisibly, a tibble with columns `id`, `old_path`, `new_path`, `status`
(one of `"rewritten"`, `"would_rewrite"`, `"unchanged"`, `"broken"`,
`"no_path"`).

## Details

Only `file_path` is changed. Content hashes, `status`, timestamps and
the change-detection metadata are left untouched, so running this never
marks a cohort stale or shows up as a definition change in syncManifest.

Ordinary loads never mutate the SQLite file — this is the *only*
operation that rewrites stored paths, and you run it explicitly.

## See also

[`findStudyProjectRoot()`](https://ohdsi.github.io/Picard/reference/findStudyProjectRoot.md),
[`loadCohortManifest()`](https://ohdsi.github.io/Picard/reference/loadCohortManifest.md)
