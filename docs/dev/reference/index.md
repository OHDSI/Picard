# Package index

## Core Classes

Main R6 classes for package functionality

- [`CohortDef`](https://ohdsi.github.io/Picard/dev/reference/CohortDef.md)
  : CohortDef R6 Class
- [`CohortManifest`](https://ohdsi.github.io/Picard/dev/reference/CohortManifest.md)
  : CohortManifest R6 Class
- [`ConceptSetDef`](https://ohdsi.github.io/Picard/dev/reference/ConceptSetDef.md)
  : ConceptSetDef R6 Class
- [`ConceptSetManifest`](https://ohdsi.github.io/Picard/dev/reference/ConceptSetManifest.md)
  : ConceptSetManifest R6 Class
- [`ContributorLine`](https://ohdsi.github.io/Picard/dev/reference/ContributorLine.md)
  : ContributorLine R6 Class
- [`DbConfigBlock`](https://ohdsi.github.io/Picard/dev/reference/DbConfigBlock.md)
  : DbConfigBlock R6 Class
- [`ExecOptions`](https://ohdsi.github.io/Picard/dev/reference/ExecOptions.md)
  : ExecOptions R6 Class
- [`ExecutionSettings`](https://ohdsi.github.io/Picard/dev/reference/ExecutionSettings.md)
  : ExecutionSettings
- [`StudyMeta`](https://ohdsi.github.io/Picard/dev/reference/StudyMeta.md)
  : StudyMeta R6 Class
- [`UlyssesStudy`](https://ohdsi.github.io/Picard/dev/reference/UlyssesStudy.md)
  : UlyssesStudy R6 Class

## Creation Functions

Functions for creating objects and structures (make\*)

- [`makeExecOptions()`](https://ohdsi.github.io/Picard/dev/reference/makeExecOptions.md)
  : Make ExecOptions for Ulysses
- [`makePrintFriendlyFile()`](https://ohdsi.github.io/Picard/dev/reference/makePrintFriendlyFile.md)
  : Generate Print-Friendly Cohort Documentation from JSON
- [`makeSrcFile()`](https://ohdsi.github.io/Picard/dev/reference/makeSrcFile.md)
  : Create a Source Utility File
- [`makeSrcSqlFile()`](https://ohdsi.github.io/Picard/dev/reference/makeSrcSqlFile.md)
  : Create a SqlRender SQL File
- [`makeStudyMeta()`](https://ohdsi.github.io/Picard/dev/reference/makeStudyMeta.md)
  : Make Study Meta for Ulysses
- [`makeTaskFile()`](https://ohdsi.github.io/Picard/dev/reference/makeTaskFile.md)
  : Function initializing an R file for an analysis task
- [`makeUlyssesStudySettings()`](https://ohdsi.github.io/Picard/dev/reference/makeUlyssesStudySettings.md)
  : Make Ulysses Study Settings

## Initialization Functions

Functions for initializing components (init\*)

- [`initAgentMode()`](https://ohdsi.github.io/Picard/dev/reference/initAgentMode.md)
  : Initialize or Restore Agent Mode for Cloned Repository
- [`initCohortManifest()`](https://ohdsi.github.io/Picard/dev/reference/initCohortManifest.md)
  : Initialize a New Cohort Manifest
- [`initConceptSetManifest()`](https://ohdsi.github.io/Picard/dev/reference/initConceptSetManifest.md)
  : Initialize a New Concept Set Manifest
- [`initializeRenv()`](https://ohdsi.github.io/Picard/dev/reference/initializeRenv.md)
  : Initialize Renv for Project

## Build Functions

Functions for building study components (build\*)

- [`buildComplementCohort()`](https://ohdsi.github.io/Picard/dev/reference/buildComplementCohort.md)
  : Build a Complement Cohort Definition
- [`buildCompositeCohort()`](https://ohdsi.github.io/Picard/dev/reference/buildCompositeCohort.md)
  : Build a Composite Cohort Definition
- [`buildStratifiedCohorts()`](https://ohdsi.github.io/Picard/dev/reference/buildStratifiedCohorts.md)
  : Split a Base Cohort into Multiple Stratified Sub-Cohorts
- [`buildStudyHub()`](https://ohdsi.github.io/Picard/dev/reference/buildStudyHub.md)
  : Build Study Hub
- [`buildSubsetCohortDemographic()`](https://ohdsi.github.io/Picard/dev/reference/buildSubsetCohortDemographic.md)
  **\[deprecated\]** : Build a Demographic Subset Cohort
- [`buildSubsetCohortTemporal()`](https://ohdsi.github.io/Picard/dev/reference/buildSubsetCohortTemporal.md)
  : Build a Subset Cohort Definition (Temporal)
- [`buildUnionCohort()`](https://ohdsi.github.io/Picard/dev/reference/buildUnionCohort.md)
  : Build a Union Cohort Definition

## Create Functions

Functions for creating new objects (create\*)

- [`createAgentBranch()`](https://ohdsi.github.io/Picard/dev/reference/createAgentBranch.md)
  : Create Feature Branch for Agent Work
- [`createBlankCohortsLoadFile()`](https://ohdsi.github.io/Picard/dev/reference/createBlankCohortsLoadFile.md)
  : Create Blank Cohorts Load File
- [`createBlankConceptSetsLoadFile()`](https://ohdsi.github.io/Picard/dev/reference/createBlankConceptSetsLoadFile.md)
  : Create Blank Concept Sets Load File
- [`createExecutionSettings()`](https://ohdsi.github.io/Picard/dev/reference/createExecutionSettings.md)
  : Create an ExecutionSettings object and set its attributes
- [`createExecutionSettingsFromConfig()`](https://ohdsi.github.io/Picard/dev/reference/createExecutionSettingsFromConfig.md)
  : Create ExecutionSettings from Config Block
- [`createPullRequest()`](https://ohdsi.github.io/Picard/dev/reference/createPullRequest.md)
  : Create Pull Request Metadata
- [`createSubsetEndWindow()`](https://ohdsi.github.io/Picard/dev/reference/createSubsetEndWindow.md)
  : Create a Subset End Window Operator
- [`createSubsetStartWindow()`](https://ohdsi.github.io/Picard/dev/reference/createSubsetStartWindow.md)
  : Create a Subset Start Window Operator

## Execution Functions

Functions for executing study tasks (exec\*)

- [`execStudyPipeline()`](https://ohdsi.github.io/Picard/dev/reference/execStudyPipeline.md)
  : Production Study Pipeline Execution

## Configuration Functions

Functions for configuration and setup (set\*)

- [`getAtlasConnection()`](https://ohdsi.github.io/Picard/dev/reference/getAtlasConnection.md)
  : Get Atlas Connection
- [`getTaskRunSummary()`](https://ohdsi.github.io/Picard/dev/reference/getTaskRunSummary.md)
  : Get Task Run Summary
- [`setAtlasConnection()`](https://ohdsi.github.io/Picard/dev/reference/setAtlasConnection.md)
  : Set Atlas Connection (Deprecated)
- [`setContributor()`](https://ohdsi.github.io/Picard/dev/reference/setContributor.md)
  : Set Ulysses Contributor
- [`setDbConfigBlock()`](https://ohdsi.github.io/Picard/dev/reference/setDbConfigBlock.md)
  : set the config block for a database
- [`setOutputFolder()`](https://ohdsi.github.io/Picard/dev/reference/setOutputFolder.md)
  : Set Output Folder for Task

## Loading Functions

Functions for loading and importing data (load\*)

- [`loadCohortManifest()`](https://ohdsi.github.io/Picard/dev/reference/loadCohortManifest.md)
  : Load Cohort Manifest from SQLite Database
- [`loadConceptSetManifest()`](https://ohdsi.github.io/Picard/dev/reference/loadConceptSetManifest.md)
  : Load Concept Set Manifest

## Utility Functions

Other utility and helper functions

- [`agentSaveWork()`](https://ohdsi.github.io/Picard/dev/reference/agentSaveWork.md)
  : Save Work for Agents (Automated, No Prompts)
- [`cleanColumnNames()`](https://ohdsi.github.io/Picard/dev/reference/cleanColumnNames.md)
  : Clean Column Names to Standard Format
- [`clearPendingPR()`](https://ohdsi.github.io/Picard/dev/reference/clearPendingPR.md)
  : Clear Pending PR Reference
- [`defineCustomCohort()`](https://ohdsi.github.io/Picard/dev/reference/defineCustomCohort.md)
  : Define (Enrich) a Custom SQL Cohort (Deprecated)
- [`displayTaskStatusReport()`](https://ohdsi.github.io/Picard/dev/reference/displayTaskStatusReport.md)
  : Display Task Status Report
- [`documentDependencies()`](https://ohdsi.github.io/Picard/dev/reference/documentDependencies.md)
  : Document Dependencies
- [`formatFloats()`](https://ohdsi.github.io/Picard/dev/reference/formatFloats.md)
  : Format Float Columns
- [`formatPercentages()`](https://ohdsi.github.io/Picard/dev/reference/formatPercentages.md)
  : Format Percentage Columns
- [`generateCohorts()`](https://ohdsi.github.io/Picard/dev/reference/generateCohorts.md)
  : Generate Cohorts for Pipeline Execution
- [`importAndBind()`](https://ohdsi.github.io/Picard/dev/reference/importAndBind.md)
  : Import and Bind Results by Version and Task
- [`importAtlasCohorts()`](https://ohdsi.github.io/Picard/dev/reference/importAtlasCohorts.md)
  : Import CIRCE Cohort Definitions from ATLAS
- [`importAtlasConceptSets()`](https://ohdsi.github.io/Picard/dev/reference/importAtlasConceptSets.md)
  : Import CIRCE Concept Sets from ATLAS
- [`migrateCohortManifest()`](https://ohdsi.github.io/Picard/dev/reference/migrateCohortManifest.md)
  : Migrate Old CohortManifest SQLite to New Schema
- [`orchestratePipelineExport()`](https://ohdsi.github.io/Picard/dev/reference/orchestratePipelineExport.md)
  : Orchestrate Pipeline Export with Merging and QC
- [`pivotForComparison()`](https://ohdsi.github.io/Picard/dev/reference/pivotForComparison.md)
  : Pivot Data Wide for Comparison
- [`placeHolderExecOptions()`](https://ohdsi.github.io/Picard/dev/reference/placeHolderExecOptions.md)
  : set the execOptions as placeholder.
- [`plotCohortGraph()`](https://ohdsi.github.io/Picard/dev/reference/plotCohortGraph.md)
  : Plot Cohort Dependency Graph
- [`prepareDisseminationData()`](https://ohdsi.github.io/Picard/dev/reference/prepareDisseminationData.md)
  : Prepare Dissemination Data with Chained Transformations
- [`recordTaskExecution()`](https://ohdsi.github.io/Picard/dev/reference/recordTaskExecution.md)
  : Record Task Execution Status
- [`resetCohortManifest()`](https://ohdsi.github.io/Picard/dev/reference/resetCohortManifest.md)
  : Reset Cohort Manifest
- [`resetConceptSetManifest()`](https://ohdsi.github.io/Picard/dev/reference/resetConceptSetManifest.md)
  : Reset Concept Set Manifest
- [`restoreEnvironment()`](https://ohdsi.github.io/Picard/dev/reference/restoreEnvironment.md)
  : Restore Environment from Lockfile
- [`reviewExportSchema()`](https://ohdsi.github.io/Picard/dev/reference/reviewExportSchema.md)
  : Review Export File Schema
- [`saveWork()`](https://ohdsi.github.io/Picard/dev/reference/saveWork.md)
  : Sync Local Work to Remote Branch
- [`shouldRerunTask()`](https://ohdsi.github.io/Picard/dev/reference/shouldRerunTask.md)
  : Check if Task Needs to be Rerun
- [`snapshotEnvironment()`](https://ohdsi.github.io/Picard/dev/reference/snapshotEnvironment.md)
  : Snapshot Current Environment State
- [`standardizeDataTypes()`](https://ohdsi.github.io/Picard/dev/reference/standardizeDataTypes.md)
  : Standardize Data Types
- [`templateAtlasCredentials()`](https://ohdsi.github.io/Picard/dev/reference/templateAtlasCredentials.md)
  : Template for setting Atlas Credentials
- [`testOrchestratePipelineExport()`](https://ohdsi.github.io/Picard/dev/reference/testOrchestratePipelineExport.md)
  : Test Orchestrate Pipeline Export
- [`testStudyPipeline()`](https://ohdsi.github.io/Picard/dev/reference/testStudyPipeline.md)
  : Test Study Pipeline
- [`testStudyTask()`](https://ohdsi.github.io/Picard/dev/reference/testStudyTask.md)
  : Test a Single Study Task
- [`updateCohortMetadata()`](https://ohdsi.github.io/Picard/dev/reference/updateCohortMetadata.md)
  : Update the Label and/or Tags of an Existing Manifest Cohort
- [`updateStudyVersion()`](https://ohdsi.github.io/Picard/dev/reference/updateStudyVersion.md)
  : Function to update the study version
- [`validateCohortResults()`](https://ohdsi.github.io/Picard/dev/reference/validateCohortResults.md)
  : Validate Cohort Results Completeness
- [`validateConfigYaml()`](https://ohdsi.github.io/Picard/dev/reference/validateConfigYaml.md)
  : Validate config.yml File Structure
- [`validateStudyTask()`](https://ohdsi.github.io/Picard/dev/reference/validateStudyTask.md)
  : Validate Study Task Script
- [`validateUlyssesStructure()`](https://ohdsi.github.io/Picard/dev/reference/validateUlyssesStructure.md)
  : Validate Ulysses Repository Structure
- [`visualizeCohortDependencies()`](https://ohdsi.github.io/Picard/dev/reference/visualizeCohortDependencies.md)
  : Visualize Cohort Dependencies (Deprecated)
- [`zipAndArchive()`](https://ohdsi.github.io/Picard/dev/reference/zipAndArchive.md)
  : Zip and Archive results from a study execution
