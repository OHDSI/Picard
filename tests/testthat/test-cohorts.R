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

# test_that(desc = "Cohort definition set is valid", code = {
#
#   result <- viewCohortDefinitionSet(manifestDb = manifestDb)
#
#   expect(ok = , failure_message = "Dependency not found.")
# })



# 1. add 5 comorbids
# 2. (study team messed up) add union template cohort to cover those 5 cohorts - deprecate this

# 3. undo the last step, and add 1 more comorbid
# 4. add union template to cover 6 cohorts - not by id.
  ## We can use dplyr to obtain all cohort ids that are active and have tag == "Comorbid"





