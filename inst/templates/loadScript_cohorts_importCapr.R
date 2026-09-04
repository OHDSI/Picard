# ================================================================================
# File: importCapr.R
# ================================================================================
#
# Study: <<studyName>>
# Author: <<author>>
# Purpose: <<description>>
#
# This script allows you to build cohorts programmatically using Capr
# and add them to the manifest using the manifest API.
# It is designed to be sourced as part of the pre-pipeline setup workflow.
#
# Workflow:
#   1. Write Capr code to define your cohorts (Section B)
#   2. Use cohortManifest$addCaprCohort() to register each cohort (Section C)
#   3. Review the added cohorts in the manifest (Section D)
#
# AI agent support: an agent skill for this workflow is available at
# .agent/skills/picard-capr-cohorts/ (it wraps the Capr package's
# capr-cohort-generation skill). Ask your coding agent to build the cohort;
# only edit and source this script yourself.
#
# Note: Capr cohorts are powerful because they can be:
#   - Generated dynamically in code
#   - Version-controlled in your repository
#   - Parameterized for different analyses

library(picard)

# ================================================================================
# A. LOAD OR INITIALIZE MANIFEST
# ================================================================================


# Subsequent times: Load from existing SQLite database
cohortManifest <- loadCohortManifest()


# ================================================================================
# B. WRITE YOUR CAPR COHORTS BELOW
# ================================================================================

# Ensure Capr is loaded (you may need to install it first)
# remotes::install_github("OHDSI/Capr")
library(Capr)

# ---- Example: First-time Type 2 Diabetes diagnosis with 365d washout ----
# Verify all concept ids in ATHENA (https://athena.ohdsi.org) before use.

# t2dCs <- cs(descendants(201826), name = "Type 2 diabetes mellitus")
#
# t2dCohort <- cohort(
#   entry = entry(
#     conditionOccurrence(t2dCs),
#     observationWindow = continuousObservation(priorDays = 365L),
#     primaryCriteriaLimit = "First"
#   ),
#   attrition = attrition(
#     "No prior T2D diagnosis" = withAll(
#       exactly(
#         0L,
#         conditionOccurrence(t2dCs),
#         duringInterval(eventStarts(-Inf, -1))
#       )
#     ),
#     expressionLimit = "First"
#   ),
#   exit = exit(endStrategy = observationExit()),
#   era = era(eraDays = 0L)
# )


# ================================================================================
# C. ADD CAPR COHORTS TO THE MANIFEST
# ================================================================================

# Registration writes the cohort JSON to inputs/cohorts/json/ and records it in
# the manifest -- do NOT call Capr::writeCohort() yourself in this script.
# Labels must be unique within the manifest.

# cohortManifest$addCaprCohort(
#   caprCohort = t2dCohort,
#   label = "Type 2 Diabetes",
#   category = "Target",
#   tags = list(source = "capr", domain = "condition")
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
# - Capr documentation: https://ohdsi.github.io/Capr/
# - Concept search (ATHENA): https://athena.ohdsi.org
# - Agent skill bundle: .agent/skills/capr-cohort-generation/ (includes
#   CAPR_REFERENCE.md, the full Capr API reference)
#
# Capr allows you to build complex cohorts with:
#   - Entry events per OMOP domain (conditionOccurrence, drugExposure, measurement, ...)
#   - Inclusion/exclusion rules via attrition() with withAll()/withAny()/withAtLeast()
#   - Occurrence counts via exactly()/atLeast()/atMost() and assessment windows
#     via duringInterval(eventStarts(...), ...)
#   - Exit strategies: observationExit(), fixedExit(), drugExit()
#
# See the Capr documentation for advanced patterns and best practices.
