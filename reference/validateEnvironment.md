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
