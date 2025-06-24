Barista [under development]
=====

[![Build Status](https://github.com/OHDSI/Barista/workflows/R-CMD-check/badge.svg)](https://github.com/OHDSI/Barista/actions?query=workflow%3AR-CMD-check) [![codecov.io](https://codecov.io/github/OHDSI/Barista/coverage.svg?branch=develop)](https://app.codecov.io/github/OHDSI/Barista?branch=develop)

# Introduction

The purpose of Barista is to provide a streamlined, standard way to create and manage all of the study assets needed throughout the life of an observational study conducted using RWD transformed into the OMOP Common Data Model and OHDSI tools.

# Features

## Manifests

In prior OHDSI studies, researchers have built cohort and concept set manifests to track all of the assets in a study. In this context, a manifest is merely a table of all of the assets and their metadata needed for the study.

Each manifest was manually maintained in a CSV file, and brought organization and transparency improvements.

However, the manual edits to the CSV needed were challenging as a study lead, and the id management was cumbersome to maintain accurately.

### SQLite-based manifests

To avoid manual CSV edits, Barista is built upon a Sqlite manifest system. This allows us to track concept sets, cohorts, files, analyses, and tags in a robust manner.

As the database is SQLite, the object can be stored on disk without any setup, and it can be tracked in version control (e.g. Git).

### Automatic generation of ids

Based upon prior studies, we have observed that ids for cohorts and concept sets are largely arbitrary - they just need to be consistent and unique.

Therefore, Barista uses the built-in benefits of a SQLite database to automatically generated ids for each manifest table. 

This means that you can add new items to the manifest without worrying about id management, and the ids will be unique and consistent.

### Ulysses lifecycle

Barista is built to support the Ulysses lifecycle, which is a set of best practices for managing RWD studies. This includes the idea of analysis tasks, migration tasks, and dissemination tasks to support a very linear lifecycle of a study.

### CohortGenerator integration

For cohorts, Barista integrates with the CohortGenerator package by producing a Cohort Definition Set that then can be leveraged by CohortGenerator's functions.

### Tagging

With observational studies, we often have many versions of concept sets and cohort definitions, either due to ongoing development work, or due to the specific needs of endpoints within a study. 

To ensure that all of the metadata for a given manifest item is tracked and transparent, Barista offers a TagManifest, which can be used to create a 1-to-many relationship of a manifest item to tag values.

# Example

``` r
# First construct a ManifestDb object

Barista::createManifestDb(
  dbPath = "/path/to/manifestdb.sqlite"
)

# Create a Concept Set Manifest Item

thisConceptSetItem <- Barista::createConceptSetManifestItem(
  name = "My Concept Set",
  provenanceId = "123", # this is the id of the concept set as it existed in Atlas
  designMethod = "Atlas",
  relativeJsonPath = "path/to/thisConceptSet.json"
)

# Add it to the Concept Set Manifest

Barista::addConceptSetManifestItem(
  manifestDb = manifestDb,
  conceptSetManifestItem = thisConceptSetItem
)

# Create a Cohort Manifest Item based on a JSON definition

thisCohortItem <- Barista::createCohortManifestItem(
  name = "My Cohort",
  provenanceId = "456", # this is the id of the cohort as it existed in Atlas
  designMethod = "Atlas",
  relativeJsonPath = "path/to/thisCohort.json"
)

# Add it to the Cohort Manifest

Barista::addCohortManifestItem(
  manifestDb = manifestDb,
  cohortManifestItem = thisCohortItem
)

# View the Cohort Definition Set 

Barista::viewCohortDefinitionSet(
  manifestDb = manifestDb
)

# Add a tag to the Cohort Manifest Item
Barista::addTagToCohortManifestItem(
  manifestDb = manifestDb,
  cohortId = 1,
  tagName = "QC Status",
  tagValue = "Complete"
)
```

# Technology

Barista is an R package.

# System requirements

Requires R (version 4.2.3 or higher).

# Getting Started

1.  Make sure your R environment is properly configured. This means that Java must be installed. See [these instructions](https://ohdsi.github.io/Hades/rSetup.html) for how to configure your R environment.

2.  In R, use the following commands to download and install Barista:

    ``` r
    remotes::install_github("OHDSI/Barista", ref = "develop")
    ```

# User Documentation

<!--
Documentation can be found on the [package website](https://ohdsi.github.io/Barista/).

PDF versions of the documentation are also available:

-   Vignette: [Using Barista](https://raw.githubusercontent.com/OHDSI/Barista/develop/inst/doc/UsingBarista.pdf)
-   Package manual: [Barista.pdf](https://raw.githubusercontent.com/OHDSI/Barista/develop/extras/Barista.pdf)
!-->

# Support

-   Developer questions/comments/feedback: <a href="http://forums.ohdsi.org/c/developers">OHDSI Forum</a>
-   We use the <a href="https://github.com/OHDSI/Barista/issues">GitHub issue tracker</a> for all bugs/issues/enhancements

# Contributing

Please add feature requests in the Github issue tracker. If you want to contribute code, please fork the repository and submit a pull request towards the `develop` branch.

# License

Barista is licensed under Apache License 2.0

# Development

This package is being developed in RStudio.

### Development status

Beta
