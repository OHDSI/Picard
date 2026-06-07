# ════════════════════════════════════════════════════════════════════════════════
# File: test_main.R
# "Explore strange new databases..." - Jean-Luc Picard (modified for testing)
# ════════════════════════════════════════════════════════════════════════════════
#
# TEST FLIGHT PROCEDURES
#
# This script provides a development/testing variant of the production pipeline.
# Use this during active development and iteration cycles.
#
# Key differences from main.R:
#   • No git state validation required
#   • No release branch creation
#   • No semantic version increment
#   • No PENDING_PR workflow
#   • "dev" version tagged in results
#   • Full pipeline execution with all validations
#   • Safe for rapid iteration and testing
#
# Once satisfied with results, use main.R for production run.

# ════════════════════════════════════════════════════════════════════════════════
# A. Test Mission Parameters ─────────────────────────────────────────────────────

# Study: {studyName}
# Stardate: {lubridate::today()}
# Purpose: Development & Iteration
# 
# TEST FLIGHT PROFILE:
# Execute the picard study pipeline in test mode. Validates all data and execution
# logic but skips git/versioning constraints. Perfect for development iteration.

# B. Systems Check & Initialization ───────────────────────────────────────────

# Initialize ship systems (restore environment if first run in this session)
# renv::restore()

library(picard)
library(DatabaseConnector)
library(tidyverse)

# C. Database Configuration ──────────────────────────────────────────────────

# Database sectors to traverse (from config.yml)
dbIds <- c("{configBlocks}")

cli::cli_alert_info("Setting course for database sectors: {{paste(dbIds, collapse = ', ')}}")

# ════════════════════════════════════════════════════════════════════════════════
# D. Engage Test Pipeline ────────────────────────────────────────────────────────
# ════════════════════════════════════════════════════════════════════════════════

# TEST MODE CAPABILITIES:
#   • Execute full pipeline validation and task processing
#   • Skip environment validation (assumes development setup)
#   • Skip git state checks (work on any branch, no cleanup required)
#   • No version increment (results tagged as "dev")
#   • Rapid iteration without administrative overhead
#   • Full audit trail to exec/logs/ for review

cli::cli_h2("Initiating test flight sequence...")

taskResults <- testStudyPipeline(
  configBlock = dbIds,
  skipRenv = FALSE  # Set to TRUE only if you've manually verified environment
)

cli::cli_h2("Test flight complete - all systems performing nominally.")
cli::cli_alert_success("Test cycle results logged. Review in exec/logs/")

# ════════════════════════════════════════════════════════════════════════════════
# E. Review Test Results ──────────────────────────────────────────────────────────

# Your test flight has generated comprehensive execution logs and task results.
#
# NEXT STEPS:
#   1. Review exec/logs/ for detailed execution records
#   2. Inspect taskResults for data quality and completeness
#   3. Verify cohort counts, concept set definitions, and pipeline outputs
#   4. Make any necessary adjustments to cohort/concept definitions
#   5. Re-run test_main.R if changes were made
#   6. Once satisfied, use main.R to execute production mission

cli::cli_blockquote(paste(
  "Test flight successful.",
  "Review exec/logs/ and taskResults.",
  "When ready for production, switch to main.R",
  sep = "\n"
))

# ════════════════════════════════════════════════════════════════════════════════
# F. Optional Analysis & Exploration (development-only) ────────────────────────

# Uncomment sections below to explore results further during development

## Inspect task execution summary
# summary_report <- getTaskRunSummary(taskResults)
# print(summary_report)

## View cohort manifest details
# manifest <- loadCohortManifest()
# print(manifest$getManifest())

## View concept set manifest details
# concept_manifest <- loadConceptSetManifest()
# print(concept_manifest$getManifest())

## Export results for external analysis (if applicable)
# results <- runPostProcessing(
#   executionSettings = eo,
#   reviewSchema = TRUE
# )

## Prepare dataset for dissemination (if applicable)
# dissemination_data <- prepareDisseminationData(
#   taskResults = taskResults,
#   includeMetadata = TRUE
# )

# ════════════════════════════════════════════════════════════════════════════════
#                           Test Flight Complete
#                              Ready for Review
#                    See main.R when mission is approved
# ════════════════════════════════════════════════════════════════════════════════
