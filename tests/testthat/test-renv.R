# Purpose: Build a renv::status()-shaped result with the given library/lockfile records.
renv_test_status <- function(librarySpec, lockfileSpec, synchronized = NULL) {
  asPackages <- function(spec) {
    list(Packages = stats::setNames(
      lapply(names(spec), function(pkg) list(Package = pkg, Version = spec[[pkg]])),
      names(spec)
    ))
  }

  status <- list(library = asPackages(librarySpec), lockfile = asPackages(lockfileSpec))
  if (!is.null(synchronized)) {
    status$synchronized <- synchronized
  }
  status
}

# Testing: renv::status() reports sync state through `synchronized`; it never
# returns NULL, which is what made every project look drifted (issue #84).
testthat::test_that("renv_status_synchronized reads the synchronized flag", {
  testthat::expect_true(renv_status_synchronized(list(synchronized = TRUE)))
  testthat::expect_false(renv_status_synchronized(list(synchronized = FALSE)))
  testthat::expect_true(is.na(renv_status_synchronized(list(library = list()))))
  testthat::expect_true(is.na(renv_status_synchronized(NULL)))
})

# Testing: a freshly snapshotted project reports no drift.
testthat::test_that("renv_status_drift reports nothing when versions match", {
  status <- renv_test_status(
    librarySpec = list(dplyr = "1.1.4", cli = "3.6.3"),
    lockfileSpec = list(dplyr = "1.1.4", cli = "3.6.3")
  )

  testthat::expect_equal(renv_status_drift(status), character(0))
})

# Testing: differing versions, and packages present on only one side, are drift.
testthat::test_that("renv_status_drift reports version and membership differences", {
  status <- renv_test_status(
    librarySpec = list(dplyr = "1.1.4", cli = "3.6.3"),
    lockfileSpec = list(dplyr = "1.1.3", tibble = "3.2.1")
  )

  drift <- renv_status_drift(status)

  testthat::expect_equal(length(drift), 3)
  testthat::expect_true(any(grepl("dplyr", drift, fixed = TRUE)))
  testthat::expect_true(any(grepl("cli", drift, fixed = TRUE)))
  testthat::expect_true(any(grepl("tibble", drift, fixed = TRUE)))
})

# Testing: an empty or unparseable status is treated as no drift rather than
# aborting the pipeline.
testthat::test_that("renv_status_drift tolerates missing records", {
  testthat::expect_equal(renv_status_drift(list()), character(0))
  testthat::expect_equal(
    renv_status_drift(list(library = list(Packages = list()), lockfile = list())),
    character(0)
  )
})

# Testing: the pipeline records renv.lock for the audit trail but must never
# rewrite it — snapshotting mid-run dirties the tree the code-state check just
# validated, so keeping the lockfile current is the analyst's call.
testthat::test_that("captureLockfile hashes without modifying the lockfile", {
  tmp <- withr::local_tempdir()
  lock <- fs::path(tmp, "renv.lock")
  readr::write_file('{"R": {"Version": "4.4.1"}}', lock)

  before_mtime <- fs::file_info(lock)$modification_time
  before_content <- readr::read_file(lock)

  hash <- captureLockfile(path = lock)

  testthat::expect_identical(hash, rlang::hash(before_content))
  testthat::expect_identical(readr::read_file(lock), before_content)
  testthat::expect_identical(fs::file_info(lock)$modification_time, before_mtime)
})

testthat::test_that("captureLockfile archives a versioned copy when asked", {
  tmp <- withr::local_tempdir()
  lock <- fs::path(tmp, "renv.lock")
  readr::write_file('{"R": {"Version": "4.4.1"}}', lock)

  suppressMessages(
    captureLockfile(versionLabel = "1.2.0", savePath = tmp, path = lock)
  )

  archived <- fs::path(tmp, "renv_lock_1.2.0.json")
  testthat::expect_true(fs::file_exists(archived))
  testthat::expect_identical(readr::read_file(archived), readr::read_file(lock))
})

testthat::test_that("captureLockfile aborts when the lockfile is missing", {
  tmp <- withr::local_tempdir()

  testthat::expect_error(
    captureLockfile(path = fs::path(tmp, "renv.lock")),
    "not found"
  )
})

testthat::test_that("preflight checks do not call renv::snapshot", {
  body_text <- paste(deparse(body(runPreflightChecks)), collapse = " ")

  testthat::expect_false(grepl("snapshotEnvironment(", body_text, fixed = TRUE))
  testthat::expect_true(grepl("lockfileHashOnDisk(", body_text, fixed = TRUE))
})
