# Restore Environment from Lockfile

Restores all packages to versions specified in renv.lock. Useful for
reproducibility when re-running analyses.

## Usage

``` r
restoreEnvironment(versionLabel = NULL)
```

## Arguments

- versionLabel:

  Character. Optional label to restore from specific versioned lockfile
  (e.g., "v1.0.0" restores from renv_lock_v1.0.0.json)

## Value

Invisible TRUE
