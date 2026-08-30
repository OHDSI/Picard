
# WebApiConnection ---------------------
WebApiConnection <- R6::R6Class(
  classname = "WebApiConnection",
  public = list(
    initialize = function(baseUrl, authMethod, user, password) {
      # check baseUrl
      checkmate::assert_string(x = baseUrl, min.chars = 1)
      private[[".baseUrl"]] <- baseUrl
      # check authMethod
      checkmate::assert_string(x = authMethod, min.chars = 1)
      private[[".authMethod"]] <- authMethod
      # check user
      checkmate::assert_string(x = user, min.chars = 1)
      private[[".user"]] <- user
      # check user
      checkmate::assert_string(x = password, min.chars = 1)
      private[[".password"]] <- password
    },

    checkUser = function() {
      usr <- private$.user
      cli::cli_bullets(c("v" = "user: {.val {usr}}"))
      invisible(usr)
    },

    checkPassword = function() {
      pwd <- private$.password
      cli::cli_bullets(c("v" = "password: ********"))
      invisible(pwd)
    },

    checkBaseUrl = function() {
      baseUrl <- private$.baseUrl
      cli::cli_bullets(c("v" = "baseUrl: {.url {baseUrl}}"))
      invisible(baseUrl)
    },

    checkAuthMethod = function() {
      am <- private$.authMethod
      cli::cli_bullets(c("v" = "authMethod: {.val {am}}"))
      invisible(am)
    },

    getWebApiUrl = function() {
      baseUrl <- private$.baseUrl
      return(baseUrl)
    },

    checkAtlasCredentials = function() {

      cli::cli_rule("Checking Atlas Credentials from {.path .Renviron}")
      cli::cli_text("")

      self$checkBaseUrl()
      self$checkAuthMethod()
      self$checkUser()
      self$checkPassword()

      cli::cli_text("")
      cli::cli_bullets(c(
        "*" = "To modify credentials run {.fn usethis::edit_r_environ} and change system variables for Atlas credentials"
      ))

    },

    getCohortDefinition = function(cohortId) {

      if (is.null(private$.bearerToken)) {
        private$authorizeWebApi()
      }
      baseUrl <- private$.baseUrl
      req <- paste0(baseUrl, "/cohortdefinition/", cohortId) |>
        httr2::request() |>
        httr2::req_auth_bearer_token(token = private$.bearerToken)
      resp <- httr2::req_perform(req = req)
      cd <- httr2::resp_body_json(resp)
      cdExp <- RJSONIO::fromJSON(cd$expression, nullValue = NA, digits = 23)

      tb <- tibble::tibble(
        id = cd$id,
        name = cd$name,
        expression = formatCohortExpression(cdExp),
        saveName = paste0(cd$id, "_", cd$name) |> snakecase::to_snake_case()
      )

      return(tb)
    },

    getConceptSetDefinition = function(conceptSetId) {

      if (is.null(private$.bearerToken)) {
        private$authorizeWebApi()
      }
      baseUrl <- private$.baseUrl
      req <- paste0(baseUrl, "/conceptset/", conceptSetId) |>
        httr2::request() |>
        httr2::req_auth_bearer_token(token = private$.bearerToken)
      resp <- httr2::req_perform(req = req)
      cs <- httr2::resp_body_json(resp)

      # get the expression from the right spot
      csExp <- pluckConceptSetExpression(
        conceptSetId = conceptSetId,
        baseUrl = baseUrl,
        bearerToken = private$.bearerToken
      )

      tb <- tibble::tibble(
        id = cs$id,
        name = cs$name,
        expression = csExp,
        saveName = paste0(cs$id, "_", cs$name) |> snakecase::to_snake_case()
      )

      return(tb)
    }

  ),
  private = list(
    .baseUrl = NULL,
    .authMethod = NULL,
    .user = NULL,
    .password = NULL,
    .bearerToken = NULL,

    # functions
    authorizeWebApi = function() {

      baseUrl <- private$.baseUrl
      authMethod <- private$.authMethod
      user <- private$.user
      password <- private$.password

      cli::cli_alert_info("Authorizing Web API connection for {.url {baseUrl}}")

      authUrl <- paste0(baseUrl, "/user/login/", authMethod)

      req <- httr2::request(authUrl) |>
        httr2::req_body_form(
          login = user,
          password = password
        )

      bearerToken <- httr2::req_perform(req)$headers$Bearer

      checkmate::assert_string(x = bearerToken, min.chars = 1, null.ok = TRUE)
      private[[".bearerToken"]] <- bearerToken

      invisible(bearerToken)
    }
  )
)


CirceCohortsToLoad <- R6::R6Class(
  classname = "CirceCohortsToLoad",
  public = list(
    initialize = function(cohortsToLoadTable,
                          webApiCreds) {
      # check and init cohortsToLoadTable
      checkmate::assert_data_frame(
        x = cohortsToLoadTable,
        min.rows = 1,
        ncols = 3
      )
      private[[".cohortsToLoadTable"]] <- cohortsToLoadTable

      # check webApi creds
      checkmate::assert_class(x = webApiCreds, classes = "WebApiCreds")
      private[[".webApiCreds"]] <- webApiCreds
    },

    getCirce = function() {

      private$.webApiCreds$authorizeWebApi()
      circeIds <- private$.cohortsToLoadTable$atlasId
      circeTb <- vector('list', length = length(circeIds))
      for (i in seq_along(circeIds)) {
        circeTb[[i]] <- grabCohortFromWebApi(
          cohortId = circeIds[i],
          baseUrl = private$.webApiCreds$getWebApiUrl()
        )
      }
      circeTb2 <- do.call('rbind', circeTb)
      circeTb3 <- private$.cohortsToLoadTable |>
        dplyr::left_join(
          circeTb2, by = c('atlasId' = "id")
        ) |>
        dplyr::mutate(
          savePath = fs::path("inputs/cohorts/json", analysisType, saveName, ext = "json")
        ) |>
        dplyr::select(
          atlasId, assetLabel, analysisType, expression, saveName, savePath
        )

      return(circeTb3)
    }


  ),
  private = list(
    .webApiCreds = NULL,
    .cohortsToLoadTable = NULL
  ),
  active = list(
    cohortsToLoadTable = function(value) {
      if(missing(value)) {
        res <- private$.cohortsToLoadTable
        return(res)
      }
      checkmate::assert_data_frame(
        x = value,
        min.rows = 1,
        ncols = 3
      )
      private[[".cohortsToLoadTable"]] <- value

      cli::cli_alert_success("Replaced {.field cohortsToLoadTable}")
    }
  )
)


CirceConceptSetsToLoad <- R6::R6Class(
  classname = "CirceConceptSetsToLoad",
  public = list(
    initialize = function(conceptSetsToLoadTable,
                          webApiCreds) {
      # check and init cohortsToLoadTable
      checkmate::assert_data_frame(
        x = conceptSetsToLoadTable,
        min.rows = 1,
        ncols = 3
      )
      private[[".conceptSetsToLoadTable"]] <- conceptSetsToLoadTable

      # check webApi creds
      checkmate::assert_class(x = webApiCreds, classes = "WebApiCreds")
      private[[".webApiCreds"]] <- webApiCreds
    },

    getCirce = function() {

      private$.webApiCreds$authorizeWebApi()
      circeIds <- private$.conceptSetsToLoadTable$atlasId
      circeTb <- vector('list', length = length(circeIds))
      for (i in seq_along(circeIds)) {
        circeTb[[i]] <- grabConceptSetFromWebApi(
          conceptSetId = circeIds[i],
          baseUrl = private$.webApiCreds$getWebApiUrl()
        )
      }
      circeTb2 <- do.call('rbind', circeTb)
      circeTb3 <- private$.conceptSetsToLoadTable |>
        dplyr::left_join(
          circeTb2, by = c('atlasId' = "id")
        ) |>
        dplyr::mutate(
          savePath = fs::path("inputs/conceptSets/json", analysisType, saveName, ext = "json")
        ) |>
        dplyr::select(
          atlasId, assetLabel, analysisType, expression, saveName, savePath
        )

      return(circeTb3)
    }


  ),
  private = list(
    .webApiCreds = NULL,
    .conceptSetsToLoadTable = NULL
  ),
  active = list(
    conceptSetsToLoadTable = function(value) {
      if(missing(value)) {
        res <- private$.conceptSetsToLoadTable
        return(res)
      }
      checkmate::assert_data_frame(
        x = value,
        min.rows = 1,
        ncols = 3
      )
      private[[".conceptSetsToLoadTable"]] <- value

      cli::cli_alert_success("Replaced {.field conceptSetsToLoadTable}")
    }
  )
)

# Atlas Connection ---------------

#' Get Atlas Connection
#'
#' @description
#' Creates a \code{WebApiConnection} object using credentials from secrets.yml
#'
#' @param secretsFilePath Character. Path to secrets.yml. Default
#'   \code{"~/.picard/secrets.yml"}. 
#'
#' @details
#' Store Atlas credentials in
#' \code{~/.picard/secrets.yml} via \code{setupAtlasSecretsKeyring()} or \code{editSecrets()}.
#' The secrets.yml approach supports three credential formats:
#' - Plain strings, \code{!expr keyring::key_get(...)}, or \code{!expr Sys.getenv(...)}.
#'
#' @returns An R6 class of WebApiConnection containing the ATLAS WebAPI connection details
#'
#' @export
getAtlasConnection <- function(secretsFilePath = "~/.picard/secrets.yml") {

  # Try secrets.yml first (preferred path)
  atlasCreds <- getAtlasCredentials(secretsFilePath = secretsFilePath)

  atlasCon <- WebApiConnection$new(
      baseUrl = atlasCreds$baseUrl,
      authMethod = atlasCreds$authMethod,
      user = atlasCreds$user,
      password = atlasCreds$password
    )
    return(atlasCon)
}

pluckConceptSetExpression <- function(conceptSetId, baseUrl, bearerToken) {
  req <- paste0(baseUrl, "/conceptset/", conceptSetId, "/expression") |>
    httr2::request() |>
    httr2::req_auth_bearer_token(token = bearerToken)
  resp <- httr2::req_perform(req = req)
  csExp <- httr2::resp_body_json(resp)
  csExp2 <- RJSONIO::toJSON(
    canonicalize_concept_set_expression(csExp),
    digits = 23,
    pretty = TRUE
  )
  return(csExp2)
}

# ATLAS returns the concepts of a concept set in a nondeterministic order, so an
# unchanged definition can serialize to a different JSON string on every fetch.
# That churns the on-disk JSON file, its content hash and therefore the manifest
# sqlite file, which then shows up as an uncommitted change in git. Ordering the
# concepts by a stable key makes the fetch reproducible. A concept set
# expression is a set of items — reordering them does not change its meaning,
# and circe resolves concept sets by `id`, not by position.

# Safely read a named element from a parsed JSON node, which RJSONIO/httr2 may
# hand back as either a named list or a named atomic vector.
pluck_json_field <- function(x, name) {
  if (is.null(x) || is.null(names(x)) || !(name %in% names(x))) {
    return(NULL)
  }
  x[[name]]
}

# Build the sort key for one concept set item. CONCEPT_ID is the primary key,
# zero-padded so it sorts numerically; vocabulary, code and the inclusion flags
# break ties so items that share a concept still order deterministically.
concept_set_item_key <- function(item) {
  concept <- pluck_json_field(item, "concept")

  conceptField <- function(name) {
    value <- pluck_json_field(concept, name)
    if (is.null(value) || length(value) != 1 || is.na(value)) "" else as.character(value)
  }

  itemFlag <- function(name) {
    if (isTRUE(pluck_json_field(item, name))) "1" else "0"
  }

  rawId <- conceptField("CONCEPT_ID")
  numericId <- suppressWarnings(as.numeric(rawId))
  idKey <- if (is.na(numericId)) paste0("z", rawId) else sprintf("%020.0f", numericId)

  paste(
    idKey,
    conceptField("VOCABULARY_ID"),
    conceptField("CONCEPT_CODE"),
    itemFlag("isExcluded"),
    itemFlag("includeDescendants"),
    itemFlag("includeMapped"),
    sep = "|"
  )
}

# Sort the `items` of a concept set expression by concept, leaving every other
# element of the expression untouched.
canonicalize_concept_set_expression <- function(expression) {
  items <- pluck_json_field(expression, "items")

  if (!is.list(items) || length(items) < 2) {
    return(expression)
  }

  keys <- vapply(items, concept_set_item_key, character(1))
  expression[["items"]] <- items[order(keys, method = "radix")]
  expression
}

# Canonicalize the ConceptSets block of a circe cohort expression: sort each
# concept set's items, then order the concept sets by their circe id.
canonicalize_circe_concept_sets <- function(conceptSets) {
  if (!is.list(conceptSets) || length(conceptSets) == 0) {
    return(conceptSets)
  }

  conceptSets <- lapply(conceptSets, function(conceptSet) {
    if (!is.list(conceptSet)) {
      return(conceptSet)
    }
    expression <- pluck_json_field(conceptSet, "expression")
    if (!is.null(expression)) {
      conceptSet[["expression"]] <- canonicalize_concept_set_expression(expression)
    }
    conceptSet
  })

  ids <- vapply(conceptSets, function(conceptSet) {
    id <- pluck_json_field(conceptSet, "id")
    if (is.null(id) || length(id) != 1) {
      return(NA_real_)
    }
    suppressWarnings(as.numeric(id))
  }, numeric(1))

  # Without a usable id on every concept set, leave the order alone rather than
  # risk reordering against the codeset references in the cohort expression
  if (anyNA(ids)) {
    return(conceptSets)
  }

  conceptSets[order(ids)]
}


formatCohortExpression <- function(expression) {
  # reformat to standard circe
  circe <- list(
    'ConceptSets' = canonicalize_circe_concept_sets(expression$ConceptSets),
    'PrimaryCriteria' = expression$PrimaryCriteria,
    'AdditionalCriteria' = expression$AdditionalCriteria,
    'QualifiedLimit' = expression$QualifiedLimit,
    'ExpressionLimit' = expression$ExpressionLimit,
    'InclusionRules' = expression$InclusionRules,
    'EndStrategy' = expression$EndStrategy,
    'CensoringCriteria' = expression$CensoringCriteria,
    'CollapseSettings' = expression$CollapseSettings,
    'CensorWindow' = expression$CensorWindow,
    'cdmVersionRange' = expression$cdmVersionRange
  )
  if (is.null(circe$AdditionalCriteria)) {
    circe$AdditionalCriteria <- NULL
  }
  if (is.null(circe$EndStrategy)) {
    circe$EndStrategy <- NULL
  }

  circeJson <- RJSONIO::toJSON(circe, digits = 23, pretty = TRUE)

  return(circeJson)
}



#' @title Template for setting Atlas Credentials
#' @returns no return; prints info to console
#' @export
templateAtlasCredentials <- function() {

  credsToSetTxt <- paste0(
    "atlasBaseUrl='https://organization-atlas.com/WebAPI'\n",
    "atlasAuthMethod='ad'\n",
    "atlasUser='atlas.user@company.com'\n",
    "atlasPassword='TisASecret'"
  )

  cli::cli_rule("Atlas Credential Template")
  cli::cli_text("")
  cli::cli_bullets(c(
    "i" = "Template for setting Atlas Credentials. Please alter to the correct credentials!"
  ))
  cli::cli_bullets(c(
    "*" = "To set Atlas Credentials run {.fn usethis::edit_r_environ} and paste the template to {.path .Renviron} changing the credentials accordingly."
  ))
  cli::cli_alert_warning("The variable names of the atlas credentials must be in this exact format!")
  cli::cli_text("")
  cli::cli_code(credsToSetTxt)

  invisible(credsToSetTxt)
}





getAtlasAuthBearerToken <- function(baseUrl, authMethod, user, password) {

  authUrl <- paste0(baseUrl, "/user/login/", authMethod)

  req <- httr2::request(authUrl) |>
    httr2::req_body_form(
      login = user,
      password = password
    )

  bearerToken <- httr2::req_perform(req)$headers$Bearer

  return(bearerToken)
}



