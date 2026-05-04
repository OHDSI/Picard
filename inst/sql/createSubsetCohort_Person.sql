/*Subset Cohort  Demographic Filtering Based on Person Table Attributes
Creates a subset of a base cohort by filtering on person-level demographic attributes
Example Patients with CKD who are male, age 40-75, and non-Hispanic White

Parameters-
  base_cohort_id The cohort definition ID to subset
  min_age Minimum age (calculated at cohort_start_date). NULL = no minimum
  max_age Maximum age (calculated at cohort_start_date). NULL = no maximum
  gender_concept_ids Comma-separated list of gender concept IDs to include. NULL = include all genders
                       Common values: 8507=Male, 8532=Female, 0=Unknown
  race_concept_ids Comma-separated list of race concept IDs to include. NULL = include all races
                     Common values: 8516=Asian, 8515=Black, 8557=Hispanic, 8527=Native, 8557=Pacific, 8539=White
  ethnicity_concept_ids Comma-separated list of ethnicity concept IDs to include. NULL = include all ethnicities
  output_cohort_id The new cohort definition ID for the subset
  output_table Schema.table to insert results into
  base_cohort_table Schema.table containing the base cohort
  cdm_database_schema Schema containing CDM tables (person, observation)
*/
{DEFAULT @min_age = NULL}
{DEFAULT @max_age = NULL}
{DEFAULT @gender_concept_ids = NULL}
{DEFAULT @race_concept_ids = NULL}
{DEFAULT @ethnicity_concept_ids = NULL}

DELETE FROM @output_table WHERE cohort_definition_id = @output_cohort_id;
INSERT INTO @output_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
SELECT DISTINCT
  @output_cohort_id AS cohort_definition_id,
  bc.subject_id,
  bc.cohort_start_date,
  bc.cohort_end_date
FROM @base_cohort_table bc
INNER JOIN @cdm_database_schema.person p
  ON bc.subject_id = p.person_id
WHERE bc.cohort_definition_id = @base_cohort_id
  {@min_age != ''}?{
    AND YEAR(bc.cohort_start_date) - p.year_of_birth >= @min_age
  }:{}
  {@max_age != ''}?{
    AND YEAR(bc.cohort_start_date) - p.year_of_birth <= @max_age
  }:{}
  {@gender_concept_ids != ''}?{
    AND p.gender_concept_id IN (@gender_concept_ids)
  }:{}
  {@race_concept_ids != ''}?{
    AND p.race_concept_id IN (@race_concept_ids)
  }:{}
  {@ethnicity_concept_ids != ''}?{
    AND p.ethnicity_concept_id IN (@ethnicity_concept_ids)
  }:{}
;
