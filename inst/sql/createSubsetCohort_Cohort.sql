/*
Subset Cohort  Temporal Filtering Based on Second Cohort
Creates a subset of a base cohort by filtering with temporal logic against another cohort
Example Patients with CKD who had a T2D diagnosis in the prior year

Parameters
  base_cohort_id The cohort definition ID to subset (e.g., CKD)
  filter_cohort_id The cohort definition ID to use for temporal filtering (e.g., T2D)
  start_window SQL snippet defining the temporal relationship between base cohort event and filter cohort event for cohort_start_date
  end_window SQL snippet defining the temporal relationship between base cohort event and filter cohort event for cohort_end_date (optional)
  end_date_type Whether to use the base cohort end date or filter cohort end date as the cohort end date in the output subset cohort. Allowed values are 'base' or 'filter'. Default is 'base'.
  subset_limit Whether to keep the first qualifying filter cohort event per subject or all qualifying filter cohort events per subject in the output subset cohort. Allowed values are 'First', 'Last', or 'All'. Default is 'First'.
      If 'First' (default), the first qualifying filter cohort event per subject will be kept based on the specified temporal relationship and offsets, which may result in one row per subject in the output cohort.
      If 'Last', the last qualifying filter cohort event per subject will be kept based on the specified temporal relationship and offsets, which may result in one row per subject in the output cohort.
      If 'All', all qualifying filter cohort events per subject will be kept based on the specified temporal relationship and offsets, which may result in multiple rows per subject in the output cohort if multiple filter cohort events meet the criteria.
  output_cohort_id The new cohort definition ID for the subset
  output_table Schema.table to insert results into
  base_cohort_table Schema.table containing the base cohort
*/
DELETE FROM @output_table WHERE cohort_definition_id = @output_cohort_id;
INSERT INTO @output_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
SELECT
  @output_cohort_id AS cohort_definition_id,
  sub.subject_id,
  sub.base_cohort_start_date AS cohort_start_date,
  {@end_date_type == 'base'} ? {sub.base_cohort_end_date AS cohort_end_date} : {sub.filter_cohort_end_date AS cohort_end_date}
FROM (
  SELECT 
    bc.subject_id,
    bc.cohort_start_date AS base_cohort_start_date,
    bc.cohort_end_date AS base_cohort_end_date,
    fc.cohort_start_date AS filter_cohort_start_date,
    fc.cohort_end_date AS filter_cohort_end_date,
    {@subset_limit == 'Last'} ? {
      /*Take the last event as the qualifying filter cohort event per subject, which ranks events in descending order by cohort start date and keeps the first ranked event per subject in the final output cohort*/
      ROW_NUMBER() OVER (PARTITION BY bc.subject_id ORDER BY bc.cohort_start_date DESC) AS rn
    } : {
      /*Take the first event as the qualifying filter cohort event per subject, which ranks events in ascending order by cohort start date and keeps the first ranked event per subject in the final output cohort*/
      ROW_NUMBER() OVER (PARTITION BY bc.subject_id ORDER BY bc.cohort_start_date) AS rn
    } 
  FROM @base_cohort_table bc
  INNER JOIN @base_cohort_table fc ON bc.subject_id = fc.subject_id AND fc.cohort_definition_id = @filter_cohort_id
    /* determine temporal relationship between base cohort event and filter cohort event based on specified operator and offsets */
    @start_window
    @end_window
  WHERE bc.cohort_definition_id = @base_cohort_id
) sub
/* Determine which qualifying filter cohort event to keep for each subject based on subsetLimit parameter */
{@subset_limit == 'First' | @subset_limit == 'Last'} ? {
WHERE sub.rn = 1 /*keep only the first ranked evert per subject*/
} : {
/*keep all qualifying filter cohort events per subject, which may result in multiple rows per subject in the output cohort*/
}
;
