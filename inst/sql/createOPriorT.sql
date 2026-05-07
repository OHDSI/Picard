/*
Modify an Outcome cohort with prior target cohort

O: @outcome_name cohort ID @outcome_id
T: @target_name cohort ID @target_id
*/

DELETE FROM @target_database_schema.@target_cohort_table WHERE cohort_definition_id = @output_cohort_id;
INSERT INTO @target_database_schema.@target_cohort_table (cohort_definition_id,subject_id,cohort_start_date,cohort_end_date)

SELECT DISTINCT
  @output_cohort_id AS cohort_definition_id,
  o.subject_id,
  o.cohort_start_date,
  o.cohort_end_date
FROM @target_database_schema.@target_cohort_table o
  JOIN @target_database_schema.@target_cohort_table t ON t.subject_id = o.subject_id
    AND t.cohort_definition_id = @target_id
    AND t.cohort_start_date < o.cohort_start_date
WHERE o.cohort_definition_id = @outcome_id;