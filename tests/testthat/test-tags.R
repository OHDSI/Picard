library(testthat)


test_that(desc = "Tag fever cohort as type = target", code = {

  applyTagToCohortManifestItem(
    manifestDb = manifestDb,
    cohortId = feverCohort$thisItem$cohortId,
    tagName = "type",
    tagValue = "target"
  )

  result <- viewCohortManifest(manifestDb = manifestDb,
                               tagNameValues = list(
                                 list(name = "type", value = "target")
                               ))

  expect(ok = nrow(result) == 1, failure_message = "Cohort not found.")
})

