# Picard — Pipeline Execution: Decisions and Findings

**Reviewed:** 2026-11-19 · **Decisions taken:** 2026-11-20
**Against:** `ml_exec_work` @ `f740169`
**Code read:** `R/execute.R`, `R/validation.R`, `R/taskTracking.R`, `R/postProcess.R`,
`R/disseminate.R`, `R/studyHub.R`, `R/git.R`, `R/Ulysses.R`, `R/make.R`,
`R/ExecutionSettings.R`, `inst/templates/*`
**Related:** `hidden/notes_exec.md` (earlier call-graph) · `hidden/notes_v1_pathway.md`
(manifest waves) · `hidden/pipeline_rationale.md` (why pipelines) ·
`hidden/decisions_v1.md` (superseded snapshot, not maintained)

**Status.** All 17 decisions are settled. **Wave E0 is implemented** (`f2f321f`,
`ebfff0a` on `ml_exec_work`); Waves ES through E4 are not started. One external input is
still outstanding — D16's size measurement. §10 carries the per-wave status.

**How to read it.** The two tables below are the index. **§0–§5** describe how the code
works today, with file:line references — the implementation reference. **§6** is the full
defect list, **§7** maps the open GitHub issues, **§8** is the survey of other pipeline
tools. **§9** holds the decisions in full, each with rationale, consequences and rejected
alternatives. **§10** is the sequencing.

---

## Where this stands

| | |
|---|---|
| **Decisions** | 17 of 17 settled (§9). Five have open follow-ons — see *Still outstanding* below |
| **Wave E0** | **done** — `f2f321f` (G3/#151), `ebfff0a` (X-3, X-9, X-14, P8) on `ml_exec_work` |
| **Waves ES–E4** | not started |
| **Issues closed** | #127, #149, #151 |
| **Issues filed** | #169, #170, #171, #172 |
| **Blocked on the manifest track** | D11's builder-loop collapse and D13.8b both need **#144**. D12 should land as **#162** *before* #163 |

**Picking this back up.** §2–§5 describe the code as it stands *after* E0, so they are
current. §10 is the next work: **Wave ES** (repo structure) is the largest mechanical batch
and is self-contained; **Wave E3** is the one that overlaps the manifest work, since it is
#162 then #163.

---

## Decisions at a glance

| | Decision | Outcome |
|---|---|---|
| **D1** | What a pipeline run is, and where it terminates | **Six steps**, each a separate public function; the run **terminates at step 4** with the data product formed. Publish (step 5) is optional |
| **D2** | Where the EGP lives | Authored at **`egp.md` in the repo root**; step 4 snapshots it into `export/`. No `documents/` folder |
| **D3** | The repository structure | `dissemination/{export, pretty, publish/{quarto,deck,workbook}}`; both manifests scaffolded; **no `extras/`, no `documents/`, no `test_main.R`** |
| **D4** | Where the code boundary goes | Six independent verbs — execution and post-processing **not** wrapped together. Prospective version at step 1, committed at step 6 |
| **D5** | The branch model | Require `develop`, cut `release/x.y.z` from it, PR to `main`, **`on.exit` back to `develop`**. Open: merge strategy (squash orphans the tag) |
| **D6** | What a production run commits | **Commit `export/`**, no version segment in the path, `exec/` stays ignored, metadata lives in the export |
| **D7** | Release semantics | **Two lanes, one counter.** Internal = a named test namespace; release = single-tier semver. No "minor release" concept |
| **D8** | Non-interactive execution | **No `readline()` anywhere.** Every former prompt becomes a named argument |
| **D9** | Freshness and idempotency | `export/` cleared every run (abort if dirty); `exec/` cleared **per block** by `clearStudyResults()`, never a flag; step 4 writes through a **staging directory** |
| **D10** | Change detection | Version-scoped history kept; **resume at the same version is first-class**; outputs verified before skipping; `dataVersion` probe added; named `rerunTriggers` |
| **D11** | Input builders | **Verify mode default-on** in the release lane; `skipInputBuilders` removed; both manifests scaffolded; init functions made idempotent; **#46 rejected** |
| **D12** | Execution environment hygiene | **The pipeline never uses `globalenv()`.** One child env per script; `sourceSrcFile()` for helpers; bare `source()` in a task becomes a validation failure |
| **D13** | Post-processing authority and scope | Union discovery; coverage gaps **warn in step 4, gate in step 6**; schema mismatch a hard error; `qcStatus` **split** into functional and content |
| **D14** | Failure policy | **Per-block isolation** across databases, fail-fast within a block. A partial run merges, reports `Incomplete`, and cannot be promoted |
| **D15** | The durable record of a run | One **`runManifest.yml`** written by step 4, completed by step 6, replacing `qc_processMeta.csv` |
| **D16** | Results storage and git layout | One committed layer, overwritten, git as the version store; `compress` **removed**; **release tagging becomes picard's job**. Open: the size measurement |
| **D17** | The disclosure guard | Identifier-column check **aborts**; `minCellCount` suppression; file gate is an **allowlist**, derived not hand-authored; runs against the staged copy |

### Still outstanding

| | Needs |
|---|---|
| **D16** — the measurement | `du -sh dissemination/export/merge/v*/` plus a `diff -rq` between two versions on an existing study repo, to get the **per-release delta**, not just absolute size. Only a single file over 50 MB changes the plan |
| **D5** — merge strategy | A squash-merged release PR orphans the release tag. Merge commit, or tag `main` after the merge |
| **D17** — parameters | `minCellCount` default; how a suppressed value is written; which columns; manifest location and contents |
| **D13.8b** — deferred | `validateCohortResults()` must become `databaseId`-aware **as part of #144**, not before |
| **D11** — blocked | Collapsing step 2's per-database builder loop to one pass needs **#144** |

---

## Defects, and what was filed

Twenty defects were confirmed against the code (full detail in §6). Four are bugs in
current behaviour and have been filed:

| | Filed | Summary |
|---|---|---|
| **X-16** | [#169](https://github.com/OHDSI/Picard/issues/169) | `importAndBind()` picks the bundle subdirectory from the first database and applies it to all of them — other databases contribute nothing, silently |
| **X-17** | [#170](https://github.com/OHDSI/Picard/issues/170) | `validateCohortResults()` treats a zero cohort count as a warning, so `qcStatus` is `HasWarnings` on nearly every run |
| **X-18** | [#171](https://github.com/OHDSI/Picard/issues/171) | `databaseInfo.csv` reports coverage from `dbIds`, never from what actually ran |
| **X-19** | [#172](https://github.com/OHDSI/Picard/issues/172) | No run records the picard or R version, so an export cannot say which tool produced it |

**X-20** (nothing creates a release tag) is **not filed**: it is latent while the
`v{version}` folder still makes releases addressable by path, and only becomes a bug once
D6's path collapse lands. It belongs on that work's issue, with D5's merge-strategy
follow-on.

The remaining fifteen (**X-1**–**X-15**) are design gaps resolved by the decisions rather
than standalone bugs. The most consequential is **X-1**: a production run dirties
`config.yml`, `README.md` and `NEWS.md` and never commits them, so the next run fails
pre-flight — which is why `main.R` cannot be run twice in a row today.

---

## 0. The settled pipeline, and how today's code differs

**Settled 2026-11-20 (D1, D4).** A run is six steps, each a separate public function,
shown in sequence in `main.R`:

```
1  preFlightChecksForStudy()   verify the code state is clean           required
2  sourceInputBuilders()       source builders, establish the manifest  required
3  executeStudyPipeline()      generate cohorts, execute tasks          required
4  runPostProcessing()         merge, format, metadata, egp snapshot    required  ← DATA PRODUCT
5  prepareForPublish()         quarto / workbook / deck; also QC        OPTIONAL
6  promoteRelease()            final checks, prepare the PR             required
```

**The pipeline is done at step 4.** Everything through there is the Run tier; step 5 is
Publish (optional, swappable); step 6 is Promote.

Where today's code sits against that:

| Target step | Today | Gap |
|---|---|---|
| 1 | `runPreflightChecks()` is **internal** and called from *inside* `execute_pipeline()` (`R/execute.R:728`), after the branch cut and version math | Cannot be run on its own (**G5**); runs too late to prevent a half-released repo |
| 2 | `sourceInputBuilderScripts()` called once for *all* dbs from `main.R:56`; `skipInputBuilders = TRUE` by default | The default path is the one both templates document as wrong for db-specific builders (#163 → D11) |
| 3 | `execute_pipeline()`'s per-block loop (`R/execute.R:828`) | Also owns the branch cut, version bump and PR prep, which belong in 1 and 6 |
| 4 | `runPostProcessing()` called separately from `main.R`; `pretty` is a separate optional call | Pipeline reports success before anything is merged or QC'd; `pretty` must move inside |
| 5 | `buildStudyHub()` exists but is never called by the pipeline | Matches the target — it was already optional in all but name |
| 6 | `createPullRequest()` + `save_pr_reference()` at the tail of `execStudyPipeline()`; **nothing is committed** | **X-1** — the single biggest blocker to `main.R` running twice |

Two things worth knowing before reading §2: pre-flight is **12 checks**, and **no snapshot
is taken during it**. Manifest hashes are snapshotted later, per config block
(`R/execute.R:881-883`), and the only durable manifest *snapshot file* is written at
post-processing time (`cohortManifestSnapshot.csv`). Pre-flight counts and validates, nothing
more.

---

## 1. The run as it exists today

### 1.1 `main.R` (generated template)

```r
renv::restore()                                  # line 20
dbIds <- c("...")                                # line 29
sourceInputBuilderScripts(configBlock = dbIds)   # line 56  — all dbs, up front
taskResults <- execStudyPipeline(configBlock = dbIds, updateType = "patch")  # line 68
pipelineVersion <- config::get("version")        # line 75  — re-read after the bump
results <- runPostProcessing(pipelineVersion, dbIds)                         # line 85
# sourceDisseminationScripts(...)                # line 94  — commented out
# clearPendingPR()                               # line 112 — commented out
```

### 1.2 `execStudyPipeline()` — `R/execute.R:1128`

1. Branch guard: abort if on `main`.
2. Read `  version: ` out of `config.yml` by **line regex** (`:1165-1171`).
3. Compute `newVersion` from `updateType` (`:1176-1203`).
4. `releaseBranch <- "release/{newVersion}"`; create or checkout (`:1208-1224`).
   `gert::git_branch_create()` is called with no `ref`, and its default is `ref = "HEAD"`
   — so the branch is cut from **wherever you currently are**, not from `main`.
5. `execute_pipeline(...)` (`:1230`).
6. `createPullRequest()` → `save_pr_reference()` → `PENDING_PR.md` (`:1245-1257`).

**Steps 2–3 are duplicated verbatim inside `execute_pipeline()`** (`:689-717`). Two
independent reads of `config.yml` and two independent increments per run.

### 1.3 `execute_pipeline()` — `R/execute.R:656`

| # | Step | Line |
|---|---|---|
| 1 | Compute `pipelineVersion` (test: normalize namespace; prod: validate `updateType`, read config, bump) | 666-717 |
| 2 | `newExecutionContext()` — owns cohort-table suffix + results path derivation | 720 |
| 3 | `runPreflightChecks()` — 12 checks | 728 |
| 4 | Abort if zero tasks | 744 |
| 5 | `.resolveForcedTasks(forceRerun, taskFiles)` | 751 |
| 6 | **prod only:** `updateStudyVersion()` → writes `config.yml`, `README.md`, prompts for `NEWS.md` | 757-766 |
| 7 | Logging setup → `exec/logs/picard_log_{version}_{ts}.txt` | 769-818 |
| 8 | **per config block:** `[sourceInputBuilderScripts]` → `createExecutionSettingsFromConfig()` → `generateCohorts(override = TRUE)` → snapshot 3 hashes → **per task:** `execute_task()` | 828-920 |
| 9 | Console summary + log footer | 923-953 |

Failure policy: `stop()` on the first failing task (`:912`), which kills the whole run —
remaining tasks *and remaining config blocks* never execute.

### 1.4 `execute_task()` — `R/execute.R:415`

```
assert ExecutionContext → pipelineVersion from ctx
snapshot cohort/conceptSet/renv hashes (or use the ones passed in)
file-exists check
if (checkStatus) → shouldRerunTask() → if up to date: record("skipped"); return
validateStudyTask()                                    # :503
read file → normalize CRLF → glue(.open="!||", .close="||!")
rlang::parse_exprs()
for each expr: eval(expr, env)                         # env = caller_env()
record("success" | "failed")
```

Two structural notes:

- The skip check runs **before** validation, so a skipped task is never validated.
- `env` defaults to `rlang::caller_env()`, which from `main.R` is **`globalenv()`**. Every
  task in every config block evaluates into that one environment. Task 5 can see whatever
  task 4 left behind, and `db_b`'s tasks can see `db_a`'s leftovers.

### 1.5 Results layout

```
exec/results/{snake_case(databaseName)}/{pipelineVersion}/{taskName}/*.csv
exec/results/{db}/{version}/00_buildCohorts/cohortCounts.csv
exec/logs/picard_log_{version}_{timestamp}.txt
exec/logs/task_run_history.csv
```

`exec/` is **gitignored** (`R/Ulysses.R:238-242`). Nothing under it ever reaches the
release branch.

---

## 2. The pre-flight checklist — `runPreflightChecks()` (`R/validation.R:575`)

> **Reflects Wave E0 (`f2f321f`, `ebfff0a`).** Check 6 "Results folder" was **removed**
> (**X-3**, per D10) and check **10b "Task indices"** was **added** (**G3**, closing #151).
> Thirteen checks, not the twelve described in the original review.

Signature defaults matter here:

```r
runPreflightChecks(configBlock, pipelineVersion,
                   testMode = FALSE, skipRenv = FALSE,
                   skipConnectivityCheck = TRUE,        # <- off by default
                   ignoreUncommittedPaths = NULL,       # <- read from config.yml default block
                   skipCodeStateCheck = FALSE,
                   skipInputBuilders = TRUE,
                   tasksFolderPath = here::here("analysis/tasks"))
```

| # | Check | Implementation | Severity | Skipped when |
|---|---|---|---|---|
| 1 | **Branch** | `get_current_branch() != "main"` | **fail** | never |
| 2 | **Code state** | `code_state_check()` → `validateCodeState(ignorePaths)` | **fail** / warn if `dirty-ignored` or skipped | `testMode`, `skipCodeStateCheck` |
| 3 | **Environment** | `validateEnvironment()` + `lockfileHashOnDisk()`; deliberately does *not* snapshot | **fail** | `testMode`, `skipRenv` |
| 4 | **Config** | `validateConfigYaml()` | **fail** | never |
| 5 | **Config blocks** | `validateConfigBlockCompleteness()` — every block is a real key | **fail** | never |
| 5b | **Secrets** | `validateSecretsYaml("~/.picard/secrets.yml", dbServers)` | **fail** | never |
| 7 | **Cohort manifest** | `loadCohortManifest()$validateManifest()`; counts `active`+`stale`, collects missing files | **fail** on error; warn if no manifest and builders will run | — |
| 8 | **Concept sets** | `validateConceptSetManifest()` | warn-only | — |
| | *(D11: the manifest is always scaffolded, so this becomes "N registered", N possibly 0 — not a conditional warning)* | | | |
| 9 | **DB connectivity** | `validateDatabaseConnectivity(configBlock)` | warn-only | **default on** (`skipConnectivityCheck = TRUE`), `testMode` |
| 10 | **Tasks** | `fs::dir_ls("analysis/tasks")`, sorted basenames | **fail** if folder missing or empty | never |
| 10b | **Task indices** | `validateTaskIndices()` over `taskExportPrefix()` — two tasks sharing an export prefix would overwrite each other's merged results | **fail** on a collision; **warn** on a missing numeric prefix | no task files |
| 11 | **Task deps** | `validateTaskDependencies()` — resolve `source()` paths | warn-only | — |
| 12 | **Branch sync** | `validateReleaseBranchFreshness()` — is local `develop`'s tip in the last 200 commits of HEAD | warn-only | `testMode`, no local `develop` |

Then, in order (`R/validation.R:834-895`):

1. Render the aligned checklist (`✓ / ✗ / ~ / -`).
2. `cli_abort` if any **fail** (warnings are reported but do not block).
3. `announce_code_state()` — loud banner whenever the tree was not verified clean.
4. **Interactive prompt** if any active cohort's file is missing from disk —
   `readline("Continue with pipeline? (yes/no): ")`.

Returns `list(lockfileHash, taskFilesToRun, codeState)`.

### 2.1 Gaps in the checklist

**G1 — The version-collision check is a no-op.** *(**DONE** `ebfff0a` — removed, not fixed, per D10.)* `validateResultsFolderFresh()`
(`R/validation.R:300`) inspects `exec/results/{pipelineVersion}`. The real layout is
`exec/results/{database}/{pipelineVersion}` (`ExecutionContext$getResultsPath()`,
`R/ExecutionSettings.R:489-500`). That directory never exists, so the function returns
`TRUE` at its first branch, every time. The one check that is supposed to stop you from
writing two different runs into the same version folder does not fire. **This is the root
of #117 and #151** — stale folders survive because nothing ever notices them.

**G2 — `lockfileHash` is computed and thrown away.** Assigned at `R/execute.R:741`,
referenced nowhere else (grep: single hit). The log header records `codeState` but not the
lockfile hash; the per-task record recomputes it via `.getRenvLockHash()`. Either wire it
through or drop it.

**G3 — Nothing checks that tasks are coherent as a set.** *(**DONE** `f2f321f` — the
"Task indices" check now fails on a shared export prefix and warns on a missing numeric
prefix; closed #151.)* Check 10 lists files and sorts
basenames. Nothing validates the `NN_` numbering: duplicate indices, gaps, or a file
without a numeric prefix all pass. The downstream consequence is #151, and the ordering
guarantee the whole pipeline depends on rests on `sort()` over basenames.

**G3b — No export-manifest freshness check.** *(Open — belongs with D17's manifest.)* Nothing tells you before a run that
`analysis/tasks/` has changed since the export manifest was approved, so a new task output
is discovered at step 4 — hours in — rather than at step 1. D17 adds this check.

**G4 — No concurrency guard.** Two analysts (or two R sessions) can run the same version
against the same `cohortTable` and the same `exec/` folder simultaneously. There is no
lockfile; `task_run_history.csv` is read-modify-written without one.

**G5 — The checklist cannot be run on its own.** `runPreflightChecks()` is
`@keywords internal` and unexported. There is no `preflight(configBlock)` an analyst can
run before committing to a release branch and a version bump. Everything about the
ordering today forces the branch cut and version math to happen *before* you learn the
run would have failed.

**G6 — Two blocking prompts, and no non-interactive path.** The missing-cohort prompt
(`R/validation.R:891`) and the `NEWS.md` loop (`R/execute.R:115-128`) both call
`readline()`. Under `Rscript`/CI, `readline()` returns `""` immediately:
- missing-cohort prompt → `""` is not `"yes"` → run aborts.
- `NEWS.md` loop → `repeat { readline() }` never sees `"END"` → **infinite loop**. This is
  exactly #128.

**G7 — Pre-flight validates the manifest but never records it.** *(Check 7's "no manifest yet" branch is removed by D11 — both manifests are scaffolded.)* `codeState` is threaded
into the run history; the manifest state at pre-flight time is not. If a builder script
mutates the manifest between pre-flight and generation (possible when
`skipInputBuilders = FALSE`), nothing detects the drift.

**G8 — Connectivity is off by default.** The most common real failure (bad credentials,
VPN down, expired keyring entry) is the one check that does not run unless you ask. You
discover it after the release branch exists, the version is bumped, and `NEWS.md` has been
rewritten.

---

## 3. Change detection — `shouldRerunTask()` (`R/taskTracking.R:54`)

History key: **(task_name, config_block, pipeline_version)** — `R/taskTracking.R:98-102`.
Re-run is triggered by any of:

1. task file sha256 differs from the recorded hash;
2. a `source()`d dependency changed (`.checkDependencyChanges()`);
3. cohort manifest hash differs;
4. concept set manifest hash differs;
5. `renv.lock` hash differs;
6. the previous run's status was `failed`;
7. no record at all (first run in this namespace).

Fail-safe direction is correct: an uncomputable hash forces a re-run.

**The cache is effectively test-mode-only.** In production, `pipelineVersion` is new on
every run by construction, so the history lookup never matches and *everything* re-runs.
The vignette states this explicitly (`vignettes/running_the_pipeline.Rmd:285-287`). So the
sophisticated caching layer only serves `test*` runs. Worth deciding whether that is
intended (see D10).

**Cohort generation has its own, separate cache.** `generateCohorts()` always runs for
every block (`override = TRUE` only suppresses the confirmation prompt,
`R/execute.R:293-308`); the actual skip decision lives inside
`cm$executeCohortGeneration()`, keyed on a checksum stored in the work schema. There is no
`force` argument on `executeCohortGeneration()` (`R/CohortManifest.R:5216`) — which is the
unaddressed half of **#130**.

Known gap, already filed: tasks that *read* data files (especially another task's output)
are invisible to the check (**#136**). Also noted there: `.checkDependencyChanges()` never
stores dependency hashes, so any task that `source()`s a file re-runs unconditionally.

---

## 4. Post-processing — `runPostProcessing()` (`R/postProcess.R:629`)

> **Reflects Wave E0.** A per-database **duplicate task-index guard** was added after task
> discovery (**G3**, closing #151), and the version-folder `stop()` is now a `cli_abort`
> (**P8**).

```
testMode  <- !grepl("^\d+\.\d+\.\d+$", pipelineVersion)      # inferred from the version string
codeCommitSha <- gert::git_log()$commit[1]
lockfileHash  <- captureLockfile(version)  | "dev-skip"
db names/labels/cohortTable  <- config::get(..., config = dbId)
firstDbVersionPath <- exec/results/{db[1]}/{version}          # must exist, else cli_abort()
versionExportPath  <- dissemination/export/merge/v{version}
taskFolders <- dir_ls(firstDbVersionPath, type = "directory") # TASK DISCOVERY: first db only
validateTaskIndices(per database)                             # ADDED E0: abort on a shared prefix
for (task in taskNames) importAndBind(version, task, dbIds, ...)
reviewExportSchema()        -> schema_review.csv
databaseInfo                -> databaseInfo.csv
cohortManifest$tabulateManifest("active","wide") -> cohortManifestSnapshot.csv
validateCohortResults()     -> qc_cohortValidation.csv
processMeta                 -> qc_processMeta.csv   (qcStatus: OK | HasWarnings | Completed | DevMode)
```

### `importAndBind()` (`R/postProcess.R:40`)

- Export filename prefix comes from `taskExportPrefix()` — extracted in E0 so the merge and
  `validateTaskIndices()` cannot disagree about what collides.
- Per-db task folders built from `snake_case(databaseName)`; missing ones **warn only**
  (`:65-69`).
- The **file list is taken from the first existing db folder** (`:71`).
- Bundle detection: if no direct CSVs, look for subdirectories containing CSVs and take
  the **alphabetically last** one (treating `YYYYMMDD_HHMMSS` naming as chronological),
  warning about the ones it skips (`:88-124`).
- Per file: read each db's copy, `dplyr::mutate(databaseId = databaseNames[i], .before = 1)`,
  `do.call('rbind', ...)`, write (`:150-167`).

### 4.1 Gaps in post-processing

**P1 — First-database authority (silent data loss).** *(Settled by D13.1 — union discovery, db1 hard-stop removed.)* Both task discovery
(`R/postProcess.R:678`) and file discovery (`R/postProcess.R:71`) key off the *first*
database only. A task or an output file that exists for `db_b` but not `db_a` is never
merged, and nothing says so. For a network study where one db legitimately produces an
extra file, the merge quietly omits it.

**P2 — Partial merges report success.** *(Settled by D13.2/D13.3 — three error paths, release lane fails.)* The per-task loop (`:705-736`) and the per-file
loop (`:135-192`) each wrap everything in `tryCatch` that only emits
`cli_alert_danger`. A column-schema mismatch across databases makes `do.call('rbind')`
error, the file is dropped from the export, and the run continues. `qcStatus` is derived
only from `validateCohortResults()` — it does not reflect merge failures at all. A run can
finish "OK" having merged half the data.

**P3 — No "all databases contributed" assertion.** *(Settled by D13.2 — expected is `dbIds`.)* `databaseCount` is recorded per file in
the summary but never compared to `length(dbIds)`.

**P4 — Nothing is ever cleared.** `dissemination/export/merge/v{version}/` accumulates
across runs; so does `exec/results/{db}/{version}/`. Combined with **G1**, a renamed task
folder leaves its predecessor behind and the next merge picks up both (#117, #151).

**P5 — Provenance is captured after the fact and from the wrong point.**
`codeCommitSha` is `git_log()$commit[1]` at *post-processing* time. In the production flow
that is the commit before `updateStudyVersion()` dirtied `config.yml`/`README.md`/`NEWS.md`
— and those changes are never committed (see X-1 below). So the SHA recorded in
`qc_processMeta.csv` does not describe the tree that produced the results, and it is not
the `codeState$sha` the pre-flight check validated and wrote into
`task_run_history.csv`. Two different provenance records, two different answers.

**P6 — No disclosure/sensitivity gate.** *(Settled by D17.)* Picard merges *every* CSV it finds. #142 is a
study team's hand-rolled wrapper that adds a 25-file allowlist, aborts on any
`subjectId`/`personId`/`patientId` column, and refuses to run if patient-level files are
already sitting in the merge folder. For a package whose rationale document lists
"security — limit access to patient data" as a first-class goal
(`hidden/pipeline_rationale.md`), this belongs in picard, not in a copy-pasted helper.

**P7 — Metadata and results share one folder.** #142 also relocates the five
reference/QC files to `dissemination/documents/v{version}` so the merge folder holds only
task results. **Declined by D6** — the metadata stays in `export/` with the results, since
it is the data product's provenance. The rest of #142 (P6) is unaffected.

**P8 — Cosmetic.** *(**DONE** — now `cli::cli_abort()`.)* `stop("Cannot find results for version {pipelineVersion}")`
(`R/postProcess.R:669`) is base `stop()` with glue syntax — prints the braces literally.

---

## 5. Dissemination and Study Hub

- `sourceDisseminationScripts()` (`R/execute.R:1858`) — alphabetical `dissemination/pretty/R/*.R`,
  `source(file, local = FALSE)` with `disseminationEnv` **assigned into `globalenv()`**
  (`:1913`) and never removed. Errors are reported at file granularity (#119).
- `prepareDisseminationData()` and friends (`R/disseminate.R`) — formatting helpers;
  `cleanColumnNames`, `formatPercentages`, `standardizeDataTypes`, `pivotForComparison`.
- `buildStudyHub()` (`R/studyHub.R:99`) — Quarto render of README/NEWS + exported results;
  `publishStudyHubPosit()` for deployment.

Same globalenv-assignment problem as the input builders (#162, #62) — and
`hidden/MEMORY`-level note: the `inputBuilderEnv` globalenv design is already slated for
redesign, so don't build on it.

---

## 6. Confirmed defects

Twenty defects confirmed against the code, ordered by how badly they break an end-to-end
production run.

- **Fixed:** X-3, X-9, X-14 (Wave E0, `ebfff0a`), plus P8 and G1/G3 — struck through below.
- **Filed as issues:** X-16–X-19 → #169–#172.
- **Latent:** X-20 — only becomes a bug once D6's path collapse lands.
- **Everything else** is resolved by the decisions in §9, not yet implemented.

Label conventions used throughout: **X-n** defects (this section) · **Dn** decisions (§9) ·
**Gn** pre-flight gaps (§2.1) · **Pn** post-processing gaps (§4.1).

| # | Defect | Location | Consequence |
|---|---|---|---|
| **X-1** | Production run dirties `config.yml`, `README.md`, `NEWS.md` and **never commits them**. No `git_add`/`git_commit`/`saveWork` anywhere in `execute.R`. | `R/execute.R:757-766` writes; `:1245` only writes `PENDING_PR.md` | The release branch has no commit for the release. The *next* production run fails pre-flight check 2 (uncommitted changes) unless the analyst commits by hand. `main.R` never tells them to. **This alone stops "run end to end on main.R" from working twice in a row.** |
| **X-2** | `NEWS.md` prompt is an unguarded `repeat { readline() }` | `R/execute.R:115-128` | Infinite loop under `Rscript`/CI. = **#128** |
| ~~**X-3**~~ | `validateResultsFolderFresh()` checks a path that never exists | `R/validation.R:302` vs `R/ExecutionSettings.R:492-496` | Version-collision detection is dead; stale results silently merge. **Resolved by removal, not repair** — D10 drops the check in favour of per-task change detection, per-task output clearing and G3. Underlies **#117/#151** **DONE** ebfff0a — removed, not repaired |
| **X-4** | Version read + increment duplicated across two functions | `R/execute.R:1165-1203` and `:689-717` | Two `config.yml` reads per run; divergence if anything writes between them. Regex-on-a-line parsing of YAML in both |
| **X-5** | Missing-cohort prompt blocks non-interactively, defaulting to abort | `R/validation.R:891` | CI runs die on a prompt they cannot answer |
| **X-6** | All tasks share one evaluation environment (`globalenv()` via `caller_env()`) | `R/execute.R:419`, `:539` | Cross-task and cross-database state leakage; a task can pass only because of a predecessor's leftovers. **Settled by D12** — one child env per script, parent excludes `globalenv()` |
| **X-7** | Builder/dissemination context objects assigned into `globalenv()`, never cleaned up | `R/execute.R:1566`, `:1913` | **#162**, **#62**; stale `inputBuilderEnv` makes a hand-run builder target the wrong db. **Settled by D12** — bound in the script's own env, so there is nothing to clean up |
| **X-8** | First failing task kills all remaining config blocks | `R/execute.R:912` | `db_a` task 7 fails ⇒ `db_b`, `db_c` never run at all |
| ~~**X-9**~~ | `lockfileHash` returned by pre-flight is dead | `R/execute.R:741` | Dead code / lost provenance **DONE** ebfff0a — wired into the run log |
| **X-10** | `execStudyPipeline()` leaves you on the release branch | no `on.exit` in `R/execute.R:1128-1262` | Next session starts on `release/x.y.z` with a dirty tree. `hidden/notes_exec.md` already proposes the `on.exit(develop)` fix |
| **X-11** | Two scaffolded dissemination folders are dead. The scaffold creates `dissemination/export/pretty/` and `dissemination/export/studyHubOutput/`, but every code path reads and writes `dissemination/pretty/` — one level up | `R/Ulysses.R:1010` vs `R/execute.R:1752`, `R/execute.R:1862`, `R/make.R:1291`, `inst/templates/main.R:99` | Two tracked folders only ever hold a `.gitkeep`; the folder the code actually uses is created ad hoc and was never part of the scaffold. Settled by **D3** |
| **X-12** | `qc_processMeta.csv` embeds `Sys.time()`, so a no-op re-run still produces a git diff | `R/postProcess.R:874` | Committed-export churn with no information content. Volatile fields belong in the run manifest (D15), not in committed results |
| **X-13** | `compress = TRUE` defeats git delta compression on exactly the files that get committed | `R/postProcess.R:42`, `:612` | A gzipped CSV is already-compressed binary: a one-row change stores a full new blob. The flag exists to save space and costs space in git. See **D16** |
| ~~**X-14**~~ | `CLAUDE.md` documents `orchestratePipelineExport()`, which does not exist in `R/` | `CLAUDE.md` post-processing section | Stale guidance; `runPostProcessing()` is the real entry point **DONE** ebfff0a — `CLAUDE.md` corrected |
| **X-15** | `buildStudyHub()` renders into `dissemination/quarto/_site/`, which `.addGitIgnore()` does not ignore | `R/studyHub.R:112-116` vs `R/Ulysses.R:239-242` | Building the hub commits an entire rendered HTML site into the study repo — a third copy of the same data. Neither `_site/` nor `.quarto/` is ignored. See **D3**, **D16** |
| **X-16** ([#169](https://github.com/OHDSI/Picard/issues/169)) | `importAndBind()` derives the bundle subdirectory name from the first database and applies it to all of them | `R/postProcess.R:88-124` | Bundle names are per-run timestamps, so other databases' paths do not exist and they contribute nothing — the merge silently reports fewer databases. Settled by **D13.6**: becomes a hard error |
| **X-17** ([#170](https://github.com/OHDSI/Picard/issues/170)) | `validateCohortResults()` treats a zero cohort count as a warning | `R/postProcess.R:818` | `hasWarnings <- any(validationStatus %in% c("ZeroCount", "Missing"))` — but a zero count is a clinical finding (the entity is not viable in that database), so every such run reports `HasWarnings` and the QC status becomes noise. Settled by **D13.2** |
| **X-18** ([#171](https://github.com/OHDSI/Picard/issues/171)) | `databaseInfo.csv` asserts coverage from `dbIds` and `config.yml`, never from what actually ran | `R/postProcess.R:656` | An export can state three databases while containing two, with its own reference file corroborating the false claim. Live because D4 makes step 4 independently callable with any `dbIds`. Settled by **D14** |
| **X-19** ([#172](https://github.com/OHDSI/Picard/issues/172)) | The picard version is never recorded in a run | no `packageVersion()` call anywhere in `R/` | A committed export cannot say which picard produced it; the R version exists only inside `renv.lock`, hashed rather than stated. Reproducing a release means guessing the tool version. Settled by **D15** |
| **X-20** | Nothing creates a release tag | no `git_tag*` call in `R/`; only a manual instruction at `vignettes/running_the_pipeline.Rmd:364` | D6 replaced the `v{version}` folder with git as the version store, so `git show v1.2.0:...` is the only route to a past export — and the tag it needs is a step an analyst may forget. A squash-merged release PR also orphans it. Settled by **D16** |

---

## 7. Open-issue map (execution-relevant)

| Issue | What it is | Where it bites | Note |
|---|---|---|---|
| **#128** | `execStudyPipeline` interactive-only | X-2, X-5, G6 | Two prompts; the `NEWS` one is an infinite loop |
| ~~**#127**~~ | "Confusing behavior": forces develop, "checks out release off main" | §1.2 step 4 | **CLOSED as feedback, not a bug.** Both premises wrong: `gert::git_branch_create()` defaults to `ref = "HEAD"` so the branch is cut from the current branch, and only `main` is rejected. Real finding: an existing `release/<version>` is reused as-is, so re-running a failed release lands on a stale branch. Check 12 detects it, warn-only. D5's enforcement (E2) covers it |
| **#130** | Override for pipeline caching | §3 | **Half done.** `forceRerun` (logical or task-name vector) already exists on `execStudyPipeline`/`testStudyPipeline`/`testStudyTask`. The remaining ask — a cohort-generation override — has no hook: `executeCohortGeneration()` has no `force` param |
| **#117** | Clear exec folder on runs? | X-3, P4 | Needs a policy decision (D9 + D16), not just a fix. The issue asks about `exec/`, the merge folder *and* `pretty/` — D16 answers the latter two by making them derived-and-ignored |
| ~~**#151**~~ | Error on duplicate task indices in `exec/` | G3, P4 | **CLOSED** by `f2f321f` — pre-flight `"Task indices"` check plus a per-database guard in post-processing, one prefix definition shared with `importAndBind()` |
| **#136** | Detect data-file reads before skipping a task | §3 | Well-specified with 6 options. Note it's moot in production (everything re-runs) |
| **#162** | Per-expression eval into an explicit env for builders/dissemination | X-7 | **Settled by D12**, which goes further: no `globalenv()` at all, one child env per script, and `sourceSrcFile()` for helpers. Closes **#62** (four `<<-` sites) and **#119**. Prerequisite for #163 |
| **#163** | Input-builder workflow: production vs interactive | §1.1, §0 | **Settled by D11** — verify mode default-on in the release lane, both manifests scaffolded, `skipInputBuilders` removed. Delivers **#64**'s guarantee; largely defuses **#69**. End state blocked on **#144** |
| **#46** | Let analysts organise builder files their own way | D11 | **Rejected by D11** as counter to the design — the mandatory concept-sets→cohorts→derived order is a correctness requirement, and a free-form folder cannot be verified |
| **#64** | Make cohort/concept-set pipeline reproducible | G7, #163 | Verify mode is the mechanism — **settled by D11** |
| **#131** | System env vars in `config.yml` | §4, CI | Prereq for any non-interactive/CI story alongside #128 |
| **#119** | Verbose output for `sourceDisseminationScripts` | §5 | Falls out of D12's per-expression loop for free |
| **#142** | Post-processing wrapper: allowlist, PHI header guard, metadata relocation | P6, P7 | The most concrete external feature request on the board |
| ~~**#149**~~ | Uppercase column refs break across platforms | `R/cohort_builders.R` | **CLOSED** — positional indexing already in place at `R/cohort_builders.R:318`, `:366` |
| **#153** | Database class | P1, P3, #144 | Would give post-processing a real roster to assert against instead of `config::get()` scrapes |
| **#154** | EGP class | — | Design question (write-first vs generate-from-code) |
| **#144 / #157** | `displayName` + `databaseId` on the manifest; schema-migration blocker | #163, P1 | Already waved in `notes_v1_pathway.md`. `databaseId` on manifest rows is what would let the builder loop collapse to one pass |
| **#147 / #138** | NEWS duplication; README version drift | `updateStudyVersion()` | Both are `updateStudyVersion()` side-effects: it regex-patches the first semver-looking line in README (`R/execute.R:88-101`) and prepends to root `NEWS.md` only |

---

## 8. What other pipeline tools do that Picard could borrow

Snakemake, Nextflow/nf-core, `targets`, dbt, DVC, Dagster, Metaflow, and — most directly
relevant — OHDSI's own Strategus and StudyStudio, grouped by the problem each solves.

### 8.1 Pre-flight as a first-class, standalone, non-destructive command

Every mature tool separates "tell me what you would do" from "do it":

- **DVC** — `dvc status` reports which stages are out of date versus `dvc.lock`;
  `dvc repro --dry` prints the plan without running it.
- **Snakemake** — `--dry-run` plus `--summary`, `--list-code-changes`,
  `--list-params-changes`: *which* rules would re-run and *why*.
- **`targets`** — `tar_outdated()` / `tar_visnetwork()` answer "what's stale" before
  `tar_make()`.
- **nf-core** — `nf-core pipelines schema validate` checks a params file against the
  pipeline's JSON schema *before* launch; `validateParameters()` from the `nf-schema`
  plugin aborts the run at startup on a bad param set.

**For Picard:** export the checklist as `preflightStudy(configBlock, updateType)` —
runnable on `develop`, no branch cut, no version bump, no `NEWS` prompt, returning the
result list. Add a `dryRun = TRUE` to `execStudyPipeline()` that prints, per block and per
task, *skip or run and why* — the reasons are already computed in `shouldRerunTask()` and
currently only printed mid-run. This fixes **G5** and makes **G8** cheap, since connectivity
checking can be on by default in a dry run.

### 8.2 Make the ordering "check, then branch, then bump" — and bump last

Picard currently cuts the release branch and rewrites `config.yml`/`README.md`/`NEWS.md`
*before* a single task runs, which is why a mid-run failure leaves a half-released repo.

- **Metaflow** takes an immutable **code package** snapshot of the working directory at
  run start, stores it in the datastore, and runs *from that snapshot* — the run is pinned
  regardless of what happens to the working tree afterwards.
- **semantic-release / release-please** derive the version bump from the commit history
  (`feat` → minor, `fix` → patch, `BREAKING CHANGE` → major) and generate the changelog
  from commits, rather than asking a human at run time.

**For Picard:** two separable borrowings.

1. **Move the version bump into a promotion step after a successful run** — exactly what
   `hidden/notes_exec.md` already proposes (step 5d). That kills X-1's ordering problem
   and makes a failed run leave nothing behind.
2. **Stop prompting for the changelog.** Either accept `newsEntry = c(...)` as an argument
   (fixes #128 directly), or generate it from the commits on the release branch since the
   last tag. The second option also answers #138/#147: one generated changelog, one source
   of truth.

### 8.3 Lock the working directory

**Snakemake locks the working directory for the duration of a run**, and ships `--unlock`
for the case where a crash leaves a stale lock. This is the entire fix for **G4**.

**For Picard:** a lock file keyed on `(exec/results/{db}/{version}, cohortTable)`, written
at run start with pid/user/timestamp, removed on exit, with an `unlockStudy()` escape
hatch. You have a sharper need than Snakemake does, because two analysts sharing a work
schema can collide *in the database*, not just on disk.

### 8.4 Name the re-run triggers explicitly and let callers choose

Snakemake's `--rerun-triggers` takes any of `mtime`, `input`, `params`, `code`,
`software-env`, **all enabled by default**. `targets` exposes the same idea per-target via
`tar_cue(mode =, command =, depend =, file =)`.

**For Picard:** the trigger set is already conceptually identical — task file (`code`),
`source()`d deps (`code`), cohort manifest (`input`), concept-set manifest (`input`),
`renv.lock` (`software-env`), prior failure. Expose it:

```r
execStudyPipeline(..., rerunTriggers = c("code", "inputs", "env", "failed"))
```

That generalises `forceRerun` (which is "disable all triggers"), and gives **#130** its
cohort-generation override as a trigger name rather than yet another boolean. It also
gives **#136** a natural home: add a `data` trigger, off by default, that hashes declared
data inputs.

### 8.5 Separate "code version" from "data version", and record both

- **Dagster** distinguishes an asset's `code_version` from its `DataVersion`, and has
  **observable source assets** — a function that reports the current version of an
  upstream thing you don't control, which then participates in staleness.
- **dbt** compares against a production `manifest.json` (`--state`) and selects
  `state:modified+`.
- **DVC** stores content hashes of inputs, outputs, *and* parameter values in `dvc.lock`.

**For Picard this is the missing third axis.** Your own brainstorm names the three change
types — *cohorts/inputs, data, code/tasks* — and the pipeline currently tracks only two.
A CDM refresh is invisible: same code, same manifest, different data, and
`shouldRerunTask()` happily skips. An **observable source asset** is the right model for a
CDM: a small per-database probe (CDM source `vocabulary_version`, `cdm_release_date`,
`observation_period` max date, or a `cdm_source` row hash) recorded as `dataVersion` in
the run history, and added as a re-run trigger. It also gives you the thing you need for
release semantics in D7: "this version differs from the last because the *data* changed"
becomes a statement you can make from records instead of memory.

### 8.6 Content-addressed, resumable task outputs

**Nextflow** hashes each task's inputs + script + container/conda env into a 128-bit
digest, runs in `work/ab/cd1234…/`, and `-resume` recovers a task only when both the cache
entry *and* its output directory are intact. Crucially, **a cache hit alone is not enough
— it verifies the outputs still exist.**

Picard's skip decision trusts `task_run_history.csv` and never checks whether the task's
output files are still on disk. Delete `exec/results/db_a/1.2.0/05_foo/` and the task is
still "up to date". With post-processing reading from those folders, the merge then
silently omits it (**P1** compounds it). Snakemake goes further and tracks **incomplete**
outputs explicitly (`--rerun-incomplete`), because a killed run leaves half-written files.

**For Picard:** record the output file list + hashes in the run record, and make the skip
conditional on them still being present. Mark a task `incomplete` when the run dies
mid-task, and treat `incomplete` like `failed` for re-run purposes.

### 8.7 A run manifest you can hand to someone

- **DVC** commits `dvc.lock` to git — the pipeline's realised state is a reviewable file.
- **Snakemake** `--report` emits a self-contained HTML report with provenance per result.
- **StudyStudio (OHDSI)** is the strongest analogue to what you're reaching for with
  releases: sites produce **StudyPacks** — sealed result bundles with a manifest listing
  **SHA-256 of every file**, the protocol copy, execution logs, and provenance (CDM
  version, vocabulary version, `renv.lock` software versions, DBMS platform, execution
  timestamps, DQD results), optionally ECDSA-signed for regulatory studies. Protocols are
  **pinned by SHA-256** — the analysis spec, run script, and `renv.lock` are locked, and
  any deviation is detected at verification. The coordinator records a per-site
  **disposition** (adopted / excluded, who decided, why) in a hash-chained audit trail.

**For Picard:** today provenance is scattered across three places with three different
answers — `exec/logs/picard_log_*.txt` (prose, gitignored),
`exec/logs/task_run_history.csv` (per task/block/version, gitignored), and
`qc_processMeta.csv` (export-time, committed, and with a *different* commit SHA — **P5**).
Collapse them into **one run manifest** written at the end of the run:
version, `codeState` (sha + status + ignored files), lockfile hash, both manifest hashes,
per-database `dataVersion`, per-task status + timing + output hashes, and the merge
summary. Commit *that* to the release branch. It is small, it is reviewable in a PR, and
it is the artifact that makes "show me what produced this number" answerable — which is
the first bullet of `hidden/pipeline_rationale.md`.

The manifest is also the answer to "how do you iterate versions of a pipeline run": a
release is a *sealed manifest*, and the diff between two releases is a diff between two
manifests.

### 8.8 Data-quality gates as part of the run, not after it

**Dagster asset checks** run as part of materialisation and can block downstream assets;
dbt has `tests`; the OHDSI world has **DQD**, which StudyStudio uses as a hard gate (DQD
failures on study tables block a regulatory pack).

Picard's QC (`validateCohortResults`) runs *after* everything, at export, and its outcome
is a CSV column. Nothing can fail on it. At minimum: make `qcStatus` reflect merge
failures (**P2**), and let a production run refuse to produce an export when cohorts are
missing or zero-count — with an explicit override.

### 8.9 Declared, validated inputs

**nf-core** pipelines ship a `nextflow_schema.json`; params are validated against it at
launch and the run aborts on a violation. **Strategus** goes further within OHDSI
itself: the entire study is a JSON **analysis specification**, modules declare their own
`renv.lock`, connection details live in the **keyring** by
`connectionDetailsReference`, and (since 0.2.0) a missing keyring reference produces an
informative error rather than a mid-run failure.

Picard's equivalents already half-exist: `validateConfigYaml()` + `validateSecretsYaml()` +
`~/.picard/secrets.yml` with `!expr` resolution. Two borrowings:

1. Give `config.yml` a real schema (required keys per block, types, allowed values) rather
   than a structure check, and validate `!expr` secrets *resolve* in pre-flight rather
   than at connection time. Combined with **#131** (env vars) this is the CI story.
2. The EGP question in **#154** ("write first, or generate from code?") is precisely
   Strategus's analysis-specification question, and Strategus answered *write first, as
   data*. Worth weighing — it is the opposite of the lean you expressed in that issue.

### 8.10 One summary table

| Idea | Source | Picard gap it closes | Cost |
|---|---|---|---|
| Standalone dry-run / status command | DVC, Snakemake, `targets` | G5, G8, X-1 ordering | Low — export existing code |
| Working-directory lock + `--unlock` | Snakemake | G4 | Low |
| Named re-run triggers | Snakemake, `targets` | #130, #136 generalised | Low |
| Verify outputs exist before skipping; `incomplete` status | Nextflow, Snakemake | §8.6, P1 | Medium |
| Data version via an observable source (CDM probe) | Dagster | the missing third change axis; D7 | Medium |
| Single committed run manifest | DVC, StudyStudio | P5, X-9, audit trail | Medium |
| Changelog/version from commits, bump on promotion | semantic-release | #128, #138, #147, X-1 | Medium |
| Code-package snapshot at run start | Metaflow | X-1, X-10 | High |
| QC as a blocking gate | Dagster, DQD/StudyStudio | P2 | Low–medium |
| Sealed export pack w/ file hashes + PHI gate | StudyStudio, #142 | P6, P7, release semantics | Medium |
| Config schema + resolvable-secret check | nf-core, Strategus | G8, #131 | Medium |

Sources:
[Snakemake CLI](https://snakemake.readthedocs.io/en/stable/executing/cli.html) ·
[Snakemake FAQ (locking)](https://snakemake.readthedocs.io/en/stable/project_info/faq.html) ·
[Nextflow caching and resuming](https://www.nextflow.io/docs/latest/cache-and-resume.html) ·
[nf-schema parameter validation](https://nextflow-io.github.io/nf-schema/latest/parameters/validation/) ·
[nf-core schema docs](https://nf-co.re/docs/nf-core-tools/cli/pipelines/schema) ·
[targets `tar_cue`](https://docs.ropensci.org/targets/reference/tar_cue.html) ·
[dbt slim CI / defer](https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake-slim-ci-defer-to-prod) ·
[DVC running pipelines](https://doc.dvc.org/user-guide/pipelines/running-pipelines) ·
[DVC repro](https://doc.dvc.org/command-reference/repro) ·
[Dagster asset freshness policies](https://github.com/dagster-io/dagster/blob/master/docs/docs/guides/observe/asset-freshness-policies.md) ·
[Dagster assets API](https://docs.dagster.io/api/dagster/assets) ·
[Metaflow technical overview](https://docs.metaflow.org/internals/technical-overview) ·
[Metaflow `@project`](https://docs.metaflow.org/api/flow-decorators/project) ·
[OHDSI Strategus](https://ohdsi.github.io/Strategus/reference/index.html) ·
[OHDSI StudyStudio](https://github.com/OHDSI/StudyStudio) ·
[python-semantic-release commit parsing](https://python-semantic-release.readthedocs.io/en/latest/concepts/commit_parsing.html)

---

## 9. Decisions in full

All seventeen were settled on **2026-11-20**. Each records the decision, its rationale,
its consequences, the alternatives rejected and why, and any open follow-on. Where a later
decision revised an earlier one, the revision is recorded in place rather than silently
applied — those notes exist to stop settled questions being re-litigated.

`hidden/decisions_v1.md` is a superseded snapshot of the pre-decision state and is not
maintained.

### D1 — What a pipeline run is, and where it terminates — **SETTLED 2026-11-20**

**Decision.** A run is six steps, each a separate public function, shown in sequence in
`main.R`:

| # | Step | Function | Required? |
|---|---|---|---|
| 1 | Verify the code state is clean before anything runs | `preFlightChecksForStudy()` | required |
| 2 | Source the input builders and establish the manifest | `sourceInputBuilders()` | required |
| 3 | Generate cohorts and execute tasks | `executeStudyPipeline()` | required |
| 4 | Finalize extraction, merge results, run basic formatting (`pretty`), attach metadata, snapshot `egp.md` | `runPostProcessing()` | required |
| 5 | Build the aesthetic layer that visualizes the data product (quarto, workbook, deck) — also useful for QC | `prepareForPublish()` | **optional** |
| 6 | Close out the run: final checks, prepare the PR | `promoteRelease()` | required |

**The pipeline is done at step 4.** That is where the data product is formed. Step 5 is
optional — an organization may add it to review results, but it is not a requirement.

**Rationale.** The terminus is the last step whose failure invalidates the result. If
`prepareForPublish()` errors — a CSS bug, a Quarto version bump, a pandoc change — the
numbers are still right and the release still stands. If the merge fails there is nothing
to hand anyone. Reinforcing it: renv pins R packages but cannot pin the **Quarto CLI** or
pandoc, and a rendered site embeds render timestamps, so a publish step inside the run
would break the run's own reproducibility claim with a dependency picard cannot lock.
picard's code already assumed this — `quarto` is in **Suggests**, and `buildStudyHub()`
loads it via `require_pkg()` at call time (`R/studyHub.R:101`).

**Consequences.**

- Post-processing moves *inside* the run's success criterion. Today the pipeline reports
  success before anything is merged or QC'd; after this it cannot.
- **`pretty` moves into the required path** (step 4), not an optional tier. The settled
  tiers are therefore: **Run** = steps 1–4 (ends in the data product) · **Publish** =
  step 5 (optional, swappable) · **Promote** = step 6.
- This resolves the earlier "is `pretty` a tier or a sibling" question by putting it inside
  `runPostProcessing()` and giving the publish targets their own folder (see D3).
- Step 4 is the **merge boundary** — where data crosses from gitignored per-database
  `exec/` into `export/`. #142's patient-identifier guard belongs at that boundary (see
  D13). This follows from step 4 being required, not from `pretty` moving into it.
- The publish tier being optional means the Study Hub is **not** part of the run even if an
  organization mandates it as a deliverable. Those are separate things.

**Rejected.** Terminating at a rendered Study Hub — it would make the run's reproducibility
claim false and couple every aesthetic change to a full re-run across all databases.

### D2 — Where the EGP lives — **SETTLED 2026-11-20, revised same day**

**Decision.** The EGP is **authored as `egp.md` at the repository root and snapshotted
into `dissemination/export/egp.md` by step 4.** The export copy is generated output, not a
hand-maintained file.

At the root it is a peer of `README.md` and `NEWS.md` — all three are top-level narrative
documents about the study — and it is unmissable, which suits the most important document
in the repo.

The first form of this decision put the EGP *only* in `export/`. That created a collision:
a hand-authored file inside the folder `runPostProcessing()` owns and clears (D9). Copying
it in resolves that, and resolves it better than a carve-out would.

**Why this is a snapshot, not duplication.** picard already does exactly this with the
cohort manifest: the source of truth is `inputs/cohorts/cohortManifest.sqlite`, and step 4
writes `cohortManifestSnapshot.csv` into the export (`R/postProcess.R:796`). Nobody calls
that duplicative, because the copy records *the state that produced these numbers*.
`export/egp.md` at tag `v1.2.0` is the plan as it stood when those results were made. Edit
the source afterwards and the divergence between the two is the information you want.

The storage objection from D16 does not bite here: the two files are byte-identical within
any release commit, so git deltas them to near nothing. What D16 objects to is N
near-identical *trees* accumulating side by side, not one small file snapshotted per
release.

**The payoff — this closes D9's blocker.** With the EGP copied rather than authored in
place, **`export/` contains nothing hand-authored**: it is entirely generated output.
D9's clearing rule needs no carve-out, and the "must be resolved before step 4 is built"
blocker is gone rather than deferred.

**Consequence for D3.** **Neither `extras/` nor `documents/` is scaffolded.** Anything
important enough to be required belongs at the root, not filed under a folder named for
miscellany — and with nothing required in `extras/`, no folder is left half-managed.
`.gitignore` should still carry `extras/` defensively, so an ad-hoc junk drawer an analyst
creates cannot commit a scratch extract into git history — the same hazard D17 guards,
entering by a different door. One line, no structure.

**Rejected.**

- *EGP only in `export/`* (the first form of this decision) — a hand-authored file in a
  generated folder.
- *Reference instead of copy* — record the EGP's path, content hash and commit SHA in the
  export metadata and keep one file. One fewer file, but the export stops being
  self-contained: hand someone the folder and they do not have the plan. Self-containment
  was this decision's rationale, so the copy stays.
- *`extras/egp.md`* — avoided a top-level file, but filed the repo's most important document
  under miscellany and blocked `extras/` from being gitignored.
- *A dedicated `documents/` folder* — a new top-level folder for one file. Revisit **only
  if** a protocol and SAP are actually committed too; three narrative documents at the root
  would be the trigger to group them.
- *`inputs/egp.md`* — the stricter parallel to the cohort manifest, and conceptually clean
  (`inputs/` declares, `export/` holds output plus snapshots of what was declared), but an
  analyst looking for "the plan" does not look in `inputs/`, which holds machine-readable
  definitions.

**Open follow-on.** Whether step 4 copies any other root document — a protocol or SAP would
make the export a fuller standalone bundle, but makes step 4 responsible for documents it
cannot validate. Narrow default: copy `egp.md` only, by name; make anything further an
explicit list, never a glob.

**Coupling to #154 unchanged:** if the EGP is written first it is a governing document
(the root, as decided); if it is generated from the code it is pipeline output and belongs
under `dissemination/`. Settling #154 confirms or reopens this.

### D3 — The repository structure — **SETTLED 2026-11-20**

```
<repoName>/
├── <repoName>.Rproj                 .initRProj          templates/rproj.txt
├── README.md                        .initReadMe
├── NEWS.md                          .initNews
├── config.yml                       .initConfigFile
├── main.R                           .initMainExec       templates/main.R
├── egp.md                           REQUIRED — authored EGP, source of truth (D2)
├── AGENTS.md                        .initAgent                       ← gitignored
├── .agent/                          .initAgent                       ← gitignored
├── .gitignore                       .addGitIgnore
├── renv.lock  renv/                 .addRenvLockFile
│
├── inputs/
│   ├── cohorts/{json,sql,derived,R}/            listDefaultFolders
│   │   ├── cohortManifest.sqlite                SCAFFOLDED, empty but valid (D11)
│   │   └── cohortsLoad.csv                                 ✦ runtime
│   └── conceptSets/{json,R}/                    listDefaultFolders
│       ├── conceptSetManifest.sqlite            SCAFFOLDED, empty but valid (D11)
│       └── conceptSetsLoad.csv                             ✦ runtime
│
├── analysis/
│   ├── tasks/                                   listDefaultFolders
│   └── src/                                     listDefaultFolders
│
├── exec/                            ← gitignored, no .gitkeep
│   ├── logs/                                    listDefaultFolders
│   └── results/{db}/{version}/{task}/           listDefaultFolders
│
└── dissemination/
    ├── export/      REQUIRED   the data product — merged results, metadata,
    │                           and egp.md snapshotted from the root by step 4
    ├── pretty/      REQUIRED   R scripts applying finishing touches to the export
    └── publish/
        ├── quarto/     OPTIONAL
        ├── deck/       OPTIONAL   pptx
        └── workbook/   OPTIONAL   xlsx
```

**Decided changes from today.**

- **`egp.md` at the repository root**, the authored source, snapshotted into `export/` by
  step 4 (**D2**, revised twice — its first form put the EGP only in `export/`, which
  collided with D9's clearing; its second put it in `extras/`, which blocked `extras/` from
  being gitignored).
- **No `extras/` and no `documents/` folder** — anything required lives at the root.
  `.gitignore` carries `extras/` defensively so an ad-hoc junk drawer cannot commit what is
  dropped in it.
- **`test_main.R` is gone** — picard scaffolds and supports one orchestration file. See D4.
- `dissemination/export/pretty/` and `export/studyHubOutput/` deleted (**X-11**).
- `export/merge/v{version}/` collapsed to `export/` (**D6**) — a breaking path change
  across six function signatures (`R/postProcess.R:41`, `:263`, `:374`, `:609`, `:913`) and
  the path builder at `R/execute.R:1773`, plus the vignettes and `inst/agent/` docs.
- `pretty/` is **scripts only** — its output lands in `export/`, since step 4 formats the
  data product in place. No `pretty/output/`.
- Publish targets nest under `publish/`, created on demand rather than scaffolded.
- **Some folders are created by `make*()` helpers, not the scaffold** — `analysis/src/sql/`
  (`makeSrcSqlFile()`), and `inputs/cohorts/R/sql/` for custom cohort-building templates.
  These are deliberately absent from `listDefaultFolders()`.
- No `.gitkeep` under gitignored `exec/`.

**Still to do in this decision.**

- [ ] One folder-creating authority — fold `initStudyHubFiles()`'s folder creation into
      `listDefaultFolders()`, or have it declare what it creates
- [ ] Gitignore `publish/quarto/_site/` and `.quarto/` (**X-15**), and decide the same for
      the other publish targets' build output
- [ ] Separate sources from artifacts inside each publish target (`<target>/R/` for
      scripts) so **X-15** does not recur once per target
- [ ] Confirm the `inputs/conceptSets/` asymmetry is intentional — no `sql/`, no
      `derived/`, unlike `cohorts/` — and say so, since #161 otherwise commits to parity
- [x] Neither `extras/` nor `documents/` is scaffolded; no `test_main.R` (D2, D4)
- [ ] Scaffold root `egp.md` from a template and add a pre-flight check that it exists
- [ ] Add `extras/` to `.gitignore` as a defensive one-liner
- [ ] Regenerate `vignettes/picard_repository_structure.Rmd` and the `inst/agent/` files
      from it; fix the `.gitignore` description and the `CLAUDE.md` reference (**X-14**)

### D4 — Where the code boundary goes — **SETTLED 2026-11-20**

**Decision.** Six separate public functions, as listed in D1. **Do not wrap execution and
post-processing into one function** — keep the API separate. `main.R` shows every step
explicitly so an analyst can read the whole run in one file and run any step on its own.

This is option (c) from the earlier framing, extended from three verbs to six. Option (b)
— one function owning the whole arc — is explicitly rejected: it hides the pipeline from a
template whose purpose is to be readable.

**Consequences.**

- `runPreflightChecks()` becomes exported and is renamed `preFlightChecksForStudy()`
  (closes **G5**: the checklist can finally be run on its own, before any branch cut or
  version math).
- `sourceInputBuilderScripts()` → `sourceInputBuilders()`.
- `execStudyPipeline()` → `executeStudyPipeline()`, and shrinks: it generates cohorts and
  runs tasks, nothing else. The branch cut, version bump, PR preparation and pre-flight all
  leave it.
- New: `prepareForPublish()` and `promoteRelease()`.
- Six independent entry points means each must validate its own preconditions rather than
  trusting a caller — a step run out of order has to say so.

**Version provenance — CONFIRMED 2026-11-20.** Steps 3 and 4 write under
`exec/results/{db}/{version}/` and `export/`, so a version must exist *before* them, but
**X-1** says the tree must not be dirtied before the run (that is what breaks the second
production run today). Settled arrangement:

| Step | Does |
|---|---|
| 1 `preFlightChecksForStudy()` | computes and announces the **prospective** version; writes nothing |
| 3–4 | write results and the export under that version |
| 6 `promoteRelease()` | writes it to `config.yml` / `NEWS.md` and commits |

So the version exists as a value from step 1 and becomes a *fact in the repo* only at step
6. A run that fails at step 3 leaves no version bump behind — which is the whole point of
**X-1**. Consequence: `.computePipelineVersion()` (X-4) is called by step 1 and its result
is passed forward, not recomputed per step.

**One supported orchestration file — SETTLED 2026-11-20.** picard scaffolds and supports
**`main.R` only**. `test_main.R`, `addTestMainFile()` and `inst/templates/test_main.R` are
deleted. Analysts run the test workflow themselves.

Why this follows from what is already settled:

- Today `main.R` and `test_main.R` are two near-identical orchestration templates written
  from two template files and kept in sync by hand — the same duplication this review has
  been removing everywhere else.
- **D7** reduced the two lanes to a *single* difference: the internal lane is a named test
  namespace, the release lane is a semver. Nothing else about the run differs.
- **D4** makes all six steps independently callable, so the internal lane is the same six
  calls with `pipelineVersion = "qc_nov"`. There is nothing left for a second template to
  express.

Deleting it also removes the last thing that needed `extras/` (D2, D3).

**What picard still owes the test workflow.** Not a template, but the functions have to
make it obvious:

- `executeStudyPipeline(pipelineVersion = "qc_nov")` *is* the test run — so the test
  namespace must be a first-class argument on the six verbs, not an afterthought.
- `testStudyPipeline()` becomes a redundant wrapper around that and can go with the
  template.
- **`testStudyTask()` should stay.** Running one task at the console has no six-step
  equivalent, and it is the thing analysts actually reach for while iterating.
- `vignettes/running_the_pipeline.Rmd` has to document the internal lane as a way of
  *calling* the six steps rather than as a file to open, or analysts will reach for a
  release run to test with.

### D5 — The branch model — **SETTLED 2026-11-20**

**Decision.** Option (a): require `develop` (hard fail otherwise), cut `release/x.y.z` from
it, PR into `main`, and **`on.exit` back to `develop`** on every exit, success or failure.

**Rationale.** Always returning to `develop` keeps `main` purely read-only — it holds only
merged release candidates and is never a working branch.

**Consequences.**

- Pre-flight check 12 (release-branch freshness) becomes **enforceable** rather than
  warn-only.
- **#127** closes with the finding that `gert::git_branch_create()` defaults to
  `ref = "HEAD"`, so the branch was never cut from `main` — the issue's premise was wrong;
  what was missing is the enforcement this decision adds.
- **X-10** is fixed by the `on.exit`.
- Remote-sync checking stays a warning, not a failure — analysts legitimately run offline.

> **Open follow-on surfaced by D16: the merge strategy.** This decision settled *which
> branch*, not *how the release PR merges*. If it is **squash-merged**, the release-branch
> commits do not exist on `main`, so a tag created on that branch points off main's history
> and D16's `git show v1.2.0:...` retrieval resolves to an orphan. Either release PRs merge
> as a **merge commit**, or the tag is created on `main` after the merge. Pick one — the
> retrieval story breaks silently otherwise (**X-20**).

### D6 — What a production run commits — **SETTLED 2026-11-20**

**Decision.**

- **Commit `dissemination/export/`.** It holds the ultimate data product and belongs in
  version control.
- **Drop the version number from the export path.** `v{version}` duplicates what git
  already stores.
- **Keep `exec/` gitignored.** That is what keeps concurrent analysts' runs separate, via
  `pipelineVersion`.
- **Metadata goes in the export folder**, with the results.

**Rationale.** Git already is the version store; `export/merge/v{version}/` was
reinventing it one directory inside a version-controlled tree, which is where the
duplicate copies came from. Collapsing to a stable path makes release history a matter of
tags and diffs: `git show v1.2.0:dissemination/export/...` and
`git diff v1.1.0 v1.2.0 -- dissemination/export/`. Neither is possible today, because the
two releases live at different paths.

**Consequences.**

- Answers D3's metadata question: `databaseInfo.csv`, `schema_review.csv`,
  `cohortManifestSnapshot.csv`, `qc_cohortValidation.csv` and `qc_processMeta.csv` stay in
  `export/` rather than moving to a documents folder. #142's relocation request is
  therefore **declined** — its PHI gate and allowlist still stand (see D13).
- A release becomes reviewable in a PR: a reviewer sees the numbers move.
- Needs helpers so nobody types git plumbing — `getReleaseExport(version)`,
  `diffReleases(a, b)`.
- **The `compress` argument is removed** (**X-13**) — a gzipped CSV stores a full new blob
  on every one-row change, and no valid use remains once `export/` is the only thing step 4
  writes. See D16.
- **Write-if-changed**, implemented as a sync inside D9's staging swap (D16), and
  `executionTimestamp` moves out of `qc_processMeta.csv` into the run manifest (**X-12**),
  or every no-op re-run produces a commit.
- **The release tag is created by step 6** (**X-20**) — without it, `git show v1.2.0:...`
  has no handle and this decision's retrieval story does not work. See D16.
- `publish/` build output stays **ignored** — it is regenerable from `export/` and is
  where **X-15** lives.
- Release metadata (`config.yml`, `NEWS.md`, `README.md`, the run manifest) is committed by
  step 6, which is the fix for **X-1**.

**Still open (D16):** the size measurement. If a single export file exceeds ~50 MB GitHub
warns and at 100 MB blocks the push, at which point committing the export stops being
viable regardless of layout and the hashes-in-git/bytes-outside fallback applies. One
`du -sh` on an existing study repo settles it.

### D7 — Release semantics — **SETTLED 2026-11-20**

**Decision.** Start with option (b) — **two lanes, one version counter** — with room to
grow into option (c).

- **Internal / QC lane:** a named test namespace. No version, no release branch, no PR.
  This already works end to end: `testStudyPipeline(pipelineVersion = "qc_nov")` writes to
  `exec/results/{db}/qc_nov/`, and post-processing merges it (test mode is inferred from
  the non-semver string).
- **Release lane:** a single-tier semver bump, release branch, PR, committed export.

So there is **no separate "minor release"** concept: the internal lane is the test
namespace. `major`/`minor`/`patch` stops being a question the production path asks.

**Room to grow — option (c):** derive the bump from *what changed* rather than asking.
That needs the data-version probe from §8.5 first; without it, a derived bump would
silently miss a CDM refresh, which is the most common reason to re-run a study.

**Consequence.** Record *why* a release differs from its predecessor in the run manifest
(D15), not in a version digit. The useful artifact is a diff between two runs, not a
numbering scheme.

### D8 — Non-interactive execution — **SETTLED 2026-11-20**

**Decision.** **No interactivity in the pipeline. Remove `readline()` entirely** — it is an
old idea that no longer fits.

**What this removes.**

| Prompt | Location | Replacement |
|---|---|---|
| `NEWS.md` changelog loop — unguarded `repeat { readline() }`, an infinite loop under `Rscript` | `R/execute.R:115-128` | An argument on step 6 (`newsEntry =`), or generated from the release branch's commits |
| Missing-cohort continue/abort prompt | `R/validation.R:891` | An explicit argument, e.g. `onMissingCohorts = c("abort", "skip")`, defaulting to abort |
| Cohort-generation confirmation | `R/execute.R:297` | Already bypassed in the pipeline (`override = TRUE`); drop the prompt |

**Consequences.**

- **#128** closes.
- Scheduled and CI-driven runs become possible, which makes **#131** (env vars in
  `config.yml`) the next thing needed for that path.
- Every decision a prompt used to ask becomes a named argument, so a run is fully
  described by its call — which is also what makes the run manifest (D15) complete.
- Anything that genuinely needs a human judgement moves **out of the run** into a console
  command run between runs, with the result committed. D17's export manifest is the worked
  example: the pipeline reads it, `approveExportFiles()` regenerates it, and step 6 enforces
  it — the `renv::snapshot()` / `renv::restore()` split.

### D9 — Freshness and idempotency — **SETTLED 2026-11-20, revised by D10**

> **Revision.** The `exec/` **version-folder collision abort is dropped.** D10 showed it
> conflicts with resume: re-running step 3 at the same version after a partial failure *is*
> a collision by this decision's original definition, yet it is exactly the workflow D4,
> D13.10 and D14 created. Per-task change detection distinguishes resume from a genuine
> collision; folder existence cannot. What replaces it: per-task output-folder clearing when
> a task actually runs, plus G3's duplicate-index check. **X-3 is therefore moot** —
> `validateResultsFolderFresh()` is removed rather than fixed. `clearStudyResults()` survives
> for deliberately discarding a version's results after a defective run. Everything below
> about `export/` is unchanged.

**Decision.** The two folders get opposite defaults, because the cost of being wrong is
opposite — and they are triggered differently.

| Folder | When it is cleared | Triggered by | Why |
|---|---|---|---|
| `dissemination/export/` | **every run, automatically** | step 4, as part of writing it | It no longer carries a version segment (D6), so git history *is* the release history. There is never a reason not to clear it, so there is no flag and no command |
| `exec/results/{db}/{version}/` | **rarely, by hand** | analyst, via `clearStudyResults()` | Gitignored, per-analyst, and expensive — hours of database work. Never destroyed implicitly |
| `publish/*` build output | overwritten | step 5 | Regenerable from `export/`, and gitignored (D3, D6). No decision needed |

**Why the `exec/` abort is rare by construction.** The collision only occurs when a run
writes a version that already has results — and in the normal release flow the version
bumps (D7), so `exec/results/{db}/1.2.1/` does not exist yet. The abort never fires and
`clearStudyResults()` is never needed. It exists for two exceptional cases: a defective run,
and a run that completed but with a wrong parameter.

Closes **#117** and resolves **X-3** — `validateResultsFolderFresh()` must be fixed to look
at the real path (`exec/results/{db}/{version}/`, not `exec/results/{version}/`) before
either default means anything, since today the check never fires.

**Also adopted:** the duplicate-task-index validator as a pre-flight check (**G3**), which
is the real risk behind **#151** — two folders like `01_demographics` and `01_demo` both
feeding the merge.

#### The guard that makes clearing `export/` safe

"Git holds the history, so clearing is non-destructive" is true **only if the previous
export is actually committed.** If `export/` is dirty relative to `HEAD`, or holds
untracked files, clearing destroys something git cannot restore.

This repo's wave-1 priority is #166 — `loadCohortManifest()` unlinking user files by
default — so a new clear-by-default behaviour has to meet the same bar. The rule:
**clear only what git can restore, and verify it rather than assume it.**

| State of `export/` | Behaviour |
|---|---|
| clean relative to `HEAD` | clear, with a warning naming the file count |
| dirty, or untracked files present | **abort**, listing what would be lost, and say to commit or stash first |

`egp.md` needs no carve-out: after D2's revision it is snapshotted in by step 4, so
clearing and re-copying is its normal lifecycle.

#### How clearing is invoked — `clearStudyResults()`, not a flag

Pre-flight detects the collision and **aborts, naming the command**:

```
x Results already exist for optum_dod at version 1.2.0 (14 files)
i Run clearStudyResults("optum_dod", "1.2.0"), or increment the version
```

A `clearResults = TRUE` argument was the alternative. Rejected, for three reasons — the
second decisive:

1. **D8's principle.** Anything needing human judgement moves out of the run and into a
   console command run between runs. Deleting hours of database work qualifies.
2. **A flag in `main.R` is a durable hazard.** An analyst sets `clearResults = TRUE` once to
   get past a collision, commits `main.R`, and from then on *every* run silently destroys
   results on any collision. The dangerous state persists invisibly and re-arms itself. A
   console command is a deliberate act each time and leaves no committed trace.
3. **Pre-flight stays a pure check.** D4 made step 1 independently callable precisely so it
   can be run freely; a step that might delete things is not freely runnable.

The cost is one extra round trip, which for a destructive action is the point.

#### The test lane does not abort

The internal/QC lane (D7) **reuses its namespace deliberately** — an analyst iterating runs
`qc_nov` over and over. A collision abort there would fire on the single most common
workflow and demand `clearStudyResults()` every time, so it must not apply. Today's check
is already skipped in test mode (`R/validation.R:698`), which is right, but it should be a
deliberate rule rather than an inherited behaviour:

| Lane | On collision |
|---|---|
| release (semver version) | **abort**, naming `clearStudyResults()` |
| internal (test namespace) | proceed; overwrite per task as each task runs |

The test lane still needs protection, because accumulation there is how **#117** and
**#151** arise: rename `05_foo` to `05_bar` and the orphaned folder lingers, so the merge
picks up both. That is covered by **G3**'s duplicate-task-index pre-flight check, not by an
abort.

#### Granularity — per config block

`exec/results/{db}/{version}/` is cleared **per database, as that block starts**, not for
the whole version up front. This matches D14's per-block failure isolation: a run that
fails on `optum_dod` has not already destroyed `cprd`'s prior results for that version.

#### Step 4 writes through a staging directory

Clearing `export/` at the start of step 4 creates a state worse than either endpoint:

```
t0   export/ holds release 1.2.0 — committed, complete
t1   step 4 clears export/                      → empty
t2   merges tasks 1, 2, 3 … fails on task 4     → e.g. a schema mismatch (P2)
t3   export/ holds a partial merge: 3 tasks, no metadata, no QC files, no egp.md
```

Nothing in the folder says it is partial. Git can restore 1.2.0, but only if someone
notices and knows to.

**So step 4 writes into a staging directory and swaps it in only on full success.** On any
failure the staging directory is discarded and `export/` is untouched, still holding the
previous release. `export/` is only ever all-old or all-new, never half-written.

**This is also where D17's disclosure guard runs.** The guard has to inspect files *before*
they reach the committed folder: merge into staging, run the identifier-column check and
`minCellCount` suppression there, swap only if it passes. If a patient-level column turns
up, nothing ever touched `export/` and there is nothing to un-commit. #142's wrapper
already works this way — it stages approved CSVs into a temp directory and points picard at
it. One mechanism covers atomicity and the guard.

Consequence: the staging directory must be outside `export/` and gitignored, and must be
removed on exit whether or not the step succeeded (`on.exit`).

#### Not a picard concern

`clearStudyResults()` covers `exec/` only. Discarding a bad export without re-running is
`git checkout -- dissemination/export/` — worth stating in the vignette, not worth wrapping
in a function.

### D10 — Change detection — **SETTLED 2026-11-20**

#### The premise changed: resume is now a real workflow

"Production always re-runs, so the cache is a test-lane accelerator" was true while
`execStudyPipeline()` was one monolith. It is not any more:

- **D4** made the six steps independently callable,
- **D13.10** made "fix and re-run step 4 alone" the supported recovery,
- **D14** let a run end with four of five databases.

So **resuming a failed release run at the same version is a first-class workflow.** Task 5
of 12 fails on CPRD; you fix it and re-run step 3, and tasks 1–4 should skip while execution
resumes at 5. The cache is what makes that a resume rather than a restart.

#### Consequence: D9's version-folder abort is dropped

**Revises D9.** A resume *is* a collision by D9's definition — tasks 1–4 already wrote into
`exec/results/{db}/{version}/`. Folder existence cannot distinguish *"this content is from
this run"* (resume) from *"this content is from a different run"* (genuine collision), but
`shouldRerunTask()` can: if the code and input hashes match, it is a resume; if they
changed, the partial results are stale and those tasks re-run anyway.

The cache is the more precise instrument, so the crude proxy goes:

| Mechanism | Covers |
|---|---|
| per-task change detection | is this task's output current? → resume vs re-run |
| **clear a task's output folder when that task actually runs** | stale files left inside a task folder by a prior run |
| G3's duplicate-index pre-flight check | orphaned folders from a renamed task (#151) |
| ~~version-folder freshness abort~~ | **dropped** — the three above cover everything it was groping at |

This also makes **X-3** moot: `validateResultsFolderFresh()` is removed rather than fixed.
`clearStudyResults()` (D9) survives for the case the cache cannot help with — deliberately
discarding a version's results after a defective run.

#### 1. Production keeps version-scoped history — **SETTLED**

History stays keyed on (task, config block, pipeline version). Re-keying on content was
rejected: a release is a statement about a whole run at a point in time, and one where 8 of
12 tasks are inherited from an earlier version is hard to defend to a reviewer and harder
to re-derive. Within a version, resume is supported and is what the cache is for in the
release lane.

#### 2. Verify outputs still exist before skipping — **SETTLED**

The cache declares a task up to date without checking its outputs are still on disk
(`R/taskTracking.R:54`). Delete `exec/results/db_a/1.2.0/05_foo/` and the task still skips —
then D13's merge silently reports fewer databases. Nextflow explicitly verifies a cache hit's
outputs are recoverable before reusing it (§8.6).

**Decision:** record each task's output file list and SHA-256 in the cache, and skip only if
all of them are still present. D15 needs those hashes anyway, so the cost is shared.

#### 3. An `incomplete` status — **SETTLED**

A run killed mid-task (Ctrl-C, cluster timeout) can leave half-written output and no history
row, which is indistinguishable from a task that never started.

**Decision:** write a `running` row when a task starts and overwrite it with
`success`/`failed` at the end. A `running` row found at startup means the previous run died →
treat it as failed and re-run. Snakemake's pattern (§8.6).

#### 4. Tasks must not read other tasks' output (#136) — **SETTLED**

**Decision: option 1 from #136.** `validateStudyTask()` **fails** on a data read referencing
a results location (`exec/results`, `outputFolder`, `setOutputFolder()`,
`resolveResultsPath()`, `dissemination/export`), and **warns** on other data-file reads so
the analyst knows changes to them will not trigger a re-run.

Why the strict option now: under per-block isolation (D14) a producing task may not have run
at all, so cross-task file reads are more fragile than when #136 was filed. And there is now
a sanctioned alternative — if task B needs task A's output, either they are one task, or the
combination belongs in step 4.

Breaking for studies doing this today, which this release tolerates. #136's other options
(runtime tracing, declared inputs) stay on the shelf; the static scanner's blind spots
(#136 option 3) matter less when the rule is "don't", not "track it".

Note the related existing bug recorded in #136: `.checkDependencyChanges()` never stores
dependency hashes, so any task that `source()`s a file currently re-runs unconditionally.

#### 5. The `dataVersion` probe — **SETTLED in shape**

This is the missing third change-axis: the pipeline tracks **inputs** and **code** but is
blind to **data**. A CDM refresh is invisible — same code, same manifest, different data,
and every task skips. picard queries nothing about the CDM today: no `cdm_source`,
`vocabulary_version`, `cdm_version` or `cdm_release_date` anywhere in `R/`.

**Decision:** probe OMOP's own `cdm_source` table per database — `cdm_version`,
`vocabulary_version`, `cdm_release_date`, `source_release_date` — hash them into a
`dataVersion`, record it per database in the run manifest (D15), and expose it as a named
re-run trigger, **off by default until trusted**.

Two small queries, no table scan. Design for the realities:

- `cdm_source` is sometimes empty or has multiple rows → fall back to the `vocabulary`
  table's conventional version row;
- if neither resolves, record `unavailable` and **warn** — a probe must never fail a run.

Rejected as too expensive for every run: `max(observation_period_end_date)` and key-table
row counts. Informative, but they scan.

#### 6. Named re-run triggers, and #130's other half — **SETTLED**

`executeCohortGeneration()` has no `force` argument (`R/CohortManifest.R:5216`), so there is
no way to force regeneration past the checksum stored in the work schema. That is **#130's
unaddressed half** — `forceRerun` already covers tasks.

**Decision:** add `force` to cohort generation, and replace the accumulating booleans with
§8.4's named triggers:

```r
executeStudyPipeline(..., rerunTriggers = c("code", "inputs", "env", "failed"))
```

`forceRerun = TRUE` becomes "no triggers", the cohort override becomes a trigger name, and
`data` slots in when the probe above is trusted. Snakemake's `--rerun-triggers` and
`targets`' `tar_cue()` are the precedents.

#### 7. Validate before the skip check — **SETTLED**

`execute_task()` runs the skip check at `R/execute.R:493` and `validateStudyTask()` at
`:503`, so **a skipped task is never validated.** The consequence that matters: when picard
adds a validation rule, previously-passing tasks are never re-checked because they skip, and
an invalid task persists indefinitely.

**Decision:** validate first, unconditionally. It is a parse plus regex over one file.

### D11 — Input builders: production vs authoring — **SETTLED 2026-11-20**

Builds on **#163**, whose four recommendations stand (no teardown in production; verify
mode; authoring/test/production modes; manifest init moves into picard). But D1 and D4
changed the terrain under two of them, and four questions #163 left open are settled here.

#### D1/D4 already decided the shape

**`skipInputBuilders` disappears.** It exists in nine places (`R/execute.R:663` onward)
because builders were an optional sub-phase *inside* the pipeline. D4 made
`sourceInputBuilders()` **step 2** — separate, required, explicit in `main.R`. There is
nothing left to skip.

**That also removes #163's escape hatch.** #163's problem 2 was that the default path is
wrong for database-specific builders, and its workaround was `skipInputBuilders = FALSE` to
interleave builders per config block. **That option no longer exists:** step 2 runs once,
then step 3 runs per block, and interleaving would break the step model.

So D1 forces the answer #163 left open. It is not "whether the per-database loop collapses"
— **the six-step model makes collapsing mandatory, and #144 is what makes it safe.**
Database-specific manifest content must be expressed by `databaseId` on rows, not by
re-running builders per database. Until #144 lands, step 2's internal loop over `dbIds` is a
workaround with known-broken semantics (last database wins).

**D11's end state is therefore blocked on #144.** Everything else below can ship first.

#### Verify mode, and why D10 strengthens it

**Decision: verify mode is on by default in the release lane.** #163 left this open
("default or opt-in for one release"); a release whose builders would mutate the manifest is
not releasable, which is the point, and this release tolerates the breaking change.

D10 gives it support #163 did not have: the cohort and concept-set manifest hashes are
re-run triggers, so if a release run's builders mutated the manifest mid-run, the hash
snapshot step 3 takes would describe something other than what the release claims. **Verify
mode is what makes D10's input triggers meaningful in the release lane**, not merely a
reproducibility nicety.

D7's two lanes map onto #163's three modes: authoring is console work (not a pipeline step),
the internal lane creates, the release lane asserts.

#### Both manifests always exist, and the scaffold creates them — **SETTLED**

**Decision:** `conceptSetManifest.sqlite` is always present, empty if the study uses no
concept sets — and **both manifests are created by `initUlyssesRepo()`**, not on first use.

Why: empty and absent mean the same thing operationally, so the distinction was costing a
branch in every code path that touches a manifest. Pre-flight check 8 becomes *"N concept
sets registered"* where N may be 0, which is clearer than a conditional warning saying "OK
if concept sets not used". And if both are always needed, the scaffold is where they belong.

Three consequences:

| | |
|---|---|
| the chain narrows | **scaffold creates → `ensureStudyManifests()` repairs → release asserts.** `ensureStudyManifests()` stays, but as a rare repair path (a pre-change repo, a deleted file, `initUlyssesRepo()` on an existing directory), not the normal route to existence. Better than #163's design, where creation was normal and happened inside template code |
| two functions become idempotent | `initCohortManifest()` / `initConceptSetManifest()` warn and return `NULL` when a manifest exists (`R/manifest_helpers.R:186`) — which becomes *every* call once the scaffold creates them. **The warning is the defect, not the function**: make them quiet when the manifest is already present, and #163's template guards disappear with no API change. See the note below — an earlier draft of this decision said "retire them", which was wrong |
| D3's tree changes | both `.sqlite` files move from `✦ runtime` to scaffolded. They are committed, not gitignored, so every new study repo starts with two small empty-but-valid sqlite files |

**#69 is largely defused** — the file always exists with a valid schema, so `dbConnect`
cannot create a table-less one on the pipeline path. The root-cause guard still lands, since
a free function can still be pointed at a nonexistent `dbPath`.

##### Correction: the init functions are kept, not removed

An earlier draft recorded retiring `initCohortManifest()` / `initConceptSetManifest()` and
pointed at `resetCohortManifest()` as the replacement. Both halves were wrong:

- `resetCohortManifest()` resets an **existing** manifest (`scope = derived|manifest|full`,
  `R/manifest_helpers.R:340`); it does not create one. Creation is taken over by the
  scaffold plus `ensureStudyManifests()` — teardown and creation are different jobs.
- They are **exported**, with **30 call sites across 14 files** — six builder templates,
  four `inst/agent/` docs, four vignettes, and `R/`. The agent docs are generated from the
  vignettes, so removal means rewriting the manifest-management documentation as well.

**Decision: keep them exported and make them idempotent.** That fixes the one real defect
(the warn-on-every-call that forced #163's template guards) at zero breakage.

| Function | Role |
|---|---|
| `initCohortManifest()` / `initConceptSetManifest()` | **exported**, idempotent — the documented user-facing verbs |
| `ensureStudyManifests()` | **internal**, called by step 2 |

This is one fewer exported function than #163 proposed: it wanted `ensureStudyManifests()`
exported so the interactive workflow could obtain a manifest in a fresh repo, but with the
scaffold creating both, that case no longer arises in the normal flow.

Note this does not change **#157**: a repo scaffolded by one picard version and opened by a
later one needs incremental migration either way.

#### Missing scripts abort; unexpected scripts warn — **SETTLED**

Today step 2 hard-aborts if any of the six scripts is missing **or** if any unrecognised
`.R` file sits in those folders (`R/execute.R:1538`).

**Decision:** keep the abort on **missing** — that is what makes the mandatory ordering
enforceable — and downgrade **unexpected** to a warning that names the file and says it will
not be sourced. A stray helper should not block a run; it also will not be silently ignored,
because it is named.

#### The fixed six scripts stay; #46 is rejected — **SETTLED**

**Decision: #46 (let analysts organise builder files their own way) is rejected as counter
to the settled design**, not merely deferred.

The mandatory order — concept sets → cohorts → derived cohorts — is a correctness
requirement, not a convention: derived cohorts reference parents, and cohorts can reference
concept sets. A fixed, named set of six files is what makes that order enforceable and what
lets step 2 verify completeness before evaluating anything. A free-form folder cannot be
checked.

`notes_v1_pathway.md` flagged this as needing a decision *before* #163 settles the workflow,
because #162 and #163 both assume the fixed structure. Settled now so it is not
re-litigated: helper code goes in a subfolder (`inputs/cohorts/R/src/`), and `make*()`
helpers may add structured subfolders like `inputs/cohorts/R/sql/` (D3) — but the six
top-level builder scripts are fixed.

#### Sequencing

**#162 before this.** Its per-expression evaluation into an explicit environment (D12) is
the prerequisite — the eval refactor is independent of the loop shape, and #163 changes that
shape. Confirmed from `notes_v1_pathway.md`.

### D12 — Execution environment hygiene — **SETTLED 2026-11-20**

**Decision. The pipeline never uses the global environment.** Every study-authored script —
task, input builder, dissemination — is evaluated per expression into **its own child
environment whose parent excludes `globalenv()`**, and helpers are loaded with a picard
function that sources into that environment rather than into the session.

#### Why: `main.R` runs all six steps in one R session

Today the three paths have three contracts: tasks use `parse_exprs()` + per-expression
`eval(expr, env)` with `env = caller_env()`; builders and dissemination use
`source(file, local = FALSE)` plus an `assign(..., envir = globalenv())` that is never
cleaned up (`R/execute.R:1566`, `:1913`). So in a `main.R` run, **step 2's leftovers are
visible to step 3's tasks**, and a task can accidentally depend on a builder's object. For
background and scheduled runs (D8) that is a correctness hazard, not untidiness.

#### The shape

| | Decision |
|---|---|
| evaluator | one shared `eval_study_script(file, env, ...)` — read, normalize line endings, `rlang::parse_exprs()`, evaluate per expression, **return** a result rather than assigning outward |
| granularity | **one child environment per script** — each task, each builder script, each dissemination script |
| parent | **`parent.env(globalenv())`** — the first attached package, so `library()`-attached packages resolve via the search path while the user's session is **not** in the chain |
| context objects | `inputBuilderEnv` / `disseminationEnv` are **bound in that environment**, not assigned to `globalenv()` — so there is nothing to clean up and no name to collide with |
| return value | the environment, alongside `sourced_files` / `error_summary`, so callers and tests read what a script produced instead of scrubbing `globalenv()` |
| `env` parameter | **dropped from the pipeline path.** The console-debug entry points (`testStudyTask()`) keep an override so an analyst can evaluate into their session while iterating |

Per-config-block isolation falls out for free: step 3 loops blocks and each task gets a
fresh environment inside each.

Nothing legitimate needs cross-script object sharing. Builders communicate through the
**manifest** (sqlite), not the environment; tasks share code through `analysis/src/`; and
D10/#136 made cross-task *data* coupling an error, so cross-task *object* coupling goes the
same way.

#### Helpers: `sourceSrcFile()`, because bare `source()` cannot work

This is the constraint that forces a new function. `source()` defaults to `local = FALSE`,
which means **globalenv** — so a task calling `source("analysis/src/helpers.R")` writes the
definitions to the session and then, with globalenv out of its parent chain, cannot see what
it just loaded.

**Decision:** picard provides a one-line helper that sources into the calling script's
environment:

```r
sourceSrcFile <- function(file) source(file, local = parent.frame())
```

`parent.frame()` inside a function called from an expression evaluated via
`eval(expr, taskEnv)` *is* `taskEnv`, so this needs no plumbing. It pairs with the existing
`makeSrcFile()` / `makeSrcSqlFile()` — one makes the helper, the other loads it — and it
works identically for builder helpers in `inputs/cohorts/R/src/`. Called from the console it
sources into `globalenv()`, which is what an analyst iterating by hand wants, so it degrades
gracefully.

**Bare `source()` in a task becomes a validation failure**, not a runtime one.
`validateStudyTask()` fails and names `sourceSrcFile()` — the same approach D10 took to
#136's discouraged pattern, and far better than a task that loads a helper and then cannot
find it.

Consequently `validateTaskDependencies()` (pre-flight check 11) must scan for
`sourceSrcFile()` as well as `source()`. It currently regexes only the latter
(`R/validation.R:456-462`).

**Blast radius is small:** `inst/templates/task.R` does not source anything — it only calls
`library()`, which modifies the search path and is unaffected. So only studies that added
`source()` calls themselves are touched. Breaking, deliberate, and it needs a NEWS entry
plus a line in `vignettes/developing_the_pipeline.Rmd`.

#### `<<-` removal (#62) — four real sites

The shared evaluator returns a result instead of assigning outward, which removes all of
them:

| Site | What it accumulates |
|---|---|
| `R/execute.R:540` | `executionError` from the task expression loop |
| `R/execute.R:1595` | `errors[[script_label]]` in `sourceInputBuilderScripts()` |
| `R/execute.R:1938` | `errors[[script_label]]` in `sourceDisseminationScripts()` |
| `R/postProcess.R:826` | `hasWarnings` in `runPostProcessing()` |

(`R/manifest_helpers.R:638` also uses `<<-` for `report`, unrelated to this path.)
`R/validation.R` already took this lesson — it carries five comments explaining code
inlined specifically to avoid `<<-`, which is the pattern to follow.

#### Scope note: the tests codify the leak

#162 cites one test asserting a leftover. It is broader — **three test files** assert the
current contract, including
`expect_equal(get("sibs_test_marker", envir = globalenv()), "ran")`, which verifies that a
sourced script's objects land in `globalenv()`
(`tests/testthat/test-sourceInputBuilderScripts.R`, `-sourceDisseminationScripts.R`,
`-createDisseminationEnv.R`). Those assertions must be rewritten against the returned
environment, not merely stripped of cleanup lines. Budget for it.

#### What this unblocks

- **D13.10** promises an error naming the failing script *and expression*, which only exists
  once builders and dissemination use the per-expression loop.
- **#119** (verbose dissemination errors) falls out for free, as `notes_v1_pathway.md`
  predicted.
- **D11's verify mode** gets deterministic semantics: builders that cannot inherit a previous
  block's leftovers give a reliable answer to "would this mutate the manifest?"

#### Left alone deliberately

Tasks are glue-interpolated (`!||configBlock||!`, `R/execute.R:525`) while builders and
dissemination receive context as an object — two mechanisms for one job. Giving tasks a
context object instead would unify all three, but it is a breaking change to every task file
in every study. The shared evaluator takes interpolation as an option and tasks keep theirs.
A future simplification, not this one.

### D13 — Post-processing authority and scope — **SETTLED 2026-11-20**

> **Constrained by D1, D6 and D9.** Step 4 owns merge **plus** `pretty` formatting **plus**
> metadata, and its failure fails the run. D6 keeps the metadata in `export/` (declining
> #142's relocation) and makes the merge boundary the point where data becomes
> irreversible — a patient-level file that is committed and pushed is in git history
> permanently. D9 gives step 4 a staging directory, so a failure leaves `export/`
> untouched.

#### The framing: strictness in step 4 is nearly free

`exec/` holds the raw per-database results, so **re-running step 4 costs seconds**, not the
hours step 3 cost — and D9's staging swap means a failure leaves the previous export
intact. Today's code is permissive because it was written as a terminal step nobody wanted
to lose; under D1 and D9 it is cheap, repeatable and atomic. **Strict is the right default
almost everywhere here.**

(Supersedes this decision's earlier framing, which asked whether post-processing should
move "inside `promoteRelease()`". D1 settled it: post-processing *is* step 4; step 6 is
promote.)

#### 1. Discovery — union, and drop the db1 hard-stop — **SETTLED**

Two inconsistent implementations today:

| | Behaviour | Line |
|---|---|---|
| `runPostProcessing()` | task discovery from `databaseFolderNames[1]` only, and **hard-`stop()`s** if db1's version folder is missing | `R/postProcess.R:678`, `:669` |
| `importAndBind()` | file discovery from the first **existing** folder, tolerating a missing db1 | `R/postProcess.R:71` |

So if db1 did not run, post-processing dies even though every other database has complete
results — while the inner function would have coped. That hard stop goes.

**Decision:** discover by **union across all databases**, and remove the db1 requirement.
Composed with D17's export manifest, discovery becomes a three-way comparison:

| | Is |
|---|---|
| union across databases | what exists — *observation* |
| the export manifest (D17) | what is approved — *intent* |
| the diff | the report |

Unmanifested files found are excluded and recorded (D17). Manifested files missing from
some databases is sub-decision 2.

#### 2. Completeness — warn in step 4, gate in step 6 — **SETTLED**

For each file: **expected** = the databases passed in `dbIds`; **found** = those that
actually had it; **missing** = expected − found.

**Decision:** a non-empty `missing` **warns in both lanes** and is recorded as per-file
coverage in the run manifest (D15). **Step 6 refuses to promote** an export with
unexplained gaps. The export manifest (D17) can record *expected databases per file*, which
turns an acknowledged gap into a non-event rather than a recurring warning.

This follows D17's established division: **step 4 reports, step 6 enforces intent.** A
coverage gap is an intent question — *did I mean for jmdc to be absent here?* — not a
safety one, so it does not belong in the layer that blocks a run. `dbIds` is the right
definition of "expected" because it is the only statement of intent available: the caller
explicitly named the databases this export covers.

#### A missing file is not an empty one

The reason absence warns rather than passing silently is that **a null result and a missing
result look different on disk.** A task that runs and finds nothing still writes its CSV:

| On disk | Means | Treatment |
|---|---|---|
| file present, count > 0 | normal | OK |
| file present, **count 0** | **clinical finding** — the entity is not viable in that database | OK, preserve; **not** a warning |
| file present, zero rows | ambiguous — the task produced no output | warn |
| **file absent** | process gap — task errored, database did not run, write failed | the completeness check above |

A zero count is a data point and must survive to the export intact. An absent file is not a
finding, it is a gap. Conflating them is what makes coverage reporting useless.

Note that change detection does not cause absence: a task skipped as up-to-date (D10) still
has its prior output in `exec/`, so the file is present.

**This exposes a bug today.** `validateCohortResults()` sets
`hasWarnings <- any(validationStatus %in% c("ZeroCount", "Missing"))`
(`R/postProcess.R:818`), so a clinically meaningful zero count produces `HasWarnings` on
every run — the same "trains people to ignore the QC status" failure as the #144 problem
(sub-decision 8). **`ZeroCount` must stop being a warning** (**X-17**); `Missing` stays one.

#### 3. Schema mismatch — hard error, with an opt-in — **SETTLED**

**Decision:** a column mismatch across databases is a **hard error naming the mismatched
columns and the databases**, with an explicit **per-file opt-in to NA-fill**
(`dplyr::bind_rows()` semantics) where a study knows the difference is legitimate.

`rbind` demands identical columns. A column present in one database and not another usually
means something real — a different CDM version, a missing table, a covariate with no data.
NA-filling by default writes a wrong number into a committed, reviewed table.

**P2 is three nested failure paths, not one.** Each is alert-only and none touches
`qcStatus`:

| Layer | Trigger | Today | In the summary? |
|---|---|---|---|
| File absent for a database | `!file_exists` → `NULL`, dropped at `:163` | `successCount` silently lower | only as a smaller `databaseCount` |
| File unreadable, **or columns mismatched** | `read_csv` or `do.call('rbind')` throws | per-file `tryCatch` → alert; **whole file dropped from the export** | no — absent from `exportSummary` |
| Whole task fails | `importAndBind()` throws | outer `tryCatch` (`:705-736`) → alert; task absent from `mergeSummary` | no |

So a merge can lose half its files and the export still looks finished. All three become
errors in the release lane.

#### 4. The disclosure guard — **settled; see D17**

Both of #142's gates adopted, `minCellCount` suppression in scope as a parameter, file gate
is an allowlist, and the guard runs against D9's staged copy before the swap.

#### 5. Where metadata lands — **settled by D6**

Stays in `dissemination/export/` with the results. #142's relocation declined.

#### 6. Bundle subdirectories — hard error, stop guessing — **SETTLED**

When a task folder holds no direct CSVs, `importAndBind()` picks the alphabetically-last
subdirectory containing CSVs and then appends **that one name to every database's path**
(`R/postProcess.R:88-124`):

```r
selectedBundle <- bundleDirs[length(bundleDirs)]      # derived from db1 only
taskFolders <- fs::path(taskFolders, selectedBundle)  # applied to ALL databases
```

Bundle names are timestamps and each database runs at a different time, so db2's bundle
almost certainly has a different name — its path does not exist, `file_exists` is false, and
it contributes nothing. The merge silently reports fewer databases (**X-16**).

**Decision:** replace the heuristic with a **hard error** — *"task folder contains
subdirectories but no CSVs; results must be written directly to the task folder, one
version per `exec/` run."* The upstream practice is being removed from CohortPrevalence in
favour of version bumps in `exec/`, so picard should stop guessing. An error rather than
deleting the branch outright, since another package may write bundles and should be told
plainly rather than silently half-merged.

#### 7. Overwrite protection on write — **SETTLED**

`taskPrefix` prevents collisions *across* tasks, but two task folders sharing an index (the
#151 case — `01_demographics` and `01_demo`) both write `01_*.csv`, and the second
silently overwrites the first.

**Decision:** the write step refuses to overwrite a file it already wrote this run, and
says what happened — naming both source task folders and the colliding output, e.g.

```
x 01_results.csv was already written this run from task 01_demographics
i Task 01_demo would overwrite it. Task indices must be unique.
```

G3 catches this in pre-flight; this is the backstop for anything that reaches the merge.

#### 8. Split the status: functional QC vs content QC — **SETTLED 2026-11-20**

**Decision.** `qcStatus` splits into two independent fields, because they answer different
questions for different readers and conflating them is what let a clinical finding and a
dropped file look identical.

| Field | Question | Owner | Blocks? |
|---|---|---|---|
| **functional / integrity** | did the pipeline work — did everything that should be here arrive? | step 4 | step 6 gates on it |
| **content** | what do the numbers say — zero counts, cohort validation | step 4, read by a reviewer | **never** |

Both live in `qc_processMeta.csv`; the per-cohort detail stays in
`qc_cohortValidation.csv`.

**Values.**

- *functional:* `OK` (everything expected arrived) · `Incomplete` (coverage gaps — warns
  per D13.2, step 6 gates). **A written export is never `Failed`**: a hard error in step 4
  aborts before the staging swap (D9), so no export is written at all. That is a useful
  invariant — the presence of an export means step 4 completed.
- *content:* `OK` · **`HasFindings`** (zero counts present). Deliberately not
  "HasWarnings" — a zero count is a finding, not a defect (**X-17**).

**Third cleanup:** `DevMode` is currently a `qcStatus` value, but the lane is a *fact about
the run*, not a status. It becomes its own field (`lane: release | internal`, per D7)
rather than being smuggled into an enum.

What this fixes: today `OK` means almost nothing — `ZeroCount` inflates warnings (**X-17**)
while dropped files, failed tasks and schema mismatches do not register at all (**P2**).
After the split, functional `OK` means *nothing was dropped*, and that is what step 6 can
safely gate on.

#### 8b. `validateCohortResults()` vs `databaseId` — **DEFERRED to #144**

**Decision: do not build this ahead of time.** The check stays as it is until #144 lands,
and becoming `databaseId`-aware is **in #144's scope**, not step 4's.

Recorded so it is not forgotten, because it breaks the day #144 ships: once cohorts can be
gated per database, every legitimately-gated cohort reports as `Missing` → the functional QC
field goes `Incomplete` on every run, and the status becomes noise. What #144 has to add:

| Status | Means | Contributes to |
|---|---|---|
| present, count > 0 | normal | — |
| `ZeroCount` | not viable in that database — a **finding** | content QC |
| `NotApplicable` | gated out for that database | nothing |
| `Missing` | expected and absent — a **gap** | functional QC |

The expected-databases mapping comes free from `cohortManifestSnapshot.csv`, which step 4
already writes into the export — so there is no plumbing to prepare now. Couples to D11 and
the manifest waves; belongs on #144's checklist.

#### 9. Partial runs — **moved to D14**

Settled there: per-block isolation, and step 4 merges what exists, warns, and lets step 6
gate. See D14.

#### 10. A `pretty` failure errors — and step 4 is re-runnable on its own — **SETTLED 2026-11-20**

**Decision.** A formatting failure is an **error**: step 4 fails, and per D9's staging swap
nothing is written, so `export/` still holds the previous release. **The recovery is to fix
the script and re-run step 4 alone** — never to re-run `executeStudyPipeline()`.

This makes explicit a property D4 and D9 already provide but which must now be treated as a
**requirement, not a happy accident**:

- the six steps are independently callable (D4), and
- `exec/` persists and is untouched by step 4 (D9),

so re-running `runPostProcessing()` costs seconds and repeats no database work. Step 3 is
the expensive step and a post-processing failure must never force it to run again.

**What that requires in practice:**

- Step 4 takes everything it needs as arguments and reads nothing that only step 1 computed
  in memory. In particular the **pipeline version must be recoverable without re-running
  step 1** — it is in the `exec/results/{db}/{version}/` paths and the run manifest (D15).
- Step 4 is idempotent: re-running it re-merges from scratch and replaces the export, rather
  than appending to whatever the failed attempt left (which D9's staging swap already
  guarantees).
- The error message names the failing script and expression (per #162's per-expression
  evaluation) and states the recovery: fix, then re-run step 4.

Consistent with `sourceDisseminationScripts(stopOnError = TRUE)` today, and with D1 — the
data product includes its formatting, so an unformatted export is not a releasable one.

### D14 — Failure policy — **SETTLED 2026-11-20**

**Decision.** **Per-block isolation across databases; fail-fast within a block.**

Today the first failing task aborts everything, including config blocks that never started
(**X-8**) — so one Optum task failure prevents CPRD and JMDC from running at all.

| Scope | Policy | Why |
|---|---|---|
| tasks **within** a config block | fail fast — stop that block | Tasks are ordered and plausibly interdependent; continuing past a failure risks building on a missing result |
| **across** config blocks | isolate — other blocks still run | Databases are independent by construction |

The run then ends with a per-block status, and the run completes rather than aborting.

#### What a partial run means for step 4 (closes D13.9)

A run can legitimately end with four of five databases succeeded. Step 4 **merges what
exists**, warns about the coverage gap, and lets step 6 gate — which is exactly D13.2's
rule arriving by a different route, so no new mechanism is needed:

| | Behaviour |
|---|---|
| step 4 | merges the four; functional QC becomes `Incomplete` (D13.8); per-file coverage recorded in the run manifest |
| step 6 | **refuses to promote** an `Incomplete` export unless the gap is acknowledged |

Under D6 the export is committed and reviewed, so "silently merged four of five" was the
dangerous option. This is not silent: the status says `Incomplete` and promotion is blocked.

**One design consequence worth stating: step 4 must stop inferring coverage from the
filesystem.** Three different causes produce an identical absent folder —

| Cause | Right response |
|---|---|
| the block failed in step 3 | `Incomplete`, reason known and attributable |
| the block ran but the task wrote nothing | a different anomaly — succeeded yet produced nothing |
| the block was **never run** (step 3 called with two databases, step 4 with three) | the export claims coverage it does not have |

— and the third is live precisely because D4 made the steps independently callable. It is
also the dangerous one: `databaseInfo.csv` is built straight from `dbIds` and `config.yml`
(`R/postProcess.R:656`), from what the caller *said* rather than what ran, so an export can
state three databases while containing two and have its own reference file corroborate the
wrong claim.

**The record already exists; step 4 just does not read it.** `task_run_history.csv` carries
`config_block`, `pipeline_version` and `status` per task (`R/taskTracking.R:356`), so "cprd
task 05 failed" is on disk today. This is a reading gap, not a missing artifact — **D14 is
not blocked on D15.**

What D15 adds is different: `task_run_history.csv` lives under gitignored `exec/` and never
travels with the export, so a reviewer holding only the committed `export/` has an
unverified coverage claim. Two needs, easily conflated:

| Need | Met by |
|---|---|
| step 4 needs to **know** what ran | read `task_run_history.csv` — exists today, local, gitignored |
| the export needs to **carry** a verified claim | the run manifest in `export/` — D15, committed |

So D14 sharpens *what D15 must contain* — per-block outcome, and a coverage statement
derived from what ran rather than from `dbIds` — without depending on it.

#### Open follow-on

- [ ] **Does a failed block abort at its first failing task, or finish its remaining
      independent tasks?** Fail-fast within a block is the decision above, on the grounds
      that tasks are ordered and interdependent. But nothing currently *declares* the
      dependencies between tasks (#136's option 6 would), so "interdependent" is an
      assumption. Revisit if declared task inputs ever land.

### D15 — The durable record of a run — **SETTLED 2026-11-20**

**Decision.** One **`runManifest.yml`** per run, written into `dissemination/export/` by
step 4 and completed by step 6. It replaces `qc_processMeta.csv`.

#### First, three roles that were conflated

The three artifacts today are not three attempts at the same thing — they are three
different jobs, and separating them is most of this decision:

| Artifact | Role | Lifecycle |
|---|---|---|
| `exec/logs/task_run_history.csv` | **cache** — what `shouldRerunTask()` reads | cumulative across runs, safely deletable, gitignored |
| `exec/logs/picard_log_*.txt` | **debug log** — a human reads it when something broke | per-run prose, deletable, gitignored |
| `export/qc_processMeta.csv` | **provenance record** — the committed claim | per-run, immutable once committed |

**Only the third is this decision's subject.** The cache looks like provenance but is not:
deleting it costs a re-run, not an audit trail. The manifest must not absorb it, and
earlier framing in this review that said "consolidate the three" was wrong.

#### What is wrong with `qc_processMeta.csv`

Ten fields on one CSV row (`R/postProcess.R:848-858`), with six defects:

| | Problem |
|---|---|
| **P5** | its `codeCommitSha` comes from `gert::git_log()` at post-processing time, not the pre-flight `codeState$sha` — two different answers to "what code produced this" |
| **X-9** | pre-flight computes a lockfile hash and drops it |
| **X-12** | `executionTimestamp` forces a git diff on every run |
| **X-18** | `databasesIncluded` is built from `dbIds`, not from what ran |
| **X-19** | **the picard version is never recorded anywhere in a run** — `grep` finds no `packageVersion()` call in `R/`, so a committed export cannot say which picard produced it. The R version exists only inside `renv.lock`, hashed rather than stated |
| shape | one flat CSV row cannot express run → block → task → file |

#### 1. Format — YAML

Nested content, and a file that will be **diffed between releases**, so diffability
matters more than compactness. YAML with **stable key ordering**, consistent with
`config.yml` and `secrets.yml`, and `yaml` is already a dependency.

Per-file hashes stay a flat `files:` list inside the same YAML. Revisit only if it becomes
unwieldy — 40 files across 5 databases is tolerable; ten times that is not.

#### 2. Writer — step 4 writes it, step 6 completes it

Step 4 describes steps 1–4, but promotion facts do not exist until step 6. So step 4 writes
the manifest and step 6 appends the promotion block.

Step 6 writing it alone was rejected: the **internal lane never reaches step 6** (D7), and
D13.10's fix-and-re-run-step-4 cycle would produce nothing. Every run gets a manifest; only
promoted runs get the promotion block.

#### 3. Contents

| Group | Fields | Serves |
|---|---|---|
| identity | repo, `pipelineVersion`, **`lane`** (`release` / `internal`) | D7, D13.8 |
| code | **pre-flight** `commitSha`, `codeState` status, `ignoredFiles` | fixes **P5** — one authoritative SHA |
| environment | `renv.lock` hash, R version, **picard version** | **X-9**, **X-19** |
| inputs | cohort + concept-set manifest hashes and counts | D7's "why does this release differ" |
| data | per-database `dataVersion` | **reserved — contingent on D10** |
| execution | per-block outcome (`succeeded` / `failed at task N` / `not attempted`), per-task status and duration | D14, **X-18** |
| merge | per file: row count, contributing databases, sha256; excluded files with reason | D16's fallback, D17 |
| QC | functional status, content status | D13.8 |
| promotion | release branch, PR reference, promoted-at | step 6 |

`dataVersion` is **reserved, not specified** — its shape depends on D10's data-version
probe. Leave the key absent rather than inventing a shape now.

#### 4. What it replaces, and what survives

| File | Fate |
|---|---|
| `qc_processMeta.csv` | **replaced** — fully subsumed |
| `databaseInfo.csv` | **survives** — a flat join table analysts join to results; fix **X-18** so it reports what ran |
| `schema_review.csv` | survives — observed schema, a different question (D17) |
| `cohortManifestSnapshot.csv` | survives — point-in-time input snapshot |
| `egp.md` | survives — snapshotted plan (D2) |

#### 5. Mutability

Overwritten freely while step 4 is re-run (D13.10); **immutable once step 6 commits it**.
Git provides the immutability, not the file.

#### Consequence: the manifest is the one committed file that should diff every run

That is its job, and it is what lets **X-12** pull volatile fields out of the result CSVs —
timestamps and durations belong in the manifest, which is *expected* to change, not in
results that should be byte-stable when the numbers are.

The corollary: a reviewer asking *"did the numbers change?"* must diff `export/`
**excluding** the manifest. That is an argument for keeping provenance in its own file
rather than embedded in result files, and it needs a line in the vignette:

```bash
git diff v1.1.0 v1.2.0 -- dissemination/export/ ':!dissemination/export/runManifest.yml'
```

#### What this makes true

This is the artifact that makes D7 answerable without over-thinking release numbering — the
diff between two manifests *is* the difference between two releases — and the thing that
makes `hidden/pipeline_rationale.md`'s first claim, *"audit trail: able to see all
assumptions and code used to produce a number"*, literally true rather than aspirational.

It is also what makes D16's fallback viable: because it carries SHA-256 per result file,
"hashes in git, bytes elsewhere" remains an option if the export turns out too large to
commit.

### D16 — Results storage and git layout — **SETTLED 2026-11-20 except the measurement**

> **Mostly settled elsewhere:** **D6** commits `export/`, drops the version segment, keeps
> `exec/` ignored and keeps metadata in the export; **D3** fixes the folder layout; **D9**
> makes clearing `export/` the default; **D15** absorbs the volatile fields. Settled here:
> `compress` is **removed**, write-if-changed is implemented as a sync inside D9's staging
> swap, **release tagging becomes picard's job**, and the retrieval helpers are specified.
> **Still open: the measurement** — and only the >50 MB single-file case changes the plan.

#### The problem this closed

`exec/` was gitignored to keep data out of git, but `dissemination/export/` is **not**
(`R/Ulysses.R:1010`) — so merged results, pretty output and Study Hub output were all
committed anyway. The original intent was undone one directory over, and the symptom was
many near-identical copies of the same numbers.

The cause was not the data volume. **`export/merge/v{version}/` reinvented version control
inside a version-controlled directory**: the repo accumulated N near-identical *trees side
by side* instead of N *commits* of one tree, which is the one thing git stores cheaply and
was given no chance to. It was also strictly worse for the purpose — two releases at
different paths cannot be compared with `git diff` at all.

Two amplifiers, both now defects: `compress = TRUE` (**X-13**) turns each release into a
full new blob, because a gzipped CSV is already-compressed binary that neither zlib nor
delta compression can help; and `executionTimestamp` in `qc_processMeta.csv` (**X-12**)
guarantees a diff even on a no-op re-run.

#### What was decided, and where

| | Decided in |
|---|---|
| commit **one** derived layer — the merged export — at a stable path, no `merge/` segment and no `v{version}` | **D6**, path shape in **D3** |
| keep `exec/` gitignored — largest, per-database, highest patient-level-data risk, fully re-derivable | **D6** |
| gitignore the derived presentation layers (`pretty/` output, `publish/*` build output) | **D3**, **D6** |
| metadata stays in the export, volatile fields move to the run manifest | **D6**, **D15** |
| clearing, and the staging swap that writes it | **D9** |

Retrieval becomes `git show v1.2.0:dissemination/export/01_cohort_counts.csv`, and
comparison `git diff v1.1.0 v1.2.0 -- dissemination/export/` — neither of which was possible
before, because the two releases lived at different paths.

The trade-off accepted: browsing the repo on GitHub shows only the latest release, and the
working tree no longer displays history. That is acceptable where the Study Hub is the
browsing surface, but it is a real change in how the repo reads on the web.

What it preserves is the actual argument for committing results at all — a release PR where
the reviewer sees the numbers move is a far better review than one where they cannot, which
argues for committing something **small, stable and uncompressed**.

#### Settled here

5. **Remove the `compress` argument entirely** (**X-13**) — not merely forbid it. `export/`
   is the only thing step 4 writes and it is committed, so no valid use remains. A merged
   file big enough to want gzip is too big for git at all, which is the signal to switch to
   the external-store fallback below, not to compress.
6. **Write-if-changed, implemented as a sync inside D9's staging swap** — not as
   clear-then-copy. For each staged file, replace the export copy only if the hash differs;
   delete any export file absent from staging. One operation satisfies both D9 ("the export
   contains exactly this run") and D16 ("no spurious diffs"), and unchanged files keep their
   mtime so git sees nothing. **This refines how D9's "clear" is implemented.**
7. **Quarantine volatile metadata** — `executionTimestamp` and friends move into the run
   manifest (**D15**), which is *supposed* to change every run (**X-12**).

#### Release tagging is picard's job — **SETTLED**

**The gap this closes.** D6 removed the `v{version}` folder that used to make a release
addressable by path, and replaced it with git — so the retrieval story depends entirely on
**tags existing**. But **nothing in picard creates a tag**: `grep` finds no `git_tag` call in
`R/`, and the only mention is a manual instruction in a vignette
(`vignettes/running_the_pipeline.Rmd:364`, *"After merging to main, create a git tag"*). An
analyst who forgets makes that release unaddressable by version.

**Decision:** tagging becomes part of the promotion workflow rather than a documented manual
step. `gert` supports it directly — `git_tag_create`, `git_tag_list`, `git_tag_push`.

**And a constraint on D5 that D5 did not settle: the merge strategy.** If the release PR is
**squash-merged**, the release-branch commits do not exist on `main`, so a tag created on
that branch points off main's history and `git show v1.2.0:...` resolves to an orphan.
Either the release PR merges as a **merge commit**, or the tag is created on `main` after
the merge. Pick one and document it — the retrieval story breaks silently otherwise.

#### The retrieval helpers — **SETTLED in shape**

`getReleaseExport(version)` and `diffReleases(a, b)`, so no analyst types git plumbing.
Implementable without shelling out: `gert::git_archive_zip()` or `gert::git_worktree_add()`
to materialise a past export, and a tag-to-tag diff for the comparison. Both depend on the
tagging decision above.

Honest trade-off on (4): browsing the repo on GitHub shows only the latest release, and
the working tree no longer displays history. That is acceptable precisely when the Study
Hub is the browsing surface — which is its stated purpose — but it is a real change in how
the repo reads to someone who opens it on the web.

What this preserves is the actual argument *for* committing results at all: a release PR
where the reviewer sees the numbers move is a far better review than one where they
cannot. That argues for committing something **small, stable, and uncompressed** — which
lands on the same answer.

#### The measurement — and the right question to ask — **STILL OPEN**

An earlier draft of this decision asked "how large is one export?" and offered a
"prune older releases" tier. That was confused: under option (b) only **one** copy is ever
in the working tree, so there is nothing to prune. Repo growth is

```
growth  ≈  (per-release delta)  ×  (number of releases)
```

so the question is not absolute size but **how much the export changes between releases**. A
40 MB export that barely moves deltas to almost nothing; a 5 MB export rewritten wholesale
costs 5 MB every release.

**Today's layout lets you measure both, because every version is side by side in the tree:**

```bash
du -sh dissemination/export/merge/v*/
diff -rq dissemination/export/merge/v1.1.0 dissemination/export/merge/v1.2.0 | wc -l
```

Only one bucket changes the plan: **any single file over 50 MB** — GitHub warns there and
**hard-blocks the push at 100 MB**, at which point layout is irrelevant and the (c) fallback
applies. Everything below that is option (b) indefinitely.

#### The fallback if the measurement comes back large: hashes in git, bytes outside

If a single file exceeds ~50 MB, committing the export stops being viable regardless of
layout. The run manifest (**D15**) already carries SHA-256 per result file, so the fallback
is to keep **hashes in git and bytes outside**: add a `resultsStore` pointer (network share,
S3, Posit Connect pin), and git stays reviewable and *verifiable* without holding the data.

**DVC** is purpose-built for exactly this split and is the off-the-shelf answer, at the cost
of a second tool every analyst installs and a remote someone administers. **Git-LFS** is the
lighter variant where GitHub Enterprise has it enabled. Both are the right answer to a
storage problem and the wrong answer to a layout problem — hold them until the measurement
says which this is.

**Blocks / is blocked by:** D3 (the tree this writes into), D6 (what gets committed), D9 (clearing is only safe once git
holds the history), D15 (the manifest absorbs the volatile fields and enables the (c)
fallback), D13.5 / #142 (where metadata lands), and the repo-structure finalization listed
in `notes_v1_pathway.md`.

---

### D17 — The disclosure guard in post-processing — **SETTLED 2026-11-20 (mechanism); parameters open**

**Decision.** `runPostProcessing()` (step 4) gains a disclosure guard at the **merge
boundary** — the point where data crosses from gitignored per-database `exec/` into
committed `export/`. It takes a minimum-cell-count suppression input. The file gate is an
**allowlist**, not a blacklist.

This closes the scope question left open in D13 sub-decision 4: minimum-cell-count
suppression **is** picard's responsibility, as a parameter.

#### Why allowlist, not blacklist

The failure modes are asymmetric, and **D6 sharpens the asymmetry**:

| A new, unclassified output file appears | Allowlist | Blacklist |
|---|---|---|
| Behaviour | excluded from the merge | merged |
| Consequence | a missing file in the export — visible, annoying, fixable | patient-level data committed and pushed; **permanent in git history** |

Before D6 a blacklist miss left a patient-level file in an untracked local folder. After
D6 it is in a commit. One failure mode is an inconvenience; the other is irreversible.
Fail closed.

**The legitimate objection to allowlists**, recorded because it shapes the design: picard
cannot ship a default allowlist, because task output filenames are study-specific and
analyst-authored. A naive allowlist means every study hand-authors one before its first
merge — friction at exactly the moment someone is trying to get a pipeline running — and
forgetting to update it silently drops results. That is #142's own wrapper, with 25
hardcoded filenames.

#### The guard is three layers, and the name-based one is the weakest

**1. Identifier column guard — unconditional, no list.** Abort if any CSV carries a column
matching `subjectId` / `personId` / `patientId`, case- and punctuation-insensitive
(#142's check; nothing like it exists in `R/` today). Content-based, so it needs no
configuration, cannot go stale, and catches the hazard regardless of filename. **This is
the actual protection.** Configurable only to *add* patterns, never to remove them.

**2. Minimum-cell-count suppression** — also content-based, so also strong. Parameters in
the next section.

> **Where the guard runs — settled by D9:** step 4 merges into a gitignored **staging
> directory** and swaps it into `export/` only on success. Layers 1 and 2 below run against
> the staged copy, so unvetted data never touches the committed folder and a failed guard
> leaves nothing to un-commit. This is also how #142's wrapper works.

**3. File manifest — derived, reviewed in git, never prompted for.** The key split: layers
1 and 2 answer *"could this leak?"*, the manifest answers *"did I mean to publish this?"*

| | Answers | Mechanism | Maintenance |
|---|---|---|---|
| **Safety** | could this leak? | content rules (layers 1 and 2) | none — no list |
| **Intent** | did I mean to publish this? | the file manifest | derived, reviewed in git |

Because the content rules carry the safety, **a manifest miss is a wrong export, not a
disclosure** — which is what makes it affordable to fail soft on the process while still
failing closed on the data.

#### The run must never block on this

D8 forbids interactivity, and pipelines run for hours — a step-4 prompt would be the worst
possible place to wait on a human. So no step ever asks:

| Condition | Step 4 behaviour |
|---|---|
| Identifier column found (layer 1) | **abort** — a task is emitting patient-level data; something is badly wrong and continuing is worse than stopping |
| File absent from the manifest | **exclude, warn loudly, record** it in the run manifest (D15) and in `qcStatus` |
| No manifest exists at all | merge everything that passes the content rules, write the derived manifest, and stamp the export **unapproved** |

Never hangs, never prompts, never leaks, always reports — and a bookkeeping problem never
costs hours of step 3.

**Approval is enforced at step 6, not step 4.** `promoteRelease()` refuses to cut a release
whose export manifest is unapproved or has drifted. Step 6 takes seconds and runs at the
end regardless, so it is the right place for a gate about *intent*: an unreviewed export
cannot ship, and a run cannot be lost to one.

#### How the manifest is built without hand-authoring

The chicken-and-egg — the file set cannot be listed before it exists, and cannot be merged
before it is listed — resolves through **D7's internal/QC lane**, which runs first anyway:

```
1  testStudyPipeline(pipelineVersion = "qc_nov")   → exec/results/ populated
2  approveExportFiles()                            → scans exec/, writes the manifest to config
3  git diff                                        → the review happens here
4  commit
5  release run                                     → reads the manifest; excludes anything new
```

`approveExportFiles()` is an analyst console command run **between** runs — the same
relationship `renv::snapshot()` has to `renv::restore()`, or regenerating `dvc.lock` has to
`dvc repro` consuming it (§8.1, §8.7). Nothing in the pipeline waits on a human, and the
review is a git diff, which under D6 is already part of the PR a reviewer reads.

#### Warn in step 1, not step 4

Pre-flight cannot know what step 3 will emit, but it *can* know whether `analysis/tasks/`
has changed since the manifest was derived — so record a hash of the task set in the
manifest. Pre-flight then reports, in seconds:

```
~ Export manifest   approved 2026-11-12; tasks 07, 09 changed since — new outputs will be excluded
```

This turns a surprise at hour three into a warning at second two, and costs one more
pre-flight check (§2, alongside **G3**).

#### Two leak vectors a naive implementation will miss

**Derived columns recover suppressed cells.** Suppress `n = 3` but leave `pct = 1.2%`
beside a denominator of 250 and the count is trivially recoverable. Percentages, rates and
any other column derived from a suppressed count must be suppressed with it.

**Row-wise complementary disclosure.** A stratified table showing total 100 with strata 60,
35 and one suppressed discloses the third as 5. Genuine disclosure control suppresses a
second cell. This is hard, and is **out of scope for v1** — but then the limitation must be
*stated*: `minCellCount` is a **mechanism, not a guarantee**, and picard should not imply it
satisfies a formal disclosure policy. If BI has one, picard implements part of it.

#### Open parameter choices

- [ ] **`minCellCount` default.** OHDSI convention is commonly 5; some policies use 11. A
      conservative default of 5, overridable, is the usual compromise — but consider making
      it **required with no default**, which forces every study to state its policy
      explicitly. Breaking, which this release tolerates.
- [ ] **How a suppressed value is written.** `NA` plus a `suppressed` flag column is the
      safest. **Not `0`** — that conflates "none observed" with "hidden", and downstream
      code cannot tell the difference. A negative sentinel is an OHDSI convention but relies
      on every consumer knowing it.
- [ ] **Which columns are subject to suppression.** Auto-detection is risky — suppressing a
      `year` column because it reads as a small number would be worse than useless. Default
      to the count columns picard already knows (`cohort_entries`, `cohort_subjects`, keyed
      by `cohort_id` — the set `validateCohortResults()` already requires at
      `R/postProcess.R:457`), plus a per-file declaration for task-specific outputs.
- [ ] **Where the guard runs relative to `pretty`.** Suppression before formatting means
      formatters see suppressed values and must handle `NA`; after means formatters see real
      values and could leak them into a derived column. **Before** is safer, and makes the
      derived-column rule above enforceable.
- [ ] **Does a guard failure fail the run?** **Settled above:** an identifier-column hit
      aborts; an unmanifested file is excluded and recorded; approval is enforced in step 6.
      Confirm the abort is intended, since it means one stray task output blocks a release
      until fixed.
- [ ] **Where the manifest is stored.** `config.yml` keeps it with the other study settings
      but mixes derived state into a hand-edited file; a separate committed
      `exportManifest.yml` diffs more cleanly and is closer to the `renv.lock` / `dvc.lock`
      precedent this follows. Leaning to the separate file, **at the repo root beside
      `config.yml` — not inside `export/`**: it is an *input* to step 4 while `export/` is
      output-owned and (after D2's revision) entirely generated, D9 clears `export/` at run
      start, and `reviewExportSchema()` already has to exclude itself from its own scan
      (`R/postProcess.R:277`) — a second self-exclusion would be a smell.

#### Is the manifest duplicative of `schema_review.csv`?

No — they are opposites that happen to have a similar shape.
`reviewExportSchema()` (`R/postProcess.R:263`) emits
`fileName, columnName, dataType, rowCount` by scanning the **export** folder, and writes the
result **into** that folder at the **end** of step 4.

| | `schema_review.csv` | `exportManifest.yml` |
|---|---|---|
| Direction | **observed** — what the export contains | **declared** — what may be exported |
| Timing | written at the end of step 4 | read at the start of step 4 |
| File set | export-side **merged** names | exec-side **source** names |
| Lifecycle | regenerated automatically every run | changes only via `approveExportFiles()` |
| Location | inside `export/` (output) | outside `export/` (input) |

**The decisive reason to keep both:** a guard whose reference artifact regenerates itself
every run is not a guard. If `schema_review.csv` were the allowlist, "approved" would be
indistinguishable from "whatever happened last time", and every unexpected file would
approve itself the first time it appeared. A declared manifest only moves when a human
moves it — the same reason `renv.lock` and `renv::status()` are separate artifacts.

**They do not even describe the same files.** `importAndBind()` prefixes merged output with
the task sequence (`R/postProcess.R:46-51`, `:168`):

```
exec/results/db_a/1.0.0/01_demographics/results.csv   ← what the gate must decide on
dissemination/export/01_results.csv                   ← what schema_review sees
```

The gate runs **before** the merge, on exec-side `{task folder}/{file name}` pairs across
every database; `schema_review.csv` only ever sees the post-merge, renamed, single-copy
result. A merge cannot be gated by an artifact that exists only after it.

**One real synergy, not a duplication.** `schema_review.csv` already computes `rowCount` per
file — exactly the input D17's layer 2 wants for a row-count sanity heuristic (a "merged
aggregate" with 500k rows is suspicious). `reviewExportSchema()` computes it one step too
late to act on, so extract that scan into a helper both the guard and the schema review can
call.
- [ ] **What the manifest records per file.** File name at minimum; name + column names
      lets step 6 detect schema drift as well as new files. Column names are cheap and make
      the drift warning meaningful — a file that gains a column gets re-reviewed.
- [ ] **`approveExportFiles()` naming and scope.** Whether it is approve-semantics or
      snapshot-semantics (`snapshotExportManifest()`), and whether it can be pointed at a
      release run's `exec/` as well as a test namespace's.

**Blocks / is blocked by:** D1 (step 4 is required, so the guard is in the required path),
D6 (which makes a miss irreversible and is the reason for failing closed), D13 (this is its
sub-decision 4, now settled in mechanism), #142 (both of its gates are adopted here).

---

## 10. Suggested sequencing

With all seventeen decisions settled, the work splits into "build the six-step API" and
"everything that hangs off it". **Wave E0 is done** (`f2f321f`, `ebfff0a`); ES onward is
the remaining work, and it runs in parallel with the manifest waves in
`notes_v1_pathway.md`.

**Wave ES needs no further decisions** — it is mechanical. E1 onward implements §9.

**Wave E0 — free, no remaining decisions — COMPLETE except the measurement**
- [x] G3: pre-flight `"Task indices"` check plus a per-database guard in
      `runPostProcessing()`, both driven by `validateTaskIndices()` over
      `taskExportPrefix()`. Missing numeric prefix warns. Committed `f2f321f`; **#151 closed**.
- [x] X-3: `validateResultsFolderFresh()`, its pre-flight check, and the now-unused
      `resultsPath` parameter **removed** (D10 drops the version-folder abort in favour of
      per-task change detection, per-task output clearing and G3). The check was retired,
      not repaired.
- [x] X-9: `lockfileHash` wired into the run log header and summary footer beside the commit
      SHA. Kept rather than deleted because **D15** wants it in the run manifest.
- [x] X-14: `CLAUDE.md`'s post-processing paragraph corrected — it named a non-existent
      `orchestratePipelineExport()` *and* claimed migration scripts write to
      `export/pretty/` and `studyHubOutput/`, which nothing does (**X-11**).
- [x] P8: the `stop()`/glue typo at `R/postProcess.R:690`.
- [x] **#149** closed; the positional-indexing fix is already in
      `R/cohort_builders.R:318`, `:366`.
- [x] **#127 closed as feedback, not a bug.** Both premises were factually wrong —
      `gert::git_branch_create()` defaults to `ref = "HEAD"`, so the release branch is cut
      from the current branch, and only `main` is rejected (nothing enforces `develop`). The
      real rough edge found while investigating: an existing `release/<version>` is checked
      out **as-is**, so re-running a failed release at the same version lands on a stale
      branch with a clean tree. Check 12 detects it but is warn-only. D5's enforcement in E2
      covers it.
- **Measure for D16:** `du -sh` on an existing study repo's export per release version.
  Decides whether committing the export is viable before anything is built on it.

**Wave ES — repo structure (D3)** — *not started*
- X-11: delete `dissemination/export/pretty/` and `export/studyHubOutput/`.
- Create `dissemination/{export,pretty,publish/}`; stop scaffolding `extras/` and add it
  to `.gitignore`.
- X-15: gitignore `publish/quarto/_site/` and `.quarto/`; apply the same to other targets'
  build output; separate `<target>/R/` sources from artifacts.
- Fold `initStudyHubFiles()`'s folder creation into `listDefaultFolders()` — one authority.
- Drop `.gitkeep` under gitignored `exec/`; leave `analysis/src/sql/` and
  `inputs/cohorts/R/sql/` to their `make*()` helpers.
- Move the EGP out of `dissemination/quarto/` to a root `egp.md` as the authored source;
  scaffold it from a template and add the pre-flight existence check (D2).
- Regenerate `vignettes/picard_repository_structure.Rmd` and the `inst/agent/` files; fix
  the `.gitignore` description.

**Wave E1 — unblocks end-to-end runs (D5, D6, D8)** — *not started*
- X-2/X-5 + the cohort prompt: **remove every `readline()`**; replace with named arguments
  (`newsEntry`, `onMissingCohorts`). Closes **#128**.
- X-1: commit release metadata on the release branch — the fix that makes `main.R` work
  twice in a row.
- X-4: single `.computePipelineVersion()`, called by step 1 and its result passed forward
  (D4: prospective version at step 1, committed at step 6 — confirmed).
- X-10: `on.exit` back to `develop`; enforce `develop` as the release source (D5).
- Collapse `export/merge/v{version}/` to `export/` across the six signatures and
  `R/execute.R:1773`; **remove** the `compress` argument (X-13); write-if-changed as a sync
  in D9's staging swap; move `executionTimestamp` into the run manifest (X-12).
- **X-20: create the release tag in `promoteRelease()`** (`gert::git_tag_create` /
  `git_tag_push`) and settle D5's merge-strategy follow-on — without a tag, D16's retrieval
  story has no handle.
- `getReleaseExport()` / `diffReleases()` via `gert::git_archive_zip()` or
  `git_worktree_add()`.
- **Measure first (D16):** `du -sh dissemination/export/merge/v*/` plus a `diff -rq` between
  two versions, to get the per-release delta rather than just the absolute size.

**Wave E2 — the six-step API (D1, D4)** — *not started*
- **Prerequisite — extract one CSV-shape scanner.** Pull the per-file scan out of
  `reviewExportSchema()` (`R/postProcess.R:263-330`) into a shared helper, e.g.
  `scanCsvShape(path)` returning `fileName, columnName, dataType, rowCount`. Three
  consumers need it and must agree: the disclosure guard's identifier-column check and
  row-count heuristic (reading `exec/`, before the merge), `approveExportFiles()` (deriving
  the manifest from `exec/`), and `reviewExportSchema()` itself (reading `export/`, after
  the merge). Build this *before* the guard, or "what columns does this CSV have" gets three
  implementations that drift apart the way the hash layer did in #165. Note the scanner must
  handle `.csv.gz` (`readr::spec_csv()` already does) and the bundle subdirectories
  `importAndBind()` detects (`R/postProcess.R:88-124`).
- Export and rename `preFlightChecksForStudy()`; add a dry-run that reports skip/run and
  why, per block and per task.
- `sourceInputBuilders()`; `executeStudyPipeline()` reduced to cohorts + tasks.
- `runPostProcessing()` absorbs `pretty` and becomes part of the run's success criterion,
  and gains the **disclosure guard** at its merge boundary — identifier-column check (abort),
  `minCellCount` suppression with derived-column propagation, and manifest-based exclusion
  that warns and records rather than blocking (D17).
- D13's merge rules: union discovery and **drop the db1 hard-stop**; coverage gaps warn in
  step 4 and gate in step 6; schema mismatch a hard error with a per-file NA-fill opt-in;
  **X-16** bundle heuristic replaced by a hard error; overwrite protection on write naming
  both source tasks; **X-17** `ZeroCount` no longer a warning; and `qcStatus` reworked so
  `OK` means nothing was dropped (D13.8).
- Step 4 snapshots the root `egp.md` into `export/`, the same way it already snapshots the
  cohort manifest (D2).
- `approveExportFiles()` as a console command, plus step 6 refusing to promote an
  unapproved or drifted manifest, plus the pre-flight freshness check (**G3b**).
- New `prepareForPublish()` and `promoteRelease()`; version bump and PR prep move into the
  latter.
- Delete `test_main.R`, `addTestMainFile()`, `inst/templates/test_main.R` and
  `testStudyPipeline()`; keep `testStudyTask()`; make the test namespace a first-class
  argument on the six verbs (D4).
- Each entry point validates its own preconditions, since all six are independently
  callable.
- Per-block failure isolation across databases, fail-fast within a block (D14, X-8); step 4
  reads per-block outcome from `task_run_history.csv` instead of inferring coverage from
  directory existence, and `databaseInfo.csv` reports what ran rather than what `dbIds` said.
- D10's two cheap fixes: **validate before the skip check** (`R/execute.R:493` vs `:503`),
  and clear a task's output folder when that task actually runs.
- D10/#136: `validateStudyTask()` fails on reads of a results location, warns on other
  data-file reads. Breaking, and deliberate.
- Split `qcStatus` into functional and content fields, add `lane`, demote `ZeroCount`
  (D13.8, X-17). `validateCohortResults()`'s `databaseId` awareness is **deferred to #144**
  (D13.8b) — add it to that issue's checklist.
- A `pretty` failure errors; document re-running step 4 alone as the supported recovery,
  and make step 4 take everything it needs as arguments so it never depends on step 1
  having just run (D13.10).
- D9's clearing rules: step 4 writes through a **gitignored staging directory** and swaps
  into `export/` only on success (this is also where D17's guard runs); `export/` cleared
  at swap time but **aborting if it is dirty or has untracked files**; `exec/` cleared
  **per config block** and aborting on collision **in the release lane only** (the test
  lane reuses its namespace, so G3's duplicate-index check protects it instead), with a
  separate `clearStudyResults()` console command rather than a flag.

**Wave E3 — parallel track (D11, D12) — *not started*; this is the one that overlaps the manifest work**
- **#162** first, per **D12** (then **#119** and **#62** fall out) — independent of the
  loop shape #163 changes, and the prerequisite for D13.10's per-expression error messages.
  Scope: one shared `eval_study_script()`; one child env per script with
  `parent.env(globalenv())` as parent; context objects bound in that env; `sourceSrcFile()`
  for helpers, with bare `source()` in a task becoming a **validation failure**;
  `validateTaskDependencies()` scanning both; four `<<-` sites removed; `env` dropped from
  the pipeline path; and the **three test files that assert the globalenv leak** rewritten
  against the returned env.
- Then **#163** per D11: delete `skipInputBuilders` (nine sites); verify mode default-on in
  the release lane; `ensureStudyManifests()` as an **internal** repair path; make
  `initCohortManifest()` / `initConceptSetManifest()` **idempotent** (kept exported — this
  is what removes #163's template guards); missing-script abort kept, unexpected-script
  abort downgraded to a warning. Closes **#64**, largely defuses **#69**, and **closes #46
  as rejected**.
- Scaffold both manifests in `initUlyssesRepo()` (D11) — empty but valid, committed.
- **Blocked on #144:** collapse step 2's per-database loop to a single pass.

**Wave E4 — the borrowings (D10, D15)** — *not started*
- `runManifest.yml` (D15, §8.7): step 4 writes it, step 6 appends the promotion block;
  replaces `qc_processMeta.csv`; fixes **P5** (one authoritative commit SHA), **X-9**,
  **X-12** and **X-19** (record the picard and R versions). Prerequisite for D16's fallback.
- Document the results-only diff that excludes the manifest (D15); fix **X-18** so
  `databaseInfo.csv` reports what ran.
- D10: `rerunTriggers = c("code","inputs","env","failed")` replacing the booleans, plus
  `force` on `executeCohortGeneration()` (closes **#130**); per-task output hashes recorded
  and verified before skipping; `running` → `success`/`failed` history rows so a killed run
  is detectable as `incomplete`.
- D10: the `dataVersion` probe — `cdm_source` fields with a `vocabulary`-table fallback,
  `unavailable` + warn if neither, recorded per database in the run manifest and exposed as
  a trigger that is off by default. Also what D7 needs to grow into deriving the bump.
- Working-directory lock (§8.3).
- **#131** env vars, which D8 makes the next thing needed for scheduled runs.
  (#142's gates moved up to E2 with the guard — see D17.)
