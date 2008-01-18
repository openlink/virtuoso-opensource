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

#define KUBL_ILLEGAL_DATE_VALUE (0)	/* Added by AK 15-JAN-1997. */


caddr_t
bif_date_arg (caddr_t * qst, state_slot_t ** args, int nth, char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp != DV_DATETIME && dtp != DV_BIN)
    sqlr_new_error ("22007", "DT001",
	"Function %s needs a datetime, date or time as argument %d, not an arg of type %s (%d)",
	func, nth + 1, dv_type_title (dtp), dtp);
  return arg;
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


#define DT_PART(part) \
caddr_t \
bif_##part (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args) \
{ \
  caddr_t dt = bif_date_arg (qst, args, 0, #part); \
  TIMESTAMP_STRUCT ts; \
  dt_to_timestamp_struct (dt, &ts); \
  return box_num (ts.part); \
}


DT_PART (year)
DT_PART (month)
DT_PART (day)
DT_PART (hour)
DT_PART (minute)
DT_PART (second)


caddr_t
bif_timezone (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_date_arg (qst, args, 0, "timezone");
  return box_num (DT_TZ (arg));
}


caddr_t
bif_date_add (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t res;
  caddr_t part = bif_string_arg (qst, args, 0, "dateadd");
  int n = (int) bif_long_arg (qst, args, 1, "dateadd");
  caddr_t dt = bif_date_arg (qst, args, 2, "dateadd");
  TIMESTAMP_STRUCT ts;
  dt_to_timestamp_struct (dt, &ts);
  ts_add (&ts, n, part);
  res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  timestamp_struct_to_dt (&ts, res);
  return res;
}


caddr_t
bif_date_diff (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t unit = bif_string_arg (qst, args, 0, "datediff");
  caddr_t dt1 = bif_date_arg (qst, args, 1, "datediff");
  caddr_t dt2 = bif_date_arg (qst, args, 2, "datediff");
  TIMESTAMP_STRUCT ts1;
  TIMESTAMP_STRUCT ts2;
  /* BELOW OVERFLOWS on 32 bit long.  Numbers used for computing difference,
   * hence this works when difference below 2**21 = 34 years */
  long s1 = (long)DT_DAY (dt1) * 24 * 60 * 60 + DT_HOUR (dt1) * 60 * 60 + DT_MINUTE (dt1) * 60 + DT_SECOND (dt1);
  long s2 = (long)DT_DAY (dt2) * 24 * 60 * 60 + DT_HOUR (dt2) * 60 * 60 + DT_MINUTE (dt2) * 60 + DT_SECOND (dt2);

  if (0 == stricmp (unit, "day"))
    return box_num ((boxint)DT_DAY (dt2) - (boxint)DT_DAY (dt1));

  if (0 == stricmp (unit, "hour"))
    return box_num ((s2 - s1) / (60 * 60));

  if (0 == stricmp (unit, "minute"))
    return box_num ((s2 - s1) / 60);

  if (0 == stricmp (unit, "second"))
    return box_num (s2 - s1);

  dt_to_timestamp_struct (dt2, &ts2);
  dt_to_timestamp_struct (dt1, &ts1);

  if (0 == stricmp (unit, "month"))
    return box_num ((boxint)(ts2.year * 12 + ts2.month) - (boxint)(ts1.year * 12 + ts1.month));

  if (0 == stricmp (unit, "year"))
    return box_num ((boxint)ts2.year - (boxint)ts1.year);

  if (0 == stricmp (unit, "millisecond"))
    return box_num ((s2 - s1) * 1000 + (ts2.fraction / 1000 - ts1.fraction / 1000));

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
  TIMESTAMP_STRUCT ts;
  dt_to_timestamp_struct (dt, &ts);
  ts_add (&ts, n, interval_odbc_to_text (part, "timestampadd"));
  res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  timestamp_struct_to_dt (&ts, res);
  return res;
}


caddr_t
bif_timestampdiff (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong long_unit = bif_long_arg (qst, args, 0, "timestampdiff");
  caddr_t dt1 = bif_date_arg (qst, args, 1, "timestampdiff");
  caddr_t dt2 = bif_date_arg (qst, args, 2, "timestampdiff");
  TIMESTAMP_STRUCT ts1;
  TIMESTAMP_STRUCT ts2;
  /* BELOW OVERFLOWS on 32 bit long.  Numbers used for computing difference,
   * hence this works when difference below 2**21 = 34 years */
  long s1 = (long)DT_DAY (dt1) * 24 * 60 * 60 + DT_HOUR (dt1) * 60 * 60 + DT_MINUTE (dt1) * 60 + DT_SECOND (dt1);
  long s2 = (long)DT_DAY (dt2) * 24 * 60 * 60 + DT_HOUR (dt2) * 60 * 60 + DT_MINUTE (dt2) * 60 + DT_SECOND (dt2);
  char *unit = interval_odbc_to_text (long_unit, "timestampdiff");

  if (0 == stricmp (unit, "day"))
    return box_num ((boxint)DT_DAY (dt2) - (boxint)DT_DAY (dt1));

  if (0 == stricmp (unit, "hour"))
    return box_num ((s2 - s1) / (60 * 60));

  if (0 == stricmp (unit, "minute"))
    return box_num ((s2 - s1) / 60);

  if (0 == stricmp (unit, "second"))
    return box_num (s2 - s1);

  dt_to_timestamp_struct (dt2, &ts2);
  dt_to_timestamp_struct (dt1, &ts1);

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
  long tz = (long) bif_long_arg (qst, args, 1, "dt_set_tz");
  caddr_t res = box_copy (arg);
  DT_SET_TZ (res, tz);
  return res;
}


caddr_t
string_to_dt_box (char * str)
{
  int rc;
  char temp[DT_LENGTH];
  char *res;
  const char *err_str = "";

  memset (temp, 0, sizeof (temp));
  rc = string_to_dt (str, temp, &err_str);
  if (rc == 0)
    {
      res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
      memcpy (res, temp, DT_LENGTH);
      return (res);
    }
  sqlr_new_error ("22007", "DT006", "Cannot convert %s to datetime : %s", str, err_str);
  return NULL;			/*dummy */
}


caddr_t
string_to_time_dt_box (char * str)
{
  int rc;
  char temp[DT_LENGTH];
  char *res;

  rc = string_to_time_dt (str, temp);
  if (rc == 0)
    {
      res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
      memcpy (res, temp, DT_LENGTH);
      return (res);
    }
  sqlr_new_error ("22007", "DT011", "Cannot convert %s to time", str);
  return NULL;			/*dummy */
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
  char cvt[DT_LENGTH];
  char temp[100];
  const char *err_str = "";
  if (!str)
    sqlr_new_error ("22002", "DT009", "Nulls not allowed as parameters to stringtime");
  if (DV_WIDESTRINGP (str))
    {
      snprintf (temp, sizeof (temp), "1999-1-1 ");
      box_wide_string_as_narrow (str, temp + 9, 91, QST_CHARSET (qst));
    }
  else
    snprintf (temp, sizeof (temp), "1999-1-1 %s", str);
  if (0 != string_to_dt (temp, cvt, &err_str))
    sqlr_new_error ("22007", "DT010", "Can't convert %s to time : %s", str, err_str);
  dt_make_day_zero (cvt);
  res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  memcpy (res, cvt, DT_LENGTH);
  return res;
}


caddr_t
bif_curdatetime (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long fract = 0;
  caddr_t res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  dt_now (res);
  if (args && BOX_ELEMENTS (args) > 0)
    fract = (long) bif_long_arg (qst, args, 0, "curdatetime");
  DT_SET_FRACTION (res, fract);
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
    fract = (long) bif_long_arg (qst, args, 0, "curtime");
  DT_SET_FRACTION (res, fract);
  dt_make_day_zero (res);
  return res;
}


void
bif_date_init ()
{
  bif_define_typed ("dayname", bif_dayname, &bt_varchar);
  bif_define_typed ("monthname", bif_monthname, &bt_varchar);
  bif_define_typed ("dayofmonth", bif_day, &bt_integer);
  bif_define_typed ("dayofweek", bif_dayofweek, &bt_integer);
  bif_define_typed ("dayofyear", bif_dayofyear, &bt_integer);
  bif_define_typed ("quarter", bif_quarter, &bt_integer);
  bif_define_typed ("week", bif_week, &bt_integer);
  bif_define_typed ("month", bif_month, &bt_integer);
  bif_define_typed ("year", bif_year, &bt_integer);
  bif_define_typed ("hour", bif_hour, &bt_integer);
  bif_define_typed ("minute", bif_minute, &bt_integer);
  bif_define_typed ("second", bif_second, &bt_integer);
  bif_define_typed ("timezone", bif_timezone, &bt_integer);

  bif_define_typed ("now", bif_timestamp, &bt_timestamp);	/* This is standard name */
  bif_define_typed ("getdate", bif_timestamp, &bt_datetime);	/* This is standard name? */
  bif_define_typed ("curdate", bif_curdate, &bt_date);	/* This is standard fun. */
  bif_define_typed ("curtime", bif_curtime, &bt_time);	/* This is standard fun. */
  bif_define_typed ("curdatetime", bif_curdatetime, &bt_timestamp);	/* This is our own. */
  bif_define_typed ("datestring", bif_date_string, &bt_varchar);
  bif_define_typed ("datestring_GMT", bif_date_string_GMT, &bt_varchar);
  bif_define_typed ("stringdate", bif_string_timestamp, &bt_datetime);
  bif_define_typed ("d", bif_string_date, &bt_date);	/* Two aliases for ODBC */
  bif_define_typed ("ts", bif_string_timestamp, &bt_timestamp);	/* brace literals */
  bif_define_typed ("stringtime", bif_string_time, &bt_time);	/* New one. */
  bif_define_typed ("t", bif_string_time, &bt_time);	/* An alias for ODBC */

  bif_define_typed ("get_timestamp", bif_timestamp, &bt_timestamp);
  bif_define_typed ("dateadd", bif_date_add, &bt_timestamp);
  bif_define_typed ("datediff", bif_date_diff, &bt_integer);
  bif_define_typed ("timestampadd", bif_timestampadd, &bt_timestamp);
  bif_define_typed ("timestampdiff", bif_timestampdiff, &bt_integer);
  bif_define_typed ("dt_set_tz", bif_dt_set_tz, &bt_timestamp);
  bif_define_typed ("__extract", bif_extract, &bt_integer);
  dt_init ();
}
