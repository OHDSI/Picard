/*Complement Cohort Template
Creates a complement cohort: all subjects in the population cohort who are NOT found
in the exclude cohort(s). Uses a LEFT JOIN anti-join for cross-DBMS compatibility.
Dates are always taken from the population cohort (index dates are preserved).

Parameters
  population_cohort_id     The cohort definition ID representing the population
  exclude_cohort_ids       Comma-separated list of cohort definition IDs to exclude
  exclude_cohort_ids_count Number of unique cohort IDs in exclude_cohort_ids
                           Required for 'exclude_all': subject must appear in ALL N cohorts
  complement_type          'exclude_any' - exclude if subject appears in ANY exclude cohort
                           'exclude_all' - exclude only if subject appears in ALL exclude cohorts
  output_cohort_id         The new cohort definition ID for the complement
  output_table             Schema.table to insert results into
  base_cohort_table        Schema.table containing the input cohorts
*/

{DEFAULT @complement_type = 'exclude_any'}

DELETE FROM @output_table WHERE cohort_definition_id = @output_cohort_id;

INSERT INTO @output_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
SELECT
  @output_cohort_id AS cohort_definition_id,
  pop.subject_id,
  pop.cohort_start_date,
  pop.cohort_end_date
FROM @base_cohort_table pop
LEFT JOIN (
  SELECT
    subject_id
  FROM @base_cohort_table
  WHERE cohort_definition_id IN (@exclude_cohort_ids)
  GROUP BY subject_id
  HAVING COUNT(DISTINCT cohort_definition_id) >=
    {@complement_type == 'exclude_any'} ? {1} : {@exclude_cohort_ids_count}
) excluded
  ON pop.subject_id = excluded.subject_id
WHERE pop.cohort_definition_id = @population_cohort_id
  AND excluded.subject_id IS NULL;
