#' ConceptSetDef R6 Class
#'
#' An R6 class that stores key information about OHDSI CIRCE concept sets that need to be
#' managed in a study.
#'
#' @details
#' The ConceptSetDef class manages concept set metadata, JSON definitions, and domain information.
#' Upon initialization, it loads and validates concept set definitions from CIRCE JSON files,
#' creates a hash to uniquely identify the generated JSON, and stores domain and source concept information.
#'
#' @export
ConceptSetDef <- R6::R6Class(
  classname = "ConceptSetDef",
  private = list(
    .label = NULL,
    .tags = NULL,
    .filePath = NULL,
    .json = NULL,
    .hash = NULL,
    .id = NULL,

    # Load JSON from file
    load_json_from_file = function(filePath) {
      if (!file.exists(filePath)) {
        stop("File does not exist: ", filePath)
      }

      file_ext <- tolower(tools::file_ext(filePath))

      if (file_ext != "json") {
        stop("Concept set file must be .json, got: .", file_ext)
      }

      # Load and validate JSON as CIRCE concept set
      json_content <- readr::read_file(filePath)

      # Validate JSON is valid CIRCE using CirceR
      tryCatch(
        CirceR::conceptSetExpressionFromJson(json_content),
        error = function(e) {
          stop("JSON file is not valid CIRCE concept set format: ", filePath, "\nError: ", e$message)
        }
      )

      # Store JSON string
      private$.json <- json_content

      # Create hash of JSON string
      private$.hash <- rlang::hash(private$.json)
    }
  ),

  public = list(
    #' @description Initialize a new ConceptSetDef
    #'
    #' @param label Character. The common name of the concept set.
    #' @param tags List. A named list of tags that give metadata about the concept set.
    #' @param filePath Character. Path to the concept set JSON file in inputs/conceptSet folder.
    #' @param sourceCode Logical. Whether the concept set uses source concepts (TRUE) or standard concepts (FALSE).
    #' @param domain Character. The OMOP CDM clinical domain for this concept set. 
    #'   Valid values: "drug_exposure", "condition_occurrence", "measurement", "procedure", "observation", "device_exposure", "visit_occurrence", "init".
    initialize = function(label, tags = list(), filePath, domain = "init") {
      checkmate::assert_string(x = label, min.chars = 1)
      checkmate::assert_list(x = tags, names = "named")
      checkmate::assert_file_exists(x = filePath)

      # Validate domain
      valid_domains <- c("drug_exposure", "condition_occurrence", "measurement", "procedure", 
        "observation", "device_exposure", "visit_occurrence", "init")
      if (!(domain %in% valid_domains)) {
        stop("Invalid domain '", domain, "'. Valid domains: ", paste(valid_domains, collapse = ", "))
      }
      tags <- c(tags, list(domain = domain))
      private$.label <- label
      private$.tags <- tags
      private$.filePath <- filePath

      # Load JSON and generate hash
      private$load_json_from_file(filePath)

      # Concept set ID will be assigned later when listed within the ConceptSetManifest
      private$.id <- NA_integer_
    },

    #' Get the file path
    #'
    #' @return Character. Relative path to the concept set file.
    getFilePath = function() {
      fs::path_rel(private$.filePath)
    },

    #' Get the concept set JSON
    #'
    #' @return Character. The JSON definition of the concept set.
    getJson = function() {
      private$.json
    },

    #' Get the JSON hash
    #'
    #' @return Character. MD5 hash of the current JSON definition.
    getHash = function() {
      private$.hash
    },

    #' Get the concept set ID
    #'
    #' @return Integer. The concept set ID, or NA_integer_ if not set.
    getId = function() {
      private$.id
    },

    #' Set the concept set ID (internal use)
    #'
    #' @param id Integer. The concept set ID to set.
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
    }
  )
)
