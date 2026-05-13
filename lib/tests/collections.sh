# =============================================================================
# Test: COLLECTIONS  (AssetListEntry)
# Tables: AssetListEntry, AssetListEntryAssetEntryRel,
#         AssetListEntrySegmentsEntryRel,
#         AssetEntry, SegmentsEntry, ClassName_
# =============================================================================
# AssetListEntry type_ values:
#   0 = Manual   (static, explicitly selected assets)
#   1 = Dynamic  (criteria-based)
# =============================================================================

test_collections() {
    section "COLLECTIONS"

    # =========================================================================
    # AssetListEntry
    # =========================================================================

    check "AssetListEntry – Total count" "
        SELECT
            COUNT(*)    AS total
        FROM AssetListEntry
        WHERE groupId = __GROUPID__
         AND ctCollectionId = 0;
    "

    check "AssetListEntry – Count by type" "
        SELECT
            type_,
            COUNT(*)        AS total
        FROM AssetListEntry
        WHERE groupId = __GROUPID__
         AND ctCollectionId = 0
        GROUP BY type_
        ORDER BY type_;
    "

    check "AssetListEntry – Identifiers" "
        SELECT
            assetListEntryKey,
            externalReferenceCode,
            uuid_
        FROM AssetListEntry
        WHERE groupId = __GROUPID__
         AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    check "AssetListEntry – Title" "
        SELECT
            externalReferenceCode,
            title
        FROM AssetListEntry
        WHERE groupId = __GROUPID__
         AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    check "AssetListEntry – Core fields" "
        SELECT
            externalReferenceCode,
            type_,
            assetEntryType
        FROM AssetListEntry
        WHERE groupId = __GROUPID__
         AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    check "AssetListEntry – Asset type and subtype" "
        SELECT
            ale.externalReferenceCode,
            ale.assetEntryType,
            CASE
                WHEN ale.assetEntryType = 'com.liferay.journal.model.JournalArticle'
                    THEN COALESCE(
                        (SELECT structureKey FROM DDMStructure
                         WHERE structureId = ale.assetEntrySubtype AND ctCollectionId = 0),
                        '(any subtype)')
                WHEN ale.assetEntryType = 'com.liferay.document.library.kernel.model.DLFileEntry'
                    THEN COALESCE(
                        (SELECT fileEntryTypeKey FROM DLFileEntryType
                         WHERE fileEntryTypeId = ale.assetEntrySubtype AND ctCollectionId = 0),
                        '(any subtype)')
                WHEN ale.assetEntryType = 'com.liferay.blogs.model.BlogsEntry'
                    THEN '(no subtype)'
                WHEN ale.assetEntryType = 'com.liferay.asset.kernel.model.AssetEntry'
                    THEN '(no subtype)'
                WHEN ale.assetEntrySubtype IS NULL
                    THEN '(any subtype)'
                ELSE CONCAT('(unresolved assetEntrySubtype=', ale.assetEntrySubtype, ')')
            END                     AS subtype_key
        FROM AssetListEntry ale
        WHERE ale.groupId = __GROUPID__
           AND ale.ctCollectionId = 0
        ORDER BY ale.externalReferenceCode;
    "

    check "AssetListEntry – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM AssetListEntry
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    # =========================================================================
    # AssetListEntryAssetEntryRel
    # =========================================================================

    check "AssetListEntryAssetEntryRel – Total count" "
        SELECT
            ale.externalReferenceCode,
            COUNT(*)        AS total
        FROM AssetListEntry ale
        JOIN AssetListEntryAssetEntryRel rel
          ON rel.assetListEntryId = ale.assetListEntryId
             AND rel.ctCollectionId = 0
        WHERE ale.groupId = __GROUPID__
          AND ale.ctCollectionId = 0
        GROUP BY ale.externalReferenceCode
        ORDER BY ale.externalReferenceCode;
   "

    check "AssetListEntryAssetEntryRel – Identifiers" "
        SELECT
            uuid_
        FROM AssetListEntryAssetEntryRel
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    check "AssetListEntryAssetEntryRel – Dates" "
        SELECT
            uuid_,
            createDate,
            modifiedDate
        FROM AssetListEntryAssetEntryRel
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    check "AssetListEntryAssetEntryRel – Asset count per manual collection" "
        SELECT
            ale.externalReferenceCode,
            COUNT(*)        AS asset_count
        FROM AssetListEntry ale
        JOIN AssetListEntryAssetEntryRel rel
          ON rel.assetListEntryId = ale.assetListEntryId
             AND rel.ctCollectionId = 0
        WHERE ale.groupId = __GROUPID__
          AND ale.ctCollectionId = 0
          AND ale.type_   = 0
        GROUP BY ale.externalReferenceCode
        ORDER BY ale.externalReferenceCode;
    "

    check "AssetListEntryAssetEntryRel – Assets in manual collections" "
        SELECT
            ale.externalReferenceCode,
            cn.value            AS class_name,
            ae.classUuid        AS asset_uuid,
            rel.position
        FROM AssetListEntry ale
        JOIN AssetListEntryAssetEntryRel rel
          ON rel.assetListEntryId = ale.assetListEntryId
             AND rel.ctCollectionId = 0
        JOIN AssetEntry ae
          ON ae.entryId = rel.assetEntryId
             AND ae.ctCollectionId = 0
        JOIN ClassName_ cn
          ON cn.classNameId = ae.classNameId
        WHERE ale.groupId = __GROUPID__
          AND ale.ctCollectionId = 0
          AND ale.type_   = 0
        ORDER BY ale.externalReferenceCode, rel.position;
    "

    # =========================================================================
    # AssetListEntrySegmentsEntryRel
    # =========================================================================

    check "AssetListEntrySegmentsEntryRel – Total count" "
        SELECT
            COUNT(*)        AS total
        FROM AssetListEntrySegmentsEntryRel
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0;
   "

    check "AssetListEntrySegmentsEntryRel – Priority" "
        SELECT
            uuid_,
            priority
        FROM AssetListEntrySegmentsEntryRel
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    check "AssetListEntrySegmentsEntryRel – Dates" "
        SELECT
            uuid_,
            createDate,
            modifiedDate
        FROM AssetListEntrySegmentsEntryRel
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    check "AssetListEntrySegmentsEntryRel – Personalized variation count" "
        SELECT
            ale.externalReferenceCode,
            COUNT(*)        AS variation_count
        FROM AssetListEntry ale
        JOIN AssetListEntrySegmentsEntryRel ser
          ON ser.assetListEntryId = ale.assetListEntryId
             AND ser.ctCollectionId = 0
        WHERE ale.groupId = __GROUPID__
          AND ale.ctCollectionId = 0
        GROUP BY ale.externalReferenceCode
        ORDER BY ale.externalReferenceCode;
    "

    check "AssetListEntrySegmentsEntryRel – Segment mappings" "
        SELECT
            ale.externalReferenceCode   AS collection_erc,
            se.segmentsEntryKey         AS segment_key,
            ser.priority
        FROM AssetListEntry ale
        JOIN AssetListEntrySegmentsEntryRel ser
          ON ser.assetListEntryId = ale.assetListEntryId
             AND ser.ctCollectionId = 0
        JOIN SegmentsEntry se
          ON se.segmentsEntryId = ser.segmentsEntryId
             AND se.ctCollectionId = 0
        WHERE ale.groupId = __GROUPID__
          AND ale.ctCollectionId = 0
        ORDER BY ale.externalReferenceCode, se.segmentsEntryKey;
    "
}
