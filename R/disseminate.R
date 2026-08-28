#' Clean Column Names to Standard Format
#' @description Standardizes column names to snake_case format, making them
#'   consistent across datasets for easier dissemination and reporting.
#' @param data Data frame or tibble to clean
#' @param to_lower Logical. Convert to lowercase. Defaults to TRUE.
#'
#' @return Data frame with standardized column names in snake_case
#' @export
#'
#' @details
#' Converts column names to snake_case by:
#' - Converting spaces to underscores
#' - Converting periods to underscores
#' - Converting CamelCase to snake_case
#' - Converting to lowercase (optional)
#'
cleanColumnNames <- function(data, to_lower = TRUE) {
  checkmate::assert_data_frame(data)
  checkmate::assert_logical(to_lower, len = 1)

  # Convert column names to snake_case
  new_names <- colnames(data)
  new_names <- gsub(" ", "_", new_names)
  new_names <- gsub("\\.", "_", new_names)
  new_names <- gsub("([a-z])([A-Z])", "\\1_\\2", new_names)
  if (to_lower) {
    new_names <- tolower(new_names)
  }

  colnames(data) <- new_names
  return(data)
}

#' Format Percentage Columns
#' @description Formats percentage columns to a consistent decimal places
#'   with optional percent symbol. Useful for preparing results for publication.
#' @param data Data frame or tibble
#' @param percent_cols Character vector of column names to format as percentages.
#'   If NULL, attempts to detect columns with "percent", "pct", or "prop" in name.
#' @param decimal_places Integer. Number of decimal places. Defaults to 1.
#' @param add_symbol Logical. Add "%" symbol to values. Defaults to TRUE.
#'
#' @return Data frame with formatted percentage columns (as character)
#' @export
#'
#' @details
#' This function:
#' - Multiplies values by 100 if they are between 0 and 1 (proportions)
#' - Rounds to specified decimal places
#' - Optionally adds a percent symbol
#' - Converts to character for consistent display
#'
formatPercentages <- function(data, percent_cols = NULL, decimal_places = 1, add_symbol = TRUE) {
  checkmate::assert_data_frame(data)
  checkmate::assert_integerish(decimal_places, lower = 0, upper = 10)
  checkmate::assert_logical(add_symbol, len = 1)

  # Auto-detect percentage columns if not specified
  if (is.null(percent_cols)) {
    col_lower <- tolower(colnames(data))
    percent_cols <- colnames(data)[grepl("percent|pct|prop", col_lower)]

    if (length(percent_cols) == 0) {
      cli::cli_alert_info("No percentage columns detected. Specify via percent_cols parameter.")
      return(data)
    }
  }

  # Format each percentage column
  for (col in percent_cols) {
    if (col %in% colnames(data)) {
      values <- as.numeric(data[[col]])

      # If values are proportions (0-1), multiply by 100
      if (!all(is.na(values)) && max(values, na.rm = TRUE) <= 1 && min(values, na.rm = TRUE) >= 0) {
        values <- values * 100
      }

      # Round and format
      formatted <- round(values, decimal_places)
      if (add_symbol) {
        data[[col]] <- paste0(formatted, "%")
      } else {
        data[[col]] <- as.character(formatted)
      }
    }
  }

  return(data)
}

#' Format Float Columns
#' @description Rounds and formats numeric columns to a consistent number of
#'   decimal places, removing trailing zeros for cleaner display.
#' @param data Data frame or tibble
#' @param float_cols Character vector of column names to format.
#'   If NULL, formats all numeric columns except integers.
#' @param decimal_places Integer. Number of decimal places. Defaults to 2.
#' @param remove_trailing_zeros Logical. Remove trailing zeros. Defaults to TRUE.
#'
#' @return Data frame with formatted float columns
#' @export
#'
formatFloats <- function(data, float_cols = NULL, decimal_places = 2, remove_trailing_zeros = TRUE) {
  checkmate::assert_data_frame(data)
  checkmate::assert_integerish(decimal_places, lower = 0, upper = 10)
  checkmate::assert_logical(remove_trailing_zeros, len = 1)

  # Auto-detect float columns if not specified
  if (is.null(float_cols)) {
    float_cols <- colnames(data)[sapply(data, function(x) {
      is.numeric(x) && !all(x == as.integer(x), na.rm = TRUE)
    })]
  }

  # Format each float column
  for (col in float_cols) {
    if (col %in% colnames(data)) {
      values <- as.numeric(data[[col]])
      formatted <- round(values, decimal_places)

      if (remove_trailing_zeros) {
        formatted <- as.character(formatted)
        # Remove trailing zeros after decimal
        formatted <- sub("\\.0+$", "", formatted)
        formatted <- sub("(\\.[0-9]*[1-9])0+$", "\\1", formatted)
      }

      data[[col]] <- formatted
    }
  }

  return(data)
}

# Coerce a single column to a target type. Unknown types are returned
# untouched so an unrecognised rule is a no-op rather than an error.
coerce_column <- function(x, target_type) {
  switch(target_type,
    integer = as.integer(x),
    numeric = as.numeric(x),
    character = as.character(x),
    logical = as.logical(x),
    date = as.Date(x),
    x
  )
}

#' Standardize Data Types
#' @description Standardizes data types across columns based on common patterns
#'   (e.g., columns ending in "_id" become integers, columns with "date" become dates).
#' @param data Data frame or tibble
#' @param type_rules List of named character vectors defining type conversion rules.
#'   If NULL, applies default heuristics.
#'
#' @return Data frame with standardized data types
#' @export
#'
#' @details
#' Default type conversions:
#' - Columns named "*_id": convert to integer
#' - Columns named "*_date": convert to date (ISO format assumed)
#' - Columns named "*_count": convert to integer
#' - Columns containing "flag" or "indicator": convert to logical
#'
#' A conversion is only applied if it preserves every non-missing value. A
#' column that matches a rule but cannot be coerced without introducing `NA`
#' (for example a character `database_id`) is left as-is and reported.
#'
standardizeDataTypes <- function(data, type_rules = NULL) {
  checkmate::assert_data_frame(data)

  # Default type rules
  if (is.null(type_rules)) {
    type_rules <- list(
      integer = c("_id$", "_count$"),
      date = c("_date$", "_time$"),
      logical = c("flag", "indicator")
    )
  }

  # Apply type conversions
  for (target_type in names(type_rules)) {
    patterns <- type_rules[[target_type]]

    for (pattern in patterns) {
      matching_cols <- colnames(data)[grepl(pattern, tolower(colnames(data)))]

      for (col in matching_cols) {
        converted <- tryCatch(
          suppressWarnings(coerce_column(data[[col]], target_type)),
          error = function(e) {
            cli::cli_alert_info("Could not convert {col} to {target_type}: {e$message}")
            NULL
          }
        )

        if (is.null(converted)) {
          next
        }

        # A coercion that turns real values into NA is data loss, not
        # standardization: databaseId becomes database_id upstream and matches
        # "_id$", but holds names like "db_alpha" that have no integer form.
        if (anyNA(converted[!is.na(data[[col]])])) {
          cli::cli_alert_info(
            "Skipping {col}: converting to {target_type} would discard values"
          )
          next
        }

        data[[col]] <- converted
      }
    }
  }

  return(data)
}

#' Pivot Data Wide for Comparison
#' @description Pivots data from long to wide format for cross-database or
#'   cross-group comparison. Common use case: compare cohort counts across databases.
#' @param data Data frame in long format
#' @param id_cols Character vector of column(s) identifying rows
#' @param names_from Character. Column to pivot into new column names
#' @param values_from Character. Column(s) to pivot into values
#' @param names_prefix Character. Prefix to add to new column names. Defaults to "".
#' @param values_fill Value to fill missing combinations. Defaults to NA.
#'
#' @return Data frame in wide format, suitable for side-by-side comparison
#' @export
#'
#' @details
#' This is a convenience wrapper around tidyr::pivot_wider() with sensible defaults
#' for comparison outputs. Common use:
#' ```r
#' cohort_counts <- pivotForComparison(
#'   data = merged_counts,
#'   id_cols = "cohortId",
#'   names_from = "databaseId",
#'   values_from = "count",
#'   names_prefix = "count_"
#' )
#' ```
#'
pivotForComparison <- function(data, id_cols, names_from, values_from,
                              names_prefix = "", values_fill = NA) {
  checkmate::assert_data_frame(data)
  checkmate::assert_character(id_cols, min.len = 1)
  checkmate::assert_string(names_from)
  checkmate::assert_character(values_from, min.len = 1)

  pivot_result <- tidyr::pivot_wider(
    data = data,
    id_cols = all_of(id_cols),
    names_from = all_of(names_from),
    values_from = all_of(values_from),
    names_prefix = names_prefix,
    values_fill = values_fill
  )

  return(pivot_result)
}

#' Prepare Dissemination Data with Chained Transformations
#' @description Convenience function that chains common data preparation steps
#'   for dissemination: cleaning names, formatting numbers, standardizing types.
#' @param data Data frame or tibble to prepare
#' @param clean_names Logical. Apply cleanColumnNames(). Defaults to TRUE.
#' @param format_percentages Logical. Apply formatPercentages(). Defaults to TRUE.
#' @param format_floats Logical. Apply formatFloats(). Defaults to TRUE.
#' @param standardize_types Logical. Apply standardizeDataTypes(). Defaults to TRUE.
#' @param percent_decimal_places Integer. Decimal places for percentages. Defaults to 1.
#' @param float_decimal_places Integer. Decimal places for floats. Defaults to 2.
#'
#' @return Data frame prepared for dissemination
#' @export
#'
#' @details
#' This function applies transformations in sequence:
#' 1. Clean column names to snake_case
#' 2. Format percentage columns
#' 3. Format float columns
#' 4. Standardize data types
#'
#' Each step is optional and can be controlled individually.
#'
prepareDisseminationData <- function(
    data,
    clean_names = TRUE,
    format_percentages = TRUE,
    format_floats = TRUE,
    standardize_types = TRUE,
    percent_decimal_places = 1,
    float_decimal_places = 2) {

  checkmate::assert_data_frame(data)
  checkmate::assert_logical(c(clean_names, format_percentages, format_floats, standardize_types),
    len = 4, any.missing = FALSE
  )

  cli::cli_rule("Prepare Dissemination Data")

  if (clean_names) {
    cli::cli_alert_info("Cleaning column names...")
    data <- cleanColumnNames(data)
  }

  if (format_percentages) {
    cli::cli_alert_info("Formatting percentages...")
    data <- formatPercentages(data, decimal_places = percent_decimal_places)
  }

  if (format_floats) {
    cli::cli_alert_info("Formatting floats...")
    data <- formatFloats(data, decimal_places = float_decimal_places)
  }

  if (standardize_types) {
    cli::cli_alert_info("Standardizing data types...")
    data <- standardizeDataTypes(data)
  }

  cli::cli_alert_success("Dissemination data preparation complete!")
  return(data)
}
