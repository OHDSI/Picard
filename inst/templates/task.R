# {taskName}

# A. Meta Info --------------

# Study: {studyName}
# Author: {author}
# Date: {lubridate::today()}
# Description: {description}

# B. Dependencies ---------------

library(picard)
library(DatabaseConnector)
library(tidyverse)

# C. Connection Settings -------------

# set config block
configBlock <- "!||configBlock||!"

#set pipeline version
pipelineVersion <- "!||pipelineVersion||!"

# set executionSettings
executionSettings <- createExecutionSettingsFromConfig(
  configBlock = configBlock,
  pipelineVersion = pipelineVersion
)

# D. Task Settings ------------------

# set output folder
outputFolder <- setOutputFolder(
  executionSettings = executionSettings, 
  pipelineVersion = pipelineVersion, 
  taskName = "{taskName}"
)

# get cohort manifest
cm <- loadCohortManifest()

##### Note: Add code that identifies task settings like cohorts or time windows

# E. Script ------------------

##### Note: Add code that runs task
