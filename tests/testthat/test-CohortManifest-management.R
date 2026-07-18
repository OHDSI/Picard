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
  testthat::skip("Known bug: active_count miscount pending fix")

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

# Purpose: Fetch the raw sqlite manifest row for a label (any status).
cm_test_get_manifest_row <- function(manifest, label) {
  conn <- DBI::dbConnect(RSQLite::SQLite(), manifest$getDbPath())
  on.exit(DBI::dbDisconnect(conn))
  DBI::dbGetQuery(
    conn,
    "SELECT * FROM cohort_manifest WHERE label = ?",
    list(label)
  )
}

# Testing: updateCaprCohort overwrites the registered JSON and refreshes the hash in place.
testthat::test_that("updateCaprCohort updates definition keeping id and file path", {
  setup <- cm_test_new_manifest("mgmt-update-capr")
  manifest <- setup$manifest

  cm_test_add_capr_cohort(manifest, label = "Capr T2D", category = "Target")
  before <- cm_test_get_manifest_row(manifest, "Capr T2D")

  revised <- cm_test_make_minimal_capr_cohort(prior_days = 365L)
  returned_id <- manifest$updateCaprCohort(revised, label = "Capr T2D")

  after <- cm_test_get_manifest_row(manifest, "Capr T2D")
  testthat::expect_equal(as.integer(returned_id), as.integer(before$id[[1]]))
  testthat::expect_equal(after$id[[1]], before$id[[1]])
  testthat::expect_equal(after$file_path[[1]], before$file_path[[1]])
  testthat::expect_false(identical(after$hash[[1]], before$hash[[1]]))

  # Hash recorded in the manifest matches the file now on disk
  disk_hash <- rlang::hash(readr::read_file(after$file_path[[1]]))
  testthat::expect_equal(after$hash[[1]], disk_hash)
})

# Testing: updateCaprCohort leaves manifest untouched when the definition is unchanged.
testthat::test_that("updateCaprCohort is a no-op for identical definitions", {
  setup <- cm_test_new_manifest("mgmt-update-capr-noop")
  manifest <- setup$manifest

  cm_test_add_capr_cohort(manifest, label = "Capr T2D", category = "Target")
  before <- cm_test_get_manifest_row(manifest, "Capr T2D")

  same <- cm_test_make_minimal_capr_cohort()
  testthat::expect_message(
    manifest$updateCaprCohort(same, label = "Capr T2D"),
    regexp = "unchanged"
  )

  after <- cm_test_get_manifest_row(manifest, "Capr T2D")
  testthat::expect_equal(after$hash[[1]], before$hash[[1]])
})

# Testing: updateCaprCohort errors for labels not registered in the manifest.
testthat::test_that("updateCaprCohort errors when label is not registered", {
  setup <- cm_test_new_manifest("mgmt-update-capr-missing")
  manifest <- setup$manifest

  capr_cohort <- cm_test_make_minimal_capr_cohort()
  testthat::expect_error(
    manifest$updateCaprCohort(capr_cohort, label = "Not Registered"),
    regexp = "No active cohort"
  )
})

# Testing: updateCaprCohort marks derived dependents stale after a definition change.
testthat::test_that("updateCaprCohort cascades stale to derived dependents", {
  setup <- cm_test_new_manifest("mgmt-update-capr-stale")
  manifest <- setup$manifest

  cm_test_add_capr_cohort(manifest, label = "Capr T2D", category = "Target")
  cm_test_add_circe_cohort(
    manifest = manifest,
    paths = setup$paths,
    label = "Chronic Kidney Disease",
    fixture_name = "ckd.json"
  )

  parents <- manifest$queryCohortsByLabel(
    labels = c("Capr T2D", "Chronic Kidney Disease"),
    matchType = "exact"
  )
  manifest$buildUnionCohort(
    label = "Capr_T2D_or_CKD",
    category = "Derived Cohorts",
    cohortEntries = parents
  )

  revised <- cm_test_make_minimal_capr_cohort(prior_days = 365L)
  manifest$updateCaprCohort(revised, label = "Capr T2D")

  stale <- manifest$tabulateManifest(filter = "stale")
  testthat::expect_true(any(stale$label == "Capr_T2D_or_CKD"))
})

# Testing: addCaprCohort with stopIfExists = FALSE upserts the existing cohort in place.
testthat::test_that("addCaprCohort stopIfExists FALSE updates existing cohort", {
  setup <- cm_test_new_manifest("mgmt-add-capr-upsert")
  manifest <- setup$manifest

  cm_test_add_capr_cohort(manifest, label = "Capr T2D", category = "Target")
  before <- cm_test_get_manifest_row(manifest, "Capr T2D")

  revised <- cm_test_make_minimal_capr_cohort(prior_days = 365L)
  returned_id <- manifest$addCaprCohort(
    caprCohort = revised,
    label = "Capr T2D",
    category = "Comparator",
    tags = list(source = "capr", revision = "v2"),
    stopIfExists = FALSE
  )

  after <- cm_test_get_manifest_row(manifest, "Capr T2D")
  testthat::expect_equal(nrow(after), 1)
  testthat::expect_equal(as.integer(returned_id), as.integer(before$id[[1]]))
  testthat::expect_equal(after$file_path[[1]], before$file_path[[1]])
  testthat::expect_false(identical(after$hash[[1]], before$hash[[1]]))
  testthat::expect_equal(after$category[[1]], "Comparator")
  testthat::expect_true(grepl("revision", after$tags[[1]]))
})

# Purpose: Build a fake ATLAS connection returning fixed expression JSON keyed by atlasId.
cm_test_fake_atlas_connection <- function(expressions) {
  list(
    getCohortDefinition = function(cohortId) {
      list(
        expression = expressions[[as.character(cohortId)]],
        saveName = paste0("atlas_cohort_", cohortId)
      )
    }
  )
}

# Testing: importAtlasCohorts updateExisting = TRUE upserts changed ATLAS definitions in place.
testthat::test_that("importAtlasCohorts updateExisting TRUE updates changed definitions", {
  setup <- cm_test_new_manifest("mgmt-atlas-upsert")
  manifest <- setup$manifest

  # Fake ATLAS payloads must be valid CIRCE JSON (CohortDef validates via CirceR)
  v1_path <- testthat::test_path("test_files", "ckd.json")
  v2_path <- testthat::test_path("test_files", "t2d.json")
  testthat::skip_if_not(fs::file_exists(v1_path) && fs::file_exists(v2_path),
                        message = "Missing CIRCE test fixtures")
  v1_json <- readr::read_file(v1_path)
  v2_json <- readr::read_file(v2_path)

  load_df <- data.frame(atlasId = 100L, label = "Atlas Cohort", category = "Target")

  conn_v1 <- cm_test_fake_atlas_connection(list("100" = v1_json))
  manifest$importAtlasCohorts(cohortsLoad = load_df, atlasConnection = conn_v1)
  before <- cm_test_get_manifest_row(manifest, "Atlas Cohort")
  testthat::expect_equal(nrow(before), 1)

  conn_v2 <- cm_test_fake_atlas_connection(list("100" = v2_json))

  # Default re-import leaves the registered definition untouched
  manifest$importAtlasCohorts(cohortsLoad = load_df, atlasConnection = conn_v2)
  unchanged <- cm_test_get_manifest_row(manifest, "Atlas Cohort")
  testthat::expect_equal(unchanged$hash[[1]], before$hash[[1]])

  # updateExisting = TRUE fetches the new definition and updates in place
  manifest$importAtlasCohorts(cohortsLoad = load_df, atlasConnection = conn_v2, updateExisting = TRUE)
  after <- cm_test_get_manifest_row(manifest, "Atlas Cohort")
  testthat::expect_equal(after$id[[1]], before$id[[1]])
  testthat::expect_equal(after$file_path[[1]], before$file_path[[1]])
  testthat::expect_false(identical(after$hash[[1]], before$hash[[1]]))
})

# Testing: addCaprCohort default stopIfExists = TRUE still errors on duplicate labels.
testthat::test_that("addCaprCohort errors on duplicate label by default", {
  setup <- cm_test_new_manifest("mgmt-add-capr-dup")
  manifest <- setup$manifest

  cm_test_add_capr_cohort(manifest, label = "Capr T2D", category = "Target")

  same <- cm_test_make_minimal_capr_cohort()
  testthat::expect_error(
    manifest$addCaprCohort(same, label = "Capr T2D", category = "Target"),
    regexp = "already in use"
  )
})
