
# Helpers ---------------------------------------------------------------------

cs_test_make_repo <- function() {
  root <- fs::file_temp("picard-codestate-")
  fs::dir_create(root)

  gert::git_init(root)
  gert::git_config_set("user.name", "Picard Test", repo = root)
  gert::git_config_set("user.email", "picard-test@example.org", repo = root)

  fs::dir_create(fs::path(root, "inputs", "cohorts"))
  fs::dir_create(fs::path(root, "analysis", "tasks"))
  fs::dir_create(fs::path(root, "exec", "logs"))

  readr::write_lines("committed", fs::path(root, "inputs", "cohorts", "a.json"))
  readr::write_lines("committed", fs::path(root, "analysis", "tasks", "01_a.R"))

  suppressMessages(gert::git_add(".", repo = root))
  gert::git_commit("initial commit", repo = root)

  as.character(root)
}

# Creates a throwaway repo, moves into it for the duration of the calling test,
# and points here::here() at it so audit-trail writes stay inside the temp repo.
cs_test_local_repo <- function(env = parent.frame()) {
  root <- cs_test_make_repo()

  withr::local_dir(root, .local_envir = env)
  testthat::local_mocked_bindings(
    here = function(...) file.path(root, ...),
    .package = "here",
    .env = env
  )

  root
}

cs_test_dirty_inputs <- function(root) {
  readr::write_lines("churn", fs::path(root, "inputs", "cohorts", "a.json"))
}

cs_test_dirty_analysis <- function(root) {
  readr::write_lines("real edit", fs::path(root, "analysis", "tasks", "01_a.R"))
}


# validateCodeState: default behavior -----------------------------------------

test_that("validateCodeState passes on a clean tree and returns the HEAD sha", {
  cs_test_local_repo()

  result <- suppressMessages(validateCodeState())

  expect_true(result$clean)
  expect_identical(result$status, "clean")
  expect_identical(result$ignoredFiles, character(0))
  expect_true(nchar(result$sha) > 0)
})

test_that("validateCodeState still fails on a dirty tree by default", {
  root <- cs_test_local_repo()
  cs_test_dirty_inputs(root)

  expect_error(suppressMessages(validateCodeState()), "uncommitted changes")
})

test_that("validateCodeState with no ignore paths fails even for inputs churn", {
  root <- cs_test_local_repo()
  cs_test_dirty_inputs(root)

  expect_error(
    suppressMessages(validateCodeState(ignorePaths = character(0))),
    "uncommitted changes"
  )
})


# validateCodeState: path-scoped ignore ---------------------------------------

test_that("validateCodeState passes when all changes fall inside ignorePaths", {
  root <- cs_test_local_repo()
  cs_test_dirty_inputs(root)

  result <- suppressMessages(validateCodeState(ignorePaths = "inputs"))

  expect_false(result$clean)
  expect_identical(result$status, "dirty-ignored")
  expect_identical(result$ignoredFiles, "inputs/cohorts/a.json")
  expect_identical(result$ignorePaths, "inputs")
  expect_true(nchar(result$sha) > 0)
})

test_that("validateCodeState honours a nested folder and an exact file path", {
  root <- cs_test_local_repo()
  cs_test_dirty_inputs(root)

  expect_identical(
    suppressMessages(validateCodeState(ignorePaths = "inputs/cohorts"))$status,
    "dirty-ignored"
  )
  expect_identical(
    suppressMessages(validateCodeState(ignorePaths = "inputs/cohorts/a.json"))$status,
    "dirty-ignored"
  )
})

test_that("validateCodeState still fails for changes outside ignorePaths", {
  root <- cs_test_local_repo()
  cs_test_dirty_inputs(root)
  cs_test_dirty_analysis(root)

  expect_error(
    suppressMessages(validateCodeState(ignorePaths = "inputs")),
    "uncommitted changes"
  )
})

test_that("validateCodeState ignore paths do not match by prefix alone", {
  root <- cs_test_local_repo()
  cs_test_dirty_inputs(root)

  # "input" must not swallow "inputs/..."
  expect_error(
    suppressMessages(validateCodeState(ignorePaths = "input")),
    "uncommitted changes"
  )
})

test_that("validateCodeState rejects ignore paths that disable the whole check", {
  cs_test_local_repo()

  expect_error(validateCodeState(ignorePaths = "."), "Invalid code-state ignore path")
  expect_error(validateCodeState(ignorePaths = ".."), "Invalid code-state ignore path")
  expect_error(
    validateCodeState(ignorePaths = "inputs/../analysis"),
    "Invalid code-state ignore path"
  )
  expect_error(validateCodeState(ignorePaths = "/etc"), "Invalid code-state ignore path")
})

test_that("path_is_ignored handles trailing slashes and ./ prefixes", {
  expect_true(path_is_ignored("./inputs/cohorts/a.json", "inputs/"))
  expect_true(path_is_ignored("inputs/cohorts/a.json", c("exec", "inputs")))
  expect_false(path_is_ignored("analysis/tasks/01_a.R", "inputs"))
  expect_false(path_is_ignored("inputs/cohorts/a.json", character(0)))
})


# config.yml opt-in ------------------------------------------------------------

test_that("getIgnoreUncommittedPaths defaults to ignoring nothing", {
  root <- cs_test_local_repo()

  expect_identical(getIgnoreUncommittedPaths(), character(0))

  readr::write_lines(
    c("default:", "  projectName: x", "  version: 1.0.0"),
    fs::path(root, "config.yml")
  )
  expect_identical(getIgnoreUncommittedPaths(), character(0))
})

test_that("getIgnoreUncommittedPaths reads the default block of config.yml", {
  root <- cs_test_local_repo()

  readr::write_lines(
    c(
      "default:",
      "  projectName: x",
      "  version: 1.0.0",
      "  ignoreUncommittedPaths:",
      "    - inputs",
      "    - exec/logs"
    ),
    fs::path(root, "config.yml")
  )

  expect_identical(getIgnoreUncommittedPaths(), c("inputs", "exec/logs"))
})


# code_state_check -------------------------------------------------------------

test_that("code_state_check passes clean and warns on ignored churn", {
  root <- cs_test_local_repo()

  clean <- code_state_check()
  expect_identical(clean$status, "pass")
  expect_identical(clean$codeState$status, "clean")

  cs_test_dirty_inputs(root)

  ignored <- code_state_check(ignoreUncommittedPaths = "inputs")
  expect_identical(ignored$status, "warn")
  expect_identical(ignored$codeState$status, "dirty-ignored")
  expect_match(ignored$message, "NOT clean")
  expect_match(ignored$message, "inputs")
})

test_that("code_state_check fails for changes outside the ignore paths", {
  root <- cs_test_local_repo()
  cs_test_dirty_analysis(root)

  failed <- code_state_check(ignoreUncommittedPaths = "inputs")

  expect_identical(failed$status, "fail")
  expect_identical(failed$codeState$status, "dirty-blocked")
})

test_that("skipCodeStateCheck warns rather than silently skipping", {
  root <- cs_test_local_repo()
  cs_test_dirty_analysis(root)

  skipped <- code_state_check(skipCodeStateCheck = TRUE)

  expect_identical(skipped$status, "warn")
  expect_identical(skipped$codeState$status, "unverified-skipped")
  expect_match(skipped$message, "NOT CHECKED")
  expect_true(nchar(skipped$codeState$sha) > 0)
})

test_that("test mode skips the code state check", {
  root <- cs_test_local_repo()
  cs_test_dirty_analysis(root)

  testModeResult <- code_state_check(testMode = TRUE)

  expect_identical(testModeResult$status, "skip")
  expect_identical(testModeResult$codeState$status, "unverified-test-mode")
})

test_that("announce_code_state is loud for ignored and skipped, quiet for clean", {
  expect_silent(announce_code_state(list(status = "clean")))
  expect_silent(announce_code_state(NULL))

  expect_message(
    announce_code_state(list(
      status = "dirty-ignored",
      sha = "abcdef1234567890",
      ignoredFiles = "inputs/cohorts/a.json",
      ignorePaths = "inputs"
    )),
    "inputs/cohorts/a.json"
  )

  expect_message(
    announce_code_state(list(
      status = "unverified-skipped",
      sha = "abcdef1234567890",
      ignoredFiles = character(0),
      ignorePaths = character(0)
    )),
    "skipCodeStateCheck"
  )
})


# Audit trail ------------------------------------------------------------------

test_that("task_run_history.csv records commit sha and code state", {
  root <- cs_test_local_repo()

  suppressMessages(recordTaskExecution(
    taskFile = as.character(fs::path(root, "analysis", "tasks", "01_a.R")),
    configBlock = "block1",
    pipelineVersion = "1.0.0",
    status = "success",
    commitSha = "abcdef1234567890",
    codeState = "dirty-ignored"
  ))

  history <- readr::read_csv(
    fs::path(root, "exec", "logs", "task_run_history.csv"),
    show_col_types = FALSE
  )

  expect_true(all(c("commit_sha", "code_state") %in% names(history)))
  expect_identical(history$code_state[1], "dirty-ignored")
  expect_identical(history$commit_sha[1], "abcdef1234567890")
  expect_false(any(history$code_state == "clean"))
})

test_that("task history defaults to unrecorded rather than implying a clean tree", {
  root <- cs_test_local_repo()

  suppressMessages(recordTaskExecution(
    taskFile = as.character(fs::path(root, "analysis", "tasks", "01_a.R")),
    configBlock = "block1",
    pipelineVersion = "1.0.0",
    status = "success"
  ))

  history <- suppressMessages(getTaskRunSummary())

  expect_identical(history$code_state[1], "unrecorded")
  expect_identical(history$commit_sha[1], "")
})

test_that("history files written before the provenance columns still load", {
  root <- cs_test_local_repo()
  historyFile <- fs::path(root, "exec", "logs", "task_run_history.csv")

  legacy <- data.frame(
    task_name = "01_a.R",
    config_block = "block1",
    last_run_time = "2026-01-01 00:00:00",
    pipeline_version = "0.9.0",
    task_file_hash = "deadbeef",
    cohort_manifest_hash = "cafe",
    status = "success",
    error_message = "",
    stringsAsFactors = FALSE
  )
  readr::write_csv(legacy, historyFile)

  loaded <- .initializeTaskHistory(historyFile)

  expect_true(all(c("commit_sha", "code_state") %in% names(loaded)))
  expect_identical(loaded$code_state[1], "unrecorded")

  # A new row appended to a legacy file keeps both schemas readable
  suppressMessages(recordTaskExecution(
    taskFile = as.character(fs::path(root, "analysis", "tasks", "01_a.R")),
    configBlock = "block1",
    pipelineVersion = "1.0.0",
    status = "success",
    commitSha = "abcdef1234567890",
    codeState = "unverified-skipped"
  ))

  history <- suppressMessages(getTaskRunSummary())
  expect_equal(nrow(history), 2)
  expect_identical(history$code_state, c("unrecorded", "unverified-skipped"))
})

test_that("execute_task records the pipeline code state on failure", {
  root <- cs_test_local_repo()

  # 01_a.R is not a valid study task, so execution fails and is recorded
  expect_error(suppressMessages(execute_task(
    taskFile = "01_a.R",
    configBlock = "block1",
    pipelineVersion = "1.0.0",
    codeState = list(sha = "abcdef1234567890", status = "dirty-ignored")
  )))

  history <- suppressMessages(getTaskRunSummary())

  expect_equal(nrow(history), 1)
  expect_identical(history$status[1], "failed")
  expect_identical(history$code_state[1], "dirty-ignored")
  expect_identical(history$commit_sha[1], "abcdef1234567890")
})

test_that("execute_task records unrecorded when run outside the pipeline", {
  root <- cs_test_local_repo()

  expect_error(suppressMessages(execute_task(
    taskFile = "01_a.R",
    configBlock = "block1",
    pipelineVersion = "1.0.0"
  )))

  history <- suppressMessages(getTaskRunSummary())

  expect_identical(history$code_state[1], "unrecorded")
  expect_identical(history$commit_sha[1], "")
})
