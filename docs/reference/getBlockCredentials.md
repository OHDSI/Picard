# Get credentials for a config block

Convenience function: reads the config block from config.yml, extracts
its `dbServer` field, then calls
[`getServerCredentials()`](https://ohdsi.github.io/Picard/reference/getServerCredentials.md).

## Usage

``` r
getBlockCredentials(
  configBlock,
  configFilePath,
  secretsFilePath = "~/.picard/secrets.yml"
)
```

## Arguments

- configBlock:

  Character. The config block name.

- configFilePath:

  Character. Path to config.yml.

- secretsFilePath:

  Character. Path to secrets.yml.

## Value

A named list of resolved credential values.
