# =============================================================================
# Test: BLOGS
# Tables: BlogsEntry, DLFileEntry (cover image)
# =============================================================================

test_blogs() {
    section "BLOGS"

    # =========================================================================
    # BlogsEntry
    # =========================================================================

    check "BlogsEntry – Total count of published entries" "
        SELECT
            COUNT(*)            AS total
        FROM BlogsEntry
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            AND status = 0
            $(date_filter modifiedDate);
    "

    check "BlogsEntry – Identifiers" "
        SELECT
            urlTitle,
            externalReferenceCode,
            uuid_
        FROM BlogsEntry
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            AND status = 0
            $(date_filter modifiedDate)
        ORDER BY urlTitle;
    "

    check "BlogsEntry – Titles and description" "
        SELECT
            urlTitle,
            title,
            MD5(subtitle)       AS subtitle_md5,
            LENGTH(subtitle)    AS subtitle_len,
            MD5(description)    AS description_md5,
            LENGTH(description) AS description_len
        FROM BlogsEntry
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            AND status = 0
            $(date_filter modifiedDate)
        ORDER BY urlTitle;
    "

    check "BlogsEntry – Pingbacks and trackbacks" "
        SELECT
            urlTitle,
            allowPingbacks,
            allowTrackbacks,
            MD5(trackbacks)     AS trackbacks_md5,
            LENGTH(trackbacks)  AS trackbacks_len
        FROM BlogsEntry
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            AND status = 0
            $(date_filter modifiedDate)
        ORDER BY urlTitle;
    "

    check "BlogsEntry – Small image and cover image caption" "
        SELECT
            urlTitle,
            smallImage,
            coverImageCaption
        FROM BlogsEntry
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            AND status = 0
            $(date_filter modifiedDate)
        ORDER BY urlTitle;
    "

    check "BlogsEntry – Content checksums" "
        SELECT
            urlTitle,
            MD5(content)       AS content_hash,
            LENGTH(content)    AS content_length
        FROM BlogsEntry
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            AND status = 0
            $(date_filter modifiedDate)
        ORDER BY urlTitle;
    "

    check "BlogsEntry – Cover image" "
        SELECT
            be.urlTitle,
            dlfe.fileName       AS cover_image_file
        FROM BlogsEntry be
        LEFT JOIN DLFileEntry dlfe
               ON dlfe.fileEntryId = be.coverImageFileEntryId
              AND be.coverImageFileEntryId > 0
              AND dlfe.ctCollectionId = 0
        WHERE be.groupId = __GROUPID__
            AND be.ctCollectionId = 0
            AND be.status = 0
            $(date_filter be.modifiedDate)
        ORDER BY be.urlTitle;
    "

    check "BlogsEntry – Small image" "
        SELECT
            be.urlTitle,
            dlfe.fileName       AS small_image_file
        FROM BlogsEntry be
        LEFT JOIN DLFileEntry dlfe
               ON dlfe.fileEntryId = be.smallImageFileEntryId
              AND be.smallImageFileEntryId > 0
              AND dlfe.ctCollectionId = 0
        WHERE be.groupId = __GROUPID__
            AND be.ctCollectionId = 0
            AND be.status = 0
            $(date_filter be.modifiedDate)
        ORDER BY be.urlTitle;
    "

    check "BlogsEntry – Dates" "
        SELECT
            urlTitle,
            displayDate,
            createDate,
            modifiedDate
        FROM BlogsEntry
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            AND status = 0
            $(date_filter modifiedDate)
        ORDER BY urlTitle;
    "
}
