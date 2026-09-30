# Purpose: Build a minimal temp project with the input builder folder structure.
sibs_test_project <- function(test_name = "sibs") {
  root <- fs::file_temp(pattern = paste0("picard-", test_name, "-"))
  fs::dir_create(fs::path(root, "inputs", "cohorts", "R"))
  fs::dir_create(fs::path(root, "inputs", "conceptSets", "R"))
  return(root)
}

# Testing: sourceInputBuilderScripts sources scripts and reports them on success.
testthat::test_that("sourceInputBuilderScripts sources scripts in order on success", {
  root <- sibs_test_project("sibs-ok")
  writeLines(
    "sibs_test_marker <- 'ran'",
    fs::path(root, "inputs", "cohorts", "R", "import_sql_cohort.R")
  )

  res <- sourceInputBuilderScripts(projectPath = root, verbose = FALSE, warnMissing = FALSE)

  testthat::expect_length(res$sourced_files, 1)
  testthat::expect_length(res$error_summary, 0)
  testthat::expect_equal(get("sibs_test_marker", envir = globalenv()), "ran")
  rm("sibs_test_marker", envir = globalenv())
})

# Testing: a failing builder script aborts the run so the pipeline cannot start,
# and all script errors are reported together.
testthat::test_that("sourceInputBuilderScripts aborts when a builder script fails", {
  root <- sibs_test_project("sibs-fail")
  writeLines(
    "stop('concept set boom')",
    fs::path(root, "inputs", "conceptSets", "R", "import_atlas_concept_set.R")
  )
  writeLines(
    "stop('cohort boom')",
    fs::path(root, "inputs", "cohorts", "R", "import_sql_cohort.R")
  )

  err <- testthat::expect_error(
    sourceInputBuilderScripts(projectPath = root, verbose = FALSE, warnMissing = FALSE),
    regexp = "input builder script"
  )

  # Both failures are reported in one pass, not just the first
  msg <- conditionMessage(err)
  testthat::expect_true(grepl("concept set boom", msg, fixed = TRUE))
  testthat::expect_true(grepl("cohort boom", msg, fixed = TRUE))
})

# Testing: configBlock and pipelineVersion are exposed to builder scripts via
# inputBuilderEnv so they do not need to be hard-coded.
testthat::test_that("sourceInputBuilderScripts exposes configBlock and pipelineVersion", {
  root <- sibs_test_project("sibs-env")
  writeLines(
    "sibs_test_env <- inputBuilderEnv",
    fs::path(root, "inputs", "cohorts", "R", "import_sql_cohort.R")
  )
  withr::defer(rm(list = c("sibs_test_env", "inputBuilderEnv"), envir = globalenv()))

  res <- sourceInputBuilderScripts(
    projectPath = root,
    configBlock = c("db_a", "db_b"),
    pipelineVersion = "dev",
    verbose = FALSE,
    warnMissing = FALSE
  )

  env <- get("sibs_test_env", envir = globalenv())
  testthat::expect_equal(env$configBlock, c("db_a", "db_b"))
  testthat::expect_equal(env$pipelineVersion, "dev")
  testthat::expect_identical(res$inputBuilderEnv, env)
})

# Testing: pipelineVersion falls back to the version recorded in config.yml.
testthat::test_that("createInputBuilderEnv defaults pipelineVersion from config.yml", {
  root <- sibs_test_project("sibs-version")
  writeLines(
    c("default:", "  version: 1.2.0"),
    fs::path(root, "config.yml")
  )

  env <- createInputBuilderEnv(projectPath = root, verbose = FALSE)

  testthat::expect_null(env$configBlock)
  testthat::expect_equal(env$pipelineVersion, "1.2.0")
})
