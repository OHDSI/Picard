# Testing: queryCohortsByIds returns matching active rows for supplied IDs.
testthat::test_that("queryCohortsByIds returns matching rows", {
  setup <- cm_test_seed_manifest_for_queries("query-by-ids")
  manifest <- setup$manifest

  ckd <- manifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")
  t2d <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")

  out <- manifest$queryCohortsByIds(as.integer(c(ckd$id[[1]], t2d$id[[1]])))

  testthat::expect_s3_class(out, "tbl_df")
  testthat::expect_equal(sort(out$label), sort(c("Chronic Kidney Disease", "Type 2 Diabetes")))
})

# Testing: queryCohortsByTag supports any/all semantics for parsed name:value tags.
testthat::test_that("queryCohortsByTag supports any and all matching", {
  setup <- cm_test_seed_manifest_for_queries("query-by-tag")
  manifest <- setup$manifest

  any_match <- manifest$queryCohortsByTag(c("group: base", "domain: bleed"), match = "any")
  all_match <- manifest$queryCohortsByTag(c("group: base", "domain: bleed"), match = "all")

  testthat::expect_true(nrow(any_match) >= nrow(all_match))
  testthat::expect_equal(all_match$label[[1]], "Major Bleeding Outcome")
})

# Testing: queryCohortsByLabel supports exact and pattern matching.
testthat::test_that("queryCohortsByLabel supports exact and pattern", {
  setup <- cm_test_seed_manifest_for_queries("query-by-label")
  manifest <- setup$manifest

  exact <- manifest$queryCohortsByLabel("All-Cause Death", matchType = "exact")
  pattern <- manifest$queryCohortsByLabel("Outcome", matchType = "pattern")

  testthat::expect_equal(nrow(exact), 1)
  testthat::expect_equal(exact$label[[1]], "All-Cause Death")
  testthat::expect_true(any(grepl("Outcome", pattern$label, fixed = TRUE)))
})

# Testing: queryCohortsByCategory supports exact and pattern category search.
testthat::test_that("queryCohortsByCategory supports exact and pattern", {
  setup <- cm_test_seed_manifest_for_queries("query-by-category")
  manifest <- setup$manifest

  exact <- manifest$queryCohortsByCategory("Comparator", matchType = "exact")
  pattern <- manifest$queryCohortsByCategory("Out", matchType = "pattern")

  testthat::expect_equal(exact$label[[1]], "Type 2 Diabetes")
  testthat::expect_true(all(grepl("Out", pattern$category)))
})

# Testing: queryCohortsByTagName returns rows whose JSON tags include the requested key.
testthat::test_that("queryCohortsByTagName finds cohorts with tag key", {
  setup <- cm_test_seed_manifest_for_queries("query-by-tag-name")
  manifest <- setup$manifest

  out <- manifest$queryCohortsByTagName("domain")

  testthat::expect_s3_class(out, "tbl_df")
  testthat::expect_true(nrow(out) >= 4)
})

# Testing: getCohortById retrieves a CohortDef object for an existing ID.
testthat::test_that("getCohortById returns CohortDef", {
  setup <- cm_test_seed_manifest_for_queries("get-by-id")
  manifest <- setup$manifest

  ckd <- manifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")
  cohort <- manifest$getCohortById(as.integer(ckd$id[[1]]))

  testthat::expect_s3_class(cohort, "CohortDef")
  testthat::expect_equal(cohort$label, "Chronic Kidney Disease")
})

# Testing: getCohortsByTag returns matching CohortDef objects for any/all tag logic.
testthat::test_that("getCohortsByTag returns CohortDef list", {
  setup <- cm_test_seed_manifest_for_queries("get-by-tag")
  manifest <- setup$manifest

  any_match <- manifest$getCohortsByTag(c("group: base", "domain: mortality"), match = "any")
  all_match <- manifest$getCohortsByTag(c("group: base", "domain: mortality"), match = "all")

  testthat::expect_true(length(any_match) >= length(all_match))
  testthat::expect_equal(all_match[[1]]$label, "All-Cause Death")
})

# Testing: getCohortsByLabel returns CohortDef objects for exact and pattern label matching.
testthat::test_that("getCohortsByLabel supports exact and pattern", {
  setup <- cm_test_seed_manifest_for_queries("get-by-label")
  manifest <- setup$manifest

  exact <- manifest$getCohortsByLabel("Type 2 Diabetes", matchType = "exact")
  pattern <- manifest$getCohortsByLabel("Outcome", matchType = "pattern")

  testthat::expect_equal(length(exact), 1)
  testthat::expect_equal(exact[[1]]$label, "Type 2 Diabetes")
  testthat::expect_true(length(pattern) >= 2)
})

# Testing: nCohorts reflects seeded active cohorts in manifest.
testthat::test_that("nCohorts returns seeded cohort count", {
  setup <- cm_test_seed_manifest_for_queries("ncohorts")
  manifest <- setup$manifest

  testthat::expect_equal(manifest$nCohorts(), 5)
})
