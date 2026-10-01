# Testing: addCaprCohort registers a Capr-based cohort with capr source type.
testthat::test_that("addCaprCohort registers Capr cohort", {
  setup <- cm_test_new_manifest("build-add-capr")
  manifest <- setup$manifest

  cm_test_add_capr_cohort(
    manifest = manifest,
    label = "Capr Cohort",
    category = "Target",
    tags = list(source = "capr")
  )

  cm_test_assert_cohort_registered(
    manifest = manifest,
    label = "Capr Cohort",
    expected_source_type = "capr"
  )
})

# Testing: buildUnionCohort registers a derived union cohort from entry inputs.
testthat::test_that("buildUnionCohort entry route registers derived cohort", {
  setup <- cm_test_seed_manifest_for_builders("build-union")
  manifest <- setup$manifest

  parents <- manifest$queryCohortsByLabel(
    labels = c("Chronic Kidney Disease", "Type 2 Diabetes"),
    matchType = "exact"
  )

  manifest$buildUnionCohort(
    label = "CKD_or_T2D",
    category = "Derived Cohorts",
    cohortEntries = parents
  )

  cm_test_assert_cohort_registered(manifest, "CKD_or_T2D", expected_source_type = "derived", expected_cohort_type = "union")
})

# Testing: buildSubsetCohortTemporal registers subset cohort from base/filter entry rows.
testthat::test_that("buildSubsetCohortTemporal entry route registers subset", {
  setup <- cm_test_seed_manifest_for_builders("build-subset")
  manifest <- setup$manifest

  base <- manifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")
  filter <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")

  start_window <- createSubsetStartWindow(
    subsetCohortWindowAnchor = "cohort_start_date",
    startDays = -365,
    endDays = 0,
    baseCohortWindowAnchor = "cohort_start_date"
  )

  manifest$buildSubsetCohortTemporal(
    label = "CKD_With_Prior_T2D",
    category = "Derived Cohorts",
    baseCohortEntry = base,
    filterCohortEntry = filter,
    startWindow = start_window
  )

  cm_test_assert_cohort_registered(manifest, "CKD_With_Prior_T2D", expected_source_type = "derived", expected_cohort_type = "subset")
})

# Testing: buildComplementCohort registers a complement cohort from entry inputs.
testthat::test_that("buildComplementCohort entry route registers complement", {
  setup <- cm_test_seed_manifest_for_builders("build-complement")
  manifest <- setup$manifest

  population <- manifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")
  exclude <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")

  manifest$buildComplementCohort(
    label = "CKD_Without_T2D",
    category = "Derived Cohorts",
    populationCohortEntry = population,
    excludeCohortEntries = exclude
  )

  cm_test_assert_cohort_registered(manifest, "CKD_Without_T2D", expected_source_type = "derived", expected_cohort_type = "complement")
})

# Testing: buildCompositeCohort registers a composite cohort from criteria entry rows.
testthat::test_that("buildCompositeCohort entry route registers composite", {
  setup <- cm_test_seed_manifest_for_builders("build-composite")
  manifest <- setup$manifest

  criteria <- manifest$queryCohortsByLabel(
    labels = c("Chronic Kidney Disease", "Type 2 Diabetes"),
    matchType = "exact"
  )

  manifest$buildCompositeCohort(
    label = "CKD_and_T2D_Composite",
    category = "Derived Cohorts",
    criteriaCohortEntries = criteria,
    minEventCount = 2L,
    eventSelection = "First"
  )

  cm_test_assert_cohort_registered(manifest, "CKD_and_T2D_Composite", expected_source_type = "derived", expected_cohort_type = "composite")
})

# Testing: buildCompositeCohort warns when minEventCount is not supplied and keeps the default of 1.
testthat::test_that("buildCompositeCohort warns when minEventCount is missing", {
  setup <- cm_test_seed_manifest_for_builders("build-composite-default")
  manifest <- setup$manifest

  criteria <- manifest$queryCohortsByLabel(
    labels = c("Chronic Kidney Disease", "Type 2 Diabetes"),
    matchType = "exact"
  )

  testthat::expect_warning(
    manifest$buildCompositeCohort(
      label = "CKD_and_T2D_Default",
      category = "Derived Cohorts",
      criteriaCohortEntries = criteria
    ),
    "minEventCount = 2L"
  )

  row <- cm_test_get_manifest_row(manifest, "CKD_and_T2D_Default")
  rule <- jsonlite::fromJSON(row$dependency_rule[[1]])
  testthat::expect_equal(as.integer(rule$minEventCount), 1L)

  testthat::expect_no_warning(
    manifest$buildCompositeCohort(
      label = "CKD_and_T2D_Explicit",
      category = "Derived Cohorts",
      criteriaCohortEntries = criteria,
      minEventCount = 2L
    )
  )

  testthat::expect_error(
    manifest$buildCompositeCohort(
      label = "CKD_and_T2D_TooMany",
      category = "Derived Cohorts",
      criteriaCohortEntries = criteria,
      minEventCount = 3L
    )
  )
})

# Testing: buildDemographicCohort registers demographic subset from base cohort entry.
testthat::test_that("buildDemographicCohort entry route registers subset", {
  setup <- cm_test_seed_manifest_for_builders("build-demographic")
  manifest <- setup$manifest

  base <- manifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")

  manifest$buildDemographicCohort(
    label = "CKD_Males_40_to_75",
    category = "Derived Cohorts",
    baseCohortEntry = base,
    minAge = 40L,
    maxAge = 75L,
    genderConceptIds = c(8507)
  )

  cm_test_assert_cohort_registered(manifest, "CKD_Males_40_to_75", expected_source_type = "derived", expected_cohort_type = "subset")
})

# Testing: buildStratifiedCohorts registers stratum cohorts plus Unclassified.
testthat::test_that("buildStratifiedCohorts creates named strata and unclassified", {
  setup <- cm_test_seed_manifest_for_builders("build-stratified")
  manifest <- setup$manifest

  base <- manifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")
  strata <- list(
    Female = list(genderConceptIds = c(8532)),
    Male = list(genderConceptIds = c(8507))
  )

  ids <- manifest$buildStratifiedCohorts(
    baseCohortEntry = base,
    strata = strata,
    labelPrefix = "CKD",
    category = "Derived Cohorts"
  )

  testthat::expect_true("CKD - Female" %in% names(ids))
  testthat::expect_true("CKD - Male" %in% names(ids))
  testthat::expect_true("CKD - Unclassified" %in% names(ids))
})

# Testing: buildOPriorT registers o-prior derived cohort from outcome/target entries.
testthat::test_that("buildOPriorT entry route registers oprior cohort", {
  setup <- cm_test_seed_manifest_for_builders("build-opriort")
  manifest <- setup$manifest

  outcome <- manifest$queryCohortsByLabel("Major Bleeding Outcome", matchType = "exact")
  target <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")

  manifest$buildOPriorT(
    label = "Outcome_Prior_Target",
    category = "Derived Cohorts",
    outcomeCohortEntry = outcome,
    targetCohortEntry = target,
    mode = "prior",
    priorTimeWindowDays = 30L
  )

  cm_test_assert_cohort_registered(manifest, "Outcome_Prior_Target", expected_source_type = "derived", expected_cohort_type = "oprior")
})

# Testing: buildTPriorO registers t-prior derived cohort from target/outcome entries.
testthat::test_that("buildTPriorO entry route registers tprior cohort", {
  setup <- cm_test_seed_manifest_for_builders("build-tprioro")
  manifest <- setup$manifest

  target <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")
  outcome <- manifest$queryCohortsByLabel("Major Bleeding Outcome", matchType = "exact")

  manifest$buildTPriorO(
    label = "Target_Prior_Outcome",
    category = "Derived Cohorts",
    targetCohortEntry = target,
    outcomeCohortEntry = outcome,
    mode = "prior",
    priorTimeWindowDays = 30L
  )

  cm_test_assert_cohort_registered(manifest, "Target_Prior_Outcome", expected_source_type = "derived", expected_cohort_type = "tprior")
})

# Testing: buildCensorCohort registers censor cohort from target/censor entries.
testthat::test_that("buildCensorCohort entry route registers censor cohort", {
  setup <- cm_test_seed_manifest_for_builders("build-censor")
  manifest <- setup$manifest

  target <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")
  censor <- manifest$queryCohortsByLabel("All-Cause Death", matchType = "exact")

  manifest$buildCensorCohort(
    label = "T2D_Censored_At_Death",
    category = "Derived Cohorts",
    targetCohortEntry = target,
    censorCohortEntry = censor
  )

  cm_test_assert_cohort_registered(manifest, "T2D_Censored_At_Death", expected_source_type = "derived", expected_cohort_type = "censor")
})

# Purpose: Mark cohorts 'stale' directly in the manifest sqlite.
cm_test_mark_stale <- function(manifest, ids) {
  conn <- DBI::dbConnect(RSQLite::SQLite(), manifest$getDbPath())
  on.exit(DBI::dbDisconnect(conn))
  for (id in ids) {
    DBI::dbExecute(conn, "UPDATE cohort_manifest SET status = 'stale' WHERE id = ?", list(as.integer(id)))
  }
}

# Purpose: Evaluate skip status against a stored checksum, with the DBMS
# checksum lookup mocked to return `stored_hash`.
cm_test_skip_status <- function(manifest, cohort, cohort_hashes, stored_hash, env = parent.frame()) {
  testthat::local_mocked_bindings(
    querySql = function(...) data.frame(CHECKSUM = stored_hash),
    .package = "DatabaseConnector",
    .env = env
  )
  conn <- DBI::dbConnect(RSQLite::SQLite(), manifest$getDbPath())
  on.exit(DBI::dbDisconnect(conn))
  evaluate_cohort_skip_status(
    cohort = cohort,
    sqlite_conn = conn,
    cohort_schema = "work",
    checksum_table = "cohort_checksum",
    conn = NULL,
    is_checksum_empty = FALSE,
    cohort_hashes = cohort_hashes,
    dbPath = manifest$getDbPath()
  )
}

# Testing: the derived-cohort checksum covers the cohort's own SQL, so a changed
# definition with unchanged parents is still detected without the 'stale' flag.
testthat::test_that("compute_dependency_hash changes when the derived cohort's own SQL changes", {
  setup <- cm_test_seed_manifest_for_builders("builders-dep-hash")
  manifest <- setup$manifest
  dep_id <- setup$cohorts$id[setup$cohorts$label == "Eligible_With_Exclusions"][1]
  dep <- manifest$getCohortById(dep_id)
  parent_hashes <- lapply(manifest$getManifest(), function(cd) cd$getSqlHash())
  names(parent_hashes) <- vapply(manifest$getManifest(), function(cd) as.character(cd$getId()), character(1))

  edited <- list(getId = function() dep$getId(), getSqlHash = function() "edited-sql-hash")

  testthat::expect_false(identical(
    compute_dependency_hash(manifest$getDbPath(), dep, parent_hashes),
    compute_dependency_hash(manifest$getDbPath(), edited, parent_hashes)
  ))
})

# Testing: a cohort flagged 'stale' in the shared manifest is skipped when this
# database's stored checksum still matches, and regenerated when it does not.
testthat::test_that("evaluate_cohort_skip_status decides by the per-database checksum, not the stale flag", {
  setup <- cm_test_seed_manifest_for_builders("builders-skip-stale")
  manifest <- setup$manifest
  dep_id <- setup$cohorts$id[setup$cohorts$label == "Eligible_With_Exclusions"][1]
  base_id <- setup$cohorts$id[setup$cohorts$label == "Chronic Kidney Disease"][1]
  cm_test_mark_stale(manifest, c(dep_id, base_id))

  parent_hashes <- lapply(manifest$getManifest(), function(cd) cd$getSqlHash())
  names(parent_hashes) <- vapply(manifest$getManifest(), function(cd) as.character(cd$getId()), character(1))
  dep <- manifest$getCohortById(dep_id)
  base <- manifest$getCohortById(base_id)
  dep_hash <- compute_dependency_hash(manifest$getDbPath(), dep, parent_hashes)

  dep_status <- cm_test_skip_status(manifest, dep, parent_hashes, stored_hash = dep_hash)
  testthat::expect_true(dep_status$is_stale)
  testthat::expect_true(dep_status$should_skip)

  base_status <- cm_test_skip_status(manifest, base, parent_hashes, stored_hash = base$getSqlHash())
  testthat::expect_true(base_status$is_stale)
  testthat::expect_true(base_status$should_skip)

  testthat::expect_false(cm_test_skip_status(manifest, dep, parent_hashes, stored_hash = "other")$should_skip)
  testthat::expect_false(cm_test_skip_status(manifest, base, parent_hashes, stored_hash = "other")$should_skip)
})
