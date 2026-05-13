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
          AND ctCollectionId = 0;
    "

    check "FragmentCollection – Identifiers" "
        SELECT
            fragmentCollectionKey,
            externalReferenceCode,
            uuid_
        FROM FragmentCollection
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
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
          AND ctCollectionId = 0;
    "

    check "FragmentComposition – Identifiers" "
        SELECT
            fragmentCompositionKey,
            externalReferenceCode,
            uuid_
        FROM FragmentComposition
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
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
        ORDER BY externalReferenceCode;
    "

    check "FragmentEntry – Core fields" "
        SELECT
            fe.externalReferenceCode,
            fcol.fragmentCollectionKey,
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
        ORDER BY fe.externalReferenceCode;
    "

    check "FragmentEntry – Content checksums" "
        SELECT
            externalReferenceCode,
            MD5(html)               AS html_hash,
            LENGTH(html)            AS html_len,
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
        ORDER BY externalReferenceCode;
    "

    check "FragmentEntry – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM FragmentEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND fragmentCollectionId != 0
          AND head           = 1
        ORDER BY externalReferenceCode;
    "

    # =========================================================================
    # FragmentEntryLink
    # =========================================================================

    check "FragmentEntryLink – Total count" "
        SELECT
            COUNT(*)        AS total_entry_links
        FROM FragmentEntryLink
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0;
    "

    check "FragmentEntryLink – Count per fragment" "
        SELECT
            fel.fragmentEntryERC,
            COUNT(*)        AS link_count
        FROM FragmentEntryLink fel
        WHERE fel.groupId        = __GROUPID__
          AND fel.ctCollectionId = 0
          AND fel.fragmentEntryERC IS NOT NULL
        GROUP BY fel.fragmentEntryERC
        ORDER BY fel.fragmentEntryERC;
    "

    check "FragmentEntryLink – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_
        FROM FragmentEntryLink
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    check "FragmentEntryLink – Core fields" "
        SELECT
            fel.externalReferenceCode,
            fel.fragmentEntryERC,
            fel.originalFragmentEntryLinkERC,
            COALESCE(fel.rendererKey, '') AS renderer_key,
            fel.position,
            fel.type_,
            fel.namespace
        FROM FragmentEntryLink fel
        WHERE fel.groupId        = __GROUPID__
          AND fel.ctCollectionId = 0
        ORDER BY fel.externalReferenceCode;
    "

    check "FragmentEntryLink – Editable values checksum" "
        SELECT
            externalReferenceCode,
            MD5(editableValues)     AS editable_values_hash,
            LENGTH(editableValues)  AS editable_values_length
        FROM FragmentEntryLink
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    check "FragmentEntryLink – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM FragmentEntryLink
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "
}
