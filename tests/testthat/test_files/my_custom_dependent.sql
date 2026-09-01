DELETE FROM @target_database_schema.@target_cohort_table
WHERE cohort_definition_id = @target_cohort_id;

INSERT INTO @target_database_schema.@target_cohort_table
  (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
SELECT
  @target_cohort_id,
  i.subject_id,
  i.cohort_start_date,
  i.cohort_end_date
FROM @target_database_schema.@target_cohort_table i
LEFT JOIN @target_database_schema.@target_cohort_table e
  ON i.subject_id = e.subject_id
  AND e.cohort_definition_id = @exc_cohort_id
WHERE i.cohort_definition_id = @inc_cohort_id
  AND e.subject_id IS NULL;
