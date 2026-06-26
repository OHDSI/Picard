# Migrate Old ConceptSetManifest SQLite to New Schema

One-time migration utility that converts an existing
`conceptSetManifest.sqlite` (picard \<= 0.0.3.1) to the new schema with
`category`, `status`, `created_at`, `updated_at`, and `deleted_at`
columns, and converts tags from pipe-delimited string format to JSON.

## Usage

``` r
migrateConceptSetManifest(
  dbPath = "inputs/conceptSets/conceptSetManifest.sqlite",
  categoryMap = NULL
)
```

## Arguments

- dbPath:

  Character. Path to the existing `conceptSetManifest.sqlite` file.
  Defaults to `"inputs/conceptSets/conceptSetManifest.sqlite"`.

- categoryMap:

  Named list. Maps concept set labels to categories. Example:
  `list("BMI Ratio" = "measurement", "Diabetes" = "condition_occurrence")`.
  Concept sets not in the map will be assigned from tag keywords or
  "init".

## Value

Invisible tibble of migrated rows with their assigned categories.

## Details

The migration performs the following steps:

1.  Backs up the old database to
    `conceptSetManifest_backup_{timestamp}.sqlite`

2.  Reads all rows from the old schema

3.  Assigns `category` from the tag keywords (e.g., "domain:
    condition_occurrence" -\> "condition_occurrence") or defaults to
    "init" if not found

4.  Converts tags from pipe-delimited string (e.g., "name: value \|
    name: value") to JSON named list

5.  Adds missing columns (category, status, created_at, updated_at,
    deleted_at) if they don't exist

6.  Creates new schema with proper structure

7.  Inserts migrated rows with `created_at` and `updated_at` set to old
    `timestamp` value

8.  Prints migration summary

New schema columns:

- `id`: Auto-incrementing primary key

- `label`: Concept set display name

- `category`: OMOP domain or custom category

- `tags`: JSON object of key-value metadata

- `file_path`: Absolute or relative path to JSON definition file

- `hash`: File hash for change detection

- `status`: 'active' or 'inactive' (soft delete flag)

- `created_at`: Creation timestamp

- `updated_at`: Last update timestamp

- `deleted_at`: Soft delete timestamp (NULL if active)
