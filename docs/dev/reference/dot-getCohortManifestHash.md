# Get Cohort Manifest Hash

Loads the cohort manifest and computes a SHA256 hash of the entire
manifest. This hash is used to detect changes in cohort definitions that
would require task reruns.

## Usage

``` r
.getCohortManifestHash()
```

## Value

Character. SHA256 hash of the cohort manifest, or NA_character\_ if
error occurs
