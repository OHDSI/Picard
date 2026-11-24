# Covers validateTaskIndices() and taskExportPrefix(), the pair that prevents two task
# folders from merging to the same export filename (#151).

testthat::test_that("taskExportPrefix uses a leading numeric segment as-is", {
  testthat::expect_equal(taskExportPrefix("01_demographics"), "01")
  testthat::expect_equal(taskExportPrefix("00_buildCohorts"), "00")
  testthat::expect_equal(taskExportPrefix("12_baseline_medicines"), "12")
})

testthat::test_that("taskExportPrefix slugifies a name with no numeric prefix", {
  testthat::expect_equal(taskExportPrefix("demographics"), "demographics")
  testthat::expect_equal(taskExportPrefix("my_task"), "my-task")
  testthat::expect_equal(taskExportPrefix("odd..name"), "odd-name")
})

testthat::test_that("taskExportPrefix is vectorized", {
  testthat::expect_equal(
    taskExportPrefix(c("01_a", "02_b", "notnumbered")),
    c("01", "02", "notnumbered")
  )
})

testthat::test_that("unique indices pass with no duplicates or warnings", {
  res <- validateTaskIndices(c("01_demographics.R", "02_baseline.R", "03_outcomes.R"))

  testthat::expect_length(res$duplicates, 0)
  testthat::expect_length(res$unprefixed, 0)
  testthat::expect_equal(res$total, 3L)
})

testthat::test_that("a shared index is reported with both offending names", {
  res <- validateTaskIndices(c("01_demographics.R", "01_demo.R", "02_baseline.R"))

  testthat::expect_named(res$duplicates, "01")
  testthat::expect_equal(res$duplicates[["01"]], c("01_demo", "01_demographics"))
  testthat::expect_length(res$unprefixed, 0)
})

testthat::test_that("several distinct collisions are each reported", {
  res <- validateTaskIndices(c("01_a.R", "01_b.R", "02_c.R", "02_d.R", "03_e.R"))

  testthat::expect_length(res$duplicates, 2)
  testthat::expect_setequal(names(res$duplicates), c("01", "02"))
})

testthat::test_that("differently padded indices do not collide", {
  # "1" and "01" are different prefixes, so the merged filenames differ
  res <- validateTaskIndices(c("1_a.R", "01_b.R"))

  testthat::expect_length(res$duplicates, 0)
})

testthat::test_that("a name without a numeric prefix warns but does not collide", {
  res <- validateTaskIndices(c("01_demographics.R", "demographics.R"))

  testthat::expect_length(res$duplicates, 0)
  testthat::expect_equal(res$unprefixed, "demographics")
})

testthat::test_that("two unprefixed names that slugify alike do collide", {
  res <- validateTaskIndices(c("my_task.R", "my.task.R"))

  testthat::expect_named(res$duplicates, "my-task")
  testthat::expect_length(res$unprefixed, 2)
})

testthat::test_that("the extension is ignored and stripped from the report", {
  res <- validateTaskIndices(c("01_demographics.R", "01_demo.r"))

  testthat::expect_equal(res$duplicates[["01"]], c("01_demo", "01_demographics"))
})

testthat::test_that("folder names (no extension) are handled the same way", {
  res <- validateTaskIndices(c("00_buildCohorts", "01_demographics", "01_demo"))

  testthat::expect_named(res$duplicates, "01")
  testthat::expect_equal(res$total, 3L)
})

testthat::test_that("an empty input is a no-op rather than an error", {
  res <- validateTaskIndices(character(0))

  testthat::expect_length(res$duplicates, 0)
  testthat::expect_equal(res$total, 0L)
})

testthat::test_that("validateTaskIndices rejects a non-character input", {
  testthat::expect_error(validateTaskIndices(1:3))
  testthat::expect_error(validateTaskIndices(c("01_a", NA_character_)))
})
