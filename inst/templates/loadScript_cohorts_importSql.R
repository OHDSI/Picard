# ================================================================================
# File: importSql.R
# ================================================================================
#
# Study: {studyName}
# Author: {author}
# Purpose: {description}
#
# This script loads custom SQL-based cohorts into the manifest.
# Use this when a cohort cannot be expressed in ATLAS CIRCE or as a derived cohort.
# It is designed to be sourced as part of the pre-pipeline setup workflow.
#
# Workflow:
#   1. Place your .sql files in inputs/cohorts/sql/
#   2. Write SQL that generates a cohort_definition_id and subject_id
#   3. Use manifest$addSqlCohort() to add each cohort to the manifest
#   4. Review the added cohorts in the manifest
#
# Important: Your SQL must use SqlRender parameters for compatibility

library(picard)

# ================================================================================
# A. LOAD OR INITIALIZE MANIFEST
# ================================================================================

# First time only: Initialize a new manifest (comment out after first run)
# cohortManifest <- initCohortManifest()

# Subsequent times: Load from existing SQLite database
cohortManifest <- loadCohortManifest()


# ================================================================================
# B. SQL TEMPLATE & PARAMETERS
# ================================================================================

# Your SQL file should:
#   1. Be located in inputs/cohorts/sql/your_cohort.sql
#   2. Accept these SqlRender parameters:
#      - @target_cohort_id: The cohort definition ID assigned by the manifest
#      - @target_database_schema: Schema where the cohort table resides
#      - @target_cohort_table: Name of the cohort table
#      - @cdm_database_schema: The CDM schema
#   3. Include a DELETE step before INSERT (for idempotency)
#
# Example SQL snippet:
#
# DELETE FROM @target_database_schema.@target_cohort_table
# WHERE cohort_definition_id = @target_cohort_id;
#
# INSERT INTO @target_database_schema.@target_cohort_table
# (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
# SELECT
#   @target_cohort_id as cohort_definition_id,
#   person_id,
#   condition_start_date,
#   condition_end_date
# FROM @cdm_database_schema.condition_occurrence
# WHERE condition_concept_id = 201820  -- Type 2 Diabetes


# ================================================================================
# C. ADD SQL COHORTS TO MANIFEST
# ================================================================================

# Uncomment and modify to add your SQL cohorts:

# cohortManifest$addSqlCohort(
#   filePath = here::here("inputs/cohorts/sql/type2_diabetes.sql"),
#   label = "Type 2 Diabetes - SQL",
#   category = "Disease Populations",
#   tags = list(source = "custom_sql", domain = "condition")
# )

# cohortManifest$addSqlCohort(
#   filePath = here::here("inputs/cohorts/sql/metformin_exposure.sql"),
#   label = "Metformin Exposure - SQL",
#   category = "Exposures",
#   tags = list(source = "custom_sql", domain = "drug")
# )


# ================================================================================
# D. AUTO-DISCOVERY OF SQL FILES (OPTIONAL)
# ================================================================================

# If you prefer, you can auto-discover SQL files from inputs/cohorts/sql/:
# sqlDir <- here::here("inputs/cohorts/sql")
# sqlFiles <- list.files(sqlDir, pattern = "\\.sql$", full.names = TRUE)
#
# for (sqlFile in sqlFiles) {{
#   fileName <- tools::file_path_sans_ext(basename(sqlFile))
#   cohortManifest$addSqlCohort(
#     filePath = sqlFile,
#     label = snakecase::to_title_case(fileName),
#     category = "Custom SQL",
#     tags = list(source = "custom_sql")
#   )
# }}


# ================================================================================
# E. REVIEW SQL COHORTS IN MANIFEST
# ================================================================================

# Display a table of all cohorts in the manifest (including SQL cohorts)
cohortManifest$tabulateManifest()

# Optionally, export and inspect specific cohorts:
# cohortDef <- cohortManifest$getCohortDefinition(cohortId = 1L)
# print(cohortDef)

cli::cli_alert_success("SQL cohorts added successfully to manifest!")


# ================================================================================
# F. BEST PRACTICES FOR SQL COHORTS
# ================================================================================
#
# 1. IDEMPOTENCY: Always DELETE before INSERT to allow re-runs
# 2. PARAMETERS: Use SqlRender parameters (@name) not string interpolation
# 3. READABILITY: Comment your SQL for maintainability
# 4. TESTING: Test your SQL in your database before adding to manifest
# 5. DOCUMENTATION: Document assumptions, inclusions, and exclusions
# 6. VERSION CONTROL: Keep SQL files in inputs/cohorts/sql/ and commit to git
#
# Example of proper parameterization:
# - DO:   ... AND concept_id = @my_parameter


