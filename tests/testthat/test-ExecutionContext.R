testthat::test_that("ExecutionContext derives an isolated test namespace", {
  context <- ExecutionContext$new(
    mode = "test",
    namespace = "Develop ML",
    baseCohortTable = "cohort_table",
    databaseName = "My Database",
    execPath = fs::path(tempdir(), "exec", "results")
  )

  testthat::expect_equal(context$getMode(), "test")
  testthat::expect_equal(context$getNamespace(), "develop_ml")
  testthat::expect_equal(context$getCohortTable(), "cohort_table_develop_ml")
  testthat::expect_equal(
    context$getResultsPath("01_task"),
    fs::path(tempdir(), "exec", "results", "my_database", "develop_ml", "01_task")
  )
})

testthat::test_that("ExecutionContext keeps production cohort tables unsuffixed", {
  context <- ExecutionContext$new(
    mode = "production",
    namespace = "1.2.3",
    studyVersion = "1.2.3",
    baseCohortTable = "cohort_table",
    databaseName = "My Database",
    execPath = fs::path(tempdir(), "exec", "results")
  )

  testthat::expect_equal(context$getNamespace(), "1.2.3")
  testthat::expect_equal(context$getStudyVersion(), "1.2.3")
  testthat::expect_equal(context$getCohortTable(), "cohort_table")
  testthat::expect_equal(
    context$getResultsPath(),
    fs::path(tempdir(), "exec", "results", "my_database", "1.2.3")
  )
})

testthat::test_that("ExecutionContext rejects inconsistent production versions", {
  testthat::expect_error(
    ExecutionContext$new(
      mode = "production",
      namespace = "develop_ml",
      studyVersion = "1.2.3",
      baseCohortTable = "cohort_table",
      databaseName = "My Database"
    ),
    "Production namespace must match studyVersion"
  )
})

testthat::test_that("ExecutionContext rejects oversized cohort table names", {
  testthat::expect_error(
    ExecutionContext$new(
      mode = "test",
      namespace = "develop_ml",
      baseCohortTable = "cohort_table",
      databaseName = "My Database",
      maxTableNameLength = 10L
    ),
    "Derived cohort table name is too long"
  )
})