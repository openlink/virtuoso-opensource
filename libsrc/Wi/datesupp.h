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
 *  Copyright (C) 1998-2013 OpenLink Software
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
int32 date2num (const int year, const int month, const int day);
void num2date (int32 julian_days, int *year, int *month, int *day);
int ymd_valid_p (const int year, const int month, const int day);
int date2weekday (const int year, const int month, const int day);
void dt_now (caddr_t dt);
void time_t_to_dt (time_t tim, long fraction, char *dt);
#if defined (WIN32) && (defined (_AMD64_) || defined (_FORCE_WIN32_FILE_TIME))
int file_mtime_to_dt (const char * name, char *dt);
#endif
void sec2time (int sec, int *day, int *hour, int *min, int *tsec);
int time2sec (int day, int hour, int min, int sec);
void ts_add (TIMESTAMP_STRUCT *ts, boxint n, const char *unit);
int dt_validate (caddr_t dt);
void dt_to_GMTimestamp_struct (ccaddr_t dt, GMTIMESTAMP_STRUCT *ts);
void GMTimestamp_struct_to_dt (GMTIMESTAMP_STRUCT *ts_in, char *dt);
void dt_to_timestamp_struct (ccaddr_t dt, TIMESTAMP_STRUCT *ts);
void timestamp_struct_to_dt (TIMESTAMP_STRUCT *ts_in, char *dt);
void dt_to_date_struct (char *dt, DATE_STRUCT *ots);
void date_struct_to_dt (DATE_STRUCT *ts, char *dt);
void dt_to_time_struct (char *dt, TIME_STRUCT *ots);
void time_struct_to_dt (TIME_STRUCT *ts, char *dt);
void dt_date_round (char *dt);
void dt_init (void);
int dt_part_ck (char *str, int min, int max, int *err);
void dt_to_string (const char *dt, char *str, int len);
void dbg_dt_to_string (const char *dt, char *str, int len);
void dt_to_iso8601_string (const char *dt, char *str, int len);
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
#define DTFLAG_ALLOW_ODBC_SYNTAX	0x1000
#define DTFLAG_FORMAT_SETS_FLAGS	0x2000
#define DTFLAG_FORCE_DAY_ZERO		0x4000

extern void iso8601_or_odbc_string_to_dt (const char *str, char *dt, int dtflags, int dt_type, caddr_t *err_msg_ret);
#define odbc_string_to_any_dt(str,dt,err_msg_ret) \
  iso8601_or_odbc_string_to_dt ((str), (dt), \
    (DTFLAG_DATE | DTFLAG_TIME | DTFLAG_TIMEZONE | DTFLAG_ALLOW_ODBC_SYNTAX | DTFLAG_FORMAT_SETS_FLAGS), \
    DT_TYPE_DATETIME, err_msg_ret )
#define odbc_string_to_time_dt(str,dt,err_msg_ret) \
  iso8601_or_odbc_string_to_dt ((str), (dt), \
    (DTFLAG_TIME | DTFLAG_TIMEZONE | DTFLAG_ALLOW_ODBC_SYNTAX | DTFLAG_FORMAT_SETS_FLAGS | DTFLAG_FORCE_DAY_ZERO), \
    DT_TYPE_TIME, err_msg_ret )
#define iso8601_string_to_datetime_dt(str,dt,err_msg_ret) \
  iso8601_or_odbc_string_to_dt ((str), (dt), \
    (DTFLAG_DATE | DTFLAG_TIME | DTFLAG_TIMEZONE), \
    DT_TYPE_DATETIME, err_msg_ret )

void dt_to_tv (char *dt, char *dv);
void dt_make_day_zero (char *dt);
void dt_from_parts (char *dt, int year, int month, int day, int hour, int minute, int second, int fraction, int tz);
int days_in_february (const int year);

#define DT_PRINT_MODE_YMD 0x4
#define DT_PRINT_MODE_HMS 0x2
#define DT_PRINT_MODE_XML 0x1

extern int dt_print_to_buffer (char *buf, caddr_t arg, int mode);
extern int dt_scan_from_buffer (const char *buf, int mode, caddr_t *dt_ret, const char **err_msg_ret);

extern int dt_local_tz;
int dt_compare (caddr_t dt1, caddr_t dt2);
unsigned int64  dt_seconds (caddr_t dt);
void dt_print (caddr_t dt);

typedef caddr_t arithm_dt_operation_t (ccaddr_t box1, ccaddr_t box2, caddr_t *err_ret);
extern arithm_dt_operation_t arithm_dt_add;
extern arithm_dt_operation_t arithm_dt_subtract;

#endif /* _DATESUPP_H */
