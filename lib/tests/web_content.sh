# =============================================================================
# Module: WEB CONTENT
# Tables: DDMStructure, JournalArticle, JournalArticleLocalization,
#         JournalArticleResource, JournalFolder,
#         DDMField, DDMFieldAttribute
# =============================================================================
#
# Version note:
#   JournalArticle has no head column. The article "head" is the latest
#   *approved* version (status=0), NOT the latest version overall: when an
#   author starts editing a published article, Liferay creates a new
#   DRAFT row at version+0.1 while keeping the previous APPROVED row, and
#   the export ships the APPROVED row only — so target's "latest" is the
#   approved one. Comparing against the latest version overall makes
#   source and target pick different rows for the same logical article
#   whenever there's a draft-on-top-of-approved. Every per-version
#   subquery here therefore filters `status = 0` so MAX(version) resolves
#   to the latest approved version on both sides.
#
# Content note:
#   JournalArticle has no content column. Article content is stored in
#   DDMField/DDMFieldAttribute, linked via storageId = ja.id_.
# =============================================================================

test_web_content() {
    section "WEB CONTENT"

    # =========================================================================
    # DDMStructure  (web content structures)
    # =========================================================================

    check "DDMStructure – Total count" "
        SELECT
            COUNT(*)        AS total
        FROM DDMStructure
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND classNameId    = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.journal.model.JournalArticle'
          )
          $(date_filter modifiedDate);
    "

    check "DDMStructure – Identifiers" "
        SELECT
            structureKey,
            uuid_,
            externalReferenceCode
        FROM DDMStructure
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND classNameId    = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.journal.model.JournalArticle'
          )
          $(date_filter modifiedDate)
        ORDER BY structureKey;
    "

    check "DDMStructure – Names and descriptions" "
        SELECT
            structureKey,
            REGEXP_REPLACE(name,        '<[^>]+>', '') AS name_plain,
            REGEXP_REPLACE(description, '<[^>]+>', '') AS description_plain
        FROM DDMStructure
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND classNameId    = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.journal.model.JournalArticle'
          )
          $(date_filter modifiedDate)
        ORDER BY structureKey;
    "

    check "DDMStructure – Core fields" "
        SELECT
            structureKey,
            storageType
        FROM DDMStructure
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND classNameId    = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.journal.model.JournalArticle'
          )
          $(date_filter modifiedDate)
        ORDER BY structureKey;
    "

    # No MD5/LENGTH comparison: Liferay rewrites the structure JSON during
    # import (whitespace, key ordering, default-value materialisation, etc.),
    # so the bytes legitimately differ across source/target even when the
    # structure is semantically identical. We only verify that the definition
    # survived the round-trip at all — semantic equality would require a
    # JSON-normalising compare we don't have here.
    check "DDMStructure – Definition present" "
        SELECT
            structureKey,
            definition IS NOT NULL AND definition != '' AS has_data
        FROM DDMStructure
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND classNameId    = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.journal.model.JournalArticle'
          )
          $(date_filter modifiedDate)
        ORDER BY structureKey;
    "

    check "DDMStructure – Dates" "
        SELECT
            structureKey,
            createDate,
            modifiedDate
        FROM DDMStructure
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND classNameId    = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.journal.model.JournalArticle'
          )
          $(date_filter modifiedDate)
        ORDER BY structureKey;
    "

    # =========================================================================
    # JournalArticle
    # =========================================================================

    # Counts logical articles that have at least one APPROVED version, not
    # raw version rows. JournalArticle stores one row per (articleId,
    # version), so COUNT(*) counts version history. COUNT(DISTINCT
    # articleId) WHERE status=0 picks one row per logical article with any
    # approved version — equivalent to what the export ships and the only
    # number that survives draft-on-top-of-approved skew (source can have
    # a DRAFT row at MAX(version) hiding an earlier APPROVED row; target
    # only ever sees the APPROVED row from the LAR).
    check "JournalArticle – Total count" "
        SELECT
            COUNT(DISTINCT ja.articleId) AS total
        FROM JournalArticle ja
        WHERE ja.groupId        = __GROUPID__
          AND ja.ctCollectionId = 0
          AND ja.status         = 0
          $(date_filter ja.modifiedDate);
    "

    check "JournalArticle – Count of latest versions by status" "
        SELECT
            ja.status,
            COUNT(*)        AS total
        FROM JournalArticle ja
        WHERE ja.groupId        = __GROUPID__
          AND ja.ctCollectionId = 0
          $(date_filter ja.modifiedDate)
          AND ja.status         = 0
          AND ja.version        = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
                AND ja2.status         = 0
          )
        GROUP BY ja.status
        ORDER BY ja.status;
    "

    check "JournalArticle – Identifiers (latest versions)" "
        SELECT
            ja.articleId,
            ja.uuid_,
            ja.externalReferenceCode
        FROM JournalArticle ja
        WHERE ja.groupId        = __GROUPID__
          AND ja.ctCollectionId = 0
          $(date_filter ja.modifiedDate)
          AND ja.status         = 0
          AND ja.version        = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
                AND ja2.status         = 0
          )
        ORDER BY ja.externalReferenceCode;
    "

    # Expected drift in urlTitle: Liferay enforces urlTitle uniqueness per
    # (groupId, journalArticle namespace) at import time. When the LAR's
    # urlTitle collides with one already on target — typically left over
    # from a prior partial import into the same site, or claimed by a
    # Layout friendly-URL — JournalArticleLocalServiceImpl appends a
    # numeric suffix (-1, -2, …) to make it unique. The article is still
    # the same logical row (same ERC, same articleId, same structureKey,
    # etc.); only the URL slug shifts.
    #
    # We deliberately keep urlTitle in this check so collision renames
    # surface — they're worth knowing about because they break any
    # external link pointing at the original URL. If a particular target
    # has persistent collision noise (e.g. a stale -1/-2 on every run),
    # add 'web_content:JournalArticle – Core fields (latest versions)' to
    # IGNORE_TESTS for that environment rather than masking the column
    # globally with REGEXP_REPLACE(urlTitle, '-[0-9]+\$', '') — that
    # mask would also hide legitimately-suffixed urlTitles ('report-2024',
    # 'chapter-3'), which we don't want.
    check "JournalArticle – Core fields (latest versions)" "
        SELECT
            ja.externalReferenceCode,
            ja.articleId,
            ds.structureKey,
            ja.DDMTemplateKey,
            ja.urlTitle,
            ja.defaultLanguageId,
            ja.status,
            ja.indexable,
            ja.smallImage,
            COALESCE(jf.uuid_, '(root)') AS folder_uuid
        FROM JournalArticle ja
        JOIN DDMStructure ds
          ON ds.structureId     = ja.DDMStructureId
         AND ds.ctCollectionId  = 0
        LEFT JOIN JournalFolder jf
               ON jf.folderId       = ja.folderId
              AND jf.ctCollectionId = 0
        WHERE ja.groupId        = __GROUPID__
          AND ja.ctCollectionId = 0
          $(date_filter ja.modifiedDate)
          AND ja.status         = 0
          AND ja.version        = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
                AND ja2.status         = 0
          )
        ORDER BY ja.externalReferenceCode;
    "

    # Counts APPROVED versions per article only. The export ships approved
    # versions (drafts that sit on top of an approved version are dropped),
    # so a DRAFT row on source has no twin on target — comparing total
    # version rows produces noise that has nothing to do with content
    # migration. Filtering to status=0 means a draft-on-top-of-approved
    # article that ships v1.3 has version_count=1 on both sides.
    check "JournalArticle – Version history count per article" "
        SELECT
            externalReferenceCode,
            articleId,
            COUNT(*)        AS version_count
        FROM JournalArticle
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND status         = 0
          $(date_filter modifiedDate)
        GROUP BY externalReferenceCode, articleId
        ORDER BY externalReferenceCode;
    "

    check "JournalArticle – Dates (latest versions)" "
        SELECT
            ja.externalReferenceCode,
            ja.displayDate,
            ja.expirationDate,
            ja.reviewDate,
            ja.createDate,
            ja.modifiedDate
        FROM JournalArticle ja
        WHERE ja.groupId        = __GROUPID__
          AND ja.ctCollectionId = 0
          $(date_filter ja.modifiedDate)
          AND ja.status         = 0
          AND ja.version        = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
                AND ja2.status         = 0
          )
        ORDER BY ja.externalReferenceCode;
    "

    # =========================================================================
    # JournalArticleLocalization
    # =========================================================================

    check "JournalArticleLocalization – Total count" "
        SELECT
            COUNT(*)        AS total_localizations
        FROM JournalArticleLocalization jal
        JOIN JournalArticle ja
          ON ja.id_            = jal.articlePK
         AND ja.ctCollectionId = 0
        WHERE ja.groupId       = __GROUPID__
          $(date_filter ja.modifiedDate)
          AND ja.status        = 0
          AND ja.version       = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
                AND ja2.status         = 0
          );
    "

    check "JournalArticleLocalization – Locale count per article" "
        SELECT
            ja.externalReferenceCode,
            COUNT(*)        AS locale_count,
            GROUP_CONCAT(jal.languageId ORDER BY jal.languageId) AS locales
        FROM JournalArticleLocalization jal
        JOIN JournalArticle ja
          ON ja.id_            = jal.articlePK
         AND ja.ctCollectionId = 0
        WHERE ja.groupId       = __GROUPID__
          $(date_filter ja.modifiedDate)
          AND ja.status        = 0
          AND ja.version       = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
                AND ja2.status         = 0
          )
        GROUP BY ja.externalReferenceCode
        ORDER BY ja.externalReferenceCode;
    "

    check "JournalArticleLocalization – Title and description" "
        SELECT
            ja.externalReferenceCode,
            jal.languageId,
            jal.title,
            jal.description
        FROM JournalArticleLocalization jal
        JOIN JournalArticle ja
          ON ja.id_            = jal.articlePK
         AND ja.ctCollectionId = 0
        WHERE ja.groupId       = __GROUPID__
          $(date_filter ja.modifiedDate)
          AND ja.status        = 0
          AND ja.version       = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
                AND ja2.status         = 0
          )
        ORDER BY ja.externalReferenceCode, jal.languageId;
    "

    # =========================================================================
    # DDMField + DDMFieldAttribute  (article content)
    # Content is stored per field in DDMField/DDMFieldAttribute,
    # both linked directly via storageId = ja.id_
    # =========================================================================

    # Counts DDMField rows that actually carry data — not every field defined
    # in the structure. On import Liferay materializes a DDMField row for
    # every field in the structure (including Fieldset containers and any
    # nested fields the source never wrote to), each with a single empty
    # DDMFieldAttribute placeholder. Source from older Liferay versions
    # stored only fields that received user input, so target ends up with
    # extra "ghost" rows for empty nested fields (a Fieldset's Date+Text
    # children, etc.) that have no twin on source.
    #
    # The EXISTS filter requires at least one DDMFieldAttribute with a non-
    # empty small or large value, so the count reflects fields the article
    # actually populated. Field-content equality is verified by the
    # "DDMFieldAttribute – Content checksum" check below; this one verifies
    # the *shape* (same number of value-carrying fields per article).
    check "DDMField – Field count per article (latest versions)" "
        SELECT
            ja.externalReferenceCode,
            COUNT(DISTINCT df.fieldId) AS field_count
        FROM JournalArticle ja
        JOIN DDMField df
          ON df.storageId       = ja.id_
         AND df.ctCollectionId  = 0
        WHERE ja.groupId        = __GROUPID__
          AND ja.ctCollectionId = 0
          $(date_filter ja.modifiedDate)
          AND ja.status         = 0
          AND ja.version        = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
                AND ja2.status         = 0
          )
          AND EXISTS (
              SELECT 1 FROM DDMFieldAttribute dfa
              WHERE dfa.fieldId       = df.fieldId
                AND dfa.ctCollectionId = 0
                AND COALESCE(dfa.smallAttributeValue, dfa.largeAttributeValue) IS NOT NULL
                AND COALESCE(dfa.smallAttributeValue, dfa.largeAttributeValue) != ''
          )
        GROUP BY ja.externalReferenceCode
        ORDER BY ja.externalReferenceCode;
    "

    # Three nuances baked into this checksum query, each one a real source
    # of import-time noise we have to design around:
    #
    # 1. Repeatable-field ordering. ORDER BY fieldName/languageId/
    #    attributeName isn't enough to disambiguate multiple instances of
    #    a repeatable field (e.g. four 'subheading' rows with the same
    #    fieldName, attributeName=NULL, same languageId). The actual
    #    instance order is encoded in DDMField.priority + DDMField
    #    .instanceId, both of which Liferay PRESERVES across export/import
    #    (same instanceId tokens 'j6cy1P8c', '0TjIBckn', etc. on both
    #    sides). Including both in the GROUP_CONCAT ORDER BY makes the hash
    #    deterministic and source/target-stable.
    #
    # 2. Asset/picker reference normalization. When a field references a
    #    DLFileEntry/AssetEntry (fieldName='asset', 'logo', etc.), the
    #    source stores a verbose set of attributes (alt, fileEntryId, name,
    #    resourcePrimKey, title, classPK, groupId, uuid, type). The import
    #    rewrites these into a compact form: it strips alt/fileEntryId/
    #    name/resourcePrimKey, remaps classPK and groupId to target IDs,
    #    sometimes reformats title (drops file extension), and unquotes
    #    classPK. Only uuid and type round-trip identically. We restrict
    #    the comparison to attributeName IS NULL (the field's own value)
    #    or attributeName IN ('uuid','type') (the stable asset ref bits).
    #    Field-shape divergence is caught by the 'DDMField – Field count'
    #    check above; this one is content-only.
    #
    # 3. Empty articles. An article whose schema includes a field that
    #    never received user input (e.g. a Text field left blank) lives in
    #    source as a DDMField row with zero DDMFieldAttribute rows. The
    #    import materializes the missing attribute with a NULL value, so
    #    target has one row where source has none. LEFT JOIN with the
    #    attributeName filter in the join's ON clause (not WHERE) keeps
    #    the article in the result on both sides, and IFNULL on the
    #    GROUP_CONCAT folds an all-NULL result into a stable empty-string
    #    hash that both sides agree on.
    check "DDMFieldAttribute – Content checksum per article (latest versions)" "
        SELECT
            ja.externalReferenceCode,
            MD5(IFNULL(GROUP_CONCAT(
                df.fieldName, '/', df.instanceId, '/', dfa.attributeName, '=',
                COALESCE(dfa.largeAttributeValue, dfa.smallAttributeValue)
                ORDER BY df.priority, df.instanceId, dfa.languageId, dfa.attributeName
            ), '')) AS content_hash
        FROM JournalArticle ja
        LEFT JOIN DDMField df
               ON df.storageId       = ja.id_
              AND df.ctCollectionId  = 0
        LEFT JOIN DDMFieldAttribute dfa
               ON dfa.fieldId        = df.fieldId
              AND dfa.storageId      = ja.id_
              AND dfa.ctCollectionId = 0
              AND (dfa.attributeName IS NULL
                   OR dfa.attributeName IN ('uuid','type'))
        WHERE ja.groupId        = __GROUPID__
          AND ja.ctCollectionId = 0
          $(date_filter ja.modifiedDate)
          AND ja.status         = 0
          AND ja.version        = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
                AND ja2.status         = 0
          )
        GROUP BY ja.externalReferenceCode
        ORDER BY ja.externalReferenceCode;
    "

    # =========================================================================
    # JournalArticleResource
    # =========================================================================

    check "JournalArticleResource – Total count" "
        SELECT
            COUNT(*)        AS total_resources
        FROM JournalArticleResource jar
        WHERE jar.groupId        = __GROUPID__
          AND jar.ctCollectionId = 0
          AND EXISTS (
              SELECT 1 FROM JournalArticle ja
              WHERE ja.resourcePrimKey = jar.resourcePrimKey
                AND ja.ctCollectionId  = 0
                AND ja.status          = 0
                $(date_filter ja.modifiedDate)
          );
    "

    check "JournalArticleResource – Identifiers" "
        SELECT
            jar.articleId,
            jar.uuid_
        FROM JournalArticleResource jar
        WHERE jar.groupId        = __GROUPID__
          AND jar.ctCollectionId = 0
          AND EXISTS (
              SELECT 1 FROM JournalArticle ja
              WHERE ja.resourcePrimKey = jar.resourcePrimKey
                AND ja.ctCollectionId  = 0
                AND ja.status          = 0
                $(date_filter ja.modifiedDate)
          )
        ORDER BY jar.articleId;
    "

    # =========================================================================
    # JournalFolder
    # =========================================================================

    check "JournalFolder – Total count" "
        SELECT
            COUNT(*)        AS total_folders
        FROM JournalFolder
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate);
    "

    check "JournalFolder – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_,
            name
        FROM JournalFolder
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "JournalFolder – Names and descriptions" "
        SELECT
            externalReferenceCode,
            name,
            description
        FROM JournalFolder
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "JournalFolder – Hierarchy" "
        SELECT
            f.externalReferenceCode,
            f.name,
            COALESCE(p.name, '(root)') AS parent_name
        FROM JournalFolder f
        LEFT JOIN JournalFolder p
               ON p.folderId       = f.parentFolderId
              AND p.ctCollectionId = 0
        WHERE f.groupId        = __GROUPID__
          AND f.ctCollectionId = 0
          $(date_filter f.modifiedDate)
        ORDER BY f.externalReferenceCode;
    "

    check "JournalFolder – Article count per folder" "
        SELECT
            COALESCE(jf.externalReferenceCode, '(root)') AS folder_erc,
            COALESCE(jf.name, '(root)')                  AS folder_name,
            COUNT(*)                                     AS article_count
        FROM JournalArticle ja
        LEFT JOIN JournalFolder jf
               ON jf.folderId       = ja.folderId
              AND jf.ctCollectionId = 0
        WHERE ja.groupId        = __GROUPID__
          AND ja.ctCollectionId = 0
          $(date_filter ja.modifiedDate)
          AND ja.status         = 0
          AND ja.version        = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
                AND ja2.status         = 0
          )
        GROUP BY folder_erc, folder_name
        ORDER BY folder_erc;
    "

    check "JournalFolder – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM JournalFolder
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "
}