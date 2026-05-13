// =============================================================================
// Create a Liferay portal instance (Company row) via `blade sh`.
// =============================================================================
//
// step_instance.sh substitutes the placeholders below, then runs:
//
//   blade sh < <rendered.groovy>
//
// blade sh interprets stdin as a Groovy script executed inside the Liferay
// JVM. `println` lines come back on blade's stdout; the caller greps for
// INSTANCE_COMPANY_ID= and ERROR=.
//
// Placeholders below are substituted by step_instance.sh:
//
//   __WEB_ID__           — Company.webId (unique key, e.g. "tenant-a.com")
//   __VIRTUAL_HOSTNAME__ — virtual host used to route requests to this company
//   __MAIL_DOMAIN__      — mx; address suffix for company-scoped users
//   __ADMIN_PASSWORD__
//   __ADMIN_SCREEN_NAME__
//   __ADMIN_EMAIL__
//   __ADMIN_FIRST_NAME__
//   __ADMIN_LAST_NAME__
//
// On success the script prints two parseable lines that the caller greps:
//
//   INSTANCE_COMPANY_ID=<companyId>
//   INSTANCE_WEB_ID=<webId>
//
// On failure it prints an ERROR line and a non-zero rc isn't propagated by
// Gogo, so the caller must check the output for the success markers.
// =============================================================================

import com.liferay.portal.kernel.language.LanguageUtil
import com.liferay.portal.kernel.model.Company
import com.liferay.portal.kernel.model.User
import com.liferay.portal.kernel.service.CompanyLocalServiceUtil
import com.liferay.portal.kernel.service.UserLocalServiceUtil
import com.liferay.portal.kernel.util.PrefsPropsUtil
import com.liferay.portal.kernel.util.PropsKeys

try {
    Company company = CompanyLocalServiceUtil.addCompany(
        null,                           // companyId — null lets Liferay generate one
        "__WEB_ID__",                   // webId
        "__VIRTUAL_HOSTNAME__",         // virtualHostname
        "__MAIL_DOMAIN__",              // mx (mail domain)
        0,                              // maxUsers (0 = unlimited)
        true,                           // active
        true,                           // addDefaultAdminUser
        "__ADMIN_PASSWORD__",
        "__ADMIN_SCREEN_NAME__",
        "__ADMIN_EMAIL__",
        "__ADMIN_FIRST_NAME__",
        "",                             // middle name (unused)
        "__ADMIN_LAST_NAME__"
    )

    // Liferay puts the default admin behind three first-login gates:
    // passwordReset, agreedToTermsOfUse, and the reminder-query (security
    // question) prompt. Any of them will hijack the session and break the
    // headless REST API / portlet actions, so clear them all up front.
    User admin = UserLocalServiceUtil.getUserByEmailAddress(
        company.companyId, "__ADMIN_EMAIL__")
    admin.setAgreedToTermsOfUse(true)
    admin.setPasswordReset(false)
    admin.setReminderQueryQuestion("what-is-your-favorite-color")
    admin.setReminderQueryAnswer("blue")
    UserLocalServiceUtil.updateUser(admin)

    // Mirror the source company's enabled-locales onto the new one. A fresh
    // company defaults to en_US only; LAR imports validate against the
    // destination's locale set, so importing content with extra locales
    // fails until they are enabled here too.
    Company sourceCompany = CompanyLocalServiceUtil.getCompanyByWebId("__SOURCE_WEB_ID__")
    String sourceLocales = PrefsPropsUtil.getString(
        sourceCompany.companyId, PropsKeys.LOCALES)
    if (sourceLocales != null && !sourceLocales.isEmpty()) {
        def newPrefs = PrefsPropsUtil.getPreferences(company.companyId)
        newPrefs.setValue(PropsKeys.LOCALES, sourceLocales)
        newPrefs.store()
        // Per-company locale cache is loaded lazily on first read; without a
        // reset, later writes are invisible and Liferay falls back to the
        // portal-wide defaults when the new site picks its locales.
        LanguageUtil.resetAvailableLocales(company.companyId)
    }

    println "INSTANCE_COMPANY_ID=${company.companyId}"
    println "INSTANCE_WEB_ID=${company.webId}"
}
catch (Throwable t) {
    println "ERROR=${t.class.name}: ${t.message}"
    t.printStackTrace()
}
