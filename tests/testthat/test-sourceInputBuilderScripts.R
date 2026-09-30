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

# Testing: builder scripts run once per config block, each seeing its own block
# and the pipeline version via inputBuilderEnv.
testthat::test_that("sourceInputBuilderScripts runs scripts once per config block", {
  root <- sibs_test_project("sibs-env")
  writeLines(
    "sibs_test_seen <- c(get0('sibs_test_seen', envir = globalenv()), paste(inputBuilderEnv$configBlock, inputBuilderEnv$pipelineVersion))",
    fs::path(root, "inputs", "cohorts", "R", "import_sql_cohort.R")
  )
  withr::defer(rm(list = c("sibs_test_seen", "inputBuilderEnv"), envir = globalenv()))

  res <- sourceInputBuilderScripts(
    projectPath = root,
    configBlock = c("db_a", "db_b"),
    pipelineVersion = "dev",
    verbose = FALSE,
    warnMissing = FALSE
  )

  testthat::expect_equal(get("sibs_test_seen", envir = globalenv()), c("db_a dev", "db_b dev"))
  testthat::expect_length(res$sourced_files, 1)
  testthat::expect_equal(res$config_blocks, c("db_a", "db_b"))
})

# Testing: failures are reported per config block.
testthat::test_that("sourceInputBuilderScripts reports failures per config block", {
  root <- sibs_test_project("sibs-env-fail")
  writeLines(
    "if (inputBuilderEnv$configBlock == 'db_b') stop('db_b boom')",
    fs::path(root, "inputs", "cohorts", "R", "import_sql_cohort.R")
  )
  withr::defer(rm("inputBuilderEnv", envir = globalenv()))

  err <- testthat::expect_error(
    sourceInputBuilderScripts(
      projectPath = root,
      configBlock = c("db_a", "db_b"),
      verbose = FALSE,
      warnMissing = FALSE
    ),
    regexp = "1 input builder script"
  )
  testthat::expect_true(grepl("[db_b]", conditionMessage(err), fixed = TRUE))
})

# Testing: a builder script saved under the old dependent-cohorts name is flagged.
testthat::test_that("sourceInputBuilderScripts warns about the legacy dependent cohorts file name", {
  root <- sibs_test_project("sibs-legacy")
  writeLines("NULL", fs::path(root, "inputs", "cohorts", "R", "build_dependent_cohorts_cohort.R"))
  withr::defer(rm("inputBuilderEnv", envir = globalenv()))

  testthat::expect_warning(
    sourceInputBuilderScripts(projectPath = root, verbose = FALSE, warnMissing = FALSE),
    regexp = "build_dependent_cohorts"
  )
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
