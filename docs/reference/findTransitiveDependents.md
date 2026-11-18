# Find all transitive downstream dependents of the given cohorts

BFS through the reverse dependency graph stored in
cohort_manifest.depends_on, considering active and stale rows only.

## Usage

``` r
findTransitiveDependents(dbPath, cohort_ids)
```

## Arguments

- dbPath:

  Character. Path to the manifest SQLite database.

- cohort_ids:

  Integer vector. The seed cohort IDs.

## Value

Integer vector of transitive dependent IDs in BFS (parent-first) order,
excluding the seeds themselves.
