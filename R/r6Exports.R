# ConceptSetManifestItem -----

#' R6 Class Representing a Concept Set Manifest Item
#'
#' @description
#' `r lifecycle::badge("experimental")`
#' `r .getManifestItemDescription(itemName = "ConceptSetManifestItem")`
#'
#' @details
#' `r .getManifestItemDetails(itemName = "ConceptSetManifestItem")`
#'
#' @export
ConceptSetManifestItem <- R6::R6Class(
  classname = "ConceptSetManifestItem",
  inherit = ManifestItem,

  ## public ----
  public = list(

    #' @description
    #' Create a new `ConceptSetManifest` object.
    #' @param provenanceId `r .getRoxygenParam(itemName = "provenanceId")`
    #' @param designMethod `r .getRoxygenParam(itemName = "designMethod")`
    #' @param name `r .getRoxygenParam(itemName = "name")`
    #' @param relativeJsonPath `r .getRoxygenParam(itemName = "relativeJsonPath")`
    initialize = function(provenanceId,
                          designMethod,
                          name,
                          relativeJsonPath) {
      # check json file path exists ----

      checkmate::assertFileExists(
        x = relativeJsonPath,
        access = "r",
        extension = c("json")
      )

      # check Design Method ----

      designMethodChoices <- getConceptSetDesignMethods()
      checkmate::assertChoice(
        x = designMethod,
        choices = designMethodChoices,
        null.ok = FALSE
      )

      super$initialize(manifestItemType = "ConceptSet")

      self$loadItem(
        provenanceId = provenanceId,
        designMethod = designMethod,
        name = name,
        relativeJsonPath = relativeJsonPath
      )
    }
  )
)

# CohortManifestItem -----

#' R6 Class Representing a Cohort Manifest Item
#'
#' @description
#' `r lifecycle::badge("experimental")`
#' `r .getManifestItemDescription(itemName = "CohortManifestItem")`
#'
#' @details
#' `r .getManifestItemDetails(itemName = "CohortManifestItem")`
#'
#' @export
CohortManifestItem <- R6::R6Class(
  classname = "CohortManifestItem",
  inherit = ManifestItem,

  ## public ----
  public = list(

    #' @description
    #' Create a new `CohortManifestItem` object.
    #' @param provenanceId `r .getRoxygenParam(itemName = "provenanceId")`
    #' @param designMethod `r .getRoxygenParam(itemName = "designMethod")`
    #' @param name `r .getRoxygenParam(itemName = "name")`
    #' @param relativeSqlPath `r .getRoxygenParam(itemName = "relativeSqlPath")`
    #' @param relativeJsonPath `r .getRoxygenParam(itemName = "relativeJsonPath")`
    #' @param relativeCaprPath `r .getRoxygenParam(itemName = "relativeCaprPath")`
    #' @param relativeRPath `r .getRoxygenParam(itemName = "relativeRPath")`
    initialize = function(
      provenanceId = -1,
      designMethod,
      name,
      relativeSqlPath = NA,
      relativeJsonPath = NA,
      relativeCaprPath = NA,
      relativeRPath = NA
    ) {
      # check path exists ----

      if (!is.na(relativeSqlPath)) {
        checkmate::checkFileExists(
          x = relativeSqlPath,
          access = "r",
          extension = c("sql")
        )
      } else if (!is.na(relativeJsonPath)) {
        checkmate::assertFileExists(
          x = relativeJsonPath,
          access = "r",
          extension = c("json")
        )
      } else if (!is.na(relativeCaprPath)) {
        checkmate::assertFileExists(
          x = relativeCaprPath,
          access = "r",
          extension = c("R")
        )
      } else if (!is.na(relativeRPath)) {
        checkmate::assertFileExists(
          x = relativeRPath,
          access = "r",
          extension = c("R")
        )
      }

      # check Design Method ----

      designMethodChoices <- getCohortDesignMethods()
      checkmate::assertChoice(
        x = designMethod,
        choices = designMethodChoices,
        null.ok = FALSE
      )

      super$initialize(manifestItemType = "Cohort")

      self$loadItem(
        provenanceId = !!provenanceId,
        designMethod = !!designMethod,
        name = name,
        relativeSqlPath = !!relativeSqlPath,
        relativeJsonPath = !!relativeJsonPath,
        relativeCaprPath = !!relativeCaprPath,
        relativeRPath = !!relativeRPath
      )
    }
  )
)

# TagManifestItem -----

#' R6 Class Representing a Tag Manifest Item
#'
#' @description
#' `r lifecycle::badge("experimental")`
#' `r .getManifestItemDescription(itemName = "TagManifestItem")`
#'
#' @details
#' `r .getManifestItemDetails(itemName = "TagManifestItem")`
#'
#' @export
TagManifestItem <- R6::R6Class(
  classname = "TagManifestItem",
  inherit = ManifestItem,

  ## public ----
  public = list(

    #' @description
    #' Create a new `TagManifestItem` object.
    #' @param name `r .getRoxygenParam(itemName = "name")`
    #' @param manifestItemId `r .getRoxygenParam(itemName = "manifestItemId")`
    #' @param manifestType `r .getRoxygenParam(itemName = "manifestType")`
    #' @param value `r .getRoxygenParam(itemName = "value")`
    initialize = function(name,
                          manifestItemId,
                          manifestType,
                          value) {
      super$initialize(manifestItemType = "Tag")

      self$loadItem(
        name = name,
        manifestItemId = manifestItemId,
        manifestType = manifestType,
        value = value
      )
    }
  )
)

# DependencyManifestItem -----

#' R6 Class Representing a Dependency Manifest Item
#'
#' @description
#' `r lifecycle::badge("experimental")`
#' `r .getManifestItemDescription(itemName = "DependencyManifestItem")`
#'
#' @details
#' `r .getManifestItemDetails(itemName = "DependencyManifestItem")`
#'
#' @export
DependencyManifestItem <- R6::R6Class(
  classname = "DependencyManifestItem",
  inherit = ManifestItem,

  ## public ----
  public = list(

    #' @description
    #' Create a new `DependencyManifestItem` object.
    #' @param name `r .getRoxygenParam(itemName = "name")`
    #' @param manifestItemId `r .getRoxygenParam(itemName = "manifestItemId")`
    #' @param manifestType `r .getRoxygenParam(itemName = "manifestType")`
    #' @param dependentItemId `r .getRoxygenParam(itemName = "dependentItemId")`
    #' @param tagItems `r .getRoxygenParam(itemName = "tagItems")`
    initialize = function(name,
                          manifestItemId,
                          manifestType,
                          dependentItemId,
                          tagItems = NULL) {
      super$initialize(manifestItemType = "Dependency")

      self$loadItem(
        name = name,
        manifestItemId = manifestItemId,
        manifestType = manifestType,
        dependentItemId = dependentItemId
      )

      for (tagItem in tagItems) {
        self$tagManifest$addTagManifestItem(definition = tagItem)
      }
    }
  )
)


# FileManifestItem -----

#' R6 Class Representing a Tag Manifest Item
#'
#' @description
#' `r lifecycle::badge("experimental")`
#' `r .getManifestItemDescription(itemName = "FileManifestItem")`
#'
#' @details
#' `r .getManifestItemDetails(itemName = "FileManifestItem")`
#'
#' @export
FileManifestItem <- R6::R6Class(
  classname = "FileManifestItem",
  inherit = ManifestItem,

  ## public ----
  public = list(

    #' @description
    #' Create a new `FileManifestItem` object.
    #' @param name `r .getRoxygenParam(itemName = "name")`
    #' @param manifestType `r .getRoxygenParam(itemName = "manifestType")`
    #' @param fileExtension `r .getRoxygenParam(itemName = "fileExtension")`
    #' @param relativePath `r .getRoxygenParam(itemName = "relativePath")`
    initialize = function(name,
                          manifestType,
                          fileExtension,
                          relativePath) {
      super$initialize(manifestItemType = "File")

      self$loadItem(
        name = name,
        manifestType = manifestType,
        fileExtension = fileExtension,
        relativePath = relativePath
      )
    }
  )
)

# AnalysisManifestItem -----

#' R6 Class Representing a Tag Manifest Item
#'
#' @description
#' `r lifecycle::badge("experimental")`
#' `r .getManifestItemDescription(itemName = "AnalysisManifestItem")`
#'
#' @details
#' `r .getManifestItemDetails(itemName = "AnalysisManifestItem")`
#'
#' @export
AnalysisManifestItem <- R6::R6Class(
  classname = "AnalysisManifestItem",
  inherit = ManifestItem,

  ## public ----
  public = list(

    #' @description
    #' Create a new `AnalysisManifestItem` object.
    #' @param name `r .getRoxygenParam(itemName = "name")`
    #' @param relativeRPath `r .getRoxygenParam(itemName = "relativeRPath")`
    #' @param stepOrdinal `r .getRoxygenParam(itemName = "stepOrdinal")`
    #' @param description `r .getRoxygenParam(itemName = "description")`
    initialize = function(
      name,
      relativeRPath,
      stepOrdinal,
      description
    ) {
      # check R file path exists ----

      checkmate::assertFileExists(x = relativeRPath, access = "r", extension = c("R"))

      self$loadItem(
        name = name,
        relativeRPath = relativeRPath,
        stepOrdinal = stepOrdinal,
        description = description
      )
    }
  )
)


# ManifestDatabase -----

#' R6 Class Representing a Manifest Database
#'
#' @description
#' `r lifecycle::badge("experimental")`
#' A Sqlite database to store manifests for the `Barista` package.
#'
#' @field db                      `r .getRoxygenParam(itemName = "db")`
#' @field dbPath                  `r .getRoxygenParam(itemName = "dbPath")`
#' @field conceptSetManifest      `r .getRoxygenParam(itemName = "conceptSetManifest")`
#' @field cohortManifest          `r .getRoxygenParam(itemName = "cohortManifest")`
#' @field analysisManifest        `r .getRoxygenParam(itemName = "analysisManifest")`
#' @field migrateManifest         `r .getRoxygenParam(itemName = "migrateManifest")`
#' @field fileManifest            `r .getRoxygenParam(itemName = "fileManifest")`
#' @field tagManifest             `r .getRoxygenParam(itemName = "tagManifest")`
#' @field dependencyManifest      `r .getRoxygenParam(itemName = "dependencyManifest")`
#'
#' @export
ManifestDatabase <- R6::R6Class(
  classname = "ManifestDatabase",

  ## public ----
  public = list(
    db = NULL,
    dbPath = NULL,

    #' @description
    #' Create a new `ManifestDatabase` object.
    #' @param dbPath `r .getRoxygenParam(itemName = "dbPath")`
    initialize = function(dbPath) {
      self$dbPath <- dbPath

      checkmate::assert(fs::path_ext(dbPath) == private$.dbExtension)
      self$db <- DBI::dbConnect(
        RSQLite::SQLite(),
        fs::path(self$dbPath)
      )

      # load or create manifests ----

      initialManifests <- c(
        ConceptSetManifest,
        CohortManifest,
        FileManifest,
        TagManifest,
        AnalysisManifest,
        DependencyManifest
      )

      for (manifest in initialManifests) {
        private$.initializeManifest(manifest = manifest)
      }

      # TODO: write lock file correctly ---

      # lockFilePath <- fs::path(here::here(),
      #                          self$fileManifest$getRelativePath(manifestType = "Renv", fileExtension = "lock"),
      #                          "renv", ext = "lock")
      #
      # print(lockFilePath)
      #
      # renv::snapshot(
      #   lockfile = lockFilePath,
      #   #type = "project",
      #   force = TRUE,
      #   prompt = FALSE,
      #   packages = c("Barista")
      # )
    },

    #' @description
    #' Reset a Manifest object
    #' @param manifestType `r .getRoxygenParam(itemName = "manifestType")`
    #' @param resetType `r .getRoxygenParam(itemName = "resetType")`
    resetManifest = function(manifestType,
                             resetType) {
      tableExists <- RSQLite::dbExistsTable(conn = self$db, name = manifestType)

      if (tableExists) {
        manifestString <- paste0(manifestType, "Manifest")
        if (resetType == "hard") {
          RSQLite::dbRemoveTable(conn = self$db, name = manifestType)

          private$.initializeManifest(
            manifest = eval(parse(text = manifestString))
          )
        } else {
          privateName <- snakecase::to_lower_camel_case(string = manifestString)
          thisManifest <- private[[glue::glue(".{privateName}")]]

          thisManifest$deprecateAllItems()
        }
      }

      dependencyTableExists <- RSQLite::dbExistsTable(conn = self$db, name = "Dependency")
      if (dependencyTableExists) {
        private$.dependencyManifest$deprecateAllByManifestType(manifestType = manifestType)
      }

    }
  ),

  ## active ----
  active = list(

    conceptSetManifest = function() {
      return(private$.conceptSetManifest)
    },
    cohortManifest = function() {
      return(private$.cohortManifest)
    },
    analysisManifest = function() {
      return(private$.analysisManifest)
    },
    migrateManifest = function() {
      return(private$.migrateManifest)
    },
    fileManifest = function() {
      return(private$.fileManifest)
    },
    tagManifest = function() {
      return(private$.tagManifest)
    },
    dependencyManifest = function() {
      return(private$.dependencyManifest)
    }
  ),

  ## private ----
  private = list(
    .dbExtension = "sqlite",
    .conceptSetManifest = NULL,
    .cohortManifest = NULL,
    .analysisManifest = NULL,
    .fileManifest = NULL,
    .tagManifest = NULL,
    .dependencyManifest = NULL,

    .initializeManifest = function(manifest) {
      thisManifestType <- stringr::str_remove(
        pattern = "Manifest",
        string = manifest$classname
      )
      thisManifest <- manifest$new(manifestDb = self)
      privateName <- snakecase::to_lower_camel_case(string = manifest$classname)
      private[[glue::glue(".{privateName}")]] <- thisManifest
    }
  )
)
