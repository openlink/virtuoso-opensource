/*
 *  bif_date.c
 *
 *  $Id$
 *
 *  Bifs for date
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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

#include <math.h>
#include "odbcinc.h"
#include "sqlnode.h"
#include "sqlfn.h"
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlbif.h"
#include "arith.h"
#include "security.h"
#include "sqlpfn.h"
#include "date.h"
#include "datesupp.h"
#include "multibyte.h"
#include "srvmultibyte.h"
#include "util/strfuns.h"
#include "uname_const_decl.h"

#define KUBL_ILLEGAL_DATE_VALUE (0)	/* Added by AK 15-JAN-1997. */


caddr_t
bif_date_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp != DV_DATETIME && dtp != DV_BIN)
    sqlr_new_error ("22007", "DT001",
	"Function %s needs a datetime, date or time as argument %d, not an arg of type %s (%d)",
	func, nth + 1, dv_type_title (dtp), dtp);
  return arg;
}

caddr_t
bif_date_arg_rb_type (caddr_t * qst, state_slot_t ** args, int nth, const char *func, int *rb_type_ret)
{
  rdf_box_t *src_rdf_box;
  caddr_t arg = bif_arg_unrdf_ext (qst, args, nth, func, (caddr_t *)(&src_rdf_box));
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp != DV_DATETIME && dtp != DV_BIN)
    sqlr_new_error ("22007", "DT001",
	"Function %s needs a datetime, date or time as argument %d, not an arg of type %s (%d)",
	func, nth + 1, dv_type_title (dtp), dtp);
  if ((DV_RDF == DV_TYPE_OF (src_rdf_box))
    && (RDF_BOX_DEFAULT_TYPE != src_rdf_box->rb_type)
    && ((rb_type__xsd_gDay		== src_rdf_box->rb_type)
        || (rb_type__xsd_gMonth		== src_rdf_box->rb_type)
        || (rb_type__xsd_gMonthDay	== src_rdf_box->rb_type)
        || (rb_type__xsd_gYear		== src_rdf_box->rb_type)
        || (rb_type__xsd_gYearMonth	== src_rdf_box->rb_type) ) )
    rb_type_ret[0] = src_rdf_box->rb_type;
  else
    rb_type_ret[0] = RDF_BOX_ILL_TYPE;
  return arg;
}

int
dt_print_flags_of_rb_type (int rb_type)
{
  if (rb_type__xsd_gDay		== rb_type)	return DT_PRINT_MODE_YMD | DT_PRINT_MODE_NO_Y | DT_PRINT_MODE_NO_M                                         ;
  if (rb_type__xsd_gMonth	== rb_type)	return DT_PRINT_MODE_YMD | DT_PRINT_MODE_NO_Y                      | DT_PRINT_MODE_NO_D                    ;
  if (rb_type__xsd_gMonthDay	== rb_type)	return DT_PRINT_MODE_YMD | DT_PRINT_MODE_NO_Y                                                              ;
  if (rb_type__xsd_gYear	== rb_type)	return DT_PRINT_MODE_YMD                      | DT_PRINT_MODE_NO_M | DT_PRINT_MODE_NO_D                    ;
  if (rb_type__xsd_gYearMonth	== rb_type)	return DT_PRINT_MODE_YMD                                           | DT_PRINT_MODE_NO_D                    ;
  if (rb_type__xsd_date		== rb_type)	return DT_PRINT_MODE_YMD                                                                                   ;
  if (rb_type__xsd_dateTime	== rb_type)	return DT_PRINT_MODE_YMD                                                                | DT_PRINT_MODE_HMS;
  if (rb_type__xsd_time		== rb_type)	return                                                                                    DT_PRINT_MODE_HMS;
  return 0;
}

int
dt_print_flags_of_xsd_type_uname (ccaddr_t xsd_type_uname)
{
  if (uname_xmlschema_ns_uri_hash_gDay		== xsd_type_uname)	return DT_PRINT_MODE_YMD | DT_PRINT_MODE_NO_Y | DT_PRINT_MODE_NO_M                                         ;
  if (uname_xmlschema_ns_uri_hash_gMonth	== xsd_type_uname)	return DT_PRINT_MODE_YMD | DT_PRINT_MODE_NO_Y                      | DT_PRINT_MODE_NO_D                    ;
  if (uname_xmlschema_ns_uri_hash_gMonthDay	== xsd_type_uname)	return DT_PRINT_MODE_YMD | DT_PRINT_MODE_NO_Y                                                              ;
  if (uname_xmlschema_ns_uri_hash_gYear		== xsd_type_uname)	return DT_PRINT_MODE_YMD                      | DT_PRINT_MODE_NO_M | DT_PRINT_MODE_NO_D                    ;
  if (uname_xmlschema_ns_uri_hash_gYearMonth	== xsd_type_uname)	return DT_PRINT_MODE_YMD |                                           DT_PRINT_MODE_NO_D                    ;
  if (uname_xmlschema_ns_uri_hash_date		== xsd_type_uname)	return DT_PRINT_MODE_YMD                                                                                   ;
  if (uname_xmlschema_ns_uri_hash_dateTime	== xsd_type_uname)	return DT_PRINT_MODE_YMD                                                                | DT_PRINT_MODE_HMS;
  if (uname_xmlschema_ns_uri_hash_time		== xsd_type_uname)	return                                                                                    DT_PRINT_MODE_HMS;
  return 0;
}

caddr_t
bif_date_string (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char temp[100];
  caddr_t arg = bif_date_arg (qst, args, 0, "datestring");
  dt_to_string (arg, temp, sizeof (temp));
  return (box_dv_short_string (temp));
}


caddr_t
bif_date_string_GMT (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char temp[100];
  caddr_t arg = bif_date_arg (qst, args, 0, "datestring");
  char dt2[DT_LENGTH];
  memcpy (dt2, arg, DT_LENGTH);
  DT_SET_TZ (dt2, 0);
  dt_to_string (dt2, temp, sizeof (temp));
  return (box_dv_short_string (temp));
}

int
dt_print_to_buffer (char *buf, caddr_t arg, int mode)
{
  int res = 0;
  int arg_dt_type = DT_DT_TYPE (arg);
  TIMESTAMP_STRUCT ts;
  if (0 == ((DT_PRINT_MODE_YMD | DT_PRINT_MODE_HMS) & mode))
    mode |= ((DT_TYPE_TIME == arg_dt_type) ? DT_PRINT_MODE_HMS :
      ((DT_TYPE_DATE == arg_dt_type) ? DT_PRINT_MODE_YMD : (DT_PRINT_MODE_YMD | DT_PRINT_MODE_HMS)) );
  if ((DT_PRINT_MODE_YMD & mode) && (DT_TYPE_TIME == arg_dt_type))
    sqlr_new_error ("22023", "SR592", "Bit 4 in print mode requires DATE or DATETIME argument, not TIME");
  if ((DT_PRINT_MODE_HMS & mode) && (DT_TYPE_DATE == arg_dt_type))
    sqlr_new_error ("22023", "SR593", "Bit 2 in print mode requires TIME or DATETIME argument, not DATE");
  dt_to_GMTimestamp_struct (arg, &ts);
  if (DT_PRINT_MODE_YMD & mode)
    {
      if (DT_PRINT_MODE_NO_D & mode)
        {
          if (DT_PRINT_MODE_NO_Y & mode)
            res += sprintf (buf, "--%02d", ts.month + ((15 <= ts.day) ? 1 : 0));
          else if (DT_PRINT_MODE_NO_M & mode)
            res += sprintf (buf, "%04d", ts.year + ((6 <= ts.month) ? 1 : 0));
          else if (15 <= ts.day)
            res += sprintf (buf, "%02d-%02d", ts.year + ((12 == ts.month) ? 1 : 0), (ts.month % 12) + 1);
          else
            res += sprintf (buf, "%04d-%02d", ts.year, ts.month);
        }
      else if (DT_PRINT_MODE_NO_Y & mode)
        {
          if (DT_PRINT_MODE_NO_M & mode)
            res += sprintf (buf, "---%02d", ts.day);
          else
            res += sprintf (buf, "--%04d-%02d", ts.month, ts.day);
        }
      else
        res += sprintf (buf, "%04d-%02d-%02d", ts.year, ts.month, ts.day);
    }
  if ((DT_PRINT_MODE_YMD & mode) && (DT_PRINT_MODE_HMS & mode))
    buf[res++] = ((DT_PRINT_MODE_XML & mode) ? 'T' : ' ');
  if (DT_PRINT_MODE_HMS & mode)
    {
      res += sprintf (buf + res, "%02d:%02d:%02d", ts.hour, ts.minute, ts.second);
      if (ts.fraction)
        {
          if (ts.fraction % 1000)
            res += sprintf (buf + res, ".%09d", (int)ts.fraction);
          else if (ts.fraction % 1000000)
            res += sprintf (buf + res, ".%06d", (int)(ts.fraction / 1000));
          else
            res += sprintf (buf + res, ".%03d", (int)(ts.fraction / 1000000));
        }
    }
  if (DT_TZL (arg))
    return res;
  else if (DT_PRINT_MODE_XML & mode)
    {
      strcpy (buf + res, "Z");
      return res + 1;
    }
  else
    {
      strcpy (buf + res, " GMT");
      return res + 4;
    }
}

int /* Returns number of chars parsed. */
dt_scan_from_buffer (const char *buf, int mode, caddr_t *dt_ret, const char **err_msg_ret)
{
  const char *tail = buf;
  int fld_len, acc, ymd_found = 0, hms_found = 0, msec_factor;
  TIMESTAMP_STRUCT ts;
  memset (&ts, 0, sizeof (TIMESTAMP_STRUCT));
  dt_ret[0] = NULL;
  err_msg_ret[0] = NULL;
  fld_len = 0; acc = 0; while (isdigit (tail[0]) && (4 > fld_len)) { acc = acc * 10 + (tail++)[0] - '0'; fld_len++; }
  if ('-' == tail[0])
    { /* Date delimiter, let's parse date part */
      if (((DT_PRINT_MODE_YMD | DT_PRINT_MODE_HMS) & mode) && !(DT_PRINT_MODE_YMD & mode))
        {
          err_msg_ret[0] = "Time field is expected but date field delimiter is found";
          return 0;
        }
      if (4 != fld_len)
        {
          err_msg_ret[0] = "Year field should have 4 digits";
          return 0;
        }
      ymd_found = 1;
      ts.year = acc;
      tail++;
      fld_len = 0; acc = 0; while (isdigit (tail[0]) && (2 > fld_len)) { acc = acc * 10 + (tail++)[0] - '0'; fld_len++; }
      if (2 != fld_len)
        {
          err_msg_ret[0] = "Month field should have 2 digits";
          return 0;
        }
      if ('-' != tail[0])
        {
          err_msg_ret[0] = "Minus sign is expected after month";
          return 0;
        }
      ts.month = acc;
      tail++;
      fld_len = 0; acc = 0; while (isdigit (tail[0]) && (2 > fld_len)) { acc = acc * 10 + (tail++)[0] - '0'; fld_len++; }
      if (2 != fld_len)
        {
          err_msg_ret[0] = "Day of month field should have 2 digits";
          return 0;
        }
      ts.day = acc;
      if ('T' != tail[0])
        goto scan_tz; /* see below */
      tail++;
      fld_len = 0; acc = 0; while (isdigit (tail[0]) && (2 > fld_len)) { acc = acc * 10 + (tail++)[0] - '0'; fld_len++; }
    }
  if (':' == tail[0])
    { /* Time delimiter, let's parse time part */
      if (((DT_PRINT_MODE_YMD | DT_PRINT_MODE_HMS) & mode) && !(DT_PRINT_MODE_HMS & mode))
        {
          err_msg_ret[0] = "Date field is expected but time field delimiter is found";
          return 0;
        }
      if (2 != fld_len)
        {
          err_msg_ret[0] = "Hour field should have 2 digits";
          return 0;
        }
      hms_found = 1;
      ts.hour = acc;
      tail++;
      fld_len = 0; acc = 0; while (isdigit (tail[0]) && (2 > fld_len)) { acc = acc * 10 + (tail++)[0] - '0'; fld_len++; }
      if (2 != fld_len)
        {
          err_msg_ret[0] = "Minute field should have 2 digits";
          return 0;
        }
      if (':' != tail[0])
        {
          err_msg_ret[0] = "Colon is expected after minute";
          return 0;
        }
      ts.minute = acc;
      tail++;
      fld_len = 0; acc = 0; while (isdigit (tail[0]) && (2 > fld_len)) { acc = acc * 10 + (tail++)[0] - '0'; fld_len++; }
      if (2 != fld_len)
        {
          err_msg_ret[0] = "Second field should have 2 digits";
          return 0;
        }
      ts.second = acc;
      if ('.' == tail[0])
        {
          tail++;
          msec_factor = 1000000000;
          acc = 0;
          if (!isdigit (tail[0]))
            {
              err_msg_ret[0] = "Fraction of second is expected after decimal dot";
              return 0;
            }
          do
            {
              if (msec_factor)
                acc = acc * 10 + (tail[0] - '0');
              tail++;
              msec_factor /= 10;
            } while (isdigit (tail[0]));
          ts.fraction = acc * (msec_factor ? msec_factor : 1);
        }
      if ('Z' != tail[0] && strncmp (tail, " GMT", 4))
	{
	  err_msg_ret[0] = "Colon or time zone is expected after minute";
	  return 0;
	}
    }
  else
    {
      err_msg_ret[0] = "Generic syntax error in date/time";
      return 0;
    }

scan_tz:
/* Now HMS part is complete (or skipped) */
  if ('Z' == tail[0])
    tail++;
  else if (!strncmp (tail, " GMT", 4))
    tail += 4;
  else
    {
      err_msg_ret[0] = "Generic syntax error in date/time";
      return 0;
    }
  if ((DT_PRINT_MODE_YMD & mode) && !ymd_found)
    {
      err_msg_ret[0] = "Datetime expected but time-only string is found";
      return 0;
    }
  if ((DT_PRINT_MODE_HMS & mode) && !hms_found)
    {
      err_msg_ret[0] = "Datetime expected but date-only string is found";
      return 0;
    }
  dt_ret[0] = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  DT_ZAP (dt_ret[0]);
  {
    uint32 day;
    day = date2num (ts.year, ts.month, ts.day);
    DT_SET_DAY (dt_ret[0], day);
    DT_SET_HOUR (dt_ret[0], ts.hour);
    DT_SET_MINUTE (dt_ret[0], ts.minute);
    DT_SET_SECOND (dt_ret[0], ts.second);
    DT_SET_FRACTION (dt_ret[0], ts.fraction);
    DT_SET_TZ (dt_ret[0], 0); /* was DT_SET_TZ (dt_ret[0], dt_local_tz);  before TZL patch */
  }
  if (!ymd_found)
    DT_SET_DAY (dt_ret[0], DAY_ZERO);
  SET_DT_TYPE_BY_DTP (dt_ret[0], (ymd_found ? (hms_found ? DV_DATETIME : DV_DATE) : DV_TIME));
  return (tail - buf);
}

/*
static char *weekday_names[7] =
{
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday"
};

static char *month_names[12] =
{
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December"
};
*/

static int
dayofweek (caddr_t arg)
{
  TIMESTAMP_STRUCT ts;
  uint32 nowadays, easter_sunday = date2num (2000, 4, 30);

  dt_to_timestamp_struct (arg, &ts);
  nowadays = date2num (ts.year, ts.month, ts.day);

  if (nowadays >= easter_sunday)
    return ((nowadays - easter_sunday) % 7 + 1);
  else
    {
      int wday_to_be = (easter_sunday - nowadays) % 7;
      return (!wday_to_be ? 1 : 8 - wday_to_be);
    }
}

#if defined(HAVE_GMTIME_R)
#define GMTIME_R(g,t) \
    do { \
      struct tm result; \
      g = gmtime_r(t, &result); \
    } while (0)
#else
#define GMTIME_R(g,t) g = gmtime(t)
#endif

/* since we keep time internally in GMT the local time should not be used
   after dt_to_timestampstruct, because it already uses the locales eq. timezone and daylight savings .
 */


/*XXX: on windows platform we need to setup the tm struct manually as before 1970 gmtime returns NULL */
#define bif_x_name(x, format) \
caddr_t \
bif_##x##name (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args) \
{ \
  caddr_t arg = bif_date_arg (qst, args, 0, #x "name"); \
  TIMESTAMP_STRUCT ts; \
  time_t _time; \
  char szTmp[1024]; \
  struct tm t, *gtm; \
  \
  dt_to_timestamp_struct (arg, &ts); \
  _time = ((time_t)24) * 60 * 60 * (date2num (ts.year, ts.month, ts.day) - (time_t) date2num (1970, 1, 1)); \
  \
  GMTIME_R (gtm, &_time); \
  if (NULL != gtm) \
    strftime (szTmp, sizeof (szTmp), format, gtm); \
  else \
    { \
      memset (&t, 0, sizeof (t)); \
      t.tm_wday = dayofweek (arg) - 1; \
      t.tm_mon = ts.month - 1; \
      strftime (szTmp, sizeof (szTmp), format, &t); \
    } \
  return box_dv_short_string (szTmp); \
}


bif_x_name(day, "%A")
bif_x_name(month, "%B")

caddr_t
bif_dayofweek (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_date_arg (qst, args, 0, "dayofweek");

  return box_num (dayofweek (arg));
}

/*
caddr_t
bif_dayname (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_date_arg (qst, args, 0, "bif_dayname");

  return box_dv_short_string (weekday_names [dayofweek (arg) - 1]);
}
*/

caddr_t
bif_dayofyear (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_date_arg (qst, args, 0, "dayofyear");
  TIMESTAMP_STRUCT ts;
  uint32 nowadays, new_year;

  dt_to_timestamp_struct (arg, &ts);
  nowadays = date2num (ts.year, ts.month, ts.day);
  new_year = date2num (ts.year, 1, 1);

  return (box_num (nowadays - new_year + 1));
}


caddr_t
bif_quarter (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_date_arg (qst, args, 0, "quarter");
  TIMESTAMP_STRUCT ts;
  int quarter;

  dt_to_timestamp_struct (arg, &ts);
  if (ts.month <= 3) quarter = 1;
  else if (ts.month <= 6) quarter = 2;
  else if (ts.month <= 9) quarter = 3;
  else quarter = 4;

  return (box_num (quarter));
}


caddr_t
bif_week (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_date_arg (qst, args, 0, "week");
  TIMESTAMP_STRUCT ts;
  uint32 nowadays, new_year;

  dt_to_timestamp_struct (arg, &ts);
  nowadays = date2num (ts.year, ts.month, ts.day);
  new_year = date2num (ts.year, 1, 1);

  return (box_num ((nowadays - new_year) / 7 + 1));
}



caddr_t
bif_year (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)	\
{
  caddr_t dt = bif_date_arg (qst, args, 0, "year");
  TIMESTAMP_STRUCT ts;    int year, month, day;
  num2date (DT_DAY (dt), &year, &month, &day);
  if ((1 == month && 1 == day) || (12 == month && 31 == day))
    {
      int tz = DT_TZ (dt);
      if (!tz)
	return box_num (year);
      dt_to_timestamp_struct (dt, &ts);
      return box_num (ts.year);
    }
  return box_num (year);
}



#define DT_PART(part) \
caddr_t \
bif_##part (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args) \
{ \
  caddr_t dt = bif_date_arg (qst, args, 0, #part); \
  TIMESTAMP_STRUCT ts; \
  dt_to_timestamp_struct (dt, &ts); \
  return box_num (ts.part); \
}


DT_PART (month)
DT_PART (day)
DT_PART (hour)
DT_PART (minute)
DT_PART (second)


caddr_t
bif_is_timezoneless (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_date_arg (qst, args, 0, "is_timezoneless");
  return box_num (DT_TZL (arg));
}

caddr_t
bif_timezone (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_date_arg (qst, args, 0, "timezone");
  int ignore_tzl = ((1 < BOX_ELEMENTS (args)) && bif_long_arg (qst, args, 1, "timezone"));
  if (DT_TZL (arg) && !ignore_tzl)
    return NEW_DB_NULL;
  return box_num (DT_TZ (arg));
}

caddr_t
bif_adjust_timezone (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_date_arg (qst, args, 0, "adjust_timezone");
  long tzmin = bif_long_range_arg (qst, args, 1, "adjust_timezone", -14*60, 14*60);
  int ignore_tzl = ((2 < BOX_ELEMENTS (args)) && bif_long_arg (qst, args, 2, "adjust_timezone"));
  if (DT_TZL (arg) && !ignore_tzl)
    sqlr_new_error ("22023", "SR636", "Timezoneless argument of adjust_timezone()");
  arg = box_copy (arg);
  DT_SET_TZL (arg, 0);
  DT_SET_TZ (arg, tzmin);
  return arg;
}

caddr_t
bif_forget_timezone (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_date_arg (qst, args, 0, "forget_timezone");
  int ignore_timezone = ((1 < BOX_ELEMENTS (args)) && bif_long_arg (qst, args, 1, "forget_timezone"));
  int tzmin = DT_TZ (arg);
  GMTIMESTAMP_STRUCT ts;
  if ((DT_TZL_NEVER_COMPAT == timezoneless_datetimes) && !DT_TZL (arg))
    sqlr_new_error ("22023", "SR636", "BIF forget_timezone() is disabled if TimezonelessDatetimes parameter of virtuoso.ini is set to 0 or the database is old and the parameter is 0 by default");
  arg = box_copy (arg);
  if (tzmin && !ignore_timezone)
    {
      dt_to_GMTimestamp_struct (arg, &ts);
      ts_add (&ts, tzmin, "minute");
      GMTimestamp_struct_to_dt (&ts, arg);
    }
  DT_SET_TZ (arg, 0);
  DT_SET_TZL (arg, 1);
  return arg;
}

#define NASA_TJD_OFFSET (2440000 - 1721423)

caddr_t
bif_nasa_tjd_number (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_date_arg (qst, args, 0, "nasa_tjd_number");
  long n = DT_DAY (arg) - NASA_TJD_OFFSET;
  return box_num (n);
}

caddr_t
bif_nasa_tjd_fraction (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_date_arg (qst, args, 0, "nasa_tjd_fraction");
  double f = (((DT_HOUR (arg) * (boxint)60 + DT_MINUTE (arg)) * (boxint)60 + DT_SECOND (arg)) * (boxint)1000000 + DT_FRACTION (arg)) / (60*60*24*1000000.0);
  return box_double (f);
}

caddr_t
bif_merge_nasa_tjd_to_datetime (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  boxint num = bif_long_arg (qst, args, 0, "merge_nasa_tjd_to_datetime");
  caddr_t res = dk_alloc_box_zero (DT_LENGTH, DV_DATETIME);
  DT_SET_DAY (res, num + NASA_TJD_OFFSET);
  if (1 < BOX_ELEMENTS (args))
    {
      double frac = bif_double_arg (qst, args, 1, "merge_nasa_tjd_to_datetime");
      boxint frac_microsec = frac * (60*60*24*1000000.0);
      if ((0 > frac_microsec) || (60*60*24*(boxint)(1000000) <= frac_microsec))
        sqlr_new_error ("22023", "SR644", "Fraction of julian day should be nonnegative and less than 1");
      DT_SET_FRACTION (res, (frac_microsec % 1000000) * 1000);
      frac_microsec = frac_microsec / 1000000;
      DT_SET_SECOND (res, (frac_microsec % 60));
      frac_microsec = frac_microsec / 60;
      DT_SET_MINUTE (res, (frac_microsec % 60));
      frac_microsec = frac_microsec / 60;
      DT_SET_HOUR (res, frac_microsec);
      DT_SET_DT_TYPE (res, DT_TYPE_DATETIME);
    }
  else
    DT_SET_DT_TYPE (res, DT_TYPE_DATE);
  return res;
}

caddr_t
bif_dateadd (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t res;
  caddr_t part = bif_string_arg (qst, args, 0, "dateadd");
  boxint n = bif_long_arg (qst, args, 1, "dateadd");
  caddr_t dt = bif_date_arg (qst, args, 2, "dateadd");
  TIMESTAMP_STRUCT ts;
  int dt_type = DT_DT_TYPE (dt);
  int year_or_month_tz_tweak = (((!strcmp ("year", part)) || (!strcmp ("month", part))) ? DT_TZ (dt) : 0);
  DT_AUDIT_FIELDS (dt);
  dt_to_GMTimestamp_struct (dt, &ts);
  if (year_or_month_tz_tweak)
    ts_add (&ts, year_or_month_tz_tweak, "minute");
  ts_add (&ts, n, part);
  if (year_or_month_tz_tweak)
    ts_add (&ts, -year_or_month_tz_tweak, "minute");
  res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  GMTimestamp_struct_to_dt (&ts, res);
  DT_SET_TZ (res, DT_TZ (dt));
  DT_SET_TZL (res, DT_TZL (dt));
  if (DT_TYPE_DATE == dt_type
      && (0 == stricmp (part, "year") || 0 == stricmp (part, "month") || 0 == stricmp (part, "day")))
    DT_SET_DT_TYPE (res, dt_type);
  DT_AUDIT_FIELDS (dt);
  return res;
}


caddr_t
bif_datediff (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t unit = bif_string_arg (qst, args, 0, "datediff");
  caddr_t dt1 = bif_date_arg (qst, args, 1, "datediff");
  caddr_t dt2 = bif_date_arg (qst, args, 2, "datediff");
  TIMESTAMP_STRUCT ts1;
  TIMESTAMP_STRUCT ts2;
  boxint day1, day2;
  boxint s1, s2;
  int tz_tweak;
  int frac1, frac2;
  int diffyear, diffmonth;
  if (0 == stricmp (unit, "day"))
    return box_num ((boxint)DT_DAY (dt2) - (boxint)DT_DAY (dt1));
  if ((DT_TZL (dt1) != DT_TZL (dt2)) && stricmp (unit, "month") && stricmp (unit, "year"))
    sqlr_new_error ("22023", "DT013", "Mixed timezoned and timezoneless arguments in datediff");
  s1 = DT_CAST_TO_TOTAL_SECONDS (dt1);
  s2 = DT_CAST_TO_TOTAL_SECONDS (dt2);
  tz_tweak = DT_TZ (dt1);
  if (0 == stricmp (unit, "hour"))
    return box_num ((s2 - s1) / (60 * 60));
  if (0 == stricmp (unit, "minute"))
    return box_num ((s2 - s1) / 60);
  if (0 == stricmp (unit, "second"))
    return box_num (s2 - s1);
  diffyear = !stricmp (unit, "year");
  diffmonth = (diffyear ? 0 : !stricmp (unit, "month"));
  if (diffyear || diffmonth)
    {
      TIMESTAMP_STRUCT ts1;
      TIMESTAMP_STRUCT ts2;
      int tz_tweak = DT_TZ (dt1);
      dt_to_GMTimestamp_struct (dt2, &ts2);
      dt_to_GMTimestamp_struct (dt1, &ts1);
      ts_add (&ts1, tz_tweak, "minute");
      ts_add (&ts2, tz_tweak, "minute");
      if (diffyear)
        return box_num ((boxint)ts2.year - (boxint)ts1.year);
      if (diffmonth)
        return box_num ((boxint)(ts2.year * 12 + ts2.month) - (boxint)(ts1.year * 12 + ts1.month));
    }
  frac1 = DT_FRACTION(dt1);
  frac2 = DT_FRACTION(dt2);
  if (0 == stricmp (unit, "millisecond"))
    return box_num ((s2 - s1) * (boxint)1000 + (frac2 / 1000000 - frac1 / 1000000));
  if (0 == stricmp (unit, "microsecond"))
    return box_num ((s2 - s1) * (boxint)1000000 + (frac2 / 1000 - frac1 / 1000));
  if (0 == stricmp (unit, "nanosecond"))
    return box_num ((s2 - s1) * (boxint)1000000000 + (frac2 - frac1));
  sqlr_new_error ("22023", "DT002", "Bad unit in datediff: %s.", unit);
  return NULL;
}

char *
interval_odbc_to_text (ptrlong odbcInterval, char *func_name)
{
  char *szpart = NULL;
  switch (odbcInterval)
    {
      case SQL_TSI_SECOND:	szpart = "second"; break;
      case SQL_TSI_MINUTE:	szpart = "minute"; break;
      case SQL_TSI_HOUR:	szpart = "hour"; break;
      case SQL_TSI_DAY:		szpart = "day"; break;
      case SQL_TSI_MONTH:	szpart = "month"; break;
      case SQL_TSI_YEAR:	szpart = "year"; break;
      default: sqlr_new_error ("22015", "DT003",
		   "Interval not supported in %s: %ld",
		   func_name, (long) odbcInterval);
    }
  return szpart;
}


caddr_t
bif_timestampadd (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t res;
  ptrlong part = bif_long_arg (qst, args, 0, "timestampadd");
  int n = (int) bif_long_arg (qst, args, 1, "timestampadd");
  caddr_t dt = bif_date_arg (qst, args, 2, "timestampadd");
  int saved_tz = DT_TZ (dt);
  GMTIMESTAMP_STRUCT ts;
  DT_AUDIT_FIELDS (dt);
  dt_to_GMTimestamp_struct (dt, &ts);
  ts_add (&ts, n, interval_odbc_to_text (part, "timestampadd"));
  res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  GMTimestamp_struct_to_dt (&ts, res);
  DT_SET_TZ (res, saved_tz);
  DT_SET_TZL (res, DT_TZL (dt));
  return res;
}


caddr_t
bif_timestampdiff (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong long_unit = bif_long_arg (qst, args, 0, "timestampdiff");
  caddr_t dt1 = bif_date_arg (qst, args, 1, "timestampdiff");
  caddr_t dt2 = bif_date_arg (qst, args, 2, "timestampdiff");
  GMTIMESTAMP_STRUCT ts1, ts2;
  /* BELOW OVERFLOWS on 32 bit long.  Numbers used for computing difference,
   * hence this works when difference below 2**21 = 34 years */
  boxint s1 = (boxint)DT_DAY (dt1) * 24 * 60 * 60 + DT_HOUR (dt1) * 60 * 60 + DT_MINUTE (dt1) * 60 + DT_SECOND (dt1);
  boxint s2 = (boxint)DT_DAY (dt2) * 24 * 60 * 60 + DT_HOUR (dt2) * 60 * 60 + DT_MINUTE (dt2) * 60 + DT_SECOND (dt2);
  char *unit = interval_odbc_to_text (long_unit, "timestampdiff");

  if (0 == stricmp (unit, "day"))
    return box_num ((boxint)DT_DAY (dt2) - (boxint)DT_DAY (dt1));

  if ((DT_TZL (dt1) != DT_TZL (dt2)) && stricmp (unit, "month") && stricmp (unit, "year"))
    sqlr_new_error ("22023", "DT014", "Mixed timezoned and timezoneless arguments in timestampdiff");

  if (0 == stricmp (unit, "hour"))
    return box_num ((s2 - s1) / (60 * 60));

  if (0 == stricmp (unit, "minute"))
    return box_num ((s2 - s1) / 60);

  if (0 == stricmp (unit, "second"))
    return box_num (s2 - s1);

  dt_to_GMTimestamp_struct (dt2, &ts2);
  dt_to_GMTimestamp_struct (dt1, &ts1);

  if (0 == stricmp (unit, "month"))
    return box_num ((boxint)(ts2.year * 12 + ts2.month) - (boxint)(ts1.year * 12 + ts1.month));

  if (0 == stricmp (unit, "year"))
    return box_num ((boxint)ts2.year - (boxint)ts1.year);

  sqlr_new_error ("22015", "DT004", "Bad interval in timestampdiff: %s.", unit);
  return NULL;
}

static caddr_t
bif_extract (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t unit = bif_string_arg (qst, args, 0, "extract");
  caddr_t dt = bif_date_arg (qst, args, 1, "extract");
  TIMESTAMP_STRUCT ts;

  dt_to_timestamp_struct (dt, &ts);
  if (!stricmp (unit, "SECOND"))
    return box_num (ts.second);
  else if (!stricmp (unit, "MINUTE"))
    return box_num (ts.minute);
  else if (!stricmp (unit, "HOUR"))
    return box_num (ts.hour);
  else if (!stricmp (unit, "DAY"))
    return box_num (ts.day);
  else if (!stricmp (unit, "MONTH"))
    return box_num (ts.month);
  else if (!stricmp (unit, "YEAR"))
    return box_num (ts.year);
  else
    {
      *err_ret = srv_make_new_error ("22015", "DT005", "Bad interval in extract.");
      return NULL;
    }
}




caddr_t
bif_dt_set_tz (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_date_arg (qst, args, 0, "dt_set_tz");
  long tz = (long) bif_long_range_arg (qst, args, 1, "dt_set_tz", -14*60, 14*60);
  caddr_t res = box_copy (arg);
  DT_SET_TZ (res, tz);
  DT_SET_TZL (res, 0);
  return res;
}


caddr_t
string_to_dt_box (char * str)
{
  caddr_t res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  caddr_t err_msg = NULL;
  odbc_string_to_any_dt (str, res, &err_msg);
  if (NULL != err_msg)
    {
      caddr_t err = srv_make_new_error ("22007", "DT006", "Cannot convert %s to datetime : %s", str, err_msg);
      dk_free_box (err_msg);
      dk_free_box (res);
      sqlr_resignal (err);
    }
  return res;
}


caddr_t
string_to_time_dt_box (char * str)
{
  caddr_t res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  caddr_t err_msg = NULL;
  odbc_string_to_time_dt (str, res, &err_msg);
  if (NULL != err_msg)
    {
      caddr_t err = srv_make_new_error ("22007", "DT011", "Cannot convert %s to time : %s", str, err_msg);
      dk_free_box (err_msg);
      dk_free_box (res);
      sqlr_resignal (err);
    }
  return res;
}


caddr_t
bif_string_date (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_or_wide_or_null_arg (qst, args, 0, "stringdate");
  caddr_t out;
  if (!str)
    sqlr_new_error ("22002", "DT007", "Nulls not allowed as parameters to stringdate");
  if (DV_WIDESTRINGP (str))
    {
      char szTemp[100];
      szTemp[0] = 0;
      box_wide_string_as_narrow (str, szTemp, 0, QST_CHARSET (qst));
      out = string_to_dt_box (szTemp);
    }
  else
    out = string_to_dt_box (str);
  DT_SET_DT_TYPE (out, DT_TYPE_DATE);
  return out;
}


caddr_t
bif_string_timestamp (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_or_wide_or_null_arg (qst, args, 0, "stringdate");
  caddr_t out;
  if (!str)
    sqlr_new_error ("22002", "DT007", "Nulls not allowed as parameters to stringdate");
  if (DV_WIDESTRINGP (str))
    {
      char szTemp[100];
      szTemp[0] = 0;
      box_wide_string_as_narrow (str, szTemp, 0, QST_CHARSET (qst));
      out = string_to_dt_box (szTemp);
    }
  else
    out = string_to_dt_box (str);
  return out;
}

caddr_t
bif_timestamp (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  lock_trx_t *lt = qi->qi_trx;
  if (!lt)
    sqlr_new_error ("25000", "DT008", "now/get_timestamp: No current txn for timestamp");
  return lt_timestamp_box (lt);
}


caddr_t
bif_string_time (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_or_wide_or_null_arg (qst, args, 0, "stringtime");
  caddr_t res;
  char temp[100];
  char *txt;
  caddr_t err_msg = NULL;
  if (!str)
    sqlr_new_error ("22002", "DT009", "Nulls not allowed as parameters to stringtime");
  if (DV_WIDESTRINGP (str))
    {
      box_wide_string_as_narrow (str, temp, sizeof (temp), QST_CHARSET (qst));
      txt = temp;
    }
  else
    txt = str;
  res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  odbc_string_to_time_dt (txt, res, &err_msg);
  if (NULL != err_msg)
    {
      caddr_t err = srv_make_new_error ("22007", "DT010", "Can't convert '%s' to time : %s", str, err_msg);
      dk_free_box (err_msg);
      dk_free_box (res);
      sqlr_resignal (err);
    }
  return res;
}


caddr_t
bif_curdatetime (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long fract = 0;
  caddr_t res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  dt_now (res);
  if (args && BOX_ELEMENTS (args) > 0)
    {
      fract = (long) bif_long_arg (qst, args, 0, "curdatetime");
      DT_SET_FRACTION (res, fract);
    }
  return res;
}

caddr_t
bif_curdatetime_tz (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long fract = 0;
  caddr_t res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  dt_now_tz (res);
  if (args && BOX_ELEMENTS (args) > 0)
    {
      fract = (long) bif_long_arg (qst, args, 0, "curdatetime_tz");
      DT_SET_FRACTION (res, fract);
    }
  return res;
}

caddr_t
bif_curdatetimeoffset (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long fract = 0;
  caddr_t res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  dt_now_GMT (res);
  if (args && BOX_ELEMENTS (args) > 0)
    {
      fract = (long) bif_long_arg (qst, args, 0, "curdatetimeoffset");
      DT_SET_FRACTION (res, fract);
    }
  DT_SET_TZL (res, 0);
  DT_SET_TZ (res, dt_local_tz_for_logs);
  return res;
}

caddr_t
bif_curutcdatetime (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long fract = 0;
  caddr_t res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  dt_now_GMT (res);
  if (args && BOX_ELEMENTS (args) > 0)
    {
      fract = (long) bif_long_arg (qst, args, 0, "curutcdatetime");
      DT_SET_FRACTION (res, fract);
    }
  return res;
}

caddr_t
bif_curdate (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  dt_now (res);
  dt_date_round (res);
  return res;
}


caddr_t
bif_curtime (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long fract = 0;
  caddr_t res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  dt_now (res);
  if (args && BOX_ELEMENTS (args) > 0)
    {
      fract = (long) bif_long_arg (qst, args, 0, "curtime");
      DT_SET_FRACTION (res, fract);
    }
  dt_make_day_zero (res);
  return res;
}

caddr_t
arithm_dt_add_num (ccaddr_t box1, ccaddr_t box2, int subtraction, caddr_t *err_ret)
{
  int dt_type = DT_DT_TYPE (box1);
  dtp_t dtp2 = DV_TYPE_OF (box2);
  boxint whole_seconds = 0;
  boxint nanoseconds = 0;
  TIMESTAMP_STRUCT ts;
  caddr_t res;
  switch (dtp2)
    {
    case DV_LONG_INT:
      whole_seconds = unbox (box2);
      break;
    case DV_DOUBLE_FLOAT:
      {
        double n = unbox_double (box2);
        double rest;
        whole_seconds = (n >= 0.0) ? floor(n + 0.5) : ceil(n - 0.5);
        rest = n - whole_seconds;
        if (abs(rest/n) > (3 * DBL_EPSILON))
          nanoseconds = (n - whole_seconds) * 1000000000L;
        break;
      }
    case DV_NUMERIC:
      {
        numeric_t n = (numeric_t)box2;
        if (NUMERIC_STS_SUCCESS != numeric_to_int64 (n, &whole_seconds))
          {
            err_ret[0] = srv_make_new_error ("22003", "SR087", "Wrong arguments for datetime arithmetic: decimal is out of range.");
            return NULL;
          }
        if (n->n_scale > 0)
          {
            char *nptr = n->n_value + n->n_len;
            int ctr;
            int mult = 1;
            for (ctr = 9; ctr > n->n_scale; ctr--) mult *= 10;
            while (ctr--)
              {
                nanoseconds += mult * nptr[ctr];
                mult *= 10;
              }
          }
        break;
      }
    default:
      return NULL;
    }
  DT_AUDIT_FIELDS (dt);
  dt_to_GMTimestamp_struct (box1, &ts);
  ts_add (&ts, (subtraction ? -whole_seconds : whole_seconds), "second");
  if (nanoseconds)
    ts_add (&ts, (subtraction ? -nanoseconds : nanoseconds), "nanosecond");
  res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  GMTimestamp_struct_to_dt (&ts, res);
  DT_SET_TZ (res, DT_TZ (box1));
  DT_SET_TZL (res, DT_TZL (box1));
  if ((DT_TYPE_DATE == dt_type) && (0 == (((whole_seconds * 1000000000L) + nanoseconds) % (SPERDAY * 1000000000L))))
    DT_SET_DT_TYPE (res, dt_type);
  DT_AUDIT_FIELDS (dt);
  return res;
}

caddr_t
arithm_dt_add (ccaddr_t box1, ccaddr_t box2, caddr_t *err_ret)
{
  dtp_t dtp1 = DV_TYPE_OF (box1), dtp2 = DV_TYPE_OF (box2);
  if ((DV_DATETIME == dtp1) && ((DV_LONG_INT == dtp2) || (DV_DOUBLE_FLOAT == dtp2) || (DV_NUMERIC == dtp2)))
    {
      caddr_t res = arithm_dt_add_num (box1, box2, 0, err_ret);
      if (NULL != err_ret)
        return res;
      if (NULL == res)
        goto generic_err;
      return res;
    }
  if ((DV_DATETIME == dtp2) && ((DV_LONG_INT == dtp1) || (DV_DOUBLE_FLOAT == dtp1) || (DV_NUMERIC == dtp1)))
    {
      caddr_t res = arithm_dt_add_num (box2, box1, 0, err_ret);
      if (NULL != err_ret)
        return res;
      if (NULL == res)
        goto generic_err;
      return res;
    }
generic_err:
  err_ret[0] = srv_make_new_error ("22003", "SR087", "Wrong arguments for datetime arithmetic, can not add values of type %d (%s) and type %d (%s).",
    dtp1, dv_type_title (dtp1), dtp2, dv_type_title (dtp2) );
  return NULL;
}

caddr_t
arithm_dt_subtract (ccaddr_t box1, ccaddr_t box2, caddr_t *err_ret)
{
  dtp_t dtp1 = DV_TYPE_OF (box1), dtp2 = DV_TYPE_OF (box2);
  if ((DV_DATETIME == dtp1) && (DV_DATETIME == dtp2))
    {
      boxint s1 = DT_CAST_TO_TOTAL_SECONDS(box1);
      boxint s2 = DT_CAST_TO_TOTAL_SECONDS(box2);
      int frac1 = DT_FRACTION(box1);
      int frac2 = DT_FRACTION(box2);
      if (frac1 == frac2)
        return box_num (s1 - s2);
      else
        {
          numeric_t res = numeric_allocate ();
          numeric_from_int64 (res, ((s1 - s2) * 1000000000L) + (frac1 - frac2));
          res->n_len -= 9;
          res->n_scale += 9;
          return (caddr_t)res;
        }
    }
  if ((DV_DATETIME == dtp1) && ((DV_LONG_INT == dtp2) || (DV_DOUBLE_FLOAT == dtp2) || (DV_NUMERIC == dtp2)))
    {
      caddr_t res = arithm_dt_add_num (box1, box2, 1, err_ret);
      if (NULL != err_ret)
        return res;
      if (NULL == res)
        goto generic_err;
      return res;
    }
generic_err:
  err_ret[0] = srv_make_new_error ("22003", "SR087", "Wrong arguments for datetime arithmetic, can not subtract value of type %d (%s) from value type %d (%s).",
    dtp2, dv_type_title (dtp2), dtp1, dv_type_title (dtp1) );
  return NULL;
}

void
bif_date_init ()
{
  bif_define_ex ("dayname"			, bif_dayname				, BMD_RET_TYPE, &bt_varchar	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("monthname"			, bif_monthname				, BMD_RET_TYPE, &bt_varchar	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("dayofmonth"	, bif_day		,BMD_ALIAS, "rdf_day_impl"	, BMD_RET_TYPE, &bt_integer	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("dayofweek"			, bif_dayofweek				, BMD_RET_TYPE, &bt_integer	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("dayofyear"			, bif_dayofyear				, BMD_RET_TYPE, &bt_integer	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("quarter"			, bif_quarter				, BMD_RET_TYPE, &bt_integer	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("month"	, bif_month		, BMD_ALIAS, "rdf_month_impl"	, BMD_RET_TYPE, &bt_integer	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("year"		, bif_year		, BMD_ALIAS, "rdf_year_impl"	, BMD_RET_TYPE, &bt_integer	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("hour"		, bif_hour		, BMD_ALIAS, "rdf_hours_impl"	, BMD_RET_TYPE, &bt_integer	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("minute"	, bif_minute		, BMD_ALIAS, "rdf_minutes_impl"	, BMD_RET_TYPE, &bt_integer	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("week"				, bif_week				, BMD_RET_TYPE, &bt_integer	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("second"			, bif_second				, BMD_RET_TYPE, &bt_integer	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("is_timezoneless"		, bif_is_timezoneless			, BMD_RET_TYPE, &bt_integer	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("timezone"			, bif_timezone				, BMD_RET_TYPE, &bt_integer	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex("adjust_timezone"		, bif_adjust_timezone			, BMD_RET_TYPE, &bt_datetime	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("forget_timezone"		, bif_forget_timezone			, BMD_RET_TYPE, &bt_datetime	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("nasa_tjd_number"		, bif_nasa_tjd_number			, BMD_RET_TYPE, &bt_integer	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("nasa_tjd_fraction"		, bif_nasa_tjd_fraction			, BMD_RET_TYPE, &bt_double	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("merge_nasa_tjd_to_datetime"	, bif_merge_nasa_tjd_to_datetime	, BMD_RET_TYPE, &bt_datetime	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("now"				, bif_timestamp
						, BMD_ALIAS, "getdate"
						, BMD_ALIAS, "rdf_now_impl"
						, BMD_ALIAS, "get_timestamp"
						, BMD_ALIAS, "current_timestamp" 	, BMD_RET_TYPE, &bt_timestamp	, /*BMD_IS_PURE,*/ BMD_DONE);	/* This is standard name */
  bif_define_ex ("curdate"			, bif_curdate
						, BMD_ALIAS, "current_date"		, BMD_RET_TYPE, &bt_date	, /*BMD_IS_PURE, */ BMD_DONE);	/* This is standard fun. */
  bif_define_ex ("curtime"			, bif_curtime
						, BMD_ALIAS, "current_time"		, BMD_RET_TYPE, &bt_time	, /*BMD_IS_PURE,*/ BMD_DONE);	/* This is standard fun. */
  bif_define_ex ("curdatetime"			, bif_curdatetime
						, BMD_ALIAS, "sysdatetime"		, BMD_RET_TYPE, &bt_timestamp	, /*BMD_IS_PURE,*/ BMD_DONE);	/* curdatetime() is our own, sysdatetime() is MS SQL */
  bif_define_ex ("curdatetime_tz"		, bif_curdatetime_tz , BMD_RET_TYPE, &bt_timestamp	, /*BMD_IS_PURE,*/ BMD_DONE);
  bif_define_ex ("curdatetimeoffset"			, bif_curdatetimeoffset
						, BMD_ALIAS, "sysdatetimeoffset"	, BMD_RET_TYPE, &bt_timestamp	, /*BMD_IS_PURE,*/ BMD_DONE);	/* curdatetimeoffset() is our own, sysdatetimeoffset() is MS SQL */
  bif_define_ex ("curutcdatetime"			, bif_curutcdatetime
						, BMD_ALIAS, "sysutcdatetime"		, BMD_RET_TYPE, &bt_timestamp	, /*BMD_IS_PURE,*/ BMD_DONE);	/* curutcdatetime() is our own, sysutcdatetime() is MS SQL */
  bif_define_ex ("datestring"			, bif_date_string			, BMD_RET_TYPE, &bt_varchar	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("datestring_GMT"		, bif_date_string_GMT			, BMD_RET_TYPE, &bt_varchar	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("stringdate"	, bif_string_timestamp	, BMD_ALIAS, "ts"		, BMD_RET_TYPE, &bt_datetime	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("d"				, bif_string_date			, BMD_RET_TYPE, &bt_date	, BMD_IS_PURE, BMD_DONE);	/* Two aliases for ODBC */
  bif_define_ex ("stringtime"	, bif_string_time	, BMD_ALIAS, "t"		, BMD_RET_TYPE, &bt_time	, BMD_IS_PURE, BMD_DONE);	/* New one. */
  bif_define_ex ("dateadd"			, bif_dateadd				, BMD_RET_TYPE, &bt_timestamp	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("datediff"			, bif_datediff				, BMD_RET_TYPE, &bt_integer	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("timestampadd"			, bif_timestampadd			, BMD_RET_TYPE, &bt_timestamp	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("timestampdiff"		, bif_timestampdiff			, BMD_RET_TYPE, &bt_integer	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("dt_set_tz"			, bif_dt_set_tz				, BMD_RET_TYPE, &bt_timestamp	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("__extract"			, bif_extract				, BMD_RET_TYPE, &bt_integer	, BMD_IS_PURE, BMD_DONE);
  dt_init ();
}
