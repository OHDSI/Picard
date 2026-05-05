# Evidence Generation Plan

> **Note:** This vignette is currently in development and subject to
> change.

## Introduction

An *Evidence Generation Plan* (EGP) is a **required document** in the
Picard pipeline. It is a structured specification document that bridges
your research questions to your analysis code. The EGP defines the
analytical experiment in layman’s terms and **drives the pipeline**—your
code implements the specifications you document here.

It serves three critical purposes:

1.  **Precision:** Translates research questions into exact analytical
    specifications (numerators, denominators, observation windows,
    inclusion/exclusion logic)
2.  **Transparency:** Makes all choices explicit and justified, enabling
    others to understand and validate your approach  
3.  **Implementation:** Provides sufficient detail that programmers can
    implement your vision without ambiguity

**Key insight:** EGPs are NOT one-size-fits-all templates. They adapt
fundamentally based on study design:

- **Surveillance studies** (prevalence, incidence) emphasize observation
  periods, lookback windows, numerator/denominator specifications
  (example: Type 2 Diabetes prevalence)
- **Characterization studies** describe patient populations, baseline
  features, treatment patterns, temporal trends (example: Psoriasis
  patients)
- **Outcome studies** focus on exposure definitions, time-at-risk,
  outcome specifications
- **Treatment pathway studies** detail era logic, gap collapsing rules,
  sequence analysis

Note that the EGP file is automatically generated when you launch a
study. The template contains comments and guidance to help you fill in
the details.

This vignette teaches the principles of EGP construction and shows
examples from different study types. You’ll adapt the structure to match
your research questions.

## EGP as a Bridge Between Planning and Code

An EGP sits between your research vision and your Picard implementation:

    Research Questions
           ↓
      Evidence Generation Plan
      (translate to specifications)
           ↓
      Picard Code Implementation
      (analysis/tasks/ implement specs)
           ↓
      Results & Dissemination

Each element of your EGP should have a corresponding task in your
analysis pipeline. The EGP drives the code—every analytical decision in
the code should trace back to a specification in your EGP.

## Universal EGP Components

While structure varies by study type, most EGPs contain these sections:

- Background (Rationale, Research Questions, Data Sources)
- Cohort Definitions (structured by study design)
- Analysis Specifications (baseline characteristics, prevalence
  calculations, treatment pathways, etc.)

We go into more detail in the following sections, showing how to adapt
these components based on your study design.

### 1. Background

Establish context for your study.

**Always include:** - **Rationale:** Why does this study matter? -
**Research Questions:** What specific questions will you answer? -
**Data Sources:** Where does your data come from? Why that source?

Below we provide some examples of research questions for different study
types.

Example (Prevalence Study):

    ### Research Questions
    1. What is the annual crued and standardized prevalence of Type 2 Diabetes from 2015-2024?
    2. How do prevalence estimates vary by age and sex?
    3. What proportion of Type 2 Diabetes patients receive guideline-recommended medications?

Example (Characterization Study):

    ### Research Questions
    1. What are the demographics and baseline characteristics of patients newly diagnosed with Psoriasis?
    2. What procedures, measuremetns and symptoms occur among Psoriasis patients in the year after diagnosis?
    3. What are the most common treatments and treatment sequences among Psoriasis patients?

Example (Treatment Patterns Study):

    ### Research Questions
    1. What are treatment patterns among Psoriasis patients (topical, systemic, biologic)?
      a. What proportion of patients receive each treatment class?
      b. How long do patients remain on initial therapy before switching?
      c. What are common treatment sequences and combinations?

### 2. Cohort Definitions

Define your study populations and other important cohorts precisely. The
cohort definitions will have three main components:

- **Entry criteria:** How do patients enter the cohort?
- **Inclusion criteria:** What additional criteria must be met to stay
  in the cohort?
- **Exit criteria:** How do patients exit from the cohort (i.e censored
  by death or end of continuous observation)?

Here are a few examples of how cohort definitions can be structured
based on study design:

**Psoriasis Example**:

    ### Newly-Diagnosed Psoriasis Cohort

    #### Cohort Entry
    - First visit date with Psoriasis diagnosis code
    - Requirement: >= 2 Psoriasis diagnosis visits on different dates, 30-365 days apart
    - Requirement: 365 days continuous prior observation
    - Limit occurrence to the initial event per patient (first-ever diagnosis)

    #### Inclusion Criteria
    - NO prior psoriasis-related treatments in 365 days prior to index

    #### Cohort Exit
    - End of continuous observation, OR
    - Death

**Type 2 Diabetes Example**:

    ### Type 2 Diabetes Cohort

    #### Cohort Entry
    - 2 codes of Type 2 Diabetes on different dates, at least 30 days apart
    - the second code is the index date
    - Limit occurrence to the initial event per patient (first-ever diagnosis)

    #### Inclusion Criteria
    - NO occurrence of Type 1 Diabetes diagnosis code at any time prior to index date
    - NO occurrence of Gestational Diabetes diagnosis code at any time prior to index date

    #### Cohort Exit
    - End of continuous observation, OR
    - Death

A few guiding principles about defining cohort definitions in your EGP:

- The index date should be clearly defined. Typically the index date in
  a sequence of events is the second occurrence (to avoid immortal time
  bias).
- The index date should be the occurrence of a clinical event
  (diagnosis, procedure, medication dispensing) rather than an arbitrary
  date (calendar date, visit).
- Always provide temporal logic on sequence of events. For example if no
  prior treatment state either all time or some window relative to the
  index date
- Be explicit about whether you limit to first-ever occurrence or allow
  multiple occurrences per patient
- Clearly define exit criteria (death, end of observation) to ensure
  proper censoring in follow-up analyses
- **Programming tip:** Cohort definitions from Atlas come with a
  markdown format that be pasted into the EGP or you can clean up the
  format.

#### Codelists

Codelists are very important since the describe what codes define a
clinical concept. However codelists tend to be very long and hard to
read. Attach the codelist as an appendix or add a new tab in the study
hub with codelists.

The focus of the EGP should be on the logic of how the codes are used to
define cohorts and analyses, not on the specific codes themselves.

### 3. Analysis Specifications

This section varies greatly by study type. The keyprinciple: **Be
specific enough that a programmer can implement without guessing.** Want
to convey the experiment logic in a way that it is easy to codify the
experiment with a set of parameters.

Below are some examples of how to specify analyses for different study
types. Provide as much detail as possible about the analysis.

Prevalence Example:

    ### Prevalence Calculation: Any-Time Point Estimate

    **Period of Interest:** Each calendar year 2015-2024

    **Observation Requirements:**
    - Include: Anyone with >= 1 day enrollment in the year
    - Minimum continuous: None (any fragmented enrollment allowed)

    **Lookback:**
    - Search 365 days prior to period for any Type 2 Diabetes diagnosis

    **Numerator:**
    - Patients with Type 2 Diabetes diagnosis code prior to OR during period

    **Denominator:**
    - All patients with any enrollment during period of interest

    **Calculation:**
    Prevalence = (Numerator / Denominator) per 100,000

Characterization Example:

    ### Baseline Characteristics

    **Baseline Window:** 365 days prior to index date through 1 day prior

    **Demographics Reported:**
    - Age at index date
    - Sex, Race, Ethnicity
    - Payer type
    - Calendar year of index

    **Comorbidities:**
    - Report any diagnosis code during baseline window for:
      - Autoimmune/Inflammatory conditions (Rheumatoid arthritis, Crohn's disease, etc.)
      - Cardiovascular disease
      - Metabolic disease (Diabetes, Obesity)
      - [Organized by clinical system]

    **Treatments:**
    - Any dispensing during baseline window for:
      - Topical agents (corticosteroids, calcineurin inhibitors, retinoids)
      - Systemic agents (methotrexate, acitretin, cyclosporine, apremilast)
      - Biologic agents (TNF inhibitors, IL-17i, IL-23i, JAK inhibitors)
      - Other (phototherapy, oral steroids)

    ### Treatment Pathways During Follow-up

    **Gap Collapsing Rules:**
    - Topical agents: Collapse gaps of <30 days
    - Systemic agents: Collapse gaps of <30-60 days depending on agent
    - Biologic agents: Collapse gaps of <60-120 days depending on specific drug

    **Combination Logic:**
    - Different drug classes overlapping >= 60 days = counted as combination therapy

    **Episode Minimum:**
    - Episodes of <14 days are excluded (too short to assess effectiveness)

    **Output:**
    - Sunburst plot showing first 4 treatment steps in newly-diagnosed population
    - Table: Median days on treatment by therapy class and line number

## Linking EGP to Picard Implementation

Each major section of your EGP should correspond to at least one
analysis task:

    EGP Section                 →  Ulysses Structure
    ─────────────────────────────────────────
    Cohort Definitions         →  inputs/cohorts/
    Baseline Characteristics   →  analysis/task/01_descriptiveStats.R
    Prevalence/Surveillance    →  analysis/task/02_prevalenceAnalysis.R
    Post-Index Follow-up       →  analysis/task/03_followupCharacterization.R
    Treatment Pathways         →  analysis/task/04_treatmentPathways.R

It may be helpful to include this mapping as an appendix to your EGP to
ensure that all specifications are implemented in code and to facilitate
traceability between the document and the implementation.

## Versioning Your EGP

Keep a changelog as your study evolves. This should be placed at the end
of the file. Here is an example

    ## Version 1.1 (2026-04-15)

    ### Changes from v1.0
    - Extended follow-up from 3 to 5 years (additional funding)
    - Added secondary outcome: CKD progression
    - Expanded age subgroups from 3 to 5 categories

    ### Rationale
    Stakeholder feedback requested longer follow-up for stability; 
    clinical team identified CKD progression as important secondary endpoint.

## Example: Complete Minimal EGP

For a quick reference, here’s a minimal EGP template:

``` markdown
# Evidence Generation Plan: [Study Name]

## Background

### Rationale
[1-2 sentences: Why does this study matter?]

### Research Questions
1. [First question]
2. [Second question]

### Data Sources
[Database name], [coverage period], [size], [type of data]

## Cohort Definitions

### Base Population
- Entry criteria: [How patients enter]
- Inclusion: [Who stays in]
- Exclusion: [Who gets excluded]

## Analysis

### Primary Analysis
[What is measured, how, when]

### Secondary/Subgroup Analysis  
[Optional: stratifications or sensitivity tests]

### Output
[What gets delivered - tables, figures, dataframes]

## Version
[Version number, date, and change log]
```

## See Also

- [The Ulysses Standard Repository
  Structure](https://ohdsi.github.io/Picard/dev/articles/picard_repository_structure.md) -
  Where EGP fits
- [Launching a
  Study](https://ohdsi.github.io/Picard/dev/articles/launching_a_study.md) -
  Study setup
- [Developing the
  Pipeline](https://ohdsi.github.io/Picard/dev/articles/developing_the_pipeline.md) -
  Implementing EGP as code
- [Running the
  Pipeline](https://ohdsi.github.io/Picard/dev/articles/running_the_pipeline.md) -
  Executing analyses defined in EGP
- [Post-Processing
  Steps](https://ohdsi.github.io/Picard/dev/articles/post_processing.md) -
  Converting EGP outputs to deliverables
