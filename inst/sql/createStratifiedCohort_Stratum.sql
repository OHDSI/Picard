/*Stratified Cohort Template - Single Stratum
Extracts one stratum from a base cohort by applying a WHERE condition against the CDM
person table. One SQL file is written per stratum by buildStratifiedCohorts().

Build-time parameters (rendered into the file by buildStratifiedCohorts()):
  base_cohort_id       Cohort definition ID of the source cohort
  stratum_where_clause SQL boolean expression that filters subjects into this stratum.
                       May reference:
                         bc  - alias for the cohort table row (subject_id, cohort_start_date, etc.)
                         p   - alias for cdm_database_schema.person
                       For the Unclassified stratum this is the negation of all
                       named stratum conditions combined with AND NOT.

Runtime parameters (injected by generateCohorts()):
  output_cohort_id     Cohort definition ID to write results into
  output_table         Fully-qualified cohort table (schema.table)
  base_cohort_table    Fully-qualified cohort table (same table, read side)
  cdm_database_schema  CDM schema containing the person table
*/

DELETE FROM @output_table WHERE cohort_definition_id = @output_cohort_id;

INSERT INTO @output_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
SELECT DISTINCT
  @output_cohort_id    AS cohort_definition_id,
  bc.subject_id,
  bc.cohort_start_date,
  bc.cohort_end_date
FROM @base_cohort_table bc
INNER JOIN @cdm_database_schema.person p
  ON bc.subject_id = p.person_id
WHERE bc.cohort_definition_id = @base_cohort_id
  AND (@stratum_where_clause);
