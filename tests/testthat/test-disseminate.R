# Purpose: Build a minimal temp project with per-database task results plus a
# config.yml, mirroring the layout importAndBind() expects.
diss_test_results_project <- function(test_name = "diss") {
  root <- fs::file_temp(pattern = paste0("picard-", test_name, "-"))
  fs::dir_create(root)

  writeLines(
    c(
      "default:",
      "  databaseName: \"db_alpha\"",
      "",
      "db_alpha:",
      "  databaseName: \"db_alpha\"",
      "",
      "db_beta:",
      "  databaseName: \"db_beta\""
    ),
    fs::path(root, "config.yml")
  )

  for (db in c("db_alpha", "db_beta")) {
    task_dir <- fs::path(root, "exec", "results", db, "1.0.0", "01_counts")
    fs::dir_create(task_dir, recurse = TRUE)
    readr::write_csv(
      tibble::tibble(
        cohortId = c(1L, 2L),
        cohortLabel = c("target", "comparator"),
        count = c(10L, 20L)
      ),
      fs::path(task_dir, "cohort_counts.csv")
    )
  }

  return(root)
}

# Testing: merged results carry the camelCase `databaseId` column, which is the
# name the dissemination script template must look for (issue #87).
testthat::test_that("importAndBind labels merged results with databaseId", {
  root <- diss_test_results_project("diss-merge")
  old_wd <- setwd(root)
  on.exit(setwd(old_wd), add = TRUE)

  suppressMessages(
    importAndBind(
      version = "1.0.0",
      taskName = "01_counts",
      dbIds = c("db_alpha", "db_beta"),
      resultsPath = fs::path(root, "exec", "results"),
      exportPath = fs::path(root, "dissemination", "export", "merge")
    )
  )

  # importAndBind() prefixes merged files with the task sequence from taskName
  merged <- readr::read_csv(
    fs::path(root, "dissemination", "export", "merge", "01_cohort_counts.csv"),
    show_col_types = FALSE
  )

  testthat::expect_true("databaseId" %in% names(merged))
  testthat::expect_false("database_id" %in% names(merged))
  testthat::expect_setequal(unique(merged$databaseId), c("db_alpha", "db_beta"))
})

# Testing: the shipped dissemination template inspects the merged results with
# the same column name importAndBind() writes.
testthat::test_that("dissemination script template reads databaseId from merged results", {
  template_path <- fs::path_package("picard", "templates", "disseminationScript_template.R")
  testthat::skip_if_not(fs::file_exists(template_path))

  template <- readr::read_file(template_path)

  testthat::expect_true(
    grepl("\"databaseId\" %in% names(results_df)", template, fixed = TRUE)
  )
  testthat::expect_false(grepl("results_df$database_id", template, fixed = TRUE))
})

# Testing: cleanColumnNames() is what turns databaseId into database_id, so the
# snake_case references later in the template apply to formatted data only.
testthat::test_that("cleanColumnNames converts databaseId to database_id", {
  cleaned <- cleanColumnNames(
    tibble::tibble(databaseId = "db_alpha", cohortId = 1L)
  )

  testthat::expect_equal(names(cleaned), c("database_id", "cohort_id"))
})

# Testing: prepareDisseminationData() accepts its four scalar flags. The
# argument check asserted a length of 1 on a length-4 vector, so every call
# aborted before any formatting ran (issue #87).
testthat::test_that("prepareDisseminationData runs with default flags", {
  data <- tibble::tibble(
    databaseId = c("db_alpha", "db_beta"),
    cohortLabel = c("target", "target"),
    count = c(10L, 20L),
    prevalencePct = c(0.1234, 0.5678),
    estimate = c(1.2345, 2.3456)
  )

  result <- suppressWarnings(suppressMessages(prepareDisseminationData(data)))

  testthat::expect_s3_class(result, "data.frame")
  testthat::expect_true(all(c("database_id", "cohort_label", "prevalence_pct") %in% names(result)))
  testthat::expect_equal(nrow(result), 2L)
  testthat::expect_equal(result$prevalence_pct, c("12.3%", "56.8%"))
})

# Testing: each formatting step can still be switched off individually.
testthat::test_that("prepareDisseminationData honours individually toggled flags", {
  data <- tibble::tibble(
    databaseId = c("db_alpha", "db_beta"),
    estimate = c(1.2345, 2.3456)
  )

  result <- suppressWarnings(suppressMessages(
    prepareDisseminationData(
      data,
      clean_names = FALSE,
      format_percentages = FALSE,
      format_floats = TRUE,
      standardize_types = FALSE
    )
  ))

  testthat::expect_true("databaseId" %in% names(result))
  testthat::expect_equal(result$estimate, c("1.23", "2.35"))
})

# Testing: the flag check still rejects non-scalar or missing flags.
testthat::test_that("prepareDisseminationData rejects non-scalar flags", {
  data <- tibble::tibble(databaseId = "db_alpha", estimate = 1.5)

  testthat::expect_error(
    suppressMessages(prepareDisseminationData(data, clean_names = c(TRUE, FALSE))),
    regexp = "length"
  )
  testthat::expect_error(
    suppressMessages(prepareDisseminationData(data, format_floats = NA)),
    regexp = "missing"
  )
})
