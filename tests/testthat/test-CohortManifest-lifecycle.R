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
