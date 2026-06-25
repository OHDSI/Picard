# picard 0.0.5

## Manifest API Enhancements

**API CHANGES**:
- `loadCohortManifest()` and `loadConceptSetManifest()` now include `autoSync` (default `TRUE`) and `verbose` (default `TRUE`) parameters for controlling manifest initialization behavior
- `resetCohortManifest()` and `resetConceptSetManifest()` now include `archive` parameter (default `TRUE`) to create timestamped backups of manifest database and files before reset
- `importAtlasCohorts()` and `importAtlasConceptSets()` **API CHANGE**: changed from file-based (`conceptSetsLoadPath = "path/to/file.csv"`) to dataframe-based (`conceptSetsLoad = dataframe, atlasConnection = NULL`). Users now call `readr::read_csv()` first, then pass the resulting dataframe. Dataframe must contain columns: `atlasId`, `label`, `category` (plus optional tag columns)

## Input Builder Scripts

**Pre-Pipeline Input Loading System** (`sourceInputScripts(verbose = TRUE)`):
- Auto-discovery and sourcing of builder scripts for pre-processing the pipeline
- Loads concept set definitions from `inputs/conceptSets/R/` directory (sourced first)
- Loads cohort definitions from `inputs/cohorts/R/` directory (sourced second)
- Called automatically from `main.R` before the main pipeline executes

**Six Template Builder Scripts** (auto-populated in project init):
1. **Concept Set Builders**:
   - `importAtlas.R` — bulk import from ATLAS via CSV + WebAPI connection
   - `importCapr.R` — programmatic definition using Capr functions
2. **Cohort Builders**:
   - `importAtlas.R` — bulk import from ATLAS via CSV + WebAPI connection
   - `importCapr.R` — programmatic cohort definitions with Capr
   - `importSql.R` — register hand-written SQL cohorts from `inputs/cohorts/sql/`
   - `buildDependentCohorts.R` — create derived cohorts (temporal, union, complement, O-Prior-T, T-Prior-O, censor)

**Flexible Design**:
- Scripts are sourced in alphabetical order; users can delete unused templates without breaking `main.R`
- Auto-discovery gracefully skips missing directories, enabling project-specific customization
- All manifest definitions loaded before task execution; enables dependency tracking and change detection

## Sync and Update Method Improvements

**Sync Methods** (`$syncManifest(strict_mode=TRUE)`):
- Both `CohortManifest` and `ConceptSetManifest` now include `strict_mode` parameter to control strictness of file/database reconciliation
- Reconciles files on disk (`json/`, `sql/`) against SQLite; flags missing files as deleted, detects hash changes, reports unregistered files
- Integrated into `loadCohortManifest()` and `loadConceptSetManifest()` via `autoSync` parameter

**Update Methods** (segmented by field):
- `$updateCohortLabel()`, `$updateCohortCategory()`, `$updateCohortTags()` for `CohortManifest`
- `$updateConceptSetLabel()`, `$updateConceptSetCategory()`, `$updateConceptSetTags()` for `ConceptSetManifest`
- Each method updates a single field and syncs changes to both SQLite and in-memory manifest object
- All methods return invisible NULL for consistency with R6 patterns

## Manifest-to-Filesystem 1:1 Correspondence Principle

**Core Architecture**:
Every cohort/concept set in the SQLite manifest database maintains a 1:1 correspondence with exactly one definition file on disk:
- **Circe/ATLAS cohorts**: stored as `.json` file in `json/` directory
- **SQL cohorts**: stored as `.sql` file in `sql/` directory  
- **Derived cohorts**: generated `.sql` files in `sql/derived/` directory with dependency metadata in SQLite

**Data Consistency Guarantees**:
- Each record in the manifest has a `file_path` column pointing to its corresponding disk file
- File hashes are stored in SQLite and compared during `$syncManifest()` to detect out-of-sync changes
- Soft deletes (`status = 'deleted'`) preserve both the database record and file for audit trail
- Hard deletes (if performed) remove both record and file atomically

**Sync Integrity**:
- `$syncManifest(strict_mode=TRUE)` enforces strict reconciliation: files on disk must match database records
- Unregistered files on disk are flagged as orphaned; missing files for active records are flagged as missing
- `autoSync=TRUE` in load functions ensures manifest is synchronized with disk on startup
- This 1:1 principle prevents silent data loss and enables reliable recovery workflows

## Two-Phase ATLAS Synchronization Workflow

**Phase 1: Detection** (`$checkAtlasCohorts()` / `$checkAtlasConceptSets()`):
- Read-only operation: compares local hashes against remote ATLAS definitions
- Returns a tibble showing which cohorts/concept sets have changed remotely
- No modifications to local state; useful for mid-cycle discovery
- Call parameters: `atlasConnection = NULL` (uses stored connection if available)

**Phase 2: Update** (`$updateAtlasCohorts()` / `$updateAtlasConceptSets()`):
- Downloads definition JSON files from ATLAS for all cohorts/concept sets with remote changes
- Updates JSON files on disk in `json/` directory
- For `CohortManifest` only: **automatically cascades stale status** to all downstream derived cohorts that depend on updated base cohorts
- Derived cohorts are automatically **re-executed on next `generateCohorts()` run** without user intervention

**Workflow Automation**:
- No need for separate "rebuild derived cohorts" step after ATLAS updates
- Dependent cohort execution order is automatically resolved via topological sort
- Users can chain checks and updates seamlessly in scripts: `manifest$checkAtlasCohorts()` → review results → `manifest$updateAtlasCohorts()`

## Documentation

- Comprehensive new agent file `inst/agent/04a-manifest-overview.md` provides deep-dive architecture guide, mid-cycle workflows, and ATLAS synchronization patterns
- Updated vignettes `loading_inputs.Rmd` and `manifest_overview.Rmd` with correct API signatures and two-phase ATLAS workflow documentation
- Corrected all documentation to use proper R6 method call syntax (`manifest$updateCohortLabel(...)` instead of standalone function `updateCohortManifest(...)`)

## Bug Fixes & Clarifications

- ConceptManifest Updates
    - bug fix for conceptSetManifest category checkmate (using domain requirements)
    - add function to expandManifestTags to help subsetting
- Removed non-existent method references (`removeCohort()` for CohortManifest; deletion uses soft delete via `deleteCohort(id, confirm=FALSE)`)
- Clarified soft delete behavior for both cohort and concept set manifests with audit trail preservation
- instill parity in the methods across the ConceptSetManifest and CohortManifest classes


# picard 0.0.4

- move login credentials to secrets file
- Correct the Dependent Cohort builders
- Add a query tool for category now that it is not a tag
- reorganize cohort generation to make it easier to debug
- Add `stopIfExists` to `$addSqlCohort` method allowing user to overwrite a file they worked on
- **API CHANGE**: rename `orchestratePipelineExport` to `runPostProcessing`, for test mode it is `testOrchestratePipelineExport` to `runTestPostProcessing`.

## New Features

- `$buildCustomDependentCohort(filePath, label, category, cohortIds, tags)` — new
  `CohortManifest` method for registering a user-supplied `.sql` file as a derived
  cohort with explicit dependencies. The SQL is copied to `derived/` and the cohort
  is registered with `cohort_type = "custom"` and `depends_on` set. The Phase 1.1
  skip-logic (`length(parent_ids) > 0`) handles dependency-aware hashing automatically.
- Move credentials to secrets file using `editSecrets()` and helpers for keyring `setupDbSecretsKeyring` and `setupAtlasSecretsKeyring`

## Bug Fixes

- **Custom cohort skip-logic** (`R/cohort_builders.R`): `evaluate_cohort_skip_status()`
  now checks `length(parent_ids) > 0` instead of a hardcoded list of cohort types.
  Custom cohorts with `depends_on` set now use dependency-aware hash comparison.
  (#p2.1)
- **`insert_cohort()` validation** (`R/CohortManifest.R`): Added validation enforcing
  that `circe`/`custom` cohorts cannot have dependencies, and derived cohort types
  must specify `depends_on`. (#p2.2)
- **Bare `stop(e)` re-throws** (14 occurrences): Replaced with `cli::cli_abort()`
  across `R/Ulysses.R` (12×), `R/git.R` (1×), and `R/make.R` (1×) to preserve
  error call context. (#p3)
- **SQL injection vectors** (`R/cohort_builders.R`, `R/manifest_helpers.R`): Checksum
  queries now use `SqlRender::render()` for parameterized SQL on OMOP CDM connections;
  `cascadeStaleDownstream()` uses parameterized `?` placeholders for SQLite. (#p4)

# picard 0.0.3.1

- minor bug fixes 
- `$addCirceCohort` add a circe cohort from the json folder to the manifest

# picard 0.0.3

## CohortManifest Reboot

`CohortManifest` has been fully redesigned as an R6 class backed by SQLite. All cohort
lifecycle management — adding, building, querying, syncing, deleting, and generating —
is now encapsulated as methods on the class. The previous functional approach
(`manifest_cohorts.R`, `manifest_conceptSets.R`) has been removed.

### Adding Cohorts

- `$addAtlasCohort(atlasId, label, category, tags, atlasConnection)` — fetch a single cohort JSON from ATLAS and register it
- `$addCaprCohort(caprCohort, label, category, tags)` — export a Capr `Cohort` object to JSON and register it
- `$addSqlCohort(filePath, label, category, tags)` — register an existing `.sql` file; validates portability
- `$importAtlasCohorts(atlasConnection, cohortsLoadPath)` — batch import via `cohortsLoad.csv`; extra columns become tags
- `$setAtlasConnection(atlasConnection)` / `$getAtlasConnection()` — store a connection on the manifest so it does not need to be passed on every call
- `getAtlasConnection()` is now an exported standalone function (replaces `setAtlasConnection()` which is deprecated)

### Building Dependent Cohorts

All dependent cohort methods are now on the `CohortManifest` class. Dependency metadata is stored in SQLite
(`depends_on`, `dependency_rule` columns); no sidecar JSON files. When a parent's SQL file changes, all
downstream derived cohorts are automatically marked `stale`.

- `$buildUnionCohort(label, cohortIds, category, gapDays)` — era-collapse union of ≥2 cohorts
- `$buildComplementCohort(label, populationCohortId, excludeCohortIds, category, complementType)` — exclude subjects; updated signature; supports `"exclude_any"` (default) and `"exclude_all"`
- `$buildCompositeCohort(label, cohortIds, category, minCohorts)` — intersection requiring membership in ≥ `minCohorts`
- `$buildSubsetCohortTemporal(label, baseCohortId, filterCohortId, category, startWindow, endWindow, endDateType, subsetLimit)` — temporal subset using `SubsetWindowOperator` objects
- `$buildDemographicCohort(label, baseCohortId, category, minAge, maxAge, genderConceptIds, raceConceptIds, ethnicityConceptIds)` — **new**: filter a base cohort by person-level demographics
- `$buildStratifiedCohorts(baseCohortId, strata, labelPrefix, category)` — **new**: split a cohort into N named strata; automatically appends an `Unclassified` stratum covering all non-matching subjects
- Removed: `addDependentCohort()` (replaced entirely by the `build*()` methods above)

### Mid-Cycle Manifest Management

- `$tabulateManifest(filter)` — tabulate manifest to a tibble; filter now accepts `"active"` (default), `"deleted"`, `"stale"`, or `"all"`
- `$syncManifest()` — reconcile files on disk (`json/`, `sql/`) against SQLite; flags missing files as deleted, detects hash changes, reports unregistered files
- `$reviewDependentCohorts()` — **new**: tibble of all derived cohorts with parsed parent labels and rule summaries
- `$reviewStaleCohorts()` — **new**: list all cohorts marked `stale` (parent SQL changed since last build); these are re-executed automatically by `executeCohortGeneration()`
- `$reloadFromDb()` — **new**: refresh the in-memory manifest from SQLite (useful after external DB changes or `resetCohortManifest()`)
- `$statusReport()` — tabular status overview of all active cohorts and their dependencies
- `$validateManifest()` — check file presence for all active cohort records
- `$cleanupMissing(keep_trace)` — soft-delete (`keep_trace = TRUE`) or hard-remove (`keep_trace = FALSE`) cohorts whose files are missing

### Delete API

- `$deleteCohort(id, reason)` — soft delete: marks `status = 'deleted'`, preserves the SQLite record and file on disk; recoverable
- `$removeCohort(id, deleteFile, dropFromCohortTable, confirm)` — **new**: hard, irreversible removal; deletes the SQLite record; optionally deletes the file on disk (`deleteFile = TRUE`) and/or drops rows from the DBMS cohort and checksum tables (`dropFromCohortTable = TRUE`, requires `executionSettings`); requires interactive confirmation or `confirm = TRUE`
- Removed: `permanentlyDeleteCohort()` and `hardDeleteCohort()` — both consolidated into `removeCohort()`

### DBMS Operations

- `$createCohortTables()` — create all cohort-related DBMS tables (main, inclusion, stats, checksum); skips tables that already exist
- `$dropCohortTables(tableTypes)` — drop cohort tables; optionally limit to specific table types
- `$cleanCohortTable()` — for every `status = 'deleted'` cohort, delete its DBMS rows and mark the manifest record `'purged'`
- `$executeCohortGeneration()` — generate cohorts in topological dependency order; skips cohorts whose checksum is unchanged; marks stale derived cohorts for re-execution

### Reset

`resetCohortManifest(scope)` now supports three scopes:

- `"derived"` — drop derived cohort rows from SQLite and delete the `derived/` SQL files; leaves base cohorts and `json/`/`sql/` intact
- `"manifest"` — delete the entire SQLite database; leaves files on disk
- `"full"` — delete SQLite, delete `derived/`, delete `json/` and `sql/` directories, drop DBMS cohort tables

### Visualization

- `plotCohortGraph(manifest)` — **new export**: renders a Mermaid dependency diagram of derived cohorts and their parents
- `visualizeCohortDependencies()` — deprecated; use `plotCohortGraph()` instead

## Pipeline Execution

- `preflightChecklist()` added to `execStudyPipeline()`; validates all prerequisites before a production run
- `postProcess` step now supports test mode (`testMode = TRUE`) to write outputs to a separate test directory
- Cohort tables are distinguished by test mode to prevent test runs from overwriting production cohort data
- Bug fixes in task caching and execution result recording

## Internal

- `R/manifest_cohorts.R` and `R/manifest_conceptSets.R` removed; logic consolidated into `R/manifest_helpers.R`
- `R/buildDependentCohorts.R` refactored; standalone build functions removed in favour of `CohortManifest` methods
- Stale cascade detection: `cascade_stale_downstream()` marks all transitive dependents stale when a parent SQL file hash changes

# picard 0.0.2

- Split production and test mode for pipeline runs
- Add better vignettes for using picard
- bug fixes
- add agent mode to picard
- add keyring compatability to setAtlasConnection


# picard 0.0.1

## New Features

### Core Study Management
- **UlyssesStudy**: R6 class for comprehensive study repository configuration and initialization
- **StudyMeta**: Metadata container for study information including title, therapeutic area, type, contributors, tags, and links
- **ExecutionSettings**: Configuration class for managing execution environment and database connections
- **ExecOptions**: Settings and database connection block management

### Study Repository Initialization
- Automatic R project creation and configuration
- Git repository initialization with remote support
- Standard directory structure creation for study artifacts
- README, NEWS, and configuration file templating
- Quarto documentation setup integration
- Agent skills configuration for repository automation

### Cohort Management
- **CohortDef**: R6 class for defining cohorts with ATLAS specifications
- **CohortManifest**: Management system for cohort collection with validation
- Cohort JSON and SQL file organization
- ATLAS cohort import and integration

### Concept Set Management
- **ConceptSetDef**: R6 class for defining concept sets
- **ConceptSetManifest**: Management system for concept set collections
- Concept set JSON file organization
- ATLAS concept set import and integration

### Study Execution
- Study pipeline orchestration and execution
- Task-based execution framework with status tracking
- Pipeline export functionality
- Result validation and cohort comparison tools

### Data Processing
- Cohort building with temporal and demographic subsetting
- Union and complement cohort operations
- Dissemination data preparation
- Standard data type handling and formatting
- Column name standardization

### Configuration & Integration
- **DbConfigBlock**: Database connection configuration for multiple databases
- DBMS-specific settings (CDM schema, working schema, temp schema)
- Configuration file generation and management
- ATLAS connection setup
- Contributor and team management

### Utilities
- Repository validation framework
- Task history and execution tracking
- Environment hash detection for dependency tracking
- File and directory management utilities
- Archive and export functionality

