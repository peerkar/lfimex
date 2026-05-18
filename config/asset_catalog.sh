#!/bin/bash
# =============================================================================
# Asset catalog — the registry of supported site assets and global registrations
# =============================================================================
# Two kinds of register calls live here:
#
#   asset_register <id> <label> <portlet> <extras> [test]
#     A site asset. Selected via ASSETS / --assets. May also be referenced
#     from GLOBAL_ASSETS to migrate the asset's data at the Global level.
#
#   global_register <id> <label> <portlet> <extras>
#     A company-wide thing (e.g. Custom Fields / Expando) that has no site
#     counterpart but still needs to migrate before site assets do. Selected
#     via GLOBAL_ASSETS.
#
# This file is the "what is supported" catalog; config/config.sh's ASSETS and
# GLOBAL_ASSETS selections (or --assets / --global-assets on the CLI) decide
# which of these actually run.
#
# Sourced from config/config.sh after lib/assets.sh + lib/globals.sh define
# the register helpers.
#
# Convention: `extras` is empty for almost every asset. lfimex submits just
# the high-level "include this portlet's data" enablers and lets Liferay fall
# back to each PortletDataHandler's own defaultValue — exactly what the
# Export dialog ships when the user hits Export with the defaults intact. The
# UI's tree of per-template-type / per-entity-type checkboxes is dynamic; by
# not enumerating them, we automatically pick up whatever handlers the target
# bundle has installed. See lib/assets.sh::asset_form_fields for the
# mechanics, and the "Liferay default-driven exports" note in CLAUDE.md.
#
# Use the `extras` slot only for explicit overrides where Liferay's default
# disagrees with our use case.
# =============================================================================

# Company-wide dependencies migrated by step_globals before the site cycle.
# Only runs in INSTANCE_MODE=create. Uses Liferay's Custom Fields export
# defaults (PortletDataHandlerBoolean(expando, ...) controls), with one
# explicit opt-in: PERMISSIONS=on. ExpandoColumn permissions decide who can
# view/edit each custom field — without this flag the LAR ships the columns
# but no acl, and on the target every non-admin role loses access to the
# fields. _global_form_fields auto-adds each extras key to checkboxNames,
# so PortletRequestImpl._processCheckbox rewrites "on" -> "true" and
# MapUtil.getBoolean(map, "PERMISSIONS") returns true at export and import.
# Scoped to this entry on purpose: site-asset PERMISSIONS stays at Liferay's
# default-off (matching the UI), per the catalog-wide UI-defaults convention.
global_register custom_fields "Custom Fields" \
  "com_liferay_expando_web_portlet_ExpandoPortlet" \
  "PERMISSIONS=on"

# These need to be migrated before any site assets, otherwise the site assets that reference them will fail to import.
#
# Page templates / "group pages" owned by the site, exported via
# GroupPagesPortlet. This portlet is BatchEnginePortletDataHandler-backed
# with FIVE registered task-item-delegates (LayoutPageTemplateCollection-0,
# UtilityPageResourceImpl, LayoutPageTemplateEntry-{0,1,3}). When a
# BatchEnginePortletDataHandler has more than one active registration its
# doExportData/doImportData gates each sub-registration with
# `getBooleanParameter(getPortletId(), descriptor.getKey())` and empirically
# only the first one falls through to `true` via PORTLET_DATA_CONTROL_DEFAULT
# — the rest get skipped. So we have to enumerate the toggles explicitly
# here; pure UI-defaults doesn't survive the multi-registration gate.
# Sub-registration keys map to:
#   LayoutPageTemplateCollection-0  page-template collections
#   UtilityPageResourceImpl         utility pages
#   LayoutPageTemplateEntry-0       page templates (basic / content)
#   LayoutPageTemplateEntry-1       display page templates
#   LayoutPageTemplateEntry-3       master pages
asset_register page_templates "Pages (Page Templates)" \
  "com_liferay_layout_admin_web_portlet_GroupPagesPortlet" \
  "_com_liferay_layout_admin_web_portlet_GroupPagesPortlet_com.liferay.layout.page.template.model.LayoutPageTemplateCollection-0=on
_com_liferay_layout_admin_web_portlet_GroupPagesPortlet_com.liferay.headless.admin.site.internal.resource.v1_0.UtilityPageResourceImpl=on
_com_liferay_layout_admin_web_portlet_GroupPagesPortlet_com.liferay.layout.page.template.model.LayoutPageTemplateEntry-0=on
_com_liferay_layout_admin_web_portlet_GroupPagesPortlet_com.liferay.layout.page.template.model.LayoutPageTemplateEntry-1=on
_com_liferay_layout_admin_web_portlet_GroupPagesPortlet_com.liferay.layout.page.template.model.LayoutPageTemplateEntry-3=on" \
  "page_templates"

asset_register forms "Forms" \
  "com_liferay_dynamic_data_mapping_form_web_portlet_DDMFormAdminPortlet" \
  "" \
  "forms"

# Site pages: the actual Layout tree. There are no form fields here because
# ExportLayoutsMVCActionCommand picks layouts via PortalPreferences/
# SessionTreeJSClicks, not the parameter map. step_export detects this asset
# and primes the selection by hitting /c/portal/session_tree_js_click with
# cmd=layoutCheck + plid=0 before the export POST. When this asset isn't in
# --assets the export still runs but carries no Layout rows.
asset_register site_pages "Site Pages" \
  "" \
  "" \
  "site_pages"

# Asset Libraries: a Depot is a company-wide entity, not site-scoped, so it
# isn't carried inside a site LAR. The only thing DepotAdminPortletDataHandler
# would ship is DepotEntryGroupRel (the site→depot connections). Those don't
# round-trip across companies: the handler resolves the foreign "depot-entry-
# live-group-id" via fetchGroupDepotEntry(groupId), groupIds are globally
# unique in Liferay's schema, so the call returns the SOURCE company's
# DepotEntry and the import writes a target-site connection pointing at a
# source-company group. Opening Documents and Media on the target then trips
# "Permission queries across multiple portal instances are not supported"
# because InlineSQLHelper rejects the cross-company groupId.
#
# We deliberately leave the portlet ID empty here. asset_form_fields only
# emits PORTLET_DATA_<portlet>=on when a portlet ID is present, so leaving
# it blank means DepotAdminPortletDataHandler is never invoked — neither on
# export nor on import. The `_depot_site-connections=false` toggle is not
# enough: inspecting DepotAdminPortletDataHandler.doExportData shows it
# ignores that toggle entirely and unconditionally exports every site→depot
# rel as long as the handler is invoked at all. The entry stays registered
# so the validation test still runs in INSTANCE_MODE=reuse where depots
# legitimately exist on the same company.
asset_register asset_libraries "Asset Libraries" \
  "" \
  "" \
  "asset_libraries"

asset_register blogs "Blogs" \
  "com_liferay_blogs_web_portlet_BlogsAdminPortlet" \
  "" \
  "blogs"

# asset_register bookmarks "Bookmarks" \
#  "com_liferay_bookmarks_web_portlet_BookmarksPortlet" \
#  "" \
#  ""

asset_register calendar "Calendar" \
  "com_liferay_calendar_web_portlet_CalendarAdminPortlet" \
  "" \
  "calendar"

# Same multi-registration BatchEnginePortletDataHandler pattern as
# page_templates: AssetCategoriesAdminPortlet has two task-item-delegates
# (TaxonomyVocabularyResourceImpl + TaxonomyCategoryResourceImpl) and the
# UI-defaults fallback drops one of them, so list both explicitly.
asset_register categories "Categories and Vocabularies" \
  "com_liferay_asset_categories_admin_web_portlet_AssetCategoriesAdminPortlet" \
  "_com_liferay_asset_categories_admin_web_portlet_AssetCategoriesAdminPortlet_com.liferay.headless.admin.taxonomy.internal.resource.v1_0.TaxonomyCategoryResourceImpl=on
_com_liferay_asset_categories_admin_web_portlet_AssetCategoriesAdminPortlet_com.liferay.headless.admin.taxonomy.internal.resource.v1_0.TaxonomyVocabularyResourceImpl=on" \
  "categories"

asset_register collections "Collections (Asset Lists)" \
  "com_liferay_asset_list_web_portlet_AssetListPortlet" \
  "" \
  "collections"

asset_register documents_and_media "Documents and Media" \
  "com_liferay_document_library_web_portlet_DLAdminPortlet" \
  "" \
  "documents_and_media"

asset_register fragments "Fragments" \
  "com_liferay_fragment_web_portlet_FragmentPortlet" \
  "" \
  "fragments"

# asset_register knowledge_base "Knowledge Base" \
#  "com_liferay_knowledge_base_web_portlet_AdminPortlet" \
#  "" \
#  ""

# asset_register message_boards "Message Boards" \
#  "com_liferay_message_boards_web_portlet_MBAdminPortlet" \
#  "" \
#  ""

asset_register navigation_menus "Navigation Menus" \
  "com_liferay_site_navigation_admin_web_portlet_SiteNavigationAdminPortlet" \
  "" \
  "navigation_menus"

asset_register segments "Segments" \
  "com_liferay_segments_web_internal_portlet_SegmentsPortlet" \
  "" \
  "segments"


# LOGO / THEME / THEME_REFERENCE are layout-export-level flags read directly
# by the ExportLayoutsMVCActionCommand parameter map, not portlet data
# handler controls — they don't have UI-default fallbacks, so they stay
# explicit here.
asset_register site_settings "Site Settings (logo, theme)" \
  "" \
  "LOGO=on
THEME=on
THEME_REFERENCE=on" \
  ""

asset_register style_books "Style Books" \
  "com_liferay_style_book_web_internal_portlet_StyleBookPortlet" \
  "" \
  "style_books"

# AssetTagsAdminPortlet is BatchEnginePortletDataHandler-backed; the only
# task-item-delegate is KeywordResourceImpl. Even though there's a single
# registration (so the size>1 gate doesn't fire), empirically the export
# still drops everything unless we send the explicit per-delegate toggle —
# same fix as categories / page_templates.
asset_register tags "Tags" \
  "com_liferay_asset_tags_admin_web_portlet_AssetTagsAdminPortlet" \
  "_com_liferay_asset_tags_admin_web_portlet_AssetTagsAdminPortlet_com.liferay.headless.admin.taxonomy.internal.resource.v1_0.KeywordResourceImpl=on" \
  "tags"

# Per-template-type toggles (_template_Asset Publisher Template,
# _template_Blogs Template, etc.) are dynamic — each template-type handler
# registers its own PortletDataHandlerBoolean at runtime. Letting defaults
# apply means lfimex picks up whatever types the target bundle has installed.
asset_register templates "Templates" \
  "com_liferay_template_web_internal_portlet_TemplatePortlet" \
  "" \
  "templates"

asset_register web_content "Web Content" \
  "com_liferay_journal_web_portlet_JournalPortlet" \
  "" \
  "web_content"

asset_register wiki "Wiki" \
  "com_liferay_wiki_web_portlet_WikiAdminPortlet" \
  "" \
  "wiki"

# =============================================================================
# Per-asset row-count queries surfaced in the grand summary's source-vs-target
# comparison panel. __GID__ is substituted with the groupId being queried;
# __DATE_FILTER__, when present, becomes "AND <col> BETWEEN <from> AND <to>"
# during --filter date-range runs (and an empty string otherwise). The 3rd
# argument names the column the date filter should constrain — same column
# the per-asset test's `$(date_filter <col>)` calls already use.
#
# Every WHERE includes `ctCollectionId = 0` to skip Publications drafts so the
# count matches what the user actually sees in admin. A few entries add an
# extra filter (e.g. head=1, system_=0, version=MAX) to count head/visible
# rows only — same convention the per-asset tests use for their first check.
# Assets without a meaningful per-site count are omitted (asset_libraries is
# company-scoped, site_settings has no row concept).
# =============================================================================

asset_count_register blogs              "SELECT COUNT(*) FROM BlogsEntry WHERE groupId=__GID__ AND ctCollectionId=0 __DATE_FILTER__" "modifiedDate"
asset_count_register calendar           "SELECT COUNT(*) FROM CalendarBooking WHERE groupId=__GID__ AND ctCollectionId=0 __DATE_FILTER__" "modifiedDate"
asset_count_register categories         "SELECT COUNT(*) FROM AssetCategory WHERE groupId=__GID__ AND ctCollectionId=0 __DATE_FILTER__" "modifiedDate"
asset_count_register collections        "SELECT COUNT(*) FROM AssetListEntry WHERE groupId=__GID__ AND ctCollectionId=0 __DATE_FILTER__" "modifiedDate"
asset_count_register documents_and_media "SELECT COUNT(*) FROM DLFileEntry WHERE groupId=__GID__ AND ctCollectionId=0 __DATE_FILTER__" "modifiedDate"
asset_count_register forms              "SELECT COUNT(*) FROM DDMFormInstance WHERE groupId=__GID__ AND ctCollectionId=0 __DATE_FILTER__" "modifiedDate"
asset_count_register fragments          "SELECT COUNT(*) FROM FragmentEntry WHERE groupId=__GID__ AND ctCollectionId=0 AND head=1 AND fragmentCollectionId!=0 __DATE_FILTER__" "modifiedDate"
asset_count_register navigation_menus   "SELECT COUNT(*) FROM SiteNavigationMenu WHERE groupId=__GID__ AND ctCollectionId=0 __DATE_FILTER__" "modifiedDate"
asset_count_register page_templates     "SELECT COUNT(*) FROM LayoutPageTemplateEntry WHERE groupId=__GID__ AND ctCollectionId=0 __DATE_FILTER__" "modifiedDate"
asset_count_register segments           "SELECT COUNT(*) FROM SegmentsEntry WHERE groupId=__GID__ AND ctCollectionId=0 __DATE_FILTER__" "modifiedDate"
asset_count_register site_pages         "SELECT COUNT(*) FROM Layout WHERE groupId=__GID__ AND ctCollectionId=0 AND system_=0 AND status=0 __DATE_FILTER__" "modifiedDate"
asset_count_register style_books        "SELECT COUNT(*) FROM StyleBookEntry WHERE groupId=__GID__ AND ctCollectionId=0 AND head=1 __DATE_FILTER__" "modifiedDate"
asset_count_register tags               "SELECT COUNT(*) FROM AssetTag WHERE groupId=__GID__ AND ctCollectionId=0 __DATE_FILTER__" "modifiedDate"
asset_count_register templates          "SELECT COUNT(*) FROM DDMTemplate WHERE groupId=__GID__ AND ctCollectionId=0 __DATE_FILTER__" "modifiedDate"
asset_count_register web_content        "SELECT COUNT(*) FROM JournalArticle ja WHERE ja.groupId=__GID__ AND ja.ctCollectionId=0 AND ja.version=(SELECT MAX(ja2.version) FROM JournalArticle ja2 WHERE ja2.articleId=ja.articleId AND ja2.groupId=ja.groupId AND ja2.ctCollectionId=0) __DATE_FILTER__" "ja.modifiedDate"
asset_count_register wiki               "SELECT COUNT(*) FROM WikiPage WHERE groupId=__GID__ AND ctCollectionId=0 AND head=1 __DATE_FILTER__" "modifiedDate"
