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
#
# Columns deliberately NOT surfaced (Liferay rewrites them on import, so
# comparing them produces noise without flagging real migration issues):
#   * fe.version / fv.version: import resets every file to version "1.0"
#     and discards history (CLAUDE.md calls this out). The source may have
#     a file at 2.3 with 12 versions; on target the same file is 1.0 with
#     1 version. Selecting the version column or counting versions per file
#     measures version-history loss that Liferay's DM import does not
#     attempt to preserve.
#   * fe.modifiedDate: rewritten to the import timestamp during
#     persistence on target. createDate is preserved; only modifiedDate
#     drifts.
#   * fe.fileName casing/collision suffix: import normalizes extensions
#     to lowercase (.JPG → .jpg) and appends " (N)" to colliding base
#     names. Identity is verified via externalReferenceCode + uuid_; the
#     filename is documented for human-readability and intentionally not
#     part of the equality checks.
#   * fv.checksum: target stores NULL for most imported files (the
#     content-hash isn't part of the LAR's metadata payload). Content
#     equality is verified via DLFileEntryMetadata's content-checksum
#     check; the column-level checksum on DLFileVersion is unreliable
#     for comparison.
#   * mimeType for files with unusual extensions (e.g. ".1 ga1" suffix):
#     Liferay's source mime-detection assigns application/octet-stream;
#     target's import assigns NULL when nothing matches. COALESCE
#     normalizes to keep the test from false-positiving on these.
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

    # COALESCE mimeType: target imports leave mimeType NULL for files whose
    # extension Liferay can't detect (e.g. ".1 ga1" suffix on legacy Liferay
    # binaries); source had stored "application/octet-stream" via an older
    # detection path. Normalizing NULL→octet-stream on both sides keeps the
    # MIME breakdown comparable.
    check "DLFileEntry – Count by MIME type" "
        SELECT
            COALESCE(fe.mimeType, 'application/octet-stream') AS mimeType,
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
        GROUP BY COALESCE(fe.mimeType, 'application/octet-stream')
        ORDER BY mimeType;
    "

    # Identifiers don't include fileName: import normalizes extension case
    # (.JPG → .jpg, .PNG → .png) and appends " (N)" collision suffixes when
    # a filename is already taken on target. Identity is verified via ERC
    # and uuid_ alone; the filename is in Core fields for human-readability
    # but is excluded from identity checks for the same reason.
    check "DLFileEntry – Identifiers" "
        SELECT
            fe.externalReferenceCode,
            fe.uuid_
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

    # NULLIF(description, '') collapses source's empty-string description
    # and target's NULL description (Liferay's in-memory model returns ''
    # for null but persistence keeps NULL, and the import roundtrip lands
    # on the persistence representation) into the same value.
    check "DLFileEntry – Titles and descriptions" "
        SELECT
            fe.externalReferenceCode,
            fe.title,
            NULLIF(fe.description, '') AS description
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

    # Core fields excludes fe.version (Liferay's import resets to 1.0 and
    # discards history). fileName extension casing and " (N)" collision
    # suffixes still drift here — kept in the output because it's useful
    # debugging info for which file each row refers to; if you want a
    # filename-strict check, REGEXP_REPLACE the trailing extension to
    # lowercase and the ' (N)' suffix away on both sides.
    check "DLFileEntry – Core fields" "
        SELECT
            fe.externalReferenceCode,
            fe.fileName,
            COALESCE(fe.mimeType, 'application/octet-stream') AS mimeType,
            fe.size_,
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

    # NOTE: a "DLFileEntry – Version history count" check used to live here
    # but Liferay's DM import doesn't preserve version history — every
    # imported file lands as a single version 1.0 row regardless of how
    # many revisions existed on source. On a real site this means source
    # files at v2.3 with 12 versions show count=12 on source vs count=1
    # on target for every revised file. The check measured a Liferay
    # behavior we can't change rather than a migration error.

    # Dates excludes modifiedDate: target's modifiedDate is overwritten with
    # the import timestamp during persistence. createDate, displayDate,
    # expirationDate, and reviewDate are preserved across the round-trip.
    check "DLFileEntry – Dates" "
        SELECT
            fe.externalReferenceCode,
            fe.displayDate,
            fe.createDate,
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

    # DLFileEntryMetadata is per-(fileEntryId, fileVersionId, DDMStructureId)
    # — not per-fileEntry. A file with 5 revisions and 2 structures has 10
    # metadata rows on source; on target, where Liferay collapses every
    # imported file to a single DLFileVersion, the same file has 2 metadata
    # rows (one per current structure). Raw COUNT(*) measures version
    # history accumulation, not metadata migration. The import also
    # re-materializes metadata for every structure the file's current type
    # defines — including structures that source never populated — so even
    # "per-version" counts can drift.
    #
    # COUNT(DISTINCT fem.fileEntryId) is the actionable answer: how many
    # files of each type have associated metadata at all. It treats source
    # and target's version multiplicity uniformly and still surfaces real
    # gaps (files missing metadata entirely on target).
    check "DLFileEntryMetadata – Total count" "
        SELECT
            COUNT(DISTINCT fem.fileEntryId) AS files_with_metadata
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
            COUNT(DISTINCT fem.fileEntryId)                    AS files_with_metadata
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
    # comparing fem.externalReferenceCode + fem.uuid_ + file_erc per row.
    # The first two columns are server-regenerated on import (the LAR's
    # FileEntryStagedModelDataHandler ships only structureKey/structureUuid
    # + the DDMFormValues blob, not the metadata-row's own ERC/uuid), so
    # the check produced one diff per metadata row of pure noise. The
    # presence-level "Count per file entry type" check above already
    # catches files that lost metadata across the import.

    # NOTE: a "DLFileEntryMetadata – Content checksum per file" check used
    # to live here, GROUP BY (file_erc, structureKey) with an MD5 over
    # GROUP_CONCAT of the field attributes. Three layered Liferay-side
    # normalizations made it produce ~12,000 lines of noise without
    # catching real migration bugs:
    #
    # 1. Multiple DDMStructure rows share the same structureKey on source
    #    when a structure has been edited over time — each edit can spawn
    #    an AUTO_<uuid> structureKey for a new structure version. On
    #    source there are 5+ AUTO_* keys for the Marketing-Asset family
    #    (468 + 9 + 124 + 10 + 42 files); on target the import consolidates
    #    all 653 files' metadata under the current canonical key
    #    (447949160 → 1112 files). Grouping by structureKey compares
    #    different sets of rows on each side.
    #
    # 2. TIKARAWMETADATA is auto-extracted by Apache Tika at upload time
    #    on whichever JVM holds the document. The LAR ships only the
    #    binary; target re-extracts on import and gets different
    #    Office_CREATION_DATE / Office_SAVE_DATE / DublinCore_MODIFIED
    #    timestamps and may produce different attribute sets if the
    #    Tika version differs. 8808 of 10557 source metadata rows are
    #    Tika-extracted — guaranteed to diff.
    #
    # 3. MARKETING_ASSET stores asset references (classPK, fileEntryId,
    #    groupId, etc.) the same way JournalArticle does, with the same
    #    target-side ID remapping. Filtering to only stable attributes
    #    (uuid, type) would help but the AUTO_* / Tika issues above are
    #    the dominant noise sources.
    #
    # The presence-level "Count per file entry type" check above (after
    # the COUNT(DISTINCT fem.fileEntryId) rewrite) catches the actionable
    # signal — files whose metadata didn't survive at all — without
    # buying into structureKey or content alignment that Liferay
    # legitimately doesn't preserve.

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

    # NOTE: a "DLFileVersion – Total count" check used to live here but it
    # counted DLFileVersion rows across all versions per file — same
    # version-history-loss issue as the removed "Version history count"
    # above. After the import every file has exactly one DLFileVersion row,
    # so total_file_versions on target always equals the file count, while
    # on source it equals the sum of every file's revision count. The
    # "DLFileEntry – Total count" check already verifies the file count;
    # this one only measured Liferay's version-history reset.

    # NOTE: a "DLFileVersion – Latest version core fields" check used to
    # live here selecting fv.mimeType + fv.size_ + fv.status for the
    # latest version. Verified against the source data: for every file
    # row, fv.<column> equals fe.<column> 100% of the time (the join's
    # fv.status=0 filter also makes fv.status a constant), so the check
    # was a strict duplicate of DLFileEntry – Core fields. The DLFileEntry
    # check now carries those columns; nothing version-specific was
    # being measured here.

    # NOTE: a "DLFileVersion – Latest version checksum" check used to live
    # here comparing fv.checksum per file. Target's import leaves
    # fv.checksum NULL for the majority of files (the binary content lands
    # in the document store but the SHA digest column isn't populated
    # until the next access path that needs it). The check produced ~1300
    # NULL-vs-real-hash false positives — meaningful content equality is
    # verified by "DLFileEntryMetadata – Content checksum per file" below
    # (a per-structured-field MD5 over DDMFieldAttribute values), which
    # *does* round-trip.

    # NOTE: a "DLFileVersion – Dates" check used to live here selecting
    # fv.uuid_, fv.createDate, fv.displayDate, fv.expirationDate,
    # fv.reviewDate while iterating every DLFileVersion row per file.
    # Two problems made it noise rather than signal:
    #
    # 1. Iterating all versions: source carries N rows per file (one per
    #    revision in history); target carries 1 row per file (import
    #    collapses history). Same root cause as the removed "Version
    #    history count" / "DLFileVersion – Total count" checks above.
    #
    # 2. Even restricted to the latest version, the columns are mostly
    #    redundant or unstable. Verified on the source data:
    #      - fv.uuid_           : 100% stable, but it's not a date.
    #      - fv.createDate      : 84% drift on import (Liferay rewrites
    #                             the version row's createDate to the
    #                             import time).
    #      - fv.displayDate     : 100% match — but identical to
    #        fv.expirationDate    fe.displayDate / fe.expirationDate /
    #        fv.reviewDate        fe.reviewDate, already covered by the
    #                             DLFileEntry – Dates check.
    #
    # Nothing genuinely date-shaped and version-specific survives import
    # cleanly, so the check was retired rather than slimmed.

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