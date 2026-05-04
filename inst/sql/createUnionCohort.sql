/* Union Cohort Template
Combines multiple cohorts into a single cohort, merging overlapping or adjacent eras
into continuous periods using a gaps-and-islands algorithm.

Parameters-
  cohort_ids                  Comma-separated list of source cohort definition IDs
  output_cohort_id            Output cohort definition ID
  output_table                Schema.table to insert results into
  base_cohort_table           Schema.table containing the source cohorts
  gap_days                    Bridge eras with a gap <= N days (default 0 = only overlapping periods collapse)
  era_pad_days                Expand each source period by N days on each end before collapsing (default 0)
  min_era_days                Drop collapsed eras shorter than N days (default 0 = keep all)
  min_cohorts                 Only include subjects appearing in >= N source cohorts (default 1 = any)
  washout_days                Require a clean period of at least N days before a new era can open (default 0)
  first_era_only              Return only the first collapsed era per subject (default FALSE)
*/
{DEFAULT @gap_days = 0}
{DEFAULT @era_pad_days = 0}
{DEFAULT @min_era_days = 0}
{DEFAULT @min_cohorts = 1}
{DEFAULT @washout_days = 0}
{DEFAULT @first_era_only = FALSE}

DELETE FROM @output_table WHERE cohort_definition_id = @output_cohort_id;
INSERT INTO @output_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)

/* Step 1 - Pad and deduplicate source periods.
   era_pad_days expands each individual source period symmetrically before any collapsing.
   DISTINCT removes duplicate (subject, start, end) rows produced when a subject appears
   in multiple source cohorts with identical period boundaries. */
WITH padded AS (
  SELECT DISTINCT
    subject_id,
    cohort_definition_id,
    DATEADD(day, -@era_pad_days, cohort_start_date) AS cohort_start_date,
    DATEADD(day,  @era_pad_days, cohort_end_date)   AS cohort_end_date
  FROM @base_cohort_table
  WHERE cohort_definition_id IN (@cohort_ids)
),

/* Step 2 - Apply min_cohorts filter.
   Only retain subjects who appear in at least @min_cohorts distinct source cohorts.
   Default (1) retains all subjects. A value of 2 requires the subject to appear in
   at least 2 of the input cohorts before any of their periods are included. */
qualified AS (
  SELECT subject_id
  FROM padded
  GROUP BY subject_id
  HAVING COUNT(DISTINCT cohort_definition_id) >= @min_cohorts
),
unioned AS (
  SELECT DISTINCT p.subject_id, p.cohort_start_date, p.cohort_end_date
  FROM padded p
  INNER JOIN qualified q ON p.subject_id = q.subject_id
),

/* Step 3 - Assign stable row order per subject and compute running max end date.
   ROW_NUMBER orders events chronologically. running_max_end tracks the furthest
   end date seen across all prior and current rows, used in step 4 to determine
   whether the next period truly begins a new era or overlaps an existing one. */
ranked AS (
  SELECT
    subject_id,
    cohort_start_date,
    cohort_end_date,
    ROW_NUMBER() OVER (
      PARTITION BY subject_id
      ORDER BY cohort_start_date, cohort_end_date
    ) AS rn,
    MAX(cohort_end_date) OVER (
      PARTITION BY subject_id
      ORDER BY cohort_start_date, cohort_end_date
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_max_end
  FROM unioned
),

/* Step 4 - Flag the start of each new era.
   A new era begins when current start > prior_max_end + gap_days (no bridgeable overlap).
   When washout_days > 0, the gap must additionally meet the washout threshold meaning
   the subject must have been clear of all source cohorts for at least that many days
   before the period is treated as a distinct new episode.
   The first row per subject (LAG returns NULL) always opens a new era. */
flags AS (
  SELECT
    subject_id,
    cohort_start_date,
    cohort_end_date,
    rn,
    CASE
      WHEN LAG(running_max_end) OVER (PARTITION BY subject_id ORDER BY rn) IS NULL
        THEN 1
      WHEN cohort_start_date > DATEADD(day, @gap_days, LAG(running_max_end) OVER (PARTITION BY subject_id ORDER BY rn))
        {@washout_days > 0} ? {
        AND DATEDIFF(day, LAG(running_max_end) OVER (PARTITION BY subject_id ORDER BY rn), cohort_start_date) >= @washout_days
        }
        THEN 1
      ELSE 0
    END AS new_episode_flag
  FROM ranked
),

/* Step 5 - Assign era IDs via cumulative sum of new_episode_flag.
   All overlapping or gap-bridged rows within a single era share the same episode_id,
   allowing the GROUP BY in the next step to collapse them into one output row. */
episodes AS (
  SELECT
    subject_id,
    cohort_start_date,
    cohort_end_date,
    SUM(new_episode_flag) OVER (
      PARTITION BY subject_id
      ORDER BY rn
      ROWS UNBOUNDED PRECEDING
    ) AS episode_id
  FROM flags
),

/* Step 6 - Collapse each era to a single row and apply min_era_days filter.
   Each (subject_id, episode_id) group produces one row spanning the full era.
   HAVING drops collapsed eras whose duration falls below the @min_era_days threshold. */
collapsed AS (
  SELECT
    subject_id,
    MIN(cohort_start_date) AS cohort_start_date,
    MAX(cohort_end_date)   AS cohort_end_date
  FROM episodes
  GROUP BY subject_id, episode_id
  HAVING DATEDIFF(day, MIN(cohort_start_date), MAX(cohort_end_date)) >= @min_era_days
)

/* Final SELECT - optionally restrict to first era per subject.
   When first_era_only = TRUE, ROW_NUMBER ranks eras per subject and only the earliest is returned.
   When FALSE (default), all collapsed eras are returned. */
{@first_era_only} ? {
SELECT
  @output_cohort_id AS cohort_definition_id,
  subject_id,
  cohort_start_date,
  cohort_end_date
FROM (
  SELECT
    subject_id,
    cohort_start_date,
    cohort_end_date,
    ROW_NUMBER() OVER (PARTITION BY subject_id ORDER BY cohort_start_date) AS era_rank
  FROM collapsed
) era_ranked
WHERE era_rank = 1;
} : {
SELECT
  @output_cohort_id AS cohort_definition_id,
  subject_id,
  cohort_start_date,
  cohort_end_date
FROM collapsed;
}

