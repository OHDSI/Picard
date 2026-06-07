# Read a secrets YAML file

Reads a secrets.yml file using
[`yaml::read_yaml`](https://yaml.r-lib.org/reference/read_yaml.html)
with `eval.expr = FALSE`, so `!expr` tags are preserved as raw strings
for
[`resolveSecretValue()`](https://ohdsi.github.io/Picard/reference/resolveSecretValue.md)
to evaluate later. Returns a named list keyed by dbServer names (plus
optional `atlas` key).

## Usage

``` r
readSecrets(secretsFilePath)
```

## Arguments

- secretsFilePath:

  Character. Path to the secrets.yml file.

## Value

A named list of server credential blocks.
