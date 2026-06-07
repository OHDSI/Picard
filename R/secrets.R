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
#' `user` + `password` (other DBMS). 
#'
#' If credentials are stored via [setupDbSecretsKeyring()], fields may contain
#' `!expr keyring::key_get(...)` expressions. Validation checks for the presence
#' of required fields but cannot fully validate the DBMS type or expression
#' validity when using keyring-based credentials (that validation happens at
#' credential resolution time).
#'
#' If an `atlas` entry is present, requires `baseUrl`, `authMethod`, `user`,
#' `password`.
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

    # Check if dbms is an expression (from keyring) or plain value
    dbms_value <- as.character(entry$dbms)
    is_expr <- startsWith(dbms_value, "!expr ")

    if (is_expr) {
      # Can't validate expression values, just check field presence
      if (is.null(entry$connectionString) && is.null(entry$server)) {
        cli::cli_warn(
          "Server {.val {svr}} has {.field dbms} as expression but no {.field connectionString} or {.field server} field.",
          "Cannot fully validate keyring-based credentials."
        )
      }
      if (is.null(entry$user)) {
        cli::cli_abort("Server {.val {svr}} is missing {.field user}")
      }
      if (is.null(entry$password)) {
        cli::cli_abort("Server {.val {svr}} is missing {.field password}")
      }
    } else {
      # Plain text value - validate DBMS type and fields
      dbms <- tolower(dbms_value)

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
#' If the file doesn't exist, creates a minimal skeleton with just a header comment,
#' then opens it for editing.
#'
#' @param secretsFilePath Character. Path to the secrets.yml file. Default
#'   `"~/.picard/secrets.yml"` — the canonical user-level location outside
#'   any git repo.
#' @return Invisibly returns the file path.
#' @export
editSecrets <- function(secretsFilePath = "~/.picard/secrets.yml") {
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

    readr::write_file(x = header, file = secretsFilePath)
    cli::cli_alert_success("Created secrets file: {.path {secretsFilePath}}")
  }

  # Open for editing
  usethis::edit_file(secretsFilePath)
  cli::cli_alert_info("Edit {.path {secretsFilePath}} with your credentials, then save and close.")

  invisible(secretsFilePath)
}

#' Set up keyring-based credentials for a database server
#'
#' Interactively prompts for credentials using `keyring::key_set()` dialogs,
#' then writes a secrets.yml entry with `!expr keyring::key_get(...)`
#' references. This is the most secure workflow — credentials never appear
#' in plain text on disk.
#'
#' If the secrets file already exists, the new server entry is appended rather than
#' overwriting. This allows adding new database servers to an existing configuration.
#' For Atlas credentials, use [setupAtlasSecretsKeyring()] separately.
#'
#' @param dbServerName Character. The database server name to set up (e.g.,
#'   `"snowflake_prod"` or `"redshift_jmdc"`).
#' @param dbmsVal Character. The dbms value, could be snowflake, redshift, postgres
#' @param secretsFilePath Character. Path to the secrets.yml file to write.
#'   Default `"~/.picard/secrets.yml"`.
#' @return Invisibly returns the secrets file path.
#' @export
setupDbSecretsKeyring <- function(dbServerName, dbmsVal, 
                         secretsFilePath = "~/.picard/secrets.yml") {
  if (!requireNamespace("keyring", quietly = TRUE)) {
    cli::cli_abort("keyring package is required. Install with: {.run install.packages('keyring')}")
  }

  secretsFilePath <- fs::path_expand(secretsFilePath)
  fs::dir_create(fs::path_dir(secretsFilePath))

  cli::cli_h2("Setting up keyring credentials in .picard/secrets.yml")
  cli::cli_h3("Server: {.val {dbServerName}}")

  # Always store dbms in keyring first
  keyring::key_set(service = "picard", username = paste0(dbServerName, "_dbms"), prompt = paste0("DBMS [{dbmsVal}]: "), password = dbmsVal)

  # Build the entry — ask for connectionString (snowflake) or server/port
  if (tolower(dbmsVal) == "snowflake") {
    keyring::key_set(service = "picard", username = paste0(dbServerName, "_connectionString"), prompt = "ConnectionString: ")
    keyring::key_set(service = "picard", username = paste0(dbServerName, "_user"), prompt = "User: ")
    keyring::key_set(service = "picard", username = paste0(dbServerName, "_password"), prompt = "Password: ")

    serverLines <- sprintf(
      "\n%s:\n  dbms: !expr keyring::key_get(\"picard\", \"%s_dbms\")\n  connectionString: !expr keyring::key_get(\"picard\", \"%s_connectionString\")\n  user: !expr keyring::key_get(\"picard\", \"%s_user\")\n  password: !expr keyring::key_get(\"picard\", \"%s_password\")",
      dbServerName, dbServerName, dbServerName, dbServerName, dbServerName
    )
  } else {
    keyring::key_set(service = "picard", username = paste0(dbServerName, "_server"), prompt = "Server: ")
    keyring::key_set(service = "picard", username = paste0(dbServerName, "_port"), prompt = "Port: ")
    keyring::key_set(service = "picard", username = paste0(dbServerName, "_user"), prompt = "User: ")
    keyring::key_set(service = "picard", username = paste0(dbServerName, "_password"), prompt = "Password: ")

    serverLines <- sprintf(
      "\n%s:\n  dbms: !expr keyring::key_get(\"picard\", \"%s_dbms\")\n  server: !expr keyring::key_get(\"picard\", \"%s_server\")\n  port: !expr keyring::key_get(\"picard\", \"%s_port\")\n  user: !expr keyring::key_get(\"picard\", \"%s_user\")\n  password: !expr keyring::key_get(\"picard\", \"%s_password\")",
      dbServerName, dbServerName, dbServerName, dbServerName, dbServerName, dbServerName
    )
  }

  # Build content, appending to existing file if it exists
  if (file.exists(secretsFilePath)) {
    # File exists - read existing content and append new entries
    existingContent <- readr::read_file(secretsFilePath)

    # Remove trailing whitespace
    existingContent <- sub("\\s+$", "", existingContent)

    # Append new entries
    content <- paste0(existingContent, serverLines, "\n")

    cli::cli_alert_info("Appending to existing secrets file: {.path {secretsFilePath}}")
  } else {
    # File doesn't exist - create new with header
    header <- tryCatch(
      fs::path_package("picard", "templates/secretsHeader.txt") |>
        readr::read_file(),
      error = function(e) "# secrets.yml\n"
    )

    content <- paste0(header, serverLines, "\n")

    cli::cli_alert_info("Creating new secrets file: {.path {secretsFilePath}}")
  }

  readr::write_file(x = content, file = secretsFilePath)

  cli::cli_alert_success("Database server keyring credentials stored: {.path {secretsFilePath}}")

  # Open for review
  usethis::edit_file(secretsFilePath)
  cli::cli_alert_info("Review {.path {secretsFilePath}} with your credentials, then save and close.")

  invisible(secretsFilePath)
}

#' Set up Atlas/WebAPI keyring credentials
#'
#' Interactively prompts for Atlas/WebAPI credentials using `keyring::key_set()`
#' and writes them to secrets.yml with `!expr keyring::key_get(...)` references.
#' This is the most secure workflow — credentials never appear in plain text on disk.
#'
#' If the secrets file already exists, the atlas entry is appended rather than
#' overwriting.
#'
#' @param secretsFilePath Character. Path to the secrets.yml file to write.
#'   Default `"~/.picard/secrets.yml"`.
#' @return Invisibly returns the secrets file path.
#' @export
setupAtlasSecretsKeyring <- function(secretsFilePath = "~/.picard/secrets.yml") {
  if (!requireNamespace("keyring", quietly = TRUE)) {
    cli::cli_abort("keyring package is required. Install with: {.run install.packages('keyring')}")
  }

  secretsFilePath <- fs::path_expand(secretsFilePath)
  fs::dir_create(fs::path_dir(secretsFilePath))

  cli::cli_h2("Setting up keyring credentials in .picard/secrets.yml")
  cli::cli_h3("Atlas/WebAPI credentials")
  keyring::key_set(service = "picard", username = "atlas_baseUrl", prompt = "Base URL: ")
  keyring::key_set(service = "picard", username = "atlas_authMethod", prompt = "Auth Method: ")
  keyring::key_set(service = "picard", username = "atlas_user", prompt = "User: ")
  keyring::key_set(service = "picard", username = "atlas_password", prompt = "Password: ")

  atlasSection <- sprintf(
    "\n\natlas:\n  baseUrl: !expr keyring::key_get(\"picard\", \"atlas_baseUrl\")\n  authMethod: !expr keyring::key_get(\"picard\", \"atlas_authMethod\")\n  user: !expr keyring::key_get(\"picard\", \"atlas_user\")\n  password: !expr keyring::key_get(\"picard\", \"atlas_password\")"
  )

  # Build content, appending to existing file if it exists
  if (file.exists(secretsFilePath)) {
    # File exists - read existing content and append new entries
    existingContent <- readr::read_file(secretsFilePath)

    # Remove trailing whitespace
    existingContent <- sub("\\s+$", "", existingContent)

    # Append new entries
    content <- paste0(existingContent, "\n", atlasSection, "\n")

    cli::cli_alert_info("Appending to existing secrets file: {.path {secretsFilePath}}")
  } else {
    # File doesn't exist - create new with header
    header <- tryCatch(
      fs::path_package("picard", "templates/secretsHeader.txt") |>
        readr::read_file(),
      error = function(e) "# secrets.yml\n"
    )

    content <- paste0(header, atlasSection, "\n")

    cli::cli_alert_info("Creating new secrets file: {.path {secretsFilePath}}")
  }

  readr::write_file(x = content, file = secretsFilePath)

  cli::cli_alert_success("Atlas keyring credentials stored: {.path {secretsFilePath}}")

  # Open for review
  usethis::edit_file(secretsFilePath)
  cli::cli_alert_info("Review {.path {secretsFilePath}} with your credentials, then save and close.")

  invisible(secretsFilePath)
}

#' Review keyring credentials for picard service
#'
#' Lists all credentials stored in the "picard" keyring service with their
#' actual values, organized by database servers and Atlas. Useful for verifying
#' that setup functions correctly stored credentials and debugging resolution issues.
#'
#' @details
#' Displays credentials in two organized sections:
#' - Database Server Credentials: all `{server}_dbms`, `{server}_server`, 
#'   `{server}_port`, `{server}_user`, `{server}_password`, and 
#'   `{server}_connectionString` entries
#' - Atlas Credentials: all `atlas_*` entries
#'
#' @return Invisibly returns a tibble with columns: username, service.
#' @export
reviewKeyringCredentials <- function() {
  if (!requireNamespace("keyring", quietly = TRUE)) {
    cli::cli_abort("keyring package is required. Install with: {.run install.packages('keyring')}")
  }

  # Get all keys for picard service
  all_keys <- tryCatch(
    keyring::key_list(service = "picard"),
    error = function(e) {
      cli::cli_alert_info("No credentials found in picard keyring service")
      return(NULL)
    }
  )

  if (is.null(all_keys) || nrow(all_keys) == 0) {
    cli::cli_alert_info("No credentials found in picard keyring service")
    return(invisible(tibble::tibble(username = character(), service = character())))
  }

  # Organize by type
  db_keys <- all_keys$username[grepl("_dbms|_server|_port|_user|_password|_connectionString", all_keys$username)]
  atlas_keys <- all_keys$username[grepl("^atlas_", all_keys$username)]

  # get each credential
  # first db_keys
  db_val <- vector('list', length(db_keys))
  for (i in seq_along(db_val)) {
    val <- keyring::key_get("picard", username = db_keys[i])
    db_val[i] <- glue::glue_col("{db_keys[i]}: {yellow {val}}")
  }
  

  # next atlas
  atlas_val <- vector('list', length(atlas_keys))
  for (i in seq_along(atlas_val)) {
    val <- keyring::key_get("picard", username = atlas_keys[i])
    atlas_val[i] <- glue::glue("{atlas_keys[i]}: {yellow {val}}")
  }
  atlas_val <- do.call('c', atlas_val)

  if (length(db_val) > 0) {
    cli::cli_h2("Database Server Credentials in picard")
    cli::cli_bullets(setNames(db_val, rep("i", length(db_val))))
  }

  if (length(atlas_val) > 0) {
    cli::cli_h2("Atlas Credentials in picard")
    cli::cli_bullets(setNames(atlas_val, rep("i", length(atlas_val))))
  }

  invisible(all_keys)
}

