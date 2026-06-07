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
# Clone the repository
git clone https://github.com/myorg/diabetes_study.git
```

After cloning, the repository has all configuration files, directory structure, and git history already in place. Next, click on the .Rproj file to open the project in RStudio and you can immediately start working.

However, agent mode files are excluded from git (for security and customization). You'll need to restore them using `initAgentMode()`:

```r
library(picard)

# Restore agent mode configuration (if not already present)
initAgentMode(projectPath = here::here(), verbose = TRUE)
```

This function:
1. **Checks if agent mode exists** - Looks for `.agent/` folder and `copilot-instructions.md`
2. **If missing**, restores from package templates by:
   - Extracting study metadata from README.md and config.yml
   - Creating `.agent/` folder with reference documentation
   - Writing customized `copilot-instructions.md` to workspace root (auto-loaded by VS Code Copilot)
   - Copying numbered reference guides to `.agent/reference-docs/`

After running `initAgentMode()`, you can open the repository in VS Code and Copilot will automatically use the study context to provide AI assistance tailored to your project.

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
  - `name`: Full name
  - `email`: Contact email
  - `role`: Role type (e.g., "developer", "qc", "principal investigator")
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

**For multiple databases**, create multiple blocks:

```r
db1 <- setDbConfigBlock(
  configBlockName = "my_cdm",
  cdmDatabaseSchema = "omop_cdm_schema",
  databaseName = "my_database_v1",
  cohortTable = "study_cohorts",
  databaseLabel = "Primary CDM"
)

db2 <- setDbConfigBlock(
  configBlockName = "secondary_cdm",
  cdmDatabaseSchema = "secondary_omop_schema",
  databaseName = "secondary_database_v1",
  cohortTable = "study_cohorts_sec",
  databaseLabel = "Secondary CDM"
)
```

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

You can also specify Git and renv configuration at setup time:

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

**Optional Parameters:**
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

Open the `.Rproj` file in RStudio:

```
~/studies/diabetes_study/diabetes_study.Rproj
```

Alternatively, navigate to the folder in VS Code:

```
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
# Add remote named 'origin'
git remote add origin https://github.com/myorg/diabetes_study.git

# Verify remote was added
git remote -v
```

### 4. Push to Remote

Sync your local repository with the remote:

```bash
# Push to remote
git push -u origin main
```

---

## Setting Up renv for Reproducibility

renv configuration is handled automatically during repository initialization.

**If you provided `renvLockFile` during setup:**
- Your `renv.lock` file is automatically copied to the project root
- Run `renv::restore()` in the project to install the locked packages

```r
renv::restore(project = "~/studies/diabetes_study")
```

**If you did NOT provide `renvLockFile` during setup:**
Initialize renv in your project:

```r
renv::init(project = "~/studies/diabetes_study")
```

---

## Setting Up Database Credentials

Before you can execute any pipelines, you need to configure database credentials. These are stored securely in `~/.picard/secrets.yml` using the keyring package.

**Interactive Setup (Recommended):**

Set up database server credentials interactively using `setupDbSecretsKeyring()`:

```r
picard::setupDbSecretsKeyring(dbServerName = "my_cdm")
```

This prompts you to:
1. Select your DBMS type (e.g., PostgreSQL, SQL Server, Snowflake)
2. Enter connection details (server, port, username, password)
3. Store credentials securely in your OS keyring
4. Save the configuration to `~/.picard/secrets.yml`

The function automatically opens `editSecrets()` after setup so you can review the saved configuration.

**Manual Setup:**

If you prefer to manually edit your secrets file:

```r
picard::editSecrets()
```

This opens `~/.picard/secrets.yml` in your editor. You can add database server blocks with either:
- Plain text credentials (not recommended)
- `!expr keyring::key_get(...)` references (recommended - stores passwords securely)
- `!expr Sys.getenv(...)` references (for environment variables)

**Example secrets.yml format:**

```yaml
# Database Servers
my_cdm:
  dbms: !expr keyring::key_get("picard", "my_cdm_dbms")
  server: !expr keyring::key_get("picard", "my_cdm_server")
  port: !expr keyring::key_get("picard", "my_cdm_port")
  user: !expr keyring::key_get("picard", "my_cdm_user")
  password: !expr keyring::key_get("picard", "my_cdm_password")
```

---

## Complete Example

Here's the full workflow combining all steps:

```r
library(picard)

# 1. Create study metadata
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

# 2. Configure database connection
db <- setDbConfigBlock(
  configBlockName = "my_cdm",
  cdmDatabaseSchema = "omop_cdm_schema",
  databaseName = "my_database_v1",
  cohortTable = "study_cohorts",
  databaseLabel = "Primary CDM"
)

# 3. Create study settings (with optional Git and renv configuration)
ulySt <- makeUlyssesStudySettings(
  repoName = "diabetes_study",
  repoFolder = "~/studies",
  studyMeta = sm,
  dbConnectionBlocks = list(db),
  gitRemote = "https://github.com/myorg/diabetes_study.git",
  renvLockFile = "~/my_dependencies/renv.lock"
)

# 4. Initialize the repository
ulySt$initUlyssesRepo(verbose = TRUE, openProject = FALSE)
```

## What Gets Created

After successful initialization, your repository contains:

- **Standard directories:** analysis/, inputs/, dissemination/, exec/, extras/
- **Configuration file:** config.yml with your study settings
- **Project file:** .Rproj file for RStudio
- **README and documentation:** README.md, NEWS.md
- **Git setup:** .gitignore configured for Picard projects

For detailed information about the repository structure, see the repository structure documentation.

## What's Next?

Your repository is now initialized and ready for development. The next phase is to develop your analysis pipeline. This includes:

- Setting up your development branch
- Defining inputs (cohorts and concept sets)
- Creating analysis tasks and supporting code
- Testing your pipeline on the `develop` branch

See the development guide for the complete development workflow.
