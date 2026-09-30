# Purpose: Build a minimal temp project containing all six required input
# builder scripts, each a no-op.
sibs_required_scripts <- c(
  "inputs/conceptSets/R/import_atlas_concept_set.R",
  "inputs/conceptSets/R/import_capr_concept_set.R",
  "inputs/cohorts/R/import_atlas_cohort.R",
  "inputs/cohorts/R/import_capr_cohort.R",
  "inputs/cohorts/R/import_sql_cohort.R",
  "inputs/cohorts/R/build_dependent_cohorts.R"
)

sibs_test_project <- function(test_name = "sibs", env = parent.frame()) {
  root <- fs::file_temp(pattern = paste0("picard-", test_name, "-"))
  fs::dir_create(fs::path(root, "inputs", "cohorts", "R"))
  fs::dir_create(fs::path(root, "inputs", "conceptSets", "R"))
  for (script in sibs_required_scripts) {
    writeLines("invisible(NULL)", fs::path(root, script))
  }
  withr::defer(fs::dir_delete(root), envir = env)
  withr::defer(suppressWarnings(rm("inputBuilderEnv", envir = globalenv())), envir = env)
  return(root)
}

# Testing: sourceInputBuilderScripts sources every required script on success.
testthat::test_that("sourceInputBuilderScripts sources scripts in order on success", {
  root <- sibs_test_project("sibs-ok")
  writeLines(
    "sibs_test_marker <- 'ran'",
    fs::path(root, "inputs", "cohorts", "R", "import_sql_cohort.R")
  )
  withr::defer(rm("sibs_test_marker", envir = globalenv()))

  res <- sourceInputBuilderScripts(projectPath = root, verbose = FALSE)

  testthat::expect_equal(
    as.character(fs::path_rel(res$sourced_files, root)),
    sibs_required_scripts
  )
  testthat::expect_length(res$error_summary, 0)
  testthat::expect_equal(get("sibs_test_marker", envir = globalenv()), "ran")
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
    sourceInputBuilderScripts(projectPath = root, verbose = FALSE),
    regexp = "input builder script"
  )

  # Both failures are reported in one pass, not just the first
  msg <- conditionMessage(err)
  testthat::expect_true(grepl("concept set boom", msg, fixed = TRUE))
  testthat::expect_true(grepl("cohort boom", msg, fixed = TRUE))
})

# Testing: a missing required script aborts before anything is sourced.
testthat::test_that("sourceInputBuilderScripts aborts when a required script is missing", {
  root <- sibs_test_project("sibs-missing")
  fs::file_delete(fs::path(root, "inputs", "cohorts", "R", "import_capr_cohort.R"))
  writeLines(
    "sibs_test_marker <- 'ran'",
    fs::path(root, "inputs", "conceptSets", "R", "import_atlas_concept_set.R")
  )

  err <- testthat::expect_error(
    sourceInputBuilderScripts(projectPath = root, verbose = FALSE),
    regexp = "missing or misnamed"
  )
  msg <- conditionMessage(err)
  testthat::expect_true(grepl("import_capr_cohort.R", msg, fixed = TRUE))
  testthat::expect_true(grepl('type = "importCapr", category = "cohorts"', msg, fixed = TRUE))
  testthat::expect_false(exists("sibs_test_marker", envir = globalenv()))
})

# Testing: an unrecognized script (e.g. the legacy dependent-cohorts name) aborts
# instead of being silently skipped.
testthat::test_that("sourceInputBuilderScripts aborts on unrecognized builder scripts", {
  root <- sibs_test_project("sibs-legacy")
  fs::file_move(
    fs::path(root, "inputs", "cohorts", "R", "build_dependent_cohorts.R"),
    fs::path(root, "inputs", "cohorts", "R", "build_dependent_cohorts_cohort.R")
  )

  err <- testthat::expect_error(
    sourceInputBuilderScripts(projectPath = root, verbose = FALSE),
    regexp = "missing or misnamed"
  )
  msg <- conditionMessage(err)
  testthat::expect_true(grepl("Unrecognized builder script", msg, fixed = TRUE))
  testthat::expect_true(grepl("Rename", msg, fixed = TRUE))
})

# Testing: helper code in a subfolder is not treated as a builder script.
testthat::test_that("sourceInputBuilderScripts ignores scripts in subfolders", {
  root <- sibs_test_project("sibs-src")
  fs::dir_create(fs::path(root, "inputs", "cohorts", "R", "src"))
  writeLines("stop('should not be sourced')", fs::path(root, "inputs", "cohorts", "R", "src", "helpers.R"))

  testthat::expect_no_error(sourceInputBuilderScripts(projectPath = root, verbose = FALSE))
})

# Testing: builder scripts run once per config block, each seeing its own block
# and the pipeline version via inputBuilderEnv.
testthat::test_that("sourceInputBuilderScripts runs scripts once per config block", {
  root <- sibs_test_project("sibs-env")
  writeLines(
    "sibs_test_seen <- c(get0('sibs_test_seen', envir = globalenv()), paste(inputBuilderEnv$configBlock, inputBuilderEnv$pipelineVersion))",
    fs::path(root, "inputs", "cohorts", "R", "import_sql_cohort.R")
  )
  withr::defer(rm("sibs_test_seen", envir = globalenv()))

  res <- sourceInputBuilderScripts(
    projectPath = root,
    configBlock = c("db_a", "db_b"),
    pipelineVersion = "dev",
    verbose = FALSE
  )

  testthat::expect_equal(get("sibs_test_seen", envir = globalenv()), c("db_a dev", "db_b dev"))
  testthat::expect_length(res$sourced_files, 6)
  testthat::expect_equal(res$config_blocks, c("db_a", "db_b"))
})

# Testing: failures are reported per config block.
testthat::test_that("sourceInputBuilderScripts reports failures per config block", {
  root <- sibs_test_project("sibs-env-fail")
  writeLines(
    "if (inputBuilderEnv$configBlock == 'db_b') stop('db_b boom')",
    fs::path(root, "inputs", "cohorts", "R", "import_sql_cohort.R")
  )

  err <- testthat::expect_error(
    sourceInputBuilderScripts(
      projectPath = root,
      configBlock = c("db_a", "db_b"),
      verbose = FALSE
    ),
    regexp = "1 input builder script"
  )
  testthat::expect_true(grepl("[db_b]", conditionMessage(err), fixed = TRUE))
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

# Testing: the builder scripts a new study is initialized with run cleanly
# before anyone has populated them (no manifests, no ATLAS credentials), and
# keep running cleanly on later runs across several config blocks.
testthat::test_that("unpopulated builder scripts in a new study run without error", {
  ctx <- make_test_repo_for_file_creation("sibs_fresh_repo")
  repo <- ctx$repo_path
  withr::defer(fs::dir_delete(ctx$root_dir))
  withr::local_dir(repo)
  withr::local_envvar(HOME = withr::local_tempdir())
  testthat::local_mocked_bindings(
    here = function(...) fs::path(repo, ...),
    .package = "here"
  )
  globals_before <- ls(globalenv(), all.names = TRUE)
  withr::defer(rm(
    list = setdiff(ls(globalenv(), all.names = TRUE), globals_before),
    envir = globalenv()
  ))

  res <- suppressMessages(
    sourceInputBuilderScripts(projectPath = repo, configBlock = "db_placeholder", verbose = FALSE)
  )

  testthat::expect_length(res$sourced_files, 6)
  testthat::expect_true(fs::file_exists(fs::path(repo, "inputs/cohorts/cohortManifest.sqlite")))
  testthat::expect_true(fs::file_exists(fs::path(repo, "inputs/conceptSets/conceptSetManifest.sqlite")))

  testthat::expect_no_error(suppressMessages(
    sourceInputBuilderScripts(projectPath = repo, configBlock = c("db_a", "db_b"), verbose = FALSE)
  ))
})
