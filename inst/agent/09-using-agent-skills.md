<!-- AUTO-GENERATED FILE. DO NOT EDIT DIRECTLY. -->
<!-- Source: vignettes/using_agent_skills.Rmd -->


```{r setup, include = FALSE}
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = FALSE
)
```

> **Note:** This vignette is currently in development and subject to change.

## Overview

Picard integrates with AI code agents (Claude Code, GitHub Copilot, Cursor, etc.) to streamline cohort and concept set development. Agent skills provide guided workflows that help you write valid, consistent code while documenting your decisions.

This vignette explains:
- **Agent prerequisites** — what you need to set up
- **Available skills** — Capr Cohort Generation and Dependent Cohort Builder
- **How skills work** — what agents do and don't do
- **Using the skills** — step-by-step engagement

---

## Prerequisites

### 1. Code Editor with Agent Support

You need an IDE with built-in agent capabilities:

| Editor | Agent | Setup |
|--------|-------|-------|
| VS Code | GitHub Copilot | [Install Copilot Chat extension](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot-chat) |
| VS Code | Claude Code | [Install Claude extension](https://marketplace.visualstudio.com/items?itemName=Claude.claude) |
| JetBrains IDEs | Copilot or Claude | Built-in or via marketplace |
| Cursor | Built-in | Cursor IDE comes with agent pre-configured |

**For this vignette**, we use **GitHub Copilot** and **Claude Code** as examples (both work with Picard skills).

### 2. Agent Mode Initialized in Your Repository

When you created your study with `initUlyssesRepo()` or cloned an existing repository and ran `initAgentMode()`, Picard automatically set up agent files:

- `AGENTS.md` — Main agent instructions for your study
- `.agent/reference-docs/` — Study-specific documentation
- `.agent/skills/` — Available skills including picard-capr-cohorts and picard-dependent-cohorts

If you haven't initialized agent mode yet:

```r
library(picard)
initAgentMode(projectPath = here::here(), verbose = TRUE)
```

This restores all agent files to your repository.

### 3. Study Repository Structure Ready

Your Picard repository must have:

- ✅ `config.yml` configured with database blocks
- ✅ `inputs/conceptSets/R/` folder (pre-created)
- ✅ `inputs/cohorts/R/` folder (pre-created)
- ✅ `AGENTS.md` file (see #2 above)
- ✅ `.agent/` folder with skills (see #2 above)

---

## Available Agent Skills

### 1. Capr Cohort Generation

**What it does**: Guides you through building OHDSI cohorts programmatically using Capr.

**When to use it**: You want to build cohorts from scratch using Capr's R API instead of JSON/ATLAS.

**Workflow**:
- Agent asks clarifying questions (patient inclusion/exclusion, date logic, outcomes)
- You confirm your intent
- Agent generates Capr code that builds the cohort definition
- You register the cohort in the manifest

**Output**: A Capr cohort definition added to `import_capr_cohort.R` (or similar) that registers with your manifest.

### 2. Dependent Cohort Builder

**What it does**: Guides you through creating derived cohorts (temporal subsets, unions, complements, demographic filters, stratified cohorts) that depend on existing manifest cohorts.

**When to use it**: You want to build derived cohorts from base cohorts already in your manifest.

**Examples**:
- Temporal subset: "T2D patients on Metformin for ≥90 days"
- Union: "CKD stage 2–5" (combining multiple severity stages)
- Complement: "CKD without diabetes"
- Stratified: Split "CKD" into age groups
- Demographic filter: "CKD with age 18–65 only"

**Workflow**:
1. Agent verifies all parent cohorts exist in your manifest
2. Agent asks for builder type, parent cohorts, and temporal/demographic parameters
3. Agent generates builder code
4. You register the derived cohort in the manifest

**Output**: Builder code appended to `build_dependent_cohorts.R` that generates SQL and registers with your manifest.

---

## How Agent Skills Work

### What Agents Do

Agent skills provide:

- **Guided workflows** — structured questions instead of free-form prompting
- **Validation** — checks that parent cohorts exist before generating code
- **Code generation** — consistent, auditable code matching Picard conventions
- **Dependency tracking** — automatic recording of which cohorts depend on which
- **Documentation** — comment blocks explaining scoping decisions

### What Agents Do NOT Do

Agent skills enforce boundaries:

- ❌ **Never execute the pipeline** — Skills only help you *write* input builder code
- ❌ **Never modify running pipelines** — Skills never run `main.R` or execute tasks
- ❌ **Never access your data** — Skills work with metadata only (manifest, config)
- ❌ **Never modify analysis tasks** — Skills only touch `inputs/cohorts/R/` and `inputs/conceptSets/R/`
- ❌ **Never delete** — Skills only add or append code

---

## Using the Skills

### Opening the Agent Interface

#### In VS Code with GitHub Copilot

1. Open your Picard repository in VS Code
2. Click the **Copilot Chat icon** in the left sidebar (speech bubble with Copilot logo)
3. You'll see the chat interface with access to Picard's agent skills

#### In VS Code with Claude Code

1. Open your Picard repository in VS Code
2. Click the **Claude icon** in the left sidebar
3. You'll see the chat interface with access to Picard's agent skills

#### In Cursor

1. Open your Picard repository in Cursor
2. Press `Ctrl+K` (or `Cmd+K` on Mac) to open the agent panel
3. Ask your agent for help with cohort or concept set development

### Engaging the Capr Skill

**Step 1: Open the agent and invoke the skill**

In the agent chat, ask something like:

```
I want to build a T2D cohort using Capr. Can you help me?
```

or 

```
Use the capr-cohort-generation skill to help me build a cohort.
```

**Step 2: Answer the agent's questions**

The agent will ask:
- What is the cohort about? (disease, exposure, outcome, medication, procedure)
- What are inclusion criteria? (e.g., at least one T2D diagnosis)
- What are exclusion criteria? (e.g., type 1 diabetes, pregnancy)
- Any date constraints? (e.g., index date, lookback window)
- Should the cohort be registered? (label, category, tags)

**Step 3: Review and refine**

The agent generates Capr code. You can:
- Ask the agent to modify specific logic
- Copy the code and paste it into `import_capr_cohort.R`
- Run the script to register the cohort in your manifest

**Step 4: Register the cohort**

Once you have the Capr definition, the agent helps you call:

```r
manifest$addCaprCohort(
  caprCohort = your_cohort_def,
  label = "T2D on Metformin",
  category = "target",
  tags = list(source = "capr", status = "approved")
)
```

### Engaging the Dependent Cohort Skill

**Step 1: Open the agent and invoke the skill**

```
I want to build a derived cohort. Can you help me?
```

or

```
Use the picard-dependent-cohorts skill to help me build a dependent cohort.
```

**Step 2: Confirm your base cohorts exist**

The agent will ask you to name the parent cohort(s). It will verify they exist in your manifest:

```
Parent cohort: T2D
✓ Found: T2D (id=3, active)
```

If a cohort is not found, the agent stops — you must add it to the manifest first.

**Step 3: Choose a builder type**

The agent asks which kind of derived cohort you want:

- `buildSubsetCohortTemporal()` — Temporal window (e.g., during a specific date range)
- `buildUnionCohort()` — Union (e.g., combine two definitions)
- `buildComplementCohort()` — Exclude subjects (e.g., T2D without CKD)
- `buildCompositeCohort()` — Intersection (e.g., subjects in 2+ cohorts)
- `buildDemographicCohort()` — Filter by age/gender/race
- `buildStratifiedCohorts()` — Split into subgroups
- `buildOPriorT()` or `buildTPriorO()` — Outcome/exposure temporal relationships
- `buildCensorCohort()` — Censoring logic

**Step 4: Specify builder parameters**

Depending on the builder type, the agent asks for:
- **Temporal subset**: Start window, end window (e.g., "90 days prior to index" to "end of follow-up")
- **Union**: Which cohorts to combine
- **Complement**: Which cohort is the base, which to exclude
- **Demographic**: Age range, gender, race/ethnicity to filter
- **Stratification**: How to split (e.g., age groups: <65, 65+)

**Step 5: Review and confirm**

The agent generates builder code into `build_dependent_cohorts.R` and shows you a summary on top of the code added:

```r
# ============================================================================
# Builder: T2D on Metformin at Baseline
# ============================================================================
# Type: Temporal Subset
# Base: T2D (id=3)
# Filter: Metformin (id=12)
# Window: 1 year prior to index, same day index
# ============================================================================

manifest$buildSubsetCohortTemporal(
  label = "T2D_on_Metformin_at_baseline",
  baseCohortId = 3,
  filterCohortId = 12,
  category = "derived",
  startWindow = createSubsetStartWindow(startDays = -365),
  endWindow = createSubsetEndWindow(endDays = 0),
  tags = list(type = "temporal_subset", parent = "T2D"),
  stopIfExists = FALSE
)
```

---

## Workflow Integration

### Typical Session

1. **Open Picard repository** in VS Code/Cursor with agent enabled
2. **Start agent chat** ("I want to build a T2D cohort using Capr")
3. **Follow agent questions** and provide input
4. **Review generated code** and ask for refinements if needed
5. **Copy code** to the appropriate builder script (`import_capr_cohort.R`, `build_dependent_cohorts.R`, etc.)
6. **Source the script** in R to register cohorts with the manifest
7. **Verify** with `manifest$tabulateManifest()` or view in Quarto hub

### Multiple Cohorts

If building multiple cohorts:

1. Engage the skill once for each cohort
2. All code goes into the same builder script file (not separate files)
3. Use comment blocks to organize related cohorts
4. Source the script once to register all at once

---

## Tips and Best Practices

### Before Using Skills

- ✅ Have your manifest loaded (`manifest <- loadCohortManifest()`)
- ✅ Know the IDs or labels of parent cohorts (from your manifest)
- ✅ Be ready to confirm cohort metadata (label, category, tags)

### During Skill Engagement

- ✅ Answer agent questions clearly and specifically
- ✅ Let the agent verify parent cohorts exist before proceeding
- ✅ Review the generated code before copying
- ✅ Ask the agent for refinements (e.g., "Use -180 days instead of -90 days")

### After Skill Engagement

- ✅ Paste generated code into the correct builder script file
- ✅ Keep all related cohorts in the same file (don't create separate files)
- ✅ Use comment blocks to organize groups of related cohorts
- ✅ Source the script to register cohorts
- ✅ Verify with `manifest$tabulateManifest()` or view dependency graph

---

## Troubleshooting

### Skill Not Showing Up in Chat

**Problem**: Agent doesn't recognize the skill name or doesn't offer the workflow.

**Solution**:
1. Verify `.agent/skills/` folder exists and contains skill subdirectories
2. Restart the agent (close and reopen the chat)
3. Try invoking with the full skill name: "Use the picard-dependent-cohorts skill"
4. Check that `AGENTS.md` is present in the repository root

### Parent Cohort Not Found

**Problem**: Agent can't find a cohort you reference.

**Solution**:
1. Verify the cohort is registered in your manifest: `manifest$tabulateManifest()`
2. Check the spelling (agent matches exact labels)
3. Add the cohort to the manifest first if missing
4. Re-run the agent skill

### Generated Code Won't Source

**Problem**: Code pastes but gives errors when sourced.

**Solution**:
1. Ensure manifest is loaded: `manifest <- loadCohortManifest()`
2. Check that parent cohort IDs are correct
3. Ask the agent to review the error and suggest fixes
4. Verify your builder script is in the correct location (`inputs/cohorts/R/`)

---

## Next Steps

- [Loading Inputs: Getting Started](loading_inputs.html) — Complete guide to builder scripts
- [Manifest Management](manifest_management.html) — Query, update, and delete cohorts
- [Running the Pipeline](running_the_pipeline.html) — Execute analysis tasks after inputs are loaded
