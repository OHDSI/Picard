# ============================================================================
# Dissemination Script Template - {study_name}
# ============================================================================
#
# Purpose: Format and prepare merged study results for dissemination
#
# This template demonstrates how to:
#   1. Use disseminationEnv to access pipeline metadata
#   2. Load merged results from the postprocessing step
#   3. Apply formatting functions (prepareDisseminationData, etc.)
#   4. Generate formatted outputs for Excel, StudyHub, or other targets
#
# After the pipeline runs (sourceInputBuilderScripts -> execStudyPipeline ->
# runPostProcessing), edit this script to customize your dissemination outputs,
# then source it via sourceDisseminationScripts() in your main.R.
#
# ============================================================================

library(picard)

# ============================================================================
# 0. Access Dissemination Metadata (automatically injected by sourceDisseminationScripts)
# ============================================================================

# The disseminationEnv object is automatically available with:
#   - pipelineVersion: The version being disseminated (e.g., "1.0.0")
#   - databaseIds: Vector of database IDs processed
#   - outputPath: Base output directory for results
#   - resultsPath: Merged results directory (dissemination/export/merge/v{version}/)

cat("Dissemination Metadata:\n")
cat("  Pipeline Version:", disseminationEnv$pipelineVersion, "\n")
cat("  Database IDs:", paste(disseminationEnv$databaseIds, collapse = ", "), "\n")
cat("  Output Path:", disseminationEnv$outputPath, "\n")
cat("  Results Path:", disseminationEnv$resultsPath, "\n\n")

# ============================================================================
# 1. Load Merged Results from Postprocessing
# ============================================================================

# Use disseminationEnv to avoid hardcoding paths
resultsPath <- disseminationEnv$resultsPath
outputPath <- disseminationEnv$outputPath

# Create version-specific output directory if it doesn't exist
versionedOutputPath <- file.path(outputPath, paste0("v", disseminationEnv$pipelineVersion))
if (!dir.exists(versionedOutputPath)) {
  dir.create(versionedOutputPath, recursive = TRUE)
}

# List available result files from postprocessing merge
result_files <- list.files(resultsPath, pattern = "\\.csv$", full.names = FALSE)

cat("Available result files from postprocessing merge:\n")
cat(paste("-", result_files, collapse = "\n"), "\n\n")

# ============================================================================
# 2. Example: Load and Format a Single Results File
# ============================================================================

# Example: Process the first available result file
if (length(result_files) > 0) {
  # Load the results
  result_file <- result_files[1]
  result_path <- file.path(resultsPath, result_file)
  
  results_df <- readr::read_csv(
    result_path,
    show_col_types = FALSE
  )
  
  cat("Loaded:", result_file, "\n")
  cat("Dimensions:", nrow(results_df), "rows ×", ncol(results_df), "columns\n")
  
  # Show which databases are in this result
  if ("database_id" %in% names(results_df)) {
    cat("Databases in this result:", paste(unique(results_df$database_id), collapse = ", "), "\n")
  }
  cat("\n")
  
  # Apply prepareDisseminationData for standard formatting
  formatted_df <- picard::prepareDisseminationData(
    data = results_df,
    clean_names = TRUE,           # Convert to snake_case
    format_percentages = TRUE,    # Format percentage columns (e.g., *_pct)
    format_floats = TRUE,         # Round floats to specified decimal places
    standardize_types = TRUE,     # Auto-detect patterns (*_id -> integer, *_date -> date)
    percent_decimal_places = 1,
    float_decimal_places = 2
  )
  
  # Optional: Write formatted CSV using disseminationEnv outputPath
  output_csv <- file.path(versionedOutputPath, paste0("formatted_", result_file))
  readr::write_csv(formatted_df, output_csv)
  cat("Wrote:", output_csv, "\n\n")
}

# ============================================================================
# 3. Example: Pivot Results for Cross-Database Comparison
# ============================================================================

# If your results have a 'databaseId' column, you can create a wide pivot
# for easy comparison across databases

# Uncomment and modify to use:
# 
# # Assuming 'databaseId' column exists for grouping
# comparison_df <- picard::pivotForComparison(
#   data = formatted_df,
#   pivotColumns = c("metric_name", "stratum"),  # Columns to pivot
#   valueColumn = "estimate",                     # Column with values
#   databaseId = "databaseId"                     # Grouping column
# )
# 
# output_comparison <- file.path(outputPath, "comparison_wide.csv")
# readr::write_csv(comparison_df, output_comparison)

# ============================================================================
# 4. Example: Export to Excel with Formatting
# ============================================================================

# Uncomment and modify to export a formatted Excel workbook:
#
# library(openxlsx)
# 
# wb <- createWorkbook()
# 
# # Sheet 1: Formatted results
# addWorksheet(wb, "Results")
# writeData(wb, 1, formatted_df)
# 
# # Optional: Add column widths and cell formatting
# setColWidths(wb, 1, cols = 1:ncol(formatted_df), widths = "auto")
# 
# # Save workbook
# output_excel <- file.path(outputPath, "dissemination_results.xlsx")
# saveWorkbook(wb, output_excel, overwrite = TRUE)
# cat("Wrote:", output_excel, "\n\n")

# ============================================================================
# 5. Example: Filter and Export Specific Subsets
# ============================================================================

# You can filter results by database, metric type, or other criteria.
# Use disseminationEnv$databaseIds to programmatically access database info:
#
# # Filter to specific databases from disseminationEnv
# db_results <- formatted_df |>
#   dplyr::filter(database_id %in% disseminationEnv$databaseIds)
#
# # Filter to a specific database
# db_results <- formatted_df |>
#   dplyr::filter(database_id == disseminationEnv$databaseIds[1])
#
# # Filter to specific metrics
# metric_results <- formatted_df |>
#   dplyr::filter(grepl("^prevalence", metric_name, ignore.case = TRUE))
#
# # Save filtered subsets using disseminationEnv paths
# readr::write_csv(
#   metric_results,
#   file.path(versionedOutputPath, "prevalence_subset.csv")
# )

# ============================================================================
# 6. Example: Format for Study Hub (if applicable)
# ============================================================================

# If you're uploading to a Study Hub or similar platform,
# you may need specific column names or format:
#
# studyhub_df <- formatted_df |>
#   dplyr::select(
#     database_id,
#     cohort_id,
#     metric_name,
#     estimate,
#     stratum_1 = stratum_value_1
#   ) |>
#   dplyr::mutate(
#     analysis_version = disseminationEnv$pipelineVersion,
#     upload_date = Sys.Date(),
#     # Include database IDs info
#     databases_included = paste(disseminationEnv$databaseIds, collapse = ";")
#   )
#
# readr::write_csv(
#   studyhub_df,
#   file.path(versionedOutputPath, "studyhub_format.csv")
# )

# ============================================================================
# End of Dissemination Script
# ============================================================================

cat("Dissemination script completed for version", disseminationEnv$pipelineVersion, "\n")
cat("Check", versionedOutputPath, "for formatted outputs\n")
