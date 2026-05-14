# =============================================================================
# Test: ASSET CATEGORIES & VOCABULARIES
# Tables: AssetVocabulary, AssetCategory, ClassName_
# =============================================================================

test_categories() {
    section "CATEGORIES & VOCABULARIES"

    # =========================================================================
    # AssetVocabulary
    # =========================================================================

    check "AssetVocabulary – Total Count" "
        SELECT
            COUNT(*)        AS total
        FROM AssetVocabulary
        WHERE groupId          = __GROUPID__
          AND ctCollectionId   = 0
          $(date_filter modifiedDate);
    "

    check "AssetVocabulary – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_
        FROM AssetVocabulary
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "AssetVocabulary – Names" "
        SELECT
            externalReferenceCode,
            name
        FROM AssetVocabulary
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "AssetVocabulary – Title and description" "
        SELECT
            externalReferenceCode,
            REGEXP_REPLACE(title, '<[^>]+>', '')    AS title_plain,
            MD5(description)                        AS description_md5,
            LENGTH(description)                     AS description_len
        FROM AssetVocabulary
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "AssetVocabulary – Core fields" "
        SELECT
            externalReferenceCode,
            visibilityType,
            status
        FROM AssetVocabulary
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "AssetVocabulary – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM AssetVocabulary
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    # =========================================================================
    # AssetCategory
    # =========================================================================

    check "AssetCategory – Total Count" "
        SELECT
            COUNT(*)        AS total
        FROM AssetCategory
        WHERE groupId          = __GROUPID__
          AND ctCollectionId   = 0
          $(date_filter modifiedDate);
    "

    check "AssetCategory – Count per vocabulary" "
        SELECT
            v.externalReferenceCode              AS vocabulary_external_reference_code,
            COUNT(*)            AS category_count
        FROM AssetVocabulary v
        JOIN AssetCategory c
          ON c.vocabularyId    = v.vocabularyId
             AND c.ctCollectionId = 0
        WHERE v.groupId        = __GROUPID__
          AND v.ctCollectionId = 0
          $(date_filter c.modifiedDate)
        GROUP BY v.externalReferenceCode
        ORDER BY v.externalReferenceCode;
    "

    check "AssetCategory – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_
        FROM AssetCategory
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "AssetCategory – Name" "
        SELECT
            externalReferenceCode,
            name
        FROM AssetCategory
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "AssetCategory – Title and description" "
        SELECT
            externalReferenceCode,
            REGEXP_REPLACE(title, '<[^>]+>', '')    AS title_plain,
            MD5(description)                        AS description_md5,
            LENGTH(description)                     AS description_len
        FROM AssetCategory
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "AssetCategory – Core fields" "
        SELECT
            externalReferenceCode,
            status
        FROM AssetCategory
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "AssetCategory – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM AssetCategory
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "AssetCategory – Count by depth per vocabulary" "
        SELECT
            v.externalReferenceCode              AS vocabulary_external_reference_code,
            c.parentCategoryId  = 0 AS is_root,
            COUNT(*)            AS category_count
        FROM AssetVocabulary v
        JOIN AssetCategory c
          ON c.vocabularyId    = v.vocabularyId
             AND c.ctCollectionId = 0
        WHERE v.groupId        = __GROUPID__
          AND v.ctCollectionId = 0
          $(date_filter c.modifiedDate)
        GROUP BY v.externalReferenceCode, is_root
        ORDER BY v.externalReferenceCode, is_root DESC;
    "

    check "AssetCategory – Names and hierarchy" "
        SELECT
            v.externalReferenceCode AS vocabulary_erc,
            c.externalReferenceCode AS category_erc,
            c.name              AS category_name,
            COALESCE(p.externalReferenceCode, '(root)') AS parent_erc
        FROM AssetVocabulary v
        JOIN AssetCategory c
          ON c.vocabularyId    = v.vocabularyId
             AND c.ctCollectionId  = 0
        LEFT JOIN AssetCategory p
          ON p.categoryId      = c.parentCategoryId
             AND p.ctCollectionId  = 0
        WHERE v.groupId        = __GROUPID__
          AND v.ctCollectionId = 0
          $(date_filter c.modifiedDate)
        ORDER BY v.externalReferenceCode, c.externalReferenceCode;
    "

    check "AssetCategory – Asset count per category" "
        SELECT
            v.name              AS vocabulary_name,
            c.name              AS category_name,
            COUNT(rel.assetEntryId)  AS asset_count
        FROM AssetVocabulary v
        JOIN AssetCategory c
          ON c.vocabularyId    = v.vocabularyId
             AND c.ctCollectionId  = 0
        LEFT JOIN AssetEntryAssetCategoryRel rel
          ON rel.assetCategoryId    = c.categoryId
             AND rel.ctCollectionId = 0
        WHERE v.groupId        = __GROUPID__
          AND v.ctCollectionId = 0
          $(date_filter c.modifiedDate)
        GROUP BY v.name, c.name
        ORDER BY v.name, c.name;
    "

    check "AssetCategory – Linked class types" "
        SELECT
            v.externalReferenceCode    AS vocabulary_external_reference_code,
            cn.value            AS class_name,
            COUNT(*)            AS asset_count
        FROM AssetVocabulary v
        JOIN AssetCategory c
          ON c.vocabularyId    = v.vocabularyId
             AND c.ctCollectionId = 0
        JOIN AssetEntryAssetCategoryRel rel
          ON rel.assetCategoryId    = c.categoryId
             AND rel.ctCollectionId = 0
        JOIN AssetEntry ae
          ON ae.entryId        = rel.assetEntryId
             AND ae.ctCollectionId = 0
        JOIN ClassName_ cn
          ON cn.classNameId    = ae.classNameId
        WHERE v.groupId        = __GROUPID__
          AND v.ctCollectionId = 0
          $(date_filter c.modifiedDate)
        GROUP BY v.externalReferenceCode, cn.value
        ORDER BY v.externalReferenceCode, cn.value;
    "
}
