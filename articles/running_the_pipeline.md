# Running the Pipeline: Production Execution

> **Note:** This vignette is currently in development and subject to
> change.

## Introduction

This vignette covers **production mode execution** in Picard—running
your pipeline for official analysis results.

Development and testing workflows are covered in [Developing the
Pipeline](https://ohdsi.github.io/Picard/articles/developing_the_pipeline.md).
Production mode adds rigorous validation, semantic versioning, and audit
trails to ensure results are reproducible and suitable for publications
or regulatory submissions.

## The Production Pipeline

The official execution script is `main.R` in your project root. It:

- Validates your code state (git clean, all changes committed)
- Increments your study version (semantic versioning)
- Runs the complete pipeline with all validations
- Creates a release branch for reproducibility
- Generates PR metadata for code review
- Saves production-quality results in a versioned folder

``` r
# Run production pipeline
source("main.R")
```

## When to Run Production

Run `main.R` for:

- **Formal analysis runs:** Official results for publications or
  regulatory submissions
- **Final results:** When you’re confident in the code and ready for
  version history
- **Multi-database comparisons:** Ensures consistency across databases
- **Code review:** Results go through PR review before acceptance

Production mode places versioned results in
`exec/results/[database]/[version]/` (e.g., `1.0.0/`).

## Running Production Mode

### Prerequisites

Before running production mode:

1.  **Commit all changes:** `git add .` and `git commit -m "..."`
2.  **Be on develop branch (or feature branch):** `git checkout develop`
3.  **Pull latest changes:** `git pull`
4.  **Verify configuration:** Check config.yml for correctness

You can also do this by using the
[`saveWork()`](https://ohdsi.github.io/Picard/reference/saveWork.md)
function which we describe in [Developing the
Pipeline](https://ohdsi.github.io/Picard/articles/developing_the_pipeline.md)
to save your work and prepare for production.

### Basic Usage

``` r
# Navigate to study repository
setwd("~/studies/myStudy")

# Run production pipeline with patch version increment
source("main.R")

# When prompted, answer questions about version increment:
# What type of version change? [major/minor/patch]
# You typically choose: "patch" (bug fixes), "minor" (new analyses), "major" (breaking changes)
```

### Programmatic Production Execution

``` r
library(picard)

# Run production pipeline directly
execStudyPipeline(
  configBlock = c("primaryDB", "secondaryDB"),
  updateType = "minor"  # Version increment type
)
```

### Version Increment Types

Choose the appropriate semantic version increment:

- **PATCH (1.0.0 → 1.0.1):** Bug fixes, data corrections, no new
  analyses
- **MINOR (1.0.0 → 1.1.0):** New analyses or features added (backward
  compatible)
- **MAJOR (1.0.0 → 2.0.0):** Breaking changes or study redesign

## Understanding the Pipeline Workflow

Production execution follows four main phases:

1.  **Setup:** Validate configuration, load execution settings, create
    output directories

2.  **Generate Cohorts:** Load cohort and concept set manifests,
    validate all definitions exist, generate cohorts in database,
    retrieve cohort counts

3.  **Run Analysis Tasks:** For each task in `analysis/tasks/`, load
    configuration, execute task code, check for errors, record results

4.  **Post-Processing:** Generate version logs, create PR metadata, save
    PENDING_PR.md

## Handling Errors and Failures

Production mode validates code state strictly. Common issues:

**“Cannot run production pipeline on main branch!”** - Solution: Switch
to develop: `git checkout develop`

**“Code state validation failed - uncommitted changes”** - Solution:
Commit all changes: `git add .` and `git commit -m "..."`

**“Cohort manifest not found”** - Solution: See [Loading
Inputs](https://ohdsi.github.io/Picard/articles/loading_inputs.md)

## Reviewing Results

After production mode, results are organized in versioned folders:

    exec/results/[database]/1.1.0/       # Version 1.1.0
    ├── 00_buildCohorts/
    ├── 01_firstAnalysisTask/
    ├── 02_secondAnalysisTask/
    └── picard_log_1.1.0_*.txt

Plus additional files for code review:

    PENDING_PR.md                       # PR details for manual review
    NEWS.md                              # Updated with version info

## Code Review Workflow

Production mode enables structured code review:

1.  **Run pipeline:** `source("main.R")` on develop branch
2.  **Review PENDING_PR.md:** Check proposed version, changes logged in
    NEWS.md
3.  **Review code:** Inspect changes on release branch:
    `git checkout release/1.1.0`
4.  **Create PR:** Use details from PENDING_PR.md to create PR in
    GitHub/Bitbucket
5.  **Merge:** After review and approval, merge to main
6.  **Cleanup:** Run
    [`clearPendingPR()`](https://ohdsi.github.io/Picard/reference/clearPendingPR.md)
    to remove metadata file

## Integration with Git

### Git Branches

Production mode:

1.  Creates a release branch: `release/[version]`
2.  Runs pipeline on that branch
3.  Saves PR metadata pointing to main
4.  Expects manual PR creation and merge

&nbsp;

    main ←──── PR from release/1.1.0 ─── release/1.1.0
      ↑                                        ↑
      │                                        └─ Production run here
      │                                          (all commits included)
      └────────────────────────────────────────── Merged after review

### Version Tags

After merging to main, create a git tag for the version:

``` r
# After PR is merged to main
git tag -a v1.1.0 -m "Release version 1.1.0"
git push origin v1.1.0
```

## Monitoring Pipeline Execution

### Log Files

Picard creates detailed execution logs in `exec/logs/`:

- **Production run:** `picard_log_1.1.0_*.txt`

Review logs to understand which tasks ran, their duration, and any
warnings:

    [14:32:01] Starting cohort generation...
    [14:32:15] Cohort generation completed successfully!
    [14:32:16] Executing task 1/3: 01_descriptiveStats.R
    [14:33:42] ✓ Task completed successfully
    [14:33:43] Executing task 2/3: 02_primaryAnalysis.R

### Cohort Counts

After any pipeline run, check `00_buildCohorts/cohortCounts.csv` to
verify cohorts were generated:

    id,label,cohort_entries,cohort_subjects
    1,Type 2 Diabetes,245897,123456
    2,CVD Comparator,189234,98765
    3,MI Outcome,34567,12345

## Troubleshooting

### “Tasks not running in expected order”

Picard runs tasks in alphabetical order. Ensure file names have numeric
prefixes:

    01_buildCohorts.R          ✓ Runs first
    02_descriptiveAnalysis.R   ✓ Runs second
    03_primaryAnalysis.R       ✓ Runs third
    analysis_task.R            ✗ Runs last (no prefix)

### “Results folder not created”

Manually create output folder:

``` r
# Ensure output structure exists
exec_path <- fs::path(here::here(), "exec/results/primary_db/1.0.0")
fs::dir_create(exec_path, recurse = TRUE)
```

### “Previous version results disappeared”

Results are organized by version in
`exec/results/[database]/[version]/`. Check different version folders:

``` r
# List all version folders
list.dirs("exec/results/primary_db", recursive = FALSE)
```

## Next Steps

1.  **Develop and test:** Use [Developing the
    Pipeline](https://ohdsi.github.io/Picard/articles/developing_the_pipeline.md)
    workflows
2.  **Verify code quality:** Ensure all tasks run successfully and
    produce expected results
3.  **Run production:** When ready for official results, use `main.R`
4.  **Review and merge:** Follow code review workflow before accepting
    to main branch
5.  **Archive results:** Use
    [`zipAndArchive()`](https://ohdsi.github.io/Picard/reference/zipAndArchive.md)
    to preserve important results

## See Also

- [Developing the
  Pipeline](https://ohdsi.github.io/Picard/articles/developing_the_pipeline.md) -
  Testing and iteration during development
- [The Picard Repository
  Structure](https://ohdsi.github.io/Picard/articles/picard_repository_structure.md) -
  Where results are organized
- [Launching a
  Study](https://ohdsi.github.io/Picard/articles/launching_a_study.md) -
  Initial setup
- [Loading
  Inputs](https://ohdsi.github.io/Picard/articles/loading_inputs.md) -
  Cohort and concept set setup
- [Post-Processing
  Steps](https://ohdsi.github.io/Picard/articles/post_processing.md) -
  Working with results after execution
