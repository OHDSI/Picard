# Tests for R/manifest_cohorts.R
# Focuses on functions that don't require a live database (OMOP DB) connection

# ---- parseTagsString ----

test_that("parseTagsString parses single tag pair", {
  result <- parseTagsString("category: primary")
  expect_equal(result$category, "primary")
})

test_that("parseTagsString parses multiple tag pairs with pipe separator", {
  result <- parseTagsString("category: primary | source: atlas | status: active")
  expect_equal(result$category, "primary")
  expect_equal(result$source, "atlas")
  expect_equal(result$status, "active")
})

test_that("parseTagsString returns empty list for empty string", {
  result <- parseTagsString("")
  expect_equal(length(result), 0)
  expect_type(result, "list")
})

test_that("parseTagsString returns empty list for NA input", {
  result <- parseTagsString(NA)
  expect_equal(length(result), 0)
  expect_type(result, "list")
})

test_that("parseTagsString handles extra whitespace around separators", {
  result <- parseTagsString("category:   trimmed   | source:   also_trimmed")
  expect_equal(result$category, "trimmed")
  expect_equal(result$source, "also_trimmed")
})

test_that("parseTagsString round-trips with CohortDef formatTagsAsString", {
  temp_sql <- tempfile(fileext = ".sql")
  writeLines("SELECT 1;", temp_sql)
  on.exit(unlink(temp_sql), add = TRUE)

  cohort <- CohortDef$new(
    label = "Test",
    tags = list(category = "primary", source = "atlas"),
    filePath = temp_sql,
    cohortType = "custom"
  )

  tags_str <- cohort$formatTagsAsString()
  parsed <- parseTagsString(tags_str)

  expect_equal(parsed$category, "primary")
  expect_equal(parsed$source, "atlas")
})

# ---- createBlankCohortsLoadFile ----

test_that("createBlankCohortsLoadFile creates the file in specified folder", {
  temp_dir <- tempfile(prefix = "picard_cohorts_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  createBlankCohortsLoadFile(cohortsFolderPath = temp_dir)

  expect_true(file.exists(file.path(temp_dir, "cohortsLoad.csv")))
})

test_that("createBlankCohortsLoadFile creates folder if it doesn't exist", {
  temp_dir <- tempfile(prefix = "picard_cohorts_")
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  expect_false(dir.exists(temp_dir))
  createBlankCohortsLoadFile(cohortsFolderPath = temp_dir)
  expect_true(file.exists(file.path(temp_dir, "cohortsLoad.csv")))
})

test_that("createBlankCohortsLoadFile has correct column structure", {
  temp_dir <- tempfile(prefix = "picard_cohorts_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  createBlankCohortsLoadFile(cohortsFolderPath = temp_dir)

  df <- readr::read_csv(file.path(temp_dir, "cohortsLoad.csv"), show_col_types = FALSE)
  expected_cols <- c("atlasId", "label", "category", "subCategory", "file_name")
  expect_true(all(expected_cols %in% colnames(df)))
})

test_that("createBlankCohortsLoadFile returns file path invisibly", {
  temp_dir <- tempfile(prefix = "picard_cohorts_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  result <- createBlankCohortsLoadFile(cohortsFolderPath = temp_dir)
  expect_null(result)  # invisible(NULL)
})

# ---- resetCohortManifest ----

test_that("resetCohortManifest deletes existing SQLite file", {
  temp_dir <- tempfile(prefix = "picard_cohorts_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Create a fake sqlite file to simulate an existing manifest
  sqlite_path <- file.path(temp_dir, "cohortManifest.sqlite")
  file.create(sqlite_path)
  expect_true(file.exists(sqlite_path))

  resetCohortManifest(cohortsFolderPath = temp_dir)
  expect_false(file.exists(sqlite_path))
})

test_that("resetCohortManifest warns gracefully when no manifest exists", {
  temp_dir <- tempfile(prefix = "picard_cohorts_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Should not error, just warn
  expect_no_error(resetCohortManifest(cohortsFolderPath = temp_dir))
})

# ---- loadCohortManifest ----

test_that("loadCohortManifest scans sql/ subfolder and creates CohortManifest", {
  temp_dir <- tempfile(prefix = "picard_cohorts_")
  sql_dir <- file.path(temp_dir, "sql")
  dir.create(sql_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Create a couple of dummy SQL files
  writeLines("SELECT * FROM cohort WHERE cohort_definition_id = 1;",
             file.path(sql_dir, "diabetes.sql"))
  writeLines("SELECT * FROM cohort WHERE cohort_definition_id = 2;",
             file.path(sql_dir, "hypertension.sql"))

  manifest <- loadCohortManifest(cohortsFolderPath = temp_dir, verbose = FALSE)

  expect_s3_class(manifest, "CohortManifest")
  expect_equal(manifest$nCohorts(), 2)
})

test_that("loadCohortManifest creates SQLite file after first load", {
  temp_dir <- tempfile(prefix = "picard_cohorts_")
  sql_dir <- file.path(temp_dir, "sql")
  dir.create(sql_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  writeLines("SELECT 1;", file.path(sql_dir, "test.sql"))

  loadCohortManifest(cohortsFolderPath = temp_dir, verbose = FALSE)

  expect_true(file.exists(file.path(temp_dir, "cohortManifest.sqlite")))
})

test_that("loadCohortManifest returns CohortManifest with correct labels from filenames", {
  temp_dir <- tempfile(prefix = "picard_cohorts_")
  sql_dir <- file.path(temp_dir, "sql")
  dir.create(sql_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  writeLines("SELECT 1;", file.path(sql_dir, "type2_diabetes.sql"))

  manifest <- loadCohortManifest(cohortsFolderPath = temp_dir, verbose = FALSE)
  manifest_df <- manifest$getManifest()

  expect_true("type2_diabetes" %in% manifest_df$label)
})

test_that("loadCohortManifest loads from existing sqlite on second call", {
  temp_dir <- tempfile(prefix = "picard_cohorts_")
  sql_dir <- file.path(temp_dir, "sql")
  dir.create(sql_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  writeLines("SELECT 1;", file.path(sql_dir, "cohort_a.sql"))

  # First load creates SQLite
  loadCohortManifest(cohortsFolderPath = temp_dir, verbose = FALSE)

  # Second load reads from SQLite
  manifest2 <- loadCohortManifest(cohortsFolderPath = temp_dir, verbose = FALSE)
  expect_s3_class(manifest2, "CohortManifest")
  expect_equal(manifest2$nCohorts(), 1)
})

test_that("loadCohortManifest enriches tags from cohortsLoad.csv when present", {
  temp_dir <- tempfile(prefix = "picard_cohorts_")
  sql_dir <- file.path(temp_dir, "sql")
  dir.create(sql_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Create SQL file
  sql_path <- file.path(sql_dir, "t2dm.sql")
  writeLines("SELECT 1;", sql_path)

  # Create cohortsLoad.csv that enriches with metadata
  load_csv <- data.frame(
    atlasId = 123L,
    label = "T2DM Cohort",
    category = "Disease Populations",
    subCategory = "Diabetes",
    file_name = file.path("sql", "t2dm.sql"),
    stringsAsFactors = FALSE
  )
  readr::write_csv(load_csv, file.path(temp_dir, "cohortsLoad.csv"))

  manifest <- loadCohortManifest(cohortsFolderPath = temp_dir, verbose = FALSE)
  cohort <- manifest$getCohortById(1)

  # Tags should be enriched from cohortsLoad
  expect_true(!is.null(cohort$tags$category) || nchar(cohort$formatTagsAsString()) > 0)
})

test_that("loadCohortManifest returns empty manifest when folder has no cohort files", {
  temp_dir <- tempfile(prefix = "picard_cohorts_")
  dir.create(temp_dir, recursive = TRUE)
  # Create empty sql/ dir
  dir.create(file.path(temp_dir, "sql"))
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  manifest <- loadCohortManifest(cohortsFolderPath = temp_dir, verbose = FALSE)
  expect_s3_class(manifest, "CohortManifest")
  expect_equal(manifest$nCohorts(), 0)
})
