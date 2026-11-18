# Validate a secrets.yml file

Checks that the secrets file exists, is parseable by
[`yaml::read_yaml`](https://yaml.r-lib.org/reference/read_yaml.html),
and has a top-level entry for each `dbServer` name. Each server entry
requires `dbms`; then either `connectionString` (Snowflake) or
`server` + `port` + `user` + `password` (other DBMS).

## Usage

``` r
validateSecretsYaml(secretsFilePath, dbServerNames)
```

## Arguments

- secretsFilePath:

  Character. Path to secrets.yml.

- dbServerNames:

  Character vector. Expected server names.

## Value

Invisibly returns TRUE if valid. Stops with errors otherwise.

## Details

If credentials are stored via
[`setupDbSecretsKeyring()`](https://ohdsi.github.io/Picard/reference/setupDbSecretsKeyring.md),
fields may contain `!expr keyring::key_get(...)` expressions. Validation
checks for the presence of required fields but cannot fully validate the
DBMS type or expression validity when using keyring-based credentials
(that validation happens at credential resolution time).

If an `atlas` entry is present, requires `baseUrl`, `authMethod`,
`user`, `password`.
