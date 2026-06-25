# ================================================================================
# File: importCapr.R
# ================================================================================
#
# Study: {studyName}
# Author: {author}
# Purpose: {description}
#
# This script allows you to build cohorts programmatically using Capr
# and add them to the manifest using the manifest API.
# It is designed to be sourced as part of the pre-pipeline setup workflow.
#
# Workflow:
#   1. Write Capr code to define your cohorts
#   2. Use manifest$addCaprCohort() to add each cohort to the manifest
#   3. Review the added cohorts in the manifest
#
# Note: Capr cohorts are powerful because they can be:
#   - Generated dynamically in code
#   - Version-controlled in your repository
#   - Parameterized for different analyses

# ================================================================================
# A. LOAD OR INITIALIZE MANIFEST
# ================================================================================

# First time only: Initialize a new manifest (comment out after first run)
# cohortManifest <- initCohortManifest()

# Subsequent times: Load from existing SQLite database
cohortManifest <- loadCohortManifest()


# ================================================================================
# B. WRITE YOUR CAPR COHORTS BELOW
# ================================================================================

# Ensure Capr is loaded (you may need to install it first)
# install.packages("Capr", repos = "http://ohdsi.github.io/drat")
library(Capr)

# ---- Example 1: Simple condition cohort ----
# myCohort <- cohort(
#   entry = entry(
#     condition(250171)  # Diabetes mellitus - ICD 250.1.7.1
#   ),
#   attrition(
#     "Exclude prior observations" = exclude(
#       observationWindow(
#         startWindow = window(start = -Inf, end = 0)
#       )
#     )
#   )
# )


# ---- Example 2: Drug exposure cohort ----
# drugCohort <- cohort(
#   entry = entry(
#     drug(21600095)  # Metformin
#   ),
#   attrition(
#     "Minimum 30 days observation" = exclude(
#       observationWindow(minDays = 30)
#     )
#   )
# )


# ================================================================================
# C. ADD CAPR COHORTS TO THE MANIFEST
# ================================================================================

# Uncomment and modify as you add your Capr cohorts:

# cohortManifest$addCaprCohort(
#   caprCohort = myCohort,
#   label = "Type 2 Diabetes",
#   category = "Disease Populations",
#   tags = list(source = "capr", domain = "condition")
# )

# cohortManifest$addCaprCohort(
#   caprCohort = drugCohort,
#   label = "Metformin Users",
#   category = "Exposures",
#   tags = list(source = "capr", domain = "drug")
# )


# ================================================================================
# D. REVIEW CAPR COHORTS IN MANIFEST
# ================================================================================

# Display a table of all cohorts in the manifest (including Capr cohorts)
cohortManifest$tabulateManifest()

# Optionally, export and inspect specific cohorts:
# cohortDef <- cohortManifest$getCohortDefinition(cohortId = 1L)
# print(cohortDef)

cli::cli_alert_success("Capr cohorts added successfully to manifest!")

# ================================================================================
# E. USEFUL RESOURCES
# ================================================================================
#
# - Capr GitHub: https://github.com/OHDSI/Capr
# - CirceR documentation (underlying CIRCE generation): ?CirceR
# - CohortExpressionBuilder: For visual cohort building
#
# Capr allows you to build complex cohorts with:
#   - Entry criteria (condition, drug, procedure, etc.)
#   - Inclusion/exclusion rules
#   - Attrition criteria
#   - Temporal relationships
#   - Visit context specifications
#
# See Capr documentation for advanced patterns and best practices.
