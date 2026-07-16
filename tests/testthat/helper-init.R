
make_test_repo_for_file_creation <- function(repo_name = "file_creation_repo") {
  root_dir <- fs::file_temp("picard-file-creation-")
  fs::dir_create(root_dir)

  sm <- makeStudyMeta(
    studyTitle = "File Creation Study",
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
    repoName = repo_name,
    repoFolder = as.character(root_dir),
    studyMeta = sm,
    dbConnectionBlocks = list(db)
  )

  uly$initUlyssesRepo(verbose = FALSE, openProject = FALSE)

  ll <- list(root_dir = root_dir, repo_path = fs::path(root_dir, repo_name))
  return(ll)
}