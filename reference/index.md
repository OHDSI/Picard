# Package index

## Core Classes

Main R6 classes for package functionality

- [`CohortDef`](https://ohdsi.github.io/Picard/reference/CohortDef.md) :
  CohortDef R6 Class
- [`CohortManifest`](https://ohdsi.github.io/Picard/reference/CohortManifest.md)
  : CohortManifest R6 Class
- [`ConceptSetDef`](https://ohdsi.github.io/Picard/reference/ConceptSetDef.md)
  : ConceptSetDef R6 Class
- [`ConceptSetManifest`](https://ohdsi.github.io/Picard/reference/ConceptSetManifest.md)
  : ConceptSetManifest R6 Class
- [`ContributorLine`](https://ohdsi.github.io/Picard/reference/ContributorLine.md)
  : ContributorLine R6 Class
- [`DbConfigBlock`](https://ohdsi.github.io/Picard/reference/DbConfigBlock.md)
  : DbConfigBlock R6 Class
- [`ExecutionSettings`](https://ohdsi.github.io/Picard/reference/ExecutionSettings.md)
  : ExecutionSettings
- [`StudyMeta`](https://ohdsi.github.io/Picard/reference/StudyMeta.md) :
  StudyMeta R6 Class
- [`UlyssesStudy`](https://ohdsi.github.io/Picard/reference/UlyssesStudy.md)
  : UlyssesStudy R6 Class

## Creation Functions

Functions for creating objects and structures (make\*)

- [`makeBlock()`](https://ohdsi.github.io/Picard/reference/makeBlock.md)
  : Make a database config block
- [`makeDisseminationScript()`](https://ohdsi.github.io/Picard/reference/makeDisseminationScript.md)
  : Create a Dissemination Script Template
- [`makeInputBuilderScript()`](https://ohdsi.github.io/Picard/reference/makeInputBuilderScript.md)
  : Create a Pre-Pipeline Builder Script
- [`makePrintFriendlyFile()`](https://ohdsi.github.io/Picard/reference/makePrintFriendlyFile.md)
  : Generate Print-Friendly Cohort Documentation from JSON
- [`makeSrcFile()`](https://ohdsi.github.io/Picard/reference/makeSrcFile.md)
  : Create a Source Utility File
- [`makeSrcSqlFile()`](https://ohdsi.github.io/Picard/reference/makeSrcSqlFile.md)
  : Create a SqlRender SQL File
- [`makeStudyMeta()`](https://ohdsi.github.io/Picard/reference/makeStudyMeta.md)
  : Make Study Meta for Ulysses
- [`makeTaskFile()`](https://ohdsi.github.io/Picard/reference/makeTaskFile.md)
  : Function initializing an R file for an analysis task
- [`makeUlyssesStudySettings()`](https://ohdsi.github.io/Picard/reference/makeUlyssesStudySettings.md)
  : Make Ulysses Study Settings

## Initialization Functions

Functions for initializing components (init\*)

- [`initAgentMode()`](https://ohdsi.github.io/Picard/reference/initAgentMode.md)
  : Initialize or Restore Agent Mode for Cloned Repository
- [`initCohortManifest()`](https://ohdsi.github.io/Picard/reference/initCohortManifest.md)
  : Initialize a New Cohort Manifest
- [`initConceptSetManifest()`](https://ohdsi.github.io/Picard/reference/initConceptSetManifest.md)
  : Initialize a New Concept Set Manifest
- [`initializeRenv()`](https://ohdsi.github.io/Picard/reference/initializeRenv.md)
  : Initialize Renv for Project

## Build Functions

Functions for building study components (build\*)

- [`buildStudyHub()`](https://ohdsi.github.io/Picard/reference/buildStudyHub.md)
  : Build Study Hub

## Create Functions

Functions for creating new objects (create\*)

- [`createAgentBranch()`](https://ohdsi.github.io/Picard/reference/createAgentBranch.md)
  : Create Feature Branch for Agent Work
- [`createBlankCohortsLoadFile()`](https://ohdsi.github.io/Picard/reference/createBlankCohortsLoadFile.md)
  : Create Blank Cohorts Load File
- [`createBlankConceptSetsLoadFile()`](https://ohdsi.github.io/Picard/reference/createBlankConceptSetsLoadFile.md)
  : Create Blank Concept Sets Load File
- [`createExecutionSettings()`](https://ohdsi.github.io/Picard/reference/createExecutionSettings.md)
  : Create an ExecutionSettings object and set its attributes
- [`createExecutionSettingsFromConfig()`](https://ohdsi.github.io/Picard/reference/createExecutionSettingsFromConfig.md)
  : Create ExecutionSettings from Config Block
- [`createPullRequest()`](https://ohdsi.github.io/Picard/reference/createPullRequest.md)
  : Create Pull Request Metadata
- [`createSubsetEndWindow()`](https://ohdsi.github.io/Picard/reference/createSubsetEndWindow.md)
  : Create a Subset End Window Operator
- [`createSubsetStartWindow()`](https://ohdsi.github.io/Picard/reference/createSubsetStartWindow.md)
  : Create a Subset Start Window Operator

## Execution Functions

Functions for executing study tasks (exec\*)

- [`execStudyPipeline()`](https://ohdsi.github.io/Picard/reference/execStudyPipeline.md)
  : Production Study Pipeline Execution

## Configuration Functions

Functions for configuration and setup (set\*)

- [`getAtlasConnection()`](https://ohdsi.github.io/Picard/reference/getAtlasConnection.md)
  : Get Atlas Connection
- [`getTaskRunSummary()`](https://ohdsi.github.io/Picard/reference/getTaskRunSummary.md)
  : Get Task Run Summary
- [`setAtlasConnection()`](https://ohdsi.github.io/Picard/reference/setAtlasConnection.md)
  : Set Atlas Connection (Deprecated)
- [`setContributor()`](https://ohdsi.github.io/Picard/reference/setContributor.md)
  : Set Ulysses Contributor
- [`setDbConfigBlock()`](https://ohdsi.github.io/Picard/reference/setDbConfigBlock.md)
  : set the config block for a database
- [`setOutputFolder()`](https://ohdsi.github.io/Picard/reference/setOutputFolder.md)
  : Set Output Folder for Task
- [`setupAtlasSecretsKeyring()`](https://ohdsi.github.io/Picard/reference/setupAtlasSecretsKeyring.md)
  : Set up Atlas/WebAPI keyring credentials
- [`setupDbSecretsKeyring()`](https://ohdsi.github.io/Picard/reference/setupDbSecretsKeyring.md)
  : Set up keyring-based credentials for a database server

## Loading Functions

Functions for loading and importing data (load\*)

- [`loadCohortManifest()`](https://ohdsi.github.io/Picard/reference/loadCohortManifest.md)
  : Load Cohort Manifest from SQLite Database
- [`loadConceptSetManifest()`](https://ohdsi.github.io/Picard/reference/loadConceptSetManifest.md)
  : Load Concept Set Manifest

## Utility Functions

Other utility and helper functions

- [`addBlock()`](https://ohdsi.github.io/Picard/reference/addBlock.md) :
  Add a config block to an existing config.yml
- [`agentSaveWork()`](https://ohdsi.github.io/Picard/reference/agentSaveWork.md)
  : Save Work for Agents (Automated, No Prompts)
- [`cleanColumnNames()`](https://ohdsi.github.io/Picard/reference/cleanColumnNames.md)
  : Clean Column Names to Standard Format
- [`clearPendingPR()`](https://ohdsi.github.io/Picard/reference/clearPendingPR.md)
  : Clear Pending PR Reference
- [`displayTaskStatusReport()`](https://ohdsi.github.io/Picard/reference/displayTaskStatusReport.md)
  : Display Task Status Report
- [`documentDependencies()`](https://ohdsi.github.io/Picard/reference/documentDependencies.md)
  : Document Dependencies
- [`editSecrets()`](https://ohdsi.github.io/Picard/reference/editSecrets.md)
  : Edit the secrets.yml file
- [`expandManifestTags()`](https://ohdsi.github.io/Picard/reference/expandManifestTags.md)
  : Expand JSON Tags to Columns
- [`formatFloats()`](https://ohdsi.github.io/Picard/reference/formatFloats.md)
  : Format Float Columns
- [`formatPercentages()`](https://ohdsi.github.io/Picard/reference/formatPercentages.md)
  : Format Percentage Columns
- [`generateCohorts()`](https://ohdsi.github.io/Picard/reference/generateCohorts.md)
  : Generate Cohorts for Pipeline Execution
- [`importAndBind()`](https://ohdsi.github.io/Picard/reference/importAndBind.md)
  : Import and Bind Results by Version and Task
- [`importAtlasConceptSets()`](https://ohdsi.github.io/Picard/reference/importAtlasConceptSets.md)
  : Import CIRCE Concept Sets from ATLAS
- [`migrateCohortManifest()`](https://ohdsi.github.io/Picard/reference/migrateCohortManifest.md)
  : Migrate Old CohortManifest SQLite to New Schema
- [`migrateConceptSetManifest()`](https://ohdsi.github.io/Picard/reference/migrateConceptSetManifest.md)
  : Migrate Old ConceptSetManifest SQLite to New Schema
- [`pivotForComparison()`](https://ohdsi.github.io/Picard/reference/pivotForComparison.md)
  : Pivot Data Wide for Comparison
- [`plotCohortGraph()`](https://ohdsi.github.io/Picard/reference/plotCohortGraph.md)
  : Plot Cohort Dependency Graph
- [`prepareDisseminationData()`](https://ohdsi.github.io/Picard/reference/prepareDisseminationData.md)
  : Prepare Dissemination Data with Chained Transformations
- [`recordTaskExecution()`](https://ohdsi.github.io/Picard/reference/recordTaskExecution.md)
  : Record Task Execution Status
- [`resetCohortManifest()`](https://ohdsi.github.io/Picard/reference/resetCohortManifest.md)
  : Reset Cohort Manifest
- [`resetConceptSetManifest()`](https://ohdsi.github.io/Picard/reference/resetConceptSetManifest.md)
  : Reset Concept Set Manifest
- [`restoreEnvironment()`](https://ohdsi.github.io/Picard/reference/restoreEnvironment.md)
  : Restore Environment from Lockfile
- [`reviewExportSchema()`](https://ohdsi.github.io/Picard/reference/reviewExportSchema.md)
  : Review Export File Schema
- [`reviewKeyringCredentials()`](https://ohdsi.github.io/Picard/reference/reviewKeyringCredentials.md)
  : Review keyring credentials for picard service
- [`runPostProcessing()`](https://ohdsi.github.io/Picard/reference/runPostProcessing.md)
  : Run Post-Processing Pipeline with Merging and QC
- [`runTestPostProcessing()`](https://ohdsi.github.io/Picard/reference/runTestPostProcessing.md)
  : Run Post-Processing Pipeline for test mode
- [`saveWork()`](https://ohdsi.github.io/Picard/reference/saveWork.md) :
  Sync Local Work to Remote Branch
- [`shouldRerunTask()`](https://ohdsi.github.io/Picard/reference/shouldRerunTask.md)
  : Check if Task Needs to be Rerun
- [`snapshotEnvironment()`](https://ohdsi.github.io/Picard/reference/snapshotEnvironment.md)
  : Snapshot Current Environment State
- [`sourceDisseminationScripts()`](https://ohdsi.github.io/Picard/reference/sourceDisseminationScripts.md)
  : Source Dissemination Scripts
- [`sourceInputBuilderScripts()`](https://ohdsi.github.io/Picard/reference/sourceInputBuilderScripts.md)
  : Source Pre-Pipeline Input Builder Scripts
- [`standardizeDataTypes()`](https://ohdsi.github.io/Picard/reference/standardizeDataTypes.md)
  : Standardize Data Types
- [`templateAtlasCredentials()`](https://ohdsi.github.io/Picard/reference/templateAtlasCredentials.md)
  : Template for setting Atlas Credentials
- [`testStudyPipeline()`](https://ohdsi.github.io/Picard/reference/testStudyPipeline.md)
  : Test Study Pipeline
- [`testStudyTask()`](https://ohdsi.github.io/Picard/reference/testStudyTask.md)
  : Test a Single Study Task
- [`updateStudyVersion()`](https://ohdsi.github.io/Picard/reference/updateStudyVersion.md)
  : Function to update the study version
- [`validateCohortResults()`](https://ohdsi.github.io/Picard/reference/validateCohortResults.md)
  : Validate Cohort Results Completeness
- [`validateConfigYaml()`](https://ohdsi.github.io/Picard/reference/validateConfigYaml.md)
  : Validate config.yml File Structure
- [`validateStudyTask()`](https://ohdsi.github.io/Picard/reference/validateStudyTask.md)
  : Validate Study Task Script
- [`validateUlyssesStructure()`](https://ohdsi.github.io/Picard/reference/validateUlyssesStructure.md)
  : Validate Ulysses Repository Structure
- [`zipAndArchive()`](https://ohdsi.github.io/Picard/reference/zipAndArchive.md)
  : Zip and Archive results from a study execution
