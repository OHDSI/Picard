

.viewManifest <- function(manifestDb,
                          manifestType,
                          includeDeprecated = FALSE) {

  checkmate::assertClass(x = manifestDb, classes = c("ManifestDatabase"))

  manifestBinding <- paste0(snakecase::to_lower_camel_case(manifestType), "Manifest")
  thisManifest <- manifestDb[[manifestBinding]]$manifestAsTibble

  if (!includeDeprecated & !manifestType %in% c("File")) {
    thisManifest <- thisManifest |>
      dplyr::filter(!deprecate)
  }
  return (thisManifest)
}

# .addManifestItem <- function(manifestDb,
#                              manifestType,
#                              definition) {
#   checkmate::assertClass(x = manifestDb, classes = c("ManifestDb"))
#
#   manifestBinding <- paste0(snakecase::to_lower_camel_case(manifestType), "Manifest")
#
#   manifestDb[[manifestBinding]]$addManifestItem(definition = definition)
# }

.resetManifest <- function(manifestDb,
                           manifestType,
                           resetType) {

  if (resetType == "hard") {
    warning <- glue::glue(
      "Hard reset of the manifest will remove all items from the manifest.",
      "This action cannot be undone."
    )
  } else {
    warning <- glue::glue(
      "Soft reset of the manifest will deprecate all items in the manifest.",
      "This action cannot be undone."
    )
  }

  cli::cli_warn(message = warning)
  checkmate::assertClass(x = manifestDb, classes = c("ManifestDatabase"))
  manifestDb$resetManifest(manifestType = manifestType,
                           resetType = resetType)
}

.applyTagToManifestItem <- function(manifestDb,
                                    manifestType,
                                    manifestItemId,
                                    tagName,
                                    tagValue) {

  checkmate::assertClass(x = manifestDb, classes = c("ManifestDatabase"))
  checkmate::assertChoice(x = manifestType, choices = c("File", "ConceptSet", "Cohort", "Analysis"))

  manifestBinding <- paste0(snakecase::to_lower_camel_case(manifestType), "Manifest")
  thisManifest <- manifestDb[[manifestBinding]]

  checkmate::assert(thisManifest$checkItemExists(manifestItemId = manifestItemId))
                    #msg = glue::glue("Manifest item with ID {manifestItemId} does not exist in the {manifestType} manifest."))

  # check if tag exists ---
  # TODO

  item <- Barista::TagManifestItem$new(
    name = tagName,
    manifestItemId = manifestItemId,
    manifestType = manifestType,
    value = tagValue
  )

  manifestDb$tagManifest$addTagManifestItem(definition = item)
}
