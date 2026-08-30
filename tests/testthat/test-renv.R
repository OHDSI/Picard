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
