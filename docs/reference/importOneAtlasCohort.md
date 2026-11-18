# Import one Atlas cohort intelligently (skip/update/add)

Checks if a cohort with the same label already exists in the manifest.
If it does and the Atlas JSON hasn't changed, skip it. If JSON changed,
overwrite the file and update the manifest hash. If new, add normally.

## Usage

``` r
importOneAtlasCohort(row, tag_cols, dbPath, atlasConnection, sqlite_conn)
```

## Arguments

- row:

  A one-row data frame from cohortsLoad.csv.

- tag_cols:

  Character vector. Extra column names to treat as tags.

- dbPath:

  Character. Path to the manifest SQLite database.

- atlasConnection:

  An ATLAS connection object with getCohortDefinition().

- sqlite_conn:

  An open DBI connection to the manifest database.

## Value

A list with `id`, `label`, `status`.
