
# create / load manifest db ----

#' Create Manifest Database
#'
#' @description
#' Creates a new Manifest Database object using either a new or existing Sqlite database file.
#'
#' @param dbPath `r .getRoxygenParam(itemName = "dbPath")`
#'
#' @export
createManifestDb <- function(dbPath) {

  manifestDb <- Barista::ManifestDatabase$new(
    dbPath = dbPath
  )
  return (manifestDb)
}

#' Reset Manifest Database
#'
#' @description
#' Resets a manifest database by dropping it and recreating a new one at the given path.
#'
#' @param dbPath `r .getRoxygenParam(itemName = "dbPath")`
#'
#' @export
resetManifestDb <- function(dbPath) {
  cli::cli_warn(glue::glue("This will reset the entire Barista Sqlite database."))

  checkmate::assertFileExists(x = dbPath)

  thisDb <- DBI::dbConnect(
    RSQLite::SQLite(),
    fs::path(dbPath)
  )

  DBI::dbDisconnect(conn = thisDb)

  fs::file_delete(path = dbPath)

  newDb <- createManifestDb(dbPath = dbPath)

  return (newDb)
}

# view manifests -----


#' View the File Manifest
#'
#' @description
#' View File Manifest from a given Manifest Database object, as a tibble.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#'
#' @export
viewFileManifest <- function(manifestDb) {
  manifestType <- "File"
  thisManifest <- .viewManifest(manifestDb = manifestDb,
                                manifestType = manifestType)
  return (thisManifest)
}

#' View the Concept Set Manifest
#'
#' @description
#' View Concept Set Manifest from a given Manifest Database object, as a tibble.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param includeDeprecated `r .getRoxygenParam(itemName = "includeDeprecated")`
#' @param tagNameValues `r .getRoxygenParam(itemName = "tagNameValues")`
#'
#' @export
viewConceptSetManifest <- function(manifestDb,
                                   includeDeprecated = FALSE,
                                   tagNameValues = list()) {
  manifestType <- "ConceptSet"
  manifest <- .viewManifest(manifestDb = manifestDb,
                            manifestType = manifestType,
                            includeDeprecated = includeDeprecated,
                            tagNameValues = tagNameValues)
  return (manifest)
}

#' View the Cohort Manifest
#'
#' @description
#' View Cohort Manifest from a given Manifest Database object, as a tibble.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param includeDeprecated `r .getRoxygenParam(itemName = "includeDeprecated")`
#' @param tagNameValues `r .getRoxygenParam(itemName = "tagNameValues")`
#'
#' @export
viewCohortManifest <- function(manifestDb,
                               includeDeprecated = FALSE,
                               tagNameValues = list()) {
  manifestType <- "Cohort"
  manifest <- .viewManifest(manifestDb = manifestDb,
                            manifestType = manifestType,
                            includeDeprecated = includeDeprecated,
                            tagNameValues = tagNameValues)
  return (manifest)
}

#' View Cohort Definition Set
#'
#' @description
#' View Cohort Definition Set from a given Manifest Database object, as a `CohortDefinitionSet` object.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#'
#' @export
viewCohortDefinitionSet <- function(manifestDb) {
  return (manifestDb$cohortManifest$asCohortDefinitionSet)
}

#' View Dependency Manifest
#'
#' @description
#' View Dependency Manifest from a given Manifest Database object, as a tibble.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param includeDeprecated `r .getRoxygenParam(itemName = "includeDeprecated")`
#' @param tagNameValues `r .getRoxygenParam(itemName = "tagNameValues")`
#'
#' @export
viewDependencyManifest <- function(manifestDb,
                                   includeDeprecated = FALSE,
                                   tagNameValues = list()) {
  manifestType <- "Dependency"
  manifest <- .viewManifest(manifestDb = manifestDb,
                            manifestType = manifestType,
                            includeDeprecated = includeDeprecated,
                            tagNameValues = tagNameValues)
  return (manifest)
}

#' View Analysis Manifest
#'
#' @description
#' View Analysis Manifest from a given Manifest Database object, as a tibble.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param includeDeprecated `r .getRoxygenParam(itemName = "includeDeprecated")`
#' @param tagNameValues `r .getRoxygenParam(itemName = "tagNameValues")`
#'
#' @export
viewAnalysisManifest <- function(manifestDb,
                                 includeDeprecated = FALSE,
                                 tagNameValues = list()) {
  manifestType <- "Analysis"
  manifest <- .viewManifest(manifestDb = manifestDb,
                            manifestType = manifestType,
                            includeDeprecated = includeDeprecated,
                            tagNameValues = tagNameValues)
  return (manifest)
}

#' View Migrate Manifest
#'
#' @description
#' View Migrate Manifest from a given Manifest Database object, as a tibble.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param includeDeprecated `r .getRoxygenParam(itemName = "includeDeprecated")`
#' @param tagNameValues `r .getRoxygenParam(itemName = "tagNameValues")`
#'
#' @export
viewMigrateManifest <- function(manifestDb,
                                includeDeprecated = FALSE,
                                tagNameValues = list()) {
  manifestType <- "Migrate"
  manifest <- .viewManifest(manifestDb = manifestDb,
                            manifestType = manifestType,
                            includeDeprecated = includeDeprecated,
                            tagNameValues = tagNameValues)
  return (manifest)
}

#' View Tag Manifest
#'
#' @description
#' View Tag Manifest from a given Manifest Database object, as a tibble.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param includeDeprecated `r .getRoxygenParam(itemName = "includeDeprecated")`
#'
#' @export
viewTagManifest <- function(manifestDb,
                            includeDeprecated = FALSE) {
  manifestType <- "Tag"
  manifest <- .viewManifest(manifestDb = manifestDb,
                            manifestType = manifestType,
                            includeDeprecated = includeDeprecated)
  return (manifest)
}

# Create manifest items ----

#' Create File Manifest Item
#'
#' @description
#' Create File Manifest Item to be used in the `FileManifest` within the Manifest Database.
#'
#' @param name `r .getRoxygenParam(itemName = "name")`
#' @param provenanceId `r .getRoxygenParam(itemName = "provenanceId")`
#' @param designMethod `r .getRoxygenParam(itemName = "designMethod")`
#' @param relativeJsonPath `r .getRoxygenParam(itemName = "relativeJsonPath")`
#'
#' @export
createConceptSetManifestItem <- function(name,
                                         provenanceId = -1,
                                         designMethod = "Atlas",
                                         relativeJsonPath) {
  item <- Barista::ConceptSetManifestItem$new(
    provenanceId = provenanceId,
    designMethod = designMethod,
    name = name,
    relativeJsonPath = relativeJsonPath
  )
  return (item)
}

#' Create Cohort Manifest Item
#'
#' @description
#' Create Cohort Manifest Item to be used in the `CohortManifest` within the Manifest Database.
#'
#' @param name `r .getRoxygenParam(itemName = "name")`
#' @param provenanceId `r .getRoxygenParam(itemName = "provenanceId")`
#' @param designMethod `r .getRoxygenParam(itemName = "designMethod")`
#' @param relativeSqlPath `r .getRoxygenParam(itemName = "relativeSqlPath")`
#' @param relativeJsonPath `r .getRoxygenParam(itemName = "relativeJsonPath")`
#' @param relativeRPath `r .getRoxygenParam(itemName = "relativeRPath")`
#'
#' @export
createCohortManifestItem <- function(name,
                                     provenanceId = -1,
                                     designMethod,
                                     relativeSqlPath = NA,
                                     relativeJsonPath = NA,
                                     relativeRPath = NA) {

  item <- Barista::CohortManifestItem$new(
    name = name,
    provenanceId = provenanceId,
    designMethod = designMethod,
    relativeSqlPath = relativeSqlPath,
    relativeJsonPath = relativeJsonPath,
    relativeRPath = relativeRPath
  )

  return (item)
}

#' Create File Manifest Item
#'
#' @description
#' Create File Manifest Item to be used in the `FileManifest` within the Manifest Database.
#' Note: this is not a typical pattern for most users.
#'
#' @param name `r .getRoxygenParam(itemName = "name")`
#' @param manifestType `r .getRoxygenParam(itemName = "manifestType")`
#' @param fileExtension `r .getRoxygenParam(itemName = "fileExtension")`
#' @param relativePath `r .getRoxygenParam(itemName = "relativePath")`
#'
#' @export
createFileManifestItem <- function(name,
                                   manifestType,
                                   fileExtension,
                                   relativePath) {

  item <- Barista::FileManifestItem$new(name = name,
                                        manifestType = manifestType,
                                        fileExtension = fileExtension,
                                        relativePath = relativePath)

  return (item)
}

#' Create Analysis Manifest Item
#'
#' @description
#' Create Analysis Manifest Item to be used in the `AnalysisManifest` within the Manifest Database.
#'
#' @param name `r .getRoxygenParam(itemName = "name")`
#' @param description `r .getRoxygenParam(itemName = "description")`
#' @param relativeRPath `r .getRoxygenParam(itemName = "relativeRPath")`
#' @param stepOrdinal `r .getRoxygenParam(itemName = "stepOrdinal")`
#'
#' @export
createAnalysisManifestItem <- function(name,
                                       description = NA,
                                       relativeRPath = NA,
                                       stepOrdinal = 0) {

  item <- Barista::AnalysisManifestItem$new(name = name,
                                            description = description,
                                            relativeRPath = relativeRPath,
                                            stepOrdinal = stepOrdinal)

  return (item)
}

#' Create Migrate Manifest Item
#'
#' @description
#' Create Migrate Manifest Item to be used in the `MigrateManifest` within the Manifest Database.
#'
#' @param name `r .getRoxygenParam(itemName = "name")`
#' @param description `r .getRoxygenParam(itemName = "description")`
#' @param relativeRPath `r .getRoxygenParam(itemName = "relativeRPath")`
#' @param stepOrdinal `r .getRoxygenParam(itemName = "stepOrdinal")`
#'
#' @export
createMigrateManifestItem <- function(name,
                                      description = NA,
                                      relativeRPath = NA,
                                      stepOrdinal = 0) {

  item <- Barista::MigrateManifestItem$new(name = name,
                                           description = description,
                                           relativeRPath = relativeRPath,
                                           stepOrdinal = stepOrdinal)

  return (item)
}

# add to manifests -----

#' Add File Manifest Item
#'
#' @description
#' Add File Manifest Item to the `FileManifest` within the Manifest Database.
#' Note: this is not a typical pattern for most users.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param fileManifestItem `r .getRoxygenParam(itemName = "fileManifestItem")`
#'
#' @export
addFileManifestItem <- function(manifestDb,
                                fileManifestItem) {

  checkmate::assertClass(x = manifestDb, classes = c("ManifestDatabase"))
  manifestDb$fileManifest$addFileManifestItem(definition = fileManifestItem)

  invisible(manifestDb)
}

#' Add Concept Set Manifest Item
#'
#' @description
#' Add Concept Set Manifest Item to the `ConceptSetManifest` within the Manifest Database.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param conceptSetManifestItem `r .getRoxygenParam(itemName = "conceptSetManifestItem")`
#'
#' @export
addConceptSetManifestItem <- function(manifestDb,
                                      conceptSetManifestItem) {
  checkmate::assertClass(x = manifestDb, classes = c("ManifestDatabase"))
  manifestDb$conceptSetManifest$addConceptSetManifestItem(definition = conceptSetManifestItem)

  invisible(manifestDb)
}

#' Add Cohort Manifest Item
#'
#' @description
#' Add Cohort Manifest Item to the `CohortManifest` within the Manifest Database.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param cohortManifestItem `r .getRoxygenParam(itemName = "cohortManifestItem")`
#' @param dependentCohortIds `r .getRoxygenParam(itemName = "dependentCohortIds")`
#'
#' @export
addCohortManifestItem <- function(manifestDb,
                                  cohortManifestItem,
                                  dependentCohortIds = c()) {
  checkmate::assertClass(x = manifestDb, classes = c("ManifestDatabase"))
  manifestDb$cohortManifest$addCohortManifestItem(definition = cohortManifestItem)

  if (length(dependentCohortIds) > 0) {
    cohortManifestItem$setDependentItemIds(dependentItemIds = dependentCohortIds)

    # add dependencies ----

    for (dependentId in dependentCohortIds) {
      name <- glue::glue("Cohort {cohortManifestItem$idValue} depends on cohort {dependentId}")
      dependencyItem <- Barista::DependencyManifestItem$new(name = name,
                                                            manifestItemId = cohortManifestItem$idValue,
                                                            manifestType = "Cohort",
                                                            dependentItemId = dependentId)
      manifestDb$dependencyManifest$addDependencyManifestItem(definition = dependencyItem)
    }

  }
  invisible(manifestDb)
}

# deprecate item -----

#' Deprecate Concept Set Manifest Item
#'
#' @description
#' Deprecate Concept Set Manifest Item within the `ConceptSetManifest` in the Manifest Database.
#' This function marks the specified concept set as deprecated, meaning it will no longer be used in analyses.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param conceptSetId `r .getRoxygenParam(itemName = "conceptSetId")`
#'
#' @export
deprecateConceptSetManifestItem <- function(manifestDb,
                                            conceptSetId) {
  checkmate::assertClass(x = manifestDb, classes = c("ManifestDatabase"))
  manifestDb$conceptSetManifest$deprecateConceptSetId(conceptSetId = conceptSetId)

  invisible(manifestDb)
}

#' Deprecate Cohort Manifest Item
#'
#' @description
#' Deprecate Cohort Manifest Item within the `CohortManifest` in the Manifest Database.
#' This function marks the specified cohort as deprecated,
#' meaning it will no longer be used in the cohort definition set or in analyses.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param cohortId `r .getRoxygenParam(itemName = "cohortId")`
#'
#' @export
deprecateCohortManifestItem <- function(manifestDb,
                                        cohortId) {
  checkmate::assertClass(x = manifestDb, classes = c("ManifestDatabase"))
  manifestDb$cohortManifest$deprecateCohortId(cohortId = cohortId)

  invisible(manifestDb)
}

#' Deprecate File Manifest Item
#'
#' @description
#' Deprecate File Manifest Item within the `FileManifest` in the Manifest Database.
#' This function marks the specified cohort as deprecated,
#' meaning it will no longer be used in the cohort definition set or in analyses.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param fileId `r .getRoxygenParam(itemName = "fileId")`
#'
#' @export
deprecateFileManifestItem <- function(manifestDb,
                                      fileId) {
  checkmate::assertClass(x = manifestDb, classes = c("ManifestDatabase"))
  manifestDb$fileManifest$deprecateFileId(fileId = fileId)

  invisible(manifestDb)
}

#' Deprecate Analysis Manifest Item
#'
#' @description
#' Deprecate Analysis Manifest Item within the `AnalysisManifest` in the Manifest Database.
#' This function marks the specified analysis as deprecated,
#' meaning it will no longer be used in the analysis manifest.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param analysisId `r .getRoxygenParam(itemName = "analysisId")`
deprecateAnalysisManifestItem <- function(manifestDb,
                                          analysisId) {
  checkmate::assertClass(x = manifestDb, classes = c("ManifestDatabase"))
  manifestDb$analysisManifest$deprecateAnalysisId(analysisId = analysisId)

  invisible(manifestDb)
}

#' Deprecate Migrate Manifest Item
#'
#' @description
#' Deprecate Migrate Manifest Item within the `MigrateManifest` in the Manifest Database.
#' This function marks the specified migrate item as deprecated,
#' meaning it will no longer be used in the migrate manifest.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param migrateId `r .getRoxygenParam(itemName = "migrateId")`
#'
#' @export
deprecateMigrateManifestItem <- function(manifestDb,
                                         migrateId) {
  checkmate::assertClass(x = manifestDb, classes = c("ManifestDatabase"))
  manifestDb$migrateManifest$deprecateMigrateId(migrateId = migrateId)

  invisible(manifestDb)
}

# tag a manifest item ----

#' Apply Tag to Concept Set Item
#'
#' @description
#' Apply Tag to Concept Set Item
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param conceptSetId `r .getRoxygenParam(itemName = "conceptSetId")`
#' @param tagName `r .getRoxygenParam(itemName = "tagName")`
#' @param tagValue `r .getRoxygenParam(itemName = "tagValue")`
#'
#' @export
applyTagToConceptSetItem <- function(manifestDb,
                                     conceptSetId,
                                     tagName,
                                     tagValue) {

  manifestType <- "ConceptSet"

  .applyTagToManifestItem(manifestDb = manifestDb,
                          manifestType = manifestType,
                          manifestItemId = conceptSetId,
                          tagName = tagName,
                          tagValue = tagValue)

  invisible(manifestDb)
  cli::cli_inform("Tag applied to the manifest item.")
}

#' Apply Tag to Cohort Manifest Item
#'
#' @description
#' Apply Tag to Cohort Manifest Item
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param cohortId `r .getRoxygenParam(itemName = "cohortId")`
#' @param tagName `r .getRoxygenParam(itemName = "tagName")`
#' @param tagValue `r .getRoxygenParam(itemName = "tagValue")`
#'
#' @export
applyTagToCohortManifestItem <- function(manifestDb,
                                         cohortId,
                                         tagName,
                                         tagValue) {

  manifestType <- "Cohort"

  .applyTagToManifestItem(manifestDb = manifestDb,
                          manifestType = manifestType,
                          manifestItemId = cohortId,
                          tagName = tagName,
                          tagValue = tagValue)

  invisible(manifestDb)
  cli::cli_inform("Tag applied to the manifest item.")
}

# reset manifests ------

#' Reset File Manifest
#'
#' @description
#' Reset File Manifest
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param resetType `r .getRoxygenParam(itemName = "resetType")`
#'
#' @export
resetFileManifest <- function(manifestDb,
                              resetType = "hard") {
  manifestType <- "File"
  .resetManifest(manifestDb = manifestDb,
                 manifestType = manifestType)
}

#' Reset Concept Set Manifest
#'
#' @description
#' Reset Concept Set Manifest
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param resetType `r .getRoxygenParam(itemName = "resetType")`
#'
#' @export
resetConceptSetManifest <- function(manifestDb,
                                    resetType = "hard") {
  manifestType <- "ConceptSet"
  .resetManifest(manifestDb = manifestDb,
                 manifestType = manifestType,
                 resetType = resetType)
}

#' Reset Cohort Manifest
#'
#' @description
#' Reset Cohort Manifest
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param resetType `r .getRoxygenParam(itemName = "resetType")`
#'
#' @export
resetCohortManifest <- function(manifestDb,
                                resetType = "hard") {
  manifestType <- "Cohort"
  manifestDb$resetManifest(manifestType = manifestType,
                           resetType = resetType)
}

#' Reset Analysis Manifest
#' @description
#' Reset Analysis Manifest
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param resetType `r .getRoxygenParam(itemName = "resetType")`
#'
#' @export
resetAnalysisManifest <- function(manifestDb,
                                  resetType = "hard") {
  manifestType <- "Analysis"
  manifestDb$resetManifest(manifestType = manifestType,
                           resetType = resetType)
}

#' Reset Tag Manifest
#'
#' @description
#' Reset Tag Manifest
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param resetType `r .getRoxygenParam(itemName = "resetType")`
#'
#' @export
resetTagManifest <- function(manifestDb,
                             resetType = "hard") {
  manifestType <- "Tag"
  manifestDb$resetManifest(manifestType = manifestType,
                           resetType = resetType)
}

