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
# =============================================================================

# Company-wide dependencies migrated by step_globals before the site cycle.
# Only runs in INSTANCE_MODE=create. The extras list matches what the Liferay
# export dialog ticks for the Expando "Custom Fields" portlet's data tree.
global_register custom_fields "Custom Fields" \
  "com_liferay_expando_web_portlet_ExpandoPortlet" \
  "_expando_expando-table=on
_expando_expando-column=on"

asset_register asset_libraries "Asset Libraries" \
  "com_liferay_depot_web_portlet_DepotAdminPortlet" \
  "_depot_site-connections=true" \
  "asset_libraries"

asset_register blogs "Blogs" \
  "com_liferay_blogs_web_portlet_BlogsAdminPortlet" \
  "_blogs_entries=on
_blogs_referenced-content=on
_blogs_referenced-content-behavior=include-always" \
  "blogs"

# asset_register bookmarks "Bookmarks" \
#  "com_liferay_bookmarks_web_portlet_BookmarksPortlet" \
#  "_bookmarks_folders=on
#_bookmarks_entries=on" \
#  ""

asset_register calendar "Calendar" \
  "com_liferay_calendar_web_portlet_CalendarAdminPortlet" \
  "_calendar_calendars=on
_calendar_calendar-resources=on
_calendar_events=on
_calendar_calendar-notification-templates=on
_calendar_referenced-content=on" \
  "calendar"

asset_register categories "Categories and Vocabularies" \
  "com_liferay_asset_categories_admin_web_portlet_AssetCategoriesAdminPortlet" \
  "_com_liferay_asset_categories_admin_web_portlet_AssetCategoriesAdminPortlet_com.liferay.headless.admin.taxonomy.internal.resource.v1_0.TaxonomyCategoryResourceImpl=on
_com_liferay_asset_categories_admin_web_portlet_AssetCategoriesAdminPortlet_com.liferay.headless.admin.taxonomy.internal.resource.v1_0.TaxonomyVocabularyResourceImpl=on" \
  "categories"

asset_register collections "Collections (Asset Lists)" \
  "com_liferay_asset_list_web_portlet_AssetListPortlet" \
  "_asset_lists_entries=on" \
  "collections"

asset_register documents_and_media "Documents and Media" \
  "com_liferay_document_library_web_portlet_DLAdminPortlet" \
  "_document_library_repositories=on
_document_library_folders=on
_document_library_documents=on
_document_library_previews-and-thumbnails=on
_document_library_referenced-content=on
_document_library_referenced-content-behavior=include-always
_document_library_document-types=on" \
  "documents_and_media"

asset_register forms "Forms" \
  "com_liferay_dynamic_data_mapping_form_web_portlet_DDMFormAdminPortlet" \
  "_forms_ddm-data-provider=on
_forms_forms=on
_forms_form-entries=on" \
  "forms"

asset_register fragments "Fragments" \
  "com_liferay_fragment_web_portlet_FragmentPortlet" \
  "_fragments_entries=on" \
  "fragments"

# Page templates / "group pages" owned by the site, exported via
# GroupPagesPortlet. The four toggles map to:
#   LayoutPageTemplateCollection-0  page-template collections
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

# asset_register knowledge_base "Knowledge Base" \
#  "com_liferay_knowledge_base_web_portlet_AdminPortlet" \
#  "_knowledge_base_articles=on
# _knowledge_base_attachments=on
# _knowledge_base_templates=on" \
#  ""

# asset_register message_boards "Message Boards" \
#  "com_liferay_message_boards_web_portlet_MBAdminPortlet" \
#  "_message_boards_categories=on
# _message_boards_threads=on
# _message_boards_attachments=on" \
#  ""

asset_register navigation_menus "Navigation Menus" \
  "com_liferay_site_navigation_admin_web_portlet_SiteNavigationAdminPortlet" \
  "_navigation-menus_navigation-menus=on
_navigation-menus_navigation-menu-items=on" \
  "navigation_menus"

asset_register segments "Segments" \
  "com_liferay_segments_web_internal_portlet_SegmentsPortlet" \
  "_segments_segments=on" \
  "segments"

# Site pages: the actual Layout tree. layoutIds=[0] is the "everything" form
# — Liferay's LayoutExporter walks the subtree from layoutId 0 (the synthetic
# root) which means every page. rootLayoutId / rootLayoutIncluded keep the
# subtree starting point explicit. When this asset isn't selected the export
# carries no Layout rows.
asset_register site_pages "Site Pages" \
  "" \
  "rootLayoutId=0
rootLayoutIncluded=true
layoutIds=[0]" \
  ""

asset_register site_settings "Site Settings (logo, theme)" \
  "" \
  "LOGO=on
THEME=on
THEME_REFERENCE=on" \
  ""

asset_register style_books "Style Books" \
  "com_liferay_style_book_web_internal_portlet_StyleBookPortlet" \
  "_style-books_entries=on" \
  "style_books"

asset_register tags "Tags" \
  "com_liferay_asset_tags_admin_web_portlet_AssetTagsAdminPortlet" \
  "" \
  "tags"

asset_register templates "Templates" \
  "com_liferay_template_web_internal_portlet_TemplatePortlet" \
  "_template_information-templates=on
_template_Asset Publisher Template=on
_template_Blogs Template=on
_template_Category Facet Template=on
_template_Category Filter Template=on
_template_Language Selector Template=on
_template_Media Gallery Template=on
_template_Menu Display Template=on
_template_Search Results Template=on" \
  "templates"

asset_register web_content "Web Content" \
  "com_liferay_journal_web_portlet_JournalPortlet" \
  "_journal_folders=on
_journal_web-content=on
_journal_structures=on
_journal_templates=on
_journal_feeds=on
_journal_version-history=on
_journal_referenced-content=on
_journal_referenced-content-behavior=include-always" \
  "web_content"

asset_register wiki "Wiki" \
  "com_liferay_wiki_web_portlet_WikiAdminPortlet" \
  "_wiki_wiki-nodes=on
_wiki_wiki-pages=on
_wiki_attachments=on
_wiki_referenced-content=on
_wiki_referenced-content-behavior=include-always" \
  "wiki"
