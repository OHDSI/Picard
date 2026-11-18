# Create a Dissemination Script Template

Creates a new R script template in the dissemination scripts directory
(`dissemination/pretty/R/`) for formatting and preparing merged study
results for dissemination (Excel export, StudyHub, etc.). Multiple
dissemination scripts can be created with automatic numbering (01\_,
02\_, etc.) to determine execution order.

## Usage

``` r
makeDisseminationScript(
  name = "format_results",
  projectPath = here::here(),
  open = TRUE
)
```

## Arguments

- name:

  Character. Name/description of the dissemination script purpose (e.g.,
  "format_results", "excel_export", "studyhub_upload"). Will be
  converted to snake_case. Defaults to "format_results" if not
  specified.

- projectPath:

  Character. Path to the project root directory. Defaults to
  [`here::here()`](https://here.r-lib.org/reference/here.html).

- open:

  Logical. If TRUE (default), opens the created script in RStudio editor
  for immediate editing.

## Value

Invisibly returns the template content as a character string.

## Details

The template is created with automatic numbering in
`dissemination/pretty/R/` (e.g., 01_format_results.R, 02_excel_export.R,
03_studyhub_upload.R) to determine execution order when
[`sourceDisseminationScripts`](https://ohdsi.github.io/Picard/reference/sourceDisseminationScripts.md)
is called.

Each template demonstrates:

- Loading merged results from postprocessing

- Applying standard formatting via
  [`prepareDisseminationData`](https://ohdsi.github.io/Picard/reference/prepareDisseminationData.md)

- Creating formatted outputs (CSV, Excel, etc.)

- Pivoting for cross-database comparison

- Filtering and subset creation

- StudyHub format examples

Users edit each script to customize their specific dissemination needs,
then execute them all via
[`sourceDisseminationScripts`](https://ohdsi.github.io/Picard/reference/sourceDisseminationScripts.md).

## Examples

``` r
if (FALSE) { # \dontrun{
# Create first dissemination script for basic formatting
makeDisseminationScript(name = "format_results")

# Create second script for Excel export
makeDisseminationScript(name = "excel_export")

# Create with default name
makeDisseminationScript()
} # }
```
