# Edit the secrets.yml file

Opens the secrets file in the user's editor (like
`usethis::edit_r_environ()`). If the file doesn't exist, creates a
minimal skeleton with just a header comment, then opens it for editing.

## Usage

``` r
editSecrets(secretsFilePath = "~/.picard/secrets.yml")
```

## Arguments

- secretsFilePath:

  Character. Path to the secrets.yml file. Default
  `"~/.picard/secrets.yml"` — the canonical user-level location outside
  any git repo.

## Value

Invisibly returns the file path.
