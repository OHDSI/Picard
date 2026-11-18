# Build a Composite Cohort Definition

Creates a SQL file and metadata for a composite cohort that combines
multiple cohort definitions. A composite cohort groups subjects who have
at least N qualifying events from a set of cohort definitions. Returns a
CohortDef object ready to add to a CohortManifest.

## Usage

``` r
buildCompositeCohort(
  label,
  criteriaCohortIds,
  minimumEventCount = 1,
  eventSelection = "First",
  manifest
)
```

## Arguments

- label:

  Character. User-friendly name for the composite (e.g., "Diabetes
  mellitus").

- criteriaCohortIds:

  Integer vector. The cohort IDs to include in the composite (e.g., c(1,
  2, 3) for Type 1 diabetes, Type 2 diabetes, and secondary diabetes).

- minimumEventCount:

  Integer. Minimum number of distinct cohort events required for a
  subject to qualify for the composite. Default: 1 (any subject with at
  least 1 event qualifies).

- eventSelection:

  Character. One of 'First', 'Last', or 'All'. Specifies which event(s)
  to retain as the cohort_start_date and cohort_end_date in the output:

  - 'First': Keep the earliest event (earliest index date)

  - 'Last': Keep the most recent event

  - 'All': Keep all qualifying events per subject (may result in
    multiple rows per subject) Default: 'First'.

- manifest:

  CohortManifest object. Required. Validates that all criteria cohorts
  exist.

## Value

A CohortDef object with cohortType='composite' and dependencies set.

## Details

Creates three files:

- SQL file:
  `inputs/cohorts/derived/composite/composite_cohort_{hash}.sql`

- Metadata JSON: Same path with `.json` extension (parameters for
  execution)

- Hash ensures uniqueness when same criteria are used with different
  labels

## Examples

``` r
# Create a composite cohort for diabetes (any type): Type 1, Type 2, or secondary diabetes
# Keep only subjects with at least 1 event (any diagnosis), using first event as index date

diabetes_cohort <- buildCompositeCohort(
  label = "Diabetes mellitus (any type)",
  criteriaCohortIds = c(101, 102, 103),
  minimumEventCount = 1,
  eventSelection = "First"
)
#> Error in lifecycle::deprecate_warn("0.0.3", "buildCompositeCohort()",     what2 = "CohortManifest$buildCompositeCohort()", details = "Use the R6 method: `manifest$buildCompositeCohort(label, cohortIds, category, ...)`"): unused argument (what2 = "CohortManifest$buildCompositeCohort()")
```
