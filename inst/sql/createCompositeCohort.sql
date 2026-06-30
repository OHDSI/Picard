/*
Composite Cohort - Combines multiple cohort definitions into a single cohort
Creates a cohort where subjects must have at least N events from a set of cohort definitions.
The index date can be the first event, last event, or all events are retained.

Parameters:
  criteria_cohort_ids - Comma-separated list of cohort definition IDs to include in the composite
  minimum_event_count - Minimum number of distinct cohort events required for a subject to qualify.
                        Default: 1 (any subject with at least 1 event qualifies)
  event_selection - 'First' (earliest event), 'Last' (most recent event), or 'All' (retain all events).
                    Default: 'First'
  output_cohort_id - The new cohort definition ID for the composite cohort
  output_table - Schema.table to insert results into
  base_cohort_table - Schema.table containing the cohort definitions
*/
{DEFAULT @minimum_event_count = 1}
{DEFAULT @event_selection = 'First'}

DELETE FROM @output_table WHERE cohort_definition_id = @output_cohort_id;
INSERT INTO @output_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
SELECT
  @output_cohort_id AS cohort_definition_id,
  sub.subject_id,
  sub.cohort_start_date,
  sub.cohort_end_date
FROM (
  SELECT
    subject_id,
    cohort_start_date,
    cohort_end_date,
    COUNT(DISTINCT cohort_definition_id) OVER (PARTITION BY subject_id) AS event_count, /* count distinct cohort events per subject across specified cohort definitions */
    {@event_selection == 'Last'} ? {
      ROW_NUMBER() OVER (PARTITION BY subject_id ORDER BY cohort_start_date DESC) AS rn
    } : {
      ROW_NUMBER() OVER (PARTITION BY subject_id ORDER BY cohort_start_date) AS rn
    }
  FROM @base_cohort_table
  WHERE cohort_definition_id IN (@criteria_cohort_ids)
) sub
WHERE sub.event_count >= @minimum_event_count
{@event_selection == 'First' | @event_selection == 'Last'} ? {
  AND sub.rn = 1
} : {
  /* keep all events for each subject */
}
;