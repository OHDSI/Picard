/*
Censor Cohort - Censor a target cohort on the occurrence of a censoring cohort event.

Truncates the cohort_end_date of each target cohort record to the earliest censoring
event that occurs between the cohort_start_date and cohort_end_date. If no censoring
event occurs, the original cohort_end_date is preserved.

Parameters:
  target_cohort_id    The cohort definition ID for the cohort to censor
  censor_cohort_id    The cohort definition ID for the censoring event (e.g., death, exacerbation)
  output_cohort_id    The new cohort definition ID for the censored output
  output_table        Schema.table to insert results into
  base_cohort_table   Schema.table containing the cohort definitions
*/

DELETE FROM @output_table WHERE cohort_definition_id = @output_cohort_id;
INSERT INTO @output_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
SELECT
  @output_cohort_id AS cohort_definition_id,
  t.subject_id,
  t.cohort_start_date,
  COALESCE(
    MIN(c.cohort_start_date),
    t.cohort_end_date
  ) AS cohort_end_date
FROM @base_cohort_table t
LEFT JOIN @base_cohort_table c
  ON c.subject_id = t.subject_id
  AND c.cohort_definition_id = @censor_cohort_id
  AND c.cohort_start_date >= t.cohort_start_date
  AND c.cohort_start_date <= t.cohort_end_date
WHERE t.cohort_definition_id = @target_cohort_id
GROUP BY
  t.subject_id,
  t.cohort_start_date,
  t.cohort_end_date;