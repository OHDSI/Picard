# Tests for R/manifest_conceptSets.R and ConceptSetDef/ConceptSetManifest
# Focuses on functions that don't require a live vocabulary DB connection

# Helper to create minimal valid CIRCE concept set JSON
make_circe_concept_set_json <- function() {
  '{"items":[]}'
}

# ---- ConceptSetDef ----

test_that("ConceptSetDef initializes with valid CIRCE JSON", {
  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(
    label = "Test Concept Set",
    tags = list(category = "medications"),
    filePath = temp_json,
    domain = "drug_exposure"
  )

  expect_equal(cs$label, "Test Concept Set")
  expect_true(nchar(cs$getHash()) > 0)
  expect_equal(cs$getId(), NA_integer_)
})

test_that("ConceptSetDef getFilePath returns path ending in .json", {
  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(label = "CS", filePath = temp_json)
  expect_match(cs$getFilePath(), "\\.json$")
})

test_that("ConceptSetDef getJson returns non-empty string", {
  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(label = "CS", filePath = temp_json)
  expect_type(cs$getJson(), "character")
  expect_true(nchar(cs$getJson()) > 0)
})

test_that("ConceptSetDef getId returns NA before assignment", {
  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(label = "CS", filePath = temp_json)
  expect_equal(cs$getId(), NA_integer_)
})

test_that("ConceptSetDef setId and getId round-trip", {
  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(label = "CS", filePath = temp_json)
  cs$setId(7L)
  expect_equal(cs$getId(), 7L)
})

test_that("ConceptSetDef domain tag is added automatically", {
  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(label = "CS", filePath = temp_json, domain = "condition_occurrence")
  expect_equal(cs$tags$domain, "condition_occurrence")
})

test_that("ConceptSetDef errors for invalid domain", {
  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  expect_error(
    ConceptSetDef$new(label = "CS", filePath = temp_json, domain = "not_a_domain")
  )
})

test_that("ConceptSetDef errors for non-existent file", {
  expect_error(
    ConceptSetDef$new(label = "CS", filePath = "/does/not/exist.json")
  )
})

test_that("ConceptSetDef errors for non-JSON file", {
  temp_sql <- tempfile(fileext = ".sql")
  writeLines("SELECT 1;", temp_sql)
  on.exit(unlink(temp_sql), add = TRUE)

  expect_error(
    ConceptSetDef$new(label = "CS", filePath = temp_sql)
  )
})

test_that("ConceptSetDef label active binding get/set works", {
  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(label = "Original", filePath = temp_json)
  expect_equal(cs$label, "Original")
  cs$label <- "Modified"
  expect_equal(cs$label, "Modified")
})

test_that("ConceptSetDef formatTagsAsString includes all tags", {
  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(
    label = "CS",
    tags = list(category = "medications", source = "atlas"),
    filePath = temp_json
  )
  tags_str <- cs$formatTagsAsString()
  expect_true(grepl("category: medications", tags_str))
  expect_true(grepl("source: atlas", tags_str))
})

# ---- ConceptSetManifest ----

test_that("ConceptSetManifest initializes and creates SQLite database", {
  temp_dir <- tempfile(prefix = "picard_csm_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  db_path <- file.path(temp_dir, "conceptSetManifest.sqlite")
  manifest <- ConceptSetManifest$new(dbPath = db_path)

  expect_true(file.exists(db_path))
})

test_that("ConceptSetManifest getManifest returns list of ConceptSetDef objects", {
  temp_dir <- tempfile(prefix = "picard_csm_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  db_path <- file.path(temp_dir, "test.sqlite")
  manifest <- ConceptSetManifest$new(dbPath = db_path)
  manifest$addConceptSetFile(filePath = temp_json, label = "My CS")

  result <- manifest$getManifest()
  expect_type(result, "list")
  expect_s3_class(result[[1]], "ConceptSetDef")
})

test_that("ConceptSetManifest tabulateManifest returns data frame", {
  temp_dir <- tempfile(prefix = "picard_csm_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  db_path <- file.path(temp_dir, "test.sqlite")
  manifest <- ConceptSetManifest$new(dbPath = db_path)
  manifest$addConceptSetFile(filePath = temp_json, label = "My CS")

  df <- manifest$tabulateManifest()
  expect_true(is.data.frame(df))
  expect_equal(nrow(df), 1)
  expect_equal(df$label[1], "My CS")
})

test_that("ConceptSetManifest nConceptSets returns correct count", {
  temp_dir <- tempfile(prefix = "picard_csm_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  db_path <- file.path(temp_dir, "test.sqlite")
  manifest <- ConceptSetManifest$new(dbPath = db_path)

  for (i in seq_len(3)) {
    temp_json <- tempfile(fileext = ".json")
    writeLines(make_circe_concept_set_json(), temp_json)
    manifest$addConceptSetFile(filePath = temp_json, label = paste("CS", i))
  }

  expect_equal(manifest$nConceptSets(), 3)
})

test_that("ConceptSetManifest getConceptSetById returns ConceptSetDef", {
  temp_dir <- tempfile(prefix = "picard_csm_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  db_path <- file.path(temp_dir, "test.sqlite")
  manifest <- ConceptSetManifest$new(dbPath = db_path)
  manifest$addConceptSetFile(filePath = temp_json, label = "Grab Test")
  result <- manifest$getConceptSetById(1)

  expect_s3_class(result, "ConceptSetDef")
  expect_equal(result$label, "Grab Test")
})

test_that("ConceptSetManifest queryConceptSetsByIds returns data frame row", {
  temp_dir <- tempfile(prefix = "picard_csm_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  db_path <- file.path(temp_dir, "test.sqlite")
  manifest <- ConceptSetManifest$new(dbPath = db_path)
  manifest$addConceptSetFile(filePath = temp_json, label = "Query Test")
  row <- manifest$queryConceptSetsByIds(1L)

  expect_true(is.data.frame(row))
  expect_equal(nrow(row), 1)
  expect_equal(row$label[1], "Query Test")
})

test_that("ConceptSetManifest queryConceptSetsByIds accepts vector and returns multiple rows", {
  temp_dir <- tempfile(prefix = "picard_csm_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  db_path <- file.path(temp_dir, "test.sqlite")
  manifest <- ConceptSetManifest$new(dbPath = db_path)

  for (lbl in c("CS A", "CS B", "CS C")) {
    f <- tempfile(fileext = ".json")
    writeLines(make_circe_concept_set_json(), f)
    manifest$addConceptSetFile(filePath = f, label = lbl)
  }

  rows <- manifest$queryConceptSetsByIds(c(1L, 3L))

  expect_true(is.data.frame(rows))
  expect_equal(nrow(rows), 2)
  expect_true(all(c("CS A", "CS C") %in% rows$label))
})

# ---- createBlankConceptSetsLoadFile ----

test_that("createBlankConceptSetsLoadFile creates file in specified folder", {
  temp_dir <- tempfile(prefix = "picard_cs_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  createBlankConceptSetsLoadFile(conceptSetsFolderPath = temp_dir)

  expect_true(file.exists(file.path(temp_dir, "conceptSetsLoad.csv")))
})

test_that("createBlankConceptSetsLoadFile creates directory if missing", {
  temp_dir <- tempfile(prefix = "picard_cs_")
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  expect_false(dir.exists(temp_dir))
  createBlankConceptSetsLoadFile(conceptSetsFolderPath = temp_dir)
  expect_true(file.exists(file.path(temp_dir, "conceptSetsLoad.csv")))
})

test_that("createBlankConceptSetsLoadFile has correct column structure", {
  temp_dir <- tempfile(prefix = "picard_cs_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  createBlankConceptSetsLoadFile(conceptSetsFolderPath = temp_dir)

  df <- readr::read_csv(file.path(temp_dir, "conceptSetsLoad.csv"), show_col_types = FALSE)
  expected_cols <- c("atlasId", "label", "category", "subCategory", "sourceCode", "domain", "file_name")
  expect_true(all(expected_cols %in% colnames(df)))
})

# ---- resetConceptSetManifest ----

test_that("resetConceptSetManifest deletes existing SQLite file", {
  temp_dir <- tempfile(prefix = "picard_cs_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  sqlite_path <- file.path(temp_dir, "conceptSetManifest.sqlite")
  file.create(sqlite_path)
  expect_true(file.exists(sqlite_path))

  resetConceptSetManifest(conceptSetsFolderPath = temp_dir)
  expect_false(file.exists(sqlite_path))
})

test_that("resetConceptSetManifest does not error when no manifest exists", {
  temp_dir <- tempfile(prefix = "picard_cs_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  expect_no_error(resetConceptSetManifest(conceptSetsFolderPath = temp_dir))
})

# ---- loadConceptSetManifest ----

test_that("loadConceptSetManifest scans json/ folder and creates ConceptSetManifest", {
  temp_dir <- tempfile(prefix = "picard_cs_")
  json_dir <- file.path(temp_dir, "json")
  dir.create(json_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  writeLines(make_circe_concept_set_json(), file.path(json_dir, "hypertension.json"))
  writeLines(make_circe_concept_set_json(), file.path(json_dir, "diabetes.json"))

  manifest <- loadConceptSetManifest(conceptSetsFolderPath = temp_dir)

  expect_s3_class(manifest, "ConceptSetManifest")
  expect_equal(manifest$nConceptSets(), 2)
})

test_that("loadConceptSetManifest creates SQLite on first load", {
  temp_dir <- tempfile(prefix = "picard_cs_")
  json_dir <- file.path(temp_dir, "json")
  dir.create(json_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  writeLines(make_circe_concept_set_json(), file.path(json_dir, "test.json"))

  loadConceptSetManifest(conceptSetsFolderPath = temp_dir)

  expect_true(file.exists(file.path(temp_dir, "conceptSetManifest.sqlite")))
})

test_that("loadConceptSetManifest loads from existing sqlite on second call", {
  temp_dir <- tempfile(prefix = "picard_cs_")
  json_dir <- file.path(temp_dir, "json")
  dir.create(json_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  writeLines(make_circe_concept_set_json(), file.path(json_dir, "cs1.json"))

  loadConceptSetManifest(conceptSetsFolderPath = temp_dir)
  manifest2 <- loadConceptSetManifest(conceptSetsFolderPath = temp_dir)

  expect_s3_class(manifest2, "ConceptSetManifest")
  expect_equal(manifest2$nConceptSets(), 1)
})

test_that("loadConceptSetManifest discovers new manual JSON files added after manifest exists", {
  temp_dir <- tempfile(prefix = "picard_cs_")
  json_dir <- file.path(temp_dir, "json")
  dir.create(json_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # First load: one concept set
  writeLines(make_circe_concept_set_json(), file.path(json_dir, "cs1.json"))
  loadConceptSetManifest(conceptSetsFolderPath = temp_dir)

  # Manually add a second JSON without going through importAtlasConceptSets
  writeLines(make_circe_concept_set_json(), file.path(json_dir, "cs2.json"))

  # Second load should discover the new file
  manifest2 <- loadConceptSetManifest(conceptSetsFolderPath = temp_dir)

  expect_s3_class(manifest2, "ConceptSetManifest")
  expect_equal(manifest2$nConceptSets(), 2)
})

test_that("loadConceptSetManifest handles stale DB rows for missing files without error", {
  temp_dir <- tempfile(prefix = "picard_cs_")
  json_dir <- file.path(temp_dir, "json")
  dir.create(json_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  f1 <- file.path(json_dir, "cs1.json")
  f2 <- file.path(json_dir, "cs2.json")
  writeLines(make_circe_concept_set_json(), f1)
  writeLines(make_circe_concept_set_json(), f2)

  # First load registers both
  loadConceptSetManifest(conceptSetsFolderPath = temp_dir)

  # Remove one file (stale DB row scenario)
  unlink(f2)

  # Second load should not error; only the existing file is returned in memory
  manifest2 <- expect_no_error(loadConceptSetManifest(conceptSetsFolderPath = temp_dir))
  expect_equal(manifest2$nConceptSets(), 1)

  # validateManifest still surfaces the stale row
  status <- manifest2$validateManifest()
  missing_rows <- status[status$status == "active" & !status$file_exists, ]
  expect_equal(nrow(missing_rows), 1)
})

test_that("loadConceptSetManifest works when working directory differs from json folder", {
  temp_dir <- tempfile(prefix = "picard_cs_")
  json_dir <- file.path(temp_dir, "json")
  dir.create(json_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  writeLines(make_circe_concept_set_json(), file.path(json_dir, "cs1.json"))

  original_wd <- getwd()
  on.exit(setwd(original_wd), add = TRUE)

  # Change working directory to a different temp location
  other_dir <- tempfile(prefix = "picard_wd_")
  dir.create(other_dir)
  on.exit(unlink(other_dir, recursive = TRUE), add = TRUE)
  setwd(other_dir)

  # Load using the absolute conceptSetsFolderPath — should work regardless of CWD
  manifest <- expect_no_error(
    loadConceptSetManifest(conceptSetsFolderPath = temp_dir)
  )
  expect_s3_class(manifest, "ConceptSetManifest")
  expect_equal(manifest$nConceptSets(), 1)
})

# ---- queryConceptSetsByTag match= ----

test_that("queryConceptSetsByTag match='all' filters correctly", {
  temp_dir <- tempfile(prefix = "picard_csm_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  db_path <- file.path(temp_dir, "test.sqlite")
  manifest <- ConceptSetManifest$new(dbPath = db_path)

  add_cs <- function(manifest, label, domain, category) {
    f <- tempfile(fileext = ".json")
    writeLines(make_circe_concept_set_json(), f)
    manifest$addConceptSetFile(filePath = f, label = label, domain = domain,
                               tags = list(category = category))
  }

  add_cs(manifest, "Primary Drug",   "drug_exposure",        "primary")
  add_cs(manifest, "Secondary Cond", "condition_occurrence", "secondary")
  add_cs(manifest, "Primary Cond",   "condition_occurrence", "primary")

  # match = 'any': both primary and drug_exposure concepts returned
  any_result <- manifest$queryConceptSetsByTag(
    c("category: primary", "domain: drug_exposure"),
    match = "any"
  )
  expect_true(nrow(any_result) >= 2)

  # match = 'all': only the one with BOTH tags
  all_result <- manifest$queryConceptSetsByTag(
    c("category: primary", "domain: drug_exposure"),
    match = "all"
  )
  expect_equal(nrow(all_result), 1)
  expect_equal(all_result$label[1], "Primary Drug")
})

# ---- permanentlyDeleteConceptSet ----

test_that("permanentlyDeleteConceptSet errors without confirm=TRUE", {
  temp_dir <- tempfile(prefix = "picard_csm_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  db_path <- file.path(temp_dir, "test.sqlite")
  manifest <- ConceptSetManifest$new(dbPath = db_path)
  manifest$addConceptSetFile(filePath = temp_json, label = "To Delete")

  expect_error(manifest$permanentlyDeleteConceptSet(1L))
  expect_error(manifest$permanentlyDeleteConceptSet(1L, confirm = FALSE))
})

test_that("permanentlyDeleteConceptSet succeeds with confirm=TRUE", {
  temp_dir <- tempfile(prefix = "picard_csm_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  db_path <- file.path(temp_dir, "test.sqlite")
  manifest <- ConceptSetManifest$new(dbPath = db_path)
  manifest$addConceptSetFile(filePath = temp_json, label = "To Delete")

  result <- manifest$permanentlyDeleteConceptSet(1L, confirm = TRUE)
  expect_true(isTRUE(result))

  # Record should be gone
  expect_null(manifest$queryConceptSetsByIds(1L))
})

# ---- syncManifest ----

test_that("syncManifest detects new files and adds them", {
  temp_dir <- tempfile(prefix = "picard_csm_")
  json_dir <- file.path(temp_dir, "json")
  dir.create(json_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Create initial concept set and manifest
  f1 <- file.path(json_dir, "cs1.json")
  writeLines(make_circe_concept_set_json(), f1)

  db_path <- file.path(temp_dir, "conceptSetManifest.sqlite")
  manifest <- ConceptSetManifest$new(dbPath = db_path)
  manifest$addConceptSetFile(filePath = f1, label = "CS1")

  # Add a new file on disk
  f2 <- file.path(json_dir, "cs2.json")
  writeLines(make_circe_concept_set_json(), f2)

  sync_results <- manifest$syncManifest()

  expect_true(is.data.frame(sync_results))
  expect_true(all(c("id", "label", "action") %in% names(sync_results)))
  expect_true("added" %in% sync_results$action)
})

test_that("syncManifest flags missing files as soft-deleted", {
  temp_dir <- tempfile(prefix = "picard_csm_")
  json_dir <- file.path(temp_dir, "json")
  dir.create(json_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  f1 <- file.path(json_dir, "cs1.json")
  writeLines(make_circe_concept_set_json(), f1)

  db_path <- file.path(temp_dir, "conceptSetManifest.sqlite")
  manifest <- ConceptSetManifest$new(dbPath = db_path)
  manifest$addConceptSetFile(filePath = f1, label = "CS1")

  # Remove the file
  unlink(f1)

  sync_results <- manifest$syncManifest()

  expect_true("missing_flagged" %in% sync_results$action)
  # Validate that the record is now deleted in SQLite
  status_df <- manifest$validateManifest()
  expect_true(any(status_df$status == "deleted"))
})
