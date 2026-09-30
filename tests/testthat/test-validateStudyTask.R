# Purpose: Write a structurally valid task file whose E. Script section is `script`.
vst_test_task_file <- function(script) {
  path <- withr::local_tempfile(fileext = ".R", .local_envir = parent.frame())
  writeLines(c(
    "# A. Meta Info ----",
    "# B. Dependencies ----",
    "library(picard)",
    "# C. Connection Settings ----",
    'configBlock <- "!||configBlock||!"',
    'pipelineVersion <- "!||pipelineVersion||!"',
    "executionSettings <- createExecutionSettingsFromConfig(configBlock = configBlock)",
    "# D. Task Settings ----",
    'outputFolder <- setOutputFolder(executionSettings, pipelineVersion, "02_task")',
    "# E. Script ----",
    script
  ), path)
  path
}

testthat::test_that("validateStudyTask passes a task without data file reads", {
  path <- vst_test_task_file('readr::write_csv(mtcars, fs::path(outputFolder, "cars.csv"))')

  testthat::expect_true(suppressMessages(validateStudyTask(path)))
  testthat::expect_equal(nrow(.findDataFileReads(path)), 0)
})

testthat::test_that("validateStudyTask fails when a task reads pipeline results", {
  scripts <- c(
    'x <- readr::read_csv("exec/results/db/1.0.0/01_task/out.csv")',
    'x <- readRDS(fs::path(outputFolder, "..", "01_task", "model.rds"))',
    'x <- fs::path(outputFolder, "prior.csv") |> readr::read_csv()',
    'x <- here::here("exec/results", "a.csv") %>% data.table::fread()'
  )

  for (script in scripts) {
    path <- vst_test_task_file(script)
    testthat::expect_error(
      suppressMessages(validateStudyTask(path)),
      "reads files from pipeline results",
      info = script
    )
  }
})

testthat::test_that("validateStudyTask warns but passes on other data file reads", {
  path <- vst_test_task_file('lookup <- read.csv("inputs/lookup.csv")\nprint(lookup)')

  reads <- .findDataFileReads(path)
  testthat::expect_equal(nrow(reads), 1)
  testthat::expect_false(reads$readsResults)
  testthat::expect_equal(reads$line, 11)

  testthat::expect_message(validateStudyTask(path), "does not track")
})

testthat::test_that("validateStudyTask ignores commented-out reads and strings", {
  path <- vst_test_task_file(c(
    '# x <- readr::read_csv("exec/results/db/out.csv")',
    'msg <- "do not readRDS(exec/results)"',
    "print(msg)"
  ))

  testthat::expect_equal(nrow(.findDataFileReads(path)), 0)
  testthat::expect_true(suppressMessages(validateStudyTask(path)))
})
