# {fileName}

# A. Meta Info ----

# Study: <<studyName>>
# Author: <<author>>
# Date: <<lubridate::today()>>
# Description: <<description>>

# B. Functions ----

# GUIDANCE: Treat source files like R package development
# - Use package::function() notation instead of library() calls
#   Example: dplyr::mutate() instead of loading dplyr
# - Document what each function does with a clear comment block
#   This helps teammates understand the purpose at a glance
# - Keep functions focused and reusable across multiple tasks

# Example function with documentation:
# Purpose: Calculate age in years from birth date
# Inputs: birth_date (Date or character in YYYY-MM-DD format)
# Returns: Numeric age in years
my_example_function <- function(birth_date) {
  # Convert to date if character
  birth_date <- as.Date(birth_date)
  
  # Calculate age using lubridate
  age <- as.numeric(lubridate::interval(birth_date, Sys.Date()), "years")
  rr <- floor(age)
  return(rr)
}

# Add your functions below, following the same pattern:
# Clear comment block describing purpose, inputs, and returns
# Use package::function() notation for external packages
