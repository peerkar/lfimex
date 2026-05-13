# =============================================================================
# Module: WEB CONTENT
# Tables: DDMStructure, JournalArticle, JournalArticleLocalization,
#         JournalArticleResource, JournalFolder,
#         DDMField, DDMFieldAttribute
# =============================================================================
#
# Version note:
#   JournalArticle has no head column. Latest version is identified by
#   MAX(version) per articleId scoped to groupId and ctCollectionId = 0.
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
          );
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
        ORDER BY structureKey;
    "

    check "DDMStructure – Definition checksum" "
        SELECT
            structureKey,
            MD5(definition)     AS definition_hash,
            LENGTH(definition)  AS definition_length
        FROM DDMStructure
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND classNameId    = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.journal.model.JournalArticle'
          )
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
        ORDER BY structureKey;
    "

    # =========================================================================
    # JournalArticle
    # =========================================================================

    check "JournalArticle – Total count" "
        SELECT
            COUNT(*)        AS total
        FROM JournalArticle
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate);
    "

    check "JournalArticle – Count of latest versions by status" "
        SELECT
            ja.status,
            COUNT(*)        AS total
        FROM JournalArticle ja
        WHERE ja.groupId        = __GROUPID__
          AND ja.ctCollectionId = 0
          $(date_filter ja.modifiedDate)
          AND ja.version        = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
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
          AND ja.version        = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
          )
        ORDER BY ja.externalReferenceCode;
    "

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
          AND ja.version        = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
          )
        ORDER BY ja.externalReferenceCode;
    "

    check "JournalArticle – Version history count per article" "
        SELECT
            externalReferenceCode,
            articleId,
            COUNT(*)        AS version_count
        FROM JournalArticle
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
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
          AND ja.version        = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
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
          AND ja.version       = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
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
          AND ja.version       = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
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
          AND ja.version       = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
          )
        ORDER BY ja.externalReferenceCode, jal.languageId;
    "

    # =========================================================================
    # DDMField + DDMFieldAttribute  (article content)
    # Content is stored per field in DDMField/DDMFieldAttribute,
    # both linked directly via storageId = ja.id_
    # =========================================================================

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
          AND ja.version        = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
          )
        GROUP BY ja.externalReferenceCode
        ORDER BY ja.externalReferenceCode;
    "

    check "DDMFieldAttribute – Content checksum per article (latest versions)" "
        SELECT
            ja.externalReferenceCode,
            MD5(GROUP_CONCAT(
                dfa.attributeName, '=', COALESCE(dfa.largeAttributeValue, dfa.smallAttributeValue)
                ORDER BY df.fieldName, dfa.languageId, dfa.attributeName
            )) AS content_hash
        FROM JournalArticle ja
        JOIN DDMField df
          ON df.storageId       = ja.id_
         AND df.ctCollectionId  = 0
        JOIN DDMFieldAttribute dfa
          ON dfa.fieldId        = df.fieldId
         AND dfa.storageId      = ja.id_
         AND dfa.ctCollectionId = 0
        WHERE ja.groupId        = __GROUPID__
          AND ja.ctCollectionId = 0
          $(date_filter ja.modifiedDate)
          AND ja.version        = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
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
        FROM JournalArticleResource
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0;
    "

    check "JournalArticleResource – Identifiers" "
        SELECT
            articleId,
            uuid_
        FROM JournalArticleResource
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY articleId;
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
          AND ja.version        = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
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