#' Get Default File Root Paths
#'
#' @export
getDefaultFileRootPaths <- function() {
  filePath <- system.file(package = "Barista", fs::path("yml", "defaultFileRootPaths", ext = "yml"))
  result <- yaml::read_yaml(file = filePath)
  finalResult <- result$default
  return (finalResult)
}


#' Get Design Methods
#'
#' @export
getConceptSetDesignMethods <- function() {
  filePath <- system.file(package = "Barista", fs::path("yml", "conceptSetDesignMethods", ext = "yml"))
  result <- yaml::read_yaml(file = filePath)
  finalResult <- unlist(result$designMethods)
  return (finalResult)
}

#' Get Design Methods
#'
#' @export
getCohortDesignMethods <- function() {
  filePath <- system.file(package = "Barista", fs::path("yml", "cohortDesignMethods", ext = "yml"))
  result <- yaml::read_yaml(file = filePath)
  finalResult <- unlist(result$designMethods)
  return (finalResult)
}

