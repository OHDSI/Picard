
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

      .setString(private = private, key = ".bearerToken", value = bearerToken)

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
#' Creates a \code{WebApiConnection} object using credentials from:
#' 1. **secrets.yml** (preferred) — uses the \code{atlas} key in your
#'    \code{~/.picard/secrets.yml} file (see \code{editSecrets()} and
#'    \code{setupKeyring()}).
#' 2. \code{.Renviron} — reads \code{atlasBaseUrl}, \code{atlasAuthMethod},
#'    \code{atlasUser}, \code{atlasPassword} environment variables.
#' 3. \code{keyring} — retrieves from the OS keyring directly (legacy).
#'
#' @param useKeyring Logical. If TRUE and no secrets.yml atlas key is found,
#'   retrieves credentials from the keyring package directly (legacy path).
#'   Default FALSE.
#' @param secretsFilePath Character. Path to secrets.yml. Default
#'   \code{"~/.picard/secrets.yml"}. Ignored if the file doesn't exist or
#'   has no \code{atlas} key.
#'
#' @details
#' The recommended workflow is to store Atlas credentials in
#' \code{~/.picard/secrets.yml} via \code{setupKeyring()} or \code{editSecrets()}.
#' The secrets.yml approach supports three credential formats:
#' - Plain strings, \code{!expr keyring::key_get(...)}, or \code{!expr Sys.getenv(...)}.
#'
#' @returns An R6 class of WebApiConnection containing the ATLAS WebAPI connection details
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Using secrets.yml (recommended)
#'   atlasCon <- getAtlasConnection()
#'
#'   # Using keyring directly (legacy)
#'   atlasCon <- getAtlasConnection(useKeyring = TRUE)
#' }
getAtlasConnection <- function(useKeyring = FALSE,
                                secretsFilePath = "~/.picard/secrets.yml") {

  # Try secrets.yml first (preferred path)
  atlasCreds <- tryCatch(
    getAtlasCredentials(secretsFilePath = secretsFilePath),
    error = function(e) NULL
  )

  if (!is.null(atlasCreds) &&
      !is.null(atlasCreds$baseUrl) &&
      !is.null(atlasCreds$user) &&
      !is.null(atlasCreds$password)) {
    atlasCon <- WebApiConnection$new(
      baseUrl = atlasCreds$baseUrl,
      authMethod = atlasCreds$authMethod %||% "ad",
      user = atlasCreds$user,
      password = atlasCreds$password
    )
    return(atlasCon)
  }

  # Fallback: useKeyring path (legacy)
  if (useKeyring) {
    if (!requireNamespace("keyring", quietly = TRUE)) {
      cli::cli_abort("keyring package is required. Install with: {.run install.packages('keyring')}")
    }

    cli::cli_inform("Retrieving Atlas credentials from keyring (service='picard')...")

    tryCatch({
      baseUrl <- keyring::key_get(service = "picard", username = "atlasBaseUrl")
      authMethod <- keyring::key_get(service = "picard", username = "atlasAuthMethod")
      user <- keyring::key_get(service = "picard", username = "atlasUser")
      password <- keyring::key_get(service = "picard", username = "atlasPassword")
    }, error = function(e) {
      cli::cli_abort(c(
        "Failed to retrieve Atlas credentials from keyring:",
        "x" = e$message,
        "i" = "Ensure credentials are stored with:",
        " " = "keyring::key_set(service = 'picard', username = 'atlasBaseUrl')"
      ))
    })
  } else {
    # Retrieve from .Renviron
    baseUrl <- Sys.getenv("atlasBaseUrl")
    authMethod <- Sys.getenv("atlasAuthMethod")
    user <- Sys.getenv("atlasUser")
    password <- Sys.getenv("atlasPassword")

    if (baseUrl == "" || authMethod == "" || user == "" || password == "") {
      cli::cli_abort(c(
        "Atlas credentials not found in .Renviron or secrets.yml",
        "i" = "Set credentials with: {.run editSecrets()}",
        "i" = "Or use .Renviron: {.run usethis::edit_r_environ()}",
        "i" = "View template with: {.run templateAtlasCredentials()}"
      ))
    }
  }

  atlasCon <- WebApiConnection$new(
    baseUrl = baseUrl,
    authMethod = authMethod,
    user = user,
    password = password
  )
  return(atlasCon)
}

#' Set Atlas Connection (Deprecated)
#'
#' @description
#' **Deprecated.** Use [getAtlasConnection()] instead.
#'
#' @param useKeyring Logical. Passed to [getAtlasConnection()].
#'
#' @return A WebApiConnection object.
#'
#' @export
setAtlasConnection <- function(useKeyring = FALSE) {
  lifecycle::deprecate_warn("0.0.3", "setAtlasConnection()", "getAtlasConnection()")
  getAtlasConnection(useKeyring = useKeyring)
}

pluckConceptSetExpression <- function(conceptSetId, baseUrl, bearerToken) {
  req <- paste0(baseUrl, "/conceptset/", conceptSetId, "/expression") |>
    httr2::request() |>
    httr2::req_auth_bearer_token(token = bearerToken)
  resp <- httr2::req_perform(req = req)
  csExp <- httr2::resp_body_json(resp)
  csExp2 <- RJSONIO::toJSON(csExp, digits = 23, pretty = TRUE)
  return(csExp2)
}


formatCohortExpression <- function(expression) {
  # reformat to standard circe
  circe <- list(
    'ConceptSets' = expression$ConceptSets,
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



