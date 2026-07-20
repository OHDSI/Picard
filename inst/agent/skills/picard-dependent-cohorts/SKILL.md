---
name: picard-dependent-cohorts
description: >
  Build derived/dependent cohorts inside a Picard/Ulysses study repository using the
  templated builder functions on CohortManifest. Use whenever the user asks to create a
  temporal subset, union, complement, composite, demographic subset, stratified split,
  O-Prior-T, T-Prior-O, or censor cohort from existing manifest entries. All base cohorts
  must already be registered in the manifest before this skill runs.
---

# Picard Dependent Cohort Building

Derived cohorts are defined by their relationship to base cohorts already in the manifest.
They are built by calling templated builder methods on `CohortManifest` inside
`inputs/cohorts/R/build_dependent_cohorts.R`. The manifest generates the SQL automatically,
registers the cohort, records the dependency graph, and marks downstream cohorts stale when
a parent changes.


## Process

### Prerequisites

- Base cohorts (ATLAS, Capr, SQL) must already exist in the manifest.
- The builder script is sourced via `sourceInputBuilderScripts()` as part of the pre-pipeline
  setup in `main.R`. Do not source it manually — the manifest operations are destructive to prior state.
- All builder functions require the manifest to be loaded:

```r
cohortManifest <- loadCohortManifest()
```

Before doing anything else, tell the user explicitly that you are reading the current state of
the manifest:

> I'm reading the current cohort manifest from `inputs/cohorts/cohortManifest.sqlite` and the
> builder scripts in `inputs/cohorts/R/` to understand what cohorts are already registered.

Read `inputs/cohorts/R/` and `inputs/cohorts/json/` now. Then proceed to Step 1.

---

### Step 1: Scoping Questions *(mandatory)*

Ask the following before writing any code. If the user has already provided some answers,
confirm them explicitly before proceeding.

1. **What type of derived cohort is needed?** Pick one of the 9 builder types (see `REFERENCE.md`).
2. **What are the component cohorts?** Identify each cohort by name and clarify which serves as the index date (base cohort).
3. **Builder-specific questions** — ask the additional clarifying questions for the chosen builder type (see `REFERENCE.md` for the full list per builder).
4. **Registration metadata:**
   - **label** — display name for the derived cohort; must not collide with an existing manifest label.
   - **category** — required classification (e.g. `"Derived Cohorts"`, `"Target"`, `"Outcomes"`); never invent one — ask which categories the study uses.
   - **tags** — always ask whether the user wants to add tags. Tags are very useful downstream for filtering, auditing, and QA. Suggest examples:
     > - Provenance: `list(source = "derived", parent = "CKD")`
     > - QA status: `list(status = "pending", owner = "alice")`
     > - Study role: `list(type = "sensitivity_analysis")`

     If the user does not supply tags after being asked, omit the `tags` argument entirely.

Do not guess these values or write placeholder metadata.

**Example walkthrough:**

> *User:* "I want a CKD cohort with no prior T2D at baseline"
>
> 1. Builder type → `buildSubsetCohortTemporal()` (temporal subset / exclusion at baseline)
> 2. Components → CKD as base, T2D as filter; index date = CKD cohort start date — confirm with user
> 3. Ask temporal clarifying questions (window direction, endDateType, subsetLimit)
> 4. Confirm label, category, and tags before writing code

---

### Step 2: Confirm Cohort Existence *(mandatory)*

**Do not write any builder code until parent cohort existence is confirmed.**

Read `inputs/cohorts/R/` and `inputs/cohorts/json/` to infer what is registered. If you can
identify likely labels from context, generate lookup code and ask the user to run it:

```r
ckdEntry <- cohortManifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")
t2dEntry <- cohortManifest$queryCohortsByLabel("Type 2 Diabetes",        matchType = "exact")

print(ckdEntry)
print(t2dEntry)
```

After the user runs the lookup, summarise what was found and ask for explicit confirmation:

> I found the following cohorts in the manifest — are these the ones you want to use?
>
> - **CKD entry** → id: 1, label: "Chronic Kidney Disease", category: "Target"
> - **T2D entry** → id: 2, label: "Type 2 Diabetes", category: "Comparator"
>
> If not, share the exact labels or run `cohortManifest$tabulateManifest()` so I can look them up.

If any lookup returns `NULL`, stop and tell the user clearly:

> The cohort `"<label>"` was not found in the manifest. It must be registered first via
> `import_atlas_cohort.R`, `import_capr_cohort.R`, or `import_sql_cohort.R`, then re-sourced
> before a derived cohort can be built from it.

---

### Step 3: Write the Code

> **Builder signatures, full code examples, and dependency tracking commands are in `REFERENCE.md`.**
> Consult it for the chosen builder's parameters before writing code.

All code goes in section **B** of `inputs/cohorts/R/build_dependent_cohorts.R`.

**Important:** If this file already exists and contains prior derived cohort code, append your new
code to the end of section **B** (before any existing section C or later). Do not create a new file
or overwrite existing code. Multiple calls to this agent in the same study session should all
add their builders to the same file.

**Before adding the builder call, add a comment block summarizing the scoping decisions from Step 1:**

```r
# ---- CKD_With_Prior_T2D ----
# Builder type: buildSubsetCohortTemporal (temporal subset)
# Base cohort: CKD (id: 1)
# Filter cohort: T2D (id: 2)
# Window: T2D must start within 365 days before CKD start
# End date type: follows base (CKD)
# Subset limit: First qualifying T2D event per subject
# Labels/tags: [document here]
```

Then write the entry lookups and builder call immediately after this comment.

**Two rules apply to every builder call:**

**1. Entry-first pattern** — look up cohorts by label, never hardcode IDs:

```r
ckdEntry   <- cohortManifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")
t2dEntry   <- cohortManifest$queryCohortsByLabel("Type 2 Diabetes",        matchType = "exact")
```

Pass the resulting tibble rows via `*Entry` / `*Entries` arguments. Legacy `*Id` / `*Ids`
arguments emit a migration warning and should not appear in new code.

**2. Always pass `stopIfExists = FALSE`** — with the default (`TRUE`) the call aborts if the
label is already registered. With `FALSE`, re-sourcing updates the cohort in place (same ID,
SQL re-rendered, hash refreshed, dependents marked stale), so definitions can be safely
revised after first registration. Verify the label is not already taken by a *different*
cohort before writing a new build call.

---

### Step 4: Delivery Report

After writing the builder calls, report to the user:

1. Which base cohort entries were confirmed in Step 2 and what labels/IDs they resolved to.
2. Which builder type was used and why.
3. Any clarifying assumptions made (window direction, `complementType`, etc.).
4. A reminder that **nothing is registered yet** — the user must source the builder script
   (or run `main.R`'s pre-pipeline section). Because `stopIfExists = FALSE` is used,
   re-sourcing is always safe.
