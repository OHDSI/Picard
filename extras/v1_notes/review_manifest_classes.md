# Picard — Manifest Classes: Decisions and Findings

**Reviewed:** 2026-11-17 · **Revised:** 2026-11-24
**Against:** `ml_manifest_work` @ `4260771` (line numbers below are current as of that commit)
**Code read:** `R/CohortManifest.R`, `R/ConceptSetManifest.R`, `R/CohortDef.R`,
`R/ConceptSetDef.R`, `R/manifest_helpers.R`, `R/cohort_builders.R`,
`R/migrateCohortManifest.R`, `R/migrateConceptSetManifest.R`, `R/WebApi.R`
**Related:** `review_pipeline_execution.md` (the execution track — its **D11** settles #163
and its **D12** settles #162, both of which sit in the Manifest Updates milestone)

Supersedes `manifest_class_review.md` and `notes_v1_pathway.md`.

**How to read it.** The two tables below are the index. **§1–§6** describe how the code
works today, with file:line references — the implementation reference. **§6.1** is the one major open
decision; **§6.2** proposes splitting `resetCohortManifest()`. **§7** records Katy's review input, **§8** is the issue map, **§9** the
priority list to work from now, **§10** the full dependency graph. Decisions and open
questions are up front.

---

## Where this stands

| | |
|---|---|
| **0.0.9 — data loss fixes** | #158 (`4260771`) and #69 (`659c458`, `cdd45db`) **done**; #173 Part 1 (`caa78b8`) done. #166, #139, #121, #167 open |
| **Wave 2 (the gate)** | #157 + #165's H1/H3/H4/H8 — not started |
| **Waves 3–4** | #144, #159, then #161, #165-remainder, #168, #160 — not started |
| **Issues closed** | #46 and #64 (both retired into #163), #132 (superseded by #139), #156, #158 |
| **Issues filed from this review** | #165, #166, #167, #168, #173 |
| **Blocked on the execution track** | #163's verify mode, pending the disagreement in §7. #162 (D12) is settled and unimplemented |
| **Blocking the execution track** | **#144** — exec D11's builder-loop collapse and D13.8b both wait on it |
| **Open review input** | Katy objects to exec D11's verify mode (#163) and has answered #144's `databaseId` question. §7 |
| ⚠️ **Major decision point** | **#163 — how input builder scripts are sourced.** Not a defect and not a default: it decides the shape of the builder workflow. #46 and #64 are both closed into it. **Do not implement around it** — §6.1 |

**Picking this back up.** §9 is the next work. **#166 needs a decision before code**; #139,
#121, #69 and #167 do not.

---

## Decisions at a glance

| | Decision | Outcome |
|---|---|---|
| **M1** | Where a registered definition file lives | **Staged inside the repo.** `add*()` copies the caller's file into `inputs/` and registers the copy; a row can never point outside the study repo. Done in #158 |
| **M2** | How a staged file is named | From the **label**, via `manifest_label_to_filename()` = `snakecase::to_snake_case()` — the package-wide convention (9 other call sites). The label fixes the name at **first registration only** |
| **M3** | ATLAS filenames | **Unchanged.** `saveName` (carrying the ATLAS id) still wins; only the previously-unsanitized label fallback routes through M2 |
| **M4** | Filename collisions | **Abort before any disk write.** `to_snake_case()` is not injective, so two legal labels can collide; a verbose error naming both is the remedy. No auto-disambiguation |
| **M5** | Existing files on upgrade | **No migration.** The derived upsert already pins its destination to the registered file, so "new registrations only" is free. Case-only renames are hazardous on case-insensitive filesystems and `getManifestHash()` excludes `file_path`, so there is no correctness gain |
| **M6** | `file_name` in the load CSVs | **Rejected with an error**, not ignored. Unrecognized load columns become *tags*, so merely unreserving it would have put it in `getManifestHash()` as study metadata |
| **M7** | Generated vs staged file writes | Generated content uses `readr::write_lines()` (always LF); staged content is a **byte-exact `fs::file_copy()`**. Base `writeLines()` emitted CRLF on Windows, so one cohort hashed differently per platform |
| **M8** | Input-builder workflow (#163) | **Settled in exec D11**, not here: `skipInputBuilders` removed, both manifests scaffolded by `initUlyssesRepo()`, init functions made quiet-idempotent. ⚠️ **Verify mode is contested** — Katy objects (§7); treat it as open |
| **M9** | Script evaluation (#162) | **Settled in exec D12**: the pipeline never uses `globalenv()`; one child env per script |

### Still outstanding

| | Needs |
|---|---|
| **#166** — the default | warn-only, or mode-aware per exec D7's two lanes. **Blocks 0.0.9's next step.** Also narrow the orphan glob so `sql/` subfolders are safe |
| **#163** — verify mode | **Reopened by Katy's objection** (§7). Exec D11 made it default-on in the release lane; Katy wants to edit builders and re-run in one pass |
| **#163** — script organization | #46 closed *into* #163: is the builder set a fixed six, or analyst-organized? Changes the shape of the code, not just a default. Together with verify mode this makes #163 **the strategic blocker** — see §9 |
| **#144** — four questions | ~~scalar vs. array~~ **answered: a list** (Katy, #144, 2026-10-09 — see §7). Still open: whether concept sets get both fields; whether a `databaseId` change is definition or metadata; `displayName` uniqueness; whether concept sets are gated at all |
| **#144** — the `databaseId` meaning | picard already uses the name for two different things (`databaseName` value vs. config-block name). Recommend **config block name**, which needs `configBlock` plumbed onto `ExecutionSettings` |
| **#144 vs #153** | `databaseId` should ultimately be a foreign key into #153's Database class. Either accept that #144 ships a field #153 reshapes, or pull #153 forward |
| **#165 H2** | Is `.fileHash == .sqlHash` for `.sql` cohorts intended collapse or accident? A decision, not code |
| **#160** — unknown types | Must a manifest open when it references a `cohort_type` whose package is not installed? Determines whether the registry lookup is an assertion or a lookup-with-fallback |
| **#157** — stamp mechanism | `PRAGMA user_version` as the branch driver plus a `picard_meta` row for provenance is the recommendation |

---

## Defects, and what was filed

Eight findings (**F1–F8**) came from the class review and eight (**H1–H8**) from the hash
layer. Disposition:

| | Status |
|---|---|
| **F1** `runPreflightChecks()` bypassed `get_current_branch()` | **fixed** in code |
| **F2** `loadConceptSetManifest()` not root-aware | → #159 (fallback: #161) |
| **F3** `CohortManifest` has no incremental migration | → **#157** |
| **F4** SQL string interpolation in `validate_parent_cohorts_exist()` | → **#167** |
| **F5** no-op `invisible(NULL)` early returns in both classes | → **#167** |
| **F6** `MAX(id)+1` outside a transaction | → **#167** |
| **F7** O(n²) ATLAS import | → **#168** (and #159 kills the costlier half) |
| **F8** `syncManifest(strict_mode=TRUE)` deletes files on load | → **#166** |
| **H1** `getSqlHash()` documents a normalization it does not do | → #165, **rides with #157** |
| **H2** `.fileHash == .sqlHash` for `.sql` cohorts | → #165, a decision |
| **H3** "MD5" misdocumented (it is xxHash128) ×3 | → #165, rides with #157 |
| **H4** `manifest_canonical_json()` does not sort keys | → #165, **rides with #157** |
| **H5** two competing concept-set definition hashes | → #165, after the stamp |
| **H6** ATLAS comparison hash is a hand-rolled write simulation ×4 | → #165 |
| **H7** concept sets get no canonicalization on fetch | → **#139** (and closed #132) |
| **H8** the hash column's definition inlined 8× | → #165, rides with #157 |

**Why H1/H3/H4/H8 must ride with #157.** Each changes the stored hash of every cohort in
every existing study repo. Landed alone that is an unannounced cache bust — full
regeneration and a full task rerun with no way for a study to know why. Landed with #157's
version stamp it is a controlled migration: *a manifest stamped below version N was hashed
the old way → rehash from disk, re-stamp, warn once.*

---

## 1. The three-layer model

Every manifest is the same three things kept in agreement:

```
   R6 object (in memory)        SQLite table              files on disk
   ─────────────────────        ────────────              ─────────────
   private$.manifest            cohort_manifest           inputs/cohorts/json/*.json
   = list of CohortDef          one row per file          inputs/cohorts/sql/*.sql
                                                          inputs/cohorts/derived/*.sql
```

Four invariants, genuinely enforced in code:

1. **1 row ⇄ 1 file.** The row is metadata *about* a file; the file is the definition.
   `syncManifest()` is the reconciler.
2. **One manifest to rule them all.** A single sqlite per input kind, for the whole study,
   across every database. (What #144's `databaseId` is meant to preserve.)
3. **Uniqueness by `label`** — a partial unique index plus R-level validators.
4. **Upsert keyed on `label`,** gated by `stopIfExists`.

The R6 object is a **cache, not the source of truth**: every method opens its own
short-lived connection (`DBI::dbConnect` … `on.exit(dbDisconnect)`) rather than holding one
open, and each *mutating* method ends by calling `private$load_manifest_from_db()`.

This is a *connection* pattern, not a *write* pattern — a steady-state load is a pure read,
measured byte-stable. That is why **#132 was closed**: the diff-on-every-run reports are
#139 (concept-set JSON refetched non-canonically → `syncManifest()` corrects the hash →
sqlite bytes move), not the connection pattern. A `mode=ro` URI would not have prevented
either real write, and would break `init_manifest()`.

---

## 2. `CohortManifest` (`R/CohortManifest.R`)

### Schema — `init_manifest()` (`:45`)

| Column | Notes |
|---|---|
| `id` | INTEGER PRIMARY KEY, assigned `MAX(id)+1`, **never reused** (see F6) |
| `label` | NOT NULL, unique among registered rows — the analyst's key |
| `category` | NOT NULL, free text |
| `tags` | JSON object string, nullable |
| `file_path` | NOT NULL, repo-root-relative, unique among registered rows |
| `hash` | NOT NULL, `rlang::hash()` of raw file contents |
| `source_type` | `atlas` \| `capr` \| `circe` \| `sql` \| `derived` |
| `cohort_type` | `circe` \| `custom` \| `subset` \| `union` \| `complement` \| `composite` \| `oprior` \| `tprior` \| `censor` \| `custom_derived` |
| `depends_on` | JSON int array of parent ids, nullable |
| `dependency_rule` | JSON object of build parameters, nullable |
| `status` | `active` \| `stale` \| `deleted` \| `purged` |
| `created_at` / `updated_at` / `deleted_at` | |

Two partial unique indexes on `label` and `file_path`, scoped `WHERE status IN
('active','stale')`. `ensure_registered_index()` (`:110`) drops and recreates them on load
when the stored definition differs — how older `status='active'`-only indexes widen. It
degrades to a warning rather than an abort if widening would violate uniqueness.

> **There is no in-place `ALTER TABLE` path in this class.** Schema evolution rests on
> `CREATE TABLE IF NOT EXISTS` plus the one-shot `migrateCohortManifest()`, which drops and
> rebuilds and refuses to run twice. `IF NOT EXISTS` keys on the table *name* only — SQLite
> never compares the column list — so editing the `CREATE TABLE` changes new manifests only.
> **This is #157**, and it is the gate for #144.

### Status lifecycle

```
  (insert) ──> active ──────────────────────────────> deleted ──> purged
                 ▲  │                                   ▲
                 │  │ definition changed                │ file vanished (syncManifest)
                 │  ▼ (own or a parent's)               │ deleteCohort()
                 └─ stale  ──(regenerated in DBMS)──────┘
```

- `stale` rows are **still registered** — they own their label and file path, count as valid
  parents, appear in `tabulateManifest(filter="active")`, and stay in memory so
  `executeCohortGeneration()` can regenerate them.
- Staleness is *per study*, clearing is *per database* — the flag clears when **this**
  database's checksum table is up to date. Already a single-manifest/many-databases
  compromise, and directly relevant to #144.
- `cascadeStaleDownstream()` (`manifest_helpers.R:1907`) propagates to transitive
  dependents; `findTransitiveDependents()` (`:1842`) is the walker.
- Soft delete only; `cleanCohortTable()` (`:5134`) purges DBMS rows then flips
  `deleted` → `purged`.

### Where the invariants live

Read the private layer first: `validate_label_unique()` (`:253`),
`resolve_derived_upsert()` (`:307`), `destination_for()` (`:377`),
`upsert_derived_cohort()` (`:408`), `validate_filepath_unique()` (`:538`),
`validate_parent_cohorts_exist()` (`:567`), `insert_cohort()` (`:946`),
`update_cohort_def()` (`:1034`).

Note `validate_filepath_unique()` is called from **one** place. The one-row-per-file
invariant is currently enforced three different ways — a `cli` validator on the CIRCE route,
an inline comparison on the SQL route, and the DB index everywhere else (a raw DBI error,
*after* the file is written). Consolidating that is #161's business.

### Derived-cohort upsert — the subtlest logic in the class

`upsert_derived_cohort()` (`:408`) distinguishes **definition change** from **metadata
change**:

- *definition* = file hash, resolved file path, `depends_on`, `dependency_rule`
  → marks `stale` **and** cascades downstream.
- *metadata* = `category`, `tags` → updates in place, generation status untouched.
- *neither* → logs "nothing to do" and does **not** touch `updated_at`.

That last branch is load-bearing: builder scripts are re-sourced on every pipeline run, so
an idempotent re-run must not invalidate generated cohorts or dirty the sqlite.
`manifestValueUnchanged()` (`manifest_helpers.R:1816`) serves the same purpose in
`update_cohort_def()`.

`resolve_derived_upsert()` (`:307`) refuses to: upsert when `stopIfExists=TRUE`, convert a
source cohort into a derived one, change `cohort_type` under an existing label, or introduce
a dependency cycle. It keys on **label** — which is why M4's destination check had to be
added separately, and why a collision used to destroy a file before failing.

### Generation — `executeCohortGeneration()` (`:5294`)

1. `validateExecutionSettings()`; connect (disconnect only if we opened it).
2. `checkCohortTables()` → create missing ones.
3. `build_dependency_graph()` → `validate_no_cycles()` → `topological_sort()`
   (`cohort_builders.R:85`) — parents always before children.
4. Per cohort, `evaluate_cohort_skip_status()` (`cohort_builders.R:326`) compares the
   cohort's hash (or `compute_dependency_hash()`, `:254`, for derived) against the DBMS
   checksum table. Skip → clear `stale`; otherwise generate.
5. First error aborts the remainder, reported as `"Not generated"`.

`retrieveCohortCounts()` (`:5543`) then joins `label` + `tags` back from the in-memory
`CohortDef`s. **Column order is hardcoded** — #144 adds `displayName` here, so any
dissemination script reading `cohortCounts.csv` positionally breaks.

---

## 3. `ConceptSetManifest` (`R/ConceptSetManifest.R`)

Same shape, smaller: no derived tier, so no `depends_on`, no `cohort_type`, no `stale`.
Schema: `id, label, category, tags, file_path, hash, status, created_at, updated_at,
deleted_at`.

It owns vocabulary tooling with no cohort analogue: `combineConceptSets()` (`:1959`),
`extractSourceCodes()` (`:3077`), `extractIncludedCodes()`, `grabConceptInfoFromSet()`.

### Lockstep drift — #161

`CLAUDE.md` says the two are maintained in parallel; nothing enforces it. **Correct
deviations** (do not "align" these): the derived tier, DBMS generation, the SQL/CIRCE source
routes and the `stale` status tier are cohort-only because concept sets have no dependency
graph and no DBMS artifact. Vocabulary tooling and `combineConceptSets()` are concept-set
only.

**Unintentional drift:**

| | |
|---|---|
| `migrate_schema()` exists only on `ConceptSetManifest` (`:218`) | → #157 |
| no R-level `file_path` uniqueness check on the concept-set side | → #161 |
| label uniqueness **inline-duplicated 4×** vs. one `validate_label_unique()` | → #161 |
| `load_manifest_from_db()` has no `ORDER BY` in `CohortManifest` (`:148`); the concept-set one has `ORDER BY id` (`:71`) | → #161 |
| concept-set indexes are plain `IF NOT EXISTS`, so can never be widened | → #161 |
| naming: `resolve_path`/`resolve_file_path`, `insert_cohort`/`insert_concept_set`, `find_registered_*`/`find_active_*` | → #161 |
| `print`, `statusReport`, `reloadFromDb`, entry-tibble resolvers are cohort-only | → #161 |
| `viewManifest()` signatures diverge materially (`tagDelimiter` vs `tags_format`) | → #161 |
| `insert_concept_set()` relativizes *inside* the insert (`:151`); `insert_cohort()` expects the caller to have done it | → #161 |
| `loadConceptSetManifest()` not root-aware (`manifest_helpers.R:1242`) | → #159 |

**Make lockstep enforceable:** a test diffing the two member sets against an explicit
allowlist of intentional deviations. The allowlist becomes the decision record.

---

## 4. Path handling — #159

`file_path` is stored **relative to the study repo root**. Three helpers own it:

- `findStudyProjectRoot()` (`manifest_helpers.R:27`) — walks up; cached once in
  `private$.projectRoot`.
- `manifest_path_relative()` (`:70`) → `private$to_manifest_path()` — the **write** form.
- `resolve_manifest_path()` (`:101`) → `private$resolve_path()` — the **read** form.

`CohortDef`/`ConceptSetDef` always hold an **absolute** path internally, with
`getDisplayPath(root)` for display. That boundary is deliberate and should survive #159.

### The problem: one signature, two jobs

`resolve_manifest_path()` serves both "resolve a path read out of a sqlite row" (should be
one convention, pure string composition) and "resolve a caller-supplied input path" (where
absolute is legitimate). Because one function does both, it has to guess — hence the disk
probe, *"try each candidate, the first that exists wins"*.

Only **one** of its three tiers is legacy:

| Tier | Form | Status |
|---|---|---|
| 1 | absolute | **load-bearing** — input paths are often absolute |
| 2 | repo-root-relative | **current** — the only form new rows get |
| 3 | manifest-folder-relative (`json/x.json`) | **pre-v1 only** |

#158 landed the guard that makes every *new* row tier 2 by construction (a staged path
cannot escape the repo). #157's stamp is what makes tier 3 safe to delete. Then:
`resolve_stored_path()` / `resolve_input_path()`, `validate_filepath_unique()` becomes raw
string comparison, the `file_path` unique index becomes sound rather than decorative, and
`normalize_manifest_paths()` (`:806`) plus its two exported wrappers retire.

`manifest_resolve_destination()` (`:191`) already splits these two jobs internally as
`input_path()` / `stored_path()` — a miniature of what #159 should do globally.

---

## 5. Hashing and change detection — #165

Three distinct hashes. Get them straight before touching the schema.

| Hash | Over what | Stored | Used for |
|---|---|---|---|
| `manifest.hash` column | raw file bytes | sqlite row | `syncManifest()` drift detection |
| `CohortDef$getSqlHash()` | **rendered SQL** | memory only | DBMS checksum → skip/regenerate |
| `getManifestHash()` (`:1194`) | id, label, category, tags, cohort_type, source_type, depends_on, dependency_rule, + each `getSqlHash()`, ordered by id | nowhere | `shouldRerunTask()` → task rerun |

Two deliberate properties of `getManifestHash()`: `file_path` is **excluded** (path
normalization must not force reruns — which is also why M5 declines to rename files), and
JSON columns are canonicalized via `manifest_canonical_json()` (`:374`).

**Consequence for #144:** a field that can change the analysis must enter
`getManifestHash()`, or editing it will silently fail to rerun tasks. Both new fields
qualify. And both must enter `list_tags_in_row()`'s reserved list (`:2029`) or they become
*tags* — and then get hashed twice.

Note the hash stays global, so a change to a cohort gated to `db_a` will also rerun `db_b`'s
tasks. Conservative and acceptable; call it out in NEWS.

The eight defects in this layer are **H1–H8** in the table above. The two that bite hardest:
`getSqlHash()` normalizes nothing despite documenting that it does (so a CRLF flip
regenerates a cohort and reruns every task), and `manifest_canonical_json()` does not sort
keys (so the "cosmetic reformat" promise holds for whitespace and fails for key order).

---

## 6. Input builders — see exec D11

`sourceInputBuilderScripts()` (`R/execute.R`) sources exactly **six** scripts in a fixed,
hardcoded order (concept sets before cohorts, base before derived), aborting if one is
missing or if either `R/` folder holds another `.R` file.

Its per-config-block re-sourcing loop is **today's workaround for the problem `databaseId`
exists to solve** — the comment in the loop is explicit that builders may make
database-specific manifest changes that the next block's builders overwrite (last database
wins).

Everything about this is settled in the execution track, not here: **exec D11** (#163) and
**exec D12** (#162). The manifest-side consequence is that **D11's end state is blocked on
#144**, which makes collapsing the loop safe.

⚠️ `loadCohortManifest(autoSync = TRUE)` — the default — runs `syncManifest(strict_mode =
TRUE)`, which **`unlink()`s** unregistered `.json`/`.sql` under `inputs/cohorts/{json,sql}`,
recursively. Merely loading the manifest can delete files. That is **#166**.

---

## 6.1 #163 is a major decision point, not a task

**#163 decides how input builder scripts are sourced.** It is the one item in this plan that
is a design question rather than a defect or a default, and it has absorbed two other issues
(#46 and #64 are both closed into it). It should be settled deliberately, in conversation
with Katy, and not implemented around.

Three questions, each of which changes the code rather than a parameter:

| | Question | Status |
|---|---|---|
| **a** | **What is the script set?** A fixed, hardcoded six in a mandatory order, or analyst-organized files discovered at runtime? | open — #46's navigability concern, closed into #163 |
| **b** | **May a run mutate the manifest?** Verify mode default-on in the release lane, or opt-in, or definition-changes-only | open — **Katy objects** (§7) |
| **c** | **How many times do builders run?** Once, or once per config block? | **forced by #144**, not by #163 — see §9 |

Why each is load-bearing:

- **(a)** is the assumption under `sourceInputBuilderScripts()`'s validation, its mandatory
  source order, and its "no other `.R` file in these folders" abort. Changing it is a
  rewrite, not a flag. It also interacts with exec **D12** (#162), which restructures the
  same function.
- **(b)** is what #64's reproducibility guarantee now rests on, so it is not merely a
  convenience default — but it is also the thing a working analyst feels on every run,
  which is why Katy's objection carries weight that a correctness argument does not answer.
- **(c)** is already decided elsewhere: exec D1/D4's six-step model makes collapsing the
  loop mandatory, and D11 says it is unsafe until rows declare their own `databaseId`.
  **So this one is answered by landing #144, not by deciding #163.**

**Consequence.** (c) resolves itself once #144 lands. (a) and (b) need a conversation. None
of the manifest-class work in §9 depends on any of the three — the four files this plan is
about contain *zero* references to the builder machinery (§9). So #163 can stay open without
holding anything up.

---

## 6.2 `resetCohortManifest()` — the scope split (filed as #173)

**Context.** #69's real reproduction runs through this function. A manifest object holds a
*path*, not a handle, so when `resetCohortManifest(scope = "manifest")` calls
`file.remove(dbPath)` (`manifest_helpers.R:759`) the caller's live object is left pointing
at nothing. Before `private$safe_connect()` (added for #69), the next method call recreated
the file as a **table-less** database and failed with `no such table: cohort_manifest` —
after which the bogus file passed `loadCohortManifest()`'s own existence check, so the
failure moved deeper rather than being reported. Reproduced and now closed.

### The asymmetry that exposed it

| Scope | sqlite file | live object | OMOP tables |
|---|---|---|---|
| `"derived"` | **survives** (derived rows deleted, `derived/` cleared) | **handled** — calls `manifest$reloadFromDb()` | untouched |
| `"manifest"` | **deleted** (`json/`, `sql/` archived) | nothing | untouched |
| `"full"` | **deleted** (+ `json/`, `sql/`, `cohortsLoad.csv`) | nothing | **dropped** |

The one scope that keeps the file refreshes the object; the two that delete it do nothing.
That is a good sign the author was thinking about staleness, but only in the branch where
staleness was the whole problem.

Note `manifest` is a **parameter** of `resetCohortManifest()` — required for `"derived"`,
optional for the other two. So it is optional in exactly the two scopes that would need it.

### Decision: `safe_connect()` is the fix, not object invalidation

Three options were weighed:

| | |
|---|---|
| **(a) guard on connect** — **chosen** | The object fails loudly on next use. Does not depend on reset knowing anything, so it also covers deletion reset cannot see: a `git checkout`, a manual `fs::file_delete`, a synced folder, another R session. Implemented as `private$safe_connect()` across 51 sites in the two classes |
| (b) reset marks the object invalid | R6 is reference semantics, so reset *could* set an `.invalidated` flag and get a better message. But `manifest` is optional for both deleting scopes, so it fires only when the caller happened to pass it. A nicety on top of (a), never a replacement |
| (c) truncate instead of delete | Arguably the truest reading of "reset", and no dangling state could exist. Rejected: it contradicts documented behaviour ("Deletes the SQLite database"), the `archive = TRUE` flow is built around deletion, `"full"` deliberately drops the OMOP tables too, and it still would not cover deletion by other means |

### Proposed split — extract the authoring verb, keep `reset` for teardown

The three scopes are not three intensities of one operation; they are three different
operations that happen to share a confirmation prompt.

| Today | Proposed | What it is |
|---|---|---|
| `scope = "derived"` | **`clearDerivedCohorts()`** | Not a reset at all. The manifest survives, base cohorts survive, only the derived tier is dropped so it can be rebuilt with new parameters. An **authoring-loop** operation, run repeatedly and routinely |
| `scope = "manifest"` | **`resetCohortManifest(scope = "manifest")`** | Unchanged. `reset` keeps its name and owns teardown; it loses only the `"derived"` value from `scope` |
| `scope = "full"` | **`resetCohortManifest(scope = "full")`** | Unchanged. Kept as a scope value rather than flags: it differs on two independent axes (`cohortsLoad.csv`, and dropping the OMOP tables), which `dropCohortTables=` + `deleteLoadFile=` would not make clearer |

Why this is worth doing rather than leaving one function with a `scope`:

- **The requirements differ, and the signature cannot express that.** `"derived"` requires a
  live `manifest`; the teardowns only need a path. `"full"` requires `executionSettings`;
  the others ignore it. One signature carrying `manifest`, `cohortsFolderPath`, `scope`,
  `executionSettings`, `archive` and `confirm` makes every argument conditionally required,
  which is why the documentation has to spell out the matrix.
- **The blast radius differs by orders of magnitude**, but the only thing standing between
  them is one string literal. `scope = "full"` instead of `scope = "derived"` is a typo that
  drops your OMOP cohort tables.
- **It separates the authoring loop from the destructive path.** Dropping and rebuilding
  derived cohorts is normal iteration. Deleting the manifest is not. They should not share
  a name, and exec **D11** already places teardown in the authoring lane only.
- **`archive` only applies to one scope**, which a dedicated verb can make a first-class
  argument rather than a footnote.

**Open question for the split.** Should the derived verb *also* remove the generated SQL in
`inputs/cohorts/derived/`, or only the manifest rows? Today `"derived"` does both. Since
#158 the filenames are label-derived and an upsert restages over the registered file, so
leaving the files is now harmless — the rebuild overwrites them. Dropping only the rows
would make the operation non-destructive on disk, which is a better fit for something run
routinely.

### Resolved while filing: the `archive` documentation was wrong, not the default

`archive = FALSE` in the signature (`manifest_helpers.R:632`) while the roxygen claimed
*"if **TRUE (default)**, archives source files… and **can be restored**"* (`:618`, `:598`,
and the concept-set copy at `:1365`). With the real default the `else` branch `unlink()`s
`derived/`, `json/` and `sql/` outright.

**Decided: the default stays `FALSE`** — deleting is the intended behaviour and archiving
is the opt-in. The documentation was corrected instead, in `caa78b8`: both `@param` blocks
and both `@section Scope options` blocks now describe deletion, with `archive = TRUE` as
the opt-in that copies to `_archive/<timestamp>/` first. The interactive prompt was always
accurate; the help page was not, which mattered for scripted callers passing
`confirm = FALSE`, where no prompt is shown.

So **#173 Part 1 is closed** and #173 now covers Part 2 only — the split.

**Sequencing.** The split is a breaking API change on an exported function, so it belongs with
the other v1 breaks rather than in 0.0.9 — the `safe_connect()` guard already removes the
data-loss consequence, which is what made it urgent. It also touches no manifest-class
internals, so it is independent of #157/#159/#161 and can land whenever. Worth confirming
against exec **D3**'s repository structure first, since teardown semantics and what the
scaffold creates are two halves of the same question (D11 already moved manifest creation
into `initUlyssesRepo()`).

---

## 7. Review comments from Katy — open input

Four comments from @katy-sadowski bear on this plan. Recorded here because three of them
change a decision and one closes a question.

### Verify mode — a direct objection (#163, 2026-11-21)

Posted the day *after* exec D11 settled verify mode as default-on:

> I do not agree with this. I should be able to make changes to my builder scripts and then
> re-run the pipeline in one swoop, not needing there to be 2 separate steps. It would be
> very inconvenient to need to isolate and commit cohort changes before running the pipeline.

This is the strongest open disagreement in either track, and it is about workflow cost, not
correctness — so it will not be settled by argument from reproducibility alone.

**Where the two positions may already reconcile.** D11 scopes verify mode to the **release
lane** only; D7's internal lane creates and mutates freely. If Katy is describing day-to-day
iteration, the two-lane split already gives her the one-swoop workflow and verify mode never
fires. Worth establishing first, because it may be a communication gap rather than a design
conflict.

**Where they genuinely conflict.** If she means a *release* run, D11 and D6 both require a
clean tree anyway — pre-flight's code-state check already rejects uncommitted changes
(exec X-1), so "commit cohort changes before running" is a pre-existing requirement of the
release lane that verify mode merely names. If that requirement is itself the objection,
the argument is with D6, not D11.

**Options if it does not reconcile:**

| | |
|---|---|
| opt-in for one release | what #163 originally proposed and D11 closed. Lowest friction, defers the guarantee |
| error only on a *definition* change | metadata-only mutations pass. Uses the distinction `upsert_derived_cohort()` already draws (`:408`), so it is cheap. Narrower guarantee, much lower friction |
| keep default-on | relies on the lane split answering her. Needs her agreement, not just the rationale |

My read: offer the **definition-change-only** variant. It preserves what D10 actually needs
— that the hash snapshot describes what the release claims — while letting an analyst
retag or recategorize mid-run. Needs Martin and Katy to agree, not a technical fix.

### `databaseId` holds a list — answered (#144, 2026-10-09)

> Only change is to clarify, I think databaseId should be able to hold a list of databases.

This **closes** the load-bearing #144 question. `database_id` is a JSON array in a TEXT
column (the `depends_on` pattern), `NULL` meaning all databases, with a scalar accepted and
wrapped. It also kills the duplicate-label workaround (FILD-US-1, FILD-US-2) that a scalar
would have forced.

### #46 — retired into #163 (#46, 2026-10-09)

> I still think we should consider it down the road. For studies with lots of cohorts the
> files become hard to read & navigate.

**#46 is closed and rerouted into #163** (2026-11-24), as #64 was. So #163 now owns two
questions, not one:

| | |
|---|---|
| **verify mode** | should a release run treat a manifest mutation as an error? Katy objects (above) |
| **script organization** | is the builder set a fixed, hardcoded six, or analyst-organized files? #46's navigability concern |

These belong together — they are the same conversation about what the builder workflow *is*
— but note they are different *kinds* of question. Verify mode is a default; script
organization changes the shape of the code, since #163's validation, its mandatory source
order and its per-block loop are all built on the fixed-six assumption.

**Consequence for sequencing:** #163 is now the single strategic blocker for the builder
workflow, and it has grown rather than shrunk. Nothing else in this plan should wait on it
— see §9.

### #64 — her remaining-work list is done (#64, 2026-08-28)

> This should be the one remaining cohort builder to fix: #61, and this concept set builder:
> #81

Both are **closed**, and verified in current code: `buildStratifiedCohorts()` takes
`stopIfExists` (`CohortManifest.R:3158`) and so does `combineConceptSets()`
(`ConceptSetManifest.R:1963`).

So #64's *stated* remaining scope was complete, and **#64 has since been closed** as
retired into #163 (2026-11-24). Its reproducibility guarantee now lives entirely in #163's
verify mode — which means the guarantee is held up by the contested decision above. Noted
so that "reproducibility is handled" is not mistaken for "reproducibility is shipped".

---

## 8. Open-issue map

### 0.0.9 — data loss fixes

| # | What | Note |
|---|---|---|
| ~~#158~~ | staging | **done**, `4260771` |
| **#166** | `autoSync` hard-deletes unregistered files | **needs the default decided.** Also surfaces a *seventh* hardcoded `cohort_type` list for #160, and the recursive glob makes `sql/` subfolders unsafe for work in progress |
| **#139** | no `formatConceptSetExpression()` exists | H7. Closing this is what actually closed #132 |
| **#121** | `importAtlasConceptSets` can't update a label | reported bug with a traceback |
| **#69** | builder free functions create a table-less sqlite | largely defused by exec D11 (scaffold creates both manifests); the root-cause guard still lands |
| **#167** | F4 + F5 + F6 | F4 **must** land before #160 exports the function containing it; F5 folds into #157's diff |

### The v1 chain

| # | What | Blocked by |
|---|---|---|
| **#157** | `migrate_schema()` on `CohortManifest`, schema + hash version stamp, retire both `migrate*.R` | — |
| **#165** H1/H3/H4/H8 | one hash-layer pass | rides *with* #157 |
| **#144** | `displayName` / `databaseId` | #157; five open questions |
| **#159** | split stored-path from input-path, drop tier 3 | #157's stamp (#158's guard is in) |
| **#161** | align the two classes, parity test with allowlist | #159 |
| **#165** H2/H5/H6 | remainder | #157's stamp |
| **#168** | `find_registered_atlas_registration()` O(n²) | #159 kills the other half. If `atlasId` becomes a column, do it inside #144's schema event |
| **#160** | cohort-type registry | #157/#159/#161. **Gate 3 already cleared** by #158's work. Prereq for **`picardTemplates`** |

### Not v1-sequenced

**#145** (concept-set-based cohorts) — new capability; easier after #160's registry.
**#46** and **#64** are closed into #163 — both are builder-workflow concerns rather than
manifest-class work (§7).
**#153** (Database class) is the one cross-milestone coupling — see *Still outstanding*.

---

## 9. Priority list — what to do before #144 and #163

Both #144 and #163 are held up by decisions: #144 by four open questions (§*Still
outstanding*) and #163 by the two in §6.1. Everything below is independent of **both**, and
accounts for the whole of 0.0.9 plus the schema gate plus most of the consolidation work.

**Why this is safe.** #163's blast radius is `R/execute.R` and the templates, not the
manifest classes:

| File | `sourceInputBuilderScripts` / `skipInputBuilders` / `createInputBuilderEnv` refs |
|---|---|
| `R/execute.R` | 26 |
| `R/validation.R` | 4 |
| `inst/templates/main.R`, `test_main.R` | 2 each |
| `R/make.R`, one loader template | 1 each |
| **`CohortManifest.R`, `ConceptSetManifest.R`, `manifest_helpers.R`, `cohort_builders.R`** | **0** |

### P1 — no decisions, no dependencies

| # | What | Why first |
|---|---|---|
| **#139** | `formatConceptSetExpression()` on the ATLAS concept-set fetch path (`WebApi.R:90` has no canonicalization; the cohort path has it at `:83`) | **Highest value per unit of work.** Ends the diff-on-every-run churn, which is the real cause behind the closed #132. Pure addition — nothing depends on it |
| **#121** | `importAtlasConceptSets` can't update a label even with `stopIfExists = FALSE` | Reported bug with a traceback; a user is blocked |
| **#167** | F4 parameter binding, F5 the two no-op returns, F6 id allocation in a transaction | Three one-liners. **F4 must precede #160** |
| **#69** (guard half only) | reject a nonexistent `dbPath` in the `cohort_builders.R` free functions | The scaffolding half belongs to exec D11 → #163. Do the guard, leave the scaffolding |

### P2 — one small decision each

| # | Decision | Recommendation |
|---|---|---|
| **#166** | warn-only vs. mode-aware default for `autoSync` / `strict_mode` | **Warn-only.** The mode-aware variant means "error in the release lane", which is structurally what Katy objects to in verify mode — warn-only keeps #166 out of the #163 argument entirely. Also narrow the recursive glob so `sql/` subfolders are safe, and record the glob ↔ `cohort_type`-filter coupling as #160's seventh list |
| **#168** (contained fix only) | hoist the atlasId index out of the `importAtlasCohorts()` loop | Do the **loop-hoisting** half now. The structural fix — promoting `atlasId` to an indexed column — should ride #144's schema event rather than being a separate `ALTER TABLE` |
| ~~#173 Part 1~~ | ~~`archive` default contradicts the docs~~ | **done** (`caa78b8`) — resolved as a docs fix; the `FALSE` default is intended. Part 2 (the split) is a v1 break and stays out of 0.0.9 |

### P3 — the gate

| # | What | Note |
|---|---|---|
| **#157 + #165** H1/H3/H4/H8 | `migrate_schema()` on `CohortManifest`, schema + hash version stamp, retire both `migrate*.R`, and the four hash fixes that invalidate stored hashes | **The single highest-value item that does not need #144.** It is #144's prerequisite, but it also unblocks #159/#160 and the hash fixes are worth having on their own. Only open choice is the stamp mechanism — `PRAGMA user_version` to branch on, plus a `picard_meta` row for provenance |

### P4 — unlocked by the gate, still independent of #144/#163

| # | What | Blocked by |
|---|---|---|
| **#159** | split `resolve_stored_path()` / `resolve_input_path()`, drop legacy tier 3, retire `normalize_manifest_paths()` | #157's stamp. #158's guard is already in |
| **#165** H5/H6 | unify the two concept-set definition hashes; hash-after-write in the four ATLAS sites | #157's stamp (H5 only). H2 is a decision, not code |
| **#161** | align the two classes, parity test with an intentional-deviation allowlist | #159 |
| **#160** | cohort-type registry | #161. **Has an open decision** (unknown-type degradation), so it may slip past #144 regardless — Gate 3 is already cleared |

### Not in this list

**#144** and **#163** by definition. **#145** (concept-set-based cohorts) is new capability
and easier after #160's registry. **#162** is mechanically independent but rewrites
`sourceInputBuilderScripts()`'s signature — the same function #163 restructures — so it is
the one item where going first risks touching the same lines twice. Hold it with #163.

### If you want one item

**#139.** No decisions, no dependencies, and it is the fix that stops every study repo
showing a spurious git diff on every pipeline run.

---

## 10. Sequencing

```
0.0.9 ──┬── #166  (decide default first)
        ├── #139  (closes the #132 symptom class)
        ├── #121
        ├── #69
        └── #167  (F4 before #160)
              │
Wave 2 ───────┴── #157 + #165 H1/H3/H4/H8        <- the gate; everything below waits
                    │
Wave 3 ─────────────┼── #144  (settle the five questions; unblocks exec D11 + D13.8b)
                    └── #159
                          │
Wave 4 ───────────────────┴── #161 ── #160
                               #165 H2/H5/H6
                               #168
```

**Rationale for 0.0.9 before #157.** #166 and #158 were active data-loss bugs — files
hard-deleted on load, rows silently deleted on other machines — while #157 only blocks
*future* work. That is a different kind of urgent. #158 is done; #166 is the remaining one.

**Rationale for #157 + #165 as one pass.** H1 and H4 each invalidate every stored hash in
every study repo. The version stamp is the only thing that turns that from a silent cache
bust into a controlled migration.

**#144 and #163 are decision-gated, not dependency-gated.** Both sit late in the graph
above because of open questions (§*Still outstanding*, §6.1), not because the code beneath
them is missing. §9 is the list that proceeds without them. Note one inversion: **#144
answers #163's question (c)** — collapsing the per-block builder loop — so landing #144
makes #163 a smaller decision, and the dependency runs #144 → #163, not the reverse.

**Rationale for #160 last.** #157, #159 and #161 all rewrite the code it sits on, and its
unknown-type handling reuses the "manifest must always open" guarantee #157 establishes.
Doing it alongside means refactoring the same code twice.
