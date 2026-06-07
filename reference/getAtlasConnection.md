# Get Atlas Connection

Creates a `WebApiConnection` object using credentials from:

1.  **secrets.yml** (preferred) — uses the `atlas` key in your
    `~/.picard/secrets.yml` file (see
    [`editSecrets()`](https://ohdsi.github.io/Picard/reference/editSecrets.md)
    and
    [`setupAtlasSecretsKeyring()`](https://ohdsi.github.io/Picard/reference/setupAtlasSecretsKeyring.md)).

2.  `.Renviron` — reads `atlasBaseUrl`, `atlasAuthMethod`, `atlasUser`,
    `atlasPassword` environment variables.

3.  `keyring` — retrieves from the OS keyring directly (legacy).

## Usage

``` r
getAtlasConnection(
  useKeyring = FALSE,
  secretsFilePath = "~/.picard/secrets.yml"
)
```

## Arguments

- useKeyring:

  Logical. If TRUE and no secrets.yml atlas key is found, retrieves
  credentials from the keyring package directly (legacy path). Default
  FALSE.

- secretsFilePath:

  Character. Path to secrets.yml. Default `"~/.picard/secrets.yml"`.
  Ignored if the file doesn't exist or has no `atlas` key.

## Value

An R6 class of WebApiConnection containing the ATLAS WebAPI connection
details

## Details

The recommended workflow is to store Atlas credentials in
`~/.picard/secrets.yml` via
[`setupAtlasSecretsKeyring()`](https://ohdsi.github.io/Picard/reference/setupAtlasSecretsKeyring.md)
or
[`editSecrets()`](https://ohdsi.github.io/Picard/reference/editSecrets.md).
The secrets.yml approach supports three credential formats:

- Plain strings, `!expr keyring::key_get(...)`, or
  `!expr Sys.getenv(...)`.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Using secrets.yml (recommended)
  atlasCon <- getAtlasConnection()

  # Using keyring directly (legacy)
  atlasCon <- getAtlasConnection(useKeyring = TRUE)
} # }
```
