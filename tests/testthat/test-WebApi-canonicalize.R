# Purpose: Build a concept set item shaped like the JSON ATLAS returns.
wa_test_item <- function(conceptId, excluded = FALSE, descendants = TRUE) {
  list(
    concept = list(
      CONCEPT_ID = conceptId,
      CONCEPT_NAME = paste("concept", conceptId),
      VOCABULARY_ID = "SNOMED",
      CONCEPT_CODE = as.character(conceptId)
    ),
    isExcluded = excluded,
    includeDescendants = descendants,
    includeMapped = FALSE
  )
}

# Purpose: Pull the CONCEPT_IDs out of a canonicalized expression, in order.
wa_test_concept_ids <- function(expression) {
  vapply(expression$items, function(item) as.numeric(item$concept$CONCEPT_ID), numeric(1))
}

# Testing: concept set items are ordered by CONCEPT_ID regardless of the order
# ATLAS returned them in (issue #84).
testthat::test_that("canonicalize_concept_set_expression sorts items by CONCEPT_ID", {
  expression <- list(items = list(
    wa_test_item(443238),
    wa_test_item(201826),
    wa_test_item(4193704)
  ))

  out <- canonicalize_concept_set_expression(expression)

  testthat::expect_equal(wa_test_concept_ids(out), c(201826, 443238, 4193704))
})

# Testing: any permutation of the same items canonicalizes to the same JSON, so
# the on-disk file and its content hash stay stable across ATLAS fetches.
testthat::test_that("canonicalize_concept_set_expression is order-invariant", {
  items <- list(wa_test_item(443238), wa_test_item(201826), wa_test_item(4193704))

  serialize <- function(order) {
    RJSONIO::toJSON(
      canonicalize_concept_set_expression(list(items = items[order])),
      digits = 23,
      pretty = TRUE
    )
  }

  permutations <- list(c(1, 2, 3), c(3, 2, 1), c(2, 1, 3), c(2, 3, 1))
  serialized <- vapply(permutations, serialize, character(1))

  testthat::expect_equal(length(unique(serialized)), 1)
  testthat::expect_equal(
    rlang::hash(serialized[[1]]),
    rlang::hash(serialized[[length(serialized)]])
  )
})

# Testing: items sharing a CONCEPT_ID but differing in inclusion flags still get a
# deterministic order, and no item is dropped.
testthat::test_that("canonicalize_concept_set_expression keeps every item", {
  items <- list(
    wa_test_item(201826, excluded = TRUE),
    wa_test_item(201826, excluded = FALSE),
    wa_test_item(201826, excluded = FALSE, descendants = FALSE)
  )

  first <- canonicalize_concept_set_expression(list(items = items))
  second <- canonicalize_concept_set_expression(list(items = rev(items)))

  testthat::expect_equal(length(first$items), 3)
  testthat::expect_equal(first$items, second$items)
})

# Testing: non-item elements of the expression are left untouched.
testthat::test_that("canonicalize_concept_set_expression preserves other fields", {
  expression <- list(
    items = list(wa_test_item(443238), wa_test_item(201826)),
    extra = "keep me"
  )

  out <- canonicalize_concept_set_expression(expression)

  testthat::expect_equal(out$extra, "keep me")
  testthat::expect_equal(names(out), names(expression))
})

# Testing: expressions with no items, or a single item, pass through unchanged.
testthat::test_that("canonicalize_concept_set_expression tolerates empty expressions", {
  testthat::expect_equal(
    canonicalize_concept_set_expression(list(items = list())),
    list(items = list())
  )
  testthat::expect_equal(
    canonicalize_concept_set_expression(list(other = 1)),
    list(other = 1)
  )
})

# Testing: the ConceptSets block of a circe cohort is ordered by concept set id,
# with each concept set's items ordered by CONCEPT_ID.
testthat::test_that("canonicalize_circe_concept_sets sorts concept sets and their items", {
  conceptSets <- list(
    list(id = 2, name = "second",
         expression = list(items = list(wa_test_item(443238), wa_test_item(201826)))),
    list(id = 0, name = "first",
         expression = list(items = list(wa_test_item(4193704))))
  )

  out <- canonicalize_circe_concept_sets(conceptSets)

  testthat::expect_equal(vapply(out, function(cs) cs$id, numeric(1)), c(0, 2))
  testthat::expect_equal(wa_test_concept_ids(out[[2]]$expression), c(201826, 443238))
})

# Testing: concept sets missing an id keep their original order, so codeset
# references in the cohort expression cannot be broken.
testthat::test_that("canonicalize_circe_concept_sets leaves order alone without ids", {
  conceptSets <- list(
    list(name = "second", expression = list(items = list(wa_test_item(443238)))),
    list(name = "first", expression = list(items = list(wa_test_item(201826))))
  )

  out <- canonicalize_circe_concept_sets(conceptSets)

  testthat::expect_equal(vapply(out, function(cs) cs$name, character(1)), c("second", "first"))
})

# Testing: a shuffled ATLAS cohort payload serializes to identical circe JSON.
testthat::test_that("formatCohortExpression is stable under shuffled concept order", {
  makeExpression <- function(itemOrder, conceptSetOrder) {
    conceptSets <- list(
      list(id = 0, name = "target",
           expression = list(items = list(
             wa_test_item(201826), wa_test_item(443238), wa_test_item(4193704)
           )[itemOrder])),
      list(id = 1, name = "outcome",
           expression = list(items = list(wa_test_item(192671))))
    )
    list(
      ConceptSets = conceptSets[conceptSetOrder],
      PrimaryCriteria = list(CriteriaList = list()),
      QualifiedLimit = list(Type = "First"),
      ExpressionLimit = list(Type = "First"),
      InclusionRules = list(),
      CensoringCriteria = list(),
      CollapseSettings = list(CollapseType = "ERA", EraPad = 0),
      CensorWindow = list(),
      cdmVersionRange = ">=5.0.0"
    )
  }

  first <- formatCohortExpression(makeExpression(c(1, 2, 3), c(1, 2)))
  second <- formatCohortExpression(makeExpression(c(3, 1, 2), c(2, 1)))

  testthat::expect_equal(rlang::hash(first), rlang::hash(second))
})

# ── Key order within a node (#139, latent half) ───────────────────────────────

# Testing: canonicalize_concept_set_expression() orders the `items` array and
# formatCohortExpression() fixes the top-level circe slots, but neither used to
# touch the key order *inside* each node. WebAPI appears to serialize a concept
# from a hash-ordered map, which is free to vary between calls — and a varying
# key order rewrites the JSON file, its hash, and so the manifest sqlite.
testthat::test_that("canonicalize_json_keys sorts object keys recursively", {
  x <- list(b = 1L, a = list(d = 2L, c = 3L))

  out <- canonicalize_json_keys(x)

  testthat::expect_identical(names(out), c("a", "b"))
  testthat::expect_identical(names(out$a), c("c", "d"))
})

# Testing: arrays are order-carrying, so they must not be touched. `items` is a
# JSON array; its order is set by canonicalize_concept_set_expression().
testthat::test_that("canonicalize_json_keys leaves unnamed lists in order", {
  arr <- list(list(z = 1L), list(a = 2L))

  out <- canonicalize_json_keys(arr)

  testthat::expect_identical(names(out[[1]]), "z")
  testthat::expect_identical(names(out[[2]]), "a")
})

# Testing: a partially or duplicately named list is ambiguous — reordering it
# could change what it deserializes to, so it is left alone.
testthat::test_that("canonicalize_json_keys leaves ambiguous names alone", {
  partial <- list(b = 1L, 2L)
  dupes <- stats::setNames(list(1L, 2L), c("a", "a"))

  testthat::expect_identical(names(canonicalize_json_keys(partial)), c("b", ""))
  testthat::expect_identical(names(canonicalize_json_keys(dupes)), c("a", "a"))
})

testthat::test_that("canonicalize_json_keys tolerates atomics and empty nodes", {
  testthat::expect_identical(canonicalize_json_keys(1L), 1L)
  testthat::expect_identical(canonicalize_json_keys("x"), "x")
  testthat::expect_identical(canonicalize_json_keys(list()), list())
  testthat::expect_null(canonicalize_json_keys(NULL))
})

# Testing: the concept-set fetch path is now stable under a reordering of the
# keys inside a concept, which is the half of #139 the item sort did not cover.
testthat::test_that("a concept set serializes identically when concept keys are reordered", {
  serialize <- function(expression) {
    RJSONIO::toJSON(
      canonicalize_json_keys(canonicalize_concept_set_expression(expression)),
      digits = 23,
      pretty = TRUE
    )
  }

  forward <- list(items = list(list(
    concept = list(CONCEPT_ID = 1L, VOCABULARY_ID = "SNOMED", CONCEPT_CODE = "X")
  )))
  shuffled <- list(items = list(list(
    concept = list(VOCABULARY_ID = "SNOMED", CONCEPT_CODE = "X", CONCEPT_ID = 1L)
  )))

  testthat::expect_identical(serialize(forward), serialize(shuffled))
})

# Testing: the same for the cohort path, and that the deliberate circe slot
# order survives — the sort runs over each slot's contents, not over the slots.
testthat::test_that("formatCohortExpression is stable under nested key reorder and keeps slot order", {
  makeExpression <- function(conceptKeys) {
    concept <- list(CONCEPT_ID = 1L, VOCABULARY_ID = "SNOMED", CONCEPT_CODE = "X")[conceptKeys]
    ll <- list(
      ConceptSets = list(list(
        id = 0L, name = "cs",
        expression = list(items = list(list(concept = concept)))
      )),
      PrimaryCriteria = list(
        CriteriaList = list(list(ConditionOccurrence = list(CodesetId = 0L))),
        ObservationWindow = list(PriorDays = 0L, PostDays = 0L)
      ),
      QualifiedLimit = list(Type = "First"),
      ExpressionLimit = list(Type = "First"),
      InclusionRules = list(),
      CensoringCriteria = list(),
      CollapseSettings = list(CollapseType = "ERA", EraPad = 0L),
      CensorWindow = list(),
      cdmVersionRange = ">=5.0.0"
    )
    return(ll)
  }

  forward <- formatCohortExpression(makeExpression(c("CONCEPT_ID", "VOCABULARY_ID", "CONCEPT_CODE")))
  shuffled <- formatCohortExpression(makeExpression(c("VOCABULARY_ID", "CONCEPT_CODE", "CONCEPT_ID")))

  testthat::expect_identical(forward, shuffled)

  # ConceptSets stays first: alphabetical ordering would have put CensorWindow there
  testthat::expect_match(forward, "^\\{\\s*\"ConceptSets\"")
})
