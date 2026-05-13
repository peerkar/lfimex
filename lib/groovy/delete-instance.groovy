// =============================================================================
// Delete a Liferay portal instance (Company row) by its companyId.
// Cascades to every group, layout, user, and content row inside that company.
//
// Run via scripts/executeScript.gosh, same as create-instance.groovy.
// Placeholder __COMPANY_ID__ is substituted by step_cleanup.sh.
// =============================================================================

import com.liferay.portal.kernel.service.CompanyLocalServiceUtil

try {
    CompanyLocalServiceUtil.deleteCompany(__COMPANY_ID__L)

    println "DELETED_COMPANY_ID=__COMPANY_ID__"
}
catch (Throwable t) {
    println "ERROR=${t.class.name}: ${t.message}"
    t.printStackTrace()
}
