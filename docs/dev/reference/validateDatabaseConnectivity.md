# Validate Database Connectivity

Attempts a test connection to each config block's database using the
project's config.yml credentials. Only called when
`skipConnectivityCheck = FALSE` in
[`execStudyPipeline()`](https://ohdsi.github.io/Picard/dev/reference/execStudyPipeline.md).
Returns a named list of pass/warn results per block.

## Usage

``` r
validateDatabaseConnectivity(configBlock)
```

## Arguments

- configBlock:

  Character vector. Config block names to test.

## Value

Named list of result lists with `status` and `message` per block.
