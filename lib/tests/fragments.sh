# =============================================================================
# Test: FRAGMENTS
# Tables: FragmentCollection, FragmentComposition, FragmentEntry,
#         FragmentEntryLink
# =============================================================================
#
# FragmentEntry type_ values:
#   0 = Component
#   1 = React Component
#   2 = Section
# =============================================================================

test_fragments() {
    section "FRAGMENTS"

    # =========================================================================
    # FragmentCollection
    # =========================================================================

    check "FragmentCollection – Total count" "
        SELECT
            COUNT(*)        AS total_collections
        FROM FragmentCollection
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate);
    "

    # Identifiers compares externalReferenceCode only. fragmentCollectionKey
    # and uuid_ both drift across environments:
    #   * fragmentCollectionKey is user-mutable — admins prefix-rename to
    #     deprecate ('z---(do-not-use)-foo') or reorder ('aaa---foo'), or
    #     suffix-rename for disambiguation ('atb-master' → 'atb-master-0').
    #     The LAR ships the source key, but if the target already has a
    #     collection at that key (e.g. from an earlier import run), the
    #     import keeps the existing key on its side. Comparing keys then
    #     surfaces every renamed collection as a phantom diff.
    #   * uuid_ matches ERC 1:1 here so it adds no information.
    # ERC is the stable identifier the LAR uses for upsert semantics, so
    # comparing just ERC is sufficient to verify the collection set
    # round-tripped.
    check "FragmentCollection – Identifiers" "
        SELECT
            externalReferenceCode
        FROM FragmentCollection
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "FragmentCollection – Names and descriptions" "
        SELECT
            externalReferenceCode,
            name,
            REGEXP_REPLACE(name,        '<[^>]+>', '') AS name_plain,
            MD5(NULLIF(description, ''))                AS description_md5,
            LENGTH(NULLIF(description, ''))             AS description_len
        FROM FragmentCollection
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "FragmentCollection – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM FragmentCollection
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    # =========================================================================
    # FragmentComposition
    # =========================================================================

    check "FragmentComposition – Total count" "
        SELECT
            COUNT(*)        AS total_compositions
        FROM FragmentComposition
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate);
    "

    check "FragmentComposition – Identifiers" "
        SELECT
            fragmentCompositionKey,
            externalReferenceCode,
            uuid_
        FROM FragmentComposition
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "FragmentComposition – Names and descriptions" "
        SELECT
            externalReferenceCode,
            name,
            MD5(NULLIF(description, ''))                AS description_md5,
            LENGTH(NULLIF(description, ''))             AS description_len
        FROM FragmentComposition
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "FragmentComposition – Core fields" "
        SELECT
            fc.externalReferenceCode,
            fcol.fragmentCollectionKey,
            fc.status
        FROM FragmentComposition fc
        JOIN FragmentCollection fcol
          ON fcol.fragmentCollectionId = fc.fragmentCollectionId
             AND fcol.ctCollectionId   = 0
        WHERE fc.groupId        = __GROUPID__
          AND fc.ctCollectionId = 0
          $(date_filter fc.modifiedDate)
        ORDER BY fc.externalReferenceCode;
    "

    check "FragmentComposition – Data checksum" "
        SELECT
            externalReferenceCode,
            MD5(data_)      AS data_hash,
            LENGTH(data_)   AS data_length
        FROM FragmentComposition
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "FragmentComposition – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM FragmentComposition
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    # =========================================================================
    # FragmentEntry
    # =========================================================================

    check "FragmentEntry – Total count" "
        SELECT
            COUNT(*)        AS total_entries
        FROM FragmentEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND fragmentCollectionId != 0
          AND head           = 1
          $(date_filter modifiedDate)
    "

    check "FragmentEntry – Count by type" "
        SELECT
            type_,
            COUNT(*)        AS total
        FROM FragmentEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND fragmentCollectionId != 0
          AND head           = 1
          AND status = 0
          $(date_filter modifiedDate)
        GROUP BY type_
        ORDER BY type_;
    "

    check "FragmentEntry – Identifiers" "
        SELECT
            fragmentEntryKey,
            externalReferenceCode,
            uuid_
        FROM FragmentEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND fragmentCollectionId != 0
          AND head           = 1
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "FragmentEntry – Names" "
        SELECT
            externalReferenceCode,
            name
        FROM FragmentEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND fragmentCollectionId != 0
          AND head           = 1
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    # Join surfaces fcol.externalReferenceCode (stable) rather than
    # fragmentCollectionKey, which is user-mutable: admins rename
    # collections (e.g. prefix with 'z---(do-not-use)-' to deprecate or
    # 'aaa---' to reorder), and a target site can carry a different key
    # than source for the same logical collection (same ERC + uuid). The
    # ERC join key is what the LAR carries, so source and target line up
    # there.
    check "FragmentEntry – Core fields" "
        SELECT
            fe.externalReferenceCode,
            fcol.externalReferenceCode AS collection_erc,
            fe.type_,
            fe.cacheable,
            fe.status
        FROM FragmentEntry fe
        JOIN FragmentCollection fcol
          ON fcol.fragmentCollectionId = fe.fragmentCollectionId
             AND fcol.ctCollectionId   = 0
        WHERE fe.groupId        = __GROUPID__
          AND fe.ctCollectionId = 0
          AND fe.fragmentCollectionId != 0
          AND fe.head           = 1
          $(date_filter fe.modifiedDate)
        ORDER BY fe.externalReferenceCode;
    "

    # Friendly-URL normalization on the html column: Liferay's fragment
    # import runs a content rewriter (FragmentEntryProcessor) that
    # remaps hardcoded /documents/d/<source-site-friendly-url>/ paths
    # to /documents/d/<target-site-friendly-url>/ — same mechanism that
    # also rewrites Layout asset references on the journal-article side.
    # On a real site this means a fragment with a placeholder image
    # 'src=".../documents/d/guest/placeholder-png?download=true"' lands
    # on target with 'src=".../documents/d/imported-site-foo/...'. Same
    # logical content, +N chars where N = target_key_length -
    # source_key_length. REGEXP_REPLACE collapses the site path segment
    # to '<SITE>' on both sides so the hash compares the fragment's
    # structure rather than the runtime-resolved URL.
    #
    # CSS / JS / configuration aren't subject to this rewrite (they
    # rarely hardcode document URLs), so they keep their raw MD5/LENGTH.
    check "FragmentEntry – Content checksums" "
        SELECT
            externalReferenceCode,
            MD5(REGEXP_REPLACE(html, '/documents/d/[^/\"]+/', '/documents/d/<SITE>/'))    AS html_hash,
            LENGTH(REGEXP_REPLACE(html, '/documents/d/[^/\"]+/', '/documents/d/<SITE>/')) AS html_len,
            MD5(css)                AS css_hash,
            LENGTH(css)             AS css_len,
            MD5(js)                 AS js_hash,
            LENGTH(js)              AS js_len,
            MD5(configuration)      AS configuration_hash,
            LENGTH(configuration)   AS configuration_len
        FROM FragmentEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND fragmentCollectionId != 0
          AND head           = 1
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    # Dates excludes modifiedDate: target rewrites it to the import
    # timestamp during persistence (same Liferay quirk DM and other
    # tests work around). createDate is preserved.
    check "FragmentEntry – Dates" "
        SELECT
            externalReferenceCode,
            createDate
        FROM FragmentEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND fragmentCollectionId != 0
          AND head           = 1
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    # =========================================================================
    # FragmentEntryLink
    # =========================================================================
    # FragmentEntryLink stores one row per (fragment instance, layout,
    # segments experience). Liferay creates fresh rows whenever a layout
    # is edited, a segments experience is added, or a fragment is moved —
    # without garbage-collecting the prior rows. Source therefore has
    # cumulative history; target only has the rows the LAR materializes
    # for the layouts that survived. Verified on the source data:
    #   * source: 53,092 rows  target: 39,741 rows  (after the same
    #     deleted=0 + approved-Layout filters), a 25% gap.
    # Counts of links, per-fragment link counts, per-row identifiers,
    # editable-values checksums, and dates are all dominated by this
    # accumulation. Six per-row checks used to live here (Total count,
    # Count per fragment, Identifiers, Core fields, Editable values
    # checksum, Dates) — each produced thousands to tens of thousands of
    # diff lines that measured Liferay's per-edit materialization
    # behavior, not migration correctness.
    #
    # The one actionable question we CAN ask of this table is "which
    # fragments are actually used on each side" — if a fragment ERC
    # appears in source's links but not target's, target's import lost
    # a usage (a page that referenced it failed to migrate, or the
    # fragment itself didn't import). Comparing DISTINCT fragmentEntryERC
    # surfaces that signal without buying into the per-instance counts.

    check "FragmentEntryLink – Fragments referenced" "
        SELECT
            DISTINCT fragmentEntryERC
        FROM FragmentEntryLink
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND deleted        = 0
          AND fragmentEntryERC IS NOT NULL
          AND fragmentEntryERC <> ''
          $(date_filter modifiedDate)
        ORDER BY fragmentEntryERC;
    "
}
