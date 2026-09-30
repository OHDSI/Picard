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

# Restore the study's package environment from renv.lock
renv::restore()

library(picard) # pipeline orchestration and execution framework
library(DatabaseConnector) # database connectivity and operations
library(SqlRender) # SQL translation and rendering

# C. Database Configuration ──────────────────────────────────────────────────

# Database identifiers to process (from config.yml)
dbIds <- c("{configBlocks}")

# D. Pre-Pipeline: Load & Build Manifest ─────────────────────────────────────
#
# WORKFLOW:
#   Edit scripts in inputs/cohorts/R/ and inputs/conceptSets/R/ to:
#   - Load from ATLAS (import_atlas_*.R)
#   - Build definitions programmatically with Capr (import_capr_*.R)
#   - Load custom SQL cohorts (import_sql_cohort.R)
#   - Build derived cohorts (build_dependent_cohorts.R)
#
# All 6 builder scripts are required - leave unused ones as generated, since
# unpopulated builders run without error. Scripts run in a fixed order with
# concept sets first, so cohorts can reference them if needed.
#
# You do not call the builder scripts here: execStudyPipeline() sources them
# for each database in dbIds, right before generating that database's cohorts
# and running its tasks, so database-specific changes (e.g. concept ids in
# custom SQL) are not overwritten by the next database. Each pass can read
# inputBuilderEnv$configBlock and inputBuilderEnv$pipelineVersion to build
# execution settings. To run the builders on their own while developing, use
# sourceInputBuilderScripts(configBlock = "<one of dbIds>").
#
# WARNING: Do NOT add builder scripts to analysis/tasks/ folder!
#          Use the dedicated R/ folders in inputs/cohorts/ and inputs/conceptSets/

# E. Execute Production Pipeline ─────────────────────────────────────────────────

# PIPELINE ACTIVATION SEQUENCE:
# - Validates environment and git state before running
# - Creates release branch automatically
# - Increments semantic version
# - For each database: sources input builders, generates cohorts, runs tasks
# - Commits changes and saves PR reference to PENDING_PR.md

cli::cli_h2("Engaging primary systems...")

taskResults <- execStudyPipeline(
  configBlock = dbIds,
  updateType = "patch", # "major", "minor", or "patch" version increment
  skipRenv = FALSE  # Set to TRUE only if environment is pre-verified
)

# execStudyPipeline() writes the new version to config.yml
pipelineVersion <- config::get("version")

cli::cli_h2("Pipeline Execution Complete")
cli::cli_alert_success("Task results saved to exec/logs/")

# F. Post-Processing merge ──────────────────────────────────────────────────

# Modify your pull request with post-processing results and notes as needed before final review.

## Export results for further analysis
cli::cli_alert_info("Initiating data export sequence...")
results <- runPostProcessing(
  pipelineVersion = pipelineVersion,
  dbIds = dbIds
)

# G. Post-Processing pretty ─────────────────────────────────────────────────

## Prepare dataset for dissemination
# cli::cli_alert_info("Preparing dissemination package...")
# sourceDisseminationScripts(
#   pipelineVersion = pipelineVersion,
#   databaseIds = dbIds,
#   outputPath = here::here("dissemination/pretty")
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











