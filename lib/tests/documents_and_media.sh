# =============================================================================
# Test: DOCUMENTS & MEDIA
# Tables: DLFileEntry, DLFileEntryMetadata, DLFileEntryType,
#         DLFileEntryTypes_DLFolders, DLFileShortcut, DLFileVersion,
#         DLFolder, DDMField, DDMFieldAttribute, DDMStructure
# =============================================================================
#
# Version note:
#   DLFileVersion has no head/latest flag. Latest version is resolved by
#   joining DLFileEntry.version = DLFileVersion.version to avoid
#   lexicographic issues with MAX() on a varchar version column.
#
# Export-ADQ alignment:
#   FileEntryStagedModelRepository.getExportActionableDynamicQuery filters
#   DLFileEntry to rows where the latest DLFileVersion.status = APPROVED (0)
#   and repositoryId is in DLExportableRepositoryPublisherUtil.publish(...),
#   which for sites is effectively repositoryId = groupId (mounted external
#   repos are excluded). Trashed file entries and rows in mounted repos
#   therefore never ship, so the source-side count must filter the same way
#   or it drifts above the importable count on the target.
#   FolderStagedModelRepository likewise restricts to repositoryId = groupId
#   and skips trashed folders at perform time; the FileShortcut ADQ adds
#   active_ = TRUE. All counts/identifier queries below mirror those filters.
# =============================================================================

test_documents_and_media() {
    section "DOCUMENTS & MEDIA"

    # =========================================================================
    # DLFileEntry
    # =========================================================================

    check "DLFileEntry – Total count" "
        SELECT
            COUNT(*)        AS total_files
        FROM DLFileEntry fe
        JOIN DLFileVersion fv
          ON fv.fileEntryId    = fe.fileEntryId
         AND fv.version        = fe.version
         AND fv.ctCollectionId = 0
         AND fv.status         = 0
        WHERE fe.groupId        = __GROUPID__
          AND fe.repositoryId   = fe.groupId
          AND fe.ctCollectionId = 0
          $(date_filter fe.modifiedDate);
    "

    check "DLFileEntry – Count by MIME type" "
        SELECT
            fe.mimeType,
            COUNT(*)        AS total
        FROM DLFileEntry fe
        JOIN DLFileVersion fv
          ON fv.fileEntryId    = fe.fileEntryId
         AND fv.version        = fe.version
         AND fv.ctCollectionId = 0
         AND fv.status         = 0
        WHERE fe.groupId        = __GROUPID__
          AND fe.repositoryId   = fe.groupId
          AND fe.ctCollectionId = 0
          $(date_filter fe.modifiedDate)
        GROUP BY fe.mimeType
        ORDER BY fe.mimeType;
    "

    check "DLFileEntry – Identifiers" "
        SELECT
            fe.externalReferenceCode,
            fe.uuid_,
            fe.fileName
        FROM DLFileEntry fe
        JOIN DLFileVersion fv
          ON fv.fileEntryId    = fe.fileEntryId
         AND fv.version        = fe.version
         AND fv.ctCollectionId = 0
         AND fv.status         = 0
        WHERE fe.groupId        = __GROUPID__
          AND fe.repositoryId   = fe.groupId
          AND fe.ctCollectionId = 0
          $(date_filter fe.modifiedDate)
        ORDER BY fe.externalReferenceCode;
    "

    check "DLFileEntry – Titles and descriptions" "
        SELECT
            fe.externalReferenceCode,
            fe.title,
            fe.description
        FROM DLFileEntry fe
        JOIN DLFileVersion fv
          ON fv.fileEntryId    = fe.fileEntryId
         AND fv.version        = fe.version
         AND fv.ctCollectionId = 0
         AND fv.status         = 0
        WHERE fe.groupId        = __GROUPID__
          AND fe.repositoryId   = fe.groupId
          AND fe.ctCollectionId = 0
          $(date_filter fe.modifiedDate)
        ORDER BY fe.externalReferenceCode;
    "

    check "DLFileEntry – Core fields" "
        SELECT
            fe.externalReferenceCode,
            fe.fileName,
            fe.mimeType,
            fe.size_,
            fe.version,
            COALESCE(ft.fileEntryTypeKey, '(basic document)') AS file_entry_type,
            COALESCE(f.externalReferenceCode, '(root)')       AS folder_erc
        FROM DLFileEntry fe
        JOIN DLFileVersion fv
          ON fv.fileEntryId    = fe.fileEntryId
         AND fv.version        = fe.version
         AND fv.ctCollectionId = 0
         AND fv.status         = 0
        LEFT JOIN DLFileEntryType ft
               ON ft.fileEntryTypeId  = fe.fileEntryTypeId
              AND ft.ctCollectionId   = 0
        LEFT JOIN DLFolder f
               ON f.folderId          = fe.folderId
              AND f.ctCollectionId    = 0
        WHERE fe.groupId        = __GROUPID__
          AND fe.repositoryId   = fe.groupId
          AND fe.ctCollectionId = 0
          $(date_filter fe.modifiedDate)
        ORDER BY fe.externalReferenceCode;
    "

    check "DLFileEntry – Version history count" "
        SELECT
            fe.externalReferenceCode,
            fe.fileName,
            COUNT(*)        AS version_count
        FROM DLFileEntry fe
        JOIN DLFileVersion latest
          ON latest.fileEntryId    = fe.fileEntryId
         AND latest.version        = fe.version
         AND latest.ctCollectionId = 0
         AND latest.status         = 0
        JOIN DLFileVersion fv
          ON fv.fileEntryId    = fe.fileEntryId
         AND fv.ctCollectionId = 0
        WHERE fe.groupId        = __GROUPID__
          AND fe.repositoryId   = fe.groupId
          AND fe.ctCollectionId = 0
          $(date_filter fe.modifiedDate)
        GROUP BY fe.externalReferenceCode, fe.fileName
        ORDER BY fe.externalReferenceCode;
    "

    check "DLFileEntry – Dates" "
        SELECT
            fe.externalReferenceCode,
            fe.displayDate,
            fe.createDate,
            fe.modifiedDate,
            fe.expirationDate,
            fe.reviewDate
        FROM DLFileEntry fe
        JOIN DLFileVersion fv
          ON fv.fileEntryId    = fe.fileEntryId
         AND fv.version        = fe.version
         AND fv.ctCollectionId = 0
         AND fv.status         = 0
        WHERE fe.groupId        = __GROUPID__
          AND fe.repositoryId   = fe.groupId
          AND fe.ctCollectionId = 0
          $(date_filter fe.modifiedDate)
        ORDER BY fe.externalReferenceCode;
    "

    # =========================================================================
    # DLFileEntryMetadata
    # =========================================================================

    check "DLFileEntryMetadata – Total count" "
        SELECT
            COUNT(*)        AS total_metadata_sets
        FROM DLFileEntryMetadata fem
        JOIN DLFileEntry fe
          ON fe.fileEntryId    = fem.fileEntryId
         AND fe.ctCollectionId = 0
        JOIN DLFileVersion fv
          ON fv.fileEntryId    = fe.fileEntryId
         AND fv.version        = fe.version
         AND fv.ctCollectionId = 0
         AND fv.status         = 0
        WHERE fe.groupId         = __GROUPID__
          AND fe.repositoryId    = fe.groupId
          AND fem.ctCollectionId = 0
          $(date_filter fe.modifiedDate);
    "

    check "DLFileEntryMetadata – Count per file entry type" "
        SELECT
            COALESCE(ft.fileEntryTypeKey, '(basic document)') AS file_entry_type,
            COUNT(*)        AS metadata_count
        FROM DLFileEntryMetadata fem
        JOIN DLFileEntry fe
          ON fe.fileEntryId      = fem.fileEntryId
         AND fe.ctCollectionId   = 0
        JOIN DLFileVersion fv
          ON fv.fileEntryId    = fe.fileEntryId
         AND fv.version        = fe.version
         AND fv.ctCollectionId = 0
         AND fv.status         = 0
        LEFT JOIN DLFileEntryType ft
               ON ft.fileEntryTypeId  = fe.fileEntryTypeId
              AND ft.ctCollectionId   = 0
        WHERE fe.groupId         = __GROUPID__
          AND fe.repositoryId    = fe.groupId
          AND fem.ctCollectionId = 0
          $(date_filter fe.modifiedDate)
        GROUP BY file_entry_type
        ORDER BY file_entry_type;
    "

    # NOTE: a "DLFileEntryMetadata – Identifiers" check used to live here
    # comparing fem.externalReferenceCode + fem.uuid_ + file_erc per row, but
    # the first two columns are server-regenerated on import (the LAR's
    # FileEntryStagedModelDataHandler ships only structureKey/structureUuid
    # + the DDMFormValues blob, not the metadata-row's own ERC/uuid). The
    # `Content checksum per file` check below already groups by
    # (file_erc, structureKey) and asserts byte-equal content, which is
    # strictly stronger than presence-by-natural-key — if a metadata row is
    # missing on target, its MD5 is absent and the diff catches it. Drop
    # rather than ignore.

    check "DLFileEntryMetadata – Content checksum per file" "
        SELECT
            fe.externalReferenceCode AS file_erc,
            ds.structureKey,
            MD5(GROUP_CONCAT(
                dfa.attributeName, '=', COALESCE(dfa.largeAttributeValue, dfa.smallAttributeValue)
                ORDER BY df.fieldName, dfa.languageId, dfa.attributeName
            )) AS content_hash
        FROM DLFileEntryMetadata fem
        JOIN DLFileEntry fe
          ON fe.fileEntryId      = fem.fileEntryId
         AND fe.ctCollectionId   = 0
        JOIN DLFileVersion fv
          ON fv.fileEntryId    = fe.fileEntryId
         AND fv.version        = fe.version
         AND fv.ctCollectionId = 0
         AND fv.status         = 0
        JOIN DDMStructure ds
          ON ds.structureId      = fem.DDMStructureId
         AND ds.ctCollectionId   = 0
        JOIN DDMField df
          ON df.storageId        = fem.DDMStorageId
         AND df.ctCollectionId   = 0
        JOIN DDMFieldAttribute dfa
          ON dfa.fieldId         = df.fieldId
         AND dfa.storageId       = fem.DDMStorageId
         AND dfa.ctCollectionId  = 0
        WHERE fe.groupId         = __GROUPID__
          AND fe.repositoryId    = fe.groupId
          AND fem.ctCollectionId = 0
          $(date_filter fe.modifiedDate)
        GROUP BY fe.externalReferenceCode, ds.structureKey
        ORDER BY fe.externalReferenceCode, ds.structureKey;
    "

    # =========================================================================
    # DLFileEntryType
    # =========================================================================

    check "DLFileEntryType – Total count" "
        SELECT
            COUNT(*)        AS total_file_entry_types
        FROM DLFileEntryType
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate);
    "

    check "DLFileEntryType – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_,
            fileEntryTypeKey
        FROM DLFileEntryType
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "DLFileEntryType – Names and descriptions" "
        SELECT
            externalReferenceCode,
            REGEXP_REPLACE(name,        '<[^>]+>', '') AS name_plain,
            REGEXP_REPLACE(description, '<[^>]+>', '') AS description_plain
        FROM DLFileEntryType
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "DLFileEntryType – Core fields" "
        SELECT
            ft.externalReferenceCode,
            ft.fileEntryTypeKey,
            COALESCE(ds.structureKey, '(none)') AS data_definition_key,
            ft.scope
        FROM DLFileEntryType ft
        LEFT JOIN DDMStructure ds
               ON ds.structureId    = ft.dataDefinitionId
              AND ds.ctCollectionId = 0
        WHERE ft.groupId        = __GROUPID__
          AND ft.ctCollectionId = 0
          $(date_filter ft.modifiedDate)
        ORDER BY ft.externalReferenceCode;
    "

    check "DLFileEntryType – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM DLFileEntryType
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    # =========================================================================
    # DLFileShortcut
    # =========================================================================

    check "DLFileShortcut – Total count" "
        SELECT
            COUNT(*)        AS total_shortcuts
        FROM DLFileShortcut
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND active_        = TRUE
          $(date_filter modifiedDate);
    "

    check "DLFileShortcut – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_
        FROM DLFileShortcut
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND active_        = TRUE
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "DLFileShortcut – Core fields" "
        SELECT
            fs.externalReferenceCode,
            fe.externalReferenceCode AS target_file_erc,
            fs.active_,
            fs.status
        FROM DLFileShortcut fs
        JOIN DLFileEntry fe
          ON fe.fileEntryId    = fs.toFileEntryId
         AND fe.ctCollectionId = 0
        WHERE fs.groupId        = __GROUPID__
          AND fs.ctCollectionId = 0
          AND fs.active_        = TRUE
          $(date_filter fs.modifiedDate)
        ORDER BY fs.externalReferenceCode;
    "

    check "DLFileShortcut – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM DLFileShortcut
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND active_        = TRUE
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    # =========================================================================
    # DLFileVersion
    # =========================================================================

    check "DLFileVersion – Total count" "
        SELECT
            COUNT(*)        AS total_file_versions
        FROM DLFileVersion fv
        JOIN DLFileEntry fe
          ON fe.fileEntryId    = fv.fileEntryId
         AND fe.ctCollectionId = 0
        JOIN DLFileVersion latest
          ON latest.fileEntryId    = fe.fileEntryId
         AND latest.version        = fe.version
         AND latest.ctCollectionId = 0
         AND latest.status         = 0
        WHERE fe.groupId        = __GROUPID__
          AND fe.repositoryId   = fe.groupId
          AND fv.ctCollectionId = 0
          $(date_filter fe.modifiedDate);
    "

    check "DLFileVersion – Latest version core fields" "
        SELECT
            fe.externalReferenceCode AS file_erc,
            fv.version,
            fv.mimeType,
            fv.size_,
            fv.status
        FROM DLFileEntry fe
        JOIN DLFileVersion fv
          ON fv.fileEntryId    = fe.fileEntryId
         AND fv.version        = fe.version
         AND fv.ctCollectionId = 0
         AND fv.status         = 0
        WHERE fe.groupId        = __GROUPID__
          AND fe.repositoryId   = fe.groupId
          AND fe.ctCollectionId = 0
          $(date_filter fe.modifiedDate)
        ORDER BY fe.externalReferenceCode;
    "

    check "DLFileVersion – Latest version checksum" "
        SELECT
            fe.externalReferenceCode AS file_erc,
            fv.checksum
        FROM DLFileEntry fe
        JOIN DLFileVersion fv
          ON fv.fileEntryId    = fe.fileEntryId
         AND fv.version        = fe.version
         AND fv.ctCollectionId = 0
         AND fv.status         = 0
        WHERE fe.groupId        = __GROUPID__
          AND fe.repositoryId   = fe.groupId
          AND fe.ctCollectionId = 0
          $(date_filter fe.modifiedDate)
        ORDER BY fe.externalReferenceCode;
    "

    check "DLFileVersion – Dates" "
        SELECT
            fe.externalReferenceCode AS file_erc,
            fv.uuid_,
            fv.createDate,
            fv.modifiedDate,
            fv.displayDate,
            fv.expirationDate,
            fv.reviewDate
        FROM DLFileVersion fv
        JOIN DLFileEntry fe
          ON fe.fileEntryId    = fv.fileEntryId
         AND fe.ctCollectionId = 0
        JOIN DLFileVersion latest
          ON latest.fileEntryId    = fe.fileEntryId
         AND latest.version        = fe.version
         AND latest.ctCollectionId = 0
         AND latest.status         = 0
        WHERE fe.groupId        = __GROUPID__
          AND fe.repositoryId   = fe.groupId
          AND fv.ctCollectionId = 0
          $(date_filter fe.modifiedDate)
        ORDER BY fe.externalReferenceCode, fv.version;
    "

    # =========================================================================
    # DLFolder
    # =========================================================================

    check "DLFolder – Total count" "
        SELECT
            COUNT(*)        AS total_folders
        FROM DLFolder
        WHERE groupId        = __GROUPID__
          AND repositoryId   = groupId
          AND ctCollectionId = 0
          AND status        <> 8
          $(date_filter modifiedDate);
    "

    check "DLFolder – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_,
            name
        FROM DLFolder
        WHERE groupId        = __GROUPID__
          AND repositoryId   = groupId
          AND ctCollectionId = 0
          AND status        <> 8
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "DLFolder – Names and descriptions" "
        SELECT
            externalReferenceCode,
            name,
            description
        FROM DLFolder
        WHERE groupId        = __GROUPID__
          AND repositoryId   = groupId
          AND ctCollectionId = 0
          AND status        <> 8
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "DLFolder – Hierarchy" "
        SELECT
            f.externalReferenceCode,
            f.name,
            COALESCE(p.name, '(root)') AS parent_name
        FROM DLFolder f
        LEFT JOIN DLFolder p
               ON p.folderId       = f.parentFolderId
              AND p.ctCollectionId = 0
        WHERE f.groupId        = __GROUPID__
          AND f.repositoryId   = f.groupId
          AND f.ctCollectionId = 0
          AND f.status        <> 8
          $(date_filter f.modifiedDate)
        ORDER BY f.externalReferenceCode;
    "

    check "DLFolder – File count per folder" "
        SELECT
            COALESCE(f.externalReferenceCode, '(root)') AS folder_erc,
            COALESCE(f.name, '(root)')                  AS folder_name,
            COUNT(*)                                    AS file_count
        FROM DLFileEntry fe
        JOIN DLFileVersion fv
          ON fv.fileEntryId    = fe.fileEntryId
         AND fv.version        = fe.version
         AND fv.ctCollectionId = 0
         AND fv.status         = 0
        LEFT JOIN DLFolder f
               ON f.folderId       = fe.folderId
              AND f.ctCollectionId = 0
        WHERE fe.groupId        = __GROUPID__
          AND fe.repositoryId   = fe.groupId
          AND fe.ctCollectionId = 0
          $(date_filter fe.modifiedDate)
        GROUP BY folder_erc, folder_name
        ORDER BY folder_erc;
    "

    check "DLFolder – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM DLFolder
        WHERE groupId        = __GROUPID__
          AND repositoryId   = groupId
          AND ctCollectionId = 0
          AND status        <> 8
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    # =========================================================================
    # DLFileEntryTypes_DLFolders  (type-to-folder restrictions)
    # =========================================================================

    check "DLFileEntryTypes_DLFolders – Mappings" "
        SELECT
            ft.externalReferenceCode AS type_erc,
            f.externalReferenceCode  AS folder_erc,
            f.name                   AS folder_name
        FROM DLFileEntryTypes_DLFolders m
        JOIN DLFileEntryType ft
          ON ft.fileEntryTypeId  = m.fileEntryTypeId
         AND ft.ctCollectionId   = 0
        JOIN DLFolder f
          ON f.folderId          = m.folderId
         AND f.ctCollectionId    = 0
        WHERE f.groupId          = __GROUPID__
          AND f.repositoryId     = f.groupId
          AND f.status          <> 8
          AND m.ctCollectionId   = 0
          $(date_filter f.modifiedDate)
        ORDER BY ft.externalReferenceCode, f.externalReferenceCode;
    "
}