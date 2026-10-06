# Testing: path helper creates expected temp directory structure for test manifests.
testthat::test_that("cm_test_make_manifest_paths creates required directories", {
  paths <- cm_test_make_manifest_paths("lifecycle-paths")

  testthat::expect_true(fs::dir_exists(paths$root))
  testthat::expect_true(fs::dir_exists(paths$inputs_dir))
  testthat::expect_true(fs::dir_exists(paths$cohorts_dir))
  testthat::expect_true(fs::dir_exists(paths$sql_dir))
  testthat::expect_true(fs::dir_exists(paths$json_dir))
})

# Testing: constructor helper returns CohortManifest with valid db path.
testthat::test_that("cm_test_new_manifest returns manifest and path bundle", {
  setup <- cm_test_new_manifest("lifecycle-new")

  testthat::expect_s3_class(setup$manifest, "CohortManifest")
  testthat::expect_equal(setup$manifest$getDbPath(), setup$paths$db_path)
})

# Testing: getManifest returns in-memory CohortDef list aligned with nCohorts.
testthat::test_that("getManifest returns list matching nCohorts", {
  setup <- cm_test_seed_manifest_for_queries("lifecycle-getmanifest")
  manifest <- setup$manifest

  items <- manifest$getManifest()

  testthat::expect_type(items, "list")
  testthat::expect_equal(length(items), manifest$nCohorts())
})

# Testing: reloadFromDb refreshes memory and returns self invisibly.
testthat::test_that("reloadFromDb returns self", {
  setup <- cm_test_seed_manifest_for_queries("lifecycle-reload")
  manifest <- setup$manifest

  out <- manifest$reloadFromDb()

  testthat::expect_identical(out, manifest)
})

# Testing: set/get execution settings stores and retrieves arbitrary settings object.
testthat::test_that("setExecutionSettings and getExecutionSettings round-trip", {
  setup <- cm_test_new_manifest("lifecycle-exec-settings")
  manifest <- setup$manifest

  settings_obj <- list(db = "mock", schema = "work")
  manifest$setExecutionSettings(settings_obj)

  testthat::expect_identical(manifest$getExecutionSettings(), settings_obj)
})

# Testing: set/get atlas connection stores and retrieves atlas connection object.
testthat::test_that("setAtlasConnection and getAtlasConnection round-trip", {
  setup <- cm_test_new_manifest("lifecycle-atlas-settings")
  manifest <- setup$manifest

  atlas_obj <- list(baseUrl = "https://atlas.example.org")
  out <- manifest$setAtlasConnection(atlas_obj)

  testthat::expect_identical(out, manifest)
  testthat::expect_identical(manifest$getAtlasConnection(), atlas_obj)
})

# Testing: active-label uniqueness is enforced for cohort registration.
testthat::test_that("duplicate active labels are rejected", {
  setup <- cm_test_new_manifest("lifecycle-label-unique")
  manifest <- setup$manifest
  paths <- setup$paths

  cm_test_add_sql_cohort(manifest, paths, label = "Duplicate Label", category = "Test")

  testthat::expect_error(
    cm_test_add_circe_cohort(manifest, paths, label = "Duplicate Label", category = "Test", fixture_name = "ckd.json")
  )
})

# Testing: active-filepath uniqueness is enforced for cohort registration.
testthat::test_that("duplicate active file paths are rejected", {
  setup <- cm_test_new_manifest("lifecycle-filepath-unique")
  manifest <- setup$manifest
  paths <- setup$paths

  cm_test_add_sql_cohort(
    manifest = manifest,
    paths = paths,
    label = "SQL Cohort One",
    category = "Test",
    fixture_name = "my_custom_cohort.sql"
  )

  testthat::expect_error(
    cm_test_add_sql_cohort(
      manifest = manifest,
      paths = paths,
      label = "SQL Cohort Two",
      category = "Test",
      fixture_name = "my_custom_cohort.sql"
    )
  )
})

# ── Path portability ──────────────────────────────────────────────────────────

# Testing: the isolated test harness produces a manifest whose project root is
# discovered structurally (step 1).
testthat::test_that("manifest resolves its project root from the isolated harness", {
  setup <- cm_test_new_manifest("lifecycle-projroot")

  testthat::expect_equal(
    fs::path_norm(setup$manifest$getProjectRoot()),
    fs::path_norm(setup$paths$root)
  )
})

# Testing: new registrations store a repo-root-relative path regardless of the
# working directory the caller registered from (step 4).
testthat::test_that("registration stores a repo-root-relative path from any working directory", {
  setup <- cm_test_new_manifest("lifecycle-register-cwd")
  paths <- setup$paths
  fixture <- testthat::test_path("test_files", "ckd.json")
  testthat::skip_if_not(fs::file_exists(fixture))
  fs::file_copy(fixture, fs::path(paths$json_dir, "ckd.json"))

  nested <- fs::path(paths$root, "analysis", "deep", "here")
  fs::dir_create(nested)

  withr::with_dir(nested, {
    setup$manifest$addCirceCohort(
      filePath = fs::path(paths$json_dir, "ckd.json"),
      label = "CKD", category = "Target"
    )
  })

  row <- cm_test_get_manifest_row(setup$manifest, "CKD")
  testthat::expect_equal(row$file_path[[1]], "inputs/cohorts/json/ckd.json")
})

# Testing: a manifest loads and its cohorts resolve when opened from a working
# directory unrelated to the study repo (step 3).
testthat::test_that("manifest loads from an unrelated working directory", {
  setup <- cm_test_seed_manifest_for_queries("lifecycle-load-unrelated")
  db_path <- setup$manifest$getDbPath()
  n_expected <- setup$manifest$nCohorts()

  withr::with_dir(withr::local_tempdir(), {
    reopened <- CohortManifest$new(dbPath = db_path)
    testthat::expect_equal(length(reopened$getManifest()), n_expected)
    testthat::expect_true(
      all(vapply(reopened$getManifest(), function(cd) fs::file_exists(cd$getFilePath()), logical(1)))
    )
  })
})

# Testing: legacy stored path conventions still resolve on load (step 2/3).
testthat::test_that("legacy stored path conventions resolve on load", {
  setup <- cm_test_seed_manifest_for_queries("lifecycle-legacy-paths")
  manifest <- setup$manifest
  root <- manifest$getProjectRoot()

  rows <- cm_test_all_rows(manifest)
  circe_id <- rows$id[rows$cohort_type == "circe"][1]
  sql_id   <- rows$id[rows$cohort_type == "custom"][1]
  canonical_circe <- rows$file_path[rows$id == circe_id]
  canonical_sql   <- rows$file_path[rows$id == sql_id]

  # manifest-folder-relative (e.g. "json/ckd.json", "sql/foo.sql")
  cm_test_set_stored_path(manifest, circe_id, sub("^inputs/cohorts/", "", canonical_circe))
  cm_test_set_stored_path(manifest, sql_id, sub("^inputs/cohorts/", "", canonical_sql))
  reopened <- CohortManifest$new(dbPath = manifest$getDbPath())
  testthat::expect_equal(length(reopened$getManifest()), nrow(rows))

  # absolute path
  cm_test_set_stored_path(manifest, circe_id, fs::path(root, canonical_circe))
  reopened <- CohortManifest$new(dbPath = manifest$getDbPath())
  testthat::expect_equal(length(reopened$getManifest()), nrow(rows))
})

# Testing: a stored path pointing at a missing file is reported, never silently
# hashed to a sentinel (step 3/7).
testthat::test_that("missing cohort file is reported on load, not silently hashed", {
  setup <- cm_test_seed_manifest_for_queries("lifecycle-missing-file")
  manifest <- setup$manifest
  rows <- cm_test_all_rows(manifest)
  circe_id <- rows$id[rows$cohort_type == "circe"][1]
  original_hash <- rows$hash[rows$id == circe_id]

  cm_test_set_stored_path(manifest, circe_id, "inputs/cohorts/json/does_not_exist.json")

  testthat::expect_message(
    reopened <- CohortManifest$new(dbPath = manifest$getDbPath()),
    "file missing"
  )
  testthat::expect_equal(length(reopened$getManifest()), nrow(rows) - 1L)

  # the stored hash is untouched — nothing recomputed against a missing file
  after <- cm_test_all_rows(manifest)
  testthat::expect_equal(after$hash[after$id == circe_id], original_hash)
})

# Testing: invalid query argument types raise assertion errors.
testthat::test_that("queryCohortsByIds validates input type", {
  setup <- cm_test_seed_manifest_for_queries("lifecycle-query-validation")
  manifest <- setup$manifest

  testthat::expect_error(manifest$queryCohortsByIds("not-an-id"))
})

# Testing: Atlas methods are deferred for this test wave and intentionally skipped.
testthat::test_that("Atlas methods deferred", {
  testthat::skip("Deferred: Atlas API methods are out of scope for this wave (step 9).")
  testthat::expect_true(TRUE)
})

# Testing: executionSettings DBMS methods are out-of-scope and intentionally skipped.
testthat::test_that("executionSettings-dependent methods skipped", {
  testthat::skip("Out-of-scope: DBMS executionSettings methods are intentionally skipped in this wave (step 9).")
  testthat::expect_true(TRUE)
})

# Testing: each config block can name its own cohort manifest via cohortManifestPath.
cm_test_write_config <- function(root, lines) {
  readr::write_lines(lines, fs::path(root, "config.yml"))
}

testthat::test_that("getCohortManifestPath resolves a block's cohortManifestPath and falls back to the default", {
  paths <- cm_test_make_manifest_paths("lifecycle-manifest-path")
  cm_test_write_config(paths$root, c(
    "default:",
    "  projectName: test",
    "db_a:",
    "  cohortTable: cohort_a",
    "  cohortManifestPath: inputs/cohorts/db_a/cohortManifest.sqlite",
    "db_b:",
    "  cohortTable: cohort_b"
  ))
  root <- findStudyProjectRoot(paths$root)

  testthat::expect_equal(
    getCohortManifestPath("db_a", projectPath = paths$root),
    fs::path(root, "inputs/cohorts/db_a/cohortManifest.sqlite")
  )
  testthat::expect_equal(
    getCohortManifestPath("db_b", projectPath = paths$root),
    fs::path(root, "inputs/cohorts/cohortManifest.sqlite")
  )
  testthat::expect_equal(
    getCohortManifestPath(projectPath = paths$root),
    fs::path(root, "inputs/cohorts/cohortManifest.sqlite")
  )
  testthat::expect_error(
    getCohortManifestPath("db_missing", projectPath = paths$root),
    "not found"
  )
})

testthat::test_that("getCohortManifestPath inherits cohortManifestPath from the default block", {
  paths <- cm_test_make_manifest_paths("lifecycle-manifest-path-default")
  cm_test_write_config(paths$root, c(
    "default:",
    "  cohortManifestPath: inputs/cohorts/shared/cohortManifest.sqlite",
    "db_a:",
    "  cohortTable: cohort_a"
  ))

  testthat::expect_equal(
    getCohortManifestPath("db_a", projectPath = paths$root),
    fs::path(findStudyProjectRoot(paths$root), "inputs/cohorts/shared/cohortManifest.sqlite")
  )
})

testthat::test_that("getCohortManifestPath rejects two manifests in one folder", {
  paths <- cm_test_make_manifest_paths("lifecycle-manifest-path-shared-folder")
  cm_test_write_config(paths$root, c(
    "default:",
    "  projectName: test",
    "db_a:",
    "  cohortManifestPath: inputs/cohorts/cohortManifest_a.sqlite",
    "db_b:",
    "  cohortManifestPath: inputs/cohorts/cohortManifest_b.sqlite"
  ))

  testthat::expect_error(
    getCohortManifestPath("db_a", projectPath = paths$root),
    "shares its"
  )
  # The default manifest, unused by either block, is not a conflict until it exists
  cm_test_write_config(paths$root, c(
    "db_a:",
    "  cohortManifestPath: inputs/cohorts/db_a/cohortManifest.sqlite"
  ))
  testthat::expect_no_error(getCohortManifestPath(projectPath = paths$root))
  fs::dir_create(fs::path(paths$cohorts_dir, "db_a"))
  fs::file_create(fs::path(paths$cohorts_dir, "db_a", "other.sqlite"))
  testthat::expect_error(
    getCohortManifestPath("db_a", projectPath = paths$root),
    "shares its"
  )
})

testthat::test_that("initCohortManifest and loadCohortManifest use the config block's manifest", {
  paths <- cm_test_make_manifest_paths("lifecycle-manifest-by-block")
  cm_test_write_config(paths$root, c(
    "default:",
    "  projectName: test",
    "db_a:",
    "  cohortManifestPath: inputs/cohorts/db_a/cohortManifest.sqlite",
    "db_b:",
    "  cohortManifestPath: inputs/cohorts/db_b/cohortManifest.sqlite",
    "db_c:",
    "  cohortManifestPath: inputs/cohorts/db_a/cohortManifest.sqlite"
  ))

  manifest_a <- suppressMessages(initCohortManifest(paths$root, configBlock = "db_a"))
  suppressMessages(initCohortManifest(paths$root, configBlock = "db_b"))
  json_a <- fs::path(paths$cohorts_dir, "db_a", "json")
  fs::dir_create(json_a)
  cm_test_add_circe_cohort(manifest_a, list(json_dir = json_a), label = "CKD", fixture_name = "ckd.json")

  testthat::expect_true(fs::file_exists(fs::path(paths$cohorts_dir, "db_a", "cohortManifest.sqlite")))
  testthat::expect_true(fs::file_exists(fs::path(paths$cohorts_dir, "db_b", "cohortManifest.sqlite")))
  testthat::expect_false(fs::file_exists(paths$db_path))

  load <- function(block) {
    suppressMessages(loadCohortManifest(paths$root, configBlock = block))
  }
  testthat::expect_equal(load("db_a")$nCohorts(), 1L)
  testthat::expect_equal(load("db_b")$nCohorts(), 0L)
  testthat::expect_equal(load("db_c")$getDbPath(), load("db_a")$getDbPath())
  testthat::expect_true(fs::file_exists(fs::path(json_a, "ckd.json")))
  testthat::expect_error(
    suppressMessages(loadCohortManifest(paths$root, autoSync = FALSE)),
    "not found"
  )
})
