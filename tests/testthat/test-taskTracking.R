# Testing: .getCohortManifestHash() summarises cohort definitions for task-rerun
# detection. It must be a pure read, deterministic, and independent of where
# cohort files are stored on disk.

testthat::test_that(".getCohortManifestHash returns NA when there is no manifest", {
  setup <- cm_test_new_manifest("tt-hash-nodb")
  fs::file_delete(setup$paths$db_path)

  testthat::expect_true(is.na(.getCohortManifestHash(projectPath = setup$paths$root)))
})

testthat::test_that(".getCohortManifestHash hashes an empty manifest to a stable sentinel", {
  setup <- cm_test_new_manifest("tt-hash-empty")

  h <- .getCohortManifestHash(projectPath = setup$paths$root)

  testthat::expect_type(h, "character")
  testthat::expect_false(is.na(h))
  testthat::expect_identical(h, .getCohortManifestHash(projectPath = setup$paths$root))
})

testthat::test_that(".getCohortManifestHash changes when a cohort is added and is deterministic", {
  setup <- cm_test_new_manifest("tt-hash-add")
  root <- setup$manifest$getProjectRoot()

  cm_test_add_circe_cohort(setup$manifest, setup$paths, label = "CKD", category = "Target",
                           fixture_name = "ckd.json")
  h1 <- .getCohortManifestHash(projectPath = root)
  cm_test_add_circe_cohort(setup$manifest, setup$paths, label = "T2D", category = "Target",
                           fixture_name = "t2d.json")
  h2 <- .getCohortManifestHash(projectPath = root)

  testthat::expect_false(identical(h1, h2))
  testthat::expect_identical(h2, .getCohortManifestHash(projectPath = root))

  # deterministic from an unrelated working directory
  withr::with_dir(withr::local_tempdir(), {
    testthat::expect_identical(.getCohortManifestHash(projectPath = root), h2)
  })
})

testthat::test_that(".getCohortManifestHash is unaffected by a stored path-convention change", {
  setup <- cm_test_seed_manifest_for_queries("tt-hash-pathonly")
  manifest <- setup$manifest
  root <- manifest$getProjectRoot()
  before <- .getCohortManifestHash(projectPath = root)

  rows <- cm_test_all_rows(manifest)
  circe_id <- rows$id[rows$cohort_type == "circe"][1]
  cm_test_set_stored_path(manifest, circe_id,
                          sub("^inputs/cohorts/", "", rows$file_path[rows$id == circe_id]))

  testthat::expect_identical(.getCohortManifestHash(projectPath = root), before)
})

testthat::test_that(".getCohortManifestHash changes when a cohort's content hash changes", {
  setup <- cm_test_seed_manifest_for_queries("tt-hash-content")
  manifest <- setup$manifest
  root <- manifest$getProjectRoot()
  before <- .getCohortManifestHash(projectPath = root)

  rows <- cm_test_all_rows(manifest)
  conn <- DBI::dbConnect(RSQLite::SQLite(), manifest$getDbPath())
  DBI::dbExecute(conn, "UPDATE cohort_manifest SET hash = 'changed' WHERE id = ?",
                 list(rows$id[1]))
  DBI::dbDisconnect(conn)

  testthat::expect_false(identical(.getCohortManifestHash(projectPath = root), before))
})
