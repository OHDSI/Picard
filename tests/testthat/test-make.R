testthat::test_that("setContributor and makeStudyMeta create expected R6 objects", {
  contributor <- setContributor(
    name = "Example Contributor",
    email = "contributor@example.org",
    role = "developer"
  )

  study_meta <- makeStudyMeta(
    studyTitle = "Sample Prevalence Study",
    therapeuticArea = "TA_PLACEHOLDER",
    studyType = "Characterization",
    contributors = list(contributor),
    studyTags = c("OMOP", "OHDSI", "TEST")
  )

  testthat::expect_s3_class(contributor, "ContributorLine")
  testthat::expect_s3_class(study_meta, "StudyMeta")
  testthat::expect_equal(study_meta$studyTitle, "Sample Prevalence Study")
  testthat::expect_true(grepl("Example Contributor", study_meta$listContributors(), fixed = TRUE))
})

testthat::test_that("makeBlock builds DbConfigBlock with sanitized placeholders", {
  db_block <- makeBlock(
    configBlockName = "db_placeholder",
    cdmDatabaseSchema = "cdm_schema_placeholder",
    databaseName = "db_name_placeholder",
    cohortTable = "cohort_table_placeholder",
    databaseLabel = "Database Placeholder",
    dbServer = "server_placeholder",
    workDatabaseSchema = "work_schema_placeholder",
    tempEmulationSchema = "temp_schema_placeholder"
  )

  testthat::expect_s3_class(db_block, "DbConfigBlock")
  testthat::expect_equal(db_block$configBlockName, "db_placeholder")
  testthat::expect_equal(db_block$dbServer, "server_placeholder")

  block_text <- db_block$writeBlockSection()
  testthat::expect_true(grepl("cdm_schema_placeholder", block_text, fixed = TRUE))
  testthat::expect_true(grepl("work_schema_placeholder", block_text, fixed = TRUE))
})

testthat::test_that("makeUlyssesStudySettings initializes a standard repository structure in temp folder", {
  root_dir <- fs::file_temp("picard-make-test-")
  fs::dir_create(root_dir)
  on.exit(fs::dir_delete(root_dir), add = TRUE)

  sm <- makeStudyMeta(
    studyTitle = "Sample Prevalence Study",
    therapeuticArea = "TA_PLACEHOLDER",
    studyType = "Characterization",
    contributors = list(
      setContributor(
        name = "Example Contributor",
        email = "contributor@example.org",
        role = "developer"
      )
    ),
    studyTags = c("OMOP", "OHDSI", "TEST")
  )

  db <- makeBlock(
    configBlockName = "db_placeholder",
    cdmDatabaseSchema = "cdm_schema_placeholder",
    databaseName = "db_name_placeholder",
    cohortTable = "cohort_table_placeholder",
    databaseLabel = "Database Placeholder",
    dbServer = "server_placeholder",
    workDatabaseSchema = "work_schema_placeholder",
    tempEmulationSchema = "temp_schema_placeholder"
  )

  uly <- makeUlyssesStudySettings(
    repoName = "test_repo",
    repoFolder = as.character(root_dir),
    studyMeta = sm,
    dbConnectionBlocks = list(db)
  )

  testthat::expect_s3_class(uly, "UlyssesStudy")
  testthat::expect_no_error(uly$initUlyssesRepo(verbose = FALSE, openProject = FALSE))

  repo_path <- fs::path(root_dir, "test_repo")

  expected_dirs <- c(
    "inputs/cohorts/json",
    "inputs/cohorts/sql",
    "inputs/cohorts/derived",
    "inputs/cohorts/R",
    "inputs/conceptSets/json",
    "inputs/conceptSets/R",
    "analysis/src",
    "analysis/tasks",
    "exec/logs",
    "exec/results",
    "dissemination/quarto",
    "dissemination/export/merge",
    "dissemination/export/pretty",
    "dissemination/export/studyHubOutput",
    "dissemination/documents",
    "extras"
  )

  for (rel_path in expected_dirs) {
    testthat::expect_true(fs::dir_exists(fs::path(repo_path, rel_path)), info = rel_path)
  }

  expected_files <- c(
    "config.yml",
    "README.md",
    "NEWS.md",
    "main.R",
    "AGENTS.md",
    ".agent/reference-docs/01-repository-structure.md",
    ".agent/skills/picard-capr-cohorts/SKILL.md",
    "test_repo.Rproj"
  )

  for (rel_path in expected_files) {
    testthat::expect_true(fs::file_exists(fs::path(repo_path, rel_path)), info = rel_path)
  }

  config_text <- readr::read_file(fs::path(repo_path, "config.yml"))
  testthat::expect_true(grepl("cdm_schema_placeholder", config_text, fixed = TRUE))
  testthat::expect_true(grepl("work_schema_placeholder", config_text, fixed = TRUE))
  testthat::expect_false(grepl("boehringer|lavallem|rwesnow", config_text, ignore.case = TRUE))
})

testthat::test_that("addBlock appends and overwrite logic works for config.yml", {
  root_dir <- fs::file_temp("picard-addblock-test-")
  fs::dir_create(root_dir)
  on.exit(fs::dir_delete(root_dir), add = TRUE)

  sm <- makeStudyMeta(
    studyTitle = "Block Update Study",
    therapeuticArea = "TA_PLACEHOLDER",
    studyType = "Characterization",
    contributors = list(
      setContributor(
        name = "Example Contributor",
        email = "contributor@example.org",
        role = "developer"
      )
    )
  )

  initial_block <- makeBlock(
    configBlockName = "db_main",
    cdmDatabaseSchema = "cdm_schema_initial",
    databaseName = "db_initial",
    cohortTable = "cohort_table_initial",
    databaseLabel = "DB Initial",
    dbServer = "server_main",
    workDatabaseSchema = "work_schema_initial",
    tempEmulationSchema = "temp_schema_initial"
  )

  uly <- makeUlyssesStudySettings(
    repoName = "block_repo",
    repoFolder = as.character(root_dir),
    studyMeta = sm,
    dbConnectionBlocks = list(initial_block)
  )

  uly$initUlyssesRepo(verbose = FALSE, openProject = FALSE)

  config_path <- fs::path(root_dir, "block_repo", "config.yml")

  new_block <- makeBlock(
    configBlockName = "db_secondary",
    cdmDatabaseSchema = "cdm_schema_secondary",
    databaseName = "db_secondary",
    cohortTable = "cohort_table_secondary",
    databaseLabel = "DB Secondary",
    dbServer = "server_secondary",
    workDatabaseSchema = "work_schema_secondary",
    tempEmulationSchema = "temp_schema_secondary"
  )

  testthat::expect_true(isTRUE(addBlock(new_block, configFilePath = config_path)))
  cfg <- readr::read_file(config_path)
  testthat::expect_true(grepl("db_secondary:", cfg, fixed = TRUE))

  duplicate_block <- makeBlock(
    configBlockName = "db_secondary",
    cdmDatabaseSchema = "cdm_schema_replacement",
    databaseName = "db_secondary_replacement",
    cohortTable = "cohort_table_secondary_replacement",
    databaseLabel = "DB Secondary Replacement",
    dbServer = "server_secondary",
    workDatabaseSchema = "work_schema_secondary_replacement",
    tempEmulationSchema = "temp_schema_secondary_replacement"
  )

  testthat::expect_error(
    addBlock(duplicate_block, configFilePath = config_path, overwrite = FALSE)
  )

  testthat::expect_true(isTRUE(addBlock(duplicate_block, configFilePath = config_path, overwrite = TRUE)))

  cfg2 <- readr::read_file(config_path)
  testthat::expect_true(grepl("cdm_schema_replacement", cfg2, fixed = TRUE))
})


testthat::test_that("makeTaskFile creates a numbered task script in analysis/tasks", {
  repo_ctx <- make_test_repo_for_file_creation("task_repo")
  on.exit(fs::dir_delete(repo_ctx$root_dir), add = TRUE)

  testthat::expect_no_error(
    makeTaskFile(
      nameOfTask = "Incidence Summary Table",
      author = "QA Analyst",
      description = "Create incidence summary output",
      projectPath = repo_ctx$repo_path,
      openFile = FALSE
    )
  )

  task_files <- fs::dir_ls(
    fs::path(repo_ctx$repo_path, "analysis/tasks"),
    glob = "*_incidence_summary_table.R",
    type = "file"
  )

  testthat::expect_equal(length(task_files), 1)
  task_text <- readr::read_file(task_files[[1]])
  testthat::expect_true(grepl("QA Analyst", task_text, fixed = TRUE))
  testthat::expect_true(grepl("Create incidence summary output", task_text, fixed = TRUE))
})

testthat::test_that("makeSrcFile creates a snake_case utility R file in analysis/src", {
  repo_ctx <- make_test_repo_for_file_creation("src_repo")
  on.exit(fs::dir_delete(repo_ctx$root_dir), add = TRUE)

  testthat::expect_no_error(
    makeSrcFile(
      fileName = "Patient Utility Helpers",
      author = "QA Analyst",
      description = "Utility helpers for sanitized tests",
      projectPath = repo_ctx$repo_path,
      openFile = FALSE
    )
  )

  src_path <- fs::path(repo_ctx$repo_path, "analysis/src/patient_utility_helpers.R")
  testthat::expect_true(fs::file_exists(src_path))

  src_text <- readr::read_file(src_path)
  testthat::expect_true(grepl("QA Analyst", src_text, fixed = TRUE))
  testthat::expect_true(grepl("Utility helpers for sanitized tests", src_text, fixed = TRUE))
})

testthat::test_that("makeSrcSqlFile creates a snake_case sql template in analysis/src/sql", {
  repo_ctx <- make_test_repo_for_file_creation("sql_repo")
  on.exit(fs::dir_delete(repo_ctx$root_dir), add = TRUE)

  testthat::expect_no_error(
    makeSrcSqlFile(
      fileName = "Patient Count Query",
      author = "QA Analyst",
      description = "Sanitized SqlRender query template",
      projectPath = repo_ctx$repo_path,
      openFile = FALSE
    )
  )

  sql_path <- fs::path(repo_ctx$repo_path, "analysis/src/sql/patient_count_query.sql")
  testthat::expect_true(fs::file_exists(sql_path))

  sql_text <- readr::read_file(sql_path)
  testthat::expect_true(grepl("QA Analyst", sql_text, fixed = TRUE))
  testthat::expect_true(grepl("Sanitized SqlRender query template", sql_text, fixed = TRUE))
})

testthat::test_that("makeInputBuilderScript creates builder files for cohorts and concept sets", {
  repo_ctx <- make_test_repo_for_file_creation("builder_repo")
  on.exit(fs::dir_delete(repo_ctx$root_dir), add = TRUE)

  testthat::expect_no_error(
    makeInputBuilderScript(
      type = "importSql",
      category = "cohorts",
      projectPath = repo_ctx$repo_path,
      open = FALSE
    )
  )

  testthat::expect_no_error(
    makeInputBuilderScript(
      type = "importCapr",
      category = "conceptSets",
      projectPath = repo_ctx$repo_path,
      open = FALSE
    )
  )

  testthat::expect_true(fs::file_exists(fs::path(repo_ctx$repo_path, "inputs/cohorts/R/import_sql_cohort.R")))
  testthat::expect_true(fs::file_exists(fs::path(repo_ctx$repo_path, "inputs/conceptSets/R/import_capr_concept_set.R")))
})

testthat::test_that("makeDisseminationScript creates numbered scripts in dissemination/pretty/R", {
  repo_ctx <- make_test_repo_for_file_creation("diss_repo")
  on.exit(fs::dir_delete(repo_ctx$root_dir), add = TRUE)

  diss_dir <- fs::path(repo_ctx$repo_path, "dissemination/pretty/R")
  fs::dir_create(diss_dir)

  before_count <- length(fs::dir_ls(diss_dir, glob = "*.R", type = "file"))

  testthat::expect_no_error(
    makeDisseminationScript(
      name = "format results",
      projectPath = repo_ctx$repo_path,
      open = FALSE
    )
  )

  testthat::expect_no_error(
    makeDisseminationScript(
      name = "studyhub export",
      projectPath = repo_ctx$repo_path,
      open = FALSE
    )
  )

  after_files <- fs::dir_ls(diss_dir, glob = "*.R", type = "file")
  testthat::expect_equal(length(after_files), before_count + 2)
  testthat::expect_equal(length(fs::dir_ls(diss_dir, glob = "*_format_results.R", type = "file")), 1)
  testthat::expect_equal(length(fs::dir_ls(diss_dir, glob = "*_studyhub_export.R", type = "file")), 1)
})

testthat::test_that("makePrintFriendlyFile generates Rmd output from cohort JSON", {
  testthat::skip_if_not_installed("CirceR")

  repo_ctx <- make_test_repo_for_file_creation("printfriendly_repo")
  on.exit(fs::dir_delete(repo_ctx$root_dir), add = TRUE)

  json_target_dir <- fs::path(repo_ctx$repo_path, "inputs/cohorts/json/target")
  fs::dir_create(json_target_dir, recurse = TRUE)

  source_json <- fs::path("tests", "testthat", "test_files", "death.json")
  testthat::expect_true(fs::file_exists(source_json))
  fs::file_copy(source_json, fs::path(json_target_dir, "death.json"), overwrite = TRUE)

  output_base <- fs::path(repo_ctx$repo_path, "AI_translation")

  testthat::expect_no_error(
    makePrintFriendlyFile(
      cohorts_dir = fs::path(repo_ctx$repo_path, "inputs/cohorts"),
      output_base = output_base,
      verbose = FALSE
    )
  )

  out_file <- fs::path(output_base, "printFriendly/target/death - cohort_print_friendly.Rmd")
  testthat::expect_true(fs::file_exists(out_file))
})

testthat::test_that("initAgentMode is a no-op when agent files exist and reset = FALSE", {
  repo_ctx <- make_test_repo_for_file_creation("agent_noop_repo")
  on.exit(fs::dir_delete(repo_ctx$root_dir), add = TRUE)

  instructions_file <- fs::path(repo_ctx$repo_path, "AGENTS.md")
  readr::write_file("user-modified instructions", instructions_file)

  res <- initAgentMode(projectPath = repo_ctx$repo_path, verbose = FALSE)

  testthat::expect_true(res$already_existed)
  testthat::expect_equal(res$files_created, character(0))
  testthat::expect_equal(readr::read_file(instructions_file), "user-modified instructions")
})

testthat::test_that("initAgentMode reset = TRUE replaces existing agent files", {
  repo_ctx <- make_test_repo_for_file_creation("agent_reset_repo")
  on.exit(fs::dir_delete(repo_ctx$root_dir), add = TRUE)

  instructions_file <- fs::path(repo_ctx$repo_path, "AGENTS.md")
  readr::write_file("stale instructions from an old picard version", instructions_file)

  stale_doc <- fs::path(repo_ctx$repo_path, ".agent", "reference-docs", "99-removed-doc.md")
  readr::write_file("doc removed in newer picard versions", stale_doc)

  res <- initAgentMode(projectPath = repo_ctx$repo_path, verbose = FALSE, reset = TRUE)

  testthat::expect_false(res$already_existed)
  testthat::expect_true("AGENTS.md" %in% res$files_created)
  testthat::expect_false(
    grepl("stale instructions", readr::read_file(instructions_file), fixed = TRUE)
  )
  testthat::expect_false(fs::file_exists(stale_doc))
  testthat::expect_true(
    fs::file_exists(fs::path(repo_ctx$repo_path, ".agent", "reference-docs", "01-repository-structure.md"))
  )
})

testthat::test_that("initAgentMode migrates the legacy copilot layout", {
  repo_ctx <- make_test_repo_for_file_creation("agent_legacy_repo")
  on.exit(fs::dir_delete(repo_ctx$root_dir), add = TRUE)

  repo_path <- repo_ctx$repo_path

  # Simulate a repo created by a pre-.agent picard version
  fs::file_delete(fs::path(repo_path, "AGENTS.md"))
  fs::dir_delete(fs::path(repo_path, ".agent"))
  readr::write_file("legacy root instructions", fs::path(repo_path, "copilot-instructions.md"))
  fs::dir_create(fs::path(repo_path, ".github", "reference-docs"))
  readr::write_file("legacy copy", fs::path(repo_path, ".github", "copilot-instructions.md"))
  readr::write_file("legacy doc", fs::path(repo_path, ".github", "reference-docs", "01-old.md"))
  fs::dir_create(fs::path(repo_path, ".github", "workflows"))
  readr::write_file("user workflow", fs::path(repo_path, ".github", "workflows", "check.yml"))
  readr::write_lines(
    c(".Rhistory", ".github/", "copilot-instructions.md", "exec/"),
    fs::path(repo_path, ".gitignore")
  )

  res <- initAgentMode(projectPath = repo_path, verbose = FALSE)

  testthat::expect_false(res$already_existed)
  testthat::expect_true("copilot-instructions.md" %in% res$files_removed)
  testthat::expect_true(fs::file_exists(fs::path(repo_path, "AGENTS.md")))
  testthat::expect_true(fs::dir_exists(fs::path(repo_path, ".agent", "reference-docs")))
  testthat::expect_false(fs::file_exists(fs::path(repo_path, "copilot-instructions.md")))
  testthat::expect_false(fs::file_exists(fs::path(repo_path, ".github", "copilot-instructions.md")))
  testthat::expect_false(fs::dir_exists(fs::path(repo_path, ".github", "reference-docs")))
  # user-managed .github content is preserved
  testthat::expect_true(fs::file_exists(fs::path(repo_path, ".github", "workflows", "check.yml")))

  ignore_lines <- trimws(readr::read_lines(fs::path(repo_path, ".gitignore")))
  testthat::expect_false(".github/" %in% ignore_lines)
  testthat::expect_false("copilot-instructions.md" %in% ignore_lines)
  testthat::expect_true(".agent/" %in% ignore_lines)
  testthat::expect_true("AGENTS.md" %in% ignore_lines)
})
