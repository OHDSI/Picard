# Get Atlas Connection

Creates a `WebApiConnection` object using credentials from either
`.Renviron` or the `keyring` package. This is the standalone credential
helper — to attach the connection to a manifest use
`manifest$setAtlasConnection(getAtlasConnection())`.

## Usage

``` r
getAtlasConnection(useKeyring = FALSE)
```

## Arguments

- useKeyring:

  Logical. If TRUE, retrieves credentials from the keyring package. If
  FALSE (default), uses environment variables from .Renviron.

## Value

An R6 class of WebApiConnection containing the ATLAS WebAPI connection
details

## Details

Credentials are stored using a standardized structure in the system
keyring. All ATLAS credentials are grouped under the service "picard"
with individual identifiers for each credential type.

### Using .Renviron (Default)

    # Credentials must be set in .Renviron:
    # atlasBaseUrl='https://organization-atlas.com/WebAPI'
    # atlasAuthMethod='ad'
    # atlasUser='user@organization.com'
    # atlasPassword='YourPassword'

    atlasCon <- getAtlasConnection()

### Using keyring (Recommended for Security)

First, store credentials securely in the default keyring:

    keyring::key_set(service = "picard", username = "atlasBaseUrl")
    keyring::key_set(service = "picard", username = "atlasAuthMethod")
    keyring::key_set(service = "picard", username = "atlasUser")
    keyring::key_set(service = "picard", username = "atlasPassword")

Then retrieve and connect:

    atlasCon <- getAtlasConnection(useKeyring = TRUE)

## Examples

``` r
if (FALSE) { # \dontrun{
  # Using .Renviron (default)
  atlasCon <- getAtlasConnection()

  # Using keyring
  atlasCon <- getAtlasConnection(useKeyring = TRUE)
} # }
```
