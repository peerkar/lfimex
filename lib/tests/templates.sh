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
#
# Scope of this test:
#   We exclude DDMStructure-class rows from every DDMTemplate check below.
#   TemplatePortlet (the asset_register backing this test) does NOT export
#   DDMStructure-class templates — they're owned by whichever portlet ships
#   the underlying structure. In practice that means:
#     * structures with classNameId = JournalArticle → carried by web_content
#       (JournalPortlet exports its DDMStructures with their dependent
#       DDMTemplates as strong references)
#     * structures with classNameId = DDLRecordSet → not migrated by lfimex
#       (DDL isn't in config/asset_catalog.sh)
#     * orphan templates with classPK = 0 → fall through every handler
#   Validating those rows in this test would surface drift that belongs in
#   the web_content test (when its referenced structures are missing) or
#   represents real Liferay coverage gaps (DDL, classPK=0 orphans) that no
#   asset migration handles. Scoping this test to the templates that
#   TemplatePortlet actually owns keeps it actionable.
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
          AND classNameId    != (SELECT classNameId FROM ClassName_
                                 WHERE value = 'com.liferay.dynamic.data.mapping.model.DDMStructure')
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
          AND cn.value         != 'com.liferay.dynamic.data.mapping.model.DDMStructure'
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
          AND t.classNameId    != (SELECT classNameId FROM ClassName_
                                   WHERE value = 'com.liferay.dynamic.data.mapping.model.DDMStructure')
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
          AND t.classNameId    != (SELECT classNameId FROM ClassName_
                                   WHERE value = 'com.liferay.dynamic.data.mapping.model.DDMStructure')
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
          AND cn.value         != 'com.liferay.dynamic.data.mapping.model.DDMStructure'
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
          AND t.classNameId    != (SELECT classNameId FROM ClassName_
                                   WHERE value = 'com.liferay.dynamic.data.mapping.model.DDMStructure')
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
          AND t.classNameId    != (SELECT classNameId FROM ClassName_
                                   WHERE value = 'com.liferay.dynamic.data.mapping.model.DDMStructure')
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
          AND t.classNameId    != (SELECT classNameId FROM ClassName_
                                   WHERE value = 'com.liferay.dynamic.data.mapping.model.DDMStructure')
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
          AND t.classNameId    != (SELECT classNameId FROM ClassName_
                                   WHERE value = 'com.liferay.dynamic.data.mapping.model.DDMStructure')
          $(date_filter t.modifiedDate)
        GROUP BY cn.value
        ORDER BY cn.value;
    "

    # =========================================================================
    # DDMTemplateVersion
    # =========================================================================

    # DDMTemplate.version is varchar (e.g. "1.13"). Using MAX(tv.version) to
    # resolve the latest row falls into a lexicographic trap: MAX("1.13",
    # "1.9") = "1.9", so any template with 10+ versions ends up matched
    # against an older row. DDMTemplate carries the current version string
    # itself, so joining t.version = tv.version selects the actual head
    # version — same pattern the DM test uses for DLFileVersion (see the
    # version note in lib/tests/documents_and_media.sh and the CLAUDE.md
    # entry it cites).
    check "DDMTemplateVersion – Latest version core fields" "
        SELECT
            t.externalReferenceCode,
            tv.status
        FROM DDMTemplate t
        JOIN DDMTemplateVersion tv
          ON tv.templateId      = t.templateId
             AND tv.version        = t.version
             AND tv.ctCollectionId = 0
        WHERE t.groupId         = __GROUPID__
          AND t.ctCollectionId  = 0
          AND t.classNameId    != (SELECT classNameId FROM ClassName_
                                   WHERE value = 'com.liferay.dynamic.data.mapping.model.DDMStructure')
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
             AND tv.version        = t.version
             AND tv.ctCollectionId = 0
        WHERE t.groupId         = __GROUPID__
          AND t.ctCollectionId  = 0
          AND t.classNameId    != (SELECT classNameId FROM ClassName_
                                   WHERE value = 'com.liferay.dynamic.data.mapping.model.DDMStructure')
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

    # TemplateEntry.infoItemFormVariationKey for FileEntry-class rows is a
    # raw DLFileEntryType.fileEntryTypeId — a Counter-generated surrogate PK
    # that's reissued by the target's Counter on import (e.g. source
    # 274524237 → target 524401163 even though both rows point at the same
    # logical DLFileEntryType, ERC 5c112037…). Comparing the raw PK
    # guarantees a false positive. Resolve to the DLFileEntryType's
    # externalReferenceCode (a stable, source-authored key that's preserved
    # across export/import) for FileEntry rows; pass through whatever's
    # stored for other infoItemClassName values (typically NULL — BlogsEntry,
    # AssetEntry, etc., don't use the field).
    check "TemplateEntry – Core fields" "
        SELECT
            te.externalReferenceCode,
            te.infoItemClassName,
            COALESCE(
                ft.externalReferenceCode,
                te.infoItemFormVariationKey
            ) AS info_item_form_variation_key,
            dt.templateKey
        FROM TemplateEntry te
        JOIN DDMTemplate dt
          ON dt.templateId      = te.ddmTemplateId
             AND dt.ctCollectionId  = 0
        LEFT JOIN DLFileEntryType ft
          ON te.infoItemClassName = 'com.liferay.portal.kernel.repository.model.FileEntry'
             AND ft.fileEntryTypeId  = CAST(te.infoItemFormVariationKey AS UNSIGNED)
             AND ft.ctCollectionId   = 0
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
