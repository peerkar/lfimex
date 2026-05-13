# =============================================================================
# Test: PAGE TEMPLATES
# Tables: Layout, LayoutPageTemplateEntry, LayoutPageTemplateCollection,
#         LayoutPageTemplateStructure, LayoutPageTemplateStructureRel,
#         LayoutUtilityPageEntry, ClassName_
# =============================================================================
#
# LayoutPageTemplateEntry type_ values:
#   0 = Page Template (Basic/Content page template)
#   1 = Display Page Template
#   3 = Master Page
#
# Page structure note:
#   LayoutPageTemplateStructure has no data_ column. Page content is stored
#   in LayoutPageTemplateStructureRel.data_, linked via
#   layoutPageTemplateStructureId and scoped by segmentsExperienceId.
#
# =============================================================================

test_page_templates() {
    section "PAGE"


    # =========================================================================
    # REGULAR SITE PAGES  (Layout)
    # =========================================================================

    check "Layout – Count by type and visibility" "
        SELECT
            type_,
            privateLayout,
            hidden_,
            COUNT(*)        AS total
        FROM Layout
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND status         = 0
          AND system_        = 0
        GROUP BY type_, privateLayout, hidden_;
    "

    check "Layout – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_,
            friendlyURL
        FROM Layout
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND status         = 0
          AND system_        = 0
        ORDER BY externalReferenceCode;
    "

    check "Layout – Names and titles" "
        SELECT
            l.externalReferenceCode,
            GROUP_CONCAT(
                REPLACE(REPLACE(
                    REGEXP_SUBSTR(l.name, 'language-id=\"[^\"]*\">[^<]*', 1, seq.n),
                    'language-id=\"', ''),
                    '\">', '=')
                ORDER BY REGEXP_SUBSTR(l.name, 'language-id=\"[^\"]*\">[^<]*', 1, seq.n)
                SEPARATOR ', '
            ) AS name_translations,
            GROUP_CONCAT(
                REPLACE(REPLACE(
                    REGEXP_SUBSTR(l.title, 'language-id=\"[^\"]*\">[^<]*', 1, seq.n),
                    'language-id=\"', ''),
                    '\">', '=')
                ORDER BY REGEXP_SUBSTR(l.title, 'language-id=\"[^\"]*\">[^<]*', 1, seq.n)
                SEPARATOR ', '
            ) AS title_translations
        FROM Layout l
        JOIN (
            SELECT 1 n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
            UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10
        ) seq ON REGEXP_SUBSTR(l.name, 'language-id=\"[^\"]*\">[^<]*', 1, seq.n) IS NOT NULL
        WHERE l.groupId        = __GROUPID__
          AND l.ctCollectionId = 0
          AND l.status         = 0
          AND l.system_        = 0
        GROUP BY l.externalReferenceCode
        ORDER BY l.externalReferenceCode;
    "

    check "Layout – Core fields" "
        SELECT
            externalReferenceCode,
            friendlyURL,
            type_,
            privateLayout,
            hidden_,
            priority,
            status
        FROM Layout
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND status         = 0
          AND system_        = 0
        ORDER BY externalReferenceCode;
    "

    check "Layout – Page hierarchy" "
        SELECT
            l.externalReferenceCode,
            l.friendlyURL,
            COALESCE(p.friendlyURL, '(root)') AS parent_friendlyURL
        FROM Layout l
        LEFT JOIN Layout p
               ON p.plid           = l.parentPlid
              AND p.groupId        = l.groupId
              AND p.ctCollectionId = 0
        WHERE l.groupId        = __GROUPID__
          AND l.ctCollectionId = 0
          AND l.status         = 0
          AND l.system_        = 0
        ORDER BY l.externalReferenceCode;
    "

    check "Layout – Structure relation count (content pages)" "
        SELECT
            l.externalReferenceCode,
            COUNT(*)             AS structure_rel_count
        FROM Layout l
        JOIN LayoutPageTemplateStructure lpts
          ON lpts.plid           = l.plid
         AND lpts.ctCollectionId = 0
        JOIN LayoutPageTemplateStructureRel lptsr
          ON lptsr.layoutPageTemplateStructureId = lpts.layoutPageTemplateStructureId
         AND lptsr.ctCollectionId = 0
        WHERE l.groupId        = __GROUPID__
          AND l.ctCollectionId = 0
          AND l.status         = 0
          AND l.system_        = 0
          AND l.type_          = 'content'
        GROUP BY l.externalReferenceCode
        ORDER BY l.externalReferenceCode;
    "

    check "Layout – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate,
            publishDate
        FROM Layout
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND status         = 0
          AND system_        = 0
        ORDER BY externalReferenceCode;
    "


    # =========================================================================
    # MASTER PAGES  (LayoutPageTemplateEntry type_ = 3)
    # =========================================================================

    check "Master Pages – Count" "
        SELECT
            COUNT(*)        AS total_master_pages
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 3;
    "

    check "Master Pages – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_,
            layoutPageTemplateEntryKey
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 3
        ORDER BY externalReferenceCode;
    "

    check "Master Pages – Names" "
        SELECT
            externalReferenceCode,
            name
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 3
        ORDER BY externalReferenceCode;
    "

    check "Master Pages – Core fields" "
        SELECT
            externalReferenceCode,
            name,
            status
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 3
        ORDER BY externalReferenceCode;
    "

    check "Master Pages – Structure relation count" "
        SELECT
            lpte.externalReferenceCode,
            COUNT(*)             AS structure_rel_count
        FROM LayoutPageTemplateEntry lpte
        JOIN LayoutPageTemplateStructure lpts
          ON lpts.plid           = lpte.plid
         AND lpts.ctCollectionId = 0
        JOIN LayoutPageTemplateStructureRel lptsr
          ON lptsr.layoutPageTemplateStructureId = lpts.layoutPageTemplateStructureId
         AND lptsr.ctCollectionId = 0
        WHERE lpte.groupId        = __GROUPID__
          AND lpte.ctCollectionId = 0
          AND lpte.type_          = 3
        GROUP BY lpte.externalReferenceCode
        ORDER BY lpte.externalReferenceCode;
    "

    check "Master Pages – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 3
        ORDER BY externalReferenceCode;
    "


    # =========================================================================
    # PAGE TEMPLATES  (LayoutPageTemplateEntry type_ = 0)
    # =========================================================================

    check "Page Template Collections – Count" "
        SELECT
            COUNT(*)        AS total_collections
        FROM LayoutPageTemplateCollection
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0;
    "

    check "Page Template Collections – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_,
            lptCollectionKey
        FROM LayoutPageTemplateCollection
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    check "Page Template Collections – Names and descriptions" "
        SELECT
            externalReferenceCode,
            name,
            description
        FROM LayoutPageTemplateCollection
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    check "Page Template Collections – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM LayoutPageTemplateCollection
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    check "Page Templates – Count per collection" "
        SELECT
            lptc.externalReferenceCode  AS collection_erc,
            COUNT(*)                    AS template_count
        FROM LayoutPageTemplateEntry lpte
        JOIN LayoutPageTemplateCollection lptc
          ON lptc.layoutPageTemplateCollectionId = lpte.layoutPageTemplateCollectionId
         AND lptc.ctCollectionId = 0
        WHERE lpte.groupId        = __GROUPID__
          AND lpte.ctCollectionId = 0
          AND lpte.type_          = 0
        GROUP BY lptc.externalReferenceCode
        ORDER BY lptc.externalReferenceCode;
    "

    check "Page Templates – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_,
            layoutPageTemplateEntryKey
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 0
        ORDER BY externalReferenceCode;
    "

    check "Page Templates – Names" "
        SELECT
            externalReferenceCode,
            name
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 0
        ORDER BY externalReferenceCode;
    "

    check "Page Templates – Core fields" "
        SELECT
            lpte.externalReferenceCode,
            lpte.name,
            lptc.externalReferenceCode  AS collection_erc,
            lpte.status
        FROM LayoutPageTemplateEntry lpte
        LEFT JOIN LayoutPageTemplateCollection lptc
               ON lptc.layoutPageTemplateCollectionId = lpte.layoutPageTemplateCollectionId
              AND lptc.ctCollectionId = 0
        WHERE lpte.groupId        = __GROUPID__
          AND lpte.ctCollectionId = 0
          AND lpte.type_          = 0
        ORDER BY lpte.externalReferenceCode;
    "

    check "Page Templates – Structure relation count" "
        SELECT
            lpte.externalReferenceCode,
            COUNT(*)             AS structure_rel_count
        FROM LayoutPageTemplateEntry lpte
        JOIN LayoutPageTemplateStructure lpts
          ON lpts.plid           = lpte.plid
         AND lpts.ctCollectionId = 0
        JOIN LayoutPageTemplateStructureRel lptsr
          ON lptsr.layoutPageTemplateStructureId = lpts.layoutPageTemplateStructureId
         AND lptsr.ctCollectionId = 0
        WHERE lpte.groupId        = __GROUPID__
          AND lpte.ctCollectionId = 0
          AND lpte.type_          = 0
        GROUP BY lpte.externalReferenceCode
        ORDER BY lpte.externalReferenceCode;
    "

    check "Page Templates – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 0
        ORDER BY externalReferenceCode;
    "


    # =========================================================================
    # DISPLAY PAGE TEMPLATES  (LayoutPageTemplateEntry type_ = 1)
    # =========================================================================

    check "Display Page Templates – Count" "
        SELECT
            COUNT(*)        AS total
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 1;
    "

    check "Display Page Templates – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_,
            layoutPageTemplateEntryKey
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 1
        ORDER BY externalReferenceCode;
    "

    check "Display Page Templates – Names" "
        SELECT
            externalReferenceCode,
            name
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 1
        ORDER BY externalReferenceCode;
    "

    check "Display Page Templates – Core fields" "
        SELECT
            lpte.externalReferenceCode,
            lpte.name,
            lpte.defaultTemplate,
            lpte.status
        FROM LayoutPageTemplateEntry lpte
        WHERE lpte.groupId        = __GROUPID__
          AND lpte.ctCollectionId = 0
          AND lpte.type_          = 1
        ORDER BY lpte.externalReferenceCode;
    "

    check "Display Page Templates – Mapped asset type" "
        SELECT
            lpte.externalReferenceCode,
            cn.value         AS class_name,
            lpte.classTypeKey
        FROM LayoutPageTemplateEntry lpte
        LEFT JOIN ClassName_ cn
               ON cn.classNameId = lpte.classNameId
        WHERE lpte.groupId        = __GROUPID__
          AND lpte.ctCollectionId = 0
          AND lpte.type_          = 1
        ORDER BY lpte.externalReferenceCode;
    "

    check "Display Page Templates – Structure relation count" "
        SELECT
            lpte.externalReferenceCode,
            COUNT(*)             AS structure_rel_count
        FROM LayoutPageTemplateEntry lpte
        JOIN LayoutPageTemplateStructure lpts
          ON lpts.plid           = lpte.plid
         AND lpts.ctCollectionId = 0
        JOIN LayoutPageTemplateStructureRel lptsr
          ON lptsr.layoutPageTemplateStructureId = lpts.layoutPageTemplateStructureId
         AND lptsr.ctCollectionId = 0
        WHERE lpte.groupId        = __GROUPID__
          AND lpte.ctCollectionId = 0
          AND lpte.type_          = 1
        GROUP BY lpte.externalReferenceCode
        ORDER BY lpte.externalReferenceCode;
    "

    check "Display Page Templates – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 1
        ORDER BY externalReferenceCode;
    "


    # =========================================================================
    # DISPLAY PAGE TEMPLATE FOLDERS  (LayoutPageTemplateCollection type_ = 1)
    # =========================================================================

    check "Display Page Template Folders – Count" "
        SELECT
            COUNT(*)        AS total
        FROM LayoutPageTemplateCollection
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 1;
    "

    check "Display Page Template Folders – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_,
            lptCollectionKey
        FROM LayoutPageTemplateCollection
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 1
        ORDER BY externalReferenceCode;
    "

    check "Display Page Template Folders – Names and descriptions" "
        SELECT
            externalReferenceCode,
            name,
            description
        FROM LayoutPageTemplateCollection
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 1
        ORDER BY externalReferenceCode;
    "

    check "Display Page Template Folders – Hierarchy" "
        SELECT
            c.externalReferenceCode,
            COALESCE(p.externalReferenceCode, '(root)') AS parent_erc
        FROM LayoutPageTemplateCollection c
        LEFT JOIN LayoutPageTemplateCollection p
               ON p.layoutPageTemplateCollectionId = c.parentLPTCollectionId
              AND p.ctCollectionId = 0
        WHERE c.groupId        = __GROUPID__
          AND c.ctCollectionId = 0
          AND c.type_          = 1
        ORDER BY c.externalReferenceCode;
    "

    check "Display Page Template Folders – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM LayoutPageTemplateCollection
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 1
        ORDER BY externalReferenceCode;
    "


    # =========================================================================
    # UTILITY PAGES  (LayoutUtilityPageEntry)
    # =========================================================================

    check "Utility Pages – Count by type" "
        SELECT
            type_,
            COUNT(*)        AS total
        FROM LayoutUtilityPageEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
        GROUP BY type_
        ORDER BY type_;
    "

    check "Utility Pages – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_
        FROM LayoutUtilityPageEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    check "Utility Pages – Names" "
        SELECT
            externalReferenceCode,
            name
        FROM LayoutUtilityPageEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    check "Utility Pages – Core fields" "
        SELECT
            externalReferenceCode,
            name,
            type_,
            defaultLayoutUtilityPageEntry
        FROM LayoutUtilityPageEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    check "Utility Pages – Structure relation count" "
        SELECT
            lupe.externalReferenceCode,
            COUNT(*)             AS structure_rel_count
        FROM LayoutUtilityPageEntry lupe
        JOIN LayoutPageTemplateStructure lpts
          ON lpts.plid           = lupe.plid
         AND lpts.ctCollectionId = 0
        JOIN LayoutPageTemplateStructureRel lptsr
          ON lptsr.layoutPageTemplateStructureId = lpts.layoutPageTemplateStructureId
         AND lptsr.ctCollectionId = 0
        WHERE lupe.groupId        = __GROUPID__
          AND lupe.ctCollectionId = 0
        GROUP BY lupe.externalReferenceCode
        ORDER BY lupe.externalReferenceCode;
    "

    check "Utility Pages – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM LayoutUtilityPageEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "
}
