# picard 0.0.3

- add more support for dependent cohorts
    - union collapse to make erafied events
    - composite cohorts to make a cohort on collection of criteria
    - improve subset cohorts
    - add demographic and strata cohorts
- support for custom cohort sql 
- improve cm mid-cycle work
    - review manifest state
    - sync manifest match files to sqlite
    - delete old manifest entries
    - prune cohorts from cohort table 
- fix bugs in cohort and concept set manifests
- fix bugs in task caching
- add test mode to postProcess step
- distinguish cohort table by test mode

# picard 0.0.2

- Split production and test mode for pipeline runs
- Add better vignettes for using picard
- bug fixes
- add agent mode to picard
- add keyring compatability to setAtlasConnection


# picard 0.0.1

## New Features

### Core Study Management
- **UlyssesStudy**: R6 class for comprehensive study repository configuration and initialization
- **StudyMeta**: Metadata container for study information including title, therapeutic area, type, contributors, tags, and links
- **ExecutionSettings**: Configuration class for managing execution environment and database connections
- **ExecOptions**: Settings and database connection block management

### Study Repository Initialization
- Automatic R project creation and configuration
- Git repository initialization with remote support
- Standard directory structure creation for study artifacts
- README, NEWS, and configuration file templating
- Quarto documentation setup integration
- Agent skills configuration for repository automation

### Cohort Management
- **CohortDef**: R6 class for defining cohorts with ATLAS specifications
- **CohortManifest**: Management system for cohort collection with validation
- Cohort JSON and SQL file organization
- ATLAS cohort import and integration

### Concept Set Management
- **ConceptSetDef**: R6 class for defining concept sets
- **ConceptSetManifest**: Management system for concept set collections
- Concept set JSON file organization
- ATLAS concept set import and integration

### Study Execution
- Study pipeline orchestration and execution
- Task-based execution framework with status tracking
- Pipeline export functionality
- Result validation and cohort comparison tools

### Data Processing
- Cohort building with temporal and demographic subsetting
- Union and complement cohort operations
- Dissemination data preparation
- Standard data type handling and formatting
- Column name standardization

### Configuration & Integration
- **DbConfigBlock**: Database connection configuration for multiple databases
- DBMS-specific settings (CDM schema, working schema, temp schema)
- Configuration file generation and management
- ATLAS connection setup
- Contributor and team management

### Utilities
- Repository validation framework
- Task history and execution tracking
- Environment hash detection for dependency tracking
- File and directory management utilities
- Archive and export functionality

