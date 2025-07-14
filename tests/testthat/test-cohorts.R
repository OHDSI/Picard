library(testthat)

feverCohort <- Barista::createCohortManifestItem(
  name = "Fever",
  provenanceId = 3,
  designMethod = "Atlas",
  relativeJsonPath = testthat::test_path("fever.json")
)

Barista::addCohortManifestItem(manifestDb = manifestDb,
                               cohortManifestItem = feverCohort)

coughCohort <- Barista::createCohortManifestItem(
  name = "Cough 2",
  provenanceId = 6,
  designMethod = "Atlas",
  relativeJsonPath = testthat::test_path("cough.json")
)

Barista::addCohortManifestItem(manifestDb = manifestDb,
                               cohortManifestItem = coughCohort,
                               dependentCohortIds = c(1))

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

