#' CohortDef R6 Class
#'
#' An R6 class that stores key information about cohorts managed by the CohortManifest.
#' Each CohortDef is a pointer to a file on disk (JSON or SQL) with associated metadata.
#'
#' @details
#' The CohortDef class manages cohort metadata and SQL generation.
#' Upon initialization, it loads and validates cohort definitions from either
#' JSON (CIRCE format) or SQL files, and creates a hash to uniquely identify
#' the generated SQL.
#'
#' @export
CohortDef <- R6::R6Class(
  classname = "CohortDef",
  private = list(
    .label = NULL,
    .category = NULL,
    .tags = NULL,
    .filePath = NULL,
    .fileHash = NULL,
    .sql = NULL,
    .sqlHash = NULL,
    .id = NULL,
    .sourceType = NULL,
    .cohortType = "circe",

    # Load SQL from file
    load_sql_from_file = function(filePath) {
      if (!file.exists(filePath)) {
        stop("File does not exist: ", filePath)
      }

      file_ext <- tolower(tools::file_ext(filePath))

      if (file_ext == "sql") {
        # Load SQL file directly
        private$.sql <- readr::read_file(filePath)
      } else if (file_ext == "json") {
        # Load and validate JSON as CIRCE cohort
        json_content <- readr::read_file(filePath)
        # Validate JSON is valid CIRCE using CirceR
        tryCatch(
          CirceR::cohortExpressionFromJson(json_content),
          error = function(e) {
            stop("JSON file is not valid CIRCE format: ", filePath, "\nError: ", e$message)
          }
        )

        # Render JSON to SQL
        private$.sql <- CirceR::buildCohortQuery(json_content, options = CirceR::createGenerateOptions(generateStats = TRUE))
      } else {
        stop("File must be either .sql or .json, got: .", file_ext)
      }

      # Compute file hash from raw file content (as-is on disk)
      file_content <- readr::read_file(filePath)
      private$.fileHash <- rlang::hash(file_content)
      # Create hash of SQL string
      private$.sqlHash <- rlang::hash(private$.sql)
    }
  ),

  public = list(
    #' @description Initialize a new CohortDef
    #'
    #' @param label Character. The common name of the cohort.
    #' @param category Character. Required classification (e.g., 'target', 'exposure', 'outcome').
    #' @param sourceType Character. Provenance: 'atlas', 'capr', 'circe', 'sql', or 'derived'.
    #' @param tags List. A named list of tags that give metadata about the cohort.
    #' @param filePath Character. Path to the cohort file in inputs/cohorts folder (can be .json or .sql).
    initialize = function(label, category, sourceType, tags = list(), filePath) {
      checkmate::assert_string(x = label, min.chars = 1)
      checkmate::assert_string(x = category, min.chars = 1)
      checkmate::assert_choice(x = sourceType, choices = c("atlas", "capr", "circe", "sql", "derived"))
      checkmate::assert_list(x = tags, names = "named")
      checkmate::assert_file_exists(x = filePath)

      private$.label <- label
      private$.category <- category
      private$.sourceType <- sourceType
      private$.tags <- tags
      private$.filePath <- filePath

      # Load SQL and generate hash
      private$load_sql_from_file(filePath)

      # Cohort ID will be assigned later when listed within the CohortManifest
      private$.id <- NA_integer_
    },

    #' Get the file path
    #'
    #' @return Character. Relative path to the cohort file.
    getFilePath = function() {
      fs::path_rel(private$.filePath)
    },

    #' Get the generated SQL
    #'
    #' @return Character. The SQL definition of the cohort.
    getSql = function() {
      private$.sql
    },

    #' Get the file hash
    #'
    #' @return Character. MD5 hash of the raw file content on disk.
    getFileHash = function() {
      private$.fileHash
    },

    #' Get the SQL hash
    #'
    #' @return Character. MD5 hash of the normalized SQL definition (line endings standardized).
    getSqlHash = function() {
      private$.sqlHash
    },

    #' Get the cohort ID
    #'
    #' @return Integer. The cohort ID, or NA_integer_ if not set.
    getId = function() {
      private$.id
    },

    #' Set the cohort ID (internal use)
    #'
    #' @param id Integer. The cohort ID to set.
    setId = function(id) {
      checkmate::assert_int(x = id)
      private$.id <- id
    },

    #' Format tags as string
    #'
    #' @return Character. Tags formatted as "name: value | name: value".
    formatTagsAsString = function() {
      if (length(private$.tags) == 0) {
        return("")
      }
      tags_str <- mapply(
        function(name, value) {
          paste0(name, ": ", value)
        },
        names(private$.tags),
        private$.tags,
        SIMPLIFY = TRUE
      )
      paste(tags_str, collapse = " | ")
    },

    #' Get the cohort type
    #'
    #' @return Character. One of 'circe', 'custom', 'subset', 'union', 'complement', 'composite'.
    getCohortType = function() {
      private$.cohortType
    },

    #' Set the cohort type (internal use)
    #'
    #' @param cohortType Character. One of 'circe', 'custom', 'subset', 'union', 'complement', 'composite'.
    setCohortType = function(cohortType) {
      checkmate::assert_choice(x = cohortType, choices = c("circe", "custom", "subset", "union", "complement", "composite"))
      private$.cohortType <- cohortType
    },

    #' Get the source type
    #'
    #' @return Character. One of 'atlas', 'capr', 'sql', 'derived'.
    getSourceType = function() {
      private$.sourceType
    },

    #' Get the category
    #'
    #' @return Character. The cohort category (e.g., 'target', 'exposure', 'outcome').
    getCategory = function() {
      private$.category
    },

    #' Set the category
    #'
    #' @param category Character. The cohort category.
    setCategory = function(category) {
      checkmate::assert_string(x = category, min.chars = 1)
      private$.category <- category
    }
  ),

  active = list(

    #' @field label character to set the label to. If missing, returns the current label.
    label = function(label) {
      if (missing(label)) {
        private[[".label"]]
      } else {
        checkmate::assert_string(x = label, min.chars = 1)
        private[[".label"]] <- label
      }
    },

    #' @field tags list of the values to set the tags to. If missing, returns the current tags.
    tags = function(tags) {
      if (missing(tags)) {
        private[[".tags"]]
      } else {
        checkmate::assert_list(x = tags, names = "named")
        private[[".tags"]] <- tags
      }
    },

    #' @field category character to set the category to. If missing, returns the current category.
    category = function(category) {
      if (missing(category)) {
        private[[".category"]]
      } else {
        checkmate::assert_string(x = category, min.chars = 1)
        private[[".category"]] <- category
      }
    }
  )
)