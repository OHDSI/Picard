# Purpose: Create an isolated temporary inputs/conceptSets tree and fresh ConceptSetManifest.
csm_test_new_manifest <- function(test_name = "conceptsetmanifest") {
  root <- fs::file_temp(pattern = paste0("picard-", test_name, "-"))
  concept_sets_dir <- fs::path(root, "inputs", "conceptSets")
  fs::dir_create(fs::path(concept_sets_dir, "json"))

  manifest <- ConceptSetManifest$new(
    dbPath = fs::path(concept_sets_dir, "conceptSetManifest.sqlite")
  )

  ll <- list(
    manifest = manifest,
    concept_sets_dir = concept_sets_dir
  )
  return(ll)
}

# Purpose: Build a minimal Capr concept set for tests; skip when Capr is unavailable.
# concept_ids varies the members so tests can produce distinct definitions.
csm_test_make_capr_concept_set <- function(concept_ids = 201826) {
  testthat::skip_if_not_installed("Capr")

  tryCatch(
    Capr::cs(Capr::descendants(concept_ids), name = "test concept set"),
    error = function(e) {
      testthat::skip(paste("Unable to create Capr concept set in test helper:", conditionMessage(e)))
    }
  )
}

# Purpose: Fetch the raw sqlite manifest row for a label (any status).
csm_test_get_manifest_row <- function(manifest, label) {
  conn <- DBI::dbConnect(RSQLite::SQLite(), manifest$getDbPath())
  on.exit(DBI::dbDisconnect(conn))
  DBI::dbGetQuery(
    conn,
    "SELECT * FROM concept_set_manifest WHERE label = ?",
    list(label)
  )
}

# Testing: addCaprConceptSet registers a Capr concept set with its JSON on disk.
testthat::test_that("addCaprConceptSet registers Capr concept set", {
  setup <- csm_test_new_manifest("csm-add-capr")
  manifest <- setup$manifest

  capr_cs <- csm_test_make_capr_concept_set()
  manifest$addCaprConceptSet(capr_cs, label = "T2D Concepts", category = "condition_occurrence")

  row <- csm_test_get_manifest_row(manifest, "T2D Concepts")
  testthat::expect_equal(nrow(row), 1)
  testthat::expect_true(fs::file_exists(row$file_path[[1]]))
})

# Testing: updateCaprConceptSet overwrites the registered JSON and refreshes the hash in place.
testthat::test_that("updateCaprConceptSet updates definition keeping id and file path", {
  setup <- csm_test_new_manifest("csm-update-capr")
  manifest <- setup$manifest

  capr_cs <- csm_test_make_capr_concept_set()
  manifest$addCaprConceptSet(capr_cs, label = "T2D Concepts", category = "condition_occurrence")
  before <- csm_test_get_manifest_row(manifest, "T2D Concepts")

  revised <- csm_test_make_capr_concept_set(concept_ids = c(201826, 443238))
  returned_id <- manifest$updateCaprConceptSet(revised, label = "T2D Concepts")

  after <- csm_test_get_manifest_row(manifest, "T2D Concepts")
  testthat::expect_equal(as.integer(returned_id), as.integer(before$id[[1]]))
  testthat::expect_equal(after$id[[1]], before$id[[1]])
  testthat::expect_equal(after$file_path[[1]], before$file_path[[1]])
  testthat::expect_false(identical(after$hash[[1]], before$hash[[1]]))

  disk_hash <- rlang::hash(readr::read_file(after$file_path[[1]]))
  testthat::expect_equal(after$hash[[1]], disk_hash)
})

# Testing: updateCaprConceptSet leaves manifest untouched when the definition is unchanged.
testthat::test_that("updateCaprConceptSet is a no-op for identical definitions", {
  setup <- csm_test_new_manifest("csm-update-capr-noop")
  manifest <- setup$manifest

  capr_cs <- csm_test_make_capr_concept_set()
  manifest$addCaprConceptSet(capr_cs, label = "T2D Concepts", category = "condition_occurrence")
  before <- csm_test_get_manifest_row(manifest, "T2D Concepts")

  same <- csm_test_make_capr_concept_set()
  testthat::expect_message(
    manifest$updateCaprConceptSet(same, label = "T2D Concepts"),
    regexp = "unchanged"
  )

  after <- csm_test_get_manifest_row(manifest, "T2D Concepts")
  testthat::expect_equal(after$hash[[1]], before$hash[[1]])
})

# Testing: updateCaprConceptSet errors for labels not registered in the manifest.
testthat::test_that("updateCaprConceptSet errors when label is not registered", {
  setup <- csm_test_new_manifest("csm-update-capr-missing")
  manifest <- setup$manifest

  capr_cs <- csm_test_make_capr_concept_set()
  testthat::expect_error(
    manifest$updateCaprConceptSet(capr_cs, label = "Not Registered"),
    regexp = "No active concept set"
  )
})

# Testing: addCaprConceptSet with stopIfExists = FALSE upserts the existing concept set in place.
testthat::test_that("addCaprConceptSet stopIfExists FALSE updates existing concept set", {
  setup <- csm_test_new_manifest("csm-add-capr-upsert")
  manifest <- setup$manifest

  capr_cs <- csm_test_make_capr_concept_set()
  manifest$addCaprConceptSet(capr_cs, label = "T2D Concepts", category = "condition_occurrence")
  before <- csm_test_get_manifest_row(manifest, "T2D Concepts")

  revised <- csm_test_make_capr_concept_set(concept_ids = c(201826, 443238))
  returned_id <- manifest$addCaprConceptSet(
    caprConceptSet = revised,
    label = "T2D Concepts",
    category = "observation",
    stopIfExists = FALSE
  )

  after <- csm_test_get_manifest_row(manifest, "T2D Concepts")
  testthat::expect_equal(nrow(after), 1)
  testthat::expect_equal(as.integer(returned_id), as.integer(before$id[[1]]))
  testthat::expect_equal(after$file_path[[1]], before$file_path[[1]])
  testthat::expect_false(identical(after$hash[[1]], before$hash[[1]]))
  testthat::expect_equal(after$category[[1]], "observation")
})

# Purpose: Build a fake ATLAS connection returning fixed expression JSON keyed by atlasId.
csm_test_fake_atlas_connection <- function(expressions) {
  list(
    getConceptSetDefinition = function(conceptSetId) {
      list(
        expression = expressions[[as.character(conceptSetId)]],
        saveName = paste0("atlas_cs_", conceptSetId)
      )
    }
  )
}

# Testing: importAtlasConceptSets updateExisting = TRUE upserts changed ATLAS definitions in place.
testthat::test_that("importAtlasConceptSets updateExisting TRUE updates changed definitions", {
  setup <- csm_test_new_manifest("csm-atlas-upsert")
  manifest <- setup$manifest

  # Fake ATLAS payloads must be valid CIRCE JSON (ConceptSetDef validates via
  # CirceR), so generate two distinct definitions with Capr
  v1_tmp <- tempfile(fileext = ".json")
  Capr::writeConceptSet(csm_test_make_capr_concept_set(), v1_tmp)
  v1_json <- readr::read_file(v1_tmp)
  v2_tmp <- tempfile(fileext = ".json")
  Capr::writeConceptSet(csm_test_make_capr_concept_set(concept_ids = c(201826, 443238)), v2_tmp)
  v2_json <- readr::read_file(v2_tmp)
  unlink(c(v1_tmp, v2_tmp))

  load_df <- data.frame(atlasId = 200L, label = "Atlas Concepts", category = "condition_occurrence")

  conn_v1 <- csm_test_fake_atlas_connection(list("200" = v1_json))
  manifest$importAtlasConceptSets(conceptSetsLoad = load_df, atlasConnection = conn_v1)
  before <- csm_test_get_manifest_row(manifest, "Atlas Concepts")
  testthat::expect_equal(nrow(before), 1)

  conn_v2 <- csm_test_fake_atlas_connection(list("200" = v2_json))

  # Default re-import leaves the registered definition untouched
  manifest$importAtlasConceptSets(conceptSetsLoad = load_df, atlasConnection = conn_v2)
  unchanged <- csm_test_get_manifest_row(manifest, "Atlas Concepts")
  testthat::expect_equal(unchanged$hash[[1]], before$hash[[1]])

  # updateExisting = TRUE fetches the new definition and updates in place
  manifest$importAtlasConceptSets(conceptSetsLoad = load_df, atlasConnection = conn_v2, updateExisting = TRUE)
  after <- csm_test_get_manifest_row(manifest, "Atlas Concepts")
  testthat::expect_equal(after$id[[1]], before$id[[1]])
  testthat::expect_equal(after$file_path[[1]], before$file_path[[1]])
  testthat::expect_false(identical(after$hash[[1]], before$hash[[1]]))
})

# Testing: addCaprConceptSet default stopIfExists = TRUE errors cleanly on duplicate labels.
testthat::test_that("addCaprConceptSet errors on duplicate label by default", {
  setup <- csm_test_new_manifest("csm-add-capr-dup")
  manifest <- setup$manifest

  capr_cs <- csm_test_make_capr_concept_set()
  manifest$addCaprConceptSet(capr_cs, label = "T2D Concepts", category = "condition_occurrence")

  testthat::expect_error(
    manifest$addCaprConceptSet(capr_cs, label = "T2D Concepts", category = "condition_occurrence"),
    regexp = "already in use"
  )
})
