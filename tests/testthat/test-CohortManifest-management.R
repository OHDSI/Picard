# Testing: updateCohortLabel updates persisted label for a cohort ID.
testthat::test_that("updateCohortLabel updates label", {
  setup <- cm_test_seed_manifest_for_queries("mgmt-update-label")
  manifest <- setup$manifest

  row <- manifest$queryCohortsByLabel("Custom SQL Cohort", matchType = "exact")
  manifest$updateCohortLabel(as.integer(row$id[[1]]), "Custom SQL Cohort Updated")

  updated <- manifest$queryCohortsByLabel("Custom SQL Cohort Updated", matchType = "exact")
  testthat::expect_equal(nrow(updated), 1)
})

# Testing: updateCohortCategory updates persisted category for a cohort ID.
testthat::test_that("updateCohortCategory updates category", {
  setup <- cm_test_seed_manifest_for_queries("mgmt-update-category")
  manifest <- setup$manifest

  row <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")
  manifest$updateCohortCategory(as.integer(row$id[[1]]), "Target")

  updated <- manifest$queryCohortsByCategory("Target", matchType = "exact")
  testthat::expect_true(any(updated$label == "Type 2 Diabetes"))
})

# Testing: updateCohortTags updates persisted tags for a cohort ID.
testthat::test_that("updateCohortTags updates tags", {
  setup <- cm_test_seed_manifest_for_queries("mgmt-update-tags")
  manifest <- setup$manifest

  row <- manifest$queryCohortsByLabel("All-Cause Death", matchType = "exact")
  manifest$updateCohortTags(as.integer(row$id[[1]]), list(domain = "mortality", owner = "qa"))

  tagged <- manifest$queryCohortsByTagName("owner")
  testthat::expect_true(any(tagged$label == "All-Cause Death"))
})

# Testing: syncManifest removes orphaned files in strict mode.
testthat::test_that("syncManifest removes orphaned sql files", {
  setup <- cm_test_seed_manifest_for_queries("mgmt-sync-orphan")
  manifest <- setup$manifest

  orphan_file <- fs::path(setup$paths$sql_dir, "orphan_fixture.sql")
  writeLines("SELECT 1;", orphan_file)
  testthat::expect_true(fs::file_exists(orphan_file))

  out <- manifest$syncManifest(strict_mode = TRUE)

  testthat::expect_true(any(out$action == "auto_removed_orphan"))
  testthat::expect_false(fs::file_exists(orphan_file))
})

# Testing: validateManifest returns manifest validation columns.
testthat::test_that("validateManifest returns status dataframe", {
  setup <- cm_test_seed_manifest_for_queries("mgmt-validate")
  manifest <- setup$manifest

  out <- manifest$validateManifest()

  testthat::expect_true(all(c("id", "label", "status", "file_exists") %in% names(out)))
})

# Testing: getManifestStatus returns summary counters and next available id.
testthat::test_that("getManifestStatus returns summary list", {
  setup <- cm_test_seed_manifest_for_queries("mgmt-status")
  manifest <- setup$manifest

  out <- manifest$getManifestStatus()

  testthat::expect_true(all(c("active_count", "missing_count", "deleted_count", "next_available_id") %in% names(out)))
  testthat::expect_true(out$active_count >= 5)
})

# Testing: deleteCohort marks cohort status as deleted when confirmed.
testthat::test_that("deleteCohort marks deleted status", {
  setup <- cm_test_seed_manifest_for_queries("mgmt-delete")
  manifest <- setup$manifest

  row <- manifest$queryCohortsByLabel("Custom SQL Cohort", matchType = "exact")
  manifest$deleteCohort(id = as.integer(row$id[[1]]), confirm = TRUE)

  deleted <- manifest$tabulateManifest(filter = "deleted")
  testthat::expect_true(any(deleted$id == as.integer(row$id[[1]])))
})

# Testing: cleanupMissing handles missing active files according to keep_trace policy.
testthat::test_that("cleanupMissing processes missing active cohorts", {
  setup <- cm_test_seed_manifest_for_queries("mgmt-cleanup")
  manifest <- setup$manifest

  row <- manifest$queryCohortsByLabel("Custom SQL Cohort", matchType = "exact")
  conn <- DBI::dbConnect(RSQLite::SQLite(), manifest$getDbPath())
  on.exit(DBI::dbDisconnect(conn), add = TRUE)
  DBI::dbExecute(
    conn,
    "UPDATE cohort_manifest SET file_path = ? WHERE id = ?",
    params = list("missing_file_for_cleanup_test.sql", as.integer(row$id[[1]]))
  )

  testthat::expect_invisible(manifest$cleanupMissing(keep_trace = TRUE))
})
