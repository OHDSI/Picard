# picard 0.0.7

## New Features

### Code State Escape Hatches

- Scoped escape hatches for the "Code state" pre-flight check, for study repos where files under `inputs/` churn without a deliberate edit. Both default to off, so unchanged studies get exactly the previous behavior.
  - `execStudyPipeline(ignoreUncommittedPaths = ...)` tolerates uncommitted changes confined to the listed repo-relative paths; changes anywhere else (notably `analysis/`) still fail the check. The list can be set once per study as `ignoreUncommittedPaths` in the `default:` block of `config.yml`, with the argument overriding it for a single run.
  - `execStudyPipeline(skipCodeStateCheck = TRUE)` skips the check entirely as a last resort. Deliberately not settable from `config.yml`.
  - Neither hatch is silent: `Code state` is reported as a **warning** rather than a pass, a banner names every ignored file, and the pipeline log records the code state and commit SHA.
  - `exec/logs/task_run_history.csv` gains `commit_sha` and `code_state` columns (`clean`, `dirty-ignored`, `unverified-skipped`, `unverified-test-mode`, `unrecorded`) so the audit trail never implies a clean tree when the tree was not clean. Existing history files are read and back-filled as `unrecorded`.

### Tabulate and View Manifest

- Added `viewManifest()` convenience method for both `CohortManifest` and `ConceptSetManifest` to interactively explore manifest metadata in RStudio viewer with streamlined columns (id, label, category, tags, file_path).
- Enhanced `tabulateManifest()` with `tags_format` parameter supporting three formats: `"nested"` (default, parsed tags as tibble with tag_name/tag_value), `"json"` (raw JSON string for backward compatibility), and `"wide"` (expanded tags as individual columns for spreadsheet-like analysis).

### Building a disseminationEnv Interactively

- Added `createDisseminationEnv()`, which returns the `disseminationEnv` object a dissemination script receives (`pipelineVersion`, `databaseIds`, `outputPath`, `resultsPath`) without having to run `sourceDisseminationScripts()` first, so a script can be tested as it is written (see Issue #86). `sourceDisseminationScripts()` now builds its environment through the same function, so the two cannot drift.

## Bug Fixes

- Fixed several problems with the `'stale'` cohort status (see Issue #74). `'stale'` now consistently means "registered, but needs regenerating", rather than removing a cohort from the study:
  - Re-running a derived cohort builder (e.g. `addDependentCustomCohort()`, `buildUnionCohort()`) with `stopIfExists = FALSE` and unchanged inputs no longer marks the cohort — and everything downstream of it — stale. Staleness is now cascaded only on a real definition change (content hash, file path, parents, or build rule), and a metadata-only edit no longer forces regeneration.
  - Stale cohorts are once again returned by `tabulateManifest(filter = "active")` and therefore by all `query...()` methods, so they can be queried by label/tag/category and used as parents for new derived cohorts.
  - `generateCohorts()` now lists stale cohorts in its confirmation prompt (they are exactly the cohorts that need generating) and flags them as such.
  - `print()` and `getManifestStatus()` count stale cohorts as registered and break them out separately; `getManifestStatus()` gains `stale_count`.
  - Fixed `viewManifest()` erroring on an undefined `tags_format` argument; it now also shows the `status` column.
- Manifest tag parsing no longer assumes the `tags` column holds a JSON string (see Issue #78). The `query*ByTagName()` methods default to `tags_format = "nested"`, which returns tags as a `tag_name`/`tag_value` tibble, so internal callers that re-parsed that column failed with `Argument 'txt' must be a JSON string, URL or file.` This broke `importAtlasCohorts()`/`importAtlasConceptSets()` (and therefore `sourceInputBuilderScripts()`), as well as `listAllUniqueTags()` and `getTagValuesSummary()`. Tag parsing now goes through a shared helper that accepts JSON strings, nested tibbles, and already-parsed lists, and treats missing/empty/malformed tags as no tags.
- add `$queryConceptSetsByCategory()` it was missing
- Pipeline pre-flight checks were impossible to pass (#84):
  - The manifest metadata writers issued an `UPDATE` even when every value already matched the stored row, bumping `updated_at` and rewriting `cohortManifest.sqlite` / `conceptSetManifest.sqlite` on every metadata refresh and every ATLAS re-import. Unchanged assignments are now dropped, so a re-run leaves the manifest files byte-identical and `validateCodeState()` no longer sees uncommitted changes. `cascadeStaleDownstream()` likewise skips rows that are already stale.
  - `validateEnvironment()` always reported "Environment drift detected!" because it tested `renv::status()` for `NULL`, and `renv::status()` always returns a list. It now reads the `synchronized` flag and compares the library and lockfile package records, and treats source-only mismatches as a warning rather than a blocker.
  - `runPreflightChecks()` ran `renv::snapshot()` immediately after validating that the working tree was clean, so the check could dirty the tree it had just approved and leave the next run failing its code-state check. The lockfile is now recorded rather than refreshed; keeping `renv.lock` current is the analyst's call, via `snapshotEnvironment()`.
- add `stopIfExists` option to ATLAS csv load builders (see Issue #65)
- Custom dependent cohort builder is now consistent with the other dependent cohort builders - the rendered SQL query is written to the file system, and it accepts cohort objects as inputs instead of IDs. 
- Custom dependent cohort builder now also allows user to specify non-cohort-ID params, so the rendered SQL query can be generated in a single function call (see Issue #66)
- Builder console messages clarified (see Issue #70)
- `dplyr::select(-.data$tags_list)` in the tag-expansion helpers replaced with `select(-"tags_list")`; use of `.data` in tidyselect expressions was deprecated in tidyselect 1.2.0 and would eventually have errored.
- on `resetManifest` turn archive default to FALSE
- Fixed two dissemination bugs (see Issue #87):
  - `prepareDisseminationData()` asserted that four concatenated logical flags had length 1, so it aborted on every call — including all-default calls — and the formatting step could never run.
  - The dissemination script template checked merged results for a `database_id` column, but `importAndBind()` labels them with camelCase `databaseId`, so the check was always false. The later references to `database_id` are correct, as they operate on data already passed through `cleanColumnNames()`.
- `standardizeDataTypes()` no longer discards columns it cannot coerce. The default `"_id$"` rule matched the character `database_id` column and `as.integer()` silently turned it into `NA`, since failed coercion raises a warning rather than an error. A conversion that would turn a non-missing value into `NA` is now skipped and reported.
- Refactor `query...Manifest` methods to use `$tabulateManifest()` internally to be more consistent. 
- Show current manifest id after import (see Issue #68)
- remove function forced tags `route = atlas` or `route = capr` (See Issue #67)
- in `$grabConceptInfoFromSet()` change input to conceptSetRef which accepts either a manifest id or a label (See issue #56)
- Add task prefix to the `importAndBind()` save to avoid similar output names between tasks.
- Concept sets fetched from ATLAS came back with their concepts in a nondeterministic order, so an unchanged definition serialized to different JSON — and a different content hash — on every fetch, dirtying the study repo's git status (part of #84). Concept set expressions are now canonicalized before serialization: items are ordered by `CONCEPT_ID` (ties broken by vocabulary, code and inclusion flags) and circe `ConceptSets` by their `id`. Ordering is left untouched when any concept set lacks a usable `id`, so `CodesetId` references cannot break.
- Add method to ExecutionSettings to `reviewConnectionDetails()` pulls the connectionDetails used. 
- Modify `getServerCredentials()` to not evaluate full yml file, only pull the specific block and evaluate (See issue #30, #33). 
- Fix `makeDisseminationScript()` change the glue brackets to carrots
- Fix bug in `$updateAtlasCohorts()`/`$updateAtlasConceptSets()` to use tags in json mode after tab format change. 
- Regenerated `inst/agent/05-manifest-management.md` from `vignettes/manifest_management.Rmd`. It had not been synced since `viewManifest()` and the `tabulateManifest(tags_format = ...)` options were added, so agents in generated study repos were reading stale manifest guidance.
- `execStudyPipeline()`/`testStudyPipeline()` no longer go silent during a run (see Issue #85). `execute_pipeline()` used `sink(type = "output")` to capture console output into the pipeline log, which redirected every `cli` info bullet and error away from the console for the entire run — nothing showed up live, including the detail of a task's actual error. The sink is removed entirely: console output now streams normally, and the log file is instead written explicitly with high-level milestones (config block/task start, success, failure) plus a full error detail block (class, call, message) on failure. Separately, `execute_task()` was calling `stop()` from inside its per-expression error handler, which skipped the subsequent `recordTaskExecution(..., errorMessage = ...)` call entirely — so `task_run_history.csv` never recorded the real error message for a failed task, only whatever generic message the caller happened to re-throw. The detailed message is now recorded correctly.
- Improved cohort-generation reporting (see Issue #77): failures now use prominent danger-level messages with the failed cohort, label, and underlying error, remaining cohorts are reported as not generated, and the final summary says generation failed when appropriate. The cohort lookup now checks for missing manifest entries before accessing their fields, and cancellation guidance points to builder scripts and manifest methods instead of only `cohortsLoad.csv`.
- `generateCohorts()` now delegates table creation to `executeCohortGeneration(confirm = FALSE)`, avoiding duplicate table checks and connection cycles while still creating missing tables automatically. The full cohort-count table is no longer printed to the console; a compact count summary and the saved `cohortCounts.csv` path are reported instead.
- `initUlyssesRepo()` now aborts when its target repository directory already exists, preventing initialization from overwriting an existing repository.

# picard 0.0.6

## New Features

### Custom Dependent SQL Cohorts

- Added `$addDependentCustomCohort(filePath, label, category, dependentCohortIdList, tags)` to register hand-written SQL cohorts that depend on one or more existing manifest cohorts.
- Introduced `custom_derived` as an explicit cohort type for dependency-aware custom SQL, distinct from base `custom` SQL cohorts added with `$addSqlCohort()`.
- Removed the older `buildCustomDependentCohort()` pathway in favor of a single add-style workflow for dependent custom SQL.
- `dependentCohortIdList` is now stored as named dependency metadata and reused at execution time, so user-defined SqlRender placeholders such as `@inc_cohort_id`, `@exc_cohort_id`, or any other non-reserved parameter names can be injected from manifest metadata.
- Dependency-aware custom SQL must preserve the standard Picard cohort write contract by deleting from and inserting into `@target_database_schema.@target_cohort_table` using `@target_cohort_id`.
- Execution logic now treats `custom_derived` like other derived cohorts for dependency-hash comparison, checksum persistence, and stale-cascade behavior rather than using raw SQL hash logic.
- Dependent cohort review and generation summaries now include `custom_derived` cohorts explicitly.
- bug fix to deal with named list of dependent cohort ids

### Derived Cohort Builder API (Entry-First)

- **API CHANGE**: derived cohort builders in `build_dependent_cohorts.R` now support entry-row inputs (from `queryCohortsByLabel()` and similar query methods) as the preferred interface instead of raw cohort IDs.
- Updated builders include: `$buildSubsetCohortTemporal()`, `$buildUnionCohort()`, `$buildComplementCohort()`, `$buildCompositeCohort()`, `$buildDemographicCohort()`, `$buildStratifiedCohorts()`, `$buildOPriorT()`, `$buildTPriorO()`, and `$buildCensorCohort()`.
- Legacy ID-based arguments remain supported for backward compatibility, with migration guidance warnings when using ID routes.
- Added input-route validation to enforce mutually exclusive usage of ID arguments vs entry arguments within each build call.

### Comprehensive Tag Management API for CohortManifest and ConceptSetManifest

#### New Tag Manipulation Functions (Both Manifests)

- `$addCohortTag(cohortId, tagName, tagValue)` / `$addConceptSetTag()` - Add a single tag non-destructively
- `$removeConceptSetTag(conceptSetId, tagName)` / `$removeCohortTag()` - Remove a specific tag from a cohort/concept set
- `$modifyCohortTagValue(cohortId, tagName, newValue)` / `$modifyConceptSetTagValue()` - Update an existing tag value
- `$getCohortTags(cohortId)` / `$getConceptSetTags()` - Retrieve all tags for a manifest entry as a named list
- `$mergeTagsIntoCohort(cohortId, newTags)` / `$mergeTagsIntoConceptSet()` - Additive tag merge (preserves existing unspecified tags)
- `$listAllUniqueTags()` - Discover all unique tag names in use across the manifest
- `$getTagValue(cohortId, tagName)` / `$getTagValue()` - Convenience function for single tag retrieval
- `$renameTagKey(oldTagName, newTagName, cohortIds = NULL)` / `$renameTagKey()` - Batch rename tag key across specified or all manifest entries
- `$bulkModifyTagValue(tagName, oldValue, newValue)` / `$bulkModifyTagValue()` - Batch update all tags matching a name/value pair

#### New Tag Query Functions (Both Manifests)

- `$queryCohortsMissingTag(tagName)` / `$queryConceptSetsMissingTag()` - Quality audit: find manifest entries lacking a specific tag
- `$queryCohortsWithTagValues(tagValueMapping)` / `$queryConceptSetsWithTagValues()` - Clean multi-tag AND-logic queries using named list syntax (e.g., `list(status = "approved", owner = "alice")`)
- `$getTagValuesSummary(tagName)` - Audit tag value frequency and distribution across the manifest

#### Benefits

- **Non-destructive operations**: Additive functions like `addCohortTag()` and `mergeTagsIntoCohort()` preserve existing tags
- **Batch operations**: Rename and bulk-modify functions streamline large-scale tag updates
- **Quality workflows**: Missing-tag queries and summaries enable data quality and QA audits
- **Clean query syntax**: Named list interface replaces manual "name: value" string construction
- **Consistent API**: Identical method names and signatures across CohortManifest and ConceptSetManifest

### Definition Updates and Upsert API

#### Capr
- New `$updateCaprCohort()` / `$updateCaprConceptSet()`: overwrite a registered JSON definition in place — same ID and file path, hash refreshed, derived dependents marked `stale`, no-op when the definition is unchanged.
- `$addCaprCohort()` / `$addCaprConceptSet()` gain `stopIfExists = FALSE` to upsert instead of erroring on an existing label (metadata refreshed; tags replaced only when supplied).
- `$addCaprConceptSet()` now records `route = "capr"` for provenance parity with cohorts.

#### ATLAS
- `$addAtlasCohort()` / `$addAtlasConceptSet()` gain `stopIfExists = FALSE`: fetch the current ATLAS definition and update the registered entry in place.
- `importAtlasCohorts()` / `importAtlasConceptSets()` are now strictly **one-time imports**: they fail fast before importing anything when rows are already registered by `atlasId` or when labels collide.
- The import ATLAS templates now run `updateAtlasCohorts()` / `updateAtlasConceptSets()` unconditionally **before** the import section, so every `sourceInputBuilderScripts()` run syncs registered definitions with ATLAS first. The one-time import section is skipped once the load CSV has been deleted (the documented post-import step), keeping `main.R` re-runs safe.

#### Derived Cohorts
- All eight builder functions (`buildUnionCohort`, `buildSubsetCohortTemporal`, `buildComplementCohort`, `buildCompositeCohort`, `buildDemographicCohort`, `buildOPriorT`, `buildTPriorO`, `buildCensorCohort`) plus `addDependentCustomCohort()` gain `stopIfExists = FALSE`: update parents, build parameters, and (for custom SQL) the file registration in place — SQL re-rendered, `depends_on`/`dependency_rule`/hash replaced, cohort marked `stale`, staleness cascaded to dependents.
- `dependentCohortIdList` entries now accept **vectors of cohort IDs** (rendered comma-separated by SqlRender for `IN (@param)` clauses); all IDs flow into `depends_on`.

#### Accidental-Collision Guards on All Upserts
Every `stopIfExists = FALSE` upsert verifies identity before any mutation to prevent silently replacing an unrelated entry under a typo'd label:
- **ATLAS** route: the registered `atlasId` tag must match the `atlasId` passed; entries without an `atlasId` tag cannot be updated via the ATLAS route.
- **Capr** route: `updateCaprCohort()` requires `route = "capr"`; `updateCaprConceptSet()` refuses ATLAS-registered concept sets.
- **Derived builders**: the existing cohort's type must match the type the builder creates (a union can only be updated by `buildUnionCohort()`, etc.).
- Intentional cross-boundary changes remain possible as an explicit two-step (retag then rebuild, or delete + rebuild); error messages state this.

### Deletion and Dependency Integrity
- `$deleteCohort()` now refuses to orphan derived dependents; new `cascade = TRUE` parameter deletes the whole dependent subtree deepest-first (with optional `dropFromDBMS = TRUE` for DBMS cleanup).
- `$syncManifest()` cascades soft-deletion to dependents when a parent's file has gone missing (new `cascade_deleted` action).
- Dependency-cycle guard: a cohort cannot be updated to depend on itself or one of its own dependents.
- `topological_sort()` now reports dangling parent references explicitly instead of a misleading "possible circular dependency" error.

### Pipeline Safety
- `sourceInputBuilderScripts()` no longer swallows builder-script errors: failures are aggregated across all scripts and raised as a single abort, so a failed input build can never be followed by `execStudyPipeline()` running on an incomplete or stale manifest.

### Agent Skills

- **Capr Cohort Generation**: New agent skill for building OHDSI cohorts programmatically using Capr
- **Dependent Cohort Builder**: New agent skill for constructing derived cohorts (temporal subsets, unions, complements, demographic filters, stratification) with automatic parent verification and dependency tracking

## Bug Fixes

- Stale cohorts were unreachable by `generateCohorts()` — three `status = 'active'` filters dropped them from the dependency graph, the in-memory manifest, and dependency hashing, so the stale → regenerate → re-activate flow could never run.
- `checkAtlasConceptSets()` crashed on call due to undefined `cm_atlas_subset` / `atlas_id` variables and a nonexistent `filePath` column; `updateAtlasConceptSets()` targeted a nonexistent `timestamp` column.
- `updateAtlasCohorts()` never refreshed the in-memory manifest after updates; fetch-failure handlers in all four Atlas check/update methods didn't skip failed iterations; early no-op exits fell through instead of returning.
- `deleteCohort()` fell through silently when the ID didn't exist and never refreshed the in-memory manifest.
- `addCaprConceptSet()` now raises a clean duplicate-label error instead of a raw SQLite unique-index failure.
- `sourceInputBuilderScripts()` error handlers assigned to handler-local copies of the errors list (scoping bug), so `error_summary` never reported anything.
- In concept set manifest, check atlasId tag for existing entry in manifest. `$addAtlasConceptSet()` missing addition of atlasId tag.
- Flag which cohort tables are missing for cohort generation. Interactive mode to build cohort tables within `$executeCohortGeneration()`.
- Change agent mode to correct GitHub Copilot format (i.e. `/.github`).
- Clean vignettes and documentation to reflect current state of API.
- Add option that `createBlank...` will open the file.

### Unit Tests

- Expanded `test-CohortManifest-management.R` (80 passing tests).
- New `test-ConceptSetManifest-management.R` (33 passing tests).
- New `test-sourceInputBuilderScripts.R` (6 passing tests).
- New `test-CohortManifest-tags.R` covering the full tag manipulation and query API.


# picard 0.0.5

## Manifest API Enhancements

**API CHANGES**:    

- `loadCohortManifest()` and `loadConceptSetManifest()` now include `autoSync` (default `TRUE`) and `verbose` (default `TRUE`) parameters for controlling manifest initialization behavior   
- `resetCohortManifest()` and `resetConceptSetManifest()` now include `archive` parameter (default `TRUE`) to create timestamped backups of manifest database and files before reset   
- `importAtlasCohorts()` and `importAtlasConceptSets()` **API CHANGE**: changed from file-based (`conceptSetsLoadPath = "path/to/file.csv"`) to dataframe-based (`conceptSetsLoad = dataframe, atlasConnection = NULL`). Users now call `readr::read_csv()` first, then pass the resulting dataframe. Dataframe must contain columns: `atlasId`, `label`, `category` (plus optional tag columns)   

## Input Builder Scripts

**Pre-Pipeline Input Loading System** (`sourceInputBuilderScripts(verbose = TRUE)`):   

- Auto-discovery and sourcing of builder scripts for pre-processing the pipeline   
- Loads concept set definitions from `inputs/conceptSets/R/` directory (sourced first)   
- Loads cohort definitions from `inputs/cohorts/R/` directory (sourced second)   
- Called automatically from `main.R` before the main pipeline executes   

**Six Template Builder Scripts** (auto-populated in project init):  

1. **Concept Set Builders**:   

   - `import_atlas_concept_set.R` — bulk import from ATLAS via CSV + WebAPI connection   
   - `import_capr_concept_set.R` — programmatic definition using Capr functions   

2. **Cohort Builders**:   

   - `import_atlas_cohort.R` — bulk import from ATLAS via CSV + WebAPI connection   
   - `import_capr_cohort.R` — programmatic cohort definitions with Capr   
   - `import_sql_cohort.R` — register hand-written SQL cohorts from `inputs/cohorts/sql/`   
   - `build_dependent_cohorts.R` — create derived cohorts (temporal, union, complement, O-Prior-T, T-Prior-O, censor)   

**Mandatory Source Order** ⚠️:    

- `sourceInputBuilderScripts()` now enforces strict source order to respect dependencies:   
  1. Concept set builders (import_atlas_concept_set → import_capr_concept_set)   
  2. Cohort builders (import_atlas_cohort → import_capr_cohort → import_sql_cohort → build_dependent_cohorts)   
- This ensures concept sets are always loaded before cohorts, and base cohorts before dependent cohorts   
- Missing scripts are gracefully skipped; deletion of unused templates will not break `main.R`  
- Users can delete unused scripts but cannot reorder sources  

## Dissemination Script Workflow

**Post-Pipeline Result Processing** (`sourceDisseminationScripts(projectPath, pipelineVersion, databaseIds, outputPath, verbose, warnMissing)`):   

- Auto-discovery and sourcing of post-processing scripts from `dissemination/pretty/R/` directory   
- Called automatically after `runPostProcessing()` completes in `main.R`   
- Scripts are numbered (01_, 02_, etc.) and sourced in alphabetical order  
- Each script receives `disseminationEnv` list with metadata:   
  - `pipelineVersion` — current pipeline version for reproducibility   
  - `databaseIds` — vector of databases included in the analysis   
  - `outputPath` — root output directory for result export   
  - `resultsPath` — merged results file path for post-processing   

**Dissemination Script Creation** (`makeDisseminationScript(name = "format_results", projectPath, open = TRUE)`):    

- Template-based generation of new dissemination scripts   
- Auto-numbering: creates 01_name.R, 02_name.R, etc. based on existing files   
- Optional RStudio navigation to newly created file   

**Three-Phase Pipeline Integration**:   

- Phase 1: Pre-pipeline (builder scripts in `inputs/*/R/`)   
- Phase 2: Main execution (`execStudyPipeline()` runs analysis tasks)   
- Phase 3: Post-processing with dissemination scripts   
  - `runPostProcessing()` aggregates results    
  - `sourceDisseminationScripts()` runs numbered dissemination scripts for formatting, pivoting, exporting    

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

