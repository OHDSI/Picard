---
name: picard-capr-cohorts
description: >
  Build Capr cohort definitions and concept sets inside a Picard/Ulysses study repository.
  Use whenever the user asks to create, translate, or modify a cohort definition, phenotype,
  study population, or concept set in this study. Wraps the capr-cohort-generation skill with
  Picard-specific delivery: definitions are appended to the pre-pipeline builder scripts and
  registered in the study manifests instead of written to standalone files.
---

# Picard + Capr Cohort Building

This skill adapts the **`capr-cohort-generation`** skill (in `.agent/skills/capr-cohort-generation/`)
to a Picard study repository. That skill's generation contract is authoritative and unchanged:

- Step 1 clarification message (index event, domains, entry limit, washout, windows, exit) —
  every request, every time.
- Function-form output with the mandatory `Scope check` comment block.
- Only API documented in `CAPR_REFERENCE.md`; never write concept IDs from memory.
- Validation by execution before delivery.

If the `capr-cohort-generation` folder is missing, stop and ask the user to install Capr
(`remotes::install_github("OHDSI/Capr")`) and run `picard::initAgentMode()` to copy it in.

What changes in a Picard repo is **where the code lives, how it is serialized, and how it is
validated** — the delivery overrides below, permitted by that skill's *Delivery Integration*
section.

## Delivery Overrides

### 1. Target file, not standalone files

Do **not** create one R file per cohort. Append to the pre-pipeline builder scripts:

- Cohorts → `inputs/cohorts/R/import_capr_cohort.R`
- Concept sets → `inputs/conceptSets/R/import_capr_concept_set.R`

Each builder script has lettered sections. Put the `Scope check` block, concept sets, and the
cohort-building function in section **B** (definitions), and the function invocation plus
manifest registration in section **C** (registration). If the builder script does not exist,
ask the user to run `picard::makeInputBuilderScript(type = "importCapr", category = "cohorts")`
(or `category = "conceptSets"`), or create the file following the existing scripts' section
layout.

### 2. Ask for registration metadata before writing any code

Registration needs metadata the Capr skill's Step 1 questions do not cover. Extend the Step 1
clarification message with these Picard fields and get the user's answers **before** writing
the cohort-building function or the registration call:

- **label** — display name; must not collide with an existing manifest label (see the label
  check in the next section).
- **category** — required classification (e.g. `"Target"`, `"Comparator"`, `"Outcome"`);
  never invent one — ask which category the study uses.
- **tags** — optional named list of metadata; ask whether the user wants any (for cohorts, a
  `route = "capr"` provenance tag is added automatically, so it never needs to be supplied).

Do not guess these values or deliver code with placeholder metadata. If the user leaves tags
unspecified after being asked, omit the `tags` argument rather than inventing entries.

### 3. Manifest registration, not `writeCohort()`

Never call `Capr::writeCohort()` (or `writeConceptSet()`) in the builder script. Registration
goes through the manifest API, which serializes the JSON into `inputs/cohorts/json/` (or
`inputs/conceptSets/json/`) internally and records the definition with a content hash:

```r
# Section C — register cohorts in the manifest
cohortDef <- createT2dmCohort(t2dmCs, insulinCs)

cohortManifest$addCaprCohort(
  caprCohort = cohortDef,
  label = "Type 2 Diabetes",          # ask the user; see registration metadata above
  category = "Target",                # ask the user; required classification
  tags = list(source = "phenotype library"),  # ask the user; optional named list
  stopIfExists = FALSE                # upsert: re-sourcing updates the definition in place
)
```

For concept sets:

```r
conceptSetManifest$addCaprConceptSet(
  caprConceptSet = t2dmCs,
  label = "Type 2 Diabetes Mellitus",
  category = "Conditions",
  tags = list(source = "phenotype library"),
  stopIfExists = FALSE
)
```

**Always pass `stopIfExists = FALSE`** in registrations you write. With the default
(`stopIfExists = TRUE`) the call aborts if the label is already registered, so a definition
could never be revised after its first registration. With `FALSE`, editing the function in the
builder script and re-sourcing updates the registered definition in place: the cohort keeps its
ID and JSON file path, an unchanged definition is a no-op, derived cohorts that depend on it are
marked stale, and `category` (plus `tags`, when supplied) replace the registered metadata. This
is what makes it possible to fix a definition later if validation or review turns up a problem.

Because a matching label now updates rather than errors, an accidental label collision would
silently overwrite an unrelated cohort. Still check existing labels before registering a **new**
definition by listing `inputs/cohorts/json/` and reading the registrations already in the
builder scripts; if the label is taken by a different cohort, ask the user for another label.
Do **not** call `loadCohortManifest()` yourself to check: it auto-syncs by default, which
**deletes** any stray JSON file in `inputs/cohorts/json/` that isn't already registered in the
manifest — including a cohort file you're about to register.

### 4. Concept sets: check the study before placeholdering

A Picard study usually already has concept sets (imported from ATLAS or defined in
`inputs/conceptSets/R/`). Before creating a `[PLACEHOLDER]` concept set per the Capr skill's
pattern, check `inputs/conceptSets/json/` and the concept set builder scripts, and ask the user
whether an existing concept set covers the criterion. Only fall back to the placeholder pattern
(distinct incrementing ids, `[PLACEHOLDER]` name suffix) when nothing suitable exists.

### 5. Validation on a scratch copy, never by sourcing the builder script

The builder script mutates the manifest SQLite database when sourced, so it is **user-run only**
(see the Code Execution Policy in `AGENTS.md`). Validate per the Capr skill's Step 3 on a
scratch copy instead:

1. Copy the cohort function plus a placeholder example block — including a temporary
   `writeCohort()` call — into a scratch file **outside the repository** (e.g. `tempdir()`).
2. Run it with `Rscript` and run the CirceR compile check from the Capr skill. This needs no
   database and touches nothing in the repo, so it is allowed.
3. Delete nothing from the repo on failure — fix the code in the builder script and re-validate.

Do not deliver a definition whose scratch copy has not passed both checks.

### 6. Delivery report

Follow the Capr skill's Step 4 report (what was built, assumptions, placeholders), plus two
Picard-specific items:

- Remind the user that the change is **not yet registered**: they must source the builder
  script (or run the pre-pipeline section of `main.R`) to add it to the manifest and write the
  JSON. Because registrations use `stopIfExists = FALSE`, re-sourcing is safe: new definitions
  are added and revised ones are updated in place.
- If any concept set is a placeholder, note that real concept sets can come from the study's
  existing concept set manifest, ATLAS import, or ATHENA lookup — see
  `.agent/reference-docs/04-loading-inputs.md`.
