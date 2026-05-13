# =============================================================================
# Test: FORMS
# Tables: DDMFormInstance, DDMFormInstanceVersion,
#         DDMFormInstanceRecord, DDMFormInstanceRecordVersion,
#         DDMFormInstanceReport, DDMStructure
# =============================================================================

test_forms() {
    section "FORMS"

    # =========================================================================
    # DDMFormInstance
    # =========================================================================

    check "DDMFormInstance – Total count" "
        SELECT
            COUNT(*)        AS total
        FROM DDMFormInstance
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0;
    "

    check "DDMFormInstance – Identifiers" "
        SELECT
            REGEXP_REPLACE(name, '<[^>]+>', '') AS form_name,
            uuid_
        FROM DDMFormInstance
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    check "DDMFormInstance – Name and description" "
        SELECT
            uuid_,
            REGEXP_REPLACE(name, '<[^>]+>', '') AS name_plain,
            MD5(NULLIF(REGEXP_REPLACE(description, '<[^>]+>', ''), ''))                AS description_md5,
            LENGTH(NULLIF(REGEXP_REPLACE(description, '<[^>]+>', ''), ''))             AS description_len
        FROM DDMFormInstance
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    check "DDMFormInstance – Settings checksum" "
        SELECT
            uuid_,
            MD5(settings_)      AS settings_hash,
            LENGTH(settings_)   AS settings_length
        FROM DDMFormInstance
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    check "DDMFormInstance – Linked structure" "
        SELECT
            fi.uuid_,
            ds.structureKey
        FROM DDMFormInstance fi
        JOIN DDMStructure ds
          ON ds.structureId = fi.structureId
             AND ds.ctCollectionId = 0
        WHERE fi.groupId = __GROUPID__
          AND fi.ctCollectionId = 0
        ORDER BY fi.uuid_;
    "

    check "DDMFormInstance – Dates" "
        SELECT
            uuid_,
            createDate,
            modifiedDate
        FROM DDMFormInstance
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    # =========================================================================
    # DDMFormInstanceRecord
    # =========================================================================

    check "DDMFormInstanceRecord – Total count" "
        SELECT
            COUNT(*)        AS total
        FROM DDMFormInstanceRecord
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0;
    "

    check "DDMFormInstanceRecord – Count per form" "
        SELECT
            fi.uuid_        AS form_uuid,
            COUNT(*)        AS record_count
        FROM DDMFormInstance fi
        JOIN DDMFormInstanceRecord rec
          ON rec.formInstanceId = fi.formInstanceId
             AND rec.ctCollectionId = 0
        WHERE fi.groupId = __GROUPID__
          AND fi.ctCollectionId = 0
        GROUP BY fi.uuid_
        ORDER BY fi.uuid_;
    "

    check "DDMFormInstanceRecord – Audit fields" "
        SELECT
            uuid_,
            ipAddress
        FROM DDMFormInstanceRecord
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    check "DDMFormInstanceRecord – Dates" "
        SELECT
            uuid_,
            createDate,
            modifiedDate
        FROM DDMFormInstanceRecord
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    # =========================================================================
    # DDMFormInstanceRecordVersion
    # =========================================================================

    check "DDMFormInstanceRecordVersion – Total count" "
        SELECT
            COUNT(*)        AS total
        FROM DDMFormInstanceRecordVersion
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0;
    "

    check "DDMFormInstanceRecordVersion – Record version count per form" "
        SELECT
            fi.uuid_            AS form_uuid,
            COUNT(*)            AS record_version_count
        FROM DDMFormInstance fi
        JOIN DDMFormInstanceRecord rec
          ON rec.formInstanceId = fi.formInstanceId
             AND rec.ctCollectionId = 0
        JOIN DDMFormInstanceRecordVersion rv
          ON rv.formInstanceRecordId = rec.formInstanceRecordId
             AND rv.ctCollectionId = 0
        WHERE fi.groupId = __GROUPID__
          AND fi.ctCollectionId = 0
        GROUP BY fi.uuid_
        ORDER BY fi.uuid_;
    "

    check "DDMFormInstanceRecordVersion – Latest version status per record" "
        SELECT
            fi.uuid_            AS form_uuid,
            rec.uuid_           AS record_uuid,
            rv.status
        FROM DDMFormInstance fi
        JOIN DDMFormInstanceRecord rec
          ON rec.formInstanceId = fi.formInstanceId
             AND rec.ctCollectionId = 0
        JOIN DDMFormInstanceRecordVersion rv
          ON rv.formInstanceRecordId = rec.formInstanceRecordId
             AND rv.ctCollectionId = 0
             AND rv.version = (
                 SELECT MAX(rv2.version)
                 FROM DDMFormInstanceRecordVersion rv2
                 WHERE rv2.formInstanceRecordId = rec.formInstanceRecordId
                   AND rv2.ctCollectionId = 0
             )
        WHERE fi.groupId = __GROUPID__
          AND fi.ctCollectionId = 0
        ORDER BY fi.uuid_, rec.uuid_;
    "

    # =========================================================================
    # DDMFormInstanceReport
    # =========================================================================

    check "DDMFormInstanceReport – Total count" "
        SELECT
            COUNT(*)        AS total
        FROM DDMFormInstanceReport
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0;
    "

    check "DDMFormInstanceReport – Report count per form" "
        SELECT
            fi.uuid_            AS form_uuid,
            COUNT(*)            AS report_count
        FROM DDMFormInstance fi
        JOIN DDMFormInstanceReport rpt
          ON rpt.formInstanceId = fi.formInstanceId
             AND rpt.ctCollectionId = 0
        WHERE fi.groupId = __GROUPID__
          AND fi.ctCollectionId = 0
        GROUP BY fi.uuid_
        ORDER BY fi.uuid_;
    "

    # data_ contains ID references that change on import — only
    # verify that data exists after import.

    check "DDMFormInstanceReport – Data presence per form" "
        SELECT
            fi.uuid_            AS form_uuid,
            rpt.data_ IS NOT NULL AND rpt.data_ != '' AS has_data
        FROM DDMFormInstance fi
        JOIN DDMFormInstanceReport rpt
          ON rpt.formInstanceId = fi.formInstanceId
             AND rpt.ctCollectionId = 0
        WHERE fi.groupId = __GROUPID__
          AND fi.ctCollectionId = 0
        ORDER BY fi.uuid_;
    "

    check "DDMFormInstanceReport – Dates" "
        SELECT
            fi.uuid_            AS form_uuid,
            rpt.createDate,
            rpt.modifiedDate
        FROM DDMFormInstance fi
        JOIN DDMFormInstanceReport rpt
          ON rpt.formInstanceId = fi.formInstanceId
             AND rpt.ctCollectionId = 0
        WHERE fi.groupId = __GROUPID__
          AND fi.ctCollectionId = 0
        ORDER BY fi.uuid_;
    "

    # =========================================================================
    # DDMFormInstanceVersion
    # =========================================================================

    check "DDMFormInstanceVersion – Latest version core fields" "
        SELECT
            fi.uuid_            AS form_uuid,
            fiv.status
        FROM DDMFormInstance fi
        JOIN DDMFormInstanceVersion fiv
          ON fiv.formInstanceId = fi.formInstanceId
             AND fiv.ctCollectionId = 0
             AND fiv.version = (
                 SELECT MAX(fiv2.version)
                 FROM DDMFormInstanceVersion fiv2
                 WHERE fiv2.formInstanceId = fi.formInstanceId
                   AND fiv2.ctCollectionId = 0
             )
        WHERE fi.groupId = __GROUPID__
          AND fi.ctCollectionId = 0
        ORDER BY fi.uuid_;
    "

    check "DDMFormInstanceVersion – Latest version settings checksum" "
        SELECT
            fi.uuid_            AS form_uuid,
            MD5(fiv.settings_)  AS settings_hash,
            LENGTH(fiv.settings_) AS settings_length
        FROM DDMFormInstance fi
        JOIN DDMFormInstanceVersion fiv
          ON fiv.formInstanceId = fi.formInstanceId
             AND fiv.ctCollectionId = 0
             AND fiv.version = (
                 SELECT MAX(fiv2.version)
                 FROM DDMFormInstanceVersion fiv2
                 WHERE fiv2.formInstanceId = fi.formInstanceId
                   AND fiv2.ctCollectionId = 0
             )
        WHERE fi.groupId = __GROUPID__
          AND fi.ctCollectionId = 0
        ORDER BY fi.uuid_;
    "

    # =========================================================================
    # DDMStructure (form structures)
    # =========================================================================

    check "DDMStructure – Identifiers (form structures)" "
        SELECT
            structureKey,
            uuid_
        FROM DDMStructure
        WHERE groupId = __GROUPID__
          AND classNameId = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.dynamic.data.mapping.model.DDMFormInstance'
          )
          AND ctCollectionId = 0
        ORDER BY structureKey;
    "

    check "DDMStructure – Name and description (form structures)" "
        SELECT
            structureKey,
            REGEXP_REPLACE(name, '<[^>]+>', '') AS name_plain,
            REGEXP_REPLACE(description, '<[^>]+>', '') AS description_plain
        FROM DDMStructure
        WHERE groupId = __GROUPID__
          AND classNameId = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.dynamic.data.mapping.model.DDMFormInstance'
          )
          AND ctCollectionId = 0
        ORDER BY structureKey;
    "

    check "DDMStructure – Core fields (form structures)" "
        SELECT
            structureKey,
            storageType
        FROM DDMStructure
        WHERE groupId = __GROUPID__
          AND classNameId = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.dynamic.data.mapping.model.DDMFormInstance'
          )
          AND ctCollectionId = 0
        ORDER BY structureKey;
    "

    check "DDMStructure – Field definition checksum (form structures)" "
        SELECT
            structureKey,
            definition IS NOT NULL AND definition != '' AS has_data
        FROM DDMStructure
        WHERE groupId = __GROUPID__
          AND classNameId = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.dynamic.data.mapping.model.DDMFormInstance'
          )
          AND ctCollectionId = 0
        ORDER BY structureKey;
    "

    check "DDMStructure – Dates (form structures)" "
        SELECT
            structureKey,
            createDate,
            modifiedDate
        FROM DDMStructure
        WHERE groupId = __GROUPID__
          AND classNameId = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.dynamic.data.mapping.model.DDMFormInstance'
          )
          AND ctCollectionId = 0
        ORDER BY structureKey;
    "
}
