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

    # status is normalized DRAFT(2) → APPROVED(0): source master pages
    # often sit in DRAFT (work-in-progress edits that were never published
    # — their underlying system Layout row also stays status=2 until the
    # author publishes). The BatchEngine resources behind the
    # LayoutPageTemplateEntry-3 sub-registration (see config/asset_catalog
    # .sh page_templates entry) create imported rows as APPROVED outright,
    # so target always lands on status=0. Treating DRAFT as APPROVED on the
    # comparison hides that asymmetry without masking truly different
    # states like STATUS_IN_TRASH(8) or STATUS_EXPIRED(3), which still
    # surface as real diffs.
    check "Master Pages – Core fields" "
        SELECT
            externalReferenceCode,
            name,
            CASE WHEN status = 2 THEN 0 ELSE status END AS status
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

    # See "Master Pages – Core fields" above: BatchEngine resources behind
    # the LayoutPageTemplateEntry-0 sub-registration create imported rows
    # as APPROVED regardless of source's DRAFT state, so collapse DRAFT(2)
    # → APPROVED(0) on both sides. Other statuses (IN_TRASH, EXPIRED)
    # still surface as real diffs.
    check "Page Templates – Core fields" "
        SELECT
            lpte.externalReferenceCode,
            lpte.name,
            lptc.externalReferenceCode  AS collection_erc,
            CASE WHEN lpte.status = 2 THEN 0 ELSE lpte.status END AS status
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

    # See "Master Pages – Core fields" above for the DRAFT→APPROVED
    # normalization rationale (LayoutPageTemplateEntry-1 sub-registration).
    check "Display Page Templates – Core fields" "
        SELECT
            lpte.externalReferenceCode,
            lpte.name,
            lpte.defaultTemplate,
            CASE WHEN lpte.status = 2 THEN 0 ELSE lpte.status END AS status
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
    #
    # Gate the whole section on source-side presence. Liferay's site template
    # provisioning (the layout-set-prototype path our pipeline runs through
    # for a fresh target) can seed a target with default utility pages — a
    # "Page Not Found" page, etc. — that the source never had. Without this
    # guard, those defaults diff against an empty source and produce
    # false-positive failures.
    if src_has_rows LayoutUtilityPageEntry; then

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

    else
        skip_section "Utility Pages" "no rows on source"
    fi
}
