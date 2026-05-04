# set the config block for a database

set the config block for a database

## Usage

``` r
setDbConfigBlock(
  configBlockName,
  cdmDatabaseSchema,
  cohortTable,
  databaseName = NULL,
  databaseLabel = NULL
)
```

## Arguments

- configBlockName:

  the name of the config block

- cdmDatabaseSchema:

  the cdmDatabaseSchema specified as a character string

- cohortTable:

  a character string specifying the way you want to name your cohort
  table

- databaseName:

  the name of the database, typically uses the db name and id. For
  example optum_dod_202501

- databaseLabel:

  the labelling name of the database, typically a common name for a db.
  For example Optum DOD

## Value

A StudyMeta R6 class with the study meta
