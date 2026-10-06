# Testing: post-processing snapshots each database's own cohort manifest and
# validates each database's results against it.

pp_setup_two_manifest_repo <- function(env = parent.frame()) {
  fixtures <- fs::path_abs(testthat::test_path("test_files"))
  ctx <- make_test_repo_for_file_creation("pp_repo")
  repo <- ctx$repo_path
  withr::defer(fs::dir_delete(ctx$root_dir), envir = env)
  withr::local_dir(repo, .local_envir = env)

  addBlock(
    makeBlock(
      configBlockName = "db_second",
      cdmDatabaseSchema = "cdm_second",
      databaseName = "db_second_name",
      cohortTable = "cohort_second",
      workDatabaseSchema = "work_second",
      cohortManifestPath = "inputs/cohorts/db_second/cohortManifest.sqlite"
    ),
    configFilePath = fs::path(repo, "config.yml")
  )

  add_cohort <- function(manifest, folder, fixture, label) {
    json_path <- fs::path(repo, folder, "json", fixture)
    fs::dir_create(fs::path_dir(json_path))
    fs::file_copy(fs::path(fixtures, fixture), json_path)
    suppressMessages(manifest$addCirceCohort(filePath = json_path, label = label, category = "Target"))
  }
  first <- suppressMessages(initCohortManifest(repo, configBlock = "db_placeholder"))
  second <- suppressMessages(initCohortManifest(repo, configBlock = "db_second"))
  add_cohort(first, "inputs/cohorts", "ckd.json", "CKD")
  add_cohort(second, "inputs/cohorts/db_second", "ckd.json", "CKD")
  add_cohort(second, "inputs/cohorts/db_second", "t2d.json", "T2D")

  for (db in c("db_name_placeholder", "db_second_name")) {
    counts_dir <- fs::path(repo, "exec/results", db, "dev", "00_buildCohorts")
    fs::dir_create(counts_dir)
    n_cohorts <- if (db == "db_second_name") 2L else 1L
    readr::write_csv(
      data.frame(
        cohort_id = seq_len(n_cohorts),
        cohort_entries = 10L,
        cohort_subjects = 5L
      ),
      fs::path(counts_dir, "cohortCounts.csv")
    )
  }

  repo
}

testthat::test_that("runPostProcessing snapshots each database's cohort manifest", {
  repo <- pp_setup_two_manifest_repo()

  suppressMessages(runPostProcessing(
    pipelineVersion = "dev",
    dbIds = c("db_placeholder", "db_second"),
    resultsPath = fs::path(repo, "exec/results"),
    exportPath = fs::path(repo, "dissemination/export/merge"),
    cohortsFolderPath = repo
  ))

  export_dir <- fs::path(repo, "dissemination/export/merge/vdev")
  snapshot <- readr::read_csv(fs::path(export_dir, "cohortManifestSnapshot.csv"), show_col_types = FALSE)
  testthat::expect_equal(names(snapshot)[1], "databaseId")
  testthat::expect_equal(
    as.vector(table(snapshot$databaseId)[c("db_name_placeholder", "db_second_name")]),
    c(1L, 2L)
  )

  database_info <- readr::read_csv(fs::path(export_dir, "databaseInfo.csv"), show_col_types = FALSE)
  testthat::expect_equal(
    database_info$cohortManifestPath,
    c("inputs/cohorts/cohortManifest.sqlite", "inputs/cohorts/db_second/cohortManifest.sqlite")
  )

  validation <- readr::read_csv(fs::path(export_dir, "qc_cohortValidation.csv"), show_col_types = FALSE)
  testthat::expect_equal(nrow(validation), 3L)
  testthat::expect_true(all(validation$validationStatus == "OK"))
})

testthat::test_that("validateCohortResults checks each database against its own manifest snapshot", {
  export_dir <- withr::local_tempdir()
  readr::write_csv(
    data.frame(databaseId = c("db_a", "db_b", "db_b"), id = c(1L, 1L, 2L), label = c("CKD", "CKD", "T2D")),
    fs::path(export_dir, "cohortManifestSnapshot.csv")
  )
  readr::write_csv(
    data.frame(databaseId = "db_a", cohort_id = c(1L, 2L), cohort_entries = 10L, cohort_subjects = 5L),
    fs::path(export_dir, "cohortCounts.csv")
  )

  validation <- suppressMessages(validateCohortResults(exportPath = export_dir))

  testthat::expect_equal(names(validation)[1], "databaseId")
  testthat::expect_equal(validation$validationStatus, c("OK", "Missing", "Missing"))
})

testthat::test_that("validateCohortResults still reads a snapshot without databaseId", {
  export_dir <- withr::local_tempdir()
  readr::write_csv(
    data.frame(id = c(1L, 2L), label = c("CKD", "T2D")),
    fs::path(export_dir, "cohortManifestSnapshot.csv")
  )
  readr::write_csv(
    data.frame(databaseId = "db_a", cohort_id = 1L, cohort_entries = 10L, cohort_subjects = 5L),
    fs::path(export_dir, "cohortCounts.csv")
  )

  validation <- suppressMessages(validateCohortResults(exportPath = export_dir))

  testthat::expect_false("databaseId" %in% names(validation))
  testthat::expect_equal(validation$validationStatus, c("OK", "Missing"))
})
