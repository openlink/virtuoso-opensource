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
 *  Copyright (C) 1998-2006 OpenLink Software
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
 *  
*/

#ifndef _DATESUPP_H
#define _DATESUPP_H

/* datesupp.c */
uint32 date2num (const int year, const int month, const int day);
void num2date (uint32 julian_days, int *year, int *month, int *day);
int ymd_valid_p (const int year, const int month, const int day);
int date2weekday (const int year, const int month, const int day);
void dt_now (caddr_t dt);
void time_t_to_dt (time_t tim, long fraction, char *dt);
#if defined (WIN32) && (defined (_AMD64_) || defined (_FORCE_WIN32_FILE_TIME))
int file_mtime_to_dt (const char * name, char *dt);
#endif
void sec2time (int sec, int *day, int *hour, int *min, int *tsec);
int time2sec (int day, int hour, int min, int sec);
void ts_add (TIMESTAMP_STRUCT *ts, int n, const char *unit);
int dt_validate (caddr_t dt);
void dt_to_timestamp_struct (caddr_t dt, TIMESTAMP_STRUCT *ts);
void timestamp_struct_to_dt (TIMESTAMP_STRUCT *ts_in, char *dt);
void dt_to_date_struct (char *dt, DATE_STRUCT *ots);
void date_struct_to_dt (DATE_STRUCT *ts, char *dt);
void dt_to_time_struct (char *dt, TIME_STRUCT *ots);
void time_struct_to_dt (TIME_STRUCT *ts, char *dt);
void dt_date_round (char *dt);
void dt_init (void);
int dt_part_ck (char *str, int min, int max, int *err);
void dt_to_string (char *dt, char *str, int len);
void dt_to_iso8601_string (char *dt, char *str, int len);
void dt_to_rfc1123_string (char *dt, char *str, int len);
int string_to_dt (char *str, char *dt, const char **str_err);
int string_to_time_dt (char *str, char *dt);
void dt_to_tv (char *dt, char *dv);
void dt_make_day_zero (char *dt);
void dt_from_parts (char *dt, int year, int month, int day, int hour, int minute, int second, int fraction, int tz);
int days_in_february (const int year);

extern int dt_local_tz;

#endif /* _DATESUPP_H */
