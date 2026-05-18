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

    # The mi.name column on the source is unreliable for export/import diffs:
    #
    #   1. Legacy items can have mi.name = '' — they were never re-saved
    #      through SiteNavigationMenuItemLocalServiceImpl
    #      .updateSiteNavigationMenuItem(userId, id, typeSettings,
    #      serviceContext), which is the call that normalizes the column.
    #   2. Older items can have a custom string in mi.name that isn't mirrored
    #      in typeSettings.name. On import every item flows through that
    #      service form, which sets mi.name = siteNavigationMenuItemType
    #      .getName(typeSettings). For LayoutSiteNavigationMenuItemType that
    #      reads typeSettings.name first and falls back to layout.getName
    #      (locale) — so any custom name not present in typeSettings is
    #      silently replaced by the layout's default-locale name on import.
    #
    # Both effects mean the source mi.name column and the target mi.name
    # column legitimately disagree for the same item. The displayed name in
    # the navigation UI is identical on both sides (it's the layout name in
    # both cases), so compare what's actually displayed: prefer the layout's
    # default-locale name (extracted from the localized XML in Layout.name)
    # and fall back to mi.name only when no layout joins — i.e. URL / node /
    # submenu items.
    #
    # The default-locale extraction reads default-locale="X" from Layout
    # .name's root element, then pulls the value of <Name language-id="X">…
    # </Name>. For plain-string layout names this still returns the column
    # value verbatim (the SUBSTRING_INDEX chain is a no-op when neither
    # delimiter is present).
    check "SiteNavigationMenuItem – Names" "
        SELECT
            m.name AS menu_name,
            mi.externalReferenceCode,
            COALESCE(
                NULLIF(
                    REGEXP_REPLACE(
                        SUBSTRING_INDEX(
                            SUBSTRING_INDEX(
                                l.name,
                                CONCAT(
                                    '<Name language-id=\"',
                                    SUBSTRING_INDEX(
                                        SUBSTRING_INDEX(l.name, 'default-locale=\"', -1),
                                        '\"', 1
                                    ),
                                    '\">'
                                ),
                                -1
                            ),
                            '</Name>', 1
                        ),
                        '<[^>]+>', ''
                    ),
                    ''
                ),
                NULLIF(REGEXP_REPLACE(mi.name, '<[^>]+>', ''), '')
            ) AS item_name
        FROM SiteNavigationMenuItem mi
        JOIN SiteNavigationMenu m
          ON m.siteNavigationMenuId = mi.siteNavigationMenuId
             AND m.ctCollectionId   = 0
        LEFT JOIN Layout l
               ON l.externalReferenceCode = REGEXP_REPLACE(
                      REGEXP_SUBSTR(mi.typeSettings, 'externalReferenceCode=.+'),
                      '^externalReferenceCode=', ''
                  )
              AND l.groupId        = mi.groupId
              AND l.privateLayout  = (mi.typeSettings REGEXP 'privateLayout=true')
              AND l.ctCollectionId = 0
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

    # typeSettings on current Liferay holds externalReferenceCode +
    # privateLayout (the v3.0.0 upgrade dropped layoutUuid/plid). The plid
    # the old query extracted doesn't appear in typeSettings anymore, so the
    # join never matched — both sides returned zero rows and the check was
    # silently passing. Joining via ERC + privateLayout is the supported
    # resolution path and is stable across source/target (target's import
    # rewrites externalReferenceCode to the resolved layout's value, but the
    # value matches the source's since layout ERCs are preserved on import).
    check "SiteNavigationMenuItem – Layout items resolved to friendlyURL" "
        SELECT
            m.name AS menu_name,
            mi.externalReferenceCode,
            l.friendlyURL
        FROM SiteNavigationMenuItem mi
        JOIN SiteNavigationMenu m
          ON m.siteNavigationMenuId = mi.siteNavigationMenuId
             AND m.ctCollectionId   = 0
        JOIN Layout l
          ON l.externalReferenceCode = REGEXP_REPLACE(
                 REGEXP_SUBSTR(mi.typeSettings, 'externalReferenceCode=.+'),
                 '^externalReferenceCode=', ''
             )
         AND l.groupId        = mi.groupId
         AND l.privateLayout  = (mi.typeSettings REGEXP 'privateLayout=true')
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
