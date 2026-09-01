# ================================================================================
# File: importCapr.R
# ================================================================================
#
# Study: <<studyName>>
# Author: <<author>>
# Purpose: <<description>>
#
# This script allows you to build concept sets programmatically using Capr
# and add them to the manifest using the manifest API.
# It is designed to be sourced as part of the pre-pipeline setup workflow.
#
# Workflow:
#   1. Write Capr code to define your concept sets (Section B)
#   2. Use conceptSetManifest$addCaprConceptSet() to register each one (Section C)
#   3. Review the added concept sets in the manifest (Section D)
#
# AI agent support: an agent skill for this workflow is available at
# .agent/skills/picard-capr-cohorts/ (it wraps the Capr package's
# capr-cohort-generation skill). Ask your coding agent to build the concept set;
# only edit and source this script yourself.
#
# Note: Capr concept sets are powerful because they can be:
#   - Generated dynamically based on data exploration
#   - Version-controlled in your repository
#   - Reused across multiple studies
#   - Parameterized for different analyses

library(picard)

# ================================================================================
# A. LOAD OR INITIALIZE MANIFEST
# ================================================================================

# Subsequent times: Load from existing SQLite database
conceptSetManifest <- loadConceptSetManifest()


# ================================================================================
# B. WRITE YOUR CAPR CONCEPT SETS BELOW
# ================================================================================

# Ensure Capr is loaded (you may need to install it first)
# remotes::install_github("OHDSI/Capr")
library(Capr)

# Verify all concept ids in ATHENA (https://athena.ohdsi.org) before use.

# ---- Example 1: Single condition with descendants ----
# t2dConcepts <- cs(
#   descendants(201826),  # Type 2 diabetes mellitus
#   name = "Type 2 diabetes mellitus"
# )


# ---- Example 2: Multiple drug ingredients ----
# antidiabeticDrugs <- cs(
#   descendants(1503297),   # metformin
#   descendants(45774751),  # empagliflozin
#   name = "Antidiabetic drugs"
# )


# ---- Example 3: Include descendants but exclude a sub-branch ----
# nonT2dDiabetes <- cs(
#   descendants(201820),           # Diabetes mellitus
#   exclude(descendants(201826)),  # exclude the type 2 diabetes branch
#   name = "Diabetes mellitus excluding type 2"
# )


# ================================================================================
# C. ADD CAPR CONCEPT SETS TO THE MANIFEST
# ================================================================================

# Registration writes the concept set JSON to inputs/conceptSets/json/ and
# records it in the manifest. Labels must be unique within the manifest.

# conceptSetManifest$addCaprConceptSet(
#   caprConceptSet = t2dConcepts,
#   label = "Type 2 Diabetes",
#   category = "Conditions",
#   tags = list(source = "capr", clinical_domain = "endocrinology")
# )

# conceptSetManifest$addCaprConceptSet(
#   caprConceptSet = antidiabeticDrugs,
#   label = "Antidiabetic Medications",
#   category = "Drugs",
#   tags = list(source = "capr", clinical_domain = "pharmacy")
# )


# ================================================================================
# D. REVIEW CAPR CONCEPT SETS IN MANIFEST
# ================================================================================

# Display a table of all concept sets in the manifest (including Capr concept sets)
conceptSetManifest$tabulateManifest()

# Optionally, export and inspect specific concept sets:
# conceptSetDef <- conceptSetManifest$getConceptSetDefinition(conceptSetId = 1L)
# print(conceptSetDef)

cli::cli_alert_success("Capr concept sets added successfully to manifest!")


# ================================================================================
# E. USEFUL RESOURCES
# ================================================================================
#
# - Capr GitHub: https://github.com/OHDSI/Capr
# - Capr documentation: https://ohdsi.github.io/Capr/
# - OHDSI Standardized Vocabularies: https://ohdsi.github.io/TheBookOfOhdsi/StandardizedVocabularies.html
# - Concept search (ATHENA): https://athena.ohdsi.org
# - Agent skill bundle: .agent/skills/capr-cohort-generation/ (includes
#   CAPR_REFERENCE.md, the full Capr API reference)
#
# Common Capr functions for concept sets:
#   - cs(...): Create a concept set from ids and the modifiers below
#   - descendants(conceptId): Include the concept and all its descendants
#   - exclude(...): Exclude the wrapped concepts (and their descendants if wrapped
#     around descendants())
#   - mapped(...): Include source codes mapped to the concepts
#
# See Capr documentation and OHDSI community forums for advanced patterns.
