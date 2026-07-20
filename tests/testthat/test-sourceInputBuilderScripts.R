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
