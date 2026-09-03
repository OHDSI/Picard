<!-- AUTO-GENERATED FILE. DO NOT EDIT DIRECTLY. -->
<!-- Source: vignettes/running_the_pipeline.Rmd -->


> **Note:** This vignette is currently in development and subject to change.

## Introduction

This vignette covers **production mode execution** in Picard—running your pipeline for official analysis results.

Development and testing workflows are covered in [Developing the Pipeline](developing_the_pipeline.html). Production mode adds rigorous validation, semantic versioning, and audit trails to ensure results are reproducible and suitable for publications or regulatory submissions.

## The Production Pipeline

The official execution script is `main.R` in your project root. It:

- Validates your code state (git clean, all changes committed)
- Increments your study version (semantic versioning)
- Runs the complete pipeline with all validations
- Creates a release branch for reproducibility
- Generates PR metadata for code review
- Saves production-quality results in a versioned folder

```{r eval = FALSE}
# Run production pipeline
source("main.R")
```

## When to Run Production

Run `main.R` for:

- **Formal analysis runs:** Official results for publications or regulatory submissions
- **Final results:** When you're confident in the code and ready for version history
- **Multi-database comparisons:** Ensures consistency across databases
- **Code review:** Results go through PR review before acceptance

Production mode places versioned results in `exec/results/[database]/[version]/` (e.g., `1.0.0/`).

## Test Mode Namespaces (Avoiding Multi-User `dev` Conflicts)

When multiple users run test mode at the same time, sharing the default `dev`
namespace can cause collisions in both result folders and cohort table names.

Use `testStudyPipeline(testLabel = ...)` to isolate your test run:

```{r eval = FALSE}
# Default test namespace (legacy behavior)
testStudyPipeline(configBlock = "primaryDB")

# Custom namespace for your branch or feature
testStudyPipeline(
  configBlock = "primaryDB",
  testLabel = "feature_ml_test"
)
```

What `testLabel` controls:

- **Results path namespace** under `exec/results/[database]/[testLabel]/...`
- **Cohort table suffix** in execution settings (for example `_feature_ml_test`)

Normalization rules for `testLabel`:

- converted to lowercase
- non-alphanumeric characters converted to `_`
- repeated/edge underscores trimmed
- truncated to 24 characters

This behavior is **test mode only**. Production execution remains strict and
uses semantic versioning with no custom suffix overrides.

## Running Production Mode

### Prerequisites

Before running production mode:

1. **Commit all changes:** `git add .` and `git commit -m "..."`
2. **Be on develop branch (or feature branch):** `git checkout develop`
3. **Pull latest changes:** `git pull`
4. **Verify configuration:** Check config.yml for correctness
5. **Prepare builder scripts:** Edit and finalize scripts in `inputs/cohorts/R/` and `inputs/conceptSets/R/`
   - Delete unused builders; keep only the ones you need
   - See [Loading Inputs](loading_inputs.html) for detailed guidance on each builder type

You can also do this by using the `saveWork()` function which we describe in [Developing the Pipeline](developing_the_pipeline.html) to save your work and prepare for production.

If step 1 is impossible because files under `inputs/` keep changing on their own,
see [When the Code State Check Cannot Be Satisfied](#when-the-code-state-check-cannot-be-satisfied).

### Basic Usage

```{r eval = FALSE}
# Navigate to study repository
setwd("~/studies/myStudy")

# Run production pipeline with patch version increment
source("main.R")

# When prompted, answer questions about version increment:
# What type of version change? [major/minor/patch]
# You typically choose: "patch" (bug fixes), "minor" (new analyses), "major" (breaking changes)
```

### Programmatic Production Execution

```{r eval = FALSE}
library(picard)

# Run production pipeline directly
execStudyPipeline(
  configBlock = c("primaryDB", "secondaryDB"),
  updateType = "minor"  # Version increment type
)
```

### Version Increment Types

Choose the appropriate semantic version increment:

- **PATCH (1.0.0 → 1.0.1):** Bug fixes, data corrections, no new analyses
- **MINOR (1.0.0 → 1.1.0):** New analyses or features added (backward compatible)
- **MAJOR (1.0.0 → 2.0.0):** Breaking changes or study redesign

### When the Code State Check Cannot Be Satisfied

Production runs require a clean working tree so that every result can be tied
back to a known commit. Sometimes that is impossible through no fault of the
analyst: files under `inputs/` are rewritten without a deliberate edit — the
cohort and concept set manifest sqlite files are re-written on re-import, and
ATLAS-sourced JSON is refetched. The run is then blocked by churn nobody asked
for.

Two escape hatches exist. Both are **opt-in**: change nothing and the check
behaves exactly as before, failing on any uncommitted change.

#### Preferred: ignore specific paths

`ignoreUncommittedPaths` tolerates uncommitted changes **confined to the listed
repo-relative paths**. Anything outside them — most importantly `analysis/` —
still fails the check, so real analysis edits can never slip into a production
run unnoticed.

Set it once per study in the `default:` block of `config.yml`, where it is
version-controlled and reviewable alongside the rest of the study
configuration:

```yaml
default:
  projectName: myStudy
  version: 1.0.0
  ignoreUncommittedPaths:
    - inputs
```

Or pass it per run, which overrides `config.yml` for that invocation:

```{r eval = FALSE}
execStudyPipeline(
  configBlock = "primaryDB",
  updateType = "patch",
  ignoreUncommittedPaths = "inputs"
)

# Force strict checking regardless of config.yml
execStudyPipeline(
  configBlock = "primaryDB",
  updateType = "patch",
  ignoreUncommittedPaths = character(0)
)
```

Paths may name a folder (`"inputs"`, `"inputs/cohorts"`) or a single file
(`"inputs/cohorts/cohortManifest.sqlite"`). `"."` and absolute paths are
rejected — the repository root cannot be ignored wholesale.

#### Last resort: skip the check

`skipCodeStateCheck = TRUE` disables the code-state check entirely. Reach for it
only when `ignoreUncommittedPaths` cannot express the churn:

```{r eval = FALSE}
execStudyPipeline(
  configBlock = "primaryDB",
  updateType = "patch",
  skipCodeStateCheck = TRUE
)
```

This is deliberately **not** settable from `config.yml`, so it cannot be baked
permanently into a study. The branch guard (never run production from `main`) is
a separate check and is never skipped.

#### Neither hatch is silent

Whenever the check passes only because changes were ignored or skipped, the run
says so and records it:

- The pre-flight checklist shows `Code state` as a **warning**, not a pass,
  naming the ignored paths and the number of tolerated files.
- A banner after the checklist lists every ignored file by name.
- The pipeline log header (`exec/logs/picard_log_<version>_<timestamp>.txt`)
  records `Code State:`, `Commit SHA:` and the ignored files.
- `exec/logs/task_run_history.csv` gains a `commit_sha` and a `code_state`
  column for every task row. `code_state` is one of:

| `code_state` | Meaning |
|---|---|
| `clean` | Working tree had no uncommitted changes |
| `dirty-ignored` | Uncommitted changes existed but fell entirely inside `ignoreUncommittedPaths` |
| `unverified-skipped` | Check was skipped with `skipCodeStateCheck = TRUE` |
| `unverified-test-mode` | Test-mode run; code state is never checked |
| `unrecorded` | Task run outside the pipeline, or a row written by an older picard version |

So a recorded `commit_sha` never implies the tree matched that commit — read it
next to `code_state`. `displayTaskStatusReport()` prints the code state inline
for any row that is not `clean`.

## Understanding the Pipeline Workflow

Production execution follows five main phases:

1. **Pre-Pipeline:** Auto-discover and source builder scripts from `inputs/conceptSets/R/` and `inputs/cohorts/R/`
   - Concept set builders run first (importAtlas, importCapr, or custom)
   - Cohort builders run second (importAtlas, importCapr, importSql, buildDependentCohorts)
   - Manifests are loaded and populated with all definitions

2. **Setup:** Validate configuration, load execution settings, create output directories

3. **Generate Cohorts:** Instantiate all cohort definitions in the database, validate cohort counts

4. **Run Analysis Tasks:** For each task in `analysis/tasks/`, load configuration, execute task code, check for errors, record results

5. **Post-Processing:** Generate version logs, create PR metadata, save PENDING_PR.md

### Task Change Detection

In phase 4 each task is checked before it runs and **skipped when nothing that
affects its output has changed** since its last recorded run
(`exec/logs/task_run_history.csv`). A task is re-run when any of these differ
from that record:

- the task file's own contents;
- a file the task `source()`s;
- the **cohort manifest** — any change to a registered cohort's *definition*:
  the rendered SQL of a cohort, a cohort added or removed, or a derived
  cohort's build rule. Renaming a cohort or editing its tags does not count;
- the pipeline version;
- a previous run that ended in failure.

So after you edit a cohort's JSON or SQL and regenerate, the next pipeline run
re-executes every task that had run against the old definition. If the manifest
hash cannot be computed for any reason, tasks are re-run rather than skipped.

## Handling Errors and Failures

Production mode validates code state strictly. Common issues:

**"Cannot run production pipeline on main branch!"**
- Solution: Switch to develop: `git checkout develop`

**"Cannot proceed with uncommitted changes!"**
- Solution: Commit all changes: `git add .` and `git commit -m "..."`
- If the changes are incidental churn under `inputs/` that you did not make, see
  [When the Code State Check Cannot Be Satisfied](#when-the-code-state-check-cannot-be-satisfied)

**"Cohort manifest not found"**
- Solution: See [Loading Inputs](loading_inputs.html)

## Reviewing Results

After production mode, results are organized in versioned folders:

```
exec/results/[database]/1.1.0/       # Version 1.1.0
├── 00_buildCohorts/
├── 01_firstAnalysisTask/
├── 02_secondAnalysisTask/
└── picard_log_1.1.0_*.txt
```

Plus additional files for code review:

```
PENDING_PR.md                       # PR details for manual review
NEWS.md                              # Updated with version info
```

## Code Review Workflow

Production mode enables structured code review:

1. **Run pipeline:** `source("main.R")` on develop branch
2. **Review PENDING_PR.md:** Check proposed version, changes logged in NEWS.md
3. **Review code:** Inspect changes on release branch: `git checkout release/1.1.0`
4. **Create PR:** Use details from PENDING_PR.md to create PR in GitHub/Bitbucket
5. **Merge:** After review and approval, merge to main
6. **Cleanup:** Run `clearPendingPR()` to remove metadata file

## Integration with Git

### Git Branches

Production mode:

1. Creates a release branch: `release/[version]`
2. Runs pipeline on that branch
3. Saves PR metadata pointing to main
4. Expects manual PR creation and merge

```
main ←──── PR from release/1.1.0 ─── release/1.1.0
  ↑                                        ↑
  │                                        └─ Production run here
  │                                          (all commits included)
  └────────────────────────────────────────── Merged after review
```

### Version Tags

After merging to main, create a git tag for the version:

```{r eval = FALSE}
# After PR is merged to main
git tag -a v1.1.0 -m "Release version 1.1.0"
git push origin v1.1.0
```

## Monitoring Pipeline Execution

### Log Files

Picard creates detailed execution logs in `exec/logs/`:

- **Production run:** `picard_log_1.1.0_*.txt`

The console and the log file serve different purposes and are no longer the
same stream:

- **Console** always shows everything live — every `cli` info bullet, warning,
  and the full error text the moment a task fails. It is never redirected.
- **Log file** (`picard_log_<version>_<timestamp>.txt`) is a separate,
  purpose-written record of just the high-level milestones: pipeline start
  (version, config blocks, code state), each config block/task starting, each
  task succeeding, and — on failure — a full error detail block (error class,
  call, and message) so the cause is still readable after the console
  scrollback is gone. It intentionally does not try to mirror every console
  line.
- `exec/logs/task_run_history.csv` remains the canonical structured,
  queryable record of every task run (one row per task, with `status`,
  `errorMessage`, `commitSha`, `codeState`); the log file's error detail block
  is a durable, human-readable companion to that row, not a replacement for
  it.

Review the log file to understand which tasks ran, in what order, and how a
failure surfaced:

```
[14:32:01] Starting cohort generation...
[14:32:16] Processing config block: primaryDB
[14:32:16] Executing task 1/3: 01_descriptiveStats.R
[14:33:42] ✓ Task completed successfully
[14:33:43] Executing task 2/3: 02_primaryAnalysis.R
[14:34:10] ✗ Task failed: 02_primaryAnalysis.R
----- Full error detail -----
Class: rlang_error, error, condition
Call: dplyr::rename(...)
Message:
Can't rename columns that don't exist.
✖ Column `subCategory.y` doesn't exist.
------------------------------
```

### Cohort Counts

After any pipeline run, check `00_buildCohorts/cohortCounts.csv` to verify cohorts were generated:

```
id,label,cohort_entries,cohort_subjects
1,Type 2 Diabetes,245897,123456
2,CVD Comparator,189234,98765
3,MI Outcome,34567,12345
```

## Troubleshooting

### "Tasks not running in expected order"

Picard runs tasks in alphabetical order. Ensure file names have numeric prefixes:

```
01_table1.R          ✓ Runs first
02_descriptiveAnalysis.R   ✓ Runs second
03_primaryAnalysis.R       ✓ Runs third
analysis_task.R            ✗ Runs last (no prefix)
```

### "Results folder not created"

Manually create output folder:

```{r eval = FALSE}
# Ensure output structure exists
exec_path <- fs::path(here::here(), "exec/results/primary_db/1.0.0")
fs::dir_create(exec_path, recurse = TRUE)
```

### "Previous version results disappeared"

Results are organized by version in `exec/results/[database]/[version]/`. Check different version folders:

```{r eval = FALSE}
# List all version folders
list.dirs("exec/results/primary_db", recursive = FALSE)
```

## Next Steps

1. **Develop and test:** Use [Developing the Pipeline](developing_the_pipeline.html) workflows
2. **Verify code quality:** Ensure all tasks run successfully and produce expected results
3. **Run production:** When ready for official results, use `main.R`
4. **Review and merge:** Follow code review workflow before accepting to main branch

## See Also

- [Developing the Pipeline](developing_the_pipeline.html) - Testing and iteration during development
- [The Picard Repository Structure](picard_repository_structure.html) - Where results are organized
- [Launching a Study](launching_a_study.html) - Initial setup
- [Loading Inputs](loading_inputs.html) - Cohort and concept set setup
- [Post-Processing Steps](post_processing.html) - Working with results after execution
