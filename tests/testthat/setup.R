library(testthat)
library(Barista)
library(withr)

# create cohort manifest db ----

dbPath <- testthat::test_path("test.sqlite")

manifestDb <- createManifestDb(dbPath = dbPath)

feverCohort <- createCohortManifestItem(
  name = "Fever",
  provenanceId = 3,
  designMethod = "Atlas",
  relativeJsonPath = testthat::test_path("resources/fever.json")
)

addCohortManifestItem(manifestDb = manifestDb,
                      cohortManifestItem = feverCohort)

coughCohort <- createCohortManifestItem(
  name = "Cough",
  provenanceId = 6,
  designMethod = "Atlas",
  relativeJsonPath = testthat::test_path("resources/cough.json")
)

feverCohortId <- viewCohortManifest(manifestDb = manifestDb) |>
  dplyr::filter(name == "Fever") |>
  dplyr::pull(cohortId)

addCohortManifestItem(manifestDb = manifestDb,
                      cohortManifestItem = coughCohort,
                      dependentCohortIds = c(feverCohortId))

defer(
  {
    DBI::dbDisconnect(conn = manifestDb$db)
    unlink(dbPath)
    unlink("cohorts", recursive = TRUE)
  },
  testthat::teardown_env()
)
