# OMOP Common Data Model (CDM) 5.4 Reference

## Introduction

The OMOP Common Data Model (CDM) is a standardized data structure for real-world evidence research. All data in your study database follows this schema, organized into standardized tables with defined relationships.

**This reference is essential when:**
- Writing SQL queries to extract patient data
- Defining cohorts using diagnosis/procedure/drug codes
- Creating concept sets for phenotypes
- Understanding relationships between clinical events

For complete official documentation, see: https://ohdsi.github.io/CommonDataModel/cdm54.html

---

## Core Clinical Tables

### PERSON
**Purpose:** Unique patient records

**Key columns:**
- `person_id` - Unique patient identifier (PRIMARY KEY)
- `birth_year`, `month_of_birth`, `day_of_birth` - Demographics
- `gender_concept_id` - Gender (8507=Male, 8532=Female)
- `race_concept_id` - Race
- `ethnicity_concept_id` - Ethnicity

**Usage in picard:**
```sql
-- Calculate age at observation
SELECT 
  person_id,
  YEAR(observation_date) - birth_year AS age_at_obs
FROM @cdmDatabaseSchema.person
JOIN @cdmDatabaseSchema.observation_period op ON person.person_id = op.person_id
```

---

### OBSERVATION_PERIOD
**Purpose:** Defines when a patient is actively enrolled in the health system

**Key columns:**
- `observation_period_id` - Unique identifier
- `person_id` - Foreign key to PERSON (REQUIRED for cohort inclusion)
- `observation_period_start_date` - First date of enrollment
- `observation_period_end_date` - Last date of enrollment
- `period_type_concept_id` - Type of enrollment

**Critical point:** Always use observation_period to define enrollment requirements. A patient must have continuous observation to be included in most cohorts.

**Usage in picard:**
```sql
-- Get patients with continuous observation for study period
SELECT 
  person_id,
  observation_period_start_date,
  observation_period_end_date
FROM @cdmDatabaseSchema.observation_period
WHERE observation_period_start_date <= '2020-01-01'
  AND observation_period_end_date >= '2023-12-31'
```

---

### CONDITION_OCCURRENCE
**Purpose:** Diagnosis codes for patients (ICD-10, SNOMED)

**Key columns:**
- `condition_occurrence_id` - Unique identifier
- `person_id` - Foreign key to PERSON
- `condition_concept_id` - OMOP concept ID for diagnosis
- `condition_start_date` - Date condition started
- `condition_end_date` - Date condition resolved
- `condition_status_concept_id` - Status (active, resolved, etc.)
- `visit_occurrence_id` - Associated visit

**Key relationships:**
- Links to CONCEPT table via `condition_concept_id`
- Links to VISIT_OCCURRENCE for timing
- Multiple conditions per person

**Usage in picard (Diabetes cohort example):**
```sql
-- Find patients with Type 2 Diabetes diagnosis
SELECT 
  person_id,
  condition_start_date AS index_date,
  condition_concept_id
FROM @cdmDatabaseSchema.condition_occurrence
WHERE condition_concept_id IN (
  SELECT descendant_concept_id 
  FROM @cdmDatabaseSchema.concept_ancestor
  WHERE ancestor_concept_id = 201826  -- Type 2 Diabetes
)
```

---

### DRUG_EXPOSURE
**Purpose:** Medication dispensing or prescriptions

**Key columns:**
- `drug_exposure_id` - Unique identifier
- `person_id` - Foreign key to PERSON
- `drug_concept_id` - OMOP concept ID for drug
- `drug_exposure_start_date` - Date medication started
- `drug_exposure_end_date` - Date medication stopped
- `quantity` - Number of units
- `days_supply` - Number of days supplied
- `visit_occurrence_id` - Associated visit

**Usage in picard (Treatment pattern example):**
```sql
-- Find drug exposures with calculated days on treatment
SELECT 
  person_id,
  drug_concept_id,
  drug_exposure_start_date,
  drug_exposure_end_date,
  DATEDIFF(DAY, drug_exposure_start_date, drug_exposure_end_date) AS days_on_drug
FROM @cdmDatabaseSchema.drug_exposure
WHERE drug_concept_id IN (
  SELECT descendant_concept_id 
  FROM @cdmDatabaseSchema.concept_ancestor
  WHERE ancestor_concept_id = 1506270  -- Metformin
)
```

---

### PROCEDURE_OCCURRENCE
**Purpose:** Procedures, measurements, and clinical procedures

**Key columns:**
- `procedure_occurrence_id` - Unique identifier
- `person_id` - Foreign key to PERSON
- `procedure_concept_id` - OMOP concept ID
- `procedure_date` - Date procedure occurred
- `visit_occurrence_id` - Associated visit

**Usage in picard:**
```sql
-- Find patients with specific procedures
SELECT 
  person_id,
  procedure_date,
  procedure_concept_id
FROM @cdmDatabaseSchema.procedure_occurrence
WHERE procedure_concept_id IN (SELECT descendant_concept_id FROM @cdmDatabaseSchema.concept_ancestor WHERE ancestor_concept_id = 4322961)  -- Kidney function test
```

---

### MEASUREMENT
**Purpose:** Lab values, vital signs, and test results

**Key columns:**
- `measurement_id` - Unique identifier
- `person_id` - Foreign key to PERSON
- `measurement_concept_id` - Type of measurement (lab test)
- `measurement_date` - Date measured
- `measurement_time` - Time measured
- `value_as_number` - Numeric result
- `value_as_concept_id` - Categorical result (e.g., positive/negative)
- `unit_concept_id` - Unit of measurement
- `operator_concept_id` - Comparison operator (=, <, >, etc.)
- `visit_occurrence_id` - Associated visit

**Usage in picard (Baseline lab values):**
```sql
-- Get most recent HbA1c before index date
SELECT 
  person_id,
  measurement_date,
  value_as_number AS hba1c_value
FROM @cdmDatabaseSchema.measurement
WHERE measurement_concept_id = 3004410  -- HbA1c
  AND measurement_date < '@indexDate'
ORDER BY person_id, measurement_date DESC
```

---

### VISIT_OCCURRENCE
**Purpose:** Healthcare visits (encounters, hospital stays)

**Key columns:**
- `visit_occurrence_id` - Unique identifier
- `person_id` - Foreign key to PERSON
- `visit_start_date` - Start of visit
- `visit_end_date` - End of visit
- `visit_type_concept_id` - Type (outpatient, inpatient, emergency)
- `visit_concept_id` - Specific visit type

**Usage in picard:**
```sql
-- Find hospitalizations
SELECT 
  person_id,
  visit_start_date,
  visit_end_date
FROM @cdmDatabaseSchema.visit_occurrence
WHERE visit_concept_id IN (9201, 9203)  -- Inpatient visits
```

---

## Standard Lookup Tables

### CONCEPT
**Purpose:** Master dictionary of all clinical concepts (diagnoses, drugs, procedures, measurements)

**Key columns:**
- `concept_id` - Unique identifier
- `concept_name` - Human-readable name
- `domain_id` - Category (Condition, Drug, Procedure, Measurement, etc.)
- `vocabulary_id` - Source (SNOMED, ICD10, RxNorm, LOINC, etc.)
- `concept_code` - Original code from source vocabulary
- `valid_start_date`, `valid_end_date` - Validity period

**Usage in picard (Find concept for a diagnosis):**
```sql
-- Find OMOP concept for Type 2 Diabetes
SELECT concept_id, concept_name, concept_code
FROM @cdmDatabaseSchema.concept
WHERE concept_name LIKE '%Type 2 Diabetes%'
  AND domain_id = 'Condition'
  AND valid_start_date <= GETDATE()
```

---

### CONCEPT_ANCESTOR
**Purpose:** Hierarchical relationships between concepts (parent-child)

**Key columns:**
- `ancestor_concept_id` - Parent concept (more general)
- `descendant_concept_id` - Child concept (more specific)
- `min_levels_of_separation` - Distance in hierarchy
- `max_levels_of_separation` - Maximum distance

**Why it matters:** Allows searching by concept hierarchy. A single diabetes code might have hundreds of descendants (different subtypes, complications).

**Usage in picard (Find all diabetes subtypes):**
```sql
-- Get all Type 2 Diabetes descendants (subtypes, complications)
SELECT DISTINCT descendant_concept_id
FROM @cdmDatabaseSchema.concept_ancestor
WHERE ancestor_concept_id = 201826  -- Type 2 Diabetes
  AND min_levels_of_separation > 0  -- Exclude the concept itself
```

---

## Key Relationships and Patterns

### Patient Timeline Pattern
```
PERSON
  ├─ OBSERVATION_PERIOD (when enrolled)
  │   ├─ VISIT_OCCURRENCE (healthcare visits)
  │   │   ├─ CONDITION_OCCURRENCE (diagnoses during visit)
  │   │   ├─ PROCEDURE_OCCURRENCE (procedures during visit)
  │   │   ├─ DRUG_EXPOSURE (medications prescribed)
  │   │   └─ MEASUREMENT (lab results)
  │   └─ DRUG_EXPOSURE (prescriptions without visit)
  └─ CONCEPT (lookups for all IDs)
```

### Cohort Definition Pattern (Picard approach)

```sql
-- Define index population
WITH base_population AS (
  SELECT DISTINCT person_id
  FROM @cdmDatabaseSchema.observation_period
  WHERE observation_period_start_date <= '@studyStart'
    AND observation_period_end_date >= '@studyEnd'
),

-- Find index event
index_event AS (
  SELECT 
    person_id,
    condition_start_date AS index_date
  FROM @cdmDatabaseSchema.condition_occurrence
  WHERE condition_concept_id IN (
    SELECT descendant_concept_id 
    FROM @cdmDatabaseSchema.concept_ancestor
    WHERE ancestor_concept_id = 201826  -- Type 2 Diabetes
  )
    AND condition_start_date >= '@studyStart'
),

-- Apply inclusion/exclusion
final_cohort AS (
  SELECT 
    person_id,
    index_date
  FROM index_event ie
  JOIN base_population bp ON ie.person_id = bp.person_id
  WHERE NOT EXISTS (
    -- Exclude: prior diabetes diagnosis
    SELECT 1 FROM @cdmDatabaseSchema.condition_occurrence co
    WHERE co.person_id = ie.person_id
      AND co.condition_start_date < ie.index_date
      AND co.condition_concept_id = 201826
  )
)

SELECT * FROM final_cohort
```

---

## Vocabulary and Coding Systems

### Common OMOP Vocabularies

| Vocabulary | Purpose | Example |
|-----------|---------|---------|
| **SNOMED** | Clinical concepts | 44054006 = Diabetes mellitus type 2 |
| **ICD10CM** | Diagnosis codes | E11 = Type 2 diabetes mellitus |
| **RxNorm** | Medication codes | 6809 = Metformin |
| **LOINC** | Lab test codes | 4547-4 = Hemoglobin A1C |
| **CPT4** | Procedure codes | 80053 = Comprehensive metabolic panel |

---

## Best Practices for SQL in Picard

### 1. Always Check Concept Hierarchies
```sql
-- ❌ WRONG: Hardcoding single concept
WHERE condition_concept_id = 201826

-- ✅ RIGHT: Using concept_ancestor to get all related concepts
WHERE condition_concept_id IN (
  SELECT descendant_concept_id FROM @cdmDatabaseSchema.concept_ancestor
  WHERE ancestor_concept_id = 201826
)
```

### 2. Use Observation Period for Inclusion
```sql
-- ✅ RIGHT: Ensure continuous observation
WHERE person_id IN (
  SELECT person_id FROM @cdmDatabaseSchema.observation_period
  WHERE observation_period_start_date <= '@studyStart'
    AND observation_period_end_date >= '@studyEnd'
)
```

### 3. Handle Date Calculations Carefully
```sql
-- ✅ Use DATEDIFF for reliable date arithmetic
SELECT 
  DATEDIFF(DAY, drug_exposure_start_date, drug_exposure_end_date) AS days_on_drug
FROM @cdmDatabaseSchema.drug_exposure

-- Handle NULL end dates (ongoing medications)
COALESCE(drug_exposure_end_date, GETDATE()) AS calculated_end_date
```

### 4. Join Efficiently
```sql
-- ✅ Use indexed columns (concept_ids usually indexed)
WHERE condition_concept_id IN (subquery)

-- ❌ AVOID: Joining to CONCEPT table on concept_name (slow)
WHERE c.concept_name LIKE '%diabetes%'
```

---

## Common Cohort Patterns

### Prevalence Cohort
Find all patients with a condition during a period
```sql
WHERE condition_concept_id = @conditionConceptId
  AND condition_start_date BETWEEN '@periodStart' AND '@periodEnd'
```

### Incident Cohort
Find patients with first-ever occurrence of a condition
```sql
WHERE condition_concept_id = @targetConcept
  AND NOT EXISTS (
    SELECT 1 FROM condition_occurrence prior
    WHERE prior.person_id = current.person_id
      AND prior.condition_start_date < current.condition_start_date
      AND prior.condition_concept_id = @targetConcept
  )
```

### Temporal Relationship
Find events happening before another event
```sql
WHERE drug_exposure_start_date < @indexDate
  AND drug_exposure_end_date >= DATE_SUB(@indexDate, INTERVAL 365 DAY)
```

---

## Troubleshooting Common Issues

### "No results from cohort generation"
- Check that concept IDs exist in your database (concept_ancestor might be empty)
- Verify observation periods cover the study dates
- Use `COUNT(DISTINCT person_id)` to debug each step

### "Duplicate records in results"
- Your join might not be constrained uniquely
- Use `DISTINCT` or add `ORDER BY` and `ROW_NUMBER()` logic
- Check if drug_exposure or condition_occurrence has multiple entries per person per date

### "Performance issues"
- Index concept_id columns
- Filter on indexed columns first (observation_period_start_date)
- Avoid expensive aggregations until data is pre-filtered

---

## Next Steps

When defining cohorts or writing SQL in picard:
1. Reference this document for OMOP table structure
2. Use concept_ancestor for hierarchical searches
3. Always enforce observation_period requirements
4. Test SQL incrementally (count distinct person_ids at each step)
5. See `.agent/reference-docs/03-loading-inputs.md` for cohort definition workflow
6. See `.agent/reference-docs/04-developing-pipeline.md` for SQL template examples

## External Resources

- **Official OMOP CDM Documentation:** https://ohdsi.github.io/CommonDataModel/cdm54.html
- **Vocabulary in CDM:** https://ohdsi.github.io/CommonDataModel/vocabulary.html
- **Standardized Vocabularies:** https://ohdsi.github.io/TheBookOfOhdsi/StandardizedVocabularies.html
