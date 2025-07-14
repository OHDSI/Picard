# ManifestItem -----

ManifestItem <- R6::R6Class(
  classname = "ManifestItem",

  ## public -----
  public = list(
    initialize = function(manifestItemType) {
      private$.idFieldName <- paste0(
        snakecase::to_lower_camel_case(manifestItemType),
        "Id"
      )
    },
    loadItem = function(name, deprecate = 0, ...) {
      checkmate::assertCharacter(x = name, min.len = 1, any.missing = FALSE)

      thisItem <- tibble::tibble(
        name = name,
        deprecate = 0,
        ...
      )
      thisItem[[private$.idFieldName]] <- NA
      thisItem <- thisItem |>
        dplyr::select(private$.idFieldName, dplyr::everything())

      private$.thisItem <- thisItem
    },
    setIdValue = function(idValue) {
      checkmate::assertNumeric(x = idValue, len = 1, any.missing = FALSE)
      private$.idValue <- idValue
      private$.thisItem[[private$.idFieldName]] <- private$.idValue
    },
    setFieldValue = function(fieldName, fieldValue) {
      private$.thisItem[[fieldName]] <- fieldValue
    }
    # setDependentItemIds = function(dependentItemIds) {
    #   private$.dependentItemIds <- dependentItemIds
    # }
  ),
  private = list(
    .thisItem = NULL,
    .idFieldName = NULL,
    .idValue = NA,
    .dependentItemIds = NULL
  ),
  active = list(
    dependentItemIds = function() {
      return(private$.dependentItemIds)
    },
    thisItem = function() {
      return(private$.thisItem)
    },
    idValue = function() {
      return(private$.idValue)
    },
    idFieldName = function() {
      return(private$.idFieldName)
    },
    idFieldNameSnakeCase = function() {
      return(snakecase::to_snake_case(private$.idFieldName))
    },
    thisItemSnakeCase = function() {
      return(
        private$.thisItem |>
          dplyr::rename_with(.fn = snakecase::to_snake_case)
      )
    }
  )
)

# Manifest -----

Manifest <- R6::R6Class(
  classname = "Manifest",

  ## public ----
  public = list(
    manifest = NULL,
    manifestDb = NULL,
    manifestType = NULL,

    initialize = function(manifestDb, manifestType) {
      choices <- c("ConceptSet",
                   "Cohort",
                   "Analysis",
                   "Migrate",
                   "File",
                   "Tag",
                   "Dependency")

      checkmate::assertChoice(x = manifestType, choices = choices)

      self$manifestType <- manifestType

      private$.idFieldName <- paste0(
        snakecase::to_lower_camel_case(manifestType),
        "Id"
      )

      # checkmate::assertClass(x = manifestDb, classes = c("ManifestDatabase"))
      self$manifestDb <- manifestDb

      tableExists <- RSQLite::dbExistsTable(
        conn = self$manifestDb$db,
        name = self$manifestType
      )

      #print(tableExists)
      if (!tableExists) {
        private$.createEmptyManifest()
      } else {
        checkmate::assert(private$.validateTableSchema())
      }

      self$manifest <- dplyr::tbl(src = self$manifestDb$db, self$manifestType)
    },

    getItemIdByName = function(name) {
      result <- self$manifestAsTibble |>
        dplyr::filter(name == !!name) |>
        dplyr::pull(self$idFieldName) |>
        unique()

      if (length(result) == 0) {
        cli::cli_alert_danger(text = "No {self$manifestType} found with name {name}.")
        return (NA)
      } else {
        return (result)
      }
    },
    deprecateManifestItemId = function(manifestItemId) {

      allAffectedItemIds <- self$manifestDb$dependencyManifest$getAllAffectedItemIds(
        manifestType = self$manifestType,
        manifestItemId = manifestItemId
      )

      theseItems <- self$manifest |>
        dplyr::filter(!!rlang::sym(self$idFieldNameSnakeCase) %in% allAffectedItemIds) |>
        dplyr::collect() |>
        dplyr::mutate(deprecate = 1)

      if (nrow(theseItems) > 0) {

        # TODO: prompt user to confirm deprecating all affected item ids
        cli::cli_alert_warning(
          text = "Deprecating {self$manifestType} with ids {allAffectedItemIds}."
        )

        rowsToUpdate <- dbplyr::copy_inline(
          con = self$manifestDb$db,
          df = theseItems
        )

        dplyr::rows_update(
          x = self$manifest,
          y = rowsToUpdate,
          by = self$idFieldNameSnakeCase,
          unmatched = "ignore",
          in_place = TRUE
        )
      }
    },

    deprecateAllItems = function() {
      for (manifestItemId in self$activeManifestIds) {
        self$deprecateManifestItemId(manifestItemId = manifestItemId)
      }
    },
    checkItemExists = function(manifestItemId) {

      result <- self$manifestAsTibble |>
        dplyr::filter(
          !!rlang::sym(self$idFieldName) == manifestItemId,
          !deprecate
        )
      return (nrow(result) == 1)
    },
    addManifestItem = function(manifestItem,
                               suppressCli = FALSE) {
      manifestItemClass <- glue::glue("{self$manifestType}ManifestItem")

      # check that manifestItem is of the manifestItemClass ----
      checkmate::assertClass(x = manifestItem, classes = c(manifestItemClass))

      # check that manifestItem does not represent a duplicate ---
      checkmate::assert(private$.checkNotDuplicate(manifestItem = manifestItem))

      sql <- glue::glue(
        "select max({manifestItem$idFieldNameSnakeCase}) as id
                         from {self$manifestType};"
      )

      thisItem <- manifestItem$thisItemSnakeCase

      rowToAdd <- dbplyr::copy_inline(
        con = self$manifestDb$db,
        df = thisItem
      )
      dplyr::rows_insert(
        x = self$manifest,
        y = rowToAdd,
        by = c(manifestItem$idFieldNameSnakeCase),
        in_place = TRUE,
        conflict = "ignore"
      )

      thisManifestId <- RSQLite::dbGetQuery(
        conn = self$manifestDb$db,
        statement = sql
      )

      manifestItem$setIdValue(idValue = thisManifestId$id)

      if (!suppressCli) {
        cli::cli_inform(glue::glue("New {self$manifestType} item added with id {thisManifestId$id}"))
      }

      return (thisManifestId$id)
    }
  ),

  ## active ----
  active = list(
    manifestAsTibble = function() {
      return(
        self$manifest |>
          dplyr::rename_with(.fn = snakecase::to_lower_camel_case) |>
          dplyr::collect()
      )
    },
    activeManifestIds = function() {
      idFieldName <- paste0(snakecase::to_lower_camel_case(self$manifestType), "Id")
      manifestIds <- self$manifestAsTibble |>
        dplyr::filter(!deprecate) |>
        dplyr::pull(!!idFieldName) |>
        unique()

      return (manifestIds)
    },
    filteredManifestAsTibble = function(includeDeprecated,
                                        tagNameValues) {

      idFieldName <- paste0(snakecase::to_lower_camel_case(self$manifestType), "Id")

      tagManifest <- private$.tagManifest |>
        dplyr::filter(manifestType == self$manifestType) |>
        dplyr::rename(idFieldName = "manifestItemId")

      filteredManifest <- self$manifestAsTibble() |>
        dplyr::inner_join(y = tagManifest,
                          by = c(idFieldName))

      for (tagNameValue in tagNameValues) {
        filteredManifest <- filteredManifest |>
          dplyr::filter(name == tagNameValue$name)
      }

      return (filteredManifest)
    },
    idFieldName = function() {
      return(private$.idFieldName)
    },
    idFieldNameSnakeCase = function() {
      return(snakecase::to_snake_case(private$.idFieldName))
    }
  ),

  ## private ----
  private = list(
    .idFieldName = NULL,

    .checkNotDuplicate = function(manifestItem) {
      result <- self$manifestAsTibble |>
        dplyr::filter(name == manifestItem$thisItem$name)

      return (nrow(result) == 0)
    },

    .createEmptyManifest = function() {
      fieldsList <- private$.getFieldsList()

      RSQLite::dbCreateTable(
        conn = self$manifestDb$db,
        name = self$manifestType,
        fields = fieldsList
      )
    },

    .getFieldsDf = function() {
      prefix <- snakecase::to_lower_camel_case(string = self$manifestType)

      idFieldsCsv <- system.file("csv", "idFields.csv", package = "Barista")
      idFieldsDf <- readr::read_csv(
        file = idFieldsCsv,
        show_col_types = FALSE
      ) |>
        dplyr::filter(manifestType == self$manifestType) |>
        dplyr::select(-manifestType)

      baseFieldsCsv <- system.file("csv", "baseFields.csv", package = "Barista")
      specificFieldsCsv <- system.file(
        "csv",
        glue::glue("{prefix}Fields.csv"),
        package = "Barista"
      )

      baseFieldsDf <- readr::read_csv(
        file = baseFieldsCsv,
        show_col_types = FALSE
      )

      specificFieldsDf <- NULL

      if (fs::file_exists(specificFieldsCsv)) {
        specificFieldsDf <- readr::read_csv(
          file = specificFieldsCsv,
          show_col_types = FALSE
        )
      }

      allFieldsDf <- dplyr::bind_rows(
        idFieldsDf,
        baseFieldsDf,
        specificFieldsDf
      )

      return(allFieldsDf)
    },
    .getFieldsList = function() {
      allFieldsDf <- private$.getFieldsDf()
      fieldsList <- setNames(
        as.list(allFieldsDf$fieldSuffix),
        nm = allFieldsDf$name
      )
      return(fieldsList)
    },
    .validateTableSchema = function() {
      sql <- glue::glue("PRAGMA table_info({self$manifestType});")

      allFieldsDf <- private$.getFieldsDf() |>
        dplyr::select(name, type, notnull, pk)

      result <- RSQLite::dbGetQuery(
        conn = self$manifestDb$db,
        statement = sql
      ) |>
        dplyr::select(name, type, notnull, pk) |>
        tibble::as_tibble()

      # print(allFieldsDf)
      # print(result)

      validation <- all.equal(result, allFieldsDf)

      return(validation)
    }
  )
)

# FileManifest -----

FileManifest <- R6::R6Class(
  classname = "FileManifest",
  inherit = Manifest,

  ## public ----
  public = list(
    initialize = function(manifestDb) {
      super$initialize(manifestDb = manifestDb, manifestType = "File")

      # load default root paths ----
      private$.addDefaultPaths()
    },
    deprecateFileId = function(fileId) {
      super$deprecateManifestItemId(manifestItemId = fileId)
    },
    addFileManifestItem = function(definition) {

      fs::dir_create(path = definition$relativePath)

      super$addManifestItem(
        manifestItem = definition
      )
    },
    getRelativePath = function(manifestType, fileExtension) {
      result <- self$manifestAsTibble |>
        dplyr::filter(
          manifestType == !!manifestType,
          fileExtension == !!fileExtension,
          !deprecate
        ) |>
        dplyr::pull(relativePath)

      return(result)
    }
  ),
  private = list(
    .addDefaultPaths = function() {
      if (nrow(self$manifestAsTibble) == 0) {
        fileRootPaths <- getDefaultFileRootPaths()
        for (manifestType in names(fileRootPaths)) {
          for (fileExtension in names(fileRootPaths[[manifestType]])) {
            fileManifestItem <- FileManifestItem$new(
              name = glue::glue("Default {manifestType} {fileExtension} files"),
              manifestType = manifestType,
              fileExtension = fileExtension,
              relativePath = fileRootPaths[[manifestType]][[fileExtension]]
            )
            super$addManifestItem(
              manifestItem = fileManifestItem,
              suppressCli = TRUE
            )
          }
        }
      }
    }
  )
)

# TagManifest -----

TagManifest <- R6::R6Class(
  classname = "TagManifest",
  inherit = Manifest,

  ## public ----
  public = list(
    initialize = function(manifestDb) {
      super$initialize(manifestDb = manifestDb, manifestType = "Tag")
    },
    deprecateTagId = function(tagId) {
      super$deprecateManifestItemId(manifestItemId = tagId)
    },
    addTagManifestItem = function(definition) {
      super$addManifestItem(
        manifestItem = definition
      )
    }
  )
)

# DependencyManifest -----

DependencyManifest <- R6::R6Class(
  classname = "DependencyManifest",
  inherit = Manifest,

  ## public ----
  public = list(
    initialize = function(manifestDb) {
      super$initialize(manifestDb = manifestDb, manifestType = "Dependency")
    },
    deprecateDependencyId = function(dependencyId) {
      super$deprecateManifestItemId(manifestItemId = dependencyId)
    },
    deprecateAllByManifestType = function(manifestType) {
      # deprecate all dependencies by manifest type
      allDependencyIds <- self$manifestAsTibble |>
        dplyr::filter(manifestType == !!manifestType, !deprecate) |>
        dplyr::pull(dependencyId) |>
        unique()

      for (dependencyId in allDependencyIds) {
        self$deprecateDependencyId(dependencyId = dependencyId)
      }
    },
    addDependencyManifestItem = function(definition) {
      super$addManifestItem(
        manifestItem = definition
      )
    },
    getAllAffectedItemIds = function(manifestType,
                                     manifestItemId) {

      theseDependencies <- self$manifestAsTibble |>
        dplyr::filter(
          manifestType == !!manifestType,
          !deprecate
        )

      if (nrow(theseDependencies) == 0) {
        return (manifestItemId)
      } else {
        thisGraph <- theseDependencies |>
          dplyr::select(dependentItemId, manifestItemId) |>
          tidygraph::as_tbl_graph()

        paths <- igraph::shortest_paths(
          thisGraph |> tidygraph::as.igraph(),
          from = manifestItemId
        )$vpath

        # get array of all nodes from paths
        allNodes <- lapply(paths, function(x) {
          x |> as.integer()
        })

        # collapse allNodes into unique integers
        allManifestItemIds <- unique(unlist(allNodes))

        return (allManifestItemIds)
      }
    },
    checkItemDependency = function(manifestItemId,
                                   manifestType,
                                   dependentIds) {

      # check that the item's intended dependencies are present and not deprecated
      dependentIds <- unique(dependentIds)

      ## get the manifest item row ----

      manifestBinding <- paste0(snakecase::to_lower_camel_case(manifestType), "Manifest")
      thisManifest <- manifestDb[[manifestBinding]]

      items <- thisManifest$manifestAsTibble |>
        dplyr::filter(!!rlang::sym(thisManifest$idFieldName) %in% dependentIds,
                      !deprecate)

      if (nrow(items) != length(dependentIds)) {

        missingItems <- setdiff(dependentIds, items[[thisManifest$idFieldName]])

        cli::cli_alert_danger(text = "Dependency check FAILED for {manifestType} {manifestItemId}")
        cli::cli_alert_info(text = "Missing or deprecated dependencies: {missingItems}")
        return (FALSE)
      }

      return (TRUE)
    },
    checkManifestDependency = function() {
      # for each subset cohort, check that its dependencies are in the manifest and not deprecated

      # TODO

      return (TRUE)
    },
    getDependentItemIdsForItem = function(manifestType,
                                          manifestItemId) {
      result <- self$manifestAsTibble |>
        dplyr::filter(
          manifestType == !!manifestType,
          manifestItemId == !!manifestItemId,
          !deprecate
        ) |>
        dplyr::pull(dependentItemId) |> unique()

      return (result)
    }
  )
)


# ConceptSetManifest -----

ConceptSetManifest <- R6::R6Class(
  classname = "ConceptSetManifest",
  inherit = Manifest,

  ## public ----
  public = list(
    initialize = function(manifestDb) {
      super$initialize(manifestDb = manifestDb, manifestType = "ConceptSet")
    },
    addConceptSetManifestItem = function(definition) {
      super$addManifestItem(
        manifestItem = definition
      )
    },
    deprecateConceptSetId = function(conceptSetId) {
      super$deprecateManifestItemId(manifestItemId = conceptSetId)
    }
  )
)

# CohortManifest -----

CohortManifest <- R6::R6Class(
  classname = "CohortManifest",
  inherit = Manifest,

  ## public ----
  public = list(
    initialize = function(manifestDb) {
      super$initialize(manifestDb = manifestDb, manifestType = "Cohort")
    },
    deprecateCohortId = function(cohortId) {
      super$deprecateManifestItemId(manifestItemId = cohortId)
    },
    addCohortManifestItem = function(definition) {

      newCohortId <- 1
      if (nrow(self$manifestAsTibble) > 0) {
        newCohortId <- as.integer(max(self$manifestAsTibble$cohortId) + 1)
      }
      definition$setIdValue(idValue = newCohortId)

      # check dependency validity ---

      if (!is.null(definition$dependentItemIds)) {
        dependencyCheck <- self$manifestDb$dependencyManifest$checkItemDependency(
          manifestItemId = definition$idValue,
          manifestType = "Cohort",
          dependentIds = definition$dependentItemIds
        )
        checkmate::assert(dependencyCheck)
      }

      if (definition$thisItem$designMethod == "SqlTemplate") {
        private$.addSqlTemplateDefinition(definition = definition)
      } else if (definition$thisItem$designMethod == "UnionTemplate") {
        private$.addUnionDefinition(definition = definition)
      } else if (definition$thisItem$designMethod == "Subset") {
        private$.addSubsetDefinition(definition = definition)
      } else {
        # commit a standard Atlas/Circe cohort to the manifest
        private$.commitToManifest(definition = definition)
      }
    }
  ),

  ## active ----
  active = list(
    asCohortDefinitionSet = function() {

      if (nrow(self$manifestAsTibble) == 0) {
        return(CohortGenerator::createEmptyCohortDefinitionSet())
      }

      dependencyCheck <- TRUE #.checkDependencies()

      if (!dependencyCheck) {
        cli::cli_alert_danger(text = "Cohort depenency check FAILED")
      } else {
        cohortIdsWithDependencies <- self$manifestDb$dependencyManifest$manifestAsTibble |>
          dplyr::filter(manifestType == "Cohort", !deprecate) |>
          dplyr::pull(manifestItemId) |>
          unique()

        cohortDefinitionSet <- self$manifestAsTibble |>
          dplyr::rename(cohortName = name) |>
          dplyr::mutate(isSubset = cohortId %in% cohortIdsWithDependencies) |>
          dplyr::rowwise() |>
          dplyr::mutate(
            subsetParent = private$.getSubsetParent(thisCohortId = cohortId),
            sql = SqlRender::readSql(sourceFile = relativeSqlPath),
            json = private$.getCohortJson(thisJsonPath = relativeJsonPath)
          ) |>
          dplyr::ungroup() |>
          dplyr::select(cohortId,
                        cohortName,
                        sql,
                        json,
                        isSubset,
                        subsetParent)

        return(cohortDefinitionSet)
      }
    }
  ),

  ## private ----
  private = list(
    .getSubsetParent = function(thisCohortId) {
      theseDependencies <- self$manifestDb$dependencyManifest$getDependentItemIdsForItem(
        manifestType = "Cohort",
        manifestItemId = thisCohortId
      )

      if (length(theseDependencies) > 0) {
        # TODO: is this the best approach, using the highest ordered parent?
        return (min(theseDependencies))
      } else {
        return (thisCohortId)
      }
    },
    .getCohortJson = function(thisJsonPath) {
      if (thisJsonPath == "NA" | is.na(thisJsonPath)) {
        return ("")
      } else {
        return (readr::read_file(file = thisJsonPath))
      }
    },
    .addDependency = function(definition) {
      for (dependencyId in definition$dependentItemIds) {
        newDependency <- DependencyManifestItem$new(
          name = glue::glue("Dependency for cohort {definition$thisItem$name}: cohort {dependencyId}"),
          manifestType = "Cohort",
          manifestItemId = definition$idValue,
          dependentItemId = dependencyId
        )

        self$manifestDb$dependencyManifest$addDependencyManifestItem(
          definition = newDependency
        )
      }
    },
    .addUnionDefinition = function(definition) {

      unionDefinition <- CohortGenerator::createUnionCohortTemplate(cohortDatabaseSchema = "@cohort_database_schema",
                                                                    cohortTable = "@cohort_table",
                                                                    cohortIds = definition$dependentItemIds,
                                                                    unionCohortId = definition$thisItem$cohortId)

      cohortDefinitionSet <- self$asCohortDefinitionSet |>
        CohortGenerator::addCohortTemplateDefintion(cohortTemplateDefintion = unionDefinition)

      templateSql <- cohortDefinitionSet |>
        dplyr::slice_max(n = 1, order_by = cohortId) |>
        dplyr::pull(sql)

      private$.writeSqlFile(definition = definition,
                            templateSql = templateSql)

      private$.addDependency(definition = definition)

      private$.commitToManifest(definition = definition)
    },
    .addSqlTemplateDefinition = function(definition) {

      sql <- SqlRender::readSql(sourceFile = definition$thisItem$relativeSqlPath)

      cohortDefinitionSet <- self$asCohortDefinitionSet |>
        CohortGenerator::addSqlCohortDefinition(sql = sql,
                                                cohortId = definition$thisItem$cohortId,
                                                cohortName = definition$thisItem$name)

      templateSql <- cohortDefinitionSet |>
        dplyr::slice_max(n = 1, order_by = cohortId) |>
        dplyr::pull(sql)

      private$.writeSqlFile(definition = definition,
                            templateSql = templateSql)

      if (!is.null(definition$dependentItemIds)) {
        private$.addDependency(definition = definition)
      }

      .commitToManifest(definition = definition)
    },
    .addSubsetDefinition = function(definition) {

      # TODO: handle the R file path location into where we want it

      # rReady <- private$.checkRNeedsWriting(definition = definition)
      #
      # if (!rReady) {
      #   private$.writeRFile(definition = definition)
      # }

      subsetDefinition <- (source(file = definition$thisItem$relativeRPath))$value
      subsetDefinition$identifierExpression <- glue::glue("{newCohortId}")

      checkmate::assertClass(subsetDefinition, classes = "CohortSubsetDefinition")
      checkmate::assert(setdiff(x = definition$dependentItemIds, y = subsetDefinition$definitionId))
                        #msg = "Subset definition cannot have dependencies that are not in the manifest.")

      cohortDefinitionSet <- self$asCohortDefinitionSet |>
        CohortGenerator::addCohortSubsetDefinition(
          cohortSubsetDefintion = subsetDefinition,
          targetCohortIds = subsetDefinition$definitionId
        )

      templateSql <- cohortDefinitionSet |>
        dplyr::slice_max(n = 1, order_by = cohortId) |>
        dplyr::pull(sql)

      private$.writeSqlFile(definition = definition,
                            templateSql = templateSql)

      private$.addDependency(definition = definition)
      private$.commitToManifest(definition = definition)
    },
    .checkSqlNeedsWriting = function(definition) {
      thisCohortItem <- definition$thisItem
      initialSqlPath <- thisCohortItem$relativeSqlPath

      thisFileManifest <- self$manifestDb$fileManifest

      relativeSqlFolder <- fs::path(thisFileManifest$getRelativePath(
        manifestType = "Cohort",
        fileExtension = "sql"
      )) |>
        fs::dir_create()

      sqlFileName <- glue::glue("{thisCohortItem$name}")
      relativeSqlPath <- fs::path(relativeSqlFolder, sqlFileName, ext = "sql")

      # check if we have the sql file already and in the right place ---
      sqlReady <- FALSE

      if (!is.na(initialSqlPath)) {
        if (initialSqlPath == relativeSqlPath) {
          sqlReady <- TRUE
        }
      }

      return(sqlReady)
    },
    .writeRFile = function(definition) {

      rFileName <- glue::glue("{thisCohortItem$name}")

      relativeRPath <- fs::path(
        thisFileManifest$getRelativePath(
          manifestType = "Cohort",
          fileExtension = "R"
        ),
        sqlFileName,
        ext = "R"
      )

      fullSqlPath <- fs::path(here::here(), relativeSqlPath)
    },
    .writeSqlFile = function(definition,
                             templateSql = NA) {
      thisCohortItem <- definition$thisItem
      initialSqlPath <- thisCohortItem$relativeSqlPath
      initialJsonPath <- thisCohortItem$relativeJsonPath

      thisFileManifest <- self$manifestDb$fileManifest
      sqlFileName <- glue::glue("{thisCohortItem$name}")

      relativeSqlPath <- fs::path(
        thisFileManifest$getRelativePath(
          manifestType = "Cohort",
          fileExtension = "sql"
        ),
        sqlFileName,
        ext = "sql"
      )

      fullSqlPath <- fs::path(here::here(), relativeSqlPath)

      # obtain sql from the CIRCE json file ---

      if (!is.na(templateSql)) {
        sql <- templateSql
      } else if (!is.na(initialJsonPath)) {
        json <- readr::read_file(file = initialJsonPath)
        sql <- CirceR::buildCohortQuery(
          expression = CirceR::cohortExpressionFromJson(json),
          CirceR::createGenerateOptions(generateStats = TRUE)
        )
      } else if (definition$designMethod == "Capr") {
        source(file = initialRPath)
        checkmate::assert(exists("caprObject"))
        checkmate::assertClass(caprObject, classes = "Capr")
        json <- Capr::compile(object = caprObject)
        sql <- CirceR::buildCohortQuery(
          expression = CirceR::cohortExpressionFromJson(json),
          options = CirceR::createGenerateOptions(generateStats = FALSE)
        )
      } else {
        sql <- SqlRender::readSql(sourceFile = initialSqlPath)
      }

      SqlRender::writeSql(sql = sql, targetFile = fullSqlPath)

      definition$setFieldValue(
        fieldName = "relativeSqlPath",
        fieldValue = relativeSqlPath
      )
    },
    .commitToManifest = function(definition) {

      sqlReady <- private$.checkSqlNeedsWriting(definition = definition)

      if (!sqlReady) {
        private$.writeSqlFile(definition = definition)
      }

      newCohortId <- super$addManifestItem(
        manifestItem = definition
      )
    }
  )
)


# AnalysisManifest -----

AnalysisManifest <- R6::R6Class(
  classname = "AnalysisManifest",
  inherit = Manifest,

  ## public ----
  public = list(
    initialize = function(manifestDb) {
      super$initialize(manifestDb = manifestDb, manifestType = "Analysis")
    },
    addAnalysisManifestItem = function(definition) {
      thisManifestId <- super$addManifestItem(
        manifestItem = definition
      )
    },
    deprecateAnalysisId = function(manifestItemId) {
      super$deprecateManifestItemId(manifestItemId = manifestItemId)
    }
  )
)

# MigrateManifest -----

MigrateManifest <- R6::R6Class(
  classname = "MigrateManifest",
  inherit = Manifest,

  ## public ----
  public = list(
    initialize = function(manifestDb) {
      super$initialize(manifestDb = manifestDb, manifestType = "Migrate")
    },
    addMigrateManifestItem = function(definition) {
      thisManifestId <- super$addManifestItem(
        manifestItem = definition
      )
    },
    deprecateMigrateId = function(manifestItemId) {
      super$deprecateManifestItemId(manifestItemId = manifestItemId)
    }
  )
)
