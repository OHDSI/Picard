# Make ExecOptions for Ulysses

Make ExecOptions for Ulysses

## Usage

``` r
makeExecOptions(
  dbms,
  workDatabaseSchema,
  tempEmulationSchema = NULL,
  dbConnectionBlocks
)
```

## Arguments

- dbms:

  specify the dbms used in the exec options

- workDatabaseSchema:

  the name of the workDatabaseSchema as a character string, location in
  DB where user has write access

- tempEmulationSchema:

  he name of the tempEmulationSchema as a character strings

- dbConnectionBlocks:

  a list of DbConfigBlock R6 classes specifying the dbs to connect

## Value

A ExecOptions R6 class with the execOptions
