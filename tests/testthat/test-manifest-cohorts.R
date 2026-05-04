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
    category = "target",
    sourceType = "sql",
    tags = list(category = "primary", source = "atlas"),
    filePath = temp_sql
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

test_that("resetCohortManifest deletes SQLite file at manifest scope", {
  temp_dir <- tempfile(prefix = "picard_cohorts_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Create a real SQLite manifest
  sqlite_path <- file.path(temp_dir, "cohortManifest.sqlite")
  manifest <- CohortManifest$new(dbPath = sqlite_path)
  expect_true(file.exists(sqlite_path))

  resetCohortManifest(
    manifest = manifest,
    cohortsFolderPath = temp_dir,
    scope = "manifest",
    confirm = FALSE
  )
  expect_false(file.exists(sqlite_path))
})

# ---- loadCohortManifest ----

# loadCohortManifest now requires an existing SQLite (created by initCohortManifest);
# the old auto-scan behaviour has been removed.

test_that("loadCohortManifest returns CohortManifest from existing SQLite", {
  temp_dir <- tempfile(prefix = "picard_cohorts_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Create the manifest first (as initCohortManifest would)
  sqlite_path <- file.path(temp_dir, "cohortManifest.sqlite")
  CohortManifest$new(dbPath = sqlite_path)

  manifest <- loadCohortManifest(cohortsFolderPath = temp_dir, verbose = FALSE)

  expect_true(inherits(manifest, "CohortManifest"))
  expect_equal(manifest$nCohorts(), 0)
})

test_that("loadCohortManifest errors when no SQLite exists", {
  temp_dir <- tempfile(prefix = "picard_cohorts_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  expect_error(
    loadCohortManifest(cohortsFolderPath = temp_dir, verbose = FALSE),
    "not found"
  )
})

test_that("loadCohortManifest round-trips cohorts added before reload", {
  temp_dir <- tempfile(prefix = "picard_cohorts_")
  sql_dir <- file.path(temp_dir, "sql")
  dir.create(sql_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  sqlite_path <- file.path(temp_dir, "cohortManifest.sqlite")
  cm1 <- CohortManifest$new(dbPath = sqlite_path)

  writeLines("SELECT 1;", file.path(sql_dir, "cohort_a.sql"))
  cm1$addSqlCohort(filePath = file.path(sql_dir, "cohort_a.sql"), label = "Cohort A", category = "target")

  # Load from the existing SQLite
  cm2 <- loadCohortManifest(cohortsFolderPath = temp_dir, verbose = FALSE)
  expect_equal(cm2$nCohorts(), 1)
  expect_equal(cm2$getCohortById(1L)$label, "Cohort A")
})
