# Get Atlas Connection

Creates a `WebApiConnection` object using credentials from secrets.yml

## Usage

``` r
getAtlasConnection(secretsFilePath = "~/.picard/secrets.yml")
```

## Arguments

- secretsFilePath:

  Character. Path to secrets.yml. Default `"~/.picard/secrets.yml"`.

## Value

An R6 class of WebApiConnection containing the ATLAS WebAPI connection
details

## Details

Store Atlas credentials in `~/.picard/secrets.yml` via
[`setupAtlasSecretsKeyring()`](https://ohdsi.github.io/Picard/reference/setupAtlasSecretsKeyring.md)
or
[`editSecrets()`](https://ohdsi.github.io/Picard/reference/editSecrets.md).
The secrets.yml approach supports three credential formats:

- Plain strings, `!expr keyring::key_get(...)`, or
  `!expr Sys.getenv(...)`.
