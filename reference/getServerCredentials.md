# Get credentials for a database server

Looks up a `dbServer` entry in secrets.yml and retrieves credentials.

## Usage

``` r
getServerCredentials(dbServer, secretsFilePath = "~/.picard/secrets.yml")
```

## Arguments

- dbServer:

  Character. The database server name to look up.

- secretsFilePath:

  Character. Path to the secrets.yml file. Default to
  ~/.picard/secrets.yml

## Value

A named list with resolved credential values (`dbms`, `user`,
`password`, `server`, `port`, `connectionString`, `extraSettings`).
Missing optional fields are silently omitted.
