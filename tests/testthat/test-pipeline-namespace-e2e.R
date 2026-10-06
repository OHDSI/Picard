# End-to-end regression coverage for the unified pipeline namespace (issue #104).
#
# No database is used: the pre-flight and cohort-generation boundaries are the
# only parts of testStudyPipeline() that touch a connection, so they are mocked.
# Everything else — ExecutionContext construction, createExecutionSettingsFromConfig(),
# execute_task(), setOutputFolder(), task-run-history recording — runs for real,
# which is what lets these tests assert that a single `pipelineVersion` value
# flows identically into the results folder, the cohort table name, and the
# task-history namespace.

pne_setup_repo <- function(env = parent.frame()) {
  ctx <- make_test_repo_for_file_creation("pne_repo")
  repo <- ctx$repo_path
  withr::defer(fs::dir_delete(ctx$root_dir), envir = env)

  # Point the working dir and here::here() at the repo.
  withr::local_dir(repo, .local_envir = env)
  testthat::local_mocked_bindings(
    here = function(...) fs::path(repo, ...),
    .package = "here",
    .env = env
  )

  # A user-level secrets.yml with a sqlite server. createExecutionSettingsFromConfig()
  # builds a (lazy) ConnectionDetails from this but never opens a connection.
  home <- withr::local_tempdir(.local_envir = env)
  fs::dir_create(fs::path(home, ".picard"))
  readr::write_lines(
    c(
      "server_placeholder:",
      "  dbms: sqlite",
      paste0("  server: ", fs::path(home, "cdm.sqlite"))
    ),
    fs::path(home, ".picard", "secrets.yml")
  )
  withr::local_envvar(HOME = home, .local_envir = env)

  repo
}

# Generate a real task file via the template, trim its heavy dependencies, and
# append section-E code that records the names the task actually resolved.
pne_write_task <- function(repo, name = "run stats") {
  makeTaskFile(
    nameOfTask = name,
    author = "tester",
    description = "namespace e2e",
    projectPath = repo,
    openFile = FALSE
  )

  task_files <- fs::dir_ls(fs::path(repo, "analysis/tasks"), glob = "*.R", type = "file")
  task_file <- task_files[[length(task_files)]]

  lines <- readr::read_lines(task_file)
  # Trim template scaffolding this test does not exercise: heavy library() loads
  # and the cohort-manifest read (there is no manifest sqlite in the fixture).
  lines <- lines[!grepl("^library\\((tidyverse|DatabaseConnector)\\)", lines)]
  lines <- lines[!grepl("loadCohortManifest", lines)]
  lines <- lines[!grepl("^cm <-", lines)]
  lines <- c(
    lines,
    "",
    'saveRDS(',
    '  list(cohortTable = executionSettings$cohortTable, outputFolder = as.character(outputFolder)),',
    '  file.path(outputFolder, "derived.rds")',
    ')'
  )
  readr::write_lines(lines, task_file)

  basename(task_file)
}

pne_mock_boundaries <- function(task, env = parent.frame()) {
  testthat::local_mocked_bindings(
    get_current_branch = function() "develop",
    runPreflightChecks = function(...) {
      list(
        lockfileHash = NULL,
        taskFilesToRun = task,
        codeState = list(
          sha = "deadbeefdeadbeef",
          status = "clean",
          ignoredFiles = character(0),
          ignorePaths = character(0)
        )
      )
    },
    generateCohorts = function(...) invisible(data.frame()),
    .env = env
  )
}

pne_read_history <- function(repo) {
  readr::read_csv(
    fs::path(repo, "exec/logs/task_run_history.csv"),
    show_col_types = FALSE,
    progress = FALSE
  )
}


testthat::test_that("testStudyPipeline threads one pipelineVersion into folder, cohort table and history", {
  repo <- pne_setup_repo()
  task <- pne_write_task(repo)
  pne_mock_boundaries(task)

  # "Develop ML" must normalise to "develop_ml" consistently.
  testthat::expect_no_error(
    suppressMessages(
      testStudyPipeline(configBlock = "db_placeholder", pipelineVersion = "Develop ML")
    )
  )

  results_dir <- fs::path(repo, "exec/results/db_name_placeholder/develop_ml")
  testthat::expect_true(fs::dir_exists(results_dir))

  derived <- readRDS(fs::path(results_dir, sub("\\.R$", "", task), "derived.rds"))
  testthat::expect_equal(derived$cohortTable, "cohort_table_placeholder_develop_ml")
  testthat::expect_match(derived$outputFolder, "db_name_placeholder/develop_ml/")

  history <- pne_read_history(repo)
  testthat::expect_setequal(unique(history$pipeline_version), "develop_ml")
  testthat::expect_true(all(history$status %in% c("success", "skipped")))
})


testthat::test_that("testStudyTask uses the same namespace path as the full pipeline", {
  repo <- pne_setup_repo()
  task <- pne_write_task(repo)

  # testStudyTask() builds no ExecutionContext of its own; the namespace has to
  # flow through normalizePipelineVersion() + createExecutionSettingsFromConfig().
  testthat::local_mocked_bindings(
    get_current_branch = function() "develop",
    .env = rlang::current_env()
  )

  testthat::expect_no_error(
    suppressMessages(
      testStudyTask(taskFile = task, configBlock = "db_placeholder", pipelineVersion = "Develop ML")
    )
  )

  derived <- readRDS(fs::path(
    repo, "exec/results/db_name_placeholder/develop_ml", sub("\\.R$", "", task), "derived.rds"
  ))
  testthat::expect_equal(derived$cohortTable, "cohort_table_placeholder_develop_ml")

  history <- pne_read_history(repo)
  testthat::expect_setequal(unique(history$pipeline_version), "develop_ml")
})


testthat::test_that("separate test namespaces stay isolated in results and task history", {
  repo <- pne_setup_repo()
  task <- pne_write_task(repo)

  run_pipeline <- function(version) {
    pne_mock_boundaries(task, env = parent.frame())
    suppressMessages(
      testStudyPipeline(configBlock = "db_placeholder", pipelineVersion = version)
    )
  }

  run_pipeline("develop_ml")
  run_pipeline("develop_ks")

  testthat::expect_true(fs::dir_exists(fs::path(repo, "exec/results/db_name_placeholder/develop_ml")))
  testthat::expect_true(fs::dir_exists(fs::path(repo, "exec/results/db_name_placeholder/develop_ks")))

  history <- pne_read_history(repo)
  testthat::expect_setequal(unique(history$pipeline_version), c("develop_ml", "develop_ks"))
  testthat::expect_equal(sum(history$pipeline_version == "develop_ml"), 1L)
  testthat::expect_equal(sum(history$pipeline_version == "develop_ks"), 1L)
})


testthat::test_that("testStudyPipeline runs builders, cohorts and tasks per config block in order", {
  repo <- pne_setup_repo()
  task <- pne_write_task(repo)
  readr::write_lines(
    c(
      "",
      "db_second:",
      "  dbServer: server_placeholder",
      "  databaseName: db_second_name",
      "  databaseLabel: Second DB",
      "  cdmDatabaseSchema: cdm_second",
      "  vocabDatabaseSchema: cdm_second",
      "  workDatabaseSchema: work_second",
      "  tempEmulationSchema: work_second",
      "  cohortTable: cohort_second"
    ),
    fs::path(repo, "config.yml"),
    append = TRUE
  )

  # The task records itself in the same event log as the mocked builders and
  # cohort generation, so the test sees the true interleaving.
  events_file <- fs::path(repo, "events.txt")
  task_path <- fs::path(repo, "analysis/tasks", task)
  readr::write_lines(
    c(
      readr::read_lines(task_path),
      sprintf('cat("task ", executionSettings$databaseName, "\\n", sep = "", file = "%s", append = TRUE)', events_file)
    ),
    task_path
  )
  log_event <- function(...) cat(..., "\n", sep = "", file = events_file, append = TRUE)

  pne_mock_boundaries(task)
  testthat::local_mocked_bindings(
    sourceInputBuilderScripts = function(configBlock, pipelineVersion, ...) {
      log_event("build ", configBlock, " ", pipelineVersion)
      invisible(NULL)
    },
    generateCohorts = function(executionSettings, ...) {
      log_event("generate ", executionSettings$databaseName)
      invisible(data.frame())
    }
  )

  suppressMessages(
    testStudyPipeline(configBlock = c("db_placeholder", "db_second"), pipelineVersion = "dev")
  )

  testthat::expect_equal(
    readr::read_lines(events_file),
    c(
      "build db_placeholder dev", "generate db_name_placeholder", "task db_name_placeholder",
      "build db_second dev", "generate db_second_name", "task db_second_name"
    )
  )
})


testthat::test_that("testStudyPipeline uses each config block's own cohort manifest", {
  fixture <- fs::path_abs(testthat::test_path("test_files", "ckd.json"))
  repo <- pne_setup_repo()
  task <- pne_write_task(repo)
  readr::write_lines(
    c(
      "",
      "db_second:",
      "  dbServer: server_placeholder",
      "  databaseName: db_second_name",
      "  databaseLabel: Second DB",
      "  cdmDatabaseSchema: cdm_second",
      "  vocabDatabaseSchema: cdm_second",
      "  workDatabaseSchema: work_second",
      "  tempEmulationSchema: work_second",
      "  cohortTable: cohort_second",
      "  cohortManifestPath: inputs/cohorts/db_second/cohortManifest.sqlite"
    ),
    fs::path(repo, "config.yml"),
    append = TRUE
  )

  suppressMessages(initCohortManifest(repo, configBlock = "db_placeholder"))
  second <- suppressMessages(initCohortManifest(repo, configBlock = "db_second"))
  json_path <- fs::path(repo, "inputs/cohorts/db_second/json/ckd.json")
  fs::dir_create(fs::path_dir(json_path))
  fs::file_copy(fixture, json_path)
  suppressMessages(second$addCirceCohort(filePath = json_path, label = "CKD", category = "Target"))

  generated_blocks <- character(0)
  pne_mock_boundaries(task)
  testthat::local_mocked_bindings(
    sourceInputBuilderScripts = function(...) invisible(NULL),
    generateCohorts = function(..., configBlock) {
      generated_blocks <<- c(generated_blocks, configBlock)
      invisible(data.frame())
    }
  )

  suppressMessages(
    testStudyPipeline(configBlock = c("db_placeholder", "db_second"), pipelineVersion = "dev")
  )

  testthat::expect_equal(generated_blocks, c("db_placeholder", "db_second"))

  history <- pne_read_history(repo)
  recorded <- stats::setNames(history$cohort_manifest_hash, history$config_block)
  testthat::expect_false(identical(recorded[["db_placeholder"]], recorded[["db_second"]]))
  testthat::expect_identical(
    recorded[["db_second"]],
    .getCohortManifestHash(projectPath = repo, configBlock = "db_second")
  )
})


testthat::test_that("pre-flight warns rather than fails when the cohort manifest does not exist yet", {
  repo <- pne_setup_repo()
  pne_write_task(repo)
  secrets_path <- fs::path(Sys.getenv("HOME"), ".picard", "secrets.yml")
  readr::write_lines(
    c(readr::read_lines(secrets_path), "  port: 0", "  user: tester", "  password: secret"),
    secrets_path
  )
  testthat::local_mocked_bindings(get_current_branch = function() "develop")
  testthat::expect_false(fs::file_exists(fs::path(repo, "inputs/cohorts/cohortManifest.sqlite")))

  msgs <- character(0)
  testthat::expect_no_error(withCallingHandlers(
    runPreflightChecks(
      configBlock = "db_placeholder",
      pipelineVersion = "dev",
      testMode = TRUE,
      skipRenv = TRUE
    ),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  ))
  testthat::expect_true(any(grepl("~ Cohort manifest +No manifest yet", msgs)))
})


# Forced reruns -------------------------------------------------------------------

# The fixture has no cohort manifest, whose NA hash would force every rerun, so
# pin the input hashes to make an unchanged second run skippable.
pne_mock_stable_hashes <- function(env = parent.frame()) {
  testthat::local_mocked_bindings(
    .getCohortManifestHash = function(...) "cohort-hash",
    .getConceptSetManifestHash = function(...) "concept-set-hash",
    .getRenvLockHash = function(...) "renv-hash",
    .env = env
  )
}

testthat::test_that("forceRerun bypasses change detection in testStudyPipeline", {
  repo <- pne_setup_repo()
  task <- pne_write_task(repo)
  pne_mock_boundaries(task)
  pne_mock_stable_hashes()

  run <- function(...) {
    suppressMessages(testStudyPipeline(configBlock = "db_placeholder", ...))
  }

  run()
  run()
  run(forceRerun = TRUE)
  run(forceRerun = task)

  history <- pne_read_history(repo)
  testthat::expect_identical(history$status, c("success", "skipped", "success", "success"))
})

testthat::test_that("forceRerun rejects task names that are not in the pipeline", {
  repo <- pne_setup_repo()
  task <- pne_write_task(repo)
  pne_mock_boundaries(task)

  testthat::expect_error(
    suppressMessages(testStudyPipeline(configBlock = "db_placeholder", forceRerun = "99_missing.R")),
    "not in this pipeline"
  )
  testthat::expect_false(fs::file_exists(fs::path(repo, "exec/logs/task_run_history.csv")))
})

testthat::test_that("forceRerun bypasses change detection in testStudyTask", {
  repo <- pne_setup_repo()
  task <- pne_write_task(repo)
  pne_mock_stable_hashes()
  testthat::local_mocked_bindings(
    get_current_branch = function() "develop",
    .env = rlang::current_env()
  )

  run <- function(...) {
    suppressMessages(testStudyTask(taskFile = task, configBlock = "db_placeholder", ...))
  }

  run()
  run()
  run(forceRerun = TRUE)

  history <- pne_read_history(repo)
  testthat::expect_identical(history$status, c("success", "skipped", "success"))
})
