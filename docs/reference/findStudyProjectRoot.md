# Find the root of a Picard study repository

Walks upward from a file or directory until it finds the structural
markers that identify a Picard study repository, and returns that
directory. This is how the cohort and concept-set manifests locate the
root against which their stored `file_path` values are resolved, so a
manifest loads the same way regardless of the caller's working
directory.

## Usage

``` r
findStudyProjectRoot(path = here::here())
```

## Arguments

- path:

  Character. A file or directory inside the study repository. Defaults
  to the current project detected by
  [`here::here()`](https://here.r-lib.org/reference/here.html).

## Value

Character. The normalized absolute path to the study repository root.

## Details

The markers are the files `config.yml` and `README.md` together with the
directories `analysis/`, `inputs/` and `dissemination/`, all present in
the same directory. The search stops with an error if it reaches the
filesystem root without finding them.

## See also

[`normalizeCohortManifestPaths()`](https://ohdsi.github.io/Picard/reference/normalizeCohortManifestPaths.md),
[`normalizeConceptSetManifestPaths()`](https://ohdsi.github.io/Picard/reference/normalizeConceptSetManifestPaths.md)
