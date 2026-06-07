/*
Target-Prior-Outcome Cohort

Creates a derived cohort based on the temporal relationship between a target
(exposure) cohort and an outcome cohort. Supports two modes:
  - 'prior':     Retain target events where a prior outcome exists
  - 'no_prior':  Retain target events where no prior outcome exists

Optionally restricts the lookback window with @prior_time_window_days and controls
which prior outcome event anchors the match via @subset_limit.

This is the reverse direction of createOPriorT: instead of filtering outcome by
prior target, filter target by prior outcome.

Parameters:
  target_cohort_id     The cohort definition ID for the target (e.g., NSAID use)
  outcome_cohort_id    The cohort definition ID for the outcome (e.g., GI bleed)
  mode                 'prior' or 'no_prior'
  prior_time_window_days  NULL/0 = all time; integer (e.g. 365) = lookback window
  subset_limit         'First' (earliest prior), 'Last' (most recent prior), or 'All'
  output_cohort_id     The new cohort definition ID for the output
  output_table         Schema.table to insert results into
  base_cohort_table    Schema.table containing the cohort definitions
*/
{DEFAULT @mode = 'prior'}
{DEFAULT @subset_limit = 'First'}
{DEFAULT @use_prior_time_window = FALSE}

DELETE FROM @output_table WHERE cohort_definition_id = @output_cohort_id;
{@mode == 'prior'} ? {
INSERT INTO @output_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
SELECT
  @output_cohort_id AS cohort_definition_id,
  sub.subject_id,
  sub.cohort_start_date,
  sub.cohort_end_date
FROM (
  SELECT
    t.subject_id,
    t.cohort_start_date,
    t.cohort_end_date,
    {@subset_limit == 'Last'} ? {
      ROW_NUMBER() OVER (PARTITION BY t.subject_id, t.cohort_start_date ORDER BY o.cohort_start_date DESC) AS rn
    } : {
      ROW_NUMBER() OVER (PARTITION BY t.subject_id, t.cohort_start_date ORDER BY o.cohort_start_date) AS rn
    }
  FROM @base_cohort_table t
  INNER JOIN @base_cohort_table o
    ON o.subject_id = t.subject_id
    AND o.cohort_definition_id = @outcome_cohort_id
    AND o.cohort_start_date < t.cohort_start_date
    {@use_prior_time_window} ? {
      AND o.cohort_start_date >= DATEADD(DAY, -@prior_time_window_days, t.cohort_start_date)
    } : {}
  WHERE t.cohort_definition_id = @target_cohort_id
) sub
{@subset_limit == 'First' | @subset_limit == 'Last'} ? {
  WHERE sub.rn = 1
} : {}
;
} : {
INSERT INTO @output_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
SELECT
  @output_cohort_id AS cohort_definition_id,
  t.subject_id,
  t.cohort_start_date,
  t.cohort_end_date
FROM @base_cohort_table t
WHERE t.cohort_definition_id = @target_cohort_id
  AND NOT EXISTS (
    SELECT 1
    FROM @base_cohort_table o
    WHERE o.subject_id = t.subject_id
      AND o.cohort_definition_id = @outcome_cohort_id
      AND o.cohort_start_date < t.cohort_start_date
      {@use_prior_time_window} ? {
        AND o.cohort_start_date >= DATEADD(DAY, -@prior_time_window_days, t.cohort_start_date)
      } : {}
  )
;
}
