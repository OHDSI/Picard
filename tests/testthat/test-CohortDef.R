test_that("CohortDef initializes correctly with SQL file", {
  # Create a temporary SQL file
  temp_sql <- tempfile(fileext = ".sql")
  writeLines("SELECT * FROM cohort WHERE id = 1;", temp_sql)
  on.exit(unlink(temp_sql))

  # Initialize CohortDef
  cohort <- CohortDef$new(
    label = "Test Cohort",
    category = "target",
    sourceType = "sql",
    tags = list(category = "primary"),
    filePath = temp_sql
  )

  # Test initialization
  expect_equal(cohort$label, "Test Cohort")
  expect_equal(cohort$getId(), NA_integer_)
  expect_true(nchar(cohort$getHash()) > 0)
  expect_match(cohort$getFilePath(), "sql$")
})



test_that("CohortDef formatTagsAsString works correctly", {
  temp_sql <- tempfile(fileext = ".sql")
  writeLines("SELECT 1;", temp_sql)
  on.exit(unlink(temp_sql))

  cohort <- CohortDef$new(
    label = "Tagged Cohort",
    category = "target",
    sourceType = "sql",
    tags = list(category = "primary", source = "atlas"),
    filePath = temp_sql
  )

  tags_str <- cohort$formatTagsAsString()
  expect_true(grepl("category: primary", tags_str))
  expect_true(grepl("source: atlas", tags_str))
  expect_true(grepl("\\|", tags_str))  # Should have pipe separator
})

test_that("CohortDef throws error for non-existent file", {
  expect_error(
    CohortDef$new(
      label = "Bad Cohort",
      category = "target",
      sourceType = "sql",
      tags = list(),
      filePath = "/path/to/nonexistent/file.sql"
    )
  )
})

test_that("CohortDef setId and getId work correctly", {
  temp_sql <- tempfile(fileext = ".sql")
  writeLines("SELECT 1;", temp_sql)
  on.exit(unlink(temp_sql))

  cohort <- CohortDef$new(
    label = "ID Test",
    category = "target",
    sourceType = "sql",
    tags = list(),
    filePath = temp_sql
  )

  cohort$setId(42L)
  expect_equal(cohort$getId(), 42L)
})

test_that("CohortDef label active binding works", {
  temp_sql <- tempfile(fileext = ".sql")
  writeLines("SELECT 1;", temp_sql)
  on.exit(unlink(temp_sql))

  cohort <- CohortDef$new(
    label = "Original",
    category = "target",
    sourceType = "sql",
    tags = list(),
    filePath = temp_sql
  )

  expect_equal(cohort$label, "Original")

  cohort$label <- "Modified"
  expect_equal(cohort$label, "Modified")
})

test_that("CohortDef tags active binding works", {
  temp_sql <- tempfile(fileext = ".sql")
  writeLines("SELECT 1;", temp_sql)
  on.exit(unlink(temp_sql))

  cohort <- CohortDef$new(
    label = "Test",
    category = "target",
    sourceType = "sql",
    tags = list(original = "tag"),
    filePath = temp_sql
  )

  expect_equal(cohort$tags$original, "tag")

  cohort$tags <- list(new = "tags", another = "one")
  expect_equal(cohort$tags$new, "tags")
  expect_equal(cohort$tags$another, "one")
})
