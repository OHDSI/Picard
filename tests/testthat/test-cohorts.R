library(testthat)


test_that(desc = "Fever cohort added", code = {

  result <- viewCohortManifest(manifestDb = manifestDb) |>
    dplyr::filter(name == feverCohort$thisItem$name)

  expect(ok = nrow(result) == 1, failure_message = "Cohort not found.")
})



test_that(desc = "Cough cohort added", code = {

  result <- viewCohortManifest(manifestDb = manifestDb) |>
    dplyr::filter(name == coughCohort$thisItem$name)

  expect(ok = nrow(result) == 1, failure_message = "Cohort not found.")
})

test_that(desc = "Cough cohort has dependency on Fever cohort", code = {

  result <- viewDependencyManifest(manifestDb = manifestDb) |>
    dplyr::filter(manifestItemId == coughCohort$thisItem$cohortId,
                  dependentItemId == feverCohort$thisItem$cohortId)

  expect(ok = nrow(result) == 1, failure_message = "Dependency not found.")
})

