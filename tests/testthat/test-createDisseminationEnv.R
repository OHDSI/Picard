# Purpose: Build a minimal temp project with a config.yml carrying a version.
cde_test_project <- function(test_name = "cde", version = NULL) {
  root <- fs::file_temp(pattern = paste0("picard-", test_name, "-"))
  fs::dir_create(fs::path(root, "dissemination", "pretty", "R"))

  if (!is.null(version)) {
    writeLines(
      c("default:", paste0("  version: ", version)),
      fs::path(root, "config.yml")
    )
  }

  return(root)
}

# Testing: the returned object carries exactly the four documented elements and
# derives resultsPath from the supplied version.
testthat::test_that("createDisseminationEnv builds the documented metadata", {
  root <- cde_test_project("cde-basic")

  env <- createDisseminationEnv(
    projectPath = root,
    pipelineVersion = "1.0.0",
    databaseIds = c("database_1", "database_2"),
    outputPath = fs::path(root, "dissemination/pretty"),
    verbose = FALSE
  )

  testthat::expect_named(
    env,
    c("pipelineVersion", "databaseIds", "outputPath", "resultsPath")
  )
  testthat::expect_equal(env$pipelineVersion, "1.0.0")
  testthat::expect_equal(env$databaseIds, c("database_1", "database_2"))
  testthat::expect_equal(
    as.character(env$resultsPath),
    as.character(fs::path(root, "dissemination/export/merge", "v1.0.0"))
  )
})

# Testing: version is read from config.yml when the caller does not supply one.
testthat::test_that("createDisseminationEnv auto-detects the version from config.yml", {
  root <- cde_test_project("cde-config", version = "2.1.0")

  env <- createDisseminationEnv(projectPath = root, verbose = FALSE)

  testthat::expect_equal(env$pipelineVersion, "2.1.0")
  testthat::expect_equal(
    as.character(env$resultsPath),
    as.character(fs::path(root, "dissemination/export/merge", "v2.1.0"))
  )
})

# Testing: a missing config.yml is not an error; resultsPath is simply unknown.
testthat::test_that("createDisseminationEnv tolerates a missing version", {
  root <- cde_test_project("cde-noversion")

  env <- createDisseminationEnv(projectPath = root, verbose = FALSE)

  testthat::expect_null(env$pipelineVersion)
  testthat::expect_null(env$databaseIds)
  testthat::expect_identical(env$resultsPath, NA_character_)
})

# Testing: verbose output reports the metadata, and warns when no version is known.
testthat::test_that("createDisseminationEnv reports metadata when verbose", {
  root <- cde_test_project("cde-verbose", version = "1.2.3")

  testthat::expect_message(
    createDisseminationEnv(projectPath = root, verbose = TRUE),
    regexp = "1.2.3"
  )
  testthat::expect_message(
    createDisseminationEnv(
      projectPath = cde_test_project("cde-verbose-none"),
      verbose = TRUE
    ),
    regexp = "No pipeline version"
  )
})

# Testing: inputs are validated up front.
testthat::test_that("createDisseminationEnv validates its arguments", {
  root <- cde_test_project("cde-assert")

  testthat::expect_error(
    createDisseminationEnv(projectPath = root, pipelineVersion = 1.0, verbose = FALSE)
  )
  testthat::expect_error(
    createDisseminationEnv(projectPath = root, databaseIds = 1L, verbose = FALSE)
  )
  testthat::expect_error(
    createDisseminationEnv(projectPath = root, outputPath = NA, verbose = FALSE)
  )
})

# Testing: sourceDisseminationScripts injects the same object this function
# builds, so an analyst testing a script sees identical metadata.
testthat::test_that("sourceDisseminationScripts uses createDisseminationEnv", {
  root <- cde_test_project("cde-source", version = "3.0.0")
  writeLines(
    "cde_test_marker <- disseminationEnv$resultsPath",
    fs::path(root, "dissemination", "pretty", "R", "01_format.R")
  )

  res <- sourceDisseminationScripts(
    projectPath = root,
    databaseIds = "database_1",
    outputPath = fs::path(root, "dissemination/pretty"),
    verbose = FALSE,
    warnMissing = FALSE
  )

  expected <- createDisseminationEnv(
    projectPath = root,
    databaseIds = "database_1",
    outputPath = fs::path(root, "dissemination/pretty"),
    verbose = FALSE
  )

  testthat::expect_equal(res$disseminationEnv, expected)
  testthat::expect_equal(
    as.character(get("cde_test_marker", envir = globalenv())),
    as.character(expected$resultsPath)
  )

  rm("cde_test_marker", envir = globalenv())
  rm("disseminationEnv", envir = globalenv())
})
