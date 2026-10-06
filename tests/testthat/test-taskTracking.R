# Testing: .getCohortManifestHash() summarises the cohort manifest for task-rerun
# detection. It delegates to CohortManifest$getManifestHash() (a digest over each
# cohort's definition hash plus its metadata, identity, and dependency
# structure). It must be a pure read, deterministic, and independent of where
# cohort files are stored on disk.

testthat::test_that(".getCohortManifestHash returns NA when there is no manifest", {
  setup <- cm_test_new_manifest("tt-hash-nodb")
  fs::file_delete(setup$paths$db_path)

  testthat::expect_true(is.na(.getCohortManifestHash(projectPath = setup$paths$root)))
})

testthat::test_that(".getCohortManifestHash hashes an empty manifest to a stable sentinel", {
  setup <- cm_test_new_manifest("tt-hash-empty")

  h <- .getCohortManifestHash(projectPath = setup$paths$root)

  testthat::expect_type(h, "character")
  testthat::expect_false(is.na(h))
  testthat::expect_identical(h, .getCohortManifestHash(projectPath = setup$paths$root))
})

testthat::test_that(".getCohortManifestHash changes when a cohort is added and is deterministic", {
  setup <- cm_test_new_manifest("tt-hash-add")
  root <- setup$manifest$getProjectRoot()

  cm_test_add_circe_cohort(setup$manifest, setup$paths, label = "CKD", category = "Target",
                           fixture_name = "ckd.json")
  h1 <- .getCohortManifestHash(projectPath = root)
  cm_test_add_circe_cohort(setup$manifest, setup$paths, label = "T2D", category = "Target",
                           fixture_name = "t2d.json")
  h2 <- .getCohortManifestHash(projectPath = root)

  testthat::expect_false(identical(h1, h2))
  testthat::expect_identical(h2, .getCohortManifestHash(projectPath = root))

  # deterministic from an unrelated working directory
  withr::with_dir(withr::local_tempdir(), {
    testthat::expect_identical(.getCohortManifestHash(projectPath = root), h2)
  })
})

testthat::test_that(".getCohortManifestHash is unaffected by a stored path-convention change", {
  setup <- cm_test_seed_manifest_for_queries("tt-hash-pathonly")
  manifest <- setup$manifest
  root <- manifest$getProjectRoot()
  before <- .getCohortManifestHash(projectPath = root)

  rows <- cm_test_all_rows(manifest)
  circe_id <- rows$id[rows$cohort_type == "circe"][1]
  cm_test_set_stored_path(manifest, circe_id,
                          sub("^inputs/cohorts/", "", rows$file_path[rows$id == circe_id]))

  testthat::expect_identical(.getCohortManifestHash(projectPath = root), before)
})

testthat::test_that(".getCohortManifestHash changes when a cohort's definition changes", {
  setup <- cm_test_seed_manifest_for_queries("tt-hash-content")
  manifest <- setup$manifest
  root <- manifest$getProjectRoot()
  before <- .getCohortManifestHash(projectPath = root)

  # Overwrite one cohort's JSON on disk with a different (valid CIRCE)
  # definition, so its rendered SQL — its definition hash — changes.
  rows <- cm_test_all_rows(manifest)
  target <- rows[rows$label == "Chronic Kidney Disease", ]
  fs::file_copy(
    testthat::test_path("test_files", "t2d.json"),
    cm_test_resolve_path(manifest, target$file_path),
    overwrite = TRUE
  )

  testthat::expect_false(identical(.getCohortManifestHash(projectPath = root), before))
})

testthat::test_that("cohort metadata changes move the manifest hash but not the definition hash", {
  setup <- cm_test_seed_manifest_for_queries("tt-hash-meta")
  manifest <- setup$manifest
  root <- manifest$getProjectRoot()
  id <- cm_test_get_manifest_row(manifest, "Chronic Kidney Disease")$id[[1]]
  definition_hash <- function() {
    cm <- loadCohortManifest(cohortsFolderPath = root, autoSync = FALSE, verbose = FALSE)
    Filter(function(cd) cd$getId() == id, cm$getManifest())[[1]]$getSqlHash()
  }

  before_definition <- definition_hash()
  hashes <- .getCohortManifestHash(projectPath = root)

  suppressMessages(manifest$updateCohortLabel(id, "CKD (renamed)"))
  hashes <- c(hashes, .getCohortManifestHash(projectPath = root))
  suppressMessages(manifest$updateCohortCategory(id, "Comparator"))
  hashes <- c(hashes, .getCohortManifestHash(projectPath = root))
  suppressMessages(manifest$addCohortTag(id, "role", "outcome"))
  hashes <- c(hashes, .getCohortManifestHash(projectPath = root))

  testthat::expect_length(unique(hashes), 4)
  testthat::expect_identical(definition_hash(), before_definition)
})

testthat::test_that("legacy task history gets an empty pipeline version", {
  legacy_history <- data.frame(
    task_name = "01_task.R",
    config_block = "db",
    last_run_time = "2026-01-01 00:00:00",
    task_file_hash = "hash",
    cohort_manifest_hash = "manifest",
    status = "success",
    error_message = "",
    commit_sha = "",
    code_state = "unrecorded",
    stringsAsFactors = FALSE
  )

  history <- .ensureHistoryColumns(legacy_history)

  testthat::expect_true("pipeline_version" %in% names(history))
  testthat::expect_identical(history$pipeline_version[[1]], "")
})

testthat::test_that("task history namespaces are distinct lookup keys", {
  history <- .ensureHistoryColumns(data.frame(
    task_name = c("01_task.R", "01_task.R"),
    config_block = c("db", "db"),
    pipeline_version = c("develop_ml", "develop_ks"),
    last_run_time = c("2026-01-01 00:00:00", "2026-01-02 00:00:00"),
    task_file_hash = c("hash_ml", "hash_ks"),
    cohort_manifest_hash = c("manifest", "manifest"),
    status = c("success", "success"),
    error_message = c("", ""),
    commit_sha = c("", ""),
    code_state = c("unrecorded", "unrecorded"),
    stringsAsFactors = FALSE
  ))

  selected <- history[
    history$task_name == "01_task.R" &
      history$config_block == "db" &
      history$pipeline_version == "develop_ks",
    , drop = FALSE
  ]

  testthat::expect_equal(nrow(selected), 1L)
  testthat::expect_identical(selected$task_file_hash[[1]], "hash_ks")
})

# Concept set manifest hash ------------------------------------------------------

tt_test_concept_set_setup <- function(test_name) {
  root <- fs::file_temp(pattern = paste0("picard-", test_name, "-"))
  cm_test_write_project_markers(root)
  json_dir <- fs::path(root, "inputs", "conceptSets", "json")
  fs::dir_create(json_dir)
  manifest <- suppressMessages(ConceptSetManifest$new(
    dbPath = fs::path(root, "inputs", "conceptSets", "conceptSetManifest.sqlite")
  ))
  list(root = root, json_dir = json_dir, manifest = manifest)
}

tt_test_add_concept_set <- function(setup, label, category = "init", json = '{"items":[]}') {
  json_path <- fs::path(setup$json_dir, paste0(gsub("[^A-Za-z0-9]+", "_", label), ".json"))
  writeLines(json, json_path)
  suppressMessages(setup$manifest$addConceptSetFile(
    filePath = as.character(json_path), label = label, category = category
  ))
  invisible(json_path)
}

testthat::test_that(".getConceptSetManifestHash is a stable sentinel when there is no manifest", {
  root <- fs::file_temp(pattern = "picard-tt-cs-nodb-")
  cm_test_write_project_markers(root)

  h <- .getConceptSetManifestHash(projectPath = root)

  testthat::expect_identical(h, "<no-concept-set-manifest>")
  testthat::expect_false(fs::file_exists(
    fs::path(root, "inputs", "conceptSets", "conceptSetManifest.sqlite")
  ))
})

testthat::test_that(".getConceptSetManifestHash is deterministic and changes when a concept set is added", {
  setup <- tt_test_concept_set_setup("tt-cs-add")
  empty <- .getConceptSetManifestHash(projectPath = setup$root)
  testthat::expect_identical(empty, .getConceptSetManifestHash(projectPath = setup$root))

  tt_test_add_concept_set(setup, "UC Corticosteroids")
  h <- .getConceptSetManifestHash(projectPath = setup$root)

  testthat::expect_false(identical(empty, h))
  testthat::expect_identical(h, .getConceptSetManifestHash(projectPath = setup$root))
})

testthat::test_that("concept set metadata changes move the manifest hash but not the definition hash", {
  setup <- tt_test_concept_set_setup("tt-cs-meta")
  tt_test_add_concept_set(setup, "Prednisone", category = "UC Corticosteroids")
  id <- setup$manifest$getManifest()[[1]]$getId()
  definition_hash <- function() {
    csm <- suppressMessages(ConceptSetManifest$new(dbPath = setup$manifest$getDbPath()))
    csm$getManifest()[[1]]$getHash()
  }

  before_definition <- definition_hash()
  hashes <- .getConceptSetManifestHash(projectPath = setup$root)

  suppressMessages(setup$manifest$updateConceptSetCategory(id, "Corticosteroids"))
  hashes <- c(hashes, .getConceptSetManifestHash(projectPath = setup$root))
  suppressMessages(setup$manifest$updateConceptSetLabel(id, "Prednisolone"))
  hashes <- c(hashes, .getConceptSetManifestHash(projectPath = setup$root))
  suppressMessages(setup$manifest$addConceptSetTag(id, "drugClass", "steroid"))
  hashes <- c(hashes, .getConceptSetManifestHash(projectPath = setup$root))

  testthat::expect_length(unique(hashes), 4)
  testthat::expect_identical(definition_hash(), before_definition)
})

testthat::test_that(".getConceptSetManifestHash changes with the expression but not its formatting", {
  setup <- tt_test_concept_set_setup("tt-cs-content")
  json_path <- tt_test_add_concept_set(setup, "Statins", json = '{"items":[{"concept":{"CONCEPT_ID":1}}]}')
  before <- .getConceptSetManifestHash(projectPath = setup$root)

  writeLines('{\n  "items": [ { "concept": { "CONCEPT_ID": 1 } } ]\n}', json_path)
  testthat::expect_identical(.getConceptSetManifestHash(projectPath = setup$root), before)

  writeLines('{"items":[{"concept":{"CONCEPT_ID":2}}]}', json_path)
  testthat::expect_false(identical(.getConceptSetManifestHash(projectPath = setup$root), before))

  fs::file_delete(json_path)
  testthat::expect_false(identical(.getConceptSetManifestHash(projectPath = setup$root), before))
})

# renv lockfile hash --------------------------------------------------------------

tt_test_write_lock <- function(root, packages, rVersion = "4.4.1") {
  lock <- list(
    R = list(Version = rVersion),
    Packages = lapply(names(packages), function(nm) {
      list(Package = nm, Version = packages[[nm]], Source = "Repository")
    })
  )
  names(lock$Packages) <- names(packages)
  jsonlite::write_json(lock, fs::path(root, "renv.lock"), auto_unbox = TRUE, pretty = TRUE)
}

testthat::test_that(".getRenvLockHash is a stable sentinel when there is no renv.lock", {
  root <- fs::file_temp(pattern = "picard-tt-renv-none-")
  cm_test_write_project_markers(root)

  testthat::expect_identical(.getRenvLockHash(projectPath = root), "<no-renv-lock>")
})

testthat::test_that(".getRenvLockHash changes when a package or R version changes", {
  root <- fs::file_temp(pattern = "picard-tt-renv-change-")
  cm_test_write_project_markers(root)

  tt_test_write_lock(root, list(dplyr = "1.1.4", readr = "2.1.5"))
  before <- .getRenvLockHash(projectPath = root)
  testthat::expect_identical(.getRenvLockHash(projectPath = root), before)

  tt_test_write_lock(root, list(dplyr = "1.1.5", readr = "2.1.5"))
  testthat::expect_false(identical(.getRenvLockHash(projectPath = root), before))

  tt_test_write_lock(root, list(dplyr = "1.1.4", readr = "2.1.5"), rVersion = "4.5.0")
  testthat::expect_false(identical(.getRenvLockHash(projectPath = root), before))
})

testthat::test_that(".getRenvLockHash ignores package order and formatting", {
  root <- fs::file_temp(pattern = "picard-tt-renv-order-")
  cm_test_write_project_markers(root)

  tt_test_write_lock(root, list(dplyr = "1.1.4", readr = "2.1.5"))
  before <- .getRenvLockHash(projectPath = root)

  tt_test_write_lock(root, list(readr = "2.1.5", dplyr = "1.1.4"))
  testthat::expect_identical(.getRenvLockHash(projectPath = root), before)
})

testthat::test_that(".getRenvLockHash returns NA for an unreadable lockfile", {
  root <- fs::file_temp(pattern = "picard-tt-renv-bad-")
  cm_test_write_project_markers(root)
  writeLines("{ not json", fs::path(root, "renv.lock"))

  testthat::expect_true(is.na(suppressMessages(.getRenvLockHash(projectPath = root))))
})

# Rerun decisions -----------------------------------------------------------------

testthat::test_that(".compareRecordedHash fails safe", {
  testthat::expect_length(.compareRecordedHash("a", "a", "x"), 0)
  testthat::expect_identical(.compareRecordedHash("a", "b", "x"), "Change detected in x")
  testthat::expect_identical(.compareRecordedHash("a", "", "x"), "No previous x hash recorded")
  testthat::expect_identical(.compareRecordedHash("a", NULL, "x"), "No previous x hash recorded")
  testthat::expect_match(.compareRecordedHash(NA_character_, "a", "x"), "unavailable")
})

tt_test_local_study <- function(env = parent.frame()) {
  root <- fs::file_temp(pattern = "picard-tt-rerun-")
  cm_test_write_project_markers(root)
  fs::dir_create(fs::path(root, "analysis", "tasks"))
  writeLines("x <- 1", fs::path(root, "analysis", "tasks", "01_task.R"))

  withr::local_dir(root, .local_envir = env)
  testthat::local_mocked_bindings(
    here = function(...) file.path(root, ...),
    .package = "here",
    .env = env
  )
  root
}

tt_test_record_success <- function(root) {
  suppressMessages(recordTaskExecution(
    taskFile = fs::path(root, "analysis", "tasks", "01_task.R"),
    configBlock = "db", pipelineVersion = "1.0.0", status = "success",
    cohortManifestHash = "c1", conceptSetManifestHash = "cs1", renvLockHash = "r1"
  ))
}

tt_test_rerun <- function(root, cohort = "c1", conceptSet = "cs1", renv = "r1") {
  suppressMessages(shouldRerunTask(
    taskFile = fs::path(root, "analysis", "tasks", "01_task.R"),
    configBlock = "db",
    executionSettings = NULL,
    pipelineVersion = "1.0.0",
    cohortManifestHash = cohort,
    conceptSetManifestHash = conceptSet,
    renvLockHash = renv
  ))
}

testthat::test_that("shouldRerunTask skips a task when no input has changed", {
  root <- tt_test_local_study()
  tt_test_record_success(root)

  result <- tt_test_rerun(root)

  testthat::expect_false(result$should_rerun)
  testthat::expect_identical(result$concept_set_manifest_hash, "cs1")
  testthat::expect_identical(result$renv_lock_hash, "r1")
})

testthat::test_that("shouldRerunTask reruns when the concept set manifest or renv.lock changes", {
  root <- tt_test_local_study()
  tt_test_record_success(root)

  conceptSetChange <- tt_test_rerun(root, conceptSet = "cs2")
  testthat::expect_true(conceptSetChange$should_rerun)
  testthat::expect_identical(conceptSetChange$reasons, "Change detected in concept set manifest")

  renvChange <- tt_test_rerun(root, renv = "r2")
  testthat::expect_true(renvChange$should_rerun)
  testthat::expect_identical(renvChange$reasons, "Change detected in renv lockfile")
})

testthat::test_that("shouldRerunTask reruns once for history recorded before the new hash columns", {
  root <- tt_test_local_study()
  taskPath <- fs::path(root, "analysis", "tasks", "01_task.R")
  fs::dir_create(fs::path(root, "exec", "logs"))
  readr::write_csv(
    data.frame(
      task_name = "01_task.R",
      config_block = "db",
      last_run_time = "2026-01-01 00:00:00",
      pipeline_version = "1.0.0",
      task_file_hash = digest::digest(file = taskPath, algo = "sha256"),
      cohort_manifest_hash = "c1",
      status = "success",
      error_message = "",
      commit_sha = "",
      code_state = "unrecorded"
    ),
    fs::path(root, "exec", "logs", "task_run_history.csv")
  )

  result <- tt_test_rerun(root)

  testthat::expect_true(result$should_rerun)
  testthat::expect_setequal(result$reasons, c(
    "No previous concept set manifest hash recorded",
    "No previous renv lockfile hash recorded"
  ))

  tt_test_record_success(root)
  testthat::expect_false(tt_test_rerun(root)$should_rerun)
})

testthat::test_that(".getCohortManifestHash hashes the config block's own manifest", {
  setup <- cm_test_new_manifest("tt-hash-by-block")
  root <- setup$manifest$getProjectRoot()
  readr::write_lines(
    c(
      "default:",
      "  projectName: test",
      "db_a:",
      "  cohortManifestPath: inputs/cohorts/cohortManifest.sqlite",
      "db_b:",
      "  cohortManifestPath: inputs/cohorts/db_b/cohortManifest.sqlite"
    ),
    fs::path(root, "config.yml")
  )
  suppressMessages(initCohortManifest(root, configBlock = "db_b"))
  cm_test_add_circe_cohort(setup$manifest, setup$paths, label = "CKD", fixture_name = "ckd.json")

  hash_a <- .getCohortManifestHash(projectPath = root, configBlock = "db_a")
  hash_b <- .getCohortManifestHash(projectPath = root, configBlock = "db_b")

  testthat::expect_false(is.na(hash_a))
  testthat::expect_false(is.na(hash_b))
  testthat::expect_false(identical(hash_a, hash_b))
  testthat::expect_identical(hash_a, .getCohortManifestHash(projectPath = root))
})
