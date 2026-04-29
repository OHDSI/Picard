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
    filePath = temp_sql,
    cohortType = "custom"
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
    filePath = temp_sql,
    cohortType = "custom"
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
    filePath = temp_sql,
    cohortType = "custom"
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
    filePath = temp_sql,
    cohortType = "custom"
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
      filePath = temp_sql,
      cohortType = "custom"
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
    filePath = temp_sql1,
    cohortType = "custom"
  )

  cohort2 <- CohortDef$new(
    label = "Secondary Cohort",
    tags = list(category = "secondary"),
    filePath = temp_sql2,
    cohortType = "custom"
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
    filePath = temp_sql1,
    cohortType = "custom"
  )

  cohort2 <- CohortDef$new(
    label = "One Tag Cohort",
    tags = list(category = "primary", type = "outcome"),
    filePath = temp_sql2,
    cohortType = "custom"
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
      filePath = temp_sql,
      cohortType = "custom"
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
    filePath = temp_sql,
    cohortType = "custom"
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

test_that("generateCohorts requires executionSettings", {
  skip("Database testing not available - requires live database connection")
})

test_that("retrieveCohortCounts requires executionSettings", {
  skip("Database testing not available - requires live database connection")
})
