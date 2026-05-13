# =============================================================================
# Test: TAGS
# Tables: AssetTag, AssetTagStats, ClassName_
# =============================================================================

test_tags() {
    section "TAGS"

    # =========================================================================
    # AssetTag
    # =========================================================================

    check "AssetTag – Total count" "
        SELECT
            COUNT(*)    AS total
        FROM AssetTag
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0;
    "

    check "AssetTag – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_
        FROM AssetTag
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    check "AssetTag – Names" "
        SELECT
            externalReferenceCode,
            name
        FROM AssetTag
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    check "AssetTag – Asset count" "
        SELECT
            name,
            assetCount
        FROM AssetTag
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
        ORDER BY name;
    "

    check "AssetTag – Dates" "
        SELECT
            name,
            createDate,
            modifiedDate
        FROM AssetTag
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
        ORDER BY name;
    "

    # =========================================================================
    # AssetTagStats
    # =========================================================================

    check "AssetTagStats – Asset count per tag per type" "
        SELECT
            t.name              AS tag_name,
            cn.value            AS class_name,
            ts.assetCount
        FROM AssetTag t
        JOIN AssetTagStats ts
          ON ts.tagId = t.tagId
        JOIN ClassName_ cn
          ON cn.classNameId = ts.classNameId
        WHERE t.groupId = __GROUPID__
            AND t.ctCollectionId = 0
        ORDER BY t.name, cn.value;
    "
}
