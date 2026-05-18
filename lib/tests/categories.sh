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

    # AssetVocabulary.title and .description are both localized="true" — the
    # column holds an XML wrapper produced by LocalizationUtil with one
    # <Title language-id="..."> / <Description language-id="..."> child per
    # locale, plus available-locales / default-locale attributes on the root.
    # Stripping all tags concatenates every locale's value in whatever order
    # the source/target serializer happened to emit (the available-locales
    # list can re-order across import), so the diff for equal logical
    # content is full of locale-order noise. Extract the default-locale's
    # value only.
    #
    # Also: source rows often have description = '' while the import writes
    # description = NULL on target (AssetVocabularyModelImpl.getDescription
    # returns '' when _description is null in-memory, but persistence keeps
    # NULL). NULLIF(value, '') normalizes both to NULL before MD5/LENGTH so
    # MD5(NULL) = NULL = MD5(NULL) on both sides.
    check "AssetVocabulary – Title and description" "
        SELECT
            externalReferenceCode,
            NULLIF(
                REGEXP_REPLACE(
                    SUBSTRING_INDEX(
                        SUBSTRING_INDEX(
                            title,
                            CONCAT(
                                '<Title language-id=\"',
                                SUBSTRING_INDEX(SUBSTRING_INDEX(title, 'default-locale=\"', -1), '\"', 1),
                                '\">'
                            ),
                            -1
                        ),
                        '</Title>', 1
                    ),
                    '<[^>]+>', ''
                ),
                ''
            ) AS title_plain,
            MD5(NULLIF(
                REGEXP_REPLACE(
                    SUBSTRING_INDEX(
                        SUBSTRING_INDEX(
                            description,
                            CONCAT(
                                '<Description language-id=\"',
                                SUBSTRING_INDEX(SUBSTRING_INDEX(description, 'default-locale=\"', -1), '\"', 1),
                                '\">'
                            ),
                            -1
                        ),
                        '</Description>', 1
                    ),
                    '<[^>]+>', ''
                ),
                ''
            )) AS description_md5,
            LENGTH(NULLIF(
                REGEXP_REPLACE(
                    SUBSTRING_INDEX(
                        SUBSTRING_INDEX(
                            description,
                            CONCAT(
                                '<Description language-id=\"',
                                SUBSTRING_INDEX(SUBSTRING_INDEX(description, 'default-locale=\"', -1), '\"', 1),
                                '\">'
                            ),
                            -1
                        ),
                        '</Description>', 1
                    ),
                    '<[^>]+>', ''
                ),
                ''
            )) AS description_len
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

    # AssetCategory.title/.description are Liferay LocalizedString blobs:
    #   <root … ><Title language-id=\"de_DE\">Deutschland</Title>
    #            <Title language-id=\"en_US\">Germany</Title></root>
    # Per-locale element order is whatever Liferay wrote to disk and isn't
    # preserved across export/import, so REGEXP_REPLACE-then-compare or
    # MD5-on-the-raw-blob produce false positives like
    #   < DeutschlandGermany  vs  > GermanyDeutschland.
    # Fix: enumerate language-id=value pairs with a sequence-table join, then
    # GROUP_CONCAT them in sorted order so the comparison is locale-set-based.
    check "AssetCategory – Title and description" "
        SELECT
            ac.externalReferenceCode,
            GROUP_CONCAT(
                REPLACE(REPLACE(
                    REGEXP_SUBSTR(ac.title, 'language-id=\"[^\"]*\">[^<]*', 1, seq.n),
                    'language-id=\"', ''),
                    '\">', '=')
                ORDER BY REGEXP_SUBSTR(ac.title, 'language-id=\"[^\"]*\">[^<]*', 1, seq.n)
                SEPARATOR ', '
            ) AS title_translations,
            MD5(IFNULL(GROUP_CONCAT(
                REPLACE(REPLACE(
                    REGEXP_SUBSTR(ac.description, 'language-id=\"[^\"]*\">[^<]*', 1, seq.n),
                    'language-id=\"', ''),
                    '\">', '=')
                ORDER BY REGEXP_SUBSTR(ac.description, 'language-id=\"[^\"]*\">[^<]*', 1, seq.n)
                SEPARATOR ', '
            ), ''))                                 AS description_md5,
            -- description is per-row but we're aggregating by ERC; MAX picks
            -- the single value per group (each ERC has exactly one row) and
            -- keeps ONLY_FULL_GROUP_BY satisfied. NULLIF('', '') collapses
            -- source's NULL and target's '' (or vice versa — the import
            -- doesn't preserve which one persistence chose) to a single
            -- NULL so LENGTH compares equal on both sides.
            MAX(LENGTH(NULLIF(ac.description, ''))) AS description_len
        FROM AssetCategory ac
        JOIN (
            SELECT 1 n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
            UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10
        ) seq ON REGEXP_SUBSTR(ac.title, 'language-id=\"[^\"]*\">[^<]*', 1, seq.n) IS NOT NULL
        WHERE ac.groupId        = __GROUPID__
          AND ac.ctCollectionId = 0
          $(date_filter ac.modifiedDate)
        GROUP BY ac.externalReferenceCode
        ORDER BY ac.externalReferenceCode;
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

    # AssetEntryAssetCategoryRel by itself includes rels pointing at
    # AssetEntries that never ship in a site LAR: trashed entries
    # (ae.visible = FALSE), draft/pending workflow rows, AssetEntries owned
    # by other groups (mounted DL repos, asset libraries — they keep their
    # own groupId), and Publications drafts (ae.ctCollectionId != 0). Source
    # accumulates these over time; the target is a fresh import that only
    # has the approved, visible, in-site entries, so the raw rel count
    # diverges by 2-3x on busy sites. The inner subquery counts only rels
    # whose AssetEntry the export would actually ship, and the LEFT JOIN
    # back to AssetCategory keeps categories with zero qualifying rels
    # visible (as count = 0) rather than dropping them from the result.
    check "AssetCategory – Asset count per category" "
        SELECT
            v.externalReferenceCode              AS vocabulary_external_reference_code,
            c.name              AS category_name,
            COALESCE(ac_cnt.cnt, 0)  AS asset_count
        FROM AssetVocabulary v
        JOIN AssetCategory c
          ON c.vocabularyId    = v.vocabularyId
             AND c.ctCollectionId  = 0
        LEFT JOIN (
            SELECT rel.assetCategoryId, COUNT(*) AS cnt
            FROM AssetEntryAssetCategoryRel rel
            JOIN AssetEntry ae
              ON ae.entryId        = rel.assetEntryId
             AND ae.groupId        = __GROUPID__
             AND ae.visible        = TRUE
             AND ae.ctCollectionId = 0
            WHERE rel.ctCollectionId = 0
            GROUP BY rel.assetCategoryId
        ) ac_cnt ON ac_cnt.assetCategoryId = c.categoryId
        WHERE v.groupId        = __GROUPID__
          AND v.ctCollectionId = 0
          $(date_filter c.modifiedDate)
        GROUP BY v.externalReferenceCode, c.name, ac_cnt.cnt
        ORDER BY v.externalReferenceCode, c.name;
    "

    # Without an ae.groupId filter this query was counting AssetEntries from
    # any group that happened to tag categories in this site's vocabularies
    # (cross-site / Public-visibility vocabularies, foreign-group depots,
    # etc.). Source has accumulated cross-group rels organically; target —
    # a freshly imported site — only has this group's own AEs, so the diff
    # was dominated by foreign-group ghosts plus trashed/draft AEs. Filter
    # the AE side to this site's visible, non-CT-draft rows so the count
    # reflects what the LAR actually carries.
    #
    # ae.visible = TRUE still leaves *orphan* AssetEntries — rows whose
    # underlying BlogsEntry/JournalArticle/DLFileEntry was deleted but the
    # AE + rel weren't cleaned up (Liferay data-integrity gap on hard
    # deletes). The export skips them because there's no entity to ship,
    # so they show up as a small source-side surplus. Require the underlying
    # entity to exist (in an exportable state) for the three common
    # workflowed types; pass-through for the rest.
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
             AND ae.groupId        = __GROUPID__
             AND ae.visible        = TRUE
             AND ae.ctCollectionId = 0
        JOIN ClassName_ cn
          ON cn.classNameId    = ae.classNameId
        WHERE v.groupId        = __GROUPID__
          AND v.ctCollectionId = 0
          AND (
              cn.value NOT IN (
                  'com.liferay.blogs.model.BlogsEntry',
                  'com.liferay.journal.model.JournalArticle',
                  'com.liferay.document.library.kernel.model.DLFileEntry'
              )
              OR (
                  cn.value = 'com.liferay.blogs.model.BlogsEntry'
                  AND EXISTS (
                      SELECT 1 FROM BlogsEntry be
                      WHERE be.entryId       = ae.classPK
                        AND be.ctCollectionId = 0
                        AND be.status        = 0
                  )
              )
              OR (
                  cn.value = 'com.liferay.journal.model.JournalArticle'
                  AND EXISTS (
                      SELECT 1 FROM JournalArticle ja
                      WHERE ja.resourcePrimKey = ae.classPK
                        AND ja.ctCollectionId  = 0
                        AND ja.status          = 0
                  )
              )
              OR (
                  cn.value = 'com.liferay.document.library.kernel.model.DLFileEntry'
                  AND EXISTS (
                      SELECT 1 FROM DLFileEntry fe
                      JOIN DLFileVersion fv
                        ON fv.fileEntryId    = fe.fileEntryId
                       AND fv.version        = fe.version
                       AND fv.ctCollectionId = 0
                       AND fv.status         = 0
                      WHERE fe.fileEntryId   = ae.classPK
                        AND fe.ctCollectionId = 0
                        AND fe.repositoryId  = fe.groupId
                  )
              )
          )
          $(date_filter c.modifiedDate)
        GROUP BY v.externalReferenceCode, cn.value
        ORDER BY v.externalReferenceCode, cn.value;
    "
}
