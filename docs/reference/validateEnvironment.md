# Validate Environment Against Lockfile

Checks that installed packages match renv.lock. Prevents running
pipelines with environment drift. Call before execStudyPipeline() or
runPostProcessing().

## Usage

``` r
validateEnvironment()
```

## Value

Invisible TRUE if valid, aborts if drift detected

## Details

`renv::status()` always returns a list describing the project state — it
never returns `NULL` — so the result must be inspected rather than
merely tested for `NULL`. A project is treated as in sync when
`renv::status()` reports `synchronized = TRUE`, or (on older renv
versions that omit the flag) when no package version differs between the
project library and `renv.lock`. Source-only mismatches, such as
packages installed from an unknown source, are reported as a warning and
do not block the pipeline.
