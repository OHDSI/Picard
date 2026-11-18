# Get renv Lockfile Hash

Returns a SHA256 digest over the R version and every package record
(name, version, source, remote SHA) in the study's `renv.lock`. Used by
[`shouldRerunTask()`](https://ohdsi.github.io/Picard/reference/shouldRerunTask.md)
so that any package or R version change forces tasks to rerun.

## Usage

``` r
.getRenvLockHash(projectPath = here::here())
```

## Arguments

- projectPath:

  Character. A path inside the study repository. Defaults to the current
  project
  ([`here::here()`](https://here.r-lib.org/reference/here.html)).

## Value

Character. SHA256 hex digest, `"<no-renv-lock>"`, or `NA_character_` if
the lockfile cannot be read.

## Details

Only the recorded versions are hashed, not the raw file, so reformatting
the lockfile or reordering its entries does not force a rerun. The
pipeline validates that the installed library matches `renv.lock` before
running tasks, so the lockfile stands in for the installed package
versions. A study without `renv.lock` hashes to a stable sentinel; a
lockfile that cannot be parsed returns `NA_character_`, which forces a
rerun.
