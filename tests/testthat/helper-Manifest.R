# Purpose: Write the structural marker files/dirs that findStudyProjectRoot() looks
# for, so an isolated temp tree resolves as a real Picard study repository root.
cm_test_write_project_markers <- function(root) {
  fs::dir_create(root)
  fs::file_create(fs::path(root, "config.yml"))
  fs::file_create(fs::path(root, "README.md"))
  fs::dir_create(fs::path(root, "analysis"))
  fs::dir_create(fs::path(root, "inputs"))
  fs::dir_create(fs::path(root, "dissemination"))
  invisible(root)
}

# Purpose: Create an isolated temporary inputs/cohorts directory tree and sqlite path for a test run.
cm_test_make_manifest_paths <- function(test_name = "cohortmanifest") {
  root <- fs::file_temp(pattern = paste0("picard-", test_name, "-"))
  cm_test_write_project_markers(root)

  inputs_dir <- fs::path(root, "inputs")
  cohorts_dir <- fs::path(inputs_dir, "cohorts")
  sql_dir <- fs::path(cohorts_dir, "sql")
  json_dir <- fs::path(cohorts_dir, "json")

  fs::dir_create(cohorts_dir)
  fs::dir_create(sql_dir)
  fs::dir_create(json_dir)

  ll <- list(
    root = root,
    inputs_dir = inputs_dir,
    cohorts_dir = cohorts_dir,
    sql_dir = sql_dir,
    json_dir = json_dir,
    db_path = fs::path(cohorts_dir, "cohortManifest.sqlite")
  )
  return(ll)
}

# Purpose: Fetch the raw sqlite manifest row(s) for a label (any status).
cm_test_get_manifest_row <- function(manifest, label) {
  conn <- DBI::dbConnect(RSQLite::SQLite(), manifest$getDbPath())
  on.exit(DBI::dbDisconnect(conn))
  DBI::dbGetQuery(
    conn,
    "SELECT * FROM cohort_manifest WHERE label = ?",
    list(label)
  )
}

# Purpose: Overwrite a manifest row's stored file_path directly in sqlite, to
# simulate a row written under a legacy path convention (absolute,
# manifest-folder-relative, working-directory-relative).
cm_test_set_stored_path <- function(manifest, id, path) {
  conn <- DBI::dbConnect(RSQLite::SQLite(), manifest$getDbPath())
  on.exit(DBI::dbDisconnect(conn))
  DBI::dbExecute(
    conn,
    "UPDATE cohort_manifest SET file_path = ? WHERE id = ?",
    list(as.character(path), as.integer(id))
  )
  invisible(path)
}

# Purpose: Return the raw sqlite rows for a manifest as a data.frame.
cm_test_all_rows <- function(manifest) {
  conn <- DBI::dbConnect(RSQLite::SQLite(), manifest$getDbPath())
  on.exit(DBI::dbDisconnect(conn))
  DBI::dbGetQuery(conn, "SELECT * FROM cohort_manifest ORDER BY id")
}

# Purpose: Instantiate a fresh CohortManifest bound to the temporary sqlite path.
cm_test_new_manifest <- function(test_name = "cohortmanifest") {
  paths <- cm_test_make_manifest_paths(test_name)
  manifest <- CohortManifest$new(dbPath = paths$db_path)

  ll <- list(
    manifest = manifest,
    paths = paths
  )
  return(ll)
}

# Purpose: Resolve a SQL fixture path from tests/testthat/test_files and skip if missing.
cm_test_sql_fixture_path <- function(fixture_name = "my_custom_cohort.sql") {
  sql_path <- testthat::test_path("test_files", fixture_name)
  testthat::skip_if_not(
    fs::file_exists(sql_path),
    message = paste("Missing SQL test fixture:", fixture_name)
  )

  return(sql_path)
}

# Purpose: Add a custom SQL cohort to the manifest using a fixture SQL file.
# Registers a copy in the manifest's temp sql dir so tests that hard-delete
# cohorts (deleteCohort unlinks file_path) remove the copy, not the shared
# fixture in test_files.
cm_test_add_sql_cohort <- function(manifest, paths, label, category = "Test", tags = list(), fixture_name = "my_custom_cohort.sql") {
  sql_path <- cm_test_sql_fixture_path(fixture_name = fixture_name)
  local_sql <- fs::path(paths$sql_dir, fixture_name)
  fs::file_copy(sql_path, local_sql, overwrite = TRUE)

  manifest$addSqlCohort(
    filePath = local_sql,
    label = label,
    category = category,
    tags = tags
  )
}

# Purpose: Add a CIRCE cohort to the manifest using a fixture JSON file.
# Copies the fixture into the manifest's temp json/ dir first, mirroring the
# real workflow (JSON lives under inputs/cohorts/json/ inside the study repo).
cm_test_add_circe_cohort <- function(manifest, paths, label, category = "Test", tags = list(), fixture_name = "ckd.json") {
  circe_path <- testthat::test_path("test_files", fixture_name)
  testthat::skip_if_not(
    fs::file_exists(circe_path),
    message = paste("Missing CIRCE test fixture:", fixture_name)
  )

  local_json <- fs::path(paths$json_dir, fixture_name)
  fs::file_copy(circe_path, local_json, overwrite = TRUE)

  manifest$addCirceCohort(
    filePath = local_json,
    label = label,
    category = category,
    tags = tags
  )
}

# Purpose: Build a minimal Capr cohort object for tests; skip when Capr is unavailable.
# prior_days varies the observation window so tests can produce distinct definitions.
cm_test_make_minimal_capr_cohort <- function(prior_days = 0L) {
  testthat::skip_if_not_installed("Capr")

  capr_ns <- asNamespace("Capr")
  required_fns <- c("cohort", "entry", "conditionOccurrence", "cs", "descendants", "continuousObservation")

  missing_fns <- required_fns[!vapply(required_fns, exists, logical(1), envir = capr_ns, inherits = FALSE)]
  if (length(missing_fns) > 0) {
    testthat::skip(paste("Capr API missing required functions:", paste(missing_fns, collapse = ", ")))
  }

  cohort_fn <- get("cohort", envir = capr_ns, inherits = FALSE)
  entry_fn <- get("entry", envir = capr_ns, inherits = FALSE)
  condition_fn <- get("conditionOccurrence", envir = capr_ns, inherits = FALSE)
  cs_fn <- get("cs", envir = capr_ns, inherits = FALSE)
  descendants_fn <- get("descendants", envir = capr_ns, inherits = FALSE)
  continuous_observation_fn <- get("continuousObservation", envir = capr_ns, inherits = FALSE)

  cohort_obj <- tryCatch(
    {
      cs_obj <- cs_fn(descendants_fn(201826), name = "t2d")
      cohort_fn(
        entry = entry_fn(
          condition_fn(cs_obj),
          observationWindow = continuous_observation_fn(priorDays = prior_days, postDays = 0L),
          primaryCriteriaLimit = "First"
        )
      )
    },
    error = function(e) {
      testthat::skip(paste("Unable to create minimal Capr cohort in test helper:", conditionMessage(e)))
    }
  )

  return(cohort_obj)
}

# Purpose: Add a Capr cohort to the manifest using the minimal Capr test cohort object.
cm_test_add_capr_cohort <- function(manifest, label, category = "Test", tags = list()) {
  capr_cohort <- cm_test_make_minimal_capr_cohort()

  manifest$addCaprCohort(
    caprCohort = capr_cohort,
    label = label,
    category = category,
    tags = tags
  )
}

# Purpose: Resolve a manifest-stored (repo-root-relative) file_path to an absolute
# path, for test code that reads or stats the file directly. The test working
# directory is tests/testthat, not the temp study repo, so raw stored paths do
# not resolve on their own.
cm_test_resolve_path <- function(manifest, stored_path) {
  as.character(fs::path(manifest$getProjectRoot(), stored_path))
}

# Purpose: Express an absolute path the way the manifest stores it (relative to
# the study repo root), for equality assertions against a stored file_path.
cm_test_rel_path <- function(manifest, path) {
  as.character(fs::path_rel(fs::path_abs(path), start = manifest$getProjectRoot()))
}

# Purpose: Assert that a cohort exists in the manifest with optional source/cohort type checks.
cm_test_assert_cohort_registered <- function(manifest, label, expected_source_type = NULL, expected_cohort_type = NULL) {
  rows <- manifest$queryCohortsByLabel(labels = label, matchType = "exact")

  testthat::expect_equal(nrow(rows), 1)
  testthat::expect_equal(rows$label[[1]], label)

  if (!is.null(expected_source_type)) {
    testthat::expect_equal(rows$source_type[[1]], expected_source_type)
  }

  if (!is.null(expected_cohort_type)) {
    testthat::expect_equal(rows$cohort_type[[1]], expected_cohort_type)
  }

  # Stored paths are repo-root-relative; resolve against the manifest's project
  # root before checking disk (the test working directory is tests/testthat).
  testthat::expect_true(
    fs::file_exists(fs::path(manifest$getProjectRoot(), rows$file_path[[1]]))
  )
}

# Purpose: Seed a baseline manifest for query/retrieval tests with fixture cohorts.
cm_test_seed_manifest_for_queries <- function(test_name = "cohortmanifest-query") {
  setup <- cm_test_new_manifest(test_name = test_name)
  manifest <- setup$manifest
  paths <- setup$paths

  cm_test_add_circe_cohort(
    manifest = manifest,
    paths = paths,
    label = "Chronic Kidney Disease",
    category = "Target",
    tags = list(domain = "renal", group = "base"),
    fixture_name = "ckd.json"
  )

  cm_test_add_circe_cohort(
    manifest = manifest,
    paths = paths,
    label = "Type 2 Diabetes",
    category = "Comparator",
    tags = list(domain = "metabolic", group = "base"),
    fixture_name = "t2d.json"
  )

  cm_test_add_sql_cohort(
    manifest = manifest,
    paths = paths,
    label = "Custom SQL Cohort",
    category = "Outcome",
    tags = list(route = "custom_sql", group = "base"),
    fixture_name = "my_custom_cohort.sql"
  )

  cm_test_add_circe_cohort(
    manifest = manifest,
    paths = paths,
    label = "Major Bleeding Outcome",
    category = "Outcome",
    tags = list(domain = "bleed", group = "base"),
    fixture_name = "gi_bleed.json"
  )

  cm_test_add_circe_cohort(
    manifest = manifest,
    paths = paths,
    label = "All-Cause Death",
    category = "Outcome",
    tags = list(domain = "mortality", group = "base"),
    fixture_name = "death.json"
  )

  ll <- list(
    manifest = manifest,
    paths = paths,
    cohorts = manifest$tabulateManifest(filter = "active")
  )
  return(ll)
}

# Purpose: Seed a builder-ready manifest and register one dependent custom cohort.
cm_test_seed_manifest_for_builders <- function(test_name = "cohortmanifest-builders") {
  setup <- cm_test_seed_manifest_for_queries(test_name = test_name)
  manifest <- setup$manifest

  # Add a dependent custom cohort from vignette fixture using existing manifest IDs.
  base_rows <- manifest$tabulateManifest(filter = "active")
  inc_id <- base_rows$id[base_rows$label == "Chronic Kidney Disease"][1]
  exc_id <- base_rows$id[base_rows$label == "Type 2 Diabetes"][1]

  dep_sql <- cm_test_sql_fixture_path("my_custom_dependent.sql")
  manifest$addDependentCustomCohort(
    filePath = dep_sql,
    label = "Eligible_With_Exclusions",
    category = "Derived Cohorts",
    dependentCohortIdList = list(
      inc_cohort_id = as.integer(inc_id),
      exc_cohort_id = as.integer(exc_id)
    ),
    tags = list(owner = "epi_team", source = "custom_sql")
  )

  ll <- list(
    manifest = manifest,
    paths = setup$paths,
    cohorts = manifest$tabulateManifest(filter = "active")
  )
  return(ll)
}
