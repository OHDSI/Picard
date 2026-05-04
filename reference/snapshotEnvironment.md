# Snapshot Current Environment State

Captures all package versions and saves lockfile. Useful before major
pipeline operations for reproducibility tracking.

## Usage

``` r
snapshotEnvironment(versionLabel = NULL, savePath = NULL)
```

## Arguments

- versionLabel:

  Character. Optional label for the snapshot (e.g., "v1.0.0"). Used in
  saved filename: renv_lock_versionLabel.json

- savePath:

  Character. Optional path to save versioned lockfile. If NULL and
  versionLabel provided, saves to current directory.

## Value

Character. Hash of lockfile contents for audit trail (invisibly)

## Details

This function:

1.  Updates renv.lock with current package state

2.  Optionally saves versioned copy

3.  Returns lockfile hash for audit/reproducibility tracking

Call before execStudyPipeline() or orchestratePipelineExport().
