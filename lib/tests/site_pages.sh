# =============================================================================
# Test: SITE PAGES
# Tables: Layout, LayoutSet,
#         LayoutPageTemplateStructure, LayoutPageTemplateStructureRel
# =============================================================================
#
# Page structure note:
#   LayoutPageTemplateStructure has no data_ column. Page content is stored
#   in LayoutPageTemplateStructureRel.data_, linked via
#   layoutPageTemplateStructureId and scoped by segmentsExperienceId.
#
# =============================================================================

test_site_pages() {
    section "SITE PAGES"

    # =========================================================================
    # Layout
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
          $(date_filter modifiedDate)
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
          $(date_filter modifiedDate)
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
          $(date_filter l.modifiedDate)
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
          $(date_filter modifiedDate)
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
          $(date_filter l.modifiedDate)
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
          $(date_filter l.modifiedDate)
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
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    # =========================================================================
    # LayoutSet  (one row per privateLayout flag per site, carries theme +
    # look-and-feel; exported alongside the Layout tree)
    # =========================================================================

    check "LayoutSet – Count" "
        SELECT
            privateLayout,
            COUNT(*)        AS total
        FROM LayoutSet
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        GROUP BY privateLayout
        ORDER BY privateLayout;
    "

    check "LayoutSet – Theme and color scheme" "
        SELECT
            privateLayout,
            themeId,
            colorSchemeId,
            layoutSetPrototypeUuid,
            layoutSetPrototypeLinkEnabled
        FROM LayoutSet
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY privateLayout;
    "

    check "LayoutSet – Settings and CSS checksum" "
        SELECT
            privateLayout,
            MD5(settings_)      AS settings_hash,
            LENGTH(settings_)   AS settings_length,
            MD5(css)            AS css_hash,
            LENGTH(css)         AS css_length
        FROM LayoutSet
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY privateLayout;
    "

    check "LayoutSet – Dates" "
        SELECT
            privateLayout,
            createDate,
            modifiedDate
        FROM LayoutSet
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY privateLayout;
    "
}
