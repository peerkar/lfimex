# =============================================================================
# Test: PAGE TEMPLATES
# Tables: LayoutPageTemplateEntry, LayoutPageTemplateCollection,
#         LayoutPageTemplateStructure, LayoutPageTemplateStructureRel,
#         LayoutUtilityPageEntry, ClassName_
# =============================================================================
#
# LayoutPageTemplateEntry type_ values:
#   0 = Page Template (Basic/Content page template)
#   1 = Display Page Template
#   3 = Master Page
#
# Regular site pages (Layout) are covered by the `site_pages` test, not here.
# =============================================================================

test_page_templates() {
    section "PAGE TEMPLATES"

    # =========================================================================
    # MASTER PAGES  (LayoutPageTemplateEntry type_ = 3)
    # =========================================================================

    check "Master Pages – Count" "
        SELECT
            COUNT(*)        AS total_master_pages
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 3
          $(date_filter modifiedDate);
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
          $(date_filter modifiedDate)
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
          $(date_filter modifiedDate)
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
          $(date_filter modifiedDate)
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
          $(date_filter lpte.modifiedDate)
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
          $(date_filter modifiedDate)
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
          AND ctCollectionId = 0
          $(date_filter modifiedDate);
    "

    check "Page Template Collections – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_,
            lptCollectionKey
        FROM LayoutPageTemplateCollection
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
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
          $(date_filter modifiedDate)
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
          $(date_filter modifiedDate)
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
          $(date_filter lpte.modifiedDate)
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
          $(date_filter modifiedDate)
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
          $(date_filter modifiedDate)
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
          $(date_filter lpte.modifiedDate)
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
          $(date_filter lpte.modifiedDate)
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
          $(date_filter modifiedDate)
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
          AND type_          = 1
          $(date_filter modifiedDate);
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
          $(date_filter modifiedDate)
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
          $(date_filter modifiedDate)
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
          $(date_filter lpte.modifiedDate)
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
          $(date_filter lpte.modifiedDate)
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
          $(date_filter lpte.modifiedDate)
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
          $(date_filter modifiedDate)
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
          AND type_          = 1
          $(date_filter modifiedDate);
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
          $(date_filter modifiedDate)
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
          $(date_filter modifiedDate)
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
          $(date_filter c.modifiedDate)
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
          $(date_filter modifiedDate)
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
          $(date_filter modifiedDate)
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
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "Utility Pages – Names" "
        SELECT
            externalReferenceCode,
            name
        FROM LayoutUtilityPageEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
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
          $(date_filter modifiedDate)
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
          $(date_filter lupe.modifiedDate)
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
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "
}
