# Picard Dependent Cohort Builder Reference

All nine builders share the same entry-first pattern, `stopIfExists = FALSE`, and optional
`tags` argument.

---

## 1. `buildSubsetCohortTemporal()` — Temporal Subset

Subsets a base cohort to patients who also have a qualifying event from a filter cohort
within a defined time window. The window is defined relative to the **base cohort's** anchor
date and constrains which filter cohort events qualify via an `INNER JOIN`.

### Window mechanics

Each window object renders into a SQL `AND` condition on the join between base cohort (`bc`)
and filter cohort (`fc`):

```sql
INNER JOIN cohort_table fc ON bc.subject_id = fc.subject_id
  AND fc.cohort_definition_id = @filter_cohort_id
  -- start window:
  AND (fc.<subsetCohortWindowAnchor> >= DATEADD(day, startDays, bc.<baseCohortWindowAnchor>)
   AND fc.<subsetCohortWindowAnchor> <= DATEADD(day, endDays,   bc.<baseCohortWindowAnchor>))
  -- end window (omitted when endWindow = NULL):
  AND (fc.<subsetCohortWindowAnchor> >= DATEADD(day, startDays, bc.<baseCohortWindowAnchor>)
   AND fc.<subsetCohortWindowAnchor> <= DATEADD(day, endDays,   bc.<baseCohortWindowAnchor>))
```

**Key mental model:**
- `baseCohortWindowAnchor` — the **reference point** (measuring from), always a date on the base cohort
- `subsetCohortWindowAnchor` — the **filter cohort date** being checked against the window
- Negative `startDays`/`endDays` = before reference; positive = after
- Both windows are `AND` conditions — filter event must satisfy both if both provided
- `Inf` / `-Inf` are accepted and silently converted to `99999L` / `-99999L`

### The start window

Controls which filter events qualify relative to the base cohort anchor.

```r
startWindow <- createSubsetStartWindow(
  subsetCohortWindowAnchor = "cohort_start_date",  # filter date to check
  startDays = -365,                                 # filter start >= 365 days before base start
  endDays   = 0,                                    # filter start <= base start date
  baseCohortWindowAnchor = "cohort_start_date"      # reference point on base cohort
)
```

*"The filter cohort must have started between 365 days before and the same day as the base cohort start."*

### The end window (optional)

Adds a second constraint — usually checks when the filter event *ends* relative to the base
cohort end. When `endWindow = NULL`, no constraint is placed on filter event end dates.

```r
endWindow <- createSubsetEndWindow(
  subsetCohortWindowAnchor = "cohort_end_date",  # filter date to check
  startDays = -30,                               # filter end >= 30 days before base end
  endDays   = 30,                                # filter end <= 30 days after base end
  baseCohortWindowAnchor = "cohort_end_date"     # reference point on base cohort
)
```

### Common window patterns

| Scenario | startDays | endDays | baseCohortWindowAnchor | subsetCohortWindowAnchor |
|---|---|---|---|---|
| Prior lookback (1 year) | `-365` | `0` | `cohort_start_date` | `cohort_start_date` |
| Any prior history | `-Inf` | `0` | `cohort_start_date` | `cohort_start_date` |
| Concurrent (same day) | `0` | `0` | `cohort_start_date` | `cohort_start_date` |
| Post-index follow-up (1 year) | `0` | `365` | `cohort_start_date` | `cohort_start_date` |
| Any future event | `0` | `Inf` | `cohort_start_date` | `cohort_start_date` |
| Same-day index (sw + ew) | sw: `0`→`Inf` + ew: `-Inf`→`0` | — | `cohort_start_date` | `cohort_start_date` |
| Active during follow-up | endWindow: `0`→`Inf` | — | `cohort_end_date` | `cohort_start_date` |

### Additional parameters

- **`endDateType`** — controls the output `cohort_end_date` after the join resolves:
  `"base"` (default, use base cohort end) or `"filter"` (use filter cohort end).
- **`subsetLimit`** — when multiple filter events qualify per subject:
  `"First"` (default), `"Last"`, or `"All"` (may produce multiple rows per subject).

### Full example

```r
startWindow <- createSubsetStartWindow(
  subsetCohortWindowAnchor = "cohort_start_date",
  startDays = -365,
  endDays   = 0,
  baseCohortWindowAnchor = "cohort_start_date"
)

cohortManifest$buildSubsetCohortTemporal(
  label             = "CKD_With_Prior_T2D",
  category          = "Derived Cohorts",
  baseCohortEntry   = ckdEntry,
  filterCohortEntry = t2dEntry,
  startWindow       = startWindow,
  endWindow         = NULL,      # no constraint on filter cohort end date
  endDateType       = "base",    # output end date follows CKD cohort
  subsetLimit       = "First",   # keep earliest qualifying T2D event per subject
  stopIfExists      = FALSE
)
```

---

## 2. `buildUnionCohort()` — Union

Combines two or more cohorts. Subjects in any source cohort are included; overlapping eras
are collapsed.

```r
cohortManifest$buildUnionCohort(
  label          = "CKD_or_T2D",
  category       = "Derived Cohorts",
  cohortEntries  = dplyr::bind_rows(ckdEntry, t2dEntry),  # minimum 2 rows
  gapDays        = 0L,       # bridge eras separated by up to this many days
  eraPadDays     = 0L,       # expand each source era before collapsing
  minEraDays     = 0L,       # drop collapsed eras shorter than this
  minCohorts     = 1L,       # require membership in at least N source cohorts
  washoutDays    = 0L,       # clean period before a new era can open
  firstEraOnly   = FALSE,    # TRUE to keep only the first era per subject
  stopIfExists   = FALSE
)
```

Use `dplyr::bind_rows()` to combine multiple entry tibbles into `cohortEntries`.

---

## 3. `buildComplementCohort()` — Complement (Exclusion)

Patients in the population cohort who do NOT appear in any (or all) exclusion cohorts.

```r
cohortManifest$buildComplementCohort(
  label                  = "CKD_Without_T2D",
  category               = "Derived Cohorts",
  populationCohortEntry  = ckdEntry,
  excludeCohortEntries   = t2dEntry,        # single entry or bind_rows() of many
  complementType         = "exclude_any",   # "exclude_any" (default) or "exclude_all"
  stopIfExists           = FALSE
)
```

- `"exclude_any"` — removes subjects in **any** exclude cohort.
- `"exclude_all"` — removes subjects only if in **all** exclude cohorts.

---

## 4. `buildCompositeCohort()` — Composite (Intersection)

Subjects must appear in multiple source cohorts to qualify.

```r
cohortManifest$buildCompositeCohort(
  label                 = "CKD_and_T2D_Composite",
  category              = "Derived Cohorts",
  criteriaCohortEntries = dplyr::bind_rows(ckdEntry, t2dEntry),  # minimum 2 rows
  minEventCount         = 2L,       # minimum distinct cohort events required
  eventSelection        = "First",  # "First", "Last", or "All"
  stopIfExists          = FALSE
)
```

---

## 5. `buildDemographicCohort()` — Demographic Subset

Filters a base cohort by person-level attributes. All criteria are optional.

```r
cohortManifest$buildDemographicCohort(
  label               = "CKD_Males_40_to_75",
  baseCohortEntry     = ckdEntry,
  category            = "Derived Cohorts",
  minAge              = 40L,        # NULL = no minimum
  maxAge              = 75L,        # NULL = no maximum
  genderConceptIds    = c(8507L),   # 8507 = Male, 8532 = Female; NULL = all
  raceConceptIds      = NULL,
  ethnicityConceptIds = NULL,
  stopIfExists        = FALSE
)
```

---

## 6. `buildStratifiedCohorts()` — Stratified Cohorts

Splits one base cohort into N named strata plus an automatic **Unclassified** stratum.
Each stratum becomes a separate manifest entry.

```r
strata <- list(
  "Female"      = list(genderConceptIds = c(8532L)),
  "Male"        = list(genderConceptIds = c(8507L)),
  "Age_65_plus" = list(minAge = 65L)
)

cohortManifest$buildStratifiedCohorts(
  baseCohortEntry = ckdEntry,
  strata          = strata,
  labelPrefix     = "CKD",   # → "CKD - Female", "CKD - Male", "CKD - Unclassified"
  category        = "Derived Cohorts",
  stopIfExists    = FALSE
)
```

Each stratum element is a named list with any of:
`genderConceptIds`, `raceConceptIds`, `ethnicityConceptIds`, `minAge`, `maxAge`.

---

## 7. `buildOPriorT()` — Outcome Prior to Target (O-Prior-T)

Subsets outcome events to those with prior target exposure in a lookback window.

```r
cohortManifest$buildOPriorT(
  label               = "Bleed_Prior_T2D",
  category            = "Outcomes",
  outcomeCohortEntry  = bleedEntry,
  targetCohortEntry   = t2dEntry,
  mode                = "prior",   # "prior" (target before outcome)
  priorTimeWindowDays = 365L,      # NULL = any prior history
  subsetLimit         = "First",   # "First", "Last", or "All"
  stopIfExists        = FALSE
)
```

---

## 8. `buildTPriorO()` — Target Prior to Outcome (T-Prior-O)

Subsets target events to those with a prior outcome in a lookback window.

```r
cohortManifest$buildTPriorO(
  label               = "T2D_Prior_Bleed",
  category            = "Exposures",
  targetCohortEntry   = t2dEntry,
  outcomeCohortEntry  = bleedEntry,
  mode                = "prior",   # "prior" (outcome before target)
  priorTimeWindowDays = 365L,      # NULL = any prior history
  subsetLimit         = "First",
  stopIfExists        = FALSE
)
```

---

## 9. `buildCensorCohort()` — Censor Cohort

Censors a target cohort at the first occurrence of a censoring event.

```r
cohortManifest$buildCensorCohort(
  label             = "T2D_Censored_At_Death",
  category          = "Exposures",
  targetCohortEntry = t2dEntry,
  censorCohortEntry = deathEntry,
  stopIfExists      = FALSE
)
```

---

# Dependency Tracking

All nine builders automatically:

- Record `depends_on` and `dependency_rule` in SQLite.
- Mark downstream derived cohorts **stale** when a parent cohort's SQL file hash changes.
- Enforce a **cycle guard**: a cohort cannot depend on itself or its own dependents.

Review the dependency graph:

```r
cohortManifest$reviewDependentCohorts()  # tibble of all derived cohorts with parent info
cohortManifest$reviewStaleCohorts()      # list of cohorts currently marked stale
plotCohortGraph(cohortManifest)          # Mermaid dependency diagram
```
