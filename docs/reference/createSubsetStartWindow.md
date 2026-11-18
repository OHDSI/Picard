# Create a Subset Start Window Operator

Convenience wrapper to create a SubsetWindowOperator for defining the
temporal window for a subset cohort's start date relative to the filter
cohort event.

## Usage

``` r
createSubsetStartWindow(
  subsetCohortWindowAnchor,
  startDays,
  endDays,
  baseCohortWindowAnchor = "cohort_start_date"
)
```

## Arguments

- subsetCohortWindowAnchor:

  Character. Whether to anchor to the filter cohort's
  'cohort_start_date' or 'cohort_end_date'. Determines which date from
  the filter cohort event is used as the reference point.

- startDays:

  Integer. The number of days from the base cohort anchor to the start
  of the window. Negative values indicate days before the base cohort
  date.

- endDays:

  Integer. The number of days from the base cohort anchor to the end of
  the window. Negative values indicate days before the base cohort date.

- baseCohortWindowAnchor:

  Character. Whether to anchor the window to the base cohort's
  'cohort_start_date' or 'cohort_end_date'. Default:
  'cohort_start_date'.

## Value

A SubsetWindowOperator object configured for start window filtering.

## Examples

``` r
# Create a start window: filter cohort must start within 365 days before to 0 days
# after the base cohort start date
start_w <- createSubsetStartWindow(
  subsetCohortWindowAnchor = "cohort_start_date",
  startDays = -365,
  endDays = 0,
  baseCohortWindowAnchor = "cohort_start_date"
)
```
