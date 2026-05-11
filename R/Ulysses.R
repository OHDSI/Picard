#' UlyssesStudy R6 Class
#'
#' @description
#' Configuration and initialization class for Ulysses study repositories.
#' This class manages the creation and setup of a new study repository,
#' including directory structure, configuration files, and version control initialization.
#'
#' @details
#' UlyssesStudy encapsulates the configuration needed to set up a new Ulysses-based
#' study environment. It manages study metadata and database connection blocks.
#' Database schema and credential details are held per-block in DbConfigBlock.
#'
#' ## Active Fields
#'
#' - `repoName`: Study repository name (read/write)
#' - `repoFolder`: Parent directory for the repository (read/write)
#' - `studyMeta`: StudyMeta object containing metadata (read/write)
#' - `dbConnectionBlocks`: List of DbConfigBlock objects (read/write)
#' - `gitRemote`: Optional git remote URL (read/write)
#' - `renvLockFile`: Optional path to renv lock file (read/write)
#'
#' ## Methods
#'
#' - `initialize()`: Create and configure a new UlyssesStudy instance
#' - `initUlyssesRepo()`: Initialize the full repository structure
#'
#' @export
UlyssesStudy <- R6::R6Class(
  classname = "UlyssesStudy",
  public = list(
    #' @description
    #' Initialize a new UlyssesStudy instance with configuration parameters.
    #'
    #' @param repoName Character string. Name of the study repository.
    #' @param repoFolder Character string. Parent directory where the repository will be created.
    #' @param studyMeta StudyMeta object. Contains study metadata and configuration.
    #' @param dbConnectionBlocks List of DbConfigBlock objects. Optional database configurations.
    #' @param gitRemote Character string. Optional URL for git remote repository.
    #' @param renvLockFile Character string. Optional path to renv lock file for reproducibility.
    #'
    #' @return Invisibly returns self for method chaining.
    initialize = function(repoName,
                          repoFolder,
                          studyMeta,
                          dbConnectionBlocks = NULL,
                          gitRemote = NULL,
                          renvLockFile = NULL
    ) {

      checkmate::assert_string(x = repoName, min.chars = 1)
      private[[".repoName"]] <- repoName

      checkmate::assert_string(x = repoFolder, min.chars = 1)
      private[[".repoFolder"]] <- repoFolder

      checkmate::assert_class(x = studyMeta, classes = "StudyMeta")
      private[[".studyMeta"]] <- studyMeta

      checkmate::assert_list(x = dbConnectionBlocks, types = "DbConfigBlock", null.ok = TRUE)
      if (!is.null(dbConnectionBlocks)) {
        private[[".dbConnectionBlocks"]] <- dbConnectionBlocks
      }

      checkmate::assert_string(x = gitRemote, null.ok = TRUE)
      private[[".gitRemote"]] <- gitRemote

      checkmate::assert_string(x = renvLockFile, null.ok = TRUE)
      private[[".renvLockFile"]] <- renvLockFile
    },

    #' @description
    #' Initialize the complete Ulysses repository structure and configuration.
    #'
    #' This method performs the following initialization steps:
    #' 1. Creates the R project directory and Rproj file
    #' 2. Establishes the standard directory structure
    #' 3. Creates initialization files (README, NEWS, configuration files)
    #' 4. Sets up Quarto documentation
    #' 5. Creates main execution file
    #' 6. Initializes agent skills configuration
    #' 7. Initializes git repository
    #'
    #' @param verbose Logical. If TRUE (default), displays informative messages during initialization.
    #' @param openProject Logical. If TRUE, opens the project in a new RStudio session after initialization.
    #'
    #' @return Invisibly returns the path to the initialized repository.
    initUlyssesRepo = function(verbose = TRUE, openProject = FALSE) {
      repoPath <- private$.getRepoPath()
      
      if (verbose) cli::cli_h2("Initializing Ulysses Repository")
      
      tryCatch({
        # Step 1: Create repo directory and R project
        if (verbose) cli::cli_inform("Creating R project directory...")
        fs::dir_create(repoPath, recurse = TRUE)
        usethis::local_project(repoPath, force = TRUE)
        private$.initRProj()
        
        # Step 2: Create folder structure
        if (verbose) cli::cli_inform("Creating directory structure...")
        listDefaultFolders(repoPath = repoPath)
        
        # Step 3: Initialize files
        if (verbose) cli::cli_inform("Creating initialization files...")
        private$.initReadMe()
        private$.initNews()
        private$.initConfigFile()
        private$.initQuarto()
        private$.initMainExec()
        private$.initLoadingInputs()   # add after .initTestMainExec()
        private$.initAgent()
        
        # Step 4: Initialize git
        if (verbose) cli::cli_inform("Initializing git repository...")
        private$.initGit()
        
        # Step 5: Add renv lock file if supplied
        if (verbose) cli::cli_inform("Setting up renv configuration...")
        private$.addRenvLockFile()
        
        cli::cli_alert_success("Repository successfully initialized at {repoPath}")
        
        # Open project if requested
        if (openProject) {
          cli::cli_inform("Opening project in new session...")
          rstudioapi::openProject(repoPath, newSession = TRUE)
        }
      }, error = function(e) {
        cli::cli_abort("Failed to initialize repository: {e$message}")
      })
      
      invisible(repoPath)
    }
  ),
  private = list(
    .repoName = NULL,
    .repoFolder = NULL,
    .studyMeta = NULL,
    .dbConnectionBlocks = NULL,
    .gitRemote = NULL,
    .renvLockFile = NULL,

    # Helper method to get expanded repository path
    .getRepoPath = function() {
      fs::path(private$.repoFolder, private$.repoName) |> fs::path_expand()
    },

    # File initialization methods
    .initRProj = function() {
      repoPath <- private$.getRepoPath()
      repoName <- private$.repoName
      
      tryCatch({
        projLines <- fs::path_package("picard", "templates/rproj.txt") |>
          readr::read_file()
        
        projFile <- fs::path(repoPath, repoName, ext = "Rproj")
        readr::write_file(x = projLines, file = projFile)
        
        cli::cli_alert_success("Created {.file {fs::path_rel(projFile)}}")
        
        usethis::use_git_ignore(
          c(".Rproj.user", ".Ruserdata", ".Rhistory", ".RData",
            ".Renviron", "errorReportSql.txt", ".agent/", "copilot-instructions.md", "exec/logs/")
        )
      }, error = function(e) {
        cli::cli_abort("Failed to initialize R project: {e$message}")
      })
      
      invisible(NULL)
    },

    .initReadMe = function() {
      repoPath <- private$.getRepoPath()
      tryCatch({
        initReadMeFn(sm = private$.studyMeta, repoName = private$.repoName, repoPath = repoPath)
      }, error = function(e) {
        cli::cli_abort("Failed to initialize README: {e$message}")
      })
      invisible(NULL)
    },

    .initNews = function() {
      repoPath <- private$.getRepoPath()
      tryCatch({
        initNewsFn(repoName = private$.repoName, repoPath = repoPath)
      }, error = function(e) {
        cli::cli_abort("Failed to initialize NEWS: {e$message}")
      })
      invisible(NULL)
    },

    .makeConfigFile = function() {
      repoPath <- private$.getRepoPath()
      repoName <- private$.repoName
      dbBls <- self$dbConnectionBlocks

      tryCatch({
        if (length(dbBls) > 0) {
          dbBlocks <- purrr::map_chr(
            dbBls,
            ~.x$writeBlockSection()
          ) |> glue::glue_collapse(sep = "\n\n")
        } else {
          dbBlocks <- ""
        }

        header <- fs::path_package(package = "picard", "templates/configHeader.txt") |>
          readr::read_file() |>
          glue::glue()

        configFile <- c(header, dbBlocks) |>
          glue::glue_collapse(sep = "\n\n")

        readr::write_lines(
          x = configFile,
          file = fs::path(repoPath, "config.yml")
        )

        actionItem(glue::glue_col("Initialize Config: {green {fs::path(repoPath, private$.repoName, 'config.yml')}}"))
      }, error = function(e) {
        cli::cli_abort("Failed to initialize config: {e$message}")
      })
      invisible(NULL)
    },

    .initConfigFile = function() {
      repoPath <- private$.getRepoPath()
      tryCatch({
        private$.makeConfigFile()
      }, error = function(e) {
        cli::cli_abort("Failed to initialize config: {e$message}")
      })
      invisible(NULL)
    },

    .initGit = function() {
      repoPath <- private$.getRepoPath()
      tryCatch({
        gert::git_init(repoPath)
        
        if (!is.null(private$.gitRemote)) {
          git_remote_ulysses(
            gitRemoteUrl = private$.gitRemote,
            gitRemoteName = "origin"
          )
        } else {
          gert::git_add(files = ".")
          gert::git_commit_all(message = "Initialize Ulysses Repo for study")
        }
        cli::cli_alert_success("Git repository initialized")
      }, error = function(e) {
        cli::cli_abort("Failed to initialize git: {e$message}")
      })
      invisible(NULL)
    },

    .addRenvLockFile = function() {
      repoPath <- private$.getRepoPath()
      
      if (!is.null(private$.renvLockFile)) {
        tryCatch({
          # Verify source file exists
          if (!fs::file_exists(private$.renvLockFile)) {
            stop("renvLockFile does not exist: ", private$.renvLockFile)
          }
          
          # Copy file to repository root
          fs::file_copy(
            path = private$.renvLockFile,
            new_path = fs::path(repoPath, "renv.lock"),
            overwrite = TRUE
          )
          
          cli::cli_alert_success("renv.lock file copied to {fs::path_rel(repoPath)}")
        }, error = function(e) {
          cli::cli_abort("Failed to copy renv.lock file: {e$message}")
        })
      } else {
        cli::cli_alert_info("No renvLockFile supplied. Consider running {.code renv::init()} in your project to set up a reproducible environment.")
      }
      
      invisible(NULL)
    },

    .initQuarto = function() {
      tryCatch({
        initStudyHubFiles(
          repoName = private$.repoName,
          repoFolder = private$.repoFolder,
          studyTitle = private$.studyMeta$studyTitle
        )
      }, error = function(e) {
        cli::cli_abort("Failed to initialize Quarto files: {e$message}")
      })
      invisible(NULL)
    },

    .initMainExec = function() {
      tryCatch({
        hasBlocks <- length(private$.dbConnectionBlocks) > 0
        configBlocks <- if (hasBlocks) {
          purrr::map_chr(private$.dbConnectionBlocks, ~.x$configBlockName)
        } else {
          ""
        }
        toolType <- if (hasBlocks) "dbms" else "external"
        
        addMainFile(
          repoName = private$.repoName,
          repoFolder = private$.repoFolder,
          toolType = toolType,
          configBlocks = configBlocks,
          studyName = private$.studyMeta$studyTitle
        )
      }, error = function(e) {
        cli::cli_abort("Failed to initialize main execution file: {e$message}")
      })
      invisible(NULL)
    },

    .initLoadingInputs = function() {
      repoPath <- private$.getRepoPath()
      studyName <- private$.studyMeta$studyTitle
      tryCatch({
        loadingInputsR <- fs::path_package("picard", "templates/loadingInputs.R") |>
          readr::read_file() |>
          glue::glue(.open = "{", .close = "}")

        dest <- fs::path(repoPath, "extras", "loadingInputs.R")
        readr::write_file(x = loadingInputsR, file = dest)
        cli::cli_alert_success("Created loading inputs script: {.file {fs::path_rel(dest)}}")
      }, error = function(e) {
        cli::cli_abort("Failed to initialize loading inputs file: {e$message}")
      })
      invisible(NULL)
    },

    .initAgent = function() {
      repoPath <- private$.getRepoPath()
      tryCatch({
        # Create .agent folder
        agent_folder <- fs::path(repoPath, ".agent")
        fs::dir_create(agent_folder)
        
        # Prepare template substitutions for the study
        studyName <- private$.studyMeta$studyTitle
        projectName <- ifelse(
          !is.null(private$.studyMeta$projectName) && private$.studyMeta$projectName != "",
          private$.studyMeta$projectName,
          private$.repoName
        )
        databaseLabel <- "Database"
        hasBlocks <- length(private$.dbConnectionBlocks) > 0
        toolType <- if (hasBlocks) "dbms" else "external"
        repoName <- private$.repoName
        
        # Read and substitute copilot-instructions.md template
        instructions_template <- fs::path_package("picard", "agent/copilot-instructions.md") |>
          readr::read_file()
        
        instructions_content <- glue::glue(instructions_template, .open = "{{", .close = "}}")
        
        # Write to .agent folder for reference
        instructions_file <- fs::path(agent_folder, "copilot-instructions.md")
        readr::write_file(x = instructions_content, file = instructions_file)
        cli::cli_alert_success("Created {.file {fs::path_rel(instructions_file)}}")
        
        # Write to workspace root so Copilot automatically picks it up
        root_instructions_file <- fs::path(repoPath, "copilot-instructions.md")
        readr::write_file(x = instructions_content, file = root_instructions_file)
        cli::cli_alert_success("Created {.file {fs::path_rel(root_instructions_file)}} (workspace root)")
        
        # Copy reference documentation files
        reference_docs_folder <- fs::path(agent_folder, "reference-docs")
        fs::dir_create(reference_docs_folder)
        
        # Get list of reference files from inst/agent
        agent_package_folder <- fs::path_package("picard", "agent")
        
        # List all markdown files and filter for numbered ones
        all_files <- fs::dir_ls(agent_package_folder, type = "file", recurse = FALSE)
        reference_files <- all_files[grepl("^\\d{2}-.*\\.md$", fs::path_file(all_files))]
        
        # Copy each reference file
        if (length(reference_files) > 0) {
          purrr::walk(reference_files, function(ref_file) {
            base_name <- fs::path_file(ref_file)
            dest_file <- fs::path(reference_docs_folder, base_name)
            fs::file_copy(ref_file, dest_file, overwrite = TRUE)
          })
        } else {
          cli::cli_alert_warning("No numbered reference documentation files found in agent package folder")
        }
        
        cli::cli_alert_success(
          "Created {.file {fs::path_rel(reference_docs_folder)}} with {length(reference_files)} reference documents"
        )
        
      }, error = function(e) {
        cli::cli_abort("Failed to initialize agent configuration: {e$message}")
      })
      invisible(NULL)
    }
  ),
  active = list(
    #' @field repoName Study repository name. Can be read or set with validation.
    repoName = function(value) {
      if (missing(value)) return(private$.repoName)
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".repoName"]] <- value
      cli::cli_alert_info("Updated {.field repoName}")
    },

    #' @field repoFolder Parent directory for the repository. Can be read or set with validation.
    repoFolder = function(value) {
      if (missing(value)) return(private$.repoFolder)
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".repoFolder"]] <- value
      cli::cli_alert_info("Updated {.field repoFolder}")
    },

    #' @field dbConnectionBlocks List of DbConfigBlock objects managing multiple database connections. Can be read or set with class validation.
    dbConnectionBlocks = function(value) {
      if (missing(value)) return(private$.dbConnectionBlocks)
      checkmate::assert_list(x = value, types = "DbConfigBlock", null.ok = TRUE)
      private[[".dbConnectionBlocks"]] <- value
      cli::cli_alert_info("Updated {.field dbConnectionBlocks}")
    },



    #' @field studyMeta StudyMeta object containing study metadata and configuration. Can be read or set with class validation.
    studyMeta = function(value) {
      if(missing(value)) return(private$.studyMeta)
      checkmate::assert_class(x = value, classes = "StudyMeta")
      private[[".studyMeta"]] <- value
      cli::cli_alert_info("Updated {.field studyMeta}")
    },

    #' @field gitRemote Optional URL for git remote repository. Can be read or set with validation.
    gitRemote = function(value) {
      if (missing(value)) return(private$.gitRemote)
      checkmate::assert_string(x = value, null.ok = TRUE)
      private[[".gitRemote"]] <- value
      cli::cli_alert_info("Updated {.field gitRemote}")
    },

    #' @field renvLockFile Optional path to renv lock file for reproducibility. Can be read or set with validation.
    renvLockFile = function(value) {
      if (missing(value)) return(private$.renvLockFile)
      checkmate::assert_string(x = value, null.ok = TRUE)
      private[[".renvLockFile"]] <- value
      cli::cli_alert_info("Updated {.field renvLockFile}")
    }
  )
)

# Sub options classes ------------

#' ContributorLine R6 Class
#'
#' @description
#' Represents a contributor to a study with associated contact and role information.
#' This class stores metadata about individuals contributing to a research study.
#'
#' @details
#' ContributorLine encapsulates contributor information including name, email, and role.
#' Used within StudyMeta to maintain a structured list of study contributors.
#'
#' ## Active Fields
#'
#' - `name`: Contributor's name (read/write)
#' - `email`: Contributor's email address (read/write)
#' - `role`: Contributor's role in the study (read/write)
#'
#' ## Methods
#'
#' - `initialize()`: Create and configure a new ContributorLine instance
#' - `printContributorLine()`: Generate formatted contributor information string
#'
#' @export
ContributorLine <- R6::R6Class(
  classname = "ContributorLine",
  public = list(
    #' @description
    #' Initialize a new ContributorLine instance.
    #'
    #' @param name Character string. Contributor's full name.
    #' @param email Character string. Contributor's email address.
    #' @param role Character string. Contributor's role in the study.
    #'
    #' @return Invisibly returns self.
    initialize = function(name, email, role) {
      checkmate::assert_string(x = name, min.chars = 1)
      checkmate::assert_string(x = email, min.chars = 1)
      checkmate::assert_string(x = role, min.chars = 1)
      private[[".name"]] <- name
      private[[".email"]] <- email
      private[[".role"]] <- role
    },
    #' @description
    #' Generate a formatted string representation of the contributor.
    #'
    #' @return Character string with formatted contributor information.
    printContributorLine = function() {
      txt <- glue::glue("Name: {private$.name} | Email: {private$.email} | Role: {private$.role}")
      return(txt)
    }
  ),
  private = list(
    .name = NA_character_,
    .email = NA_character_,
    .role = NA_character_
  ),
  active = list(
    #' @field name Contributor's full name. Can be read or set with validation.
    name = function(value) {
      if (missing(value)) return(private$.name)
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".name"]] <- value
      cli::cli_alert_info("Updated contributor {.field name}")
    },

    #' @field email Contributor's email address. Can be read or set with validation.
    email = function(value) {
      if (missing(value)) return(private$.email)
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".email"]] <- value
      cli::cli_alert_info("Updated contributor {.field email}")
    },

    #' @field role Contributor's role in the study. Can be read or set with validation.
    role = function(value) {
      if (missing(value)) return(private$.role)
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".role"]] <- value
      cli::cli_alert_info("Updated contributor {.field role}")
    }
  )
)

#' StudyMeta R6 Class
#'
#' @description
#' Comprehensive metadata container for a research study.
#' Manages study information including title, therapeutic area, type, contributors, links, and tags.
#'
#' @details
#' StudyMeta serves as the primary data container for study-level metadata. It coordinates
#' with the ContributorLine class to maintain contributor information and provides
#' methods for generating formatted output of study components.
#'
#' ## Active Fields
#'
#' - `studyTitle`: Title of the study (read/write)
#' - `therapeuticArea`: Therapeutic area of the study (read/write)
#' - `studyType`: Type of study conducted (read/write)
#' - `studyLinks`: Character vector of relevant study links (read/write)
#' - `studyTags`: Character vector of tags describing the study (read/write)
#' - `contributors`: List of ContributorLine objects (read/write)
#'
#' ## Methods
#'
#' - `initialize()`: Create and configure a new StudyMeta instance
#' - `listContributors()`: Generate formatted markdown list of contributors
#' - `listStudyTags()`: Generate formatted markdown list of study tags
#' - `listStudyLinks()`: Generate formatted markdown section of study resources
#'
#' @export
StudyMeta <- R6::R6Class(
  classname = "StudyMeta",
  public = list(
    #' @description
    #' Initialize a new StudyMeta instance with study metadata.
    #'
    #' @param studyTitle Character string. Title of the study.
    #' @param therapeuticArea Character string. Therapeutic area focus of the study.
    #' @param studyType Character string. Type of study (e.g., observational, interventional).
    #' @param contributors List of ContributorLine objects. Study team members.
    #' @param studyLinks Character vector. Optional URLs and references for the study.
    #' @param studyTags Character vector. Optional tags describing the study topics/characteristics.
    #'
    #' @return Invisibly returns self.
    initialize = function(studyTitle,
                          therapeuticArea,
                          studyType,
                          contributors,
                          studyLinks = NULL,
                          studyTags = NULL) {
      checkmate::assert_string(x = studyTitle, min.chars = 1)
      checkmate::assert_string(x = therapeuticArea, min.chars = 1)
      checkmate::assert_string(x = studyType, min.chars = 1)
      private[[".studyTitle"]] <- studyTitle
      private[[".therapeuticArea"]] <- therapeuticArea
      private[[".studyType"]] <- studyType

      checkmate::assert_character(x = studyLinks, null.ok = TRUE)
      if (!is.null(studyLinks)) {
        private[[".studyLinks"]] <- studyLinks
      }


      checkmate::assert_character(x = studyTags, null.ok = TRUE)
      if (!is.null(studyTags)) {
        private[[".studyTags"]] <- studyTags
      }

      checkmate::assert_list(x = contributors, min.len = 1, types = "ContributorLine")
      private[[".contributors"]] <- contributors

    },

    #' @description
    #' Generate a formatted markdown list of all contributors.
    #'
    #' @return Character string with markdown-formatted contributor list.
    listContributors = function() {
      ctbs <- private$.contributors
      ctbsList <- purrr::map(
        private$.contributors,
        ~glue::glue("- {.x$role}: {.x$name} (email: {.x$email})")
      ) |>
        glue::glue_collapse(sep = "\n")
      ctbs2 <- c("## Contributors", ctbsList) |> glue::glue_collapse(sep = "\n\n")

      return(ctbs2)
    },

    #' @description
    #' Generate a formatted markdown list of study tags.
    #'
    #' @return Character string with markdown-formatted tag list.
    listStudyTags = function() {
      tags <- private$.studyTags
      if (length(tags) > 0) {
        tagList <- purrr::map(
          private$.studyTags,
          ~glue::glue("\t* {.x}")
        ) |>
          glue::glue_collapse(sep = "\n")
        tagList <- c("- Tags", tagList) |> glue::glue_collapse(sep = "\n")
      } else {
        tagList <- "- Tags (Please Add)"
      }

      return(tagList)
    },

    #' @description
    #' Generate a formatted markdown section of study resources and links.
    #'
    #' @return Character string with markdown-formatted section of study resources.
    listStudyLinks = function() {
      links <- private$.studyLinks
      if (length(links) > 0) {
        linksList <- purrr::map(
          private$.studyLinks,
          ~glue::glue("\t* {.x}")
        ) |>
          glue::glue_collapse(sep = "\n")
        linksList <- c("## Resources", links) |> glue::glue_collapse(sep = "\n\n")
      } else {
        linksList <- c("## Resources", "<!-- Place study Links as needed -->") |> glue::glue_collapse(sep = "\n\n")
      }

      return(linksList)
    }

  ),
  private = list(
    .studyTitle = NULL,
    .therapeuticArea = NULL,
    .studyType = NULL,
    .contributors = NULL,
    .studyLinks = NULL,
    .studyTags = NULL
  ),
  active = list(
    #' @field studyTitle Title of the study. Can be read or set with validation.
    studyTitle = function(value) {
      if (missing(value)) return(private$.studyTitle)
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".studyTitle"]] <- value
      cli::cli_alert_info("Updated {.field studyTitle}")
    },

    #' @field therapeuticArea Therapeutic area focus of the study. Can be read or set with validation.
    therapeuticArea = function(value) {
      if (missing(value)) return(private$.therapeuticArea)
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".therapeuticArea"]] <- value
      cli::cli_alert_info("Updated {.field therapeuticArea}")
    },

    #' @field studyType Type of study conducted. Can be read or set with validation.
    studyType = function(value) {
      if (missing(value)) return(private$.studyType)
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".studyType"]] <- value
      cli::cli_alert_info("Updated {.field studyType}")
    },

    #' @field studyTags Character vector of tags describing study topics and characteristics. Can be read or set with validation.
    studyTags = function(value) {
      if (missing(value)) return(private$.studyTags)
      checkmate::assert_character(x = value)
      private[[".studyTags"]] <- value
      cli::cli_alert_info("Updated {.field studyTags}")
    },

    #' @field studyLinks Character vector of relevant study resource links and URLs. Can be read or set with validation.
    studyLinks = function(value) {
      if (missing(value)) return(private$.studyLinks)
      checkmate::assert_character(x = value)
      private[[".studyLinks"]] <- value
      cli::cli_alert_info("Updated {.field studyLinks}")
    },

    #' @field contributors List of ContributorLine objects representing study team members. Can be read or set with class validation.
    contributors = function(value) {
      if (missing(value)) return(private$.contributors)
      checkmate::assert_list(x = value, min.len = 1, types = "ContributorLine")
      private[[".contributors"]] <- value
      cli::cli_alert_info("Updated {.field contributors}")
    }
  )
)

#' DbConfigBlock R6 Class
#'
#' @description
#' Represents a database configuration block for connecting to a specific database.
#' Encapsulates database connection parameters and naming conventions used during study execution.
#'
#' @details
#' DbConfigBlock manages configuration for a single database connection within the Ulysses framework.
#' This includes CDM schema specifications, cohort table references, and database labeling.
#' Used to manage multiple database connections within a study.
#'
#' ## Active Fields
#'
#' - `configBlockName`: Unique identifier for this config block (read/write)
#' - `cdmDatabaseSchema`: Schema name containing the CDM (read/write)
#' - `cohortTable`: Table name for study cohorts (read/write)
#' - `databaseName`: Database identifier (read/write, defaults to configBlockName)
#' - `databaseLabel`: Human-readable database label (read/write)
#'
#' ## Methods
#'
#' - `initialize()`: Create and configure a new DbConfigBlock instance
#' - `writeBlockSection()`: Generate formatted configuration block text
#'
#' @export
DbConfigBlock <- R6::R6Class(
  classname = "DbConfigBlock",
  public = list(
    #' @description
    #' Initialize a new DbConfigBlock instance with database configuration.
    #'
    #' @param configBlockName Character string. Unique identifier for this configuration block.
    #' @param cdmDatabaseSchema Character string. Schema containing CDM data.
    #' @param cohortTable Character string. Table name for study cohorts.
    #' @param databaseName Character string. Optional database identifier (defaults to configBlockName).
    #' @param databaseLabel Character string. Optional human-readable database label (defaults to databaseName).
    #' @param dbServer Character string. Optional database server name for secrets.yml lookup (defaults to configBlockName).
    #' @param workDatabaseSchema Character string. Optional working schema for temp tables (per-block).
    #' @param tempEmulationSchema Character string. Optional temp table emulation schema (per-block).
    #'
    #' @return Invisibly returns self.
    initialize = function(configBlockName,
                          cdmDatabaseSchema,
                          cohortTable,
                          databaseName = NULL,
                          databaseLabel = NULL,
                          dbServer = NULL,
                          workDatabaseSchema = NULL,
                          tempEmulationSchema = NULL) {

      checkmate::assert_string(x = configBlockName, min.chars = 1)
      checkmate::assert_string(x = cdmDatabaseSchema, min.chars = 1)
      checkmate::assert_string(x = cohortTable, min.chars = 1)
      private[[".configBlockName"]] <- configBlockName
      private[[".cdmDatabaseSchema"]] <- cdmDatabaseSchema
      private[[".cohortTable"]] <- cohortTable

      checkmate::assert_string(x = databaseName, min.chars = 1, null.ok = TRUE)
      if (is.null(databaseName)) {
        private[[".databaseName"]] <- configBlockName
      } else {
        private[[".databaseName"]] <- databaseName
      }


      checkmate::assert_string(x = databaseLabel, min.chars = 1, null.ok = TRUE)
      if (is.null(databaseName) & is.null(databaseLabel)) {
        private[[".databaseLabel"]] <- configBlockName
      } else if (!is.null(databaseName) & is.null(databaseLabel)) {
        private[[".databaseLabel"]] <- databaseName
      } else {
        private[[".databaseLabel"]] <- databaseLabel
      }

      # dbServer defaults to configBlockName for single-DB-per-block simplicity
      if (is.null(dbServer)) {
        private[[".dbServer"]] <- configBlockName
      } else {
        checkmate::assert_string(x = dbServer, min.chars = 1)
        private[[".dbServer"]] <- dbServer
      }

      # Work and temp schemas are per-block (not study-level)
      checkmate::assert_string(x = workDatabaseSchema, min.chars = 1)
      private[[".workDatabaseSchema"]] <- workDatabaseSchema

      checkmate::assert_string(x = tempEmulationSchema, null.ok = TRUE)
      if (!is.null(tempEmulationSchema)) {
        private[[".tempEmulationSchema"]] <- tempEmulationSchema
      }
    },

    #' @description
    #' Generate a formatted configuration block section for the config file.
    #'
    #' @return Character string with formatted configuration block.
    #' @details Extracts all fields from the block's own private data,
    #'   including workDatabaseSchema and tempEmulationSchema which are
    #'   set per-block (not at the study level).
    writeBlockSection = function() {

      configBlockName <- private$.configBlockName
      dbServer <- private$.dbServer
      databaseName <- private$.databaseName
      databaseLabel <- private$.databaseLabel
      cdmSchema <- private$.cdmDatabaseSchema
      cohortTable <- private$.cohortTable
      workSchema <- private$.workDatabaseSchema
      tempSchema <- private$.tempEmulationSchema %||% ""

      configBlock <- fs::path_package(package = "picard", "templates/configBlock.txt") |>
        readr::read_file() |>
        glue::glue()

      return(configBlock)
    }
  ),
  private = list(
    .configBlockName = NULL,
    .cdmDatabaseSchema = NULL,
    .cohortTable = NULL,
    .databaseName = NULL,
    .databaseLabel = NULL,
    .dbServer = NULL,
    .workDatabaseSchema = NULL,
    .tempEmulationSchema = NULL
  ),
  active = list(
    #' @field configBlockName Unique identifier for this configuration block. Can be read or set with validation.
    configBlockName = function(value) {
      if (missing(value)) return(private$.configBlockName)
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".configBlockName"]] <- value
      cli::cli_alert_info("Updated {.field configBlockName}")
    },

    #' @field cdmDatabaseSchema Schema name containing the CDM data. Can be read or set with validation.
    cdmDatabaseSchema = function(value) {
      if (missing(value)) return(private$.cdmDatabaseSchema)
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".cdmDatabaseSchema"]] <- value
      cli::cli_alert_info("Updated {.field cdmDatabaseSchema}")
    },

    #' @field cohortTable Table name for study cohorts. Can be read or set with validation.
    cohortTable = function(value) {
      if (missing(value)) return(private$.cohortTable)
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".cohortTable"]] <- value
      cli::cli_alert_info("Updated {.field cohortTable}")
    },

    #' @field databaseName Database identifier. Can be read or set with validation. Defaults to configBlockName.
    databaseName = function(value) {
      if (missing(value)) return(private$.databaseName)
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".databaseName"]] <- value
      cli::cli_alert_info("Updated {.field databaseName}")
    },

    #' @field databaseLabel Human-readable database label for display. Can be read or set with validation.
    databaseLabel = function(value) {
      if (missing(value)) return(private$.databaseLabel)
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".databaseLabel"]] <- value
      cli::cli_alert_info("Updated {.field databaseLabel}")
    },

    #' @field dbServer Database server name for secrets.yml lookup. Can be read or set with validation. Defaults to configBlockName.
    dbServer = function(value) {
      if (missing(value)) return(private$.dbServer)
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".dbServer"]] <- value
      cli::cli_alert_info("Updated {.field dbServer}")
    },

    #' @field workDatabaseSchema Working schema for writing temporary tables. Per-block setting (not study-level).
    workDatabaseSchema = function(value) {
      if (missing(value)) return(private$.workDatabaseSchema)
      checkmate::assert_string(x = value, null.ok = TRUE)
      private[[".workDatabaseSchema"]] <- value
      cli::cli_alert_info("Updated {.field workDatabaseSchema}")
    },

    #' @field tempEmulationSchema Schema for emulating temporary tables (Oracle/Snowflake). Per-block setting.
    tempEmulationSchema = function(value) {
      if (missing(value)) return(private$.tempEmulationSchema)
      checkmate::assert_string(x = value, null.ok = TRUE)
      private[[".tempEmulationSchema"]] <- value
      cli::cli_alert_info("Updated {.field tempEmulationSchema}")
    }
  )
)

#' ExecOptions R6 Class
#'
#' @description
#' **Deprecated.** ExecOptions has been removed. Use `UlyssesStudy` directly with
#' `dbConnectionBlocks`, `workDatabaseSchema`, and `tempEmulationSchema` parameters.
#'
#' @export
ExecOptions <- NULL


listDefaultFolders <- function(repoPath) {
  analysisFolders <- c("src", "tasks")
  execFolders <- c('logs', 'results')
  inputFolders <- c("cohorts/json", "cohorts/sql", "cohorts/derived", "conceptSets/json")
  disseminationFolders <- c("quarto", "export/merge", "export/pretty", "export/studyHubOutput", "documents")

  folders <- c(
    paste('inputs', inputFolders, sep = "/"),
    paste('analysis', analysisFolders, sep = "/"),
    paste('exec', execFolders, sep = "/"),
    paste('dissemination', disseminationFolders, sep = "/"),
    'extras'
  )
  
  # Create directories and .gitkeep files to ensure empty folders are tracked by git
  for (folder in folders) {
    dir_path <- fs::path(repoPath, folder)
    fs::dir_create(dir_path, recurse = TRUE)
    fs::file_create(fs::path(dir_path, ".gitkeep"))
  }
  
  return(folders)
}


initReadMeFn <- function(sm, repoName, repoPath) {
  # prep title
  title <- glue::glue("# {sm$studyTitle} (Id: {repoName})")
  # prep start badge
  badge <- glue::glue(
    "<!-- badge: start -->

      ![Study Status: Started](https://img.shields.io/badge/Study%20Status-Started-blue.svg)
      ![Version: 0.0.1](https://img.shields.io/badge/Version-0.0.1-yellow.svg)

    <!-- badge: end -->"
  )

  # create tag list
  tagList <- sm$listStudyTags()

  # prep study info
  info <-c(
    "## Study Information",
    glue::glue("- Study Id: {repoName}"),
    glue::glue("- Study Title: {sm$studyTitle}"),
    glue::glue("- Study Start Date: {lubridate::today()}"),
    glue::glue("- Expected Study End Date: {lubridate::today() + (365 * 2)}"),
    glue::glue("- Study Type: {sm$studyType}"),
    glue::glue("- Therapeutic Area: {sm$therapeuticArea}"),
    tagList
  ) |>
    glue::glue_collapse(sep = "\n")

  # prep placeholder for desc
  desc <- c(
    "## Study Description",
    "Add a short description about the study!"
  ) |>
    glue::glue_collapse(sep = "\n\n")

  # prep contributors
  contributors <- sm$listContributors()

  # prep links
  links <- sm$listStudyLinks()

  # combine and save to README file
  readmeLines <- c(
    title,
    badge,
    info,
    desc,
    contributors,
    links
  ) |>
    glue::glue_collapse(sep = "\n\n")

  readr::write_lines(
    x = readmeLines,
    file = fs::path(repoPath, "README.md")
  )

  actionItem(glue::glue_col("Initialize Readme: {green {fs::path(repoPath, 'README.md')}}"))
  invisible(readmeLines)
}


initNewsFn <- function(repoName, repoPath) {

  header <- glue::glue("# {repoName} 0.0.1")
  items <- c(
    glue::glue("- Run Date: {lubridate::today()}"),
    "- Initialize Ulysses Repo"
  ) |>
    glue::glue_collapse(sep = "\n")

  newsLines <- c(header, items) |>
    glue::glue_collapse(sep = "\n")

  readr::write_lines(
    x = newsLines,
    file = fs::path(repoPath, "NEWS.md")
  )

  actionItem(glue::glue_col("Initialize NEWS: {green {fs::path(repoPath, 'NEWS.md')}}"))
  invisible(newsLines)
}

updateNews <- function(versionNumber, projectPath = here::here(), openFile = TRUE) {

  repoName <- basename(projectPath)
  newsFile <- readr::read_file(file = fs::path(projectPath, "NEWS.md"))
  newsHeader <- glue::glue("# {repoName} {versionNumber}\n\t-Run Date: {lubridate::today()}")
  updateNewsFile <- c(newsHeader, newsFile) |> glue::glue_collapse(sep = "\n\n")
  readr::write_file(updateNewsFile, file = fs::path(projectPath, "NEWS.md"))
  actionItem(glue::glue_col("Update NEWS: {green {fs::path(projectPath, 'NEWS.md')}}"))
  cli::cat_bullet(
    "Please add a bulleted description of changes to the new version!!!",
    bullet = "warning",
    bullet_col = "yellow"
  )
  if (openFile) {
    rstudioapi::navigateToFile(file = fs::path(projectPath, "NEWS.md"))
    actionItem("Opening NEWS.md for edits")
  }
  invisible(updateNewsFile)
}


notification <- function(txt) {
  cli::cat_bullet(
    txt,
    bullet = "info",
    bullet_col = "blue"
  )
  invisible(txt)
}

actionItem <- function(txt) {
  cli::cat_bullet(
    txt,
    bullet = "pointer",
    bullet_col = "yellow"
  )
  invisible(txt)
}


writeFileAndNotify <- function(x, repoPath, fileName) {

  filePath <- fs::path(repoPath, fileName)

  readr::write_lines(
    x = x,
    file = filePath
  )

  actionItem(glue::glue_col("Write {green {fileName}} to: {cyan {filePath}}"))
  invisible(filePath)
}

#' Validate Ulysses Repository Structure
#'
#' @description Checks that a directory is a valid Ulysses-style repository
#' with all required files and folders.
#'
#' @param path Character. Path to the repository to validate. If NULL (default),
#'   uses the current working directory.
#'
#' @return List with validation results containing:
#'   - is_valid: Logical. TRUE if all requirements met
#'   - path: Character. Path that was validated
#'   - required_files: Data frame with required files and their status
#'   - required_dirs: Data frame with required directories and their status
#'   - summary: Character. Summary message
#'
#' @details
#' A valid Ulysses repository must contain:
#' - README.md file
#' - NEWS.md file
#' - config.yml file
#' - *.Rproj file (R project file)
#' - analysis/ directory
#'
#' @export
#' @examples
#' \dontrun{
#'   validateUlyssesStructure()  # Check current directory
#'   validateUlyssesStructure("/path/to/repo")  # Check specific directory
#' }
validateUlyssesStructure <- function(path = NULL) {
  # Use current working directory if path not provided
  if (is.null(path)) {
    path <- here::here()
  }
  
  checkmate::assert_string(x = path, min.chars = 1)
  path <- fs::path_expand(path)
  
  # Check if path exists
  if (!fs::dir_exists(path)) {
    cli::cli_alert_danger("Path does not exist: {path}")
    return(list(
      is_valid = FALSE,
      path = path,
      summary = glue::glue("Path does not exist: {path}")
    ))
  }
  
  # Required files
  required_files <- list(
    README = fs::path(path, "README.md"),
    NEWS = fs::path(path, "NEWS.md"),
    CONFIG = fs::path(path, "config.yml")
  )
  
  # Check for .Rproj file (any .Rproj file in the directory)
  rproj_files <- fs::dir_ls(path, glob = "*.Rproj", recurse = FALSE)
  required_files$RPROJ <- if (length(rproj_files) > 0) rproj_files[1] else NA_character_
  
  # Check which files exist
  files_status <- data.frame(
    file = names(required_files),
    path = unlist(required_files),
    exists = sapply(unlist(required_files), function(p) {
      if (is.na(p)) FALSE else fs::file_exists(p)
    }),
    row.names = NULL,
    stringsAsFactors = FALSE
  )
  
  # Required directories
  required_dirs_list <- list(
    analysis = fs::path(path, "analysis")
  )
  
  dirs_status <- data.frame(
    directory = names(required_dirs_list),
    path = unlist(required_dirs_list),
    exists = sapply(unlist(required_dirs_list), fs::dir_exists),
    row.names = NULL,
    stringsAsFactors = FALSE
  )
  
  # Determine overall validity
  files_valid <- all(files_status$exists)
  dirs_valid <- all(dirs_status$exists)
  is_valid <- files_valid && dirs_valid
  
  # Build summary message
  if (is_valid) {
    summary <- glue::glue("Valid Ulysses repository at {path}")
    cli::cli_alert_success(summary)
  } else {
    missing_files <- files_status$file[!files_status$exists]
    missing_dirs <- dirs_status$directory[!dirs_status$exists]
    
    missing_items <- c(
      if (length(missing_files) > 0) glue::glue("Missing files: {paste(missing_files, collapse = ', ')}"),
      if (length(missing_dirs) > 0) glue::glue("Missing directories: {paste(missing_dirs, collapse = ', ')}")
    )
    summary <- glue::glue("Invalid Ulysses repository at {path}. {paste(missing_items, collapse = '. ')}")
    cli::cli_alert_danger(summary)
  }
  
  # Return results
  list(
    is_valid = is_valid,
    path = path,
    required_files = files_status,
    required_dirs = dirs_status,
    summary = summary
  )
}
