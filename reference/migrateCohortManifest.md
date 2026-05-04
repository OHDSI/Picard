# Migrate Old CohortManifest SQLite to New Schema

One-time migration utility that converts an existing
`cohortManifest.sqlite` (picard \<= 0.0.3) to the new schema with
`category`, `source_type`, `cohort_type`, `depends_on`,
`dependency_rule`, and timestamp columns.

## Usage

``` r
migrateCohortManifest(
  dbPath = "inputs/cohorts/cohortManifest.sqlite",
  categoryMap = NULL
)
```

## Arguments

- dbPath:

  Character. Path to the existing `cohortManifest.sqlite` file. Defaults
  to `"inputs/cohorts/cohortManifest.sqlite"`.

- categoryMap:

  Named list. Maps cohort labels to categories. Example:
  `list("Type 2 Diabetes" = "target", "GI Bleed" = "outcome")`. Cohorts
  not in the map will be assigned from tag keywords or "unclassified".

## Value

Invisible tibble of migrated rows with their assigned categories.

## Details

The migration performs the following steps:

1.  Backs up the old database to
    `cohortManifest_backup_{timestamp}.sqlite`

2.  Reads all rows from the old schema

3.  Infers `source_type` from file path (`json/` -\> "atlas", `sql/` -\>
    "sql", `derived/` -\> "derived")

4.  Infers `cohort_type` from old `cohortType` column

5.  Assigns `category` from `categoryMap`, tag keywords, or defaults to
    "unclassified"

6.  Converts tags from pipe-delimited string to JSON named list

7.  Reads sidecar `.json` metadata for dependent cohorts -\>
    `dependency_rule` and `depends_on`

8.  Creates new schema with unique indexes

9.  Inserts migrated rows

10. Prints migration summary
