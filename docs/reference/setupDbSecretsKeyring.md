# Set up keyring-based credentials for a database server

Interactively prompts for credentials using `keyring::key_set()`
dialogs, then writes a secrets.yml entry with
`!expr keyring::key_get(...)` references. This is the most secure
workflow — credentials never appear in plain text on disk.

## Usage

``` r
setupDbSecretsKeyring(
  dbServerName,
  dbmsVal,
  secretsFilePath = "~/.picard/secrets.yml"
)
```

## Arguments

- dbServerName:

  Character. The database server name to set up (e.g.,
  `"snowflake_prod"` or `"redshift_jmdc"`).

- dbmsVal:

  Character. The dbms value, could be snowflake, redshift, postgres

- secretsFilePath:

  Character. Path to the secrets.yml file to write. Default
  `"~/.picard/secrets.yml"`.

## Value

Invisibly returns the secrets file path.

## Details

If the secrets file already exists, the new server entry is appended
rather than overwriting. This allows adding new database servers to an
existing configuration. For Atlas credentials, use
[`setupAtlasSecretsKeyring()`](https://ohdsi.github.io/Picard/reference/setupAtlasSecretsKeyring.md)
separately.
