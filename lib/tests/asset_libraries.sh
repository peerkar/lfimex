# =============================================================================
# Test: ASSET LIBRARIES
# Related Tables: DepotEntry, DepotEntryGroupRel, Group_,
#         DLFolder, DLFileEntry,
#         DDMStructure, DDMTemplate, ClassName_
# =============================================================================

test_asset_libraries() {
    section "ASSET LIBRARIES"

    # =========================================================================
    # DepotEntry
    # =========================================================================

    check "DepotEntry – Total count" "
        SELECT
            COUNT(*)    AS total
        FROM DepotEntry
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            $(date_filter modifiedDate);
    "

    check "DepotEntry – Total count by type" "
        SELECT
            type_,
            COUNT(*)        AS total
        FROM DepotEntry
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            $(date_filter modifiedDate)
        GROUP BY type_
        ORDER BY type_;
    "

    check "DepotEntry – Identifiers" "
        SELECT
            uuid_
        FROM DepotEntry
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            $(date_filter modifiedDate)
        ORDER BY uuid_;
    "

    check "DepotEntry – Dates" "
        SELECT
            uuid_,
            createDate,
            modifiedDate
        FROM DepotEntry
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            $(date_filter modifiedDate)
        ORDER BY uuid_;
    "

    # =========================================================================
    # DepotEntryGroupRel
    # =========================================================================

    check "DepotEntryGroupRel – Total count" "
        SELECT
            COUNT(*)    AS total
        FROM DepotEntryGroupRel rel
        JOIN DepotEntry de
          ON de.depotEntryId = rel.depotEntryId
             AND de.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND rel.ctCollectionId = 0
            $(date_filter rel.modifiedDate);
    "

    check "DepotEntryGroupRel – Identifiers" "
        SELECT
            rel.uuid_
        FROM DepotEntryGroupRel rel
        JOIN DepotEntry de
          ON de.depotEntryId = rel.depotEntryId
             AND de.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND rel.ctCollectionId = 0
            $(date_filter rel.modifiedDate)
        ORDER BY rel.uuid_;
    "

    check "DepotEntryGroupRel – Core fields" "
        SELECT
            rel.uuid_,
            rel.ddmStructuresAvailable,
            rel.searchable,
            rel.type_
        FROM DepotEntryGroupRel rel
        JOIN DepotEntry de
          ON de.depotEntryId = rel.depotEntryId
             AND de.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND rel.ctCollectionId = 0
            $(date_filter rel.modifiedDate)
        ORDER BY rel.uuid_;
    "

    check "DepotEntryGroupRel – Site connections per library" "
        SELECT
            de.uuid_,
            g.groupKey                              AS connected_site_key
        FROM DepotEntry de
        JOIN DepotEntryGroupRel rel
          ON rel.depotEntryId = de.depotEntryId
             AND rel.ctCollectionId = 0
        JOIN Group_ g
          ON g.groupId = rel.toGroupId
        WHERE de.groupId = __GROUPID__
            AND de.ctCollectionId = 0
            $(date_filter rel.modifiedDate)
        ORDER BY de.uuid_, g.groupKey;
    "

    check "DepotEntryGroupRel – Dates" "
        SELECT
            rel.uuid_,
            rel.createDate,
            rel.modifiedDate
        FROM DepotEntryGroupRel rel
        JOIN DepotEntry de
          ON de.depotEntryId = rel.depotEntryId
             AND de.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND rel.ctCollectionId = 0
            $(date_filter rel.modifiedDate)
        ORDER BY rel.uuid_;
    "

    # =========================================================================
    # DLFolder
    # =========================================================================

    check "DLFolder – Folder count per library" "
        SELECT
            de.uuid_,
            COUNT(*)        AS folder_count
        FROM DepotEntry de
        JOIN Group_ g
          ON g.groupId = de.groupId
        JOIN DLFolder dlf
          ON dlf.groupId = g.groupId
             AND dlf.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND de.ctCollectionId = 0
            $(date_filter dlf.modifiedDate)
        GROUP BY de.uuid_
        ORDER BY de.uuid_;
    "

    # =========================================================================
    # DLFileEntry
    # =========================================================================

    check "DLFileEntry – File count per library" "
        SELECT
            de.uuid_,
            COUNT(*)        AS file_count
        FROM DepotEntry de
        JOIN Group_ g
          ON g.groupId = de.groupId
        JOIN DLFileEntry dlfe
          ON dlfe.groupId = g.groupId
             AND dlfe.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND de.ctCollectionId = 0
            $(date_filter dlfe.modifiedDate)
        GROUP BY de.uuid_
        ORDER BY de.uuid_;
    "

    check "DLFileEntry – Identifiers" "
        SELECT
            dlfe.uuid_,
            dlfe.externalReferenceCode,
            dlfe.fileName
        FROM DepotEntry de
        JOIN Group_ g
          ON g.groupId = de.groupId
        JOIN DLFileEntry dlfe
          ON dlfe.groupId = g.groupId
             AND dlfe.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND de.ctCollectionId = 0
            $(date_filter dlfe.modifiedDate)
        ORDER BY dlfe.externalReferenceCode;
    "

    check "DLFileEntry – Title and description" "
        SELECT
            dlfe.externalReferenceCode,
            dlfe.title,
            MD5(dlfe.description)                   AS description_md5,
            LENGTH(dlfe.description)                AS description_len
        FROM DepotEntry de
        JOIN Group_ g
          ON g.groupId = de.groupId
        JOIN DLFileEntry dlfe
          ON dlfe.groupId = g.groupId
             AND dlfe.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND de.ctCollectionId = 0
            $(date_filter dlfe.modifiedDate)
        ORDER BY dlfe.externalReferenceCode;
    "

    check "DLFileEntry – Core fields" "
        SELECT
            dlfe.externalReferenceCode,
            dlfe.fileName,
            dlfe.mimeType,
            dlfe.extension,
            dlfe.size_
        FROM DepotEntry de
        JOIN Group_ g
          ON g.groupId = de.groupId
        JOIN DLFileEntry dlfe
          ON dlfe.groupId = g.groupId
             AND dlfe.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND de.ctCollectionId = 0
            $(date_filter dlfe.modifiedDate)
        ORDER BY dlfe.externalReferenceCode;
    "

    check "DLFileEntry – Dates" "
        SELECT
            dlfe.externalReferenceCode,
            dlfe.createDate,
            dlfe.modifiedDate
        FROM DepotEntry de
        JOIN Group_ g
          ON g.groupId = de.groupId
        JOIN DLFileEntry dlfe
          ON dlfe.groupId = g.groupId
             AND dlfe.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND de.ctCollectionId = 0
            $(date_filter dlfe.modifiedDate)
        ORDER BY dlfe.externalReferenceCode;
    "

    # =========================================================================
    # DDMStructure
    # =========================================================================

    check "DDMStructure – Structure count per library" "
        SELECT
            de.uuid_,
            COUNT(*)        AS structure_count
        FROM DepotEntry de
        JOIN Group_ g
          ON g.groupId = de.groupId
        JOIN DDMStructure ds
          ON ds.groupId = g.groupId
             AND ds.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND de.ctCollectionId = 0
            $(date_filter ds.modifiedDate)
        GROUP BY de.uuid_
        ORDER BY de.uuid_;
    "

    check "DDMStructure – Identifiers" "
        SELECT
            ds.structureKey,
            ds.externalReferenceCode
        FROM DepotEntry de
        JOIN Group_ g
          ON g.groupId = de.groupId
        JOIN DDMStructure ds
          ON ds.groupId = g.groupId
             AND ds.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND de.ctCollectionId = 0
            $(date_filter ds.modifiedDate)
        ORDER BY ds.externalReferenceCode;
    "

    check "DDMStructure – Name and description" "
        SELECT
            ds.externalReferenceCode,
            REGEXP_REPLACE(ds.name, '<[^>]+>', '')          AS structure_name,
            MD5(ds.description)                             AS description_md5,
            LENGTH(ds.description)                          AS description_len
        FROM DepotEntry de
        JOIN Group_ g
          ON g.groupId = de.groupId
        JOIN DDMStructure ds
          ON ds.groupId = g.groupId
             AND ds.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND de.ctCollectionId = 0
            $(date_filter ds.modifiedDate)
        ORDER BY ds.externalReferenceCode;
    "

    check "DDMStructure – Content integrity" "
        SELECT
            ds.externalReferenceCode,
            MD5(ds.definition)                              AS definition_md5,
            LENGTH(ds.definition)                           AS definition_len
        FROM DepotEntry de
        JOIN Group_ g
          ON g.groupId = de.groupId
        JOIN DDMStructure ds
          ON ds.groupId = g.groupId
             AND ds.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND de.ctCollectionId = 0
            $(date_filter ds.modifiedDate)
        ORDER BY ds.externalReferenceCode;
    "

    check "DDMStructure – Dates" "
        SELECT
            ds.externalReferenceCode,
            ds.createDate,
            ds.modifiedDate
        FROM DepotEntry de
        JOIN Group_ g
          ON g.groupId = de.groupId
        JOIN DDMStructure ds
          ON ds.groupId = g.groupId
             AND ds.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND de.ctCollectionId = 0
            $(date_filter ds.modifiedDate)
        ORDER BY ds.externalReferenceCode;
    "

    # =========================================================================
    # DDMTemplate
    # =========================================================================

    check "DDMTemplate – Template count per library" "
        SELECT
            de.uuid_,
            COUNT(*)        AS template_count
        FROM DepotEntry de
        JOIN Group_ g
          ON g.groupId = de.groupId
        JOIN DDMTemplate dt
          ON dt.groupId = g.groupId
             AND dt.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND de.ctCollectionId = 0
            $(date_filter dt.modifiedDate)
        GROUP BY de.uuid_
        ORDER BY de.uuid_;
    "

    check "DDMTemplate – Identifiers" "
        SELECT
            dt.templateKey,
            dt.externalReferenceCode
        FROM DepotEntry de
        JOIN Group_ g
          ON g.groupId = de.groupId
        JOIN DDMTemplate dt
          ON dt.groupId = g.groupId
             AND dt.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND de.ctCollectionId = 0
            $(date_filter dt.modifiedDate)
        ORDER BY dt.externalReferenceCode;
    "

    check "DDMTemplate – Name and description" "
        SELECT
            dt.externalReferenceCode,
            REGEXP_REPLACE(dt.name, '<[^>]+>', '')          AS template_name,
            MD5(dt.description)                             AS description_md5,
            LENGTH(dt.description)                          AS description_len
        FROM DepotEntry de
        JOIN Group_ g
          ON g.groupId = de.groupId
        JOIN DDMTemplate dt
          ON dt.groupId = g.groupId
             AND dt.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND de.ctCollectionId = 0
            $(date_filter dt.modifiedDate)
        ORDER BY dt.externalReferenceCode;
    "

    check "DDMTemplate – Core fields" "
        SELECT
            dt.externalReferenceCode,
            dt.type_,
            dt.mode_,
            dt.language,
            dt.cacheable
        FROM DepotEntry de
        JOIN Group_ g
          ON g.groupId = de.groupId
        JOIN DDMTemplate dt
          ON dt.groupId = g.groupId
             AND dt.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND de.ctCollectionId = 0
            $(date_filter dt.modifiedDate)
        ORDER BY dt.externalReferenceCode;
    "

    check "DDMTemplate – Content integrity" "
        SELECT
            dt.externalReferenceCode,
            MD5(dt.script)                                  AS script_md5,
            LENGTH(dt.script)                               AS script_len
        FROM DepotEntry de
        JOIN Group_ g
          ON g.groupId = de.groupId
        JOIN DDMTemplate dt
          ON dt.groupId = g.groupId
             AND dt.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND de.ctCollectionId = 0
            $(date_filter dt.modifiedDate)
        ORDER BY dt.externalReferenceCode;
    "

    check "DDMTemplate – Dates" "
        SELECT
            dt.externalReferenceCode,
            dt.createDate,
            dt.modifiedDate
        FROM DepotEntry de
        JOIN Group_ g
          ON g.groupId = de.groupId
        JOIN DDMTemplate dt
          ON dt.groupId = g.groupId
             AND dt.ctCollectionId = 0
        WHERE de.groupId = __GROUPID__
            AND de.ctCollectionId = 0
            $(date_filter dt.modifiedDate)
        ORDER BY dt.externalReferenceCode;
    "
}
