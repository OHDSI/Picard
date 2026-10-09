# Purpose: Build a minimal temp project with dissemination scripts.
sds_test_project <- function(scripts, env = parent.frame()) {
  root <- fs::file_temp(pattern = "picard-sds-")
  diss_dir <- fs::path(root, "dissemination", "pretty", "R")
  fs::dir_create(diss_dir)
  for (name in names(scripts)) {
    writeLines(scripts[[name]], fs::path(diss_dir, name))
  }
  withr::defer(fs::dir_delete(root), envir = env)
  withr::defer(suppressWarnings(rm("disseminationEnv", envir = globalenv())), envir = env)
  root
}

sds_source <- function(root, ...) {
  sourceDisseminationScripts(
    projectPath = root,
    pipelineVersion = "1.0.0",
    outputPath = fs::path(root, "dissemination/pretty"),
    verbose = FALSE,
    ...
  )
}

# Testing: by default a failing dissemination script stops the run, so main.R
# cannot carry on with partial output.
testthat::test_that("sourceDisseminationScripts stops at the first failing script by default", {
  root <- sds_test_project(c(
    "01_fail.R" = "stop('format boom')",
    "02_after.R" = "sds_test_marker <- 'ran'"
  ))

  err <- testthat::expect_error(sds_source(root), regexp = "01_fail.R")
  testthat::expect_match(conditionMessage(err$parent), "format boom")
  testthat::expect_false(exists("sds_test_marker", envir = globalenv()))
})

# Testing: stopOnError = FALSE warns, continues, and records the error.
testthat::test_that("sourceDisseminationScripts warns and continues when stopOnError = FALSE", {
  root <- sds_test_project(c(
    "01_fail.R" = "stop('format {boom}')",
    "02_after.R" = "sds_test_marker <- 'ran'"
  ))
  withr::defer(rm("sds_test_marker", envir = globalenv()))

  testthat::expect_warning(
    res <- sds_source(root, stopOnError = FALSE),
    regexp = "01_fail.R"
  )

  testthat::expect_equal(
    res$error_summary,
    list("dissemination/pretty/R/01_fail.R" = "format {boom}")
  )
  testthat::expect_length(res$sourced_files, 1)
  testthat::expect_equal(get("sds_test_marker", envir = globalenv()), "ran")
})
