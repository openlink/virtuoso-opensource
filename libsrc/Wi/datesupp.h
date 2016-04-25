/*
 *  datesupp.c
 *
 *  $Id$
 *
 *  Date support functions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */

#ifndef _DATESUPP_H
#define _DATESUPP_H
#include "Dk.h"
#include "date.h"

/*! GMTIMESTAMP_STRUCT is identical to TIMESTAMP_STRUCT but is supposed to be in GMT, not in default server timezone or anything else */
#define GMTIMESTAMP_STRUCT TIMESTAMP_STRUCT

/* datesupp.c */

/* The Gregorian Reformation date. First day of Gregorian calendar is 1582-10-15 and that is the day after the 1582-10-04 that is the last Julian day. */
#define GREG_YEAR				1582
#define GREG_MONTH				10
#define GREG_LAST_JULIAN_DAY			4
#define GREG_LAST_JULIAN_DAY_AS_PROLEPTIC_GREG	14
#define GREG_JDAYS	577737L	/* date2num (GREG_YEAR, GREG_MONTH, GREG_LAST_JULIAN_DAY) */

#define GREG_YMD_IS_PROLEPTIC_GREG(year,month,day) \
  ((year) < GREG_YEAR || (((year) == GREG_YEAR) && ((month) < GREG_MONTH || (((month) == GREG_MONTH) && ((day) <= GREG_LAST_JULIAN_DAY_AS_PROLEPTIC_GREG)))))
#define GREG_YMD_IS_POST_JULIAN_PROLEPTIC_GREG(year,month,day) \
  ((year == GREG_YEAR) && ((month == GREG_MONTH) && (day <= GREG_LAST_JULIAN_DAY_AS_PROLEPTIC_GREG) &&  (day > GREG_LAST_JULIAN_DAY)))

typedef int32 jday_t;
jday_t date2num (int year, int month, int day);
void num2date (jday_t julian_days, int *year, int *month, int *day);
int ymd_valid_p (int year, int month, int day);
int date2weekday (int year, int month, int day);
void dt_now (caddr_t dt);
void dt_now_tz (caddr_t dt);
void time_t_to_dt (time_t tim, long fraction, char *dt);
#if defined (WIN32) && (defined (_AMD64_) || defined (_FORCE_WIN32_FILE_TIME))
int file_mtime_to_dt (const char * name, char *dt);
#endif
void sec2time (int sec, int *day, int *hour, int *min, int *tsec);
int time2sec (int day, int hour, int min, int sec);
void ts_add (TIMESTAMP_STRUCT *ts, boxint n, const char *unit);
int dt_validate (caddr_t dt);
extern int dt_compare (caddr_t dt1, caddr_t dt2, int cmp_is_safe);
void dt_to_GMTimestamp_struct (ccaddr_t dt, GMTIMESTAMP_STRUCT *ts);
void GMTimestamp_struct_to_dt (GMTIMESTAMP_STRUCT *ts_in, char *dt);
void dt_to_timestamp_struct (ccaddr_t dt, TIMESTAMP_STRUCT *ts);
void timestamp_struct_to_dt (TIMESTAMP_STRUCT *ts_in, char *dt);
void dt_to_date_struct (char *dt, DATE_STRUCT *ots);
void date_struct_to_dt (DATE_STRUCT *ts, char *dt);
void dt_to_time_struct (char *dt, TIME_STRUCT *ots);
void time_struct_to_dt (TIME_STRUCT *ts, char *dt);
int dt_local_tzmin_for_parts (int year, int month, int day, int hour, int minute, int second);
void dt_date_round (char *dt);
void dt_init (void);
int dt_part_ck (char *str, int min, int max, int *err);
void dt_to_string (const char *dt, char *str, int len);
void dbg_dt_to_string (const char *dt, char *str, int len);
void dt_to_iso8601_string (const char *dt, char *str, int len);
void dt_to_iso8601_string_ext (const char *dt, char *buf, int len, int mode);
void dt_to_rfc1123_string (const char *dt, char *str, int len);
int print_dt_to_buffer (char *buf, caddr_t arg, int mode);

#define DTFLAG_YY	0x1
#define DTFLAG_MM	0x2
#define DTFLAG_DD	0x4
#define DTFLAG_HH	0x8
#define DTFLAG_MIN	0x10
#define DTFLAG_SS	0x20
#define DTFLAG_SF	0x40
#define DTFLAG_ZH	0x80
#define DTFLAG_ZM	0x100
#define DTFLAG_DATE	(DTFLAG_YY | DTFLAG_MM | DTFLAG_DD)
#define DTFLAG_TIME	(DTFLAG_HH | DTFLAG_MIN | DTFLAG_SS | DTFLAG_SF)
#define DTFLAG_TIMEZONE	(DTFLAG_ZH | DTFLAG_ZM)
#define DTFLAG_ALLOW_JAVA_SYNTAX	0x0400	/*!< Allows Java-style +h, +hmm and +hhmm styles for timezone */
#define DTFLAG_DATES_AND_TIMES_ARE_ISO	0x0800
#define DTFLAG_ALLOW_ODBC_SYNTAX	0x1000
#define DTFLAG_T_FORMAT_SETS_TZL	0x2000
#define DTFLAG_FORMAT_SETS_FLAGS	0x4000
#define DTFLAG_FORCE_DAY_ZERO		0x8000

extern void iso8601_or_odbc_string_to_dt (const char *str, char *dt, int dtflags, int dt_type, caddr_t *err_msg_ret);
extern void iso8601_or_odbc_string_to_dt_1 (const char *str, char *dt, int dtflags, int dt_type, caddr_t *err_msg_ret); /*!< Note that it does not skip whitespaces at the beginning of \c str and it can change the content of \c str */

#define odbc_string_to_any_dt(str,dt,err_msg_ret) \
  iso8601_or_odbc_string_to_dt ((str), (dt), \
    (DTFLAG_DATE | DTFLAG_TIME | DTFLAG_TIMEZONE | DTFLAG_ALLOW_ODBC_SYNTAX | DTFLAG_ALLOW_JAVA_SYNTAX | DTFLAG_T_FORMAT_SETS_TZL | DTFLAG_FORMAT_SETS_FLAGS | \
      ((DT_TZL_PREFER == timezoneless_datetimes) ? DTFLAG_DATES_AND_TIMES_ARE_ISO : 0)), \
    DT_TYPE_DATETIME, err_msg_ret )
#define odbc_string_to_time_dt(str,dt,err_msg_ret) \
  iso8601_or_odbc_string_to_dt ((str), (dt), \
    (DTFLAG_TIME | DTFLAG_TIMEZONE | DTFLAG_ALLOW_ODBC_SYNTAX | DTFLAG_ALLOW_JAVA_SYNTAX | DTFLAG_T_FORMAT_SETS_TZL | DTFLAG_FORMAT_SETS_FLAGS | DTFLAG_FORCE_DAY_ZERO | \
      ((DT_TZL_PREFER == timezoneless_datetimes) ? DTFLAG_DATES_AND_TIMES_ARE_ISO : 0)), \
    DT_TYPE_TIME, err_msg_ret )
#define iso8601_string_to_datetime_dt(str,dt,err_msg_ret) \
  iso8601_or_odbc_string_to_dt ((str), (dt), \
    (DTFLAG_DATE | DTFLAG_TIME | DTFLAG_TIMEZONE | DTFLAG_ALLOW_JAVA_SYNTAX | DTFLAG_T_FORMAT_SETS_TZL | DTFLAG_DATES_AND_TIMES_ARE_ISO), \
    DT_TYPE_DATETIME, err_msg_ret )

void dt_to_tv (char *dt, char *dv);
void dt_make_day_zero (char *dt);
void dt_from_parts (char *dt, int year, int month, int day, int hour, int minute, int second, int fraction, int tz);
int days_in_february (const int year);

#define DT_PRINT_MODE_NO_Y 0x40
#define DT_PRINT_MODE_NO_M 0x20
#define DT_PRINT_MODE_NO_D 0x10
#define DT_PRINT_MODE_YMD 0x4
#define DT_PRINT_MODE_HMS 0x2
#define DT_PRINT_MODE_XML 0x1

extern int dt_print_to_buffer (char *buf, caddr_t arg, int mode);
extern int dt_scan_from_buffer (const char *buf, int mode, caddr_t *dt_ret, const char **err_msg_ret);

#define DT_TZL_NEVER_COMPAT	0	/*!< Never use timezoneless, always set local timezone on parsing strings if not timezone specified, setting tzl by BIF will signal error, but TZL values still may come from outside as dezerializations of DV_DATETIME boxes. Should be 0 because this is the default for older versions and thus 0 filler past the end of old wi_database_t serializations */
#define DT_TZL_BY_ISO		1	/*!< Set timezoneless if ISO format tells so */
#define DT_TZL_PREFER		2	/*!< Set timezoneless always, exception is when the parsed string contains explicit timezone or RFC requires GMT or timezone is set by bif. Should be greater than \c DT_TZL_BY_ISO */
#define DT_TZL_NEVER_VERBOSE	3	/*!< Never use timezoneless, always set local timezone on parsing strings if not timezone specified, setting tzl by BIF will signal error, but TZL values still may come from outside as dezerializations of DV_DATETIME boxes. The difference with \c DT_TZL_NEVER_COMPAT is that timezones are always printed on cast datetimes to strings etc. */
#define DT_TZL_AS_GMT		4	/*!< On parsing string, set timezone to GMT if no timezone specified. An explicit setting tzl by BIF will not signal error, TZL values may also come from outside as dezerializations of DV_DATETIME boxes. */
#define DT_TZL_BY_DEFAULT	DT_TZL_PREFER

extern int timezoneless_datetimes;	/*!< One of DT_TZL_XXX values. The default for newly created databases is DT_TZL_BY_DEFAULT, */
extern int dt_local_tz_for_logs;		/* minutes from GMT */
extern int dt_local_tz_for_weird_dates;	/* minutes from GMT */
unsigned int64 dt_seconds (caddr_t dt);
void dt_print (caddr_t dt);

typedef caddr_t arithm_dt_operation_t (ccaddr_t box1, ccaddr_t box2, caddr_t *err_ret);
extern arithm_dt_operation_t arithm_dt_add;
extern arithm_dt_operation_t arithm_dt_subtract;

extern int rb_type__xsd_gDay;
extern int rb_type__xsd_gMonth;
extern int rb_type__xsd_gMonthDay;
extern int rb_type__xsd_gYear;
extern int rb_type__xsd_gYearMonth;
extern int rb_type__xsd_date;
extern int rb_type__xsd_dateTime;
extern int rb_type__xsd_time;

#endif /* _DATESUPP_H */
