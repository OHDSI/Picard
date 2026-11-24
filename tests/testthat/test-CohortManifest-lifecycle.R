# Testing: path helper creates expected temp directory structure for test manifests.
testthat::test_that("cm_test_make_manifest_paths creates required directories", {
  paths <- cm_test_make_manifest_paths("lifecycle-paths")

  testthat::expect_true(fs::dir_exists(paths$root))
  testthat::expect_true(fs::dir_exists(paths$inputs_dir))
  testthat::expect_true(fs::dir_exists(paths$cohorts_dir))
  testthat::expect_true(fs::dir_exists(paths$sql_dir))
  testthat::expect_true(fs::dir_exists(paths$json_dir))
})

# Testing: constructor helper returns CohortManifest with valid db path.
testthat::test_that("cm_test_new_manifest returns manifest and path bundle", {
  setup <- cm_test_new_manifest("lifecycle-new")

  testthat::expect_s3_class(setup$manifest, "CohortManifest")
  testthat::expect_equal(setup$manifest$getDbPath(), setup$paths$db_path)
})

# Testing: tableExists returns TRUE when its query succeeds.
testthat::test_that("tableExists recognizes an existing table", {
  testthat::local_mocked_bindings(
    existsTable = function(connection, databaseSchema, tableName) TRUE,
    .package = "DatabaseConnector"
  )

  testthat::expect_true(tableExists(NULL, "work", "cohort", "postgresql"))
})

# Testing: tableExists returns FALSE for a database-confirmed missing table.
testthat::test_that("tableExists recognizes a missing table", {
  testthat::local_mocked_bindings(
    existsTable = function(connection, databaseSchema, tableName) FALSE,
    .package = "DatabaseConnector"
  )

  testthat::expect_false(tableExists(NULL, "work", "cohort", "postgresql"))
})

# Testing: operational query errors retain their database context.
testthat::test_that("tableExists reports non-missing query failures", {
  testthat::local_mocked_bindings(
    existsTable = function(connection, databaseSchema, tableName) {
      stop("Insufficient privileges to operate on warehouse")
    },
    .package = "DatabaseConnector"
  )

  error <- tryCatch(
    tableExists(NULL, "work", "cohort", "snowflake", databaseName = "study_db"),
    error = function(e) e
  )

  testthat::expect_s3_class(error, "error")
  error_message <- conditionMessage(error)
  testthat::expect_match(error_message, "study_db")
  testthat::expect_match(error_message, "work.cohort")
  testthat::expect_match(error_message, "Insufficient privileges.*warehouse")
  testthat::expect_match(error_message, "checking cohort table existence")
})

# Testing: createCohortTable propagates DDL errors with table context.
testthat::test_that("createCohortTable reports database creation failures", {
  setup <- cm_test_new_manifest("lifecycle-create-table-error")
  manifest <- setup$manifest
  mock_connection <- new.env(parent = emptyenv())
  manifest$setExecutionSettings(list(
    getConnection = function() mock_connection,
    workDatabaseSchema = "work",
    cohortTable = "cohort",
    tempEmulationSchema = NULL,
    databaseName = "study_db",
    getDbms = function() "postgresql"
  ))

  testthat::local_mocked_bindings(
    tableExists = function(...) FALSE,
    .package = "picard"
  )
  testthat::local_mocked_bindings(
    executeSql = function(...) {
      stop("permission denied creating table")
    },
    .package = "DatabaseConnector"
  )

  error <- tryCatch(
    manifest$createCohortTable(type = "main"),
    error = function(e) e
  )

  testthat::expect_s3_class(error, "error")
  error_message <- conditionMessage(error)
  testthat::expect_match(error_message, "study_db")
  testthat::expect_match(error_message, "work.cohort")
  testthat::expect_match(error_message, "permission denied creating table")
})

# Testing: getManifest returns in-memory CohortDef list aligned with nCohorts.
testthat::test_that("getManifest returns list matching nCohorts", {
  setup <- cm_test_seed_manifest_for_queries("lifecycle-getmanifest")
  manifest <- setup$manifest

  items <- manifest$getManifest()

  testthat::expect_type(items, "list")
  testthat::expect_equal(length(items), manifest$nCohorts())
})

# Testing: reloadFromDb refreshes memory and returns self invisibly.
testthat::test_that("reloadFromDb returns self", {
  setup <- cm_test_seed_manifest_for_queries("lifecycle-reload")
  manifest <- setup$manifest

  out <- manifest$reloadFromDb()

  testthat::expect_identical(out, manifest)
})

# Testing: set/get execution settings stores and retrieves arbitrary settings object.
testthat::test_that("setExecutionSettings and getExecutionSettings round-trip", {
  setup <- cm_test_new_manifest("lifecycle-exec-settings")
  manifest <- setup$manifest

  settings_obj <- list(db = "mock", schema = "work")
  manifest$setExecutionSettings(settings_obj)

  testthat::expect_identical(manifest$getExecutionSettings(), settings_obj)
})

# Testing: set/get atlas connection stores and retrieves atlas connection object.
testthat::test_that("setAtlasConnection and getAtlasConnection round-trip", {
  setup <- cm_test_new_manifest("lifecycle-atlas-settings")
  manifest <- setup$manifest

  atlas_obj <- list(baseUrl = "https://atlas.example.org")
  out <- manifest$setAtlasConnection(atlas_obj)

  testthat::expect_identical(out, manifest)
  testthat::expect_identical(manifest$getAtlasConnection(), atlas_obj)
})

# Testing: active-label uniqueness is enforced for cohort registration.
testthat::test_that("duplicate active labels are rejected", {
  setup <- cm_test_new_manifest("lifecycle-label-unique")
  manifest <- setup$manifest
  paths <- setup$paths

  cm_test_add_sql_cohort(manifest, paths, label = "Duplicate Label", category = "Test")

  testthat::expect_error(
    cm_test_add_circe_cohort(manifest, paths, label = "Duplicate Label", category = "Test", fixture_name = "ckd.json")
  )
})

# Testing: one source file registered under two labels yields two independent
# staged copies, one per row, so the 1-row-to-1-file invariant still holds. This
# replaces an earlier expectation that the second registration was *rejected* -
# true only while the caller's own path was registered directly, before
# addSqlCohort() staged its own copy (#158).
testthat::test_that("the same source file registered twice gives each label its own file", {
  setup <- cm_test_new_manifest("lifecycle-filepath-unique")
  manifest <- setup$manifest
  paths <- setup$paths

  for (label in c("SQL Cohort One", "SQL Cohort Two")) {
    cm_test_add_sql_cohort(
      manifest = manifest,
      paths = paths,
      label = label,
      category = "Test",
      fixture_name = "my_custom_cohort.sql"
    )
  }

  one <- cm_test_registered_path(manifest, "SQL Cohort One")
  two <- cm_test_registered_path(manifest, "SQL Cohort Two")

  testthat::expect_false(identical(as.character(one), as.character(two)))
  testthat::expect_true(fs::file_exists(one))
  testthat::expect_true(fs::file_exists(two))
  testthat::expect_identical(fs::path_file(one), "sql_cohort_one.sql")
  testthat::expect_identical(fs::path_file(two), "sql_cohort_two.sql")

  # Both staged copies live inside the repo, which is the point of staging.
  for (f in c(one, two)) {
    testthat::expect_false(
      startsWith(as.character(fs::path_rel(f, start = setup$paths$root)), "..")
    )
  }
})

# ── Path portability ──────────────────────────────────────────────────────────

# Testing: the isolated test harness produces a manifest whose project root is
# discovered structurally (step 1).
testthat::test_that("manifest resolves its project root from the isolated harness", {
  setup <- cm_test_new_manifest("lifecycle-projroot")

  testthat::expect_equal(
    fs::path_norm(setup$manifest$getProjectRoot()),
    fs::path_norm(setup$paths$root)
  )
})

# Testing: new registrations store a repo-root-relative path regardless of the
# working directory the caller registered from (step 4).
testthat::test_that("registration stores a repo-root-relative path from any working directory", {
  setup <- cm_test_new_manifest("lifecycle-register-cwd")
  paths <- setup$paths
  fixture <- testthat::test_path("test_files", "ckd.json")
  testthat::skip_if_not(fs::file_exists(fixture))
  fs::file_copy(fixture, fs::path(paths$json_dir, "ckd.json"))

  nested <- fs::path(paths$root, "analysis", "deep", "here")
  fs::dir_create(nested)

  withr::with_dir(nested, {
    setup$manifest$addCirceCohort(
      filePath = fs::path(paths$json_dir, "ckd.json"),
      label = "CKD", category = "Target"
    )
  })

  row <- cm_test_get_manifest_row(setup$manifest, "CKD")
  testthat::expect_equal(row$file_path[[1]], "inputs/cohorts/json/ckd.json")
})

# Testing: a manifest loads and its cohorts resolve when opened from a working
# directory unrelated to the study repo (step 3).
testthat::test_that("manifest loads from an unrelated working directory", {
  setup <- cm_test_seed_manifest_for_queries("lifecycle-load-unrelated")
  db_path <- setup$manifest$getDbPath()
  n_expected <- setup$manifest$nCohorts()

  withr::with_dir(withr::local_tempdir(), {
    reopened <- CohortManifest$new(dbPath = db_path)
    testthat::expect_equal(length(reopened$getManifest()), n_expected)
    testthat::expect_true(
      all(vapply(reopened$getManifest(), function(cd) fs::file_exists(cd$getFilePath()), logical(1)))
    )
  })
})

# Testing: legacy stored path conventions still resolve on load (step 2/3).
testthat::test_that("legacy stored path conventions resolve on load", {
  setup <- cm_test_seed_manifest_for_queries("lifecycle-legacy-paths")
  manifest <- setup$manifest
  root <- manifest$getProjectRoot()

  rows <- cm_test_all_rows(manifest)
  circe_id <- rows$id[rows$cohort_type == "circe"][1]
  sql_id   <- rows$id[rows$cohort_type == "custom"][1]
  canonical_circe <- rows$file_path[rows$id == circe_id]
  canonical_sql   <- rows$file_path[rows$id == sql_id]

  # manifest-folder-relative (e.g. "json/ckd.json", "sql/foo.sql")
  cm_test_set_stored_path(manifest, circe_id, sub("^inputs/cohorts/", "", canonical_circe))
  cm_test_set_stored_path(manifest, sql_id, sub("^inputs/cohorts/", "", canonical_sql))
  reopened <- CohortManifest$new(dbPath = manifest$getDbPath())
  testthat::expect_equal(length(reopened$getManifest()), nrow(rows))

  # absolute path
  cm_test_set_stored_path(manifest, circe_id, fs::path(root, canonical_circe))
  reopened <- CohortManifest$new(dbPath = manifest$getDbPath())
  testthat::expect_equal(length(reopened$getManifest()), nrow(rows))
})

# Testing: a stored path pointing at a missing file is reported, never silently
# hashed to a sentinel (step 3/7).
testthat::test_that("missing cohort file is reported on load, not silently hashed", {
  setup <- cm_test_seed_manifest_for_queries("lifecycle-missing-file")
  manifest <- setup$manifest
  rows <- cm_test_all_rows(manifest)
  circe_id <- rows$id[rows$cohort_type == "circe"][1]
  original_hash <- rows$hash[rows$id == circe_id]

  cm_test_set_stored_path(manifest, circe_id, "inputs/cohorts/json/does_not_exist.json")

  testthat::expect_message(
    reopened <- CohortManifest$new(dbPath = manifest$getDbPath()),
    "file missing"
  )
  testthat::expect_equal(length(reopened$getManifest()), nrow(rows) - 1L)

  # the stored hash is untouched — nothing recomputed against a missing file
  after <- cm_test_all_rows(manifest)
  testthat::expect_equal(after$hash[after$id == circe_id], original_hash)
})

# Testing: invalid query argument types raise assertion errors.
testthat::test_that("queryCohortsByIds validates input type", {
  setup <- cm_test_seed_manifest_for_queries("lifecycle-query-validation")
  manifest <- setup$manifest

  testthat::expect_error(manifest$queryCohortsByIds("not-an-id"))
})

# Testing: Atlas methods are deferred for this test wave and intentionally skipped.
testthat::test_that("Atlas methods deferred", {
  testthat::skip("Deferred: Atlas API methods are out of scope for this wave (step 9).")
  testthat::expect_true(TRUE)
})

# Testing: executionSettings DBMS methods are out-of-scope and intentionally skipped.
testthat::test_that("executionSettings-dependent methods skipped", {
  testthat::skip("Out-of-scope: DBMS executionSettings methods are intentionally skipped in this wave (step 9).")
  testthat::expect_true(TRUE)
})

# ── File staging (#158) ───────────────────────────────────────────────────────

# Testing: a definition file registered from outside the study repo is copied
# into inputs/ and the row stores the repo-relative path of the copy. Before
# #158 the row stored a "../" escape, which syncManifest() on another machine
# resolved to nothing - soft-deleting the row and cascading to its dependents.
testthat::test_that("a file registered from outside the repo is staged into inputs/", {
  setup <- cm_test_new_manifest("lifecycle-stage-outside")
  manifest <- setup$manifest

  outside_dir <- fs::dir_create(fs::file_temp(pattern = "picard-outside-"))
  outside_sql <- fs::path(outside_dir, "scratch_definition.sql")
  fs::file_copy(cm_test_sql_fixture_path(), outside_sql)

  suppressMessages(manifest$addSqlCohort(
    filePath = outside_sql, label = "Outside Cohort", category = "Target"
  ))

  row <- cm_test_get_manifest_row(manifest, "Outside Cohort")
  stored <- row$file_path[[1]]

  testthat::expect_false(startsWith(stored, ".."))
  testthat::expect_false(fs::is_absolute_path(stored))
  testthat::expect_equal(stored, "inputs/cohorts/sql/outside_cohort.sql")
  testthat::expect_true(fs::file_exists(cm_test_resolve_path(manifest, stored)))

  # The analyst's original is left alone - picard owns only its copy.
  testthat::expect_true(fs::file_exists(outside_sql))
})

# Testing: the staged row survives a reload once the source directory is gone,
# which is the actual cross-machine regression #158 describes.
testthat::test_that("a staged row survives a reload after its source disappears", {
  setup <- cm_test_new_manifest("lifecycle-stage-portable")
  manifest <- setup$manifest

  outside_dir <- fs::dir_create(fs::file_temp(pattern = "picard-outside-"))
  outside_sql <- fs::path(outside_dir, "scratch_definition.sql")
  fs::file_copy(cm_test_sql_fixture_path(), outside_sql)

  suppressMessages(manifest$addSqlCohort(
    filePath = outside_sql, label = "Portable Cohort", category = "Target"
  ))

  # Simulate a collaborator: the source directory never existed for them.
  fs::dir_delete(outside_dir)

  reloaded <- suppressMessages(CohortManifest$new(dbPath = manifest$getDbPath()))
  suppressMessages(reloaded$syncManifest(strict_mode = FALSE))

  row <- cm_test_get_manifest_row(reloaded, "Portable Cohort")
  testthat::expect_equal(nrow(row), 1)
  testthat::expect_equal(row$status[[1]], "active")
})

# Testing: a source that already sits at the destination is registered without
# a redundant copy. This is the dominant case - the builder templates and the
# test helpers both hand over in-repo paths.
testthat::test_that("staging a file already at its destination is a no-op", {
  setup <- cm_test_new_manifest("lifecycle-stage-noop")
  manifest <- setup$manifest

  in_place <- fs::path(setup$paths$sql_dir, "already_there.sql")
  fs::file_copy(cm_test_sql_fixture_path(), in_place)

  suppressMessages(manifest$addSqlCohort(
    filePath = in_place, label = "Already There", category = "Target"
  ))

  row <- cm_test_get_manifest_row(manifest, "Already There")
  testthat::expect_equal(row$file_path[[1]], "inputs/cohorts/sql/already_there.sql")
  testthat::expect_true(fs::file_exists(in_place))
})

# Testing: two labels that reduce to the same filename are rejected, and the
# first cohort's definition survives. Before #158 the second registration
# overwrote the first file and only then failed on the unique index, destroying
# a definition with no actionable error.
testthat::test_that("labels colliding on a filename are rejected without touching the first file", {
  setup <- cm_test_new_manifest("lifecycle-stage-collision")
  manifest <- setup$manifest

  suppressMessages(manifest$addSqlCohort(
    filePath = cm_test_sql_fixture_path(), label = "T2D broad", category = "Target"
  ))
  registered <- cm_test_registered_path(manifest, "T2D broad")
  before <- readr::read_file(registered)

  testthat::expect_error(
    suppressMessages(manifest$addSqlCohort(
      filePath = cm_test_sql_fixture_path(), label = "T2D (broad)", category = "Target"
    )),
    regexp = "would\\s+overwrite"
  )

  testthat::expect_identical(readr::read_file(registered), before)
  testthat::expect_equal(nrow(cm_test_get_manifest_row(manifest, "T2D (broad)")), 0L)
})

# Testing: an unregistered file sitting at the destination is reported rather
# than silently overwritten. More likely once #166 stops auto-removing orphans.
testthat::test_that("an unregistered file at the destination is not overwritten", {
  setup <- cm_test_new_manifest("lifecycle-stage-orphan")
  manifest <- setup$manifest

  orphan <- fs::path(setup$paths$sql_dir, "orphan_cohort.sql")
  readr::write_lines("-- an orphan, not in the manifest", orphan)

  testthat::expect_error(
    suppressMessages(manifest$addSqlCohort(
      filePath = cm_test_sql_fixture_path(), label = "Orphan Cohort", category = "Target"
    )),
    regexp = "not\\s+in\\s+the\\s+manifest"
  )

  testthat::expect_identical(
    readr::read_file(orphan), "-- an orphan, not in the manifest\n"
  )
})

# Testing: the rollback that removes a staged copy when registration fails.
# Every add*() route validates before it stages, so this guard is defensive -
# there is no reachable post-staging failure to drive it through the public API.
# It is unit-tested directly rather than through a contrived one.
testthat::test_that("manifest_unstage_file removes a staged copy but never a no-op one", {
  dir <- fs::dir_create(fs::file_temp(pattern = "picard-unstage-"))
  staged <- fs::path(dir, "staged.sql")
  readr::write_lines("-- staged by this call", staged)

  removed <- manifest_unstage_file(list(path = as.character(staged), action = "write"))
  testthat::expect_true(removed)
  testthat::expect_false(fs::file_exists(staged))

  # A "noop" destination was already in place and belongs to the analyst.
  kept <- fs::path(dir, "pre_existing.sql")
  readr::write_lines("-- the analyst put this here", kept)

  removed <- manifest_unstage_file(list(path = as.character(kept), action = "noop"))
  testthat::expect_false(removed)
  testthat::expect_true(fs::file_exists(kept))

  # Nothing to undo is not an error.
  testthat::expect_false(
    manifest_unstage_file(list(path = fs::path(dir, "absent.sql"), action = "write"))
  )
})

# Testing: a label with nothing usable in a filename is refused up front rather
# than producing a file called ".sql".
testthat::test_that("a label with no filename-usable characters is rejected", {
  setup <- cm_test_new_manifest("lifecycle-stage-bad-label")
  manifest <- setup$manifest

  testthat::expect_error(
    suppressMessages(manifest$addSqlCohort(
      filePath = cm_test_sql_fixture_path(), label = "---", category = "Target"
    )),
    regexp = "no\\s+characters\\s+usable\\s+in\\s+a\\s+filename"
  )
})

# Testing: load files carrying the retired file_name column are rejected, not
# silently turned into a tag (which would also enter getManifestHash()).
testthat::test_that("a load file with the retired file_name column is rejected", {
  setup <- cm_test_new_manifest("lifecycle-retired-column")
  manifest <- setup$manifest

  cohortsLoad <- data.frame(
    atlasId = 1L, label = "Some Cohort", category = "Target",
    file_name = "some_cohort.json", stringsAsFactors = FALSE
  )

  testthat::expect_error(
    suppressMessages(manifest$importAtlasCohorts(cohortsLoad = cohortsLoad)),
    regexp = "no\\s+longer\\s+uses"
  )
})

# ── Unguarded dbPath (#69) ────────────────────────────────────────────────────

# Testing: connecting to a manifest path is guarded, because
# DBI::dbConnect(RSQLite::SQLite(), path) *creates* a zero-byte file at a
# nonexistent path. Unguarded, that manufactured a table-less database and every
# later query failed with an opaque "no such table" — and left the bogus file
# behind, so the next run looked corrupt rather than missing.
testthat::test_that("a manifest helper given a nonexistent dbPath aborts without creating a file", {
  dir <- fs::dir_create(fs::file_temp(pattern = "picard-no-manifest-"))
  missing <- fs::path(dir, "cohortManifest.sqlite")

  testthat::expect_error(
    findTransitiveDependents(as.character(missing), 1L),
    regexp = "No\\s+manifest\\s+database"
  )

  testthat::expect_false(fs::file_exists(missing))
})

# Testing: a repo already left in the broken state gets an actionable message
# naming the missing table, not a raw SQLite error.
testthat::test_that("a table-less sqlite is reported as not a picard manifest", {
  dir <- fs::dir_create(fs::file_temp(pattern = "picard-empty-manifest-"))
  bogus <- fs::path(dir, "cohortManifest.sqlite")

  conn <- DBI::dbConnect(RSQLite::SQLite(), bogus)
  DBI::dbDisconnect(conn)
  testthat::expect_true(fs::file_exists(bogus))

  testthat::expect_error(
    findTransitiveDependents(as.character(bogus), 1L),
    regexp = "no\\s+cohort_manifest\\s+table"
  )
})

# Testing: every manifest helper that opens its own connection is guarded, not
# just the one above.
testthat::test_that("all dbPath-taking manifest helpers are guarded", {
  dir <- fs::dir_create(fs::file_temp(pattern = "picard-guard-all-"))
  missing <- as.character(fs::path(dir, "cohortManifest.sqlite"))

  testthat::expect_error(findTransitiveDependents(missing, 1L), regexp = "No\\s+manifest\\s+database")
  testthat::expect_error(cascadeStaleDownstream(missing, 1L), regexp = "No\\s+manifest\\s+database")
  testthat::expect_error(build_dependency_graph(missing), regexp = "No\\s+manifest\\s+database")

  testthat::expect_false(fs::file_exists(missing))
})
