# Testing the Picard Package

This directory contains the testthat test suite for the picard package.

## Running Tests

To run all tests:

```r
devtools::test()
```

Or locally in the testthat framework:

```r
testthat::test_local()
```

To run tests for a specific file:

```r
testthat::test_file("tests/testthat/test-CohortDef.R")
```

## Test Structure

The tests are organized into the following files:

### test-CohortDef.R
Tests for the `CohortDef` R6 class, including:
- Initialization with SQL and JSON files
- Active bindings (label, tags)
- Methods (getId, setId, formatTagsAsString)
- Error handling for missing files

### test-CohortManifest.R
Tests for the `CohortManifest` R6 class, including:
- Manifest initialization and SQLite database creation
- Database table structure verification
- Query methods returning data frames (queryCohortsByIds, queryCohortsByTag, etc.)
- Object retrieval (getCohortById, getCohortsByTag, etc.)
- Cohort counting

**Note**: Tests for database-dependent methods (createCohortTables, generateCohorts, retrieveCohortCounts) are skipped because they require a live database connection. These can be adapted for integration testing with a test database.

### test-helpers.R
Tests for helper functions, including:
- tableExists() - table existence checking
- getCohortTableNames() - table name generation
- SQL creation functions for all cohort table types

## Cleanup

All tests use R's automatic cleanup mechanisms:
- Temporary files created during tests are removed via `on.exit(unlink(...))`
- Temporary directories are recursively deleted
- Database connections are closed

This ensures no test artifacts are left behind after test execution.

## Database Testing

Tests that require database connections are marked with `skip()` to allow the test suite to run completely without a live database. To enable these tests, you would need to:

1. Set up a test database instance
2. Create ExecutionSettings pointing to the test database
3. Remove or modify the skip() statements

See the CohortManifest tests for examples of database-dependent functionality.
