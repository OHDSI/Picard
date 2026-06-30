# Get Atlas/WebAPI credentials from secrets.yml

Looks up the `atlas` top-level key in secrets.yml and retrieves
credentials.

## Usage

``` r
getAtlasCredentials(secretsFilePath = "~/.picard/secrets.yml")
```

## Arguments

- secretsFilePath:

  Character. Path to the secrets.yml file. Default to
  ~/.picard/secrets.yml

## Value

A named list with `baseUrl`, `authMethod`, `user`, `password`, or NULL
if no `atlas` key is present.
