# Zip and Archive results from a study execution

Zip and Archive results from a study execution

## Usage

``` r
zipAndArchive(input)
```

## Arguments

- input:

  the type of files to zip and archive. There are three options
  exportMerge, exportPretty and site. exportMerge is the merged results
  in long format. The exportPretty are xlsx files with formatted output
  from the study. The site is the html files of the studyHub

## Value

invisible return. Stores the input as a zip file in the exec/archive
folder
