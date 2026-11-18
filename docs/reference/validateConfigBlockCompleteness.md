# Validate Config Blocks Exist in config.yml

Checks that every config block name in the supplied vector corresponds
to a top-level key in config.yml. Catches typos before a mid-run
failure.

## Usage

``` r
validateConfigBlockCompleteness(configBlock, configFilePath = "config.yml")
```

## Arguments

- configBlock:

  Character vector. Config block names to validate.

- configFilePath:

  Character. Path to config.yml. Defaults to "config.yml" in the working
  directory.

## Value

Logical TRUE invisibly if all blocks exist. Stops with error if any are
missing.
