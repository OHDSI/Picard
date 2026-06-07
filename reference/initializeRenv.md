# Initialize Renv for Project

Sets up renv for the pipeline project on first run. Creates renv
infrastructure and initial lockfile.

## Usage

``` r
initializeRenv()
```

## Value

Invisible TRUE

## Details

Must be run once per project before using other renv functions. Sets up:

- renv.lock in project root

- renv/ project library

- renv auto-loader in .Rprofile
