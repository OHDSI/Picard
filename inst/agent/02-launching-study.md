# Launching a Picard Study

> **Note:** Documentation is subject to change.

## Introduction

Launching a Picard study means initializing a new RWE study repository with the standard directory structure, configuration files, and execution scripts. This process creates a clean, organized workspace for your team to conduct analyses.

There are two ways to start a Picard study:

1. **Create a new study from scratch** - Use `makeUlyssesStudySettings()` to configure and initialize a new repository
2. **Clone an existing study repository** - Use `git clone` to download a pre-configured repository from a remote

## Option 1: Create a New Study from Scratch

The launch process has four key steps:

1. Create study metadata (title, therapeutic area, study type, contributors)
2. Define database configuration blocks (these carry all DBMS and schema info)
3. Bundle everything into study settings
4. Initialize the repository

## Option 2: Clone an Existing Study Repository

If your study repository already exists on GitHub, GitLab, or another Git hosting service, you can clone it directly:

```bash
cd ~/studies
git clone https://github.com/myorg/diabetes_study.git
```

After cloning, open the `.Rproj` file and you can immediately start working - all configuration files, directory structure, and git history are already in place.

---

## Why Git and renv Matter for Picard Studies

Picard studies are designed for collaborative, reproducible research. Two tools are essential to this process:

### Git for Version Control

Git tracks every change to your code and documentation throughout the project lifecycle. For pipeline-driven studies, this provides critical benefits:

- **Code reproducibility:** Git records exactly which version of code produced which results. This is essential for regulatory compliance and peer review.
- **Audit trail:** Every commit includes who made the change, when, and why. This accountability is crucial for study documentation and QC.
- **Collaboration:** Multiple team members can work on different analysis tasks simultaneously without conflicts. Git helps merge changes cleanly.
- **Pipeline provenance:** When your pipeline generates results, you can trace those results back to the exact code commit that produced them.
- **Disaster recovery:** Git acts as a backup. If something goes wrong, you can revert to a previous working state.
- **Feature branches:** You can test new analysis approaches in isolated branches before merging into production.

**Picard's Branching Model:**
Picard enforces a strict branching workflow:

- **Main branch:** Protected branch used only for release-ready code. Production pipelines are executed from release branches created off main.
- **Develop branch:** Integration branch where team members merge tested features. All testing and QC happens here before code is ready for production.
- **Feature/task branches:** Individual developers work on their analysis tasks in isolated branches, then submit pull requests for review before merging to develop.

This branching strategy ensures:
- Production work never runs on unstable code from main
- All changes are reviewed before reaching production
- Testing happens in a controlled environment before deployment
- Team members can work independently without interfering with production results

Without Git and this disciplined branching approach, there is no safe way to run production pipelines on a study with multiple contributors.

For studies where data security and reproducibility are paramount, Git is not optional—it's foundational.

### renv for Package Management

R packages are constantly updated. Different versions can produce different results, even with identical data and code. renv solves this by creating a snapshot of your R environment:

- **Reproducibility across time:** renv.lock captures the exact package versions used during your analysis. Months or years later, you can restore the identical environment and reproduce every result.
- **Team consistency:** In collaborative studies, different team members might have different package versions installed. renv ensures everyone uses the same versions, eliminating "works on my machine" problems.
- **Dependency management:** renv tracks not just your direct dependencies but all nested dependencies.
- **Production safety:** Before promoting analysis code to production, renv ensures all dependencies are compatible and tested together.
- **Regulatory compliance:** For studies subject to validation requirements, renv provides documented evidence that all package versions have been captured and are reproducible.

**Setting up renv:**

```r
# In project root directory
renv::init()
```

This captures your current R environment. Commit the resulting files to Git:

```bash
git add renv.lock .Rprofile
git commit -m "Initialize renv for reproducibility"
```

---

## Step 1: Define Study Metadata

Study metadata describes the research project. Create a `StudyMeta` object with your project information using `makeStudyMeta()`:

```r
library(picard)

sm <- makeStudyMeta(
  studyTitle = "Diabetes Characterization Study",
  therapeuticArea = "Endocrinology",
  studyType = "Characterization",
  contributors = list(
    setContributor(
      name = "Jane Doe",
      email = "jane.doe@institution.org",
      role = "developer"
    ),
    setContributor(
      name = "John Smith",
      email = "john.smith@institution.org",
      role = "qc"
    )
  ),
  studyTags = c("OMOP", "OHDSI", "Characterization")
)
```

**Parameters:**
- `studyTitle`: Human-readable project name
- `therapeuticArea`: Therapeutic or disease area (e.g., "CRM", "Oncology", "Cardiology")
- `studyType`: Type of study (e.g., "Characterization", "Population-Level Estimation", "Patient-Level Prediction")
- `contributors`: List of contributor profiles created with `setContributor()`
- `studyTags`: Character vector of study tags for organization

## Step 2: Configure Database Connection

If analyzing a database (toolType = "dbms"), create a database configuration block using `setDbConfigBlock()`:

```r
db <- setDbConfigBlock(
  configBlockName = "my_cdm",
  cdmDatabaseSchema = "omop_cdm_schema",
  databaseName = "my_database_v1",
  cohortTable = "study_cohorts",
  databaseLabel = "Primary CDM"
)
```

**Parameters:**
- `configBlockName`: Identifier for this database configuration
- `cdmDatabaseSchema`: Schema containing the OMOP CDM tables
- `databaseName`: Name of the database (for internal tracking)
- `cohortTable`: Name of the table where cohorts will be created
- `databaseLabel`: Human-readable label for reports and documentation

**For multiple databases**, create multiple blocks and pass them as a list.

## Step 3: Create Study Settings

Bundle study metadata and database configuration blocks into `UlyssesStudySettings` using `makeUlyssesStudySettings()`:

```r
ulySt <- makeUlyssesStudySettings(
  repoName = "diabetes_study",
  repoFolder = "~/studies",
  studyMeta = sm,
  dbConnectionBlocks = list(db)
)
```

**Required Parameters:**
- `repoName`: Name of the repository directory
- `repoFolder`: Parent folder where the repository will be created
- `studyMeta`: StudyMeta object from Step 1
- `dbConnectionBlocks`: List of `DbConfigBlock` objects from Step 2 (all DBMS/schema info is contained in these blocks)

**Optional Parameters:**

```r
ulySt <- makeUlyssesStudySettings(
  repoName = "diabetes_study",
  repoFolder = "~/studies",
  studyMeta = sm,
  dbConnectionBlocks = list(db),
  gitRemote = "https://github.com/myorg/diabetes_study.git",
  renvLockFile = "~/my_dependencies/renv.lock"
)
```

**Optional:**
- `gitRemote`: URL to a Git remote repository (for version control integration)
- `renvLockFile`: Path to an existing `renv.lock` file to copy into the project (for reproducible environments)

## Step 4: Initialize the Repository

Finally, initialize the repository with `initUlyssesRepo()`:

```r
ulySt$initUlyssesRepo(verbose = TRUE, openProject = FALSE)
```

**Parameters:**
- `verbose`: Print detailed initialization messages (TRUE/FALSE)
- `openProject`: Automatically open the project in RStudio if TRUE

This creates your complete repository structure at the location specified in repoFolder.

---

## Setting Up Git Version Control

Git is automatically initialized when you launch the repository.

**If you provided `gitRemote` during setup:**
- The repository is automatically configured with your remote
- All initial files are committed with message: "Prep Ulysses repo with remote"
- Your code is automatically pushed to the remote

**If you did NOT provide `gitRemote` during setup:**
Follow these steps to add a remote and sync your repository:

### 1. Open the Project

Open the `.Rproj` file in RStudio or navigate to the folder in VS Code:

```bash
code ~/studies/diabetes_study
```

### 2. Check Git Status

Open a terminal in your project directory:

```bash
cd ~/studies/diabetes_study
git status
```

You should see that initial files are already committed locally.

### 3. Add Remote Repository

Link your local repository to a remote:

```bash
git remote add origin https://github.com/myorg/diabetes_study.git
git remote -v
```

### 4. Push to Remote

Push your committed files to the remote:

```bash
git branch -M main
git push -u origin main
```

---

## Setting Up renv for Reproducibility

After your repository is initialized, capture your R environment with renv:

```r
# In the project root directory
renv::init()
```

This creates `renv.lock` capturing all installed packages and versions. Commit these files:

```bash
git add renv.lock .Rprofile
git commit -m "Initialize renv for reproducible environment"
git push
```

Then, other team members can restore the identical environment:

```r
renv::restore()
```

---

## Next Steps

1. **Initialize repository** - Run `initUlyssesRepo()` as shown above
2. **Configure Git remote** - If you didn't set it during initialization
3. **Set up renv** - Run `renv::init()` to capture package versions
4. **Define inputs** - See "Loading Inputs" guide for cohorts and concept sets
5. **Develop analysis** - See "Developing the Pipeline" guide for creating tasks
