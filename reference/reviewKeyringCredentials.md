# Review keyring credentials for picard service

Lists all credentials stored in the "picard" keyring service with their
actual values, organized by database servers and Atlas. Useful for
verifying that setup functions correctly stored credentials and
debugging resolution issues.

## Usage

``` r
reviewKeyringCredentials()
```

## Value

Invisibly returns a tibble with columns: username, service.

## Details

Displays credentials in two organized sections:

- Database Server Credentials: all `{server}_dbms`, `{server}_server`,
  `{server}_port`, `{server}_user`, `{server}_password`, and
  `{server}_connectionString` entries

- Atlas Credentials: all `atlas_*` entries
