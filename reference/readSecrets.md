# Read a secrets YAML file

Reads a secrets.yml file using
[`yaml::read_yaml`](https://yaml.r-lib.org/reference/read_yaml.html)
with `eval.expr = FALSE`, so `!expr` tags are preserved as raw strings
for `resolveSecretValue()` to evaluate later. Returns a named list keyed
by dbServer names (plus optional `atlas` key).

## Usage

``` r
readSecrets(secretsFilePath, eval = FALSE)
```

## Arguments

- secretsFilePath:

  Character. Path to the secrets.yml file.

- eval:

  Boolean whether to evaluate the expressions. Defaults to FALSE

## Value

A named list of server credential blocks.
