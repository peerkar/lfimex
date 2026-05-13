# =============================================================================
# Test: STYLE BOOKS
# Tables: StyleBookEntry, StyleBookEntryVersion, DLFileEntry (preview image)
# =============================================================================

test_style_books() {
    section "STYLE BOOKS"

    # =========================================================================
    # StyleBookEntry
    # =========================================================================

    check "StyleBookEntry – Total Count" "
        SELECT
            COUNT(*)            AS total
        FROM StyleBookEntry
        WHERE groupId = __GROUPID__
          AND head = 1
          AND ctCollectionId = 0
          $(date_filter modifiedDate);
    "

    check "StyleBookEntry – Identifiers" "
        SELECT
            styleBookEntryKey,
            externalReferenceCode,
            themeId,
            uuid_
        FROM StyleBookEntry
        WHERE groupId = __GROUPID__
          AND head = 1
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY styleBookEntryKey;
    "

    check "StyleBookEntry – Name" "
        SELECT
            styleBookEntryKey,
            name
        FROM StyleBookEntry
        WHERE groupId = __GROUPID__
          AND head = 1
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY styleBookEntryKey;
    "

    check "StyleBookEntry – Core fields" "
        SELECT
            styleBookEntryKey,
            defaultStyleBookEntry,
            themeId
        FROM StyleBookEntry
        WHERE groupId = __GROUPID__
          AND head = 1
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY styleBookEntryKey;
    "

    check "StyleBookEntry – Frontend token values checksum" "
        SELECT
            styleBookEntryKey,
            MD5(frontendTokensValues)       AS tokens_hash,
            LENGTH(frontendTokensValues)    AS tokens_length
        FROM StyleBookEntry
        WHERE groupId = __GROUPID__
          AND head = 1
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY styleBookEntryKey;
    "

    check "StyleBookEntry – Preview image" "
        SELECT
            sbe.styleBookEntryKey,
            dlfe.fileName       AS preview_file
        FROM StyleBookEntry sbe
        LEFT JOIN DLFileEntry dlfe
               ON dlfe.fileEntryId = sbe.previewFileEntryId
              AND sbe.previewFileEntryId > 0
              AND dlfe.ctCollectionId = 0
        WHERE sbe.groupId = __GROUPID__
          AND sbe.head = 1
          AND sbe.ctCollectionId = 0
          $(date_filter sbe.modifiedDate)
        ORDER BY sbe.styleBookEntryKey;
    "

    check "StyleBookEntry – Dates" "
        SELECT
            styleBookEntryKey,
            createDate,
            modifiedDate
        FROM StyleBookEntry
        WHERE groupId = __GROUPID__
          AND head = 1
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY styleBookEntryKey;
    "

    # =========================================================================
    # StyleBookEntryVersion
    # =========================================================================

    check "StyleBookEntryVersion – Latest version identifiers" "
        SELECT
            sbe.styleBookEntryKey,
            sbev.externalReferenceCode,
            sbev.themeId,
            sbev.uuid_
        FROM StyleBookEntry sbe
        JOIN StyleBookEntryVersion sbev
          ON sbev.styleBookEntryId = sbe.styleBookEntryId
             AND sbev.ctCollectionId = 0
        WHERE sbe.groupId          = __GROUPID__
          AND sbe.head             = 1
          AND sbe.ctCollectionId   = 0
          $(date_filter sbe.modifiedDate)
          AND sbev.version = (
              SELECT MAX(sbev2.version)
              FROM StyleBookEntryVersion sbev2
              WHERE sbev2.styleBookEntryId = sbe.styleBookEntryId
                AND sbev2.ctCollectionId   = 0
          )
        ORDER BY sbe.styleBookEntryKey;
    "

    check "StyleBookEntryVersion – Latest version name" "
        SELECT
            sbe.styleBookEntryKey,
            sbev.name
        FROM StyleBookEntry sbe
        JOIN StyleBookEntryVersion sbev
          ON sbev.styleBookEntryId = sbe.styleBookEntryId
             AND sbev.ctCollectionId = 0
        WHERE sbe.groupId          = __GROUPID__
          AND sbe.head             = 1
          AND sbe.ctCollectionId   = 0
          $(date_filter sbe.modifiedDate)
          AND sbev.version = (
              SELECT MAX(sbev2.version)
              FROM StyleBookEntryVersion sbev2
              WHERE sbev2.styleBookEntryId = sbe.styleBookEntryId
                AND sbev2.ctCollectionId   = 0
          )
        ORDER BY sbe.styleBookEntryKey;
    "

    check "StyleBookEntryVersion – Latest version token checksum" "
        SELECT
            sbe.styleBookEntryKey,
            MD5(sbev.frontendTokensValues)      AS tokens_hash,
            LENGTH(sbev.frontendTokensValues)   AS tokens_length
        FROM StyleBookEntry sbe
        JOIN StyleBookEntryVersion sbev
          ON sbev.styleBookEntryId = sbe.styleBookEntryId
             AND sbev.ctCollectionId = 0
        WHERE sbe.groupId          = __GROUPID__
          AND sbe.head             = 1
          AND sbe.ctCollectionId   = 0
          $(date_filter sbe.modifiedDate)
          AND sbev.version = (
              SELECT MAX(sbev2.version)
              FROM StyleBookEntryVersion sbev2
              WHERE sbev2.styleBookEntryId = sbe.styleBookEntryId
                AND sbev2.ctCollectionId   = 0
          )
        ORDER BY sbe.styleBookEntryKey;
    "
}
