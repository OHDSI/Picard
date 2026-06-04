# secrets.R ----
# Secrets file handling for Picard: read, resolve, validate, edit, and set up
# keyring-based credentials. All database credentials live in a user-level
# secrets.yml (default ~/.picard/secrets.yml) — never in the repo.

# ============================================================================
# Internal helpers
# ============================================================================

#' Resolve a single secret value
#'
#' If the value is a plain string (no `!expr` prefix), return it as-is.
#' If it starts with `!expr `, strip the prefix and evaluate the remaining R
#' expression using `rlang::eval_tidy()`. This supports any valid R expression:
#' `keyring::key_get(...)`, `Sys.getenv(...)`, custom functions, etc.
#'
#' @param value A single value from a parsed secrets YAML file.
#' @return The resolved value (plain string or evaluated expression result).
#' @keywords internal
resolveSecretValue <- function(value) {
  if (!is.character(value) || length(value) != 1) {
    return(value)
  }

  expr_prefix <- "!expr "
  if (startsWith(value, expr_prefix)) {
    expr_str <- substr(value, nchar(expr_prefix) + 1, nchar(value))
    result <- tryCatch(
      rlang::eval_tidy(rlang::parse_expr(expr_str)),
      error = function(e) {
        cli::cli_abort("Failed to evaluate secrets expression: {.val {expr_str}}\nError: {e$message}")
      }
    )
    return(result)
  }

  value
}

# ============================================================================
# Reading and resolving
# ============================================================================

#' Read a secrets YAML file
#'
#' Reads a secrets.yml file using `yaml::read_yaml` with `eval.expr = FALSE`,
#' so `!expr` tags are preserved as raw strings for [resolveSecretValue()] to
#' evaluate later. Returns a named list keyed by dbServer names (plus optional
#' `atlas` key).
#'
#' @param secretsFilePath Character. Path to the secrets.yml file.
#' @return A named list of server credential blocks.
#' @keywords internal
readSecrets <- function(secretsFilePath) {
  
  if (!file.exists(secretsFilePath)) {
    cli::cli_abort("Secrets file not found: {.path {secretsFilePath}}")
  }

  tryCatch(
    yaml::read_yaml(secretsFilePath, eval.expr = FALSE),
    error = function(e) {
      cli::cli_abort("Failed to parse secrets file {.path {secretsFilePath}}: {e$message}")
    }
  )
}

#' Get credentials for a database server
#'
#' Looks up a `dbServer` entry in secrets.yml and resolves all its credential
#' fields via [resolveSecretValue()].
#'
#' @param dbServer Character. The database server name to look up.
#' @param secretsFilePath Character. Path to the secrets.yml file. Default to ~/.picard/secrets.yml
#' @return A named list with resolved credential values (`dbms`, `user`,
#'   `password`, `server`, `port`, `connectionString`, `extraSettings`).
#'   Missing optional fields are silently omitted.
#' @keywords internal
getServerCredentials <- function(dbServer, secretsFilePath = "~/.picard/secrets.yml") {
  
  secretsFilePath <- fs::path_expand(secretsFilePath)
  secrets <- readSecrets(secretsFilePath)

  if (is.null(secrets[[dbServer]])) {
    cli::cli_abort("Server {.val {dbServer}} not found in secrets file {.path {secretsFilePath}}")
  }

  serverEntry <- secrets[[dbServer]]

  # Fields that may appear in a server entry
  credentialFields <- c("dbms", "user", "password", "server", "port",
                        "connectionString", "extraSettings")

  result <- list()
  for (field in credentialFields) {
    if (!is.null(serverEntry[[field]])) {
      result[[field]] <- resolveSecretValue(serverEntry[[field]])
    }
  }

  return(result)
}

#' Get Atlas/WebAPI credentials from secrets.yml
#'
#' Looks up the `atlas` top-level key in secrets.yml and resolves the credential
#' fields via [resolveSecretValue()].
#'
#' @param secretsFilePath Character. Path to the secrets.yml file.
#' @return A named list with `baseUrl`, `authMethod`, `user`, `password`, or
#'   NULL if no `atlas` key is present.
#' @keywords internal
getAtlasCredentials <- function(secretsFilePath = "secrets.yml") {
  if (!file.exists(secretsFilePath)) {
    return(NULL)
  }

  secrets <- tryCatch(
    yaml::read_yaml(secretsFilePath, eval.expr = FALSE),
    error = function(e) NULL
  )

  if (is.null(secrets) || is.null(secrets[["atlas"]])) {
    return(NULL)
  }

  atlasEntry <- secrets[["atlas"]]
  atlasFields <- c("baseUrl", "authMethod", "user", "password")

  result <- list()
  for (field in atlasFields) {
    if (!is.null(atlasEntry[[field]])) {
      result[[field]] <- resolveSecretValue(atlasEntry[[field]])
    }
  }

  result
}

#' Get credentials for a config block
#'
#' Convenience function: reads the config block from config.yml, extracts its
#' `dbServer` field, then calls [getServerCredentials()].
#'
#' @param configBlock Character. The config block name.
#' @param configFilePath Character. Path to config.yml.
#' @param secretsFilePath Character. Path to secrets.yml.
#' @return A named list of resolved credential values.
#' @keywords internal
getBlockCredentials <- function(configBlock,
                                configFilePath,
                                secretsFilePath = "secrets.yml") {
  blockConfig <- config::get(config = configBlock, file = configFilePath)
  # if the dbServer is null default to the configBlock 
  if (is.null(blockConfig$dbServer)) {
    dbServer <- configBlock
   } else {
    dbServer <- blockConfig$dbServer
   }

  getServerCredentials(dbServer, secretsFilePath)
}

# ============================================================================
# Validation
# ============================================================================

#' Validate a secrets.yml file
#'
#' Checks that the secrets file exists, is parseable by `yaml::read_yaml`, and
#' has a top-level entry for each `dbServer` name. Each server entry requires
#' `dbms`; then either `connectionString` (Snowflake) or `server` + `port` +
#' `user` + `password` (other DBMS). If an `atlas` entry is present, requires
#' `baseUrl`, `authMethod`, `user`, `password`.
#'
#' @param secretsFilePath Character. Path to secrets.yml.
#' @param dbServerNames Character vector. Expected server names.
#' @return Invisibly returns TRUE if valid. Stops with errors otherwise.
#' @keywords internal
validateSecretsYaml <- function(secretsFilePath, dbServerNames) {
  secretsFilePath <- fs::path_expand(secretsFilePath)
  if (!file.exists(secretsFilePath)) {
    cli::cli_abort("Secrets file not found: {.path {secretsFilePath}}")
  }

  cli::cli_alert_info("Validating secrets file: {.path {secretsFilePath}}")

  secrets <- tryCatch(
    yaml::read_yaml(secretsFilePath, eval.expr = FALSE),
    error = function(e) {
      cli::cli_abort("Failed to parse secrets file: {e$message}")
    }
  )

  # Check each expected server
  for (svr in dbServerNames) {
    if (is.null(secrets[[svr]])) {
      cli::cli_abort("Server {.val {svr}} not found in secrets file")
    }

    entry <- secrets[[svr]]

    if (is.null(entry$dbms)) {
      cli::cli_abort("Server {.val {svr}} is missing {.field dbms}")
    }

    dbms <- tolower(as.character(entry$dbms))

    if (dbms == "snowflake") {
      if (is.null(entry$connectionString)) {
        cli::cli_abort("Snowflake server {.val {svr}} requires {.field connectionString}")
      }
    } else {
      if (is.null(entry$server)) {
        cli::cli_abort("Server {.val {svr}} ({dbms}) requires {.field server}")
      }
      if (is.null(entry$port)) {
        cli::cli_abort("Server {.val {svr}} ({dbms}) requires {.field port}")
      }
      if (is.null(entry$user)) {
        cli::cli_abort("Server {.val {svr}} ({dbms}) requires {.field user}")
      }
      if (is.null(entry$password)) {
        cli::cli_abort("Server {.val {svr}} ({dbms}) requires {.field password}")
      }
    }
  }

  # Optional: validate atlas entry if present
  if (!is.null(secrets[["atlas"]])) {
    atlasEntry <- secrets[["atlas"]]
    atlasRequired <- c("baseUrl", "authMethod", "user", "password")
    for (field in atlasRequired) {
      if (is.null(atlasEntry[[field]])) {
        cli::cli_abort("Atlas entry in secrets file is missing {.field {field}}")
      }
    }
  }

  cli::cli_alert_success("Secrets validation successful!")
  cli::cli_bullets(c(
    "v" = "{length(dbServerNames)} server(s) validated",
    "v" = "All required credential fields present"
  ))

  invisible(TRUE)
}

# ============================================================================
# Editing and setup
# ============================================================================

#' Edit the secrets.yml file
#'
#' Opens the secrets file in the user's editor (like `usethis::edit_r_environ()`).
#' If the file doesn't exist, creates a skeleton first with optional server
#' placeholders and an optional Atlas section, then opens it.
#'
#' @param secretsFilePath Character. Path to the secrets.yml file. Default
#'   `"~/.picard/secrets.yml"` — the canonical user-level location outside
#'   any git repo.
#' @param dbServerNames Character vector. Optional unique server names to
#'   include in the skeleton. Each gets a template entry with commented-out
#'   credential placeholders.
#' @param atlas Logical. If TRUE, include a commented-out Atlas credentials
#'   section in the skeleton. Default is TRUE
#' @return Invisibly returns the file path.
#' @export
editSecrets <- function(secretsFilePath = "~/.picard/secrets.yml",
                        dbServerNames = NULL,
                        atlas = TRUE) {
  secretsFilePath <- fs::path_expand(secretsFilePath)

  if (!file.exists(secretsFilePath)) {
    # Create parent directory
    fs::dir_create(fs::path_dir(secretsFilePath))

    # Read the header template
    header <- tryCatch(
      fs::path_package("picard", "templates/secretsHeader.txt") |>
        readr::read_file(),
      error = function(e) "# secrets.yml — Database & Atlas Credentials\n"
    )

    # Build server entries
    serverEntries <- character(0)
    if (!is.null(dbServerNames) && length(dbServerNames) > 0) {
      uniqueServers <- unique(dbServerNames)
      for (svr in uniqueServers) {
        serverEntries <- c(serverEntries, sprintf(
          "\n%s:\n  dbms: \"\"\n  # connectionString: \"\"  # uncomment for Snowflake\n  # server: \"\"           # uncomment for other DBMS\n  # port: \"\"             # uncomment for other DBMS\n  user: \"\"\n  password: \"\"\n  # extraSettings:  # optional",
          svr
        ))
      }
    }

    # Build atlas section
    atlasSection <- if (atlas) {
      sprintf(
        "\n\n# OHDSI Atlas/WebAPI credentials (used by getAtlasConnection)\n# atlas:\n#   baseUrl: \"https://atlas.example.com/WebAPI\"\n#   authMethod: \"ad\"\n#   user: \"\"\n#   password: \"\"\n"
      )
    } else {
      ""
    }

    content <- paste0(header,
                      paste0(serverEntries, collapse = ""),
                      atlasSection,
                      "\n")

    readr::write_file(x = content, file = secretsFilePath)
    cli::cli_alert_success("Created secrets file: {.path {secretsFilePath}}")
  }

  # Open for editing
  usethis::edit_file(secretsFilePath)
  cli::cli_alert_info("Edit {.path {secretsFilePath}} with your credentials, then save and close.")

  invisible(secretsFilePath)
}

#' Set up keyring-based credentials
#'
#' Interactively prompts for credentials using `keyring::key_set()` dialogs,
#' then writes a secrets.yml skeleton with `!expr keyring::key_get(...)`
#' references. This is the most secure workflow — credentials never appear
#' in plain text on disk.
#'
#' @param dbServerNames Character vector. Server names to set up (e.g.,
#'   `c("snowflake_prod", "redshift_jmdc")`).
#' @param secretsFilePath Character. Path to the secrets.yml file to write.
#'   Default `"~/.picard/secrets.yml"`.
#' @param atlas Logical. If TRUE, also prompt for Atlas credentials.
#' @return Invisibly returns the secrets file path.
#' @export
setupKeyring <- function(dbServerNames,
                         secretsFilePath = "~/.picard/secrets.yml",
                         atlas = FALSE) {
  if (!requireNamespace("keyring", quietly = TRUE)) {
    cli::cli_abort("keyring package is required. Install with: {.run install.packages('keyring')}")
  }

  secretsFilePath <- fs::path_expand(secretsFilePath)
  fs::dir_create(fs::path_dir(secretsFilePath))

  cli::cli_h2("Setting up keyring credentials")

  serverLines <- character(0)

  for (svr in unique(dbServerNames)) {
    cli::cli_h3("Server: {.val {svr}}")

    # Prompt for dbms
    keyring::key_set(service = "picard", username = paste0(svr, "_dbms"))
    dbms_val <- keyring::key_get("picard", paste0(svr, "_dbms"))

    # Build the entry — ask for connectionString (snowflake) or server/port
    if (tolower(dbms_val) == "snowflake") {
      keyring::key_set(service = "picard", username = paste0(svr, "_connectionString"))
      keyring::key_set(service = "picard", username = paste0(svr, "_user"))
      keyring::key_set(service = "picard", username = paste0(svr, "_password"))
    } else {
      keyring::key_set(service = "picard", username = paste0(svr, "_server"))
      keyring::key_set(service = "picard", username = paste0(svr, "_port"))
      keyring::key_set(service = "picard", username = paste0(svr, "_user"))
      keyring::key_set(service = "picard", username = paste0(svr, "_password"))
    }

    serverLines <- c(serverLines, sprintf(
      "\n%s:\n  dbms: !expr keyring::key_get(\"picard\", \"%s_dbms\")\n  user: !expr keyring::key_get(\"picard\", \"%s_user\")\n  password: !expr keyring::key_get(\"picard\", \"%s_password\")",
      svr, svr, svr, svr
    ))
  }

  # Atlas
  atlasSection <- ""
  if (atlas) {
    cli::cli_h3("Atlas/WebAPI credentials")
    keyring::key_set(service = "picard", username = "atlas_baseUrl")
    keyring::key_set(service = "picard", username = "atlas_authMethod")
    keyring::key_set(service = "picard", username = "atlas_user")
    keyring::key_set(service = "picard", username = "atlas_password")

    atlasSection <- sprintf(
      "\n\natlas:\n  baseUrl: !expr keyring::key_get(\"picard\", \"atlas_baseUrl\")\n  authMethod: !expr keyring::key_get(\"picard\", \"atlas_authMethod\")\n  user: !expr keyring::key_get(\"picard\", \"atlas_user\")\n  password: !expr keyring::key_get(\"picard\", \"atlas_password\")"
    )
  }

  # Write the secrets file
  header <- tryCatch(
    fs::path_package("picard", "templates/secretsHeader.txt") |>
      readr::read_file(),
    error = function(e) "# secrets.yml\n"
  )

  content <- paste0(header,
                    paste0(serverLines, collapse = ""),
                    atlasSection,
                    "\n")
  readr::write_file(x = content, file = secretsFilePath)

  cli::cli_alert_success("Keyring credentials stored and secrets file created: {.path {secretsFilePath}}")

  # Open for review
  editSecrets(secretsFilePath)

  invisible(secretsFilePath)
}
