# ════════════════════════════════════════════════════════════════════════════════
# File: main.R
# "Make it so." - Jean-Luc Picard
# ════════════════════════════════════════════════════════════════════════════════
#
# A. Mission Parameters ────────────────────────────────────────────────────────
#
# Study: {studyName}
# Study Date: {lubridate::today()}
# Pipeline Type: Production
# 
# Description:
# Execute the complete picard study pipeline in production mode. This assumes
# your project structure has been initialized via initializeProjectStructure()
# and your cohort/concept-set manifests have been properly populated.

# B. Setup & Dependencies ────────────────────────────────────────────────────

# Restore environment (uncomment if first run in this session)
# renv::restore()

library(picard) # pipeline orchestration and execution framework
library(DatabaseConnector) # database connectivity and operations
library(SqlRender) # SQL translation and rendering

# C. Pre-Pipeline: Load & Build Manifest ─────────────────────────────────────
#
# WORKFLOW:
#   Edit scripts in inputs/cohorts/R/ and inputs/conceptSets/R/ to:
#   - Load concept sets from ATLAS (importAtlas.R)
#   - Build concepts programmatically with Capr (importCapr.R)
#   - Load custom SQL cohorts (importSql.R) [cohorts only]
#   - Build derived cohorts (buildDependentCohorts.R) [cohorts only]
#
# Delete unused builder scripts - only the ones you need will be sourced.
# Scripts are sourced in alphabetical order, with concept sets first.
# Concept set scripts run first so cohorts can reference them if needed.
#
# WARNING: Do NOT add builder scripts to analysis/tasks/ folder!
#          Use the dedicated R/ folders in inputs/cohorts/ and inputs/conceptSets/

sourceInputBuilderScripts(verbose = TRUE)

# D. Database Configuration ──────────────────────────────────────────────────

# Database identifiers to process (from config.yml)
dbIds <- c("{configBlocks}")

# E. Execute Production Pipeline ─────────────────────────────────────────────────

# PIPELINE ACTIVATION SEQUENCE:
# - Validates environment and git state before running
# - Creates release branch automatically
# - Increments semantic version
# - Commits changes and saves PR reference to PENDING_PR.md

cli::cli_h2("Engaging primary systems...")

taskResults <- execStudyPipeline(
  configBlock = dbIds,
  skipRenv = FALSE  # Set to TRUE only if environment is pre-verified
)

cli::cli_h2("Pipeline Execution Complete")
cli::cli_alert_success("Task results saved to exec/logs/")

# F. Post-Processing merge ──────────────────

# Modify your pull request with post-processing results and notes as needed before final review.

## Export results for further analysis
cli::cli_alert_info("Initiating data export sequence...")
results <- runPostProcessing(
  executionSettings = eo,
  reviewSchema = TRUE
)

# G. Post-Processing prett ──────────────────

## Prepare dataset for dissemination
# cli::cli_alert_info("Preparing dissemination package...")
# dissemination_data <- prepareDisseminationData(
#   taskResults = taskResults,
#   includeMetadata = TRUE
# )

# H. Post-Execution: Create Pull Request ──────────────────────────────────────
#
# REQUIRED NEXT STEPS:
#   1. Consult PENDING_PR.md - contains branch name, title, and description
#   2. Create a Pull Request on GitHub with the specified parameters
#   3. Request code review and testing per your team's protocols
#   4. Upon approval and merge to main, engage clearPendingPR()

cli::cli_blockquote("Next steps: Review PENDING_PR.md and create PR in Git Client.")

# Uncomment after your pull request has been merged to main:
# clearPendingPR()











