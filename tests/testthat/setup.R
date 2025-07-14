library(testthat)
library(Barista)

# create cohort manifest db ----

dbPath <- testthat::test_path("test.sqlite")

if (fs::file_exists(dbPath)) {
  manifestDb <- resetManifestDb(dbPath = dbPath)
} else {
  manifestDb <- createManifestDb(dbPath = dbPath)
}

## for testing, alter file manifest ----

deprecateFileManifestItem(manifestDb = manifestDb, fileId = 2)
deprecateFileManifestItem(manifestDb = manifestDb, fileId = 3)


sqlFileItem <- createFileManifestItem(name = "Overridden Cohort sql files",
                                     manifestType = "Cohort",
                                     fileExtension = "sql",
                                     relativePath = fs::path("tests", "testthat", "cohorts", "sql"))

jsonFileItem <- createFileManifestItem(name = "Overridden Cohort json files",
                                       manifestType = "Cohort",
                                       fileExtension = "json",
                                       relativePath = fs::path("tests", "testthat", "cohorts", "json"))

addFileManifestItem(manifestDb = manifestDb, fileManifestItem = jsonFileItem)
addFileManifestItem(manifestDb = manifestDb, fileManifestItem = sqlFileItem)

