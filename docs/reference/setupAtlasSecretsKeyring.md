# Set up Atlas/WebAPI keyring credentials

Interactively prompts for Atlas/WebAPI credentials using
`keyring::key_set()` and writes them to secrets.yml with
`!expr keyring::key_get(...)` references. This is the most secure
workflow — credentials never appear in plain text on disk.

## Usage

``` r
setupAtlasSecretsKeyring(secretsFilePath = "~/.picard/secrets.yml")
```

## Arguments

- secretsFilePath:

  Character. Path to the secrets.yml file to write. Default
  `"~/.picard/secrets.yml"`.

## Value

Invisibly returns the secrets file path.

## Details

If the secrets file already exists, the atlas entry is appended rather
than overwriting.
