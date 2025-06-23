
.getManifestItemDescription <- function(itemName) {
  checkmate::assertString(x = itemName)
  description <- glue::glue("The `{itemName}` R6 class inherits from the `ManifestItem` R6 class.")
  return (description)
}

.getManifestItemDetails <- function(itemName) {

  manifestName <- stringr::str_remove(string = itemName, pattern = "Item")
  details <- glue::glue("The {itemName} is used to populate the `{manifestName}` object within a `ManifestDb`.")
  return (details)
}

.getRoxygenParam <- function(itemName) {
  ymlFile <- "inst/yml/roxygenParams.yml"
  checkmate::assertFileExists(x = ymlFile)

  allResults <- yaml::read_yaml(ymlFile)

  result <- allResults[[itemName]]
  checkmate::assertString(x = result, min.chars = 1)
  return (result)
}
