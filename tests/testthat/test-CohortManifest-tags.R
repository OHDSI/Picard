# ============================================================================
# Tag Manipulation Tests
# ============================================================================

# Testing: addCohortTag adds a new tag to a cohort without destroying existing tags
testthat::test_that("addCohortTag adds tag non-destructively", {
  setup <- cm_test_seed_manifest_for_queries("tags-add-nondestructive")
  manifest <- setup$manifest

  row <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")
  cohort_id <- as.integer(row$id[[1]])

  # Add initial tag
  manifest$addCohortTag(cohort_id, "status", "active")
  tags_v1 <- manifest$getCohortTags(cohort_id)
  testthat::expect_equal(tags_v1$status, "active")

  # Add another tag without destroying the first
  manifest$addCohortTag(cohort_id, "owner", "alice")
  tags_v2 <- manifest$getCohortTags(cohort_id)

  testthat::expect_equal(tags_v2$status, "active")
  testthat::expect_equal(tags_v2$owner, "alice")
})

# Testing: getCohortTags retrieves all tags for a cohort
testthat::test_that("getCohortTags returns all tags as named list", {
  setup <- cm_test_seed_manifest_for_queries("tags-get-all")
  manifest <- setup$manifest

  row <- manifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")
  cohort_id <- as.integer(row$id[[1]])

  manifest$addCohortTag(cohort_id, "qa_date", "2026-07-15")
  manifest$addCohortTag(cohort_id, "validation_needed", "FALSE")

  tags <- manifest$getCohortTags(cohort_id)

  testthat::expect_is(tags, "list")
  testthat::expect_equal(tags$qa_date, "2026-07-15")
  testthat::expect_equal(tags$validation_needed, "FALSE")
})

# Testing: removeCohortTag removes a specific tag
testthat::test_that("removeCohortTag removes tag without affecting others", {
  setup <- cm_test_seed_manifest_for_queries("tags-remove")
  manifest <- setup$manifest

  row <- manifest$queryCohortsByLabel("All-Cause Death", matchType = "exact")
  cohort_id <- as.integer(row$id[[1]])

  # Add multiple tags
  manifest$addCohortTag(cohort_id, "qa_date", "2026-07-15")
  manifest$addCohortTag(cohort_id, "owner", "bob")
  manifest$addCohortTag(cohort_id, "status", "approved")

  # Remove one tag
  manifest$removeCohortTag(cohort_id, "qa_date")
  tags <- manifest$getCohortTags(cohort_id)

  testthat::expect_false("qa_date" %in% names(tags))
  testthat::expect_equal(tags$owner, "bob")
  testthat::expect_equal(tags$status, "approved")
})

# Testing: modifyCohortTagValue updates an existing tag value
testthat::test_that("modifyCohortTagValue updates tag value", {
  setup <- cm_test_seed_manifest_for_queries("tags-modify-value")
  manifest <- setup$manifest

  row <- manifest$queryCohortsByLabel("Major Bleeding Outcome", matchType = "exact")
  cohort_id <- as.integer(row$id[[1]])

  manifest$addCohortTag(cohort_id, "status", "pending")
  manifest$modifyCohortTagValue(cohort_id, "status", "approved")

  tags <- manifest$getCohortTags(cohort_id)
  testthat::expect_equal(tags$status, "approved")
})

# Testing: getTagValue retrieves a single tag value
testthat::test_that("getTagValue returns single tag value", {
  setup <- cm_test_seed_manifest_for_queries("tags-get-value")
  manifest <- setup$manifest

  row <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")
  cohort_id <- as.integer(row$id[[1]])

  manifest$addCohortTag(cohort_id, "owner", "charlie")
  value <- manifest$getTagValue(cohort_id, "owner")

  testthat::expect_equal(value, "charlie")
})

# Testing: mergeTagsIntoCohort additively merges new tags without destroying existing
testthat::test_that("mergeTagsIntoCohort merges tags additively", {
  setup <- cm_test_seed_manifest_for_queries("tags-merge")
  manifest <- setup$manifest

  row <- manifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")
  cohort_id <- as.integer(row$id[[1]])

  manifest$addCohortTag(cohort_id, "status", "active")
  manifest$addCohortTag(cohort_id, "owner", "alice")

  # Merge in new tags
  manifest$mergeTagsIntoCohort(cohort_id, list(
    qa_date = "2026-07-15",
    validation_needed = "TRUE"
  ))

  tags <- manifest$getCohortTags(cohort_id)

  testthat::expect_equal(tags$status, "active")
  testthat::expect_equal(tags$owner, "alice")
  testthat::expect_equal(tags$qa_date, "2026-07-15")
  testthat::expect_equal(tags$validation_needed, "TRUE")
})

# Testing: renameTagKey renames a tag key across all specified or all cohorts
testthat::test_that("renameTagKey renames tag across cohorts", {
  setup <- cm_test_seed_manifest_for_queries("tags-rename-key")
  manifest <- setup$manifest

  # Add tag to multiple cohorts
  ckd <- manifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")
  t2d <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")

  ckd_id <- as.integer(ckd$id[[1]])
  t2d_id <- as.integer(t2d$id[[1]])

  manifest$addCohortTag(ckd_id, "old_name", "value1")
  manifest$addCohortTag(t2d_id, "old_name", "value2")

  # Rename the tag
  result <- manifest$renameTagKey("old_name", "new_name", cohortIds = c(ckd_id, t2d_id))

  ckd_tags <- manifest$getCohortTags(ckd_id)
  t2d_tags <- manifest$getCohortTags(t2d_id)

  testthat::expect_false("old_name" %in% names(ckd_tags))
  testthat::expect_equal(ckd_tags$new_name, "value1")
  testthat::expect_false("old_name" %in% names(t2d_tags))
  testthat::expect_equal(t2d_tags$new_name, "value2")
})

# Testing: bulkModifyTagValue updates tag value across matching cohorts
testthat::test_that("bulkModifyTagValue updates matching tag values", {
  setup <- cm_test_seed_manifest_for_queries("tags-bulk-modify")
  manifest <- setup$manifest

  # Set up cohorts with matching tags
  ckd <- manifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")
  t2d <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")
  acd <- manifest$queryCohortsByLabel("All-Cause Death", matchType = "exact")

  ckd_id <- as.integer(ckd$id[[1]])
  t2d_id <- as.integer(t2d$id[[1]])
  acd_id <- as.integer(acd$id[[1]])

  manifest$addCohortTag(ckd_id, "status", "pending")
  manifest$addCohortTag(t2d_id, "status", "pending")
  manifest$addCohortTag(acd_id, "status", "approved")

  # Bulk modify pending to approved
  result <- manifest$bulkModifyTagValue("status", "pending", "approved")

  ckd_tags <- manifest$getCohortTags(ckd_id)
  t2d_tags <- manifest$getCohortTags(t2d_id)
  acd_tags <- manifest$getCohortTags(acd_id)

  testthat::expect_equal(ckd_tags$status, "approved")
  testthat::expect_equal(t2d_tags$status, "approved")
  testthat::expect_equal(acd_tags$status, "approved")
})

# Testing: listAllUniqueTags returns all unique tag names across manifest
testthat::test_that("listAllUniqueTags returns sorted unique tag names", {
  setup <- cm_test_seed_manifest_for_queries("tags-list-unique")
  manifest <- setup$manifest

  ckd <- manifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")
  t2d <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")

  ckd_id <- as.integer(ckd$id[[1]])
  t2d_id <- as.integer(t2d$id[[1]])

  manifest$addCohortTag(ckd_id, "zebra", "z_value")
  manifest$addCohortTag(ckd_id, "alpha", "a_value")
  manifest$addCohortTag(t2d_id, "beta", "b_value")

  unique_tags <- manifest$listAllUniqueTags()

  testthat::expect_true("alpha" %in% unique_tags)
  testthat::expect_true("beta" %in% unique_tags)
  testthat::expect_true("zebra" %in% unique_tags)
  # Verify sorted
  testthat::expect_equal(unique_tags, sort(unique_tags))
})

# ============================================================================
# Tag Query Tests
# ============================================================================

# Testing: queryCohortsMissingTag returns cohorts without a specific tag
testthat::test_that("queryCohortsMissingTag finds cohorts lacking tag", {
  setup <- cm_test_seed_manifest_for_queries("tags-query-missing")
  manifest <- setup$manifest

  ckd <- manifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")
  t2d <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")

  ckd_id <- as.integer(ckd$id[[1]])

  # Add tag only to CKD
  manifest$addCohortTag(ckd_id, "qa_complete", "TRUE")

  # Query for cohorts missing the tag
  missing <- manifest$queryCohortsMissingTag("qa_complete")

  testthat::expect_s3_class(missing, "tbl_df")
  testthat::expect_false(any(missing$id == ckd_id))
  testthat::expect_true(any(missing$id == as.integer(t2d$id[[1]])))
})

# Testing: queryCohortsWithTagValues supports cleaner named list syntax for multi-tag queries
testthat::test_that("queryCohortsWithTagValues uses cleaner syntax", {
  setup <- cm_test_seed_manifest_for_queries("tags-query-with-values")
  manifest <- setup$manifest

  ckd <- manifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")
  t2d <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")

  ckd_id <- as.integer(ckd$id[[1]])
  t2d_id <- as.integer(t2d$id[[1]])

  manifest$addCohortTag(ckd_id, "status", "approved")
  manifest$addCohortTag(ckd_id, "owner", "alice")
  manifest$addCohortTag(t2d_id, "status", "approved")
  manifest$addCohortTag(t2d_id, "owner", "bob")

  # Query with named list (cleaner syntax)
  result <- manifest$queryCohortsWithTagValues(list(status = "approved", owner = "alice"))

  testthat::expect_s3_class(result, "tbl_df")
  testthat::expect_equal(nrow(result), 1)
  testthat::expect_equal(result$label[[1]], "Chronic Kidney Disease")
})

# Testing: getTagValuesSummary returns value frequency summary with counts
testthat::test_that("getTagValuesSummary summarizes tag value frequency", {
  setup <- cm_test_seed_manifest_for_queries("tags-query-summary")
  manifest <- setup$manifest

  ckd <- manifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")
  t2d <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")
  acd <- manifest$queryCohortsByLabel("All-Cause Death", matchType = "exact")

  ckd_id <- as.integer(ckd$id[[1]])
  t2d_id <- as.integer(t2d$id[[1]])
  acd_id <- as.integer(acd$id[[1]])

  # Create a distribution of status values
  manifest$addCohortTag(ckd_id, "status", "approved")
  manifest$addCohortTag(t2d_id, "status", "approved")
  manifest$addCohortTag(acd_id, "status", "pending")

  summary <- manifest$getTagValuesSummary("status")

  testthat::expect_s3_class(summary, "tbl_df")
  testthat::expect_equal(nrow(summary), 2)
  testthat::expect_equal(names(summary), c("value", "count", "cohorts"))

  # Verify counts
  approved_row <- summary[summary$value == "approved", ]
  pending_row <- summary[summary$value == "pending", ]

  testthat::expect_equal(approved_row$count[[1]], 2)
  testthat::expect_equal(pending_row$count[[1]], 1)
})

# Testing: queryCohortsByTagName finds cohorts with a specific tag name
testthat::test_that("queryCohortsByTagName finds cohorts with tag name", {
  setup <- cm_test_seed_manifest_for_queries("tags-query-by-name")
  manifest <- setup$manifest

  ckd <- manifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")
  ckd_id <- as.integer(ckd$id[[1]])

  manifest$addCohortTag(ckd_id, "my_custom_tag", "custom_value")

  result <- manifest$queryCohortsByTagName("my_custom_tag")

  testthat::expect_s3_class(result, "tbl_df")
  testthat::expect_true(any(result$id == ckd_id))
})

# ============================================================================
# Tag Update Tests
# ============================================================================

# Testing: updateCohortTags replaces all tags for a cohort
testthat::test_that("updateCohortTags replaces all tags", {
  setup <- cm_test_seed_manifest_for_queries("tags-update-all")
  manifest <- setup$manifest

  row <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")
  cohort_id <- as.integer(row$id[[1]])

  # Add initial tags
  manifest$addCohortTag(cohort_id, "status", "pending")
  manifest$addCohortTag(cohort_id, "owner", "alice")

  # Replace all tags
  manifest$updateCohortTags(cohort_id, list(
    status = "approved",
    qa_date = "2026-07-15"
  ))

  tags <- manifest$getCohortTags(cohort_id)

  testthat::expect_equal(tags$status, "approved")
  testthat::expect_equal(tags$qa_date, "2026-07-15")
  testthat::expect_false("owner" %in% names(tags))
})

# ============================================================================
# Edge Cases and Error Handling
# ============================================================================

# Testing: getCohortTags returns NULL for non-existent cohort
testthat::test_that("getCohortTags returns NULL for non-existent cohort", {
  setup <- cm_test_seed_manifest_for_queries("tags-edge-null")
  manifest <- setup$manifest

  result <- manifest$getCohortTags(99999L)

  testthat::expect_null(result)
})

# Testing: getTagValue returns NULL when tag name doesn't exist
testthat::test_that("getTagValue returns NULL for missing tag", {
  setup <- cm_test_seed_manifest_for_queries("tags-edge-missing-tag")
  manifest <- setup$manifest

  row <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")
  cohort_id <- as.integer(row$id[[1]])

  result <- manifest$getTagValue(cohort_id, "nonexistent_tag")

  testthat::expect_null(result)
})

# Testing: removeCohortTag returns invisibly when tag doesn't exist
testthat::test_that("removeCohortTag handles missing tag gracefully", {
  setup <- cm_test_seed_manifest_for_queries("tags-edge-remove-missing")
  manifest <- setup$manifest

  row <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")
  cohort_id <- as.integer(row$id[[1]])

  # Should not error
  testthat::expect_invisible(manifest$removeCohortTag(cohort_id, "nonexistent_tag"))
})

# Testing: queryCohortsMissingTag returns NULL when all have tag
testthat::test_that("queryCohortsMissingTag returns NULL when all have tag", {
  setup <- cm_test_seed_manifest_for_queries("tags-edge-all-have")
  manifest <- setup$manifest

  # Tag all cohorts with a specific tag
  for (cohort in manifest$getManifest()) {
    manifest$addCohortTag(cohort$getId(), "universal_tag", "value")
  }

  result <- manifest$queryCohortsMissingTag("universal_tag")

  testthat::expect_null(result)
})

# Testing: modifyTagValue errors when tag doesn't exist
testthat::test_that("modifyTagValue errors for non-existent tag", {
  setup <- cm_test_seed_manifest_for_queries("tags-edge-modify-error")
  manifest <- setup$manifest

  row <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")
  cohort_id <- as.integer(row$id[[1]])

  testthat::expect_error(
    manifest$modifyCohortTagValue(cohort_id, "nonexistent_tag", "new_value")
  )
})

# ============================================================================
# Integration Tests: Complex Workflows
# ============================================================================

# Testing: Complete tag lifecycle workflow
testthat::test_that("Complete tag lifecycle workflow", {
  setup <- cm_test_seed_manifest_for_queries("tags-workflow-lifecycle")
  manifest <- setup$manifest

  row <- manifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")
  cohort_id <- as.integer(row$id[[1]])

  # 1. Add tags for QA workflow
  manifest$addCohortTag(cohort_id, "status", "qa_pending")
  manifest$addCohortTag(cohort_id, "qa_reviewer", "alice")
  manifest$addCohortTag(cohort_id, "qa_date", "2026-07-10")

  # 2. Verify tags were added
  tags_v1 <- manifest$getCohortTags(cohort_id)
  testthat::expect_equal(tags_v1$status, "qa_pending")

  # 3. Query by tag
  qa_cohorts <- manifest$queryCohortsByTagName("qa_reviewer")
  testthat::expect_true(any(qa_cohorts$id == cohort_id))

  # 4. Update status after QA approval
  manifest$modifyCohortTagValue(cohort_id, "status", "qa_approved")

  # 5. Verify update and check with query
  query_result <- manifest$queryCohortsWithTagValues(list(status = "qa_approved", qa_reviewer = "alice"))
  testthat::expect_equal(nrow(query_result), 1)
  testthat::expect_equal(query_result$id[[1]], cohort_id)

  # 6. Get summary of status values
  summary <- manifest$getTagValuesSummary("status")
  testthat::expect_true(any(summary$value == "qa_approved"))
})

# Testing: Tag discovery and audit workflow
testthat::test_that("Tag discovery and audit workflow", {
  setup <- cm_test_seed_manifest_for_queries("tags-workflow-audit")
  manifest <- setup$manifest

  ckd <- manifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")
  t2d <- manifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")
  acd <- manifest$queryCohortsByLabel("All-Cause Death", matchType = "exact")

  ckd_id <- as.integer(ckd$id[[1]])
  t2d_id <- as.integer(t2d$id[[1]])
  acd_id <- as.integer(acd$id[[1]])

  # 1. Add metadata tags to some cohorts
  manifest$addCohortTag(ckd_id, "enumeration_checked", "TRUE")
  manifest$addCohortTag(t2d_id, "enumeration_checked", "TRUE")

  # 2. Find cohorts missing the tag (gaps in quality)
  missing_enum <- manifest$queryCohortsMissingTag("enumeration_checked")
  testthat::expect_true(any(missing_enum$id == acd_id))
  testthat::expect_false(any(missing_enum$id == ckd_id))

  # 3. Get list of all tags in use
  all_tags <- manifest$listAllUniqueTags()
  testthat::expect_true("enumeration_checked" %in% all_tags)

  # 4. Get summary of enumeration values
  enum_summary <- manifest$getTagValuesSummary("enumeration_checked")
  testthat::expect_equal(nrow(enum_summary), 1)
  testthat::expect_equal(enum_summary$count[[1]], 2)
})
