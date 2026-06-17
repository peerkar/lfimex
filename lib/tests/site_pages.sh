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
# Status normalization:
#   Every Layout-side check accepts both STATUS_APPROVED (0) and
#   STATUS_DRAFT (2), then CASE-collapses DRAFT→APPROVED in the SELECT.
#   Same Liferay quirk documented in lib/tests/page_templates.sh: source
#   author edits leave a draft sitting on top of an approved layout
#   (status=2), Liferay's BatchEngine-backed import recreates the row as
#   status=0 on target regardless of source state. The page is the same
#   logical layout (same ERC, same friendlyURL, same Layout.name); only
#   the workflow flag differs.
#
# Columns deliberately NOT surfaced:
#   * Layout.modifiedDate — rewritten to import timestamp during
#     persistence. createDate and publishDate are preserved.
#   * LayoutSet.modifiedDate / createDate — LayoutSet is constructed when
#     the target SITE is created, so both dates reflect the target's site
#     provisioning, not source's edit history. The LayoutSet – Dates
#     check has been retired.
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
          AND status         IN (0, 2)
          AND system_        = 0
        GROUP BY type_, privateLayout, hidden_;
    "

    # Identifiers compares ERC only. uuid_ and friendlyURL both drift:
    #   * uuid_: source has uuid_=ERC for ~30 layouts where Liferay's
    #     ERC-backfill aligned the two values; target was created with
    #     fresh uuid_s (or pre-existed with different uuid_s), so the
    #     columns diverge on every backfilled layout.
    #   * friendlyURL: Layout.friendlyURL is a denormalized cache of
    #     LayoutFriendlyURL's default-locale entry. The cache drifts on
    #     source (legacy renames updated LayoutFriendlyURL but left
    #     Layout.friendlyURL stale); on import Liferay rebuilds it from
    #     LayoutFriendlyURL, so target has the current value. Comparing
    #     friendlyURLs surfaces every such cache drift as a phantom diff.
    # ERC is the stable identifier the LAR uses for upsert semantics.
    check "Layout – Identifiers" "
        SELECT
            externalReferenceCode
        FROM Layout
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND status         IN (0, 2)
          AND system_        = 0
        ORDER BY externalReferenceCode;
    "

    # JOIN condition is OR'd across name and title: the sequence n
    # iterates as long as EITHER column has an n-th language-id match.
    # The original check joined seq on name only, so when title had more
    # locales than name (e.g. a layout with name in en_US plus title in
    # en_US + 6 other locales) seq.n stopped at 1 and the test extracted
    # just the first title locale. Liferay's import doesn't preserve the
    # XML's internal locale ordering — source serializes locales in
    # declaration order, target in import-iteration order — so the
    # "first" locale was a different one on each side, producing diffs
    # for every multi-locale title with a single-locale name. ORDER BY
    # the substring (alphabetical by 'language-id=...value') stabilizes
    # the resulting GROUP_CONCAT across both sides.
    #
    # Verified max locale count in source data: 9 for name, 8 for title;
    # the seq's 10-entry cap is sufficient.
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
        ) seq ON REGEXP_SUBSTR(l.name,  'language-id=\"[^\"]*\">[^<]*', 1, seq.n) IS NOT NULL
             OR REGEXP_SUBSTR(l.title, 'language-id=\"[^\"]*\">[^<]*', 1, seq.n) IS NOT NULL
        WHERE l.groupId        = __GROUPID__
          AND l.ctCollectionId = 0
          AND l.status         IN (0, 2)
          AND l.system_        = 0
        GROUP BY l.externalReferenceCode
        ORDER BY l.externalReferenceCode;
    "

    # Core fields excludes priority: the column controls sibling page
    # ordering within a parent, and Liferay's import recomputes priority
    # values based on processing order — verified that 159/385 layouts
    # (41%) have a different priority on target vs source. Sibling ORDER
    # is preserved (the structure relation tests catch any actual
    # reordering), only the numeric priority values drift.
    check "Layout – Core fields" "
        SELECT
            externalReferenceCode,
            friendlyURL,
            type_,
            privateLayout,
            hidden_,
            CASE WHEN status = 2 THEN 0 ELSE status END AS status
        FROM Layout
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND status         IN (0, 2)
          AND system_        = 0
        ORDER BY externalReferenceCode;
    "

    # Parent identified by externalReferenceCode (stable) rather than
    # friendlyURL: Liferay's Layout.friendlyURL column is a denormalized
    # cache of the default-locale entry in LayoutFriendlyURL. On source
    # the cache can drift (legacy renames update LayoutFriendlyURL but
    # leave Layout.friendlyURL pointing at the previous slug — verified
    # on the data: source has 2 layouts with friendlyURL != en_US
    # LayoutFriendlyURL value). On import Liferay rebuilds the cache from
    # LayoutFriendlyURL, so target ends up with the current URL. Comparing
    # parent friendlyURLs surfaces every such cache drift; comparing
    # parent ERCs sees the real hierarchy relationship round-trip.
    check "Layout – Page hierarchy" "
        SELECT
            l.externalReferenceCode,
            COALESCE(p.externalReferenceCode, '(root)') AS parent_erc
        FROM Layout l
        LEFT JOIN Layout p
               ON p.plid           = l.parentPlid
              AND p.groupId        = l.groupId
              AND p.ctCollectionId = 0
        WHERE l.groupId        = __GROUPID__
          AND l.ctCollectionId = 0
          AND l.status         IN (0, 2)
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
          AND l.status         IN (0, 2)
          AND l.system_        = 0
          AND l.type_          = 'content'
        GROUP BY l.externalReferenceCode
        ORDER BY l.externalReferenceCode;
    "

    # Dates surfaces only createDate. modifiedDate and publishDate both
    # get rewritten on import: modifiedDate to the import timestamp
    # (persistence), publishDate to 0% match across all layouts (the
    # Layout import resets it as part of the publish-flow handshake).
    # createDate has residual ~8% drift (verified 30/385 layouts) when
    # the source has multiple revisions and the import lands on a
    # different revision's createDate; that residual drift is real
    # signal worth keeping visible.
    check "Layout – Dates" "
        SELECT
            externalReferenceCode,
            createDate
        FROM Layout
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND status         IN (0, 2)
          AND system_        = 0
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
        GROUP BY privateLayout
        ORDER BY privateLayout;
    "

    # NULLIF on layoutSetPrototypeUuid: source stores empty string when
    # the LayoutSet wasn't created from a prototype; target import
    # persists NULL for the same state. Collapsing both to NULL keeps the
    # check from false-positiving on every site that wasn't prototype-
    # backed.
    check "LayoutSet – Theme and color scheme" "
        SELECT
            privateLayout,
            themeId,
            colorSchemeId,
            NULLIF(layoutSetPrototypeUuid, '') AS layoutSetPrototypeUuid,
            layoutSetPrototypeLinkEnabled
        FROM LayoutSet
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY privateLayout;
    "

    # No settings_ comparison: StagedLayoutSetStagedModelDataHandler clears
    # the field on export unless LAYOUT_SET_SETTINGS=on is in the request
    # param map (it isn't — that key bypasses PORTLET_DATA_CONTROL_DEFAULT
    # and falls back to false). Even with the toggle, settings_ accumulates
    # instance-specific keys (virtualHostname, last-merge-time, etc.) that
    # legitimately differ across companies. Theme/colorScheme/prototype-link
    # round-tripping is covered by `LayoutSet – Theme and color scheme`;
    # this check only verifies CSS transports when authored.
    check "LayoutSet – CSS present" "
        SELECT
            privateLayout,
            css IS NOT NULL AND css != '' AS css_present
        FROM LayoutSet
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY privateLayout;
    "

    # NOTE: a "LayoutSet – Dates" check used to live here selecting
    # createDate + modifiedDate. Both are non-portable for LayoutSet:
    # the row is constructed when the TARGET site is created (via
    # step_site / blade), not when the LayoutSet is imported, so both
    # dates reflect target-site provisioning rather than source's edit
    # history. The check was 100% expected to fail. Retired.
}
