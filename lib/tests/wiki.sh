# =============================================================================
# Test: WIKIS
# Tables: WikiNode, WikiPage, DLFileEntry (attachments)
# =============================================================================

test_wiki() {
    section "WIKI"

    # =========================================================================
    # WikiNode
    # =========================================================================

    check "WikiNode – Total Count" "
        SELECT
            COUNT(*)    AS total
        FROM WikiNode
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            $(date_filter modifiedDate);
    "

    check "WikiNode – Identifiers" "
        SELECT
            name,
            externalReferenceCode,
            uuid_
        FROM WikiNode
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            $(date_filter modifiedDate)
        ORDER BY name;
    "

    check "WikiNode – Name and description" "
        SELECT
            name,
            MD5(NULLIF(description, ''))                AS description_md5
        FROM WikiNode
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            $(date_filter modifiedDate)
        ORDER BY name;
    "

    check "WikiNode – Core fields" "
        SELECT
            name,
            status
        FROM WikiNode
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            $(date_filter modifiedDate)
        ORDER BY name;
    "

    check "WikiNode – Dates" "
        SELECT
            name,
            createDate,
            modifiedDate,
            lastPostDate
        FROM WikiNode
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            $(date_filter modifiedDate)
        ORDER BY name;
    "

    # =========================================================================
    # WikiPage
    # =========================================================================

    check "WikiPage – Head page and version count per node" "
        SELECT
            n.name              AS node_name,
            SUM(p.head)         AS head_pages,
            COUNT(*)            AS total_versions,
            MAX(p.version)      AS max_version
        FROM WikiPage p
        JOIN WikiNode n ON p.nodeId = n.nodeId
             AND n.ctCollectionId = 0
        WHERE p.status = 0
          AND n.groupId = __GROUPID__
          AND p.ctCollectionId = 0
          $(date_filter p.modifiedDate)
        GROUP BY n.name
        ORDER BY n.name;
    "

    check "WikiPage – Identifiers" "
        SELECT
            n.name      AS node_name,
            p.externalReferenceCode,
            p.uuid_
        FROM WikiPage p
        JOIN WikiNode n ON p.nodeId = n.nodeId
             AND n.ctCollectionId = 0
        WHERE p.head = 1
          AND n.groupId = __GROUPID__
          AND p.ctCollectionId = 0
          $(date_filter p.modifiedDate)
        ORDER BY n.name, p.title;
    "

    check "WikiPage – Format, titles and summary" "
        SELECT
            n.name      AS node_name,
            p.title,
            p.format,
            p.parentTitle,
            p.redirectTitle,
            MD5(p.summary)      AS summary_md5,
            LENGTH(p.summary)   AS summary_len
        FROM WikiPage p
        JOIN WikiNode n ON p.nodeId = n.nodeId
             AND n.ctCollectionId = 0
        WHERE p.head = 1
          AND n.groupId = __GROUPID__
          AND p.ctCollectionId = 0
          $(date_filter p.modifiedDate)
        ORDER BY n.name, p.title;
    "

    check "WikiPage – Content checksums" "
        SELECT
            n.name              AS node_name,
            p.title,
            MD5(p.content)      AS content_hash,
            LENGTH(p.content)   AS content_length
        FROM WikiPage p
        JOIN WikiNode n ON p.nodeId = n.nodeId
             AND n.ctCollectionId = 0
        WHERE p.head = 1
          AND n.groupId = __GROUPID__
          AND p.ctCollectionId = 0
          $(date_filter p.modifiedDate)
        ORDER BY n.name, p.title;
    "

    check "WikiPage – Dates" "
        SELECT
            n.name          AS node_name,
            p.title,
            p.createDate,
            p.modifiedDate
        FROM WikiPage p
        JOIN WikiNode n ON p.nodeId = n.nodeId
             AND n.ctCollectionId = 0
        WHERE p.head = 1
          AND n.groupId = __GROUPID__
          AND p.ctCollectionId = 0
          $(date_filter p.modifiedDate)
        ORDER BY n.name, p.title;
    "

    check "WikiPage – Version and count of versions" "
        SELECT
            n.name              AS node_name,
            p.title,
            COUNT(*)            AS version_count,
            MAX(p.version)      AS latest_version
        FROM WikiPage p
        JOIN WikiNode n ON p.nodeId = n.nodeId
             AND n.ctCollectionId = 0
        WHERE n.groupId = __GROUPID__
          AND p.ctCollectionId = 0
          $(date_filter p.modifiedDate)
        GROUP BY n.name, p.title
        ORDER BY n.name, p.title;
    "

    check "WikiPage – Attachment count per node" "
        SELECT
            n.name                      AS node_name,
            COUNT(dlfe.fileEntryId)     AS attachment_count
        FROM WikiNode n
        LEFT JOIN WikiPage p
               ON p.nodeId = n.nodeId
              AND p.head   = 1
              AND p.ctCollectionId = 0
        LEFT JOIN DLFileEntry dlfe
               ON dlfe.classNameId = (
                      SELECT classNameId FROM ClassName_
                      WHERE  value = 'com.liferay.wiki.model.WikiPage'
                  )
              AND dlfe.classPK = p.resourcePrimKey
              AND dlfe.ctCollectionId = 0
        WHERE n.groupId = __GROUPID__
          AND n.ctCollectionId = 0
          $(date_filter n.modifiedDate)
        GROUP BY n.name
        ORDER BY n.name;
    "
}
