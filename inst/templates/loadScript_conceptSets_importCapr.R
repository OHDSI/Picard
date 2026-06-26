# ================================================================================
# File: importCapr.R
# ================================================================================
#
# Study: {studyName}
# Author: {author}
# Purpose: {description}
#
# This script allows you to build concept sets programmatically using Capr
# and add them to the manifest using the manifest API.
# It is designed to be sourced as part of the pre-pipeline setup workflow.
#
# Workflow:
#   1. Write Capr code to define your concept sets
#   2. Use manifest$addCaprConceptSet() to add each concept set to the manifest
#   3. Review the added concept sets in the manifest
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

# First time only: Initialize a new manifest (comment out after first run)
# conceptSetManifest <- initConceptSetManifest()

# Subsequent times: Load from existing SQLite database
conceptSetManifest <- loadConceptSetManifest()


# ================================================================================
# B. WRITE YOUR CAPR CONCEPT SETS BELOW
# ================================================================================

# Ensure Capr is loaded (you may need to install it first)
# install.packages("Capr", repos = "http://ohdsi.github.io/drat")
library(Capr)

# ---- Example 1: Simple condition concept set ----
# diabetesConcepts <- cs(
#   descendants(201820)  # Type 2 Diabetes Mellitus
# )


# ---- Example 2: Multiple concepts with exclusions ----
# antidiabeticDrugs <- cs(
#   descendants(21600095),  # Metformin
#   descendants(21601461),  # Insulin
#   descendants(21603933)   # Sulfonylureas
# )


# ---- Example 3: Condition concept set ----
# hypertensionConcepts <- cs(
#   descendants(316866)  # Hypertension
# )


# ----  Example 4: Drug ingredient concept set ----
# stainConcepts <- cs(
#   descendants(1539411)  # HMG-CoA reductase inhibitors (statins)
# )


# ================================================================================
# C. ADD CAPR CONCEPT SETS TO THE MANIFEST
# ================================================================================

# Uncomment and modify as you add your Capr concept sets:

# conceptSetManifest$addCaprConceptSet(
#   caprConceptSet = diabetesConcepts,
#   label = "Type 2 Diabetes",
#   domain = "condition_occurrence",
#   sourceCode = FALSE,
#   tags = list(source = "capr", clinical_domain = "endocrinology")
# )

# conceptSetManifest$addCaprConceptSet(
#   caprConceptSet = antidiabeticDrugs,
#   label = "Antidiabetic Medications",
#   domain = "drug_exposure",
#   sourceCode = FALSE,
#   tags = list(source = "capr", clinical_domain = "pharmacy")
# )

# conceptSetManifest$addCaprConceptSet(
#   caprConceptSet = stainConcepts,
#   label = "Statins",
#   domain = "drug_exposure",
#   sourceCode = FALSE,
#   tags = list(source = "capr", clinical_domain = "cardiology")
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
# - OHDSI Standardized Vocabularies: https://www.ohdsi.org/web/wiki/doku.php?id=documentation:vocabulary
# - Concept Search: https://athena.ohdsi.org
#
# Common Capr functions for concept sets:
#   - cs(): Create a concept set
#   - descendants(conceptId): Include concept and all descendants
#   - exclude(conceptId): Exclude a specific concept
#   - hasAttributes(...): Filter by concept attributes
#   - isSourceCode(TRUE/FALSE): Filter by source vs standard codes
#
# Domain values (commonly used):
#   - condition_occurrence: Diagnosis/medical conditions
#   - drug_exposure: Medications/treatments
#   - procedure_occurrence: Medical procedures
#   - measurement: Laboratory tests and measurements
#   - observation: Other observations and findings
#
# See Capr documentation and OHDSI community forums for advanced patterns.
