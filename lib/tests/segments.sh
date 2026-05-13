# =============================================================================
# Test: SEGMENTS
# Tables: SegmentsEntry, SegmentsEntryRole, SegmentsEntryRel,
#         SegmentsExperience
# =============================================================================

test_segments() {
    section "SEGMENTS"

    # =========================================================================
    # SegmentsEntry
    # =========================================================================

    check "SegmentsEntry – Total count" "
        SELECT
            COUNT(*)            AS total
        FROM SegmentsEntry
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            $(date_filter modifiedDate);
    "

    check "SegmentsEntry – Count by active status" "
        SELECT
            active_             AS is_active,
            COUNT(*)            AS total
        FROM SegmentsEntry
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            $(date_filter modifiedDate)
        GROUP BY active_
        ORDER BY active_;
    "

    check "SegmentsEntry – Count by source" "
        SELECT
            source,
            COUNT(*)            AS total
        FROM SegmentsEntry
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            $(date_filter modifiedDate)
        GROUP BY source
        ORDER BY source;
    "

    check "SegmentsEntry – Identifiers" "
        SELECT
            segmentsEntryKey,
            externalReferenceCode,
            uuid_
        FROM SegmentsEntry
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "SegmentsEntry – Name and description" "
        SELECT
            externalReferenceCode,
            REGEXP_REPLACE(name, '<[^>]+>', '') AS name_plain,
            MD5(NULLIF(description, ''))                AS description_md5,
            LENGTH(NULLIF(description, ''))             AS description_len
        FROM SegmentsEntry
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "SegmentsEntry – Core fields" "
        SELECT
            externalReferenceCode,
            active_,
            source
        FROM SegmentsEntry
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "SegmentsEntry – Criteria checksum" "
        SELECT
            externalReferenceCode,
            MD5(criteria)       AS criteria_hash,
            LENGTH(criteria)    AS criteria_length
        FROM SegmentsEntry
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "SegmentsEntry – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM SegmentsEntry
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
            $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    # =========================================================================
    # SegmentsExperience
    # =========================================================================

    check "SegmentsExperience – Count of active experiences" "
        SELECT
            COUNT(*)            AS total
        FROM SegmentsExperience sx
        JOIN SegmentsEntry se
          ON se.externalReferenceCode = sx.segmentsEntryERC
             AND se.ctCollectionId = 0
        WHERE se.groupId = __GROUPID__
            AND sx.ctCollectionId = 0
            AND sx.active_ = 1
            $(date_filter sx.modifiedDate);
    "

    check "SegmentsExperience – Identifiers" "
        SELECT
            se.segmentsEntryKey,
            sx.externalReferenceCode,
            sx.segmentsEntryERC,
            sx.segmentsEntryScopeERC,
            sx.segmentsExperienceKey,
            sx.uuid_
        FROM SegmentsExperience sx
        JOIN SegmentsEntry se
          ON se.externalReferenceCode = sx.segmentsEntryERC
             AND se.ctCollectionId = 0
        WHERE se.groupId = __GROUPID__
            AND sx.ctCollectionId = 0
            $(date_filter sx.modifiedDate)
        ORDER BY se.segmentsEntryKey, sx.segmentsExperienceKey;
    "

    check "SegmentsExperience – Name" "
        SELECT
            sx.segmentsExperienceKey,
            REGEXP_REPLACE(sx.name, '<[^>]+>', '') AS experience_name_plain
        FROM SegmentsExperience sx
        JOIN SegmentsEntry se
          ON se.externalReferenceCode = sx.segmentsEntryERC
             AND se.ctCollectionId = 0
        WHERE se.groupId = __GROUPID__
            AND sx.ctCollectionId = 0
            $(date_filter sx.modifiedDate)
        ORDER BY se.segmentsEntryKey, sx.segmentsExperienceKey;
    "

    check "SegmentsExperience – Active and priority" "
        SELECT
            sx.segmentsExperienceKey,
            se.segmentsEntryKey,
            sx.active_,
            sx.priority
        FROM SegmentsExperience sx
        JOIN SegmentsEntry se
          ON se.externalReferenceCode = sx.segmentsEntryERC
             AND se.ctCollectionId = 0
        WHERE se.groupId = __GROUPID__
            AND sx.ctCollectionId = 0
            $(date_filter sx.modifiedDate)
        ORDER BY se.segmentsEntryKey, sx.priority DESC;
    "

    check "SegmentsExperience – Dates" "
        SELECT
            sx.segmentsExperienceKey,
            sx.createDate,
            sx.modifiedDate
        FROM SegmentsExperience sx
        JOIN SegmentsEntry se
          ON se.externalReferenceCode = sx.segmentsEntryERC
             AND se.ctCollectionId = 0
        WHERE se.groupId = __GROUPID__
            AND sx.ctCollectionId = 0
            $(date_filter sx.modifiedDate)
        ORDER BY se.segmentsEntryKey, sx.segmentsExperienceKey;
    "

    check "SegmentsExperience – Experience count per segment" "
        SELECT
            se.segmentsEntryKey,
            COUNT(sx.segmentsExperienceId)  AS experience_count,
            SUM(sx.active_)                 AS active_experiences
        FROM SegmentsEntry se
        LEFT JOIN SegmentsExperience sx
               ON sx.segmentsEntryERC = se.externalReferenceCode
              AND sx.ctCollectionId = 0
        WHERE se.groupId = __GROUPID__
            AND se.ctCollectionId = 0
            $(date_filter se.modifiedDate)
        GROUP BY se.segmentsEntryKey
        ORDER BY se.segmentsEntryKey;
    "

    # =========================================================================
    # SegmentsEntryRole
    # =========================================================================

    check "SegmentsEntryRole – Role mappings per segment" "
        SELECT
            se.segmentsEntryKey,
            COUNT(r.name)                               AS role_count,
            GROUP_CONCAT(r.name ORDER BY r.name)        AS role_names
        FROM SegmentsEntry se
        LEFT JOIN SegmentsEntryRole ser
               ON ser.segmentsEntryId = se.segmentsEntryId
              AND ser.ctCollectionId = 0
        LEFT JOIN Role_ r
               ON r.roleId = ser.roleId
        WHERE se.groupId = __GROUPID__
            AND se.ctCollectionId = 0
            $(date_filter se.modifiedDate)
        GROUP BY se.segmentsEntryKey
        ORDER BY se.segmentsEntryKey;
    "

    # =========================================================================
    # SegmentsEntryRel
    # =========================================================================

    check "SegmentsEntryRel – Static member count per segment" "
        SELECT
            se.segmentsEntryKey,
            COUNT(rel.segmentsEntryRelId)   AS member_count,
            cn.value                        AS class_name
        FROM SegmentsEntry se
        LEFT JOIN SegmentsEntryRel rel
               ON rel.segmentsEntryId = se.segmentsEntryId
              AND rel.ctCollectionId = 0
        LEFT JOIN ClassName_ cn
               ON cn.classNameId = rel.classNameId
        WHERE se.groupId = __GROUPID__
            AND se.ctCollectionId = 0
            $(date_filter se.modifiedDate)
        GROUP BY se.segmentsEntryKey, cn.value
        ORDER BY se.segmentsEntryKey, cn.value;
    "
}
