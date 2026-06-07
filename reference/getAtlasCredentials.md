# Get Atlas/WebAPI credentials from secrets.yml

Looks up the `atlas` top-level key in secrets.yml and resolves the
credential fields via
[`resolveSecretValue()`](https://ohdsi.github.io/Picard/reference/resolveSecretValue.md).

## Usage

``` r
getAtlasCredentials(secretsFilePath = "secrets.yml")
```

## Arguments

- secretsFilePath:

  Character. Path to the secrets.yml file.

## Value

A named list with `baseUrl`, `authMethod`, `user`, `password`, or NULL
if no `atlas` key is present.
