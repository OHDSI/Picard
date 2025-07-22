
#' Bulk Load Cohorts (WIP)
#'
#' @description
#' This function can be used to bulk load cohorts into the Cohort Manifest.
#'
#' @details
#' The data frame must have the following columns:
#' #' - `name`: The name of the cohort.
#' #' - `provenanceId`: The ID of the provenance.
#' #' - `designMethod`: The method used to design the cohort.
#' #' - `relativeJsonPath`: The relative path to the JSON file defining the cohort.
#' #' - ``:
#'
#'
#' @param manifestDb `r .getRoxygenParam(itemName = "manifestDb")`
#' @param cohortsToLoad `r .getRoxygenParam(itemName = "cohortsToLoad")`
#'
#' @export
bulkLoadCohorts <- function(manifestDb,
                            cohortsToLoad,
                            baseUrl = NULL) {

  for (i in 1:nrow(cohortsToLoad)) {

    thisCohortName <- cohortsToLoad[i,]$name
    thisProvenanceId <- cohortsToLoad[i,]$provenanceId
    thisJsonPath <- cohortsToLoad[i,]$relativeJsonPath
    thisSqlPath <- cohortsToLoad[i,]$relativeSqlPath
    thisRPath <- cohortsToLoad[i,]$relativeRPath
    thisDesignMethod <- cohortsToLoad[i,]$designMethod

    if (thisDesignMethod == "Atlas") {

      if (is.na(thisJsonPath)) {
        checkmate::assertString(x = baseUrl, na.ok = FALSE, null.ok = FALSE, min.chars = 1)
        definition <- ROhdsiWebApi::getCohortDefinition(cohortId = thisProvenanceId,
                                                        baseUrl = baseUrl)
        thisJson <- RJSONIO::toJSON(x = definition$expression, digits = 23, pretty = TRUE)
        thisJsonPath <- fs::path(manifestDb$fileManifest$getRelativePath(manifestType = "Cohort",
                                                                         fileExtension = "json"),
                                 thisCohortName, ext = "json")
        writeLines(text = thisJson, con = thisJsonPath)
      }

      newCohort <- Barista::createCohortManifestItem(name = cohortsToLoad[i,]$name,
                                                     provenanceId = cohortsToLoad[i,]$provenanceId,
                                                     designMethod = "Atlas",
                                                     relativeJsonPath = cohortsToLoad[i,]$relativeJsonPath)

    } else if (designMethod == "Capr") {

    } else if (designMethod == "") {

    }
  }

}





