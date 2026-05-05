# Create a SqlRender SQL File

Creates a new SQL script in the analysis/src/sql folder for storing
parameterized OMOP queries. These files are rendered using SqlRender and
executed against the CDM.

## Usage

``` r
makeSrcSqlFile(
  fileName,
  author = NULL,
  description = NULL,
  projectPath = here::here(),
  openFile = TRUE
)
```

## Arguments

- fileName:

  The name of the SQL file (e.g., "condition_occurrence_query")

- author:

  The name of the author. Defaults to template text if NULL

- description:

  A brief description of what this query does. Defaults to template text
  if NULL

- projectPath:

  The path to the project (defaults to current project)

- openFile:

  Whether to open the file after creating it (default TRUE)

## Value

Invisible character string containing the template content

## Details

SQL files in src/sql are parameterized queries meant to be rendered with
SqlRender::render() before execution. They should use @ notation for
parameters (e.g., @cdmDatabaseSchema). Document all parameters used in
your query with comments at the top of the file.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a SQL query for analyzing condition_occurrence
makeSrcSqlFile(
  fileName = "condition_occurrence_counts",
  author = "Jane Doe",
  description = "Count conditions by month in the CDM"
)

# Create with minimal arguments
makeSrcSqlFile(fileName = "get_person_demographics")
} # }
```
