# =============================================================================
# Test: CALENDAR
# Tables: CalendarResource, Calendar, CalendarBooking,
#         CalendarNotificationTemplate, ClassName_
# =============================================================================

test_calendar() {
    section "CALENDAR"

    # =========================================================================
    # Calendar
    # =========================================================================

    check "Calendar – Total count" "
        SELECT
            COUNT(*)    AS total
        FROM Calendar
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0;
    "

    check "Calendar – Count per calendar resource" "
        SELECT
            cr.uuid_            AS resource_uuid,
            COUNT(*)            AS calendar_count
        FROM Calendar c
        JOIN CalendarResource cr
          ON cr.calendarResourceId = c.calendarResourceId
             AND cr.ctCollectionId = 0
        WHERE c.groupId = __GROUPID__
          AND c.ctCollectionId = 0
        GROUP BY cr.uuid_
        ORDER BY cr.uuid_;
    "

    check "Calendar – Identifiers" "
        SELECT
            uuid_
        FROM Calendar
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    check "Calendar – Name and description" "
        SELECT
            uuid_,
            REGEXP_REPLACE(name,        '<[^>]+>', '') AS name_plain,
            MD5(NULLIF(description, ''))                AS description_md5,
            LENGTH(NULLIF(description, ''))             AS description_len
        FROM Calendar
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    check "Calendar – Core fields" "
        SELECT
            uuid_,
            color,
            defaultCalendar,
            enableComments,
            enableRatings,
            timeZoneId
        FROM Calendar
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    check "Calendar – Dates" "
        SELECT
            uuid_,
            createDate,
            modifiedDate
        FROM Calendar
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    # =========================================================================
    # CalendarResource
    # =========================================================================

    check "CalendarResource – Total Count" "
        SELECT
            COUNT(*)    AS total_resources
        FROM CalendarResource
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0;
    "

    check "CalendarResource – Identifiers" "
        SELECT
            uuid_,
            cn.value            AS className
        FROM CalendarResource cr
        JOIN ClassName_ cn
          ON cn.classNameId = cr.classNameId
        WHERE cr.groupId = __GROUPID__
          AND cr.ctCollectionId = 0
        ORDER BY cr.uuid_;
    "

    check "CalendarResource – Description" "
        SELECT
            uuid_,
            MD5(NULLIF(description, ''))                AS description_md5,
            LENGTH(NULLIF(description, ''))             AS description_len
        FROM CalendarResource
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    check "CalendarResource – Core fields" "
        SELECT
            uuid_,
            active_
        FROM CalendarResource
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    check "CalendarResource – Dates" "
        SELECT
            uuid_,
            createDate,
            modifiedDate
        FROM CalendarResource
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    # =========================================================================
    # CalendarBooking
    # =========================================================================

    check "CalendarBooking – Count per status" "
        SELECT
            status,
            COUNT(*)    AS total
        FROM CalendarBooking
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
        GROUP BY status
        ORDER BY status;
    "

    check "CalendarBooking – Identifiers" "
        SELECT
            externalReferenceCode,
            vEventUid,
            uuid_
        FROM CalendarBooking
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    check "CalendarBooking – Title and description" "
        SELECT
            externalReferenceCode,
            REGEXP_REPLACE(title,       '<[^>]+>', '') AS title_plain,
            MD5(description)                           AS description_md5,
            LENGTH(description)                        AS description_len
        FROM CalendarBooking
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    check "CalendarBooking – Core fields" "
        SELECT
            externalReferenceCode,
            allDay,
            endTime,
            firstReminder,
            firstReminderType,
            MD5(location)              AS location_md5,
            LENGTH(location)           AS location_len,
            MD5(recurrence)            AS recurrence_md5,
            LENGTH(recurrence)         AS recurrence_len,
            secondReminder,
            secondReminderType,
            startTime,
            status
        FROM CalendarBooking
        WHERE groupId = __GROUPID__
          AND parentCalendarBookingId = calendarBookingId  -- master bookings only
          AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    check "CalendarBooking – Count per calendar" "
        SELECT
            cr.code_            AS resource_code,
            REGEXP_REPLACE(c.name, '<[^>]+>', '') AS calendar_name,
            COUNT(*)            AS booking_count
        FROM CalendarBooking cb
        JOIN Calendar c
          ON c.calendarId = cb.calendarId
             AND c.ctCollectionId = 0
        JOIN CalendarResource cr
          ON cr.calendarResourceId = c.calendarResourceId
             AND cr.ctCollectionId = 0
        WHERE cb.groupId = __GROUPID__
          AND cb.ctCollectionId = 0
        GROUP BY cr.code_, calendar_name
        ORDER BY cr.code_, calendar_name;
    "

    check "CalendarBooking – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM CalendarBooking
        WHERE groupId = __GROUPID__
          AND parentCalendarBookingId = calendarBookingId  -- master bookings only
          AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    # =========================================================================
    # CalendarNotificationTemplate
    # =========================================================================

    check "CalendarNotificationTemplate – Total Count" "
        SELECT
            COUNT(*)            AS total
        FROM CalendarNotificationTemplate
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0;
    "

    check "CalendarNotificationTemplate – Identifiers" "
        SELECT
            uuid_
        FROM CalendarNotificationTemplate
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    check "CalendarNotificationTemplate – Count per calendar" "
        SELECT
            c.uuid_            AS calendar_uuid,
            COUNT(*)            AS template_count
        FROM CalendarNotificationTemplate cnt
        JOIN Calendar c
          ON c.calendarId = cnt.calendarId
             AND c.ctCollectionId = 0
        WHERE cnt.groupId = __GROUPID__
          AND cnt.ctCollectionId = 0
        GROUP BY c.uuid_
        ORDER BY c.uuid_;
    "

    check "CalendarNotificationTemplate – Core fields" "
        SELECT
            uuid_,
            notificationType,
            notificationTemplateType
        FROM CalendarNotificationTemplate
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    check "CalendarNotificationTemplate – Content" "
        SELECT
            uuid_,
            subject,
            notificationTypeSettings,
            MD5(body)           AS body_md5,
            LENGTH(body)        AS body_len
        FROM CalendarNotificationTemplate
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    check "CalendarNotificationTemplate – Dates" "
        SELECT
            uuid_,
            createDate,
            modifiedDate
        FROM CalendarNotificationTemplate
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "
}
