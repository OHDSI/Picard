# Cascade stale status to downstream dependents

Given a set of cohort IDs whose definitions changed, marks all
transitive dependent cohorts as 'stale' in the manifest database. Uses
BFS through the reverse dependency graph stored in
cohort_manifest.depends_on.

## Usage

``` r
cascadeStaleDownstream(dbPath, cohort_ids)
```

## Arguments

- dbPath:

  Character. Path to the manifest SQLite database.

- cohort_ids:

  Integer vector. The seed cohort IDs that changed.

## Value

Invisibly returns the integer vector of IDs marked stale.
