-- Cohort: Patients with Type 2 Diabetes
DELETE FROM @target_database_schema.cohort
WHERE cohort_definition_id = @target_cohort_id;

INSERT INTO @target_database_schema.cohort
  (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
SELECT
  @target_cohort_id as cohort_definition_id,
  person_id as subject_id,
  condition_start_date as cohort_start_date,
  DATEADD(day, 365, condition_start_date) as cohort_end_date
FROM @cdm_database_schema.condition_occurrence
WHERE condition_concept_id IN (201820, 443238)
  AND condition_start_date >= '2015-01-01';