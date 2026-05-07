/*
Censor a target cohort on the occurrence of a censoring cohort event.
Cohort to censor: @target_cohort_definition_id | @target_cohort_name
Cohort with censoring event: @censor_cohort_definition_id | @censor_cohort_name
Output cohort ID: @target_cohort_id
*/

DELETE FROM @target_database_schema.@target_cohort_table WHERE cohort_definition_id = @output_cohort_id;
INSERT INTO @target_database_schema.@target_cohort_table (cohort_definition_id,subject_id,cohort_start_date,cohort_end_date)
SELECT
  @output_cohort_id AS cohort_definition_id,
  t.subject_id,
  t.cohort_start_date,
  COALESCE(
    MIN(c.cohort_start_date),
    t.cohort_end_date
    ) AS cohort_end_date
FROM @target_database_schema.@target_cohort_table t
LEFT JOIN @target_database_schema.@target_cohort_table c
  ON c.subject_id = t.subject_id
  AND c.cohort_definition_id = @censor__id
  AND c.cohort_start_date BETWEEN t.cohort_start_date AND t.cohort_end_date
WHERE t.cohort_definition_id = @target_id
GROUP BY
  t.subject_id,
  t.cohort_start_date,
  t.cohort_end_date;