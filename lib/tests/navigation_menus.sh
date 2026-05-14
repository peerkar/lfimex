# =============================================================================
# Test: NAVIGATION MENUS
# Tables: SiteNavigationMenu, SiteNavigationMenuItem
# =============================================================================

# SiteNavigationMenu type_ values:
#   0 = None
#   1 = Primary navigation
#   2 = Secondary navigation
#   3 = Social navigation
# =============================================================================

test_navigation_menus() {
    section "NAVIGATION MENUS"

    # =========================================================================
    # SiteNavigationMenu
    # =========================================================================

    check "SiteNavigationMenu – Total count" "
        SELECT
            COUNT(*)        AS total_menus
        FROM SiteNavigationMenu
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate);
    "

    check "SiteNavigationMenu – Count by type" "
        SELECT
            type_,
            COUNT(*)        AS total
        FROM SiteNavigationMenu
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        GROUP BY type_
        ORDER BY type_;
    "

    check "SiteNavigationMenu – Identifiers" "
        SELECT
            name,
            externalReferenceCode,
            uuid_
        FROM SiteNavigationMenu
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "SiteNavigationMenu – Names" "
        SELECT
            externalReferenceCode,
            name
        FROM SiteNavigationMenu
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "SiteNavigationMenu – Core fields" "
        SELECT
            externalReferenceCode,
            name,
            type_,
            auto_
        FROM SiteNavigationMenu
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "SiteNavigationMenu – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM SiteNavigationMenu
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    # =========================================================================
    # SiteNavigationMenuItem
    # =========================================================================

    check "SiteNavigationMenuItem – Total count" "
        SELECT
            COUNT(*)        AS total_menu_items
        FROM SiteNavigationMenuItem
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate);
    "

    check "SiteNavigationMenuItem – Count per menu" "
        SELECT
            m.name          AS menu_name,
            COUNT(*)        AS item_count
        FROM SiteNavigationMenuItem mi
        JOIN SiteNavigationMenu m
          ON m.siteNavigationMenuId = mi.siteNavigationMenuId
             AND m.ctCollectionId   = 0
        WHERE mi.groupId        = __GROUPID__
          AND mi.ctCollectionId = 0
          $(date_filter mi.modifiedDate)
        GROUP BY m.name
        ORDER BY m.name;
    "

    check "SiteNavigationMenuItem – Count by type per menu" "
        SELECT
            m.name          AS menu_name,
            mi.type_,
            COUNT(*)        AS item_count
        FROM SiteNavigationMenuItem mi
        JOIN SiteNavigationMenu m
          ON m.siteNavigationMenuId = mi.siteNavigationMenuId
             AND m.ctCollectionId   = 0
        WHERE mi.groupId        = __GROUPID__
          AND mi.ctCollectionId = 0
          $(date_filter mi.modifiedDate)
        GROUP BY m.name, mi.type_
        ORDER BY m.name, mi.type_;
    "

    check "SiteNavigationMenuItem – Identifiers" "
        SELECT
            m.name          AS menu_name,
            mi.externalReferenceCode,
            mi.uuid_
        FROM SiteNavigationMenuItem mi
        JOIN SiteNavigationMenu m
          ON m.siteNavigationMenuId = mi.siteNavigationMenuId
             AND m.ctCollectionId   = 0
        WHERE mi.groupId        = __GROUPID__
          AND mi.ctCollectionId = 0
          $(date_filter mi.modifiedDate)
        ORDER BY m.name, mi.externalReferenceCode;
    "

    check "SiteNavigationMenuItem – Names" "
        SELECT
            m.name          AS menu_name,
            mi.externalReferenceCode,
            REGEXP_REPLACE(mi.name, '<[^>]+>', '') AS item_name
        FROM SiteNavigationMenuItem mi
        JOIN SiteNavigationMenu m
          ON m.siteNavigationMenuId = mi.siteNavigationMenuId
             AND m.ctCollectionId   = 0
        WHERE mi.groupId        = __GROUPID__
          AND mi.ctCollectionId = 0
          $(date_filter mi.modifiedDate)
        ORDER BY m.name, mi.externalReferenceCode;
    "

    check "SiteNavigationMenuItem – Core fields" "
        SELECT
            m.name              AS menu_name,
            mi.externalReferenceCode,
            mi.type_,
            mi.order_,
            COALESCE(mp.externalReferenceCode, '(root)') AS parent_item_erc
        FROM SiteNavigationMenuItem mi
        JOIN SiteNavigationMenu m
          ON m.siteNavigationMenuId = mi.siteNavigationMenuId
             AND m.ctCollectionId   = 0
        LEFT JOIN SiteNavigationMenuItem mp
               ON mp.siteNavigationMenuItemId = mi.parentSiteNavigationMenuItemId
              AND mp.ctCollectionId           = 0
        WHERE mi.groupId        = __GROUPID__
          AND mi.ctCollectionId = 0
          $(date_filter mi.modifiedDate)
        ORDER BY m.name, mi.order_, mi.externalReferenceCode;
    "

    check "SiteNavigationMenuItem – Layout items resolved to friendlyURL" "
        SELECT
            m.name              AS menu_name,
            mi.externalReferenceCode,
            l.friendlyURL
        FROM SiteNavigationMenuItem mi
        JOIN SiteNavigationMenu m
          ON m.siteNavigationMenuId = mi.siteNavigationMenuId
             AND m.ctCollectionId   = 0
        JOIN Layout l
          ON l.plid = CAST(
                 REPLACE(
                     REGEXP_SUBSTR(mi.typeSettings, 'plid=[0-9]+'),
                     'plid=', ''
                 ) AS UNSIGNED
             )
             AND l.ctCollectionId = 0
        WHERE mi.groupId        = __GROUPID__
          AND mi.ctCollectionId = 0
          AND mi.type_          LIKE '%layout%'
          $(date_filter mi.modifiedDate)
        ORDER BY m.name, mi.externalReferenceCode;
    "

    check "SiteNavigationMenuItem – Dates" "
        SELECT
            m.name          AS menu_name,
            mi.externalReferenceCode,
            mi.createDate,
            mi.modifiedDate
        FROM SiteNavigationMenuItem mi
        JOIN SiteNavigationMenu m
          ON m.siteNavigationMenuId = mi.siteNavigationMenuId
             AND m.ctCollectionId   = 0
        WHERE mi.groupId        = __GROUPID__
          AND mi.ctCollectionId = 0
          $(date_filter mi.modifiedDate)
        ORDER BY m.name, mi.externalReferenceCode;
    "
}
