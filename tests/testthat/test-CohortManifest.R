test_that("CohortManifest initializes and creates SQLite database", {
  # Create temporary directory for test
  temp_dir <- tempfile(prefix = "picard_test_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Create temporary SQL file for cohort
  temp_sql <- tempfile(fileext = ".sql")
  writeLines("SELECT 1;", temp_sql)
  on.exit(unlink(temp_sql), add = TRUE)

  # Create CohortDef
  cohort <- CohortDef$new(
    label = "Test Cohort",
    tags = list(),
    filePath = temp_sql
  )

  # Create mock ExecutionSettings - we'll use a simple list object
  mock_settings <- list(
    databaseName = "test_db",
    workDatabaseSchema = "results",
    cohortTable = "cohort",
    getConnection = function() NULL,
    disconnect = function() {}
  )
  class(mock_settings) <- "ExecutionSettings"

  # Create manifest with custom dbPath
  db_path <- file.path(temp_dir, "cohortManifest.sqlite")

  # This should create the database
  manifest <- CohortManifest$new(
    cohortEntries = list(cohort),
    executionSettings = mock_settings,
    dbPath = db_path
  )

  # Verify database was created
  expect_true(file.exists(db_path))

  # Verify we can retrieve the manifest
  manifest_df <- manifest$getManifest()
  expect_equal(nrow(manifest_df), 1)
  expect_equal(manifest_df$label[1], "Test Cohort")
})

test_that("CohortManifest creates cohort_manifest table", {
  temp_dir <- tempfile(prefix = "picard_test_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  temp_sql <- tempfile(fileext = ".sql")
  writeLines("SELECT 1;", temp_sql)
  on.exit(unlink(temp_sql), add = TRUE)

  cohort <- CohortDef$new(
    label = "Test",
    tags = list(),
    filePath = temp_sql
  )

  mock_settings <- list(
    databaseName = "test_db",
    getConnection = function() NULL,
    disconnect = function() {}
  )
  class(mock_settings) <- "ExecutionSettings"

  db_path <- file.path(temp_dir, "test.sqlite")

  manifest <- CohortManifest$new(
    cohortEntries = list(cohort),
    executionSettings = mock_settings,
    dbPath = db_path
  )

  # Connect to the database and verify table structure
  conn <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  tables <- DBI::dbListTables(conn)
  expect_true("cohort_manifest" %in% tables)

  # Verify table has expected columns
  columns <- DBI::dbListFields(conn, "cohort_manifest")
  expected_cols <- c("id", "label", "tags", "filePath", "hash", "timestamp")
  expect_true(all(expected_cols %in% columns))
})

test_that("CohortManifest queryCohortsByIds returns correct cohort data frame", {
  temp_dir <- tempfile(prefix = "picard_test_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  temp_sql <- tempfile(fileext = ".sql")
  writeLines("SELECT 1;", temp_sql)
  on.exit(unlink(temp_sql), add = TRUE)

  cohort <- CohortDef$new(
    label = "Test Cohort",
    tags = list(category = "test"),
    filePath = temp_sql
  )

  mock_settings <- list(
    databaseName = "test_db",
    getConnection = function() NULL,
    disconnect = function() {}
  )
  class(mock_settings) <- "ExecutionSettings"

  db_path <- file.path(temp_dir, "test.sqlite")

  manifest <- CohortManifest$new(
    cohortEntries = list(cohort),
    executionSettings = mock_settings,
    dbPath = db_path
  )

  result <- manifest$queryCohortsByIds(1L)

  expect_equal(nrow(result), 1)
  expect_equal(result$label[1], "Test Cohort")
  expect_equal(result$id[1], 1)
})

test_that("CohortManifest getCohortById returns CohortDef object", {
  temp_dir <- tempfile(prefix = "picard_test_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  temp_sql <- tempfile(fileext = ".sql")
  writeLines("SELECT 1;", temp_sql)
  on.exit(unlink(temp_sql), add = TRUE)

  cohort <- CohortDef$new(
    label = "Test Cohort",
    tags = list(),
    filePath = temp_sql
  )

  mock_settings <- list(
    databaseName = "test_db",
    getConnection = function() NULL,
    disconnect = function() {}
  )
  class(mock_settings) <- "ExecutionSettings"

  db_path <- file.path(temp_dir, "test.sqlite")

  manifest <- CohortManifest$new(
    cohortEntries = list(cohort),
    executionSettings = mock_settings,
    dbPath = db_path
  )

  grabbed_cohort <- manifest$getCohortById(1)

  expect_s3_class(grabbed_cohort, "CohortDef")
  expect_equal(grabbed_cohort$label, "Test Cohort")
})

test_that("CohortManifest nCohorts returns correct count", {
  temp_dir <- tempfile(prefix = "picard_test_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Create multiple cohorts
  cohorts <- list()
  for (i in 1:3) {
    temp_sql <- tempfile(fileext = ".sql")
    writeLines("SELECT 1;", temp_sql)
    on.exit(unlink(temp_sql), add = TRUE)

    cohorts[[i]] <- CohortDef$new(
      label = paste("Cohort", i),
      tags = list(),
      filePath = temp_sql
    )
  }

  mock_settings <- list(
    databaseName = "test_db",
    getConnection = function() NULL,
    disconnect = function() {}
  )
  class(mock_settings) <- "ExecutionSettings"

  db_path <- file.path(temp_dir, "test.sqlite")

  manifest <- CohortManifest$new(
    cohortEntries = cohorts,
    executionSettings = mock_settings,
    dbPath = db_path
  )

  expect_equal(manifest$nCohorts(), 3)
})

test_that("CohortManifest queryCohortsByTag filters correctly", {
  temp_dir <- tempfile(prefix = "picard_test_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  temp_sql1 <- tempfile(fileext = ".sql")
  writeLines("SELECT 1;", temp_sql1)
  on.exit(unlink(temp_sql1), add = TRUE)

  temp_sql2 <- tempfile(fileext = ".sql")
  writeLines("SELECT 2;", temp_sql2)
  on.exit(unlink(temp_sql2), add = TRUE)

  cohort1 <- CohortDef$new(
    label = "Primary Cohort",
    tags = list(category = "primary"),
    filePath = temp_sql1
  )

  cohort2 <- CohortDef$new(
    label = "Secondary Cohort",
    tags = list(category = "secondary"),
    filePath = temp_sql2
  )

  mock_settings <- list(
    databaseName = "test_db",
    getConnection = function() NULL,
    disconnect = function() {}
  )
  class(mock_settings) <- "ExecutionSettings"

  db_path <- file.path(temp_dir, "test.sqlite")

  manifest <- CohortManifest$new(
    cohortEntries = list(cohort1, cohort2),
    executionSettings = mock_settings,
    dbPath = db_path
  )

  result <- manifest$queryCohortsByTag("category: primary")

  expect_equal(nrow(result), 1)
  expect_equal(result$label[1], "Primary Cohort")
})

test_that("CohortManifest queryCohortsByTag match='all' requires all tags", {
  temp_dir <- tempfile(prefix = "picard_test_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  temp_sql1 <- tempfile(fileext = ".sql")
  writeLines("SELECT 1;", temp_sql1)
  on.exit(unlink(temp_sql1), add = TRUE)

  temp_sql2 <- tempfile(fileext = ".sql")
  writeLines("SELECT 2;", temp_sql2)
  on.exit(unlink(temp_sql2), add = TRUE)

  cohort1 <- CohortDef$new(
    label = "Both Tags Cohort",
    tags = list(category = "primary", type = "exposure"),
    filePath = temp_sql1
  )

  cohort2 <- CohortDef$new(
    label = "One Tag Cohort",
    tags = list(category = "primary", type = "outcome"),
    filePath = temp_sql2
  )

  mock_settings <- list(
    databaseName = "test_db",
    getConnection = function() NULL,
    disconnect = function() {}
  )
  class(mock_settings) <- "ExecutionSettings"

  db_path <- file.path(temp_dir, "test.sqlite")

  manifest <- CohortManifest$new(
    cohortEntries = list(cohort1, cohort2),
    executionSettings = mock_settings,
    dbPath = db_path
  )

  # 'any' returns both
  result_any <- manifest$queryCohortsByTag(
    c("category: primary", "type: exposure"),
    match = "any"
  )
  expect_equal(nrow(result_any), 2)

  # 'all' returns only the cohort that has both tags
  result_all <- manifest$queryCohortsByTag(
    c("category: primary", "type: exposure"),
    match = "all"
  )
  expect_equal(nrow(result_all), 1)
  expect_equal(result_all$label[1], "Both Tags Cohort")
})

test_that("CohortManifest queryCohortsByIds accepts vector of IDs", {
  temp_dir <- tempfile(prefix = "picard_test_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  cohorts <- list()
  for (i in 1:3) {
    temp_sql <- tempfile(fileext = ".sql")
    writeLines("SELECT 1;", temp_sql)
    on.exit(unlink(temp_sql), add = TRUE)
    cohorts[[i]] <- CohortDef$new(
      label = paste("Cohort", i),
      tags = list(),
      filePath = temp_sql
    )
  }

  mock_settings <- list(
    databaseName = "test_db",
    getConnection = function() NULL,
    disconnect = function() {}
  )
  class(mock_settings) <- "ExecutionSettings"

  db_path <- file.path(temp_dir, "test.sqlite")

  manifest <- CohortManifest$new(
    cohortEntries = cohorts,
    executionSettings = mock_settings,
    dbPath = db_path
  )

  result <- manifest$queryCohortsByIds(c(1L, 3L))

  expect_equal(nrow(result), 2)
  expect_true(all(result$id %in% c(1L, 3L)))
})

# Database-dependent tests are skipped
test_that("createCohortTables requires executionSettings", {
  skip("Database testing not available - requires live database connection")

  temp_dir <- tempfile(prefix = "picard_test_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  temp_sql <- tempfile(fileext = ".sql")
  writeLines("SELECT 1;", temp_sql)
  on.exit(unlink(temp_sql), add = TRUE)

  cohort <- CohortDef$new(
    label = "Test",
    tags = list(),
    filePath = temp_sql
  )

  mock_settings <- list(
    databaseName = "test_db",
    getConnection = function() NULL,
    disconnect = function() {}
  )
  class(mock_settings) <- "ExecutionSettings"

  db_path <- file.path(temp_dir, "test.sqlite")

  manifest <- CohortManifest$new(
    cohortEntries = list(cohort),
    executionSettings = mock_settings,
    dbPath = db_path
  )

  # This would fail without a real database connection
  expect_error(manifest$createCohortTables())
})

test_that("executeCohortGeneration requires executionSettings", {
  skip("Database testing not available - requires live database connection")
})

test_that("retrieveCohortCounts requires executionSettings", {
  skip("Database testing not available - requires live database connection")
})

# ========== PHASE C: ADD METHODS TESTS ==========

test_that("addSqlCohort registers SQL cohort correctly", {
  temp_dir <- tempfile(prefix = "picard_test_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Create temporary SQL file
  sql_dir <- file.path(temp_dir, "sql")
  dir.create(sql_dir, recursive = TRUE)
  temp_sql <- file.path(sql_dir, "test_cohort.sql")
  writeLines("SELECT * FROM person;", temp_sql)

  # Create manifest
  db_path <- file.path(temp_dir, "cohortManifest.sqlite")
  manifest <- CohortManifest$new(dbPath = db_path)

  # Add SQL cohort
  cohort_id <- manifest$addSqlCohort(
    filePath = temp_sql,
    label = "Test SQL Cohort",
    category = "outcome",
    tags = list(type = "custom")
  )

  expect_type(cohort_id, "integer")
  expect_true(cohort_id > 0)

  # Verify it was registered
  results <- manifest$queryCohortsByIds(cohort_id)
  expect_true(!is.null(results))
  expect_equal(nrow(results), 1)
  expect_equal(results$label[1], "Test SQL Cohort")
  expect_equal(results$source_type[1], "sql")
})

test_that("addSqlCohort enforces label uniqueness", {
  temp_dir <- tempfile(prefix = "picard_test_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Create SQL files
  sql_dir <- file.path(temp_dir, "sql")
  dir.create(sql_dir, recursive = TRUE)
  sql1 <- file.path(sql_dir, "test1.sql")
  sql2 <- file.path(sql_dir, "test2.sql")
  writeLines("SELECT 1;", sql1)
  writeLines("SELECT 2;", sql2)

  db_path <- file.path(temp_dir, "cohortManifest.sqlite")
  manifest <- CohortManifest$new(dbPath = db_path)

  # Add first cohort
  manifest$addSqlCohort(filePath = sql1, label = "Unique Label", category = "outcome")

  # Try to add second cohort with same label
  expect_error(
    manifest$addSqlCohort(filePath = sql2, label = "Unique Label", category = "outcome"),
    "already in use"
  )
})

# ========== PHASE D: MANAGEMENT METHODS TESTS ==========

test_that("updateCohortDef updates cohort metadata", {
  temp_dir <- tempfile(prefix = "picard_test_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  sql_dir <- file.path(temp_dir, "sql")
  dir.create(sql_dir, recursive = TRUE)
  temp_sql <- file.path(sql_dir, "test.sql")
  writeLines("SELECT 1;", temp_sql)

  db_path <- file.path(temp_dir, "cohortManifest.sqlite")
  manifest <- CohortManifest$new(dbPath = db_path)

  # Add a cohort
  cohort_id <- manifest$addSqlCohort(
    filePath = temp_sql,
    label = "Original Label",
    category = "target"
  )

  # Update the label
  manifest$updateCohortDef(cohort_id, label = "Updated Label")

  # Verify update
  results <- manifest$queryCohortsByIds(cohort_id)
  expect_equal(results$label[1], "Updated Label")
})

test_that("deleteCohort soft-deletes cohort", {
  temp_dir <- tempfile(prefix = "picard_test_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  sql_dir <- file.path(temp_dir, "sql")
  dir.create(sql_dir, recursive = TRUE)
  temp_sql <- file.path(sql_dir, "test.sql")
  writeLines("SELECT 1;", temp_sql)

  db_path <- file.path(temp_dir, "cohortManifest.sqlite")
  manifest <- CohortManifest$new(dbPath = db_path)

  cohort_id <- manifest$addSqlCohort(
    filePath = temp_sql,
    label = "Test Cohort",
    category = "outcome"
  )

  # Delete the cohort
  manifest$deleteCohort(cohort_id)

  # Verify it's marked as deleted (soft delete)
  results <- manifest$queryCohortsByIds(cohort_id)
  expect_null(results)

  # But the database row still exists (for audit trail)
  conn <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(conn), add = TRUE)
  check <- DBI::dbGetQuery(conn, "SELECT status FROM cohort_manifest WHERE id = ?", list(cohort_id))
  expect_equal(check$status[1], "deleted")
})

test_that("hardDeleteCohort hard-deletes cohort and file", {
  temp_dir <- tempfile(prefix = "picard_test_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  sql_dir <- file.path(temp_dir, "sql")
  dir.create(sql_dir, recursive = TRUE)
  temp_sql <- file.path(sql_dir, "test.sql")
  writeLines("SELECT 1;", temp_sql)

  db_path <- file.path(temp_dir, "cohortManifest.sqlite")
  manifest <- CohortManifest$new(dbPath = db_path)

  cohort_id <- manifest$addSqlCohort(
    filePath = temp_sql,
    label = "Test Cohort",
    category = "outcome"
  )

  # Hard delete with force=TRUE to skip confirmation
  manifest$hardDeleteCohort(cohort_id, force = TRUE)

  # Verify file is deleted
  expect_false(file.exists(temp_sql))

  # Verify row is deleted from database
  conn <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(conn), add = TRUE)
  check <- DBI::dbGetQuery(conn, "SELECT * FROM cohort_manifest WHERE id = ?", list(cohort_id))
  expect_equal(nrow(check), 0)
})

test_that("syncManifest detects untracked files", {
  temp_dir <- tempfile(prefix = "picard_test_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Create directories
  sql_dir <- file.path(temp_dir, "sql")
  json_dir <- file.path(temp_dir, "json")
  dir.create(sql_dir, recursive = TRUE)
  dir.create(json_dir, recursive = TRUE)

  # Create an untracked SQL file
  untracked_sql <- file.path(sql_dir, "untracked.sql")
  writeLines("SELECT 1;", untracked_sql)

  db_path <- file.path(temp_dir, "cohortManifest.sqlite")
  manifest <- CohortManifest$new(dbPath = db_path)

  # Run sync
  untracked <- manifest$syncManifest()

  # Should detect the untracked file
  expect_true(!is.null(untracked))
  expect_true(nrow(untracked) > 0)
  expect_true(any(grepl("untracked.sql", untracked$path)))
})

test_that("statusReport generates summary tibble", {
  temp_dir <- tempfile(prefix = "picard_test_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  sql_dir <- file.path(temp_dir, "sql")
  dir.create(sql_dir, recursive = TRUE)
  temp_sql <- file.path(sql_dir, "test.sql")
  writeLines("SELECT 1;", temp_sql)

  db_path <- file.path(temp_dir, "cohortManifest.sqlite")
  manifest <- CohortManifest$new(dbPath = db_path)

  # Add a cohort
  manifest$addSqlCohort(
    filePath = temp_sql,
    label = "Test Cohort",
    category = "target"
  )

  # Generate report
  report <- manifest$statusReport()

  expect_true(!is.null(report))
  expect_true(nrow(report) == 1)
  expect_true("label" %in% names(report))
})

test_that("print method displays manifest summary", {
  temp_dir <- tempfile(prefix = "picard_test_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  db_path <- file.path(temp_dir, "cohortManifest.sqlite")
  manifest <- CohortManifest$new(dbPath = db_path)

  # print() should not error
  expect_silent(capture.output(print(manifest)))
})

test_that("tabulateManifest returns correct schema columns", {
  temp_dir <- tempfile(prefix = "picard_test_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  sql_dir <- file.path(temp_dir, "sql")
  dir.create(sql_dir, recursive = TRUE)
  temp_sql <- file.path(sql_dir, "test.sql")
  writeLines("SELECT 1;", temp_sql)

  db_path <- file.path(temp_dir, "cohortManifest.sqlite")
  manifest <- CohortManifest$new(dbPath = db_path)

  manifest$addSqlCohort(
    filePath = temp_sql,
    label = "Test Cohort",
    category = "outcome"
  )

  # Get tabulated manifest
  tab <- manifest$tabulateManifest()

  # Check for new schema columns
  expected_cols <- c("id", "label", "category", "source_type", "file_path", "hash")
  for (col in expected_cols) {
    expect_true(col %in% names(tab), info = paste("Missing column:", col))
  }

  # Old schema columns should NOT be present
  old_cols <- c("filePath", "cohortType", "timestamp")
  for (col in old_cols) {
    expect_false(col %in% names(tab), info = paste("Old column still present:", col))
  }
})
