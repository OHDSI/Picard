
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
#'
#' @export
viewConceptSetManifest <- function(manifestDb,
                                   includeDeprecated = FALSE) {
  manifestType <- "ConceptSet"
  manifest <- .viewManifest(manifestDb = manifestDb,
                            manifestType = manifestType,
                            includeDeprecated = includeDeprecated)
  return (manifest)
}

#' View the Cohort Manifest
#'
#' @description
#' View Cohort Manifest from a given Manifest Database object, as a tibble.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param includeDeprecated `r .getRoxygenParam(itemName = "includeDeprecated")`
#'
#' @export
viewCohortManifest <- function(manifestDb,
                               includeDeprecated = FALSE) {
                               #withTags = FALSE) {
  manifestType <- "Cohort"
  manifest <- .viewManifest(manifestDb = manifestDb,
                            manifestType = manifestType,
                            includeDeprecated = includeDeprecated)
                            #withTags = withTags)
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
#'
#' @export
viewDependencyManifest <- function(manifestDb,
                                   includeDeprecated = FALSE) {
  manifestType <- "Dependency"
  manifest <- .viewManifest(manifestDb = manifestDb,
                            manifestType = manifestType,
                            includeDeprecated = includeDeprecated)
  return (manifest)
}

#' View Analysis Manifest
#'
#' @description
#' View Analysis Manifest from a given Manifest Database object, as a tibble.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param includeDeprecated `r .getRoxygenParam(itemName = "includeDeprecated")`
#'
#' @export
viewAnalysisManifest <- function(manifestDb,
                                 includeDeprecated = FALSE) {
  manifestType <- "Analysis"
  manifest <- .viewManifest(manifestDb = manifestDb,
                            manifestType = manifestType,
                            includeDeprecated = includeDeprecated)
  return (manifest)
}

#' View Migrate Manifest
#'
#' @description
#' View Migrate Manifest from a given Manifest Database object, as a tibble.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param includeDeprecated `r .getRoxygenParam(itemName = "includeDeprecated")`
#'
#' @export
viewMigrateManifest <- function(manifestDb,
                                includeDeprecated = FALSE) {
  manifestType <- "Migrate"
  manifest <- .viewManifest(manifestDb = manifestDb,
                            manifestType = manifestType,
                            includeDeprecated = includeDeprecated)
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
#' @param relativeCaprPath `r .getRoxygenParam(itemName = "relativeCaprPath")`
#' @param relativeRPath `r .getRoxygenParam(itemName = "relativeRPath")`
#' @param dependentItemIds `r .getRoxygenParam(itemName = "dependentItemIds")`
#'
#' @export
createCohortManifestItem <- function(name,
                                     provenanceId = -1,
                                     designMethod,
                                     relativeSqlPath = NA,
                                     relativeJsonPath = NA,
                                     relativeCaprPath = NA,
                                     relativeRPath = NA,
                                     dependentItemIds = NULL) {

  item <- Barista::CohortManifestItem$new(
    name = name,
    provenanceId = provenanceId,
    designMethod = designMethod,
    relativeSqlPath = relativeSqlPath,
    relativeJsonPath = relativeJsonPath,
    relativeCaprPath = relativeCaprPath,
    relativeRPath = relativeRPath
  )
  item$setDependentItemIds(dependentItemIds = dependentItemIds)
  return (item)
}

# add to manifests -----

#' Add File Manifest Item
#'
#' @description
#' Add File Manifest Item to the `FileManifest` within the Manifest Database.
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param fileManifestItem `r .getRoxygenParam(itemName = "fileManifestItem")`
#'
#' @export
addFileManifestItem <- function(manifestDb,
                                fileManifestItem) {
  checkmate::assertClass(x = manifestDb, classes = c("ManifestDatabase"))
  manifestDb$fileManifest$addFileManifest(definition = fileManifestItem)

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
#'
#' @export
addCohortManifestItem <- function(manifestDb,
                                  cohortManifestItem) {
  checkmate::assertClass(x = manifestDb, classes = c("ManifestDatabase"))
  manifestDb$cohortManifest$addCohortManifestItem(definition = cohortManifestItem)

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

# view manifest based on tag ----

#' View Concept Set Manifest by Tags
#'
#' @description
#' View Concept Set Manifest by Tags
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param includeDeprecated `r .getRoxygenParam(itemName = "includeDeprecated")`
#' @param tagNameValues `r .getRoxygenParam(itemName = "tagNameValues")`
#'
#' @export
viewConceptManifestByTags <- function(manifestDb,
                                      includeDeprecated = FALSE,
                                      tagNameValues) {

  filteredManifest <- manifestDb$filteredManifestAsTibble(tagNameValues = tagNameValues,
                                                          includeDeprecated = includeDeprecated)
  return (filteredManifest)
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
  manifestDb$resetManifest(manifestType = "Cohort",
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
  manifestDb$resetManifest(manifestType = "Analysis",
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
  manifestDb$resetManifest(manifestType = "Tag",
                           resetType = resetType)
}
