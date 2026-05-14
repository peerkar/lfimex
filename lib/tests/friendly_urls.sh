# =============================================================================
# Test: FRIENDLY URLS
# Tables: FriendlyURLEntry, FriendlyURLEntryLocalization
# =============================================================================
#
# Data model:
#   FriendlyURLEntry tracks which entity (classNameId + classPK) has
#   friendly URLs. The actual URL titles are stored per language in
#   FriendlyURLEntryLocalization, linked via friendlyURLEntryId.
#
# Covered entity types:
#   Layout             →  page friendly URLs
#   BlogsEntry         →  blog entry friendly URLs
#   DLFileEntry        →  document friendly URLs
#   JournalArticle     →  web content friendly URLs
#   AssetCategory      →  category friendly URLs
#   WikiPage           →  wiki page friendly URLs
# =============================================================================

test_friendly_urls() {
    section "FRIENDLY URLS"

    # =========================================================================
    # FriendlyURLEntry
    # =========================================================================

    check "FriendlyURLEntry – Total count" "
        SELECT
            COUNT(*)        AS total_friendly_urls
        FROM FriendlyURLEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate);
    "

    check "FriendlyURLEntry – Count by entity type" "
        SELECT
            cn.value        AS class_name,
            COUNT(*)        AS total
        FROM FriendlyURLEntry f
        JOIN ClassName_ cn
          ON cn.classNameId  = f.classNameId
        WHERE f.groupId        = __GROUPID__
          AND f.ctCollectionId = 0
          $(date_filter f.modifiedDate)
        GROUP BY cn.value
        ORDER BY cn.value;
    "

    check "FriendlyURLEntry – Identifiers" "
        SELECT
            cn.value        AS class_name,
            f.uuid_
        FROM FriendlyURLEntry f
        JOIN ClassName_ cn
          ON cn.classNameId  = f.classNameId
        WHERE f.groupId        = __GROUPID__
          AND f.ctCollectionId = 0
          $(date_filter f.modifiedDate)
        ORDER BY cn.value, f.uuid_;
    "

    check "FriendlyURLEntry – Layout (pages)" "
        SELECT
            l.externalReferenceCode AS page_erc,
            l.friendlyURL,
            fel.languageId,
            fel.urlTitle
        FROM FriendlyURLEntry f
        JOIN FriendlyURLEntryLocalization fel
          ON fel.friendlyURLEntryId = f.friendlyURLEntryId
         AND fel.ctCollectionId     = 0
        JOIN Layout l
          ON l.plid           = f.classPK
         AND l.ctCollectionId = 0
        WHERE f.groupId        = __GROUPID__
          AND f.ctCollectionId = 0
          AND f.classNameId    = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.portal.kernel.model.Layout'
          )
          $(date_filter f.modifiedDate)
        ORDER BY l.externalReferenceCode, fel.languageId;
    "

    check "FriendlyURLEntry – BlogsEntry" "
        SELECT
            be.externalReferenceCode AS entry_erc,
            be.urlTitle              AS entry_url_title,
            fel.languageId,
            fel.urlTitle             AS friendly_url
        FROM FriendlyURLEntry f
        JOIN FriendlyURLEntryLocalization fel
          ON fel.friendlyURLEntryId = f.friendlyURLEntryId
         AND fel.ctCollectionId     = 0
        JOIN BlogsEntry be
          ON be.entryId        = f.classPK
         AND be.ctCollectionId = 0
        WHERE f.groupId        = __GROUPID__
          AND f.ctCollectionId = 0
          AND f.classNameId    = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.blogs.model.BlogsEntry'
          )
          $(date_filter f.modifiedDate)
        ORDER BY be.externalReferenceCode, fel.languageId;
    "

    check "FriendlyURLEntry – DLFileEntry" "
        SELECT
            fe.externalReferenceCode AS file_erc,
            fe.fileName,
            fel.languageId,
            fel.urlTitle
        FROM FriendlyURLEntry f
        JOIN FriendlyURLEntryLocalization fel
          ON fel.friendlyURLEntryId = f.friendlyURLEntryId
         AND fel.ctCollectionId     = 0
        JOIN DLFileEntry fe
          ON fe.fileEntryId    = f.classPK
         AND fe.ctCollectionId = 0
        WHERE f.groupId        = __GROUPID__
          AND f.ctCollectionId = 0
          AND f.classNameId    = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.document.library.kernel.model.DLFileEntry'
          )
          $(date_filter f.modifiedDate)
        ORDER BY fe.externalReferenceCode, fel.languageId;
    "

    check "FriendlyURLEntry – JournalArticle (latest versions)" "
        SELECT
            ja.externalReferenceCode,
            ja.articleId,
            fel.languageId,
            fel.urlTitle
        FROM FriendlyURLEntry f
        JOIN FriendlyURLEntryLocalization fel
          ON fel.friendlyURLEntryId = f.friendlyURLEntryId
         AND fel.ctCollectionId     = 0
        JOIN JournalArticle ja
          ON ja.resourcePrimKey = f.classPK
         AND ja.ctCollectionId  = 0
         AND ja.version         = (
              SELECT MAX(ja2.version)
              FROM JournalArticle ja2
              WHERE ja2.articleId      = ja.articleId
                AND ja2.groupId        = ja.groupId
                AND ja2.ctCollectionId = 0
          )
        WHERE f.groupId        = __GROUPID__
          AND f.ctCollectionId = 0
          AND f.classNameId    = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.journal.model.JournalArticle'
          )
          $(date_filter f.modifiedDate)
        ORDER BY ja.externalReferenceCode, fel.languageId;
    "

    check "FriendlyURLEntry – AssetCategory" "
        SELECT
            ac.externalReferenceCode AS category_erc,
            ac.name                  AS category_name,
            fel.languageId,
            fel.urlTitle
        FROM FriendlyURLEntry f
        JOIN FriendlyURLEntryLocalization fel
          ON fel.friendlyURLEntryId = f.friendlyURLEntryId
         AND fel.ctCollectionId     = 0
        JOIN AssetCategory ac
          ON ac.categoryId     = f.classPK
         AND ac.ctCollectionId = 0
        WHERE f.groupId        = __GROUPID__
          AND f.ctCollectionId = 0
          AND f.classNameId    = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.asset.kernel.model.AssetCategory'
          )
          $(date_filter f.modifiedDate)
        ORDER BY ac.externalReferenceCode, fel.languageId;
    "

    check "FriendlyURLEntry – WikiPage (head versions)" "
        SELECT
            wp.externalReferenceCode AS page_erc,
            wp.title,
            fel.languageId,
            fel.urlTitle
        FROM FriendlyURLEntry f
        JOIN FriendlyURLEntryLocalization fel
          ON fel.friendlyURLEntryId = f.friendlyURLEntryId
         AND fel.ctCollectionId     = 0
        JOIN WikiPage wp
          ON wp.resourcePrimKey = f.classPK
         AND wp.head            = 1
         AND wp.ctCollectionId  = 0
        WHERE f.groupId        = __GROUPID__
          AND f.ctCollectionId = 0
          AND f.classNameId    = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.wiki.model.WikiPage'
          )
          $(date_filter f.modifiedDate)
        ORDER BY wp.externalReferenceCode, fel.languageId;
    "

    check "FriendlyURLEntry – Dates" "
        SELECT
            cn.value        AS class_name,
            f.uuid_,
            f.createDate,
            f.modifiedDate
        FROM FriendlyURLEntry f
        JOIN ClassName_ cn
          ON cn.classNameId  = f.classNameId
        WHERE f.groupId        = __GROUPID__
          AND f.ctCollectionId = 0
          $(date_filter f.modifiedDate)
        ORDER BY cn.value, f.uuid_;
    "

    # =========================================================================
    # FriendlyURLEntryLocalization
    # =========================================================================

    check "FriendlyURLEntryLocalization – Total count" "
        SELECT
            COUNT(*)        AS total_localized_urls
        FROM FriendlyURLEntryLocalization fel
        JOIN FriendlyURLEntry f
          ON f.friendlyURLEntryId = fel.friendlyURLEntryId
         AND f.ctCollectionId     = 0
        WHERE f.groupId           = __GROUPID__
          AND fel.ctCollectionId  = 0
          $(date_filter f.modifiedDate);
    "

    check "FriendlyURLEntryLocalization – Count by entity type and language" "
        SELECT
            cn.value        AS class_name,
            fel.languageId,
            COUNT(*)        AS total
        FROM FriendlyURLEntryLocalization fel
        JOIN FriendlyURLEntry f
          ON f.friendlyURLEntryId = fel.friendlyURLEntryId
         AND f.ctCollectionId     = 0
        JOIN ClassName_ cn
          ON cn.classNameId       = f.classNameId
        WHERE f.groupId           = __GROUPID__
          AND fel.ctCollectionId  = 0
          $(date_filter f.modifiedDate)
        GROUP BY cn.value, fel.languageId
        ORDER BY cn.value, fel.languageId;
    "

    check "FriendlyURLEntryLocalization – URLs per entity" "
        SELECT
            cn.value        AS class_name,
            f.uuid_         AS friendly_url_uuid,
            fel.languageId,
            fel.urlTitle
        FROM FriendlyURLEntryLocalization fel
        JOIN FriendlyURLEntry f
          ON f.friendlyURLEntryId = fel.friendlyURLEntryId
         AND f.ctCollectionId     = 0
        JOIN ClassName_ cn
          ON cn.classNameId       = f.classNameId
        WHERE f.groupId           = __GROUPID__
          AND fel.ctCollectionId  = 0
          $(date_filter f.modifiedDate)
        ORDER BY cn.value, f.uuid_, fel.languageId;
    "
}
