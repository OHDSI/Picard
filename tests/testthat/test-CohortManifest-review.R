# Testing: tabulateManifest returns active cohorts from seeded manifest.
testthat::test_that("tabulateManifest returns active rows", {
  setup <- cm_test_seed_manifest_for_queries("review-tabulate-active")
  manifest <- setup$manifest

  out <- manifest$tabulateManifest(filter = "active")

  testthat::expect_s3_class(out, "tbl_df")
  testthat::expect_true(nrow(out) >= 5)
  testthat::expect_true(all(out$status == "active"))
})

# Testing: tabulateManifest respects deleted and stale filters.
testthat::test_that("tabulateManifest supports deleted and stale filters", {
  setup <- cm_test_seed_manifest_for_queries("review-tabulate-filters")
  manifest <- setup$manifest

  base <- manifest$queryCohortsByLabel("Custom SQL Cohort", matchType = "exact")
  manifest$deleteCohort(id = as.integer(base$id[[1]]), confirm = TRUE)

  conn <- DBI::dbConnect(RSQLite::SQLite(), manifest$getDbPath())
  on.exit(DBI::dbDisconnect(conn), add = TRUE)
  DBI::dbExecute(conn, "UPDATE cohort_manifest SET status = 'stale' WHERE label = 'All-Cause Death'")

  deleted <- manifest$tabulateManifest(filter = "deleted")
  stale <- manifest$tabulateManifest(filter = "stale")

  testthat::expect_true(any(deleted$label == "Custom SQL Cohort"))
  testthat::expect_true(any(stale$label == "All-Cause Death"))
})

# Testing: reviewDependentCohorts summarizes derived dependency metadata.
testthat::test_that("reviewDependentCohorts returns dependent cohort summary", {
  setup <- cm_test_seed_manifest_for_builders("review-dependent")
  manifest <- setup$manifest

  out <- manifest$reviewDependentCohorts()

  testthat::expect_s3_class(out, "tbl_df")
  testthat::expect_true(any(out$label == "Eligible_With_Exclusions"))
  testthat::expect_true(any(out$cohort_type == "custom_derived"))
})

# Testing: reviewStaleCohorts returns NULL when no stale cohorts are present.
testthat::test_that("reviewStaleCohorts returns NULL when none stale", {
  setup <- cm_test_seed_manifest_for_queries("review-stale-none")
  manifest <- setup$manifest

  out <- manifest$reviewStaleCohorts()

  testthat::expect_null(out)
})

# Testing: reviewStaleCohorts returns stale cohort rows after status update.
testthat::test_that("reviewStaleCohorts returns stale rows", {
  setup <- cm_test_seed_manifest_for_queries("review-stale-rows")
  manifest <- setup$manifest

  conn <- DBI::dbConnect(RSQLite::SQLite(), manifest$getDbPath())
  on.exit(DBI::dbDisconnect(conn), add = TRUE)
  DBI::dbExecute(conn, "UPDATE cohort_manifest SET status = 'stale' WHERE label = 'Type 2 Diabetes'")

  out <- manifest$reviewStaleCohorts()

  testthat::expect_s3_class(out, "tbl_df")
  testthat::expect_true(any(out$label == "Type 2 Diabetes"))
})

# Testing: statusReport returns active manifest rows as a tibble.
testthat::test_that("statusReport returns report tibble", {
  setup <- cm_test_seed_manifest_for_queries("review-status-report")
  manifest <- setup$manifest

  out <- manifest$statusReport()

  testthat::expect_s3_class(out, "tbl_df")
  testthat::expect_true(nrow(out) >= 5)
})

# Testing: print returns self invisibly for chained inspection.
testthat::test_that("print returns manifest self", {
  setup <- cm_test_seed_manifest_for_queries("review-print")
  manifest <- setup$manifest

  out <- manifest$print()

  testthat::expect_identical(out, manifest)
})
