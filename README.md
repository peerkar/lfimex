# lfimex

CLI for automating Liferay site export/import end-to-end. Drives the source-site export, optional fresh target instance creation, global-dependency migration, layout import, and (optionally) DB-level validation against a configurable test suite.

Built for Liferay DXP 7.4 (2026.Q1+).

## Requirements

- Bash 4+
- `mysql` and `curl` on `PATH`
- `blade` on `PATH` (only when `INSTANCE_MODE=create`)
- Direct DB access (read/write) to the Liferay portal
- A running Liferay instance you can reach over HTTP

## Setup

```bash
git clone <repo> && cd lfimex
cp config/config.sh.example config/config.sh
$EDITOR config/config.sh              # fill in BUNDLES_DIR, creds, source site
ln -s "$PWD/lfimex" ~/.local/bin/lfimex   # optional, makes the command global
```

## Usage

```bash
lfimex [options]
```

Run `lfimex --help` for the full flag list and `lfimex --list-assets` for the asset catalog.

### Common runs

```bash
# Full pipeline: fresh instance, migrate globals, create site, import everything,
# validate against the source DB.
lfimex

# Single asset, throw away the target afterwards.
lfimex --assets blogs --cleanup

# Just produce LARs from the source site — no instance, no import, no validate.
# One LAR per asset (per-asset mode) or one LAR for everything (--batch-mode bundled).
lfimex --assets all --export-only
lfimex --assets documents_and_media --export-only
lfimex --assets blogs,web_content --export-only --batch-mode bundled

# Full export → import flow but skip the DB-level comparison.
# Useful as a plain migration pipeline.
lfimex --skip-validation

# Reuse the source company (no fresh instance) — fastest, but everything happens
# inside the source. Validation compares the source site to a freshly created
# sibling site.
lfimex --instance-mode reuse --cleanup

# Date-range scoped export.
lfimex --assets documents_and_media --filter date-range \
       --from-date 2023-12-01 --to-date 2026-05-13

# Drop one specific check known to be a false positive on this corpus.
# Pattern: '<test>:<check label substring>' or '*:<check label substring>'.
lfimex --assets documents_and_media \
       --ignore-tests 'documents_and_media:DLFileEntryType – Identifiers'

# Import into an existing company on the same portal (created by an earlier
# `lfimex` run, or any company you can address by Company.webId). Forces
# reuse mode and routes site creation / import / cleanup at that company's
# primary virtual host. Credentials default to the lfimex create convention
# `test@<webId>` / `test`; set TARGET_USERNAME / TARGET_PASSWORD if the
# target company uses different admin creds.
lfimex --assets style_books \
       --target-company-web-id importtest-20260519-095507.localhost

# Iterate against a pre-existing site without re-creating it on every run.
# --target-group-id pins the destination site (skips site create + cleanup);
# MIRROR_OVERWRITE re-applies the source state in place so reruns converge.
lfimex --assets web_content \
       --target-group-id 20127 \
       --import-strategy DATA_STRATEGY_MIRROR_OVERWRITE

# Cross-company re-import into a fixed site — combine both flags. Useful
# when developing a single asset's validation test against a long-lived
# target site that lives in another company.
lfimex --assets blogs \
       --target-company-web-id importtest-20260519-095507.localhost \
       --target-group-id 20127 \
       --import-strategy DATA_STRATEGY_MIRROR_OVERWRITE

```

### Subset selection

`--assets` and `--global-assets` accept `all`, exclusion (`all,-blogs`), or an explicit list.

```bash
# All site assets except blogs and wiki.
lfimex --assets 'all,-blogs,-wiki'

# Only migrate Custom Fields and Web Content at the Global level.
lfimex --global-assets 'custom_fields,web_content'
```

## Configuration

Everything is in `config/config.sh` (per-developer, gitignored). Override anything per-run with an env var:

```bash
SOURCE_GROUP_ID=10182 INSTANCE_MODE=reuse lfimex --assets blogs
```

Key variables:

| Variable | Purpose |
|---|---|
| `BASE_URL`, `USERNAME`, `PASSWORD` | Source portal + admin credentials |
| `SOURCE_COMPANY_WEB_ID`, `SOURCE_GROUP_ID` | Source site identity |
| `TARGET_COMPANY_WEB_ID`, `TARGET_GROUP_ID` | Target company / pre-existing site (also `--target-company-web-id` / `--target-group-id`) |
| `TARGET_BASE_URL`, `TARGET_USERNAME`, `TARGET_PASSWORD` | Target portal routing + admin creds. In cross-company reuse they default to `http://<webId>:<port>` and `test@<webId>` / `test` (the lfimex create convention); pin them if the target company uses different creds. |
| `SRC_DB_*`, `TGT_DB_*` | Source / target MySQL connection |
| `BUNDLES_DIR` | Local Liferay bundle (used for log capture, OSGi configs) |
| `ASSETS`, `GLOBAL_ASSETS`, `EXTRA_TESTS`, `IGNORE_TESTS` | Run defaults the CLI flags can override |
| `INSTANCE_MODE`, `BATCH_MODE`, `CLEANUP_INSTANCE` | Pipeline shape |
| `COPY_OSGI_CONFIGS` | OSGi config drop (see below) |

`SOURCE_PLID` (any Layout in the source company) is auto-derived from `SOURCE_GROUP_ID` at startup, so you don't need to set it. Override only if the lookup picks a layout you don't want.

The supported asset catalog lives in `config/asset_catalog.sh` (checked into git) — that's the registry of `asset_register` and `global_register` calls. Edit it to add or comment out support for a portlet's data.

### OSGi configs (large LAR uploads, indexer tuning)

Liferay's default upload cap is 100 MB per request, which Web Content and Documents and Media LARs routinely exceed. The import POST then fails with *"Please enter a file with a valid file size no larger than 100.0MB"* and no amount of retrying helps until that limit is raised.

`config/osgi/` ships ready-made config files for the common gotchas:

| File | What it does |
|---|---|
| `UploadServletRequestConfiguration.config` | Raises `maxSize` from 100 MB to ~24 GB so big LARs can be uploaded |
| `ExportImportServiceConfiguration.config` | Per-LAR export/import sizing overrides |
| `IndexWriterHelperConfiguration.config` | Skip background reindexing during a large import |

Pass `--copy-osgi-configs` (or set `COPY_OSGI_CONFIGS=1` in `config/config.sh`) to have lfimex copy everything in `${OSGI_CONFIGS_DIR}` (default `config/osgi/`) into `${BUNDLES_DIR}/osgi/configs/` as Step 0 of the run. 

## Results

Each run writes to `results/<RUN_ID>/`:

- `*.lar` — exported LAR files
- `summary.tsv` — per-step status + LOG counts (one row per step)
- `*.bundle.log` — captured `ERROR`/`WARN` blocks from `liferay.<date>.log` during that step
- `validate_*.compare.log` — full per-test diff output (only when validation runs)

A formatted summary table is also printed to stdout at the end of every run, with a final `STATUS: PASS | WARN | FAIL` verdict.

## Adding a new validation test

1. Create `lib/tests/<name>.sh` defining `test_<name>()`.
2. Use the `check "<label>" "<sql>"` helper. Substitute `__GROUPID__` and `__COMPANYID__` in SQL — `compare.sh` resolves them per side.
3. Always filter `ctCollectionId = 0` to exclude Publications drafts.
4. Add `$(date_filter <column>)` after every `WHERE` clause so `--filter date-range` actually narrows the scope.
5. Either:
   - Register the test against an asset (catalog: 5th arg of `asset_register`), or
   - Add the test name to `EXTRA_TESTS` for a site-wide pass.

Example:

```bash
test_example() {
    section "EXAMPLE"

    check "ExampleTable – Total count" "
        SELECT COUNT(*) AS total
        FROM ExampleTable
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate);
    "
}
```

## Standalone DB comparison

`lib/compare.sh` is the diff engine; `lfimex` invokes it as the validation step. You can also run it directly against two existing sites without going through the export/import pipeline:

```bash
lib/compare.sh --source-site guest --target-site imported-site-20260513
```

Full log lands in a `/tmp/lfimex-compare-*.log` file (or `LOG_FILE=/path/...` to override).

## Notes

- Empty queries / `NULL` vs `""` are normalized as equivalent.
- Generated IDs are never compared across environments — checks use `uuid_`, `externalReferenceCode`, or natural keys.
- Version numbers are excluded (Liferay resets them to 1 on import).
- `LIFERAY_LOG_IGNORE_REGEX` masks known Liferay log false positives during bundle-log capture.
