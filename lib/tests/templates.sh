# =============================================================================
# Test: TEMPLATES  (DDMTemplate)
# Tables: DDMTemplate, DDMTemplateVersion, DDMTemplateLink,
#         TemplateEntry, ClassName_
# =============================================================================
# DDMTemplate is shared across multiple Liferay features. The classNameId
# column identifies the owning feature:
#   com.liferay.journal.model.JournalArticle        → Web Content Templates
#   com.liferay.portlet.display.template.PortletDisplayTemplate
#                                                   → Widget Display Templates
#   com.liferay.dynamic.data.mapping.model.DDMStructure
#                                                   → Structure Templates (legacy)
# =============================================================================

test_templates() {
    section "TEMPLATES"

    # =========================================================================
    # DDMTemplate
    # =========================================================================

    check "DDMTemplate – Total count" "
        SELECT
            COUNT(*)        AS total
        FROM DDMTemplate
        WHERE groupId         = __GROUPID__
          AND ctCollectionId  = 0
          $(date_filter modifiedDate);
    "

    check "DDMTemplate – Count by type" "
        SELECT
            cn.value            AS class_name,
            t.type_,
            COUNT(*)            AS total
        FROM DDMTemplate t
        JOIN ClassName_ cn
          ON cn.classNameId     = t.classNameId
        WHERE t.groupId         = __GROUPID__
          AND t.ctCollectionId  = 0
          $(date_filter t.modifiedDate)
        GROUP BY cn.value, t.type_
        ORDER BY cn.value, t.type_;
    "

    check "DDMTemplate – Identifiers" "
        SELECT
            t.templateKey,
            t.externalReferenceCode,
            t.uuid_
        FROM DDMTemplate t
        WHERE t.groupId         = __GROUPID__
          AND t.ctCollectionId  = 0
          $(date_filter t.modifiedDate)
        ORDER BY t.externalReferenceCode;
    "

    check "DDMTemplate – Names and descriptions" "
        SELECT
            t.externalReferenceCode,
            REGEXP_REPLACE(t.name, '<[^>]+>', '') AS name_plain,
            MD5(t.description)                    AS description_md5,
            LENGTH(t.description)                 AS description_len
        FROM DDMTemplate t
        WHERE t.groupId         = __GROUPID__
          AND t.ctCollectionId  = 0
          $(date_filter t.modifiedDate)
        ORDER BY t.externalReferenceCode;
    "

    check "DDMTemplate – Core fields" "
        SELECT
            t.externalReferenceCode,
            cn.value            AS class_name,
            t.type_,
            NULLIF(t.mode_, '') AS mode,
            t.language,
            t.cacheable
        FROM DDMTemplate t
        JOIN ClassName_ cn
          ON cn.classNameId     = t.classNameId
        WHERE t.groupId         = __GROUPID__
          AND t.ctCollectionId  = 0
          $(date_filter t.modifiedDate)
        ORDER BY t.externalReferenceCode;
    "

    check "DDMTemplate – Script checksum" "
        SELECT
            t.externalReferenceCode,
            MD5(t.script)       AS script_hash,
            LENGTH(t.script)    AS script_length
        FROM DDMTemplate t
        WHERE t.groupId         = __GROUPID__
          AND t.ctCollectionId  = 0
          $(date_filter t.modifiedDate)
        ORDER BY t.externalReferenceCode;
    "

    check "DDMTemplate – Linked structure" "
        SELECT
            t.externalReferenceCode,
            ds.structureKey
        FROM DDMTemplate t
        LEFT JOIN DDMStructure ds
               ON ds.structureId    = t.classPK
              AND ds.ctCollectionId = 0
        WHERE t.groupId         = __GROUPID__
          AND t.ctCollectionId  = 0
          $(date_filter t.modifiedDate)
        ORDER BY t.externalReferenceCode;
    "

    check "DDMTemplate – Dates" "
        SELECT
            t.externalReferenceCode,
            t.createDate,
            t.modifiedDate
        FROM DDMTemplate t
        WHERE t.groupId         = __GROUPID__
          AND t.ctCollectionId  = 0
          $(date_filter t.modifiedDate)
        ORDER BY t.externalReferenceCode;
    "

    # =========================================================================
    # DDMTemplateLink
    # =========================================================================

    check "DDMTemplateLink – Template links" "
        SELECT
            cn.value            AS linked_class_name,
            COUNT(*)            AS total
        FROM DDMTemplate t
        JOIN DDMTemplateLink tl
          ON tl.templateId      = t.templateId
             AND tl.ctCollectionId = 0
        JOIN ClassName_ cn
          ON cn.classNameId     = tl.classNameId
        WHERE t.groupId         = __GROUPID__
          AND t.ctCollectionId  = 0
          $(date_filter t.modifiedDate)
        GROUP BY cn.value
        ORDER BY cn.value;
    "

    # =========================================================================
    # DDMTemplateVersion
    # =========================================================================

    check "DDMTemplateVersion – Version count per template" "
        SELECT
            t.externalReferenceCode,
            COUNT(*)            AS version_count
        FROM DDMTemplate t
        JOIN DDMTemplateVersion tv
          ON tv.templateId      = t.templateId
             AND tv.ctCollectionId = 0
        WHERE t.groupId         = __GROUPID__
          AND t.ctCollectionId  = 0
          $(date_filter tv.modifiedDate)
        GROUP BY t.externalReferenceCode
        ORDER BY t.externalReferenceCode;
    "

    check "DDMTemplateVersion – Latest version core fields" "
        SELECT
            t.externalReferenceCode,
            tv.status
        FROM DDMTemplate t
        JOIN DDMTemplateVersion tv
          ON tv.templateId      = t.templateId
             AND tv.ctCollectionId = 0
             AND tv.version     = (
                 SELECT MAX(tv2.version)
                 FROM DDMTemplateVersion tv2
                 WHERE tv2.templateId    = t.templateId
                   AND tv2.ctCollectionId = 0
             )
        WHERE t.groupId         = __GROUPID__
          AND t.ctCollectionId  = 0
          $(date_filter tv.modifiedDate)
        ORDER BY t.externalReferenceCode;
    "

    check "DDMTemplateVersion – Latest version script checksum" "
        SELECT
            t.externalReferenceCode,
            MD5(tv.script)      AS script_hash,
            LENGTH(tv.script)   AS script_length
        FROM DDMTemplate t
        JOIN DDMTemplateVersion tv
          ON tv.templateId      = t.templateId
             AND tv.ctCollectionId = 0
             AND tv.version     = (
                 SELECT MAX(tv2.version)
                 FROM DDMTemplateVersion tv2
                 WHERE tv2.templateId    = t.templateId
                   AND tv2.ctCollectionId = 0
             )
        WHERE t.groupId         = __GROUPID__
          AND t.ctCollectionId  = 0
          $(date_filter tv.modifiedDate)
        ORDER BY t.externalReferenceCode;
    "

    # =========================================================================
    # TemplateEntry (Information Templates)
    # =========================================================================

    check "TemplateEntry – Count" "
        SELECT
            COUNT(*)        AS total_information_templates
        FROM TemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate);
    "

    check "TemplateEntry – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_
        FROM TemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "

    check "TemplateEntry – Core fields" "
        SELECT
            te.externalReferenceCode,
            te.infoItemClassName,
            te.infoItemFormVariationKey,
            dt.templateKey
        FROM TemplateEntry te
        JOIN DDMTemplate dt
          ON dt.templateId      = te.ddmTemplateId
             AND dt.ctCollectionId  = 0
        WHERE te.groupId        = __GROUPID__
          AND te.ctCollectionId = 0
          $(date_filter te.modifiedDate)
        ORDER BY te.externalReferenceCode;
    "

    check "TemplateEntry – Script checksum" "
        SELECT
            te.externalReferenceCode,
            MD5(dt.script)      AS script_hash,
            LENGTH(dt.script)   AS script_length
        FROM TemplateEntry te
        JOIN DDMTemplate dt
          ON dt.templateId      = te.ddmTemplateId
             AND dt.ctCollectionId  = 0
        WHERE te.groupId        = __GROUPID__
          AND te.ctCollectionId = 0
          $(date_filter te.modifiedDate)
        ORDER BY te.externalReferenceCode;
    "

    check "TemplateEntry – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM TemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          $(date_filter modifiedDate)
        ORDER BY externalReferenceCode;
    "
}
