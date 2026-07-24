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

  # Stale cohorts must stay reachable by the generation machinery so they can
  # be regenerated and re-activated on the next generateCohorts() run
  stale_id <- as.integer(stale$id[stale$label == "Capr_T2D_or_CKD"][[1]])
  graph <- build_dependency_graph(manifest$getDbPath())
  testthat::expect_true(as.character(stale_id) %in% names(graph))
  testthat::expect_false(is.null(manifest$getCohortById(stale_id)))
})

# Purpose: Seed a manifest with a Capr parent, a circe parent, and a union dependent.
cm_test_seed_parent_with_union <- function(test_name) {
  setup <- cm_test_new_manifest(test_name)
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

  list(manifest = manifest, paths = setup$paths)
}

# Testing: deleteCohort refuses to orphan derived dependents; cascade = TRUE deletes the subtree.
testthat::test_that("deleteCohort blocks with dependents and cascades when asked", {
  setup <- cm_test_seed_parent_with_union("mgmt-delete-guard")
  manifest <- setup$manifest

  parent <- manifest$queryCohortsByLabel("Capr T2D", matchType = "exact")
  parent_id <- as.integer(parent$id[[1]])

  testthat::expect_error(
    manifest$deleteCohort(id = parent_id, confirm = TRUE),
    regexp = "dependent"
  )

  manifest$deleteCohort(id = parent_id, confirm = TRUE, cascade = TRUE)

  deleted <- manifest$tabulateManifest(filter = "deleted")
  testthat::expect_true(any(deleted$label == "Capr T2D"))
  testthat::expect_true(any(deleted$label == "Capr_T2D_or_CKD"))

  # The uninvolved parent stays active
  active <- manifest$tabulateManifest(filter = "active")
  testthat::expect_true(any(active$label == "Chronic Kidney Disease"))
})

# Testing: syncManifest soft-deletes derived dependents when a parent file goes missing.
testthat::test_that("syncManifest cascades deletion of dependents of missing parents", {
  setup <- cm_test_seed_parent_with_union("mgmt-sync-cascade")
  manifest <- setup$manifest

  parent <- manifest$queryCohortsByLabel("Capr T2D", matchType = "exact")
  unlink(parent$file_path[[1]])

  out <- manifest$syncManifest(strict_mode = TRUE)

  testthat::expect_true(any(out$action == "missing_flagged" & out$label == "Capr T2D"))
  testthat::expect_true(any(out$action == "cascade_deleted" & out$label == "Capr_T2D_or_CKD"))

  deleted <- manifest$tabulateManifest(filter = "deleted")
  testthat::expect_true(any(deleted$label == "Capr_T2D_or_CKD"))
})

# Testing: buildUnionCohort stopIfExists = FALSE updates the parent list in place.
testthat::test_that("buildUnionCohort stopIfExists FALSE updates parent list in place", {
  setup <- cm_test_seed_parent_with_union("mgmt-union-upsert")
  manifest <- setup$manifest

  cm_test_add_circe_cohort(
    manifest = manifest,
    paths = setup$paths,
    label = "All-Cause Death",
    fixture_name = "death.json"
  )

  before <- cm_test_get_manifest_row(manifest, "Capr_T2D_or_CKD")
  testthat::expect_equal(length(jsonlite::fromJSON(before$depends_on[[1]])), 2)

  parents <- manifest$queryCohortsByLabel(
    labels = c("Capr T2D", "Chronic Kidney Disease", "All-Cause Death"),
    matchType = "exact"
  )
  returned_id <- manifest$buildUnionCohort(
    label = "Capr_T2D_or_CKD",
    category = "Derived Cohorts",
    cohortEntries = parents,
    stopIfExists = FALSE
  )

  after <- cm_test_get_manifest_row(manifest, "Capr_T2D_or_CKD")
  testthat::expect_equal(nrow(after), 1)
  testthat::expect_equal(as.integer(returned_id), as.integer(before$id[[1]]))
  testthat::expect_equal(after$file_path[[1]], before$file_path[[1]])
  testthat::expect_equal(length(jsonlite::fromJSON(after$depends_on[[1]])), 3)
  testthat::expect_equal(after$status[[1]], "stale")
  testthat::expect_false(identical(after$hash[[1]], before$hash[[1]]))

  # The re-rendered SQL file matches the recorded hash
  disk_hash <- rlang::hash(readr::read_file(after$file_path[[1]]))
  testthat::expect_equal(after$hash[[1]], disk_hash)
})

# Testing: derived-cohort upsert replaces tags wholesale (cleared when none supplied).
testthat::test_that("buildUnionCohort stopIfExists FALSE without tags drops prior tags", {
  setup <- cm_test_seed_parent_with_union("mgmt-union-upsert-notags")
  manifest <- setup$manifest

  union_row <- cm_test_get_manifest_row(manifest, "Capr_T2D_or_CKD")
  manifest$updateCohortTags(as.integer(union_row$id[[1]]), list(revision = "v1"))

  parents <- manifest$queryCohortsByLabel(
    labels = c("Capr T2D", "Chronic Kidney Disease"),
    matchType = "exact"
  )
  manifest$buildUnionCohort(
    label = "Capr_T2D_or_CKD",
    category = "Derived Cohorts",
    cohortEntries = parents,
    stopIfExists = FALSE
  )

  after <- cm_test_get_manifest_row(manifest, "Capr_T2D_or_CKD")
  testthat::expect_equal(nrow(after), 1)
  testthat::expect_true(is.na(after$tags[[1]]))
})

# Testing: build methods still error on duplicate labels by default.
testthat::test_that("buildUnionCohort errors on duplicate label by default", {
  setup <- cm_test_seed_parent_with_union("mgmt-union-dup")
  manifest <- setup$manifest

  parents <- manifest$queryCohortsByLabel(
    labels = c("Capr T2D", "Chronic Kidney Disease"),
    matchType = "exact"
  )
  testthat::expect_error(
    manifest$buildUnionCohort(
      label = "Capr_T2D_or_CKD",
      category = "Derived Cohorts",
      cohortEntries = parents
    ),
    regexp = "already in use"
  )
})

# Testing: derived upsert rejects a parent set that would create a dependency cycle.
testthat::test_that("derived upsert rejects parents that would create a cycle", {
  setup <- cm_test_seed_parent_with_union("mgmt-union-cycle")
  manifest <- setup$manifest

  # Build a second union that depends on the first one
  parents_u2 <- manifest$queryCohortsByLabel(
    labels = c("Capr_T2D_or_CKD", "Chronic Kidney Disease"),
    matchType = "exact"
  )
  manifest$buildUnionCohort(
    label = "Union_of_Union",
    category = "Derived Cohorts",
    cohortEntries = parents_u2
  )

  # Updating the first union to depend on its own dependent must fail
  bad_parents <- manifest$queryCohortsByLabel(
    labels = c("Capr T2D", "Union_of_Union"),
    matchType = "exact"
  )
  testthat::expect_error(
    manifest$buildUnionCohort(
      label = "Capr_T2D_or_CKD",
      category = "Derived Cohorts",
      cohortEntries = bad_parents,
      stopIfExists = FALSE
    ),
    regexp = "cycle"
  )
})

# Testing: addDependentCustomCohort stopIfExists = FALSE updates dependent IDs and SQL in place.
testthat::test_that("addDependentCustomCohort stopIfExists FALSE updates deps and SQL in place", {
  setup <- cm_test_new_manifest("mgmt-depcustom-upsert")
  manifest <- setup$manifest

  cm_test_add_circe_cohort(manifest, setup$paths, label = "Chronic Kidney Disease", fixture_name = "ckd.json")
  cm_test_add_circe_cohort(manifest, setup$paths, label = "Type 2 Diabetes", fixture_name = "t2d.json")
  rows <- manifest$tabulateManifest(filter = "active")
  ckd_id <- as.integer(rows$id[rows$label == "Chronic Kidney Disease"][1])
  t2d_id <- as.integer(rows$id[rows$label == "Type 2 Diabetes"][1])

  # Copy the fixture into the temp repo so edits never touch the checked-in file
  fixture <- cm_test_sql_fixture_path("my_custom_dependent.sql")
  local_sql <- fs::path(setup$paths$sql_dir, "my_custom_dependent.sql")
  fs::file_copy(fixture, local_sql)

  manifest$addDependentCustomCohort(
    filePath = local_sql,
    label = "Dep Custom",
    category = "Derived Cohorts",
    dependentCohortIdList = list(inc_cohort_id = ckd_id, exc_cohort_id = t2d_id)
  )
  before <- cm_test_get_manifest_row(manifest, "Dep Custom")
  testthat::expect_equal(
    jsonlite::fromJSON(before$depends_on[[1]]),
    c(ckd_id, t2d_id)
  )

  # Edit the SQL (append a comment) and swap the dependent IDs, then upsert
  writeLines(c(readLines(local_sql), "-- revised for upsert test"), local_sql)
  returned_id <- manifest$addDependentCustomCohort(
    filePath = local_sql,
    label = "Dep Custom",
    category = "Derived Cohorts",
    dependentCohortIdList = list(inc_cohort_id = t2d_id, exc_cohort_id = ckd_id),
    stopIfExists = FALSE
  )

  after <- cm_test_get_manifest_row(manifest, "Dep Custom")
  testthat::expect_equal(nrow(after), 1)
  testthat::expect_equal(as.integer(returned_id), as.integer(before$id[[1]]))
  testthat::expect_equal(
    jsonlite::fromJSON(after$depends_on[[1]]),
    c(t2d_id, ckd_id)
  )
  testthat::expect_false(identical(after$hash[[1]], before$hash[[1]]))
  testthat::expect_equal(after$status[[1]], "stale")
  testthat::expect_equal(after$source_type[[1]], "sql")
  testthat::expect_equal(after$cohort_type[[1]], "custom_derived")

  # The dependency rule carries the swapped parameter mapping
  rule <- jsonlite::fromJSON(after$dependency_rule[[1]])
  testthat::expect_equal(as.integer(rule$dependentCohortIdList$inc_cohort_id), t2d_id)
  testthat::expect_equal(as.integer(rule$dependentCohortIdList$exc_cohort_id), ckd_id)
})

# Testing: dependentCohortIdList entries accept vectors of IDs, stored in depends_on
# and baked comma-separated into the generated derived SQL file.
testthat::test_that("addDependentCustomCohort accepts vectors of dependent IDs", {
  setup <- cm_test_new_manifest("mgmt-depcustom-vector")
  manifest <- setup$manifest

  cm_test_add_circe_cohort(manifest, setup$paths, label = "Chronic Kidney Disease", fixture_name = "ckd.json")
  cm_test_add_circe_cohort(manifest, setup$paths, label = "Type 2 Diabetes", fixture_name = "t2d.json")
  cm_test_add_circe_cohort(manifest, setup$paths, label = "All-Cause Death", fixture_name = "death.json")
  rows <- manifest$tabulateManifest(filter = "active")
  ckd_id <- as.integer(rows$id[rows$label == "Chronic Kidney Disease"][1])
  t2d_id <- as.integer(rows$id[rows$label == "Type 2 Diabetes"][1])
  death_id <- as.integer(rows$id[rows$label == "All-Cause Death"][1])

  fixture <- cm_test_sql_fixture_path("my_custom_dependent.sql")
  local_sql <- fs::path(setup$paths$sql_dir, "my_custom_dependent.sql")
  fs::file_copy(fixture, local_sql)

  dep_id <- manifest$addDependentCustomCohort(
    filePath = local_sql,
    label = "Dep Vector",
    category = "Derived Cohorts",
    dependentCohortIdList = list(
      inc_cohort_id = ckd_id,
      exc_cohort_id = c(t2d_id, death_id)
    )
  )

  row <- cm_test_get_manifest_row(manifest, "Dep Vector")
  testthat::expect_equal(
    jsonlite::fromJSON(row$depends_on[[1]]),
    c(ckd_id, t2d_id, death_id)
  )

  # The dependent IDs are baked directly into the generated derived SQL file
  # (like the other derived cohort types) - the vector renders comma-separated
  # and the original @inc_cohort_id/@exc_cohort_id placeholders are gone.
  testthat::expect_true(grepl("inputs/cohorts/derived", row$file_path[[1]], fixed = TRUE))
  rendered_sql <- readr::read_file(row$file_path[[1]])
  testthat::expect_false(grepl("@inc_cohort_id", rendered_sql, fixed = TRUE))
  testthat::expect_false(grepl("@exc_cohort_id", rendered_sql, fixed = TRUE))
  testthat::expect_true(grepl(as.character(t2d_id), rendered_sql, fixed = TRUE))
  testthat::expect_true(grepl(as.character(death_id), rendered_sql, fixed = TRUE))
  testthat::expect_true(grepl(paste0(t2d_id, ",", death_id), rendered_sql, fixed = TRUE))

  # Connection/schema placeholders are left for generateCohorts() to fill in
  testthat::expect_true(grepl("@target_cohort_id", rendered_sql, fixed = TRUE))
  testthat::expect_true(grepl("@target_database_schema", rendered_sql, fixed = TRUE))
})

# Testing: dependentCohortIdList accepts manifest entries (data.frame/tibble
# with an id column), like the other dependent cohort builders, and renders
# their labels into a QC header comment on the generated derived SQL file.
testthat::test_that("addDependentCustomCohort accepts manifest entries and renders a QC header", {
  setup <- cm_test_new_manifest("mgmt-depcustom-entries")
  manifest <- setup$manifest

  cm_test_add_circe_cohort(manifest, setup$paths, label = "Chronic Kidney Disease", fixture_name = "ckd.json")
  cm_test_add_circe_cohort(manifest, setup$paths, label = "Type 2 Diabetes", fixture_name = "t2d.json")
  cm_test_add_circe_cohort(manifest, setup$paths, label = "All-Cause Death", fixture_name = "death.json")

  ckd_entry <- manifest$queryCohortsByLabel("Chronic Kidney Disease")
  exclusion_entries <- manifest$queryCohortsByLabel(c("Type 2 Diabetes", "All-Cause Death"))
  t2d_id <- as.integer(exclusion_entries$id[exclusion_entries$label == "Type 2 Diabetes"][1])
  death_id <- as.integer(exclusion_entries$id[exclusion_entries$label == "All-Cause Death"][1])

  fixture <- cm_test_sql_fixture_path("my_custom_dependent.sql")
  local_sql <- fs::path(setup$paths$sql_dir, "my_custom_dependent.sql")
  fs::file_copy(fixture, local_sql)

  manifest$addDependentCustomCohort(
    filePath = local_sql,
    label = "Dep Entries",
    category = "Derived Cohorts",
    dependentCohortIdList = list(
      inc_cohort_id = ckd_entry,
      exc_cohort_id = exclusion_entries
    )
  )

  row <- cm_test_get_manifest_row(manifest, "Dep Entries")
  testthat::expect_equal(
    sort(jsonlite::fromJSON(row$depends_on[[1]])),
    sort(c(as.integer(ckd_entry$id[1]), t2d_id, death_id))
  )

  rendered_sql <- readr::read_file(row$file_path[[1]])
  testthat::expect_true(grepl("Dependent cohorts", rendered_sql, fixed = TRUE))
  testthat::expect_true(grepl("Chronic Kidney Disease", rendered_sql, fixed = TRUE))
  testthat::expect_true(grepl("Type 2 Diabetes", rendered_sql, fixed = TRUE))
  testthat::expect_true(grepl("All-Cause Death", rendered_sql, fixed = TRUE))
  testthat::expect_true(grepl(as.character(ckd_entry$id[1]), rendered_sql, fixed = TRUE))
})

# Testing: addDependentCustomCohort default stopIfExists = TRUE errors on duplicate labels.
testthat::test_that("addDependentCustomCohort errors on duplicate label by default", {
  setup <- cm_test_new_manifest("mgmt-depcustom-dup")
  manifest <- setup$manifest

  cm_test_add_circe_cohort(manifest, setup$paths, label = "Chronic Kidney Disease", fixture_name = "ckd.json")
  cm_test_add_circe_cohort(manifest, setup$paths, label = "Type 2 Diabetes", fixture_name = "t2d.json")
  rows <- manifest$tabulateManifest(filter = "active")
  ckd_id <- as.integer(rows$id[rows$label == "Chronic Kidney Disease"][1])
  t2d_id <- as.integer(rows$id[rows$label == "Type 2 Diabetes"][1])

  fixture <- cm_test_sql_fixture_path("my_custom_dependent.sql")
  local_sql <- fs::path(setup$paths$sql_dir, "my_custom_dependent.sql")
  fs::file_copy(fixture, local_sql)

  manifest$addDependentCustomCohort(
    filePath = local_sql,
    label = "Dep Custom",
    category = "Derived Cohorts",
    dependentCohortIdList = list(inc_cohort_id = ckd_id, exc_cohort_id = t2d_id)
  )

  testthat::expect_error(
    manifest$addDependentCustomCohort(
      filePath = local_sql,
      label = "Dep Custom",
      category = "Derived Cohorts",
      dependentCohortIdList = list(inc_cohort_id = ckd_id, exc_cohort_id = t2d_id)
    ),
    regexp = "already in use"
  )
})

# Testing: sqlParameters render arbitrary (non cohort-ID) values into the
# generated derived SQL file alongside dependentCohortIdList.
testthat::test_that("addDependentCustomCohort renders sqlParameters into the generated file", {
  setup <- cm_test_new_manifest("mgmt-depcustom-sqlparams")
  manifest <- setup$manifest

  cm_test_add_circe_cohort(manifest, setup$paths, label = "Chronic Kidney Disease", fixture_name = "ckd.json")
  cm_test_add_circe_cohort(manifest, setup$paths, label = "Type 2 Diabetes", fixture_name = "t2d.json")
  rows <- manifest$tabulateManifest(filter = "active")
  ckd_id <- as.integer(rows$id[rows$label == "Chronic Kidney Disease"][1])
  t2d_id <- as.integer(rows$id[rows$label == "Type 2 Diabetes"][1])

  local_sql <- fs::path(setup$paths$sql_dir, "my_custom_dependent_params.sql")
  writeLines(c(
    "DELETE FROM @target_database_schema.@target_cohort_table",
    "WHERE cohort_definition_id = @target_cohort_id;",
    "",
    "INSERT INTO @target_database_schema.@target_cohort_table",
    "  (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)",
    "SELECT",
    "  @target_cohort_id,",
    "  i.subject_id,",
    "  i.cohort_start_date,",
    "  DATEADD(day, @min_days, i.cohort_start_date)",
    "FROM @target_database_schema.@target_cohort_table i",
    "WHERE i.cohort_definition_id = @inc_cohort_id",
    "  AND i.cohort_definition_id != @exc_cohort_id;"
  ), local_sql)

  manifest$addDependentCustomCohort(
    filePath = local_sql,
    label = "Dep Params",
    category = "Derived Cohorts",
    dependentCohortIdList = list(inc_cohort_id = ckd_id, exc_cohort_id = t2d_id),
    sqlParameters = list(min_days = 30L)
  )

  row <- cm_test_get_manifest_row(manifest, "Dep Params")
  rendered_sql <- readr::read_file(row$file_path[[1]])
  testthat::expect_true(grepl("DATEADD(day, 30,", rendered_sql, fixed = TRUE))
  testthat::expect_false(grepl("@min_days", rendered_sql, fixed = TRUE))
  testthat::expect_false(grepl("@inc_cohort_id", rendered_sql, fixed = TRUE))
  testthat::expect_true(grepl(as.character(ckd_id), rendered_sql, fixed = TRUE))

  rule <- jsonlite::fromJSON(row$dependency_rule[[1]])
  testthat::expect_equal(as.integer(rule$sqlParameters$min_days), 30L)
})

# Testing: sqlParameters cannot collide with dependentCohortIdList names or
# reserved (connection/schema) SqlRender parameter names.
testthat::test_that("addDependentCustomCohort errors on sqlParameters name collisions", {
  setup <- cm_test_new_manifest("mgmt-depcustom-sqlparams-collision")
  manifest <- setup$manifest

  cm_test_add_circe_cohort(manifest, setup$paths, label = "Chronic Kidney Disease", fixture_name = "ckd.json")
  cm_test_add_circe_cohort(manifest, setup$paths, label = "Type 2 Diabetes", fixture_name = "t2d.json")
  rows <- manifest$tabulateManifest(filter = "active")
  ckd_id <- as.integer(rows$id[rows$label == "Chronic Kidney Disease"][1])
  t2d_id <- as.integer(rows$id[rows$label == "Type 2 Diabetes"][1])

  fixture <- cm_test_sql_fixture_path("my_custom_dependent.sql")
  local_sql <- fs::path(setup$paths$sql_dir, "my_custom_dependent.sql")
  fs::file_copy(fixture, local_sql)

  testthat::expect_error(
    manifest$addDependentCustomCohort(
      filePath = local_sql,
      label = "Dep Collide",
      category = "Derived Cohorts",
      dependentCohortIdList = list(inc_cohort_id = ckd_id, exc_cohort_id = t2d_id),
      sqlParameters = list(inc_cohort_id = 5L)
    ),
    regexp = "cannot share parameter name"
  )

  testthat::expect_error(
    manifest$addDependentCustomCohort(
      filePath = local_sql,
      label = "Dep Reserved",
      category = "Derived Cohorts",
      dependentCohortIdList = list(inc_cohort_id = ckd_id, exc_cohort_id = t2d_id),
      sqlParameters = list(target_cohort_id = 5L)
    ),
    regexp = "reserved SqlRender parameter"
  )
})

# Testing: topological_sort distinguishes dangling parent references from genuine cycles.
testthat::test_that("topological_sort reports dangling and circular dependencies distinctly", {
  testthat::expect_error(
    topological_sort(list("2" = 1L)),
    regexp = "missing/deleted"
  )

  testthat::expect_error(
    topological_sort(list("1" = 2L, "2" = 1L)),
    regexp = "circular"
  )
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

# Testing: addCaprCohort stopIfExists = FALSE with no tags clears prior tags (matching ATLAS behavior).
testthat::test_that("addCaprCohort stopIfExists FALSE without tags drops prior tags", {
  setup <- cm_test_new_manifest("mgmt-add-capr-upsert-notags")
  manifest <- setup$manifest

  cm_test_add_capr_cohort(manifest, label = "Capr T2D", category = "Target",
                          tags = list(source = "capr", revision = "v1"))

  revised <- cm_test_make_minimal_capr_cohort(prior_days = 365L)
  manifest$addCaprCohort(
    caprCohort = revised,
    label = "Capr T2D",
    category = "Target",
    stopIfExists = FALSE
  )

  after <- cm_test_get_manifest_row(manifest, "Capr T2D")
  testthat::expect_equal(nrow(after), 1)
  testthat::expect_false(grepl("revision", after$tags[[1]]))
  testthat::expect_true(grepl("route", after$tags[[1]]))
})

# Testing: addSqlCohort with stopIfExists = FALSE upserts the existing cohort in place.
testthat::test_that("addSqlCohort stopIfExists FALSE updates existing cohort in place", {
  setup <- cm_test_new_manifest("mgmt-add-sql-upsert")
  manifest <- setup$manifest

  cm_test_add_sql_cohort(manifest, setup$paths, label = "Custom SQL Cohort",
                         category = "Target", tags = list(revision = "v1"))
  before <- cm_test_get_manifest_row(manifest, "Custom SQL Cohort")

  # Revised SQL registered from a new file path
  revised_sql <- fs::path(setup$paths$sql_dir, "my_custom_cohort_v2.sql")
  writeLines(c(readr::read_file(before$file_path[[1]]), "-- revised"), revised_sql)
  returned_id <- manifest$addSqlCohort(
    filePath = revised_sql,
    label = "Custom SQL Cohort",
    category = "Comparator",
    stopIfExists = FALSE
  )

  after <- cm_test_get_manifest_row(manifest, "Custom SQL Cohort")
  testthat::expect_equal(nrow(after), 1)
  testthat::expect_equal(as.integer(returned_id), as.integer(before$id[[1]]))
  testthat::expect_false(identical(after$hash[[1]], before$hash[[1]]))
  testthat::expect_equal(after$file_path[[1]], as.character(fs::path_rel(revised_sql)))
  testthat::expect_equal(after$category[[1]], "Comparator")
  testthat::expect_true(is.na(after$tags[[1]]))
})

# Testing: addSqlCohort upsert refuses to overwrite a non-custom cohort.
testthat::test_that("addSqlCohort stopIfExists FALSE rejects non-custom targets", {
  setup <- cm_test_new_manifest("mgmt-add-sql-upsert-guard")
  manifest <- setup$manifest

  cm_test_add_circe_cohort(manifest, setup$paths, label = "Circe Cohort", fixture_name = "ckd.json")
  sql_path <- cm_test_sql_fixture_path()

  testthat::expect_error(
    manifest$addSqlCohort(
      filePath = sql_path,
      label = "Circe Cohort",
      category = "Target",
      stopIfExists = FALSE
    ),
    regexp = "custom"
  )
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

# Purpose: Read the two CIRCE fixtures used as fake ATLAS payloads (must be valid
# CIRCE JSON because CohortDef validates via CirceR); skip if missing.
cm_test_atlas_fixture_jsons <- function() {
  v1_path <- testthat::test_path("test_files", "ckd.json")
  v2_path <- testthat::test_path("test_files", "t2d.json")
  testthat::skip_if_not(fs::file_exists(v1_path) && fs::file_exists(v2_path),
                        message = "Missing CIRCE test fixtures")
  list(v1 = readr::read_file(v1_path), v2 = readr::read_file(v2_path))
}

# Testing: importAtlasCohorts errors when load rows are already registered (transient csv).
testthat::test_that("importAtlasCohorts errors on already-registered rows", {
  setup <- cm_test_new_manifest("mgmt-atlas-import-dup")
  manifest <- setup$manifest
  jsons <- cm_test_atlas_fixture_jsons()

  load_df <- data.frame(atlasId = 100L, label = "Atlas Cohort", category = "Target")
  conn_v1 <- cm_test_fake_atlas_connection(list("100" = jsons$v1))

  manifest$importAtlasCohorts(cohortsLoad = load_df, atlasConnection = conn_v1)
  testthat::expect_equal(nrow(cm_test_get_manifest_row(manifest, "Atlas Cohort")), 1)

  # Re-importing the same load file fails fast, and nothing is changed
  before <- cm_test_get_manifest_row(manifest, "Atlas Cohort")
  testthat::expect_error(
    manifest$importAtlasCohorts(cohortsLoad = load_df, atlasConnection = conn_v1),
    regexp = "already registered"
  )
  after <- cm_test_get_manifest_row(manifest, "Atlas Cohort")
  testthat::expect_equal(after$hash[[1]], before$hash[[1]])

  # A new atlasId with a colliding label also fails fast
  collide_df <- data.frame(atlasId = 200L, label = "Atlas Cohort", category = "Target")
  conn_both <- cm_test_fake_atlas_connection(list("100" = jsons$v1, "200" = jsons$v2))
  testthat::expect_error(
    manifest$importAtlasCohorts(cohortsLoad = collide_df, atlasConnection = conn_both),
    regexp = "already in use"
  )
})

# Testing: importAtlasCohorts stopIfExists = FALSE updates already-registered rows in place
# instead of erroring, supporting re-running the same load file while iterating.
testthat::test_that("importAtlasCohorts stopIfExists FALSE updates existing rows in place", {
  setup <- cm_test_new_manifest("mgmt-atlas-import-upsert")
  manifest <- setup$manifest
  jsons <- cm_test_atlas_fixture_jsons()

  load_df <- data.frame(atlasId = 100L, label = "Atlas Cohort", category = "Target")
  conn_v1 <- cm_test_fake_atlas_connection(list("100" = jsons$v1))
  manifest$importAtlasCohorts(cohortsLoad = load_df, atlasConnection = conn_v1)
  before <- cm_test_get_manifest_row(manifest, "Atlas Cohort")

  # Re-running with stopIfExists = FALSE and a changed definition updates in place
  conn_v2 <- cm_test_fake_atlas_connection(list("100" = jsons$v2))
  manifest$importAtlasCohorts(cohortsLoad = load_df, atlasConnection = conn_v2, stopIfExists = FALSE)
  after <- cm_test_get_manifest_row(manifest, "Atlas Cohort")
  testthat::expect_equal(nrow(after), 1)
  testthat::expect_equal(after$id[[1]], before$id[[1]])
  testthat::expect_false(identical(after$hash[[1]], before$hash[[1]]))

  # A mix of a new row and an already-registered row processes both
  mixed_df <- data.frame(
    atlasId = c(100L, 200L),
    label = c("Atlas Cohort", "Second Atlas Cohort"),
    category = c("Target", "Target")
  )
  conn_both <- cm_test_fake_atlas_connection(list("100" = jsons$v2, "200" = jsons$v2))
  manifest$importAtlasCohorts(cohortsLoad = mixed_df, atlasConnection = conn_both, stopIfExists = FALSE)
  testthat::expect_equal(nrow(cm_test_get_manifest_row(manifest, "Second Atlas Cohort")), 1)
})

# Testing: addAtlasCohort stopIfExists = FALSE refreshes a single cohort from ATLAS in place.
testthat::test_that("addAtlasCohort stopIfExists FALSE updates from ATLAS in place", {
  setup <- cm_test_new_manifest("mgmt-atlas-add-upsert")
  manifest <- setup$manifest
  jsons <- cm_test_atlas_fixture_jsons()

  conn_v1 <- cm_test_fake_atlas_connection(list("100" = jsons$v1))
  manifest$addAtlasCohort(atlasId = 100L, label = "Atlas Cohort", category = "Target",
                          atlasConnection = conn_v1)
  before <- cm_test_get_manifest_row(manifest, "Atlas Cohort")

  # Unchanged definition is a no-op
  manifest$addAtlasCohort(atlasId = 100L, label = "Atlas Cohort", category = "Target",
                          atlasConnection = conn_v1, stopIfExists = FALSE)
  unchanged <- cm_test_get_manifest_row(manifest, "Atlas Cohort")
  testthat::expect_equal(unchanged$hash[[1]], before$hash[[1]])

  # Changed definition updates in place, keeping ID and file path
  conn_v2 <- cm_test_fake_atlas_connection(list("100" = jsons$v2))
  returned_id <- manifest$addAtlasCohort(atlasId = 100L, label = "Atlas Cohort", category = "Comparator",
                                         atlasConnection = conn_v2, stopIfExists = FALSE)
  after <- cm_test_get_manifest_row(manifest, "Atlas Cohort")
  testthat::expect_equal(as.integer(returned_id), as.integer(before$id[[1]]))
  testthat::expect_equal(after$file_path[[1]], before$file_path[[1]])
  testthat::expect_false(identical(after$hash[[1]], before$hash[[1]]))
  testthat::expect_equal(after$category[[1]], "Comparator")

  # Default still errors on duplicate label
  testthat::expect_error(
    manifest$addAtlasCohort(atlasId = 100L, label = "Atlas Cohort", category = "Target",
                            atlasConnection = conn_v2),
    regexp = "already in use"
  )
})

# Testing: upsert identity guards catch accidental label collisions across routes and types.
testthat::test_that("upsert guards reject accidental label collisions", {
  setup <- cm_test_new_manifest("mgmt-collision-guards")
  manifest <- setup$manifest
  jsons <- cm_test_atlas_fixture_jsons()

  conn_atlas <- cm_test_fake_atlas_connection(list("100" = jsons$v1, "200" = jsons$v2))
  manifest$addAtlasCohort(atlasId = 100L, label = "Atlas Cohort", category = "Target",
                          atlasConnection = conn_atlas)
  before <- cm_test_get_manifest_row(manifest, "Atlas Cohort")

  # Different atlasId under an existing label: rejected, nothing changed
  testthat::expect_error(
    manifest$addAtlasCohort(atlasId = 200L, label = "Atlas Cohort", category = "Target",
                            atlasConnection = conn_atlas, stopIfExists = FALSE),
    regexp = "registered as ATLAS id"
  )
  testthat::expect_equal(cm_test_get_manifest_row(manifest, "Atlas Cohort")$hash[[1]], before$hash[[1]])

  # Same atlasId under a new label: rejected as a duplicate import
  testthat::expect_error(
    manifest$addAtlasCohort(atlasId = 100L, label = "Different Name", category = "Target",
                            atlasConnection = conn_atlas),
    regexp = "already registered"
  )

  # Capr update targeting an ATLAS-registered cohort: rejected
  capr_cohort <- cm_test_make_minimal_capr_cohort()
  testthat::expect_error(
    manifest$updateCaprCohort(capr_cohort, label = "Atlas Cohort"),
    regexp = "not registered via Capr"
  )
})

# Testing: derived upsert rejects a build under an existing label of a different cohort type.
testthat::test_that("derived upsert rejects cohort type change", {
  setup <- cm_test_seed_parent_with_union("mgmt-type-guard")
  manifest <- setup$manifest

  population <- manifest$queryCohortsByLabel("Capr T2D", matchType = "exact")
  exclude <- manifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")

  testthat::expect_error(
    manifest$buildComplementCohort(
      label = "Capr_T2D_or_CKD",
      category = "Derived Cohorts",
      populationCohortEntry = population,
      excludeCohortEntries = exclude,
      stopIfExists = FALSE
    ),
    regexp = "this builder creates"
  )
})

# Testing: updateAtlasCohorts syncs changed remote definitions (the always-run template step).
testthat::test_that("updateAtlasCohorts syncs changed definitions in place", {
  setup <- cm_test_new_manifest("mgmt-atlas-sync")
  manifest <- setup$manifest
  jsons <- cm_test_atlas_fixture_jsons()

  conn_v1 <- cm_test_fake_atlas_connection(list("100" = jsons$v1))
  manifest$addAtlasCohort(atlasId = 100L, label = "Atlas Cohort", category = "Target",
                          atlasConnection = conn_v1)
  before <- cm_test_get_manifest_row(manifest, "Atlas Cohort")

  # Remote unchanged: nothing happens
  manifest$updateAtlasCohorts(conn_v1)
  testthat::expect_equal(cm_test_get_manifest_row(manifest, "Atlas Cohort")$hash[[1]], before$hash[[1]])

  # Remote changed: definition updated in place
  conn_v2 <- cm_test_fake_atlas_connection(list("100" = jsons$v2))
  manifest$updateAtlasCohorts(conn_v2)
  after <- cm_test_get_manifest_row(manifest, "Atlas Cohort")
  testthat::expect_equal(after$id[[1]], before$id[[1]])
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
