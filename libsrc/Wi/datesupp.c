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

#include "CLI.h"
#include "util/strfuns.h"

/*
 *  Important preprocessor symbols for the internal ranges
 */
#define  DAY_LAST    365	/* Last day in a NON leap year */
#define  DAY_MIN     1		/* Minimum day of week/month/year */
#define  DAY_MAX     7		/* Maximum day/amount of days of week */
#define  MONTH_LAST  31		/* Highest day number in a month */
#define  MONTH_MIN   1		/* Minimum month of year */
#define  MONTH_MAX   12		/* Maximum month of year */
#define  YEAR_MIN    1		/* Minimum year able to compute */
#define  YEAR_MAX    9999	/* Maximum year able to compute */


/*
 *  The Gregorian Reformation date
 */
#define GREG_YEAR	1582
#define GREG_MONTH	10
#define GREG_FIRST_DAY	5
#define GREG_LAST_DAY	14
#define GREG_JDAYS	577737L	/* date2num (GREG_YEAR, GREG_MONTH,
				   GREG_FIRST_DAY - 1) */


/* Number of days in months */
static const int days_in_month[] =
{
  31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
};

/* Number of past days of month */
static const int cumdays_in_month[] =
{
  0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334
};


/*
 *  Computes the number of days in February, respecting the
 *  Gregorian Reformation period
 */
int
days_in_february (const int year)
{
  int day;

  if ((year > GREG_YEAR)
      || ((year == GREG_YEAR)
	  && (GREG_MONTH == 1
	      || ((GREG_MONTH == 2)
		  && (GREG_LAST_DAY >= 28)))))
    {
      day = (year & 3) ? 28 : ((!(year % 100) && (year % 400)) ? 28 : 29);
    }
  else
    {
      day = (year & 3) ? 28 : 29;
    }

  /*
   *  Exception, the year 4 AD was historically NO leap year!
   */
  if (year == 4)
    day--;

  return day;
}


static void
dt_day_ck (int day, int month, int year, int *err, const char **err_str)
{
  if (month > 0 && month < 13)
    {
      if (month == 2 && (day < 0 || day > days_in_february (year)))
	{
	  *err_str = "Date not valid for the month and year specified";
	  *err = 1;
	}
      else if (month != 2 && (day < 0 || day > days_in_month[month - 1]))
	{
	  *err_str = "Date not valid for the month specified";
	  *err = 1;
	}
    }
  else
    {
      *err_str = "Date not valid : month not valid";
      *err = 1;
    }
}


/*
 *  Converts a given number of days of a year to a standard date
 *
 *  returns:
 *    1 in case the `day_of_year' number is valid;
 *    0 otherwise
 */
static int
yearday2date (int yday, const int is_leap_year, int *month, int *day)
{
  int i;
  int decrement_date;

  if (yday > DAY_LAST + is_leap_year || yday < DAY_MIN)
    return 0;

  decrement_date = (int) (is_leap_year && (yday > 59));
  if (decrement_date)
    yday--;
  for (i = MONTH_MIN; i < MONTH_MAX; i++)
    {
      yday -= days_in_month[i - 1];
      if (yday <= 0)
	{
	  yday += days_in_month[i - 1];
	  break;
	}
    }
  *month = i;
  *day = yday;
  if (decrement_date && *month == 2 && *day == 28)
    (*day)++;

  return 1;
}


/*
 *  Computes the absolute number of days of the given date since 0001/01/01,
 *  respecting the missing period of the Gregorian Reformation
 */
uint32
date2num (const int year, const int month, const int day)
{
  uint32 julian_days;

  julian_days = (uint32) ((year - 1) * (uint32) (DAY_LAST) + ((year - 1) >> 2));

  if (year > GREG_YEAR
      || ((year == GREG_YEAR)
	  && (month > GREG_MONTH
	      || ((month == GREG_MONTH)
		  && (day > GREG_LAST_DAY)))))
    {
      julian_days -= (uint32) (GREG_LAST_DAY - GREG_FIRST_DAY + 1);
    }
  if (year > GREG_YEAR)
    {
      julian_days += (((year - 1) / 400) - (GREG_YEAR / 400));
      julian_days -= (((year - 1) / 100) - (GREG_YEAR / 100));
      if (!(GREG_YEAR % 100) && (GREG_YEAR % 400))
	julian_days--;
    }
  julian_days += (uint32) cumdays_in_month[month - 1];
  julian_days += day;
  if (days_in_february (year) == 29 && month > 2)
    julian_days++;

  return julian_days;
}


/*
 *  Converts a delivered absolute number of days `julian_days' to
 *  a standard date (since 0001/01/01),
 *  respecting the missing period of the Gregorian Reformation
 */
void
num2date (uint32 julian_days, int *year, int *month, int *day)
{
  double x;
  int i;

  if (julian_days > GREG_JDAYS)
    julian_days += (uint32) (GREG_LAST_DAY - GREG_FIRST_DAY + 1);
  x = (double) julian_days / (DAY_LAST + 0.25);
  i = (int) x;
  if ((double) i != x)
    *year = i + 1;
  else
    {
      *year = i;
      i--;
    }
  if (julian_days > GREG_JDAYS)
    {
      /*
       *  Correction for Gregorian years
       */
      julian_days -= (uint32) ((*year / 400) - (GREG_YEAR / 400));
      julian_days += (uint32) ((*year / 100) - (GREG_YEAR / 100));
      x = (double) julian_days / (DAY_LAST + 0.25);
      i = (int) x;
      if ((double) i != x)
	*year = i + 1;
      else
	{
	  *year = i;
	  i--;
	}
      if ((*year % 400)
	  && !(*year % 100))
	julian_days--;
    }
  i = (int) (julian_days - (uint32) (i * (DAY_LAST + 0.25)));
  /*
   *  Correction for Gregorian centuries
   */
  if ((*year > GREG_YEAR)
      && (*year % 400)
      && !(*year % 100)
      && (i < ((*year / 100) - (GREG_YEAR / 100)) - ((*year / 400) - (GREG_YEAR / 400))))
    i++;
  yearday2date (i, (days_in_february (*year) == 29), month, day);
}


/*
 *  Checks whether a delivered date is valid
 */
int
ymd_valid_p (const int year, const int month, const int day)
{
  if (day < 0 ||
      month < MONTH_MIN ||
      month > MONTH_MAX ||
      year < YEAR_MIN ||
      year > YEAR_MAX ||
      (month != 2 && day > days_in_month[month - 1]) ||
      (month == 2 && day > days_in_february (year)))
    {
      return 0;
    }

  return 1;
}


/*
 *  Computes the weekday of a Gregorian/Julian calendar date
 *    (month must be 1...12) and returns 1...7 (1==mo, 2==tu...7==su).
 */
int
date2weekday (const int year, const int month, const int day)
{
  uint32 julian_days = date2num (year, month, day) % DAY_MAX;

  return ((julian_days > 2) ? (int) julian_days - 2 : (int) julian_days + 5);
}


int dt_local_tz;		/* minutes from GMT */

void
dt_now (caddr_t dt)
{
  static time_t last_time;
  static long last_frac;
  long day;
  time_t tim = time (NULL);
  struct tm tm;
#if defined(HAVE_GMTIME_R)
  struct tm result;

  tm = *gmtime_r (&tim, &result);
#else  
  tm = *gmtime (&tim);
#endif  
  day = date2num (tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday);
  DT_SET_DAY (dt, day);
  DT_SET_HOUR (dt, tm.tm_hour);
  DT_SET_MINUTE (dt, tm.tm_min);
  DT_SET_SECOND (dt, tm.tm_sec);
  if (tim == last_time)
    {
      last_frac++;
      DT_SET_FRACTION (dt, (last_frac * 1000));
    }
  else
    {
      last_frac = 0;
      last_time = tim;
      DT_SET_FRACTION (dt, 0);
    }
  DT_SET_TZ (dt, dt_local_tz);
  DT_SET_DT_TYPE (dt, DT_TYPE_DATETIME);
}


void
time_t_to_dt (time_t tim, long fraction, char *dt)
{
  long day;
#if defined(HAVE_GMTIME_R)
  struct tm result;
  struct tm tm = *gmtime_r (&tim, &result);
#else  
  struct tm tm = *gmtime (&tim);
#endif
  day = date2num (tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday);
  DT_SET_DAY (dt, day);
  DT_SET_HOUR (dt, tm.tm_hour);
  DT_SET_MINUTE (dt, tm.tm_min);
  DT_SET_SECOND (dt, tm.tm_sec);
  DT_SET_FRACTION (dt, fraction);
  DT_SET_TZ (dt, dt_local_tz);
  DT_SET_DT_TYPE (dt, DT_TYPE_DATETIME);
}

#if defined (WIN32) && (defined (_AMD64_) || defined (_FORCE_WIN32_FILE_TIME))
int
file_mtime_to_dt (const char *name, char *dt)
{
  WIN32_FIND_DATA fdt;
  HANDLE hSearch;
  SYSTEMTIME stUTC;
  int time_set = 0;

  hSearch = FindFirstFile (name, &fdt);
  if (hSearch != INVALID_HANDLE_VALUE)
    {
      if (FileTimeToSystemTime (&fdt.ftLastWriteTime, &stUTC))
	{
	  long day;
	  day = date2num (stUTC.wYear, stUTC.wMonth, stUTC.wDay);
	  DT_SET_DAY (dt, day);
	  DT_SET_HOUR (dt, stUTC.wHour);
	  DT_SET_MINUTE (dt, stUTC.wMinute);
	  DT_SET_SECOND (dt, stUTC.wSecond);
	  DT_SET_FRACTION (dt, stUTC.wMilliseconds * 1000);
	  DT_SET_TZ (dt, dt_local_tz);
	  DT_SET_DT_TYPE (dt, DT_TYPE_DATETIME);
	  time_set = 1;
	}
      FindClose (hSearch);
    }
  return time_set;
}
#endif

#define SPERDAY (24*60*60)

void
sec2time (int sec, int *day, int *hour, int *min, int *tsec)
{
  *day = sec / SPERDAY;
  *hour = (sec - (*day * SPERDAY)) / (60 * 60);
  *min = (sec - (*day * SPERDAY) - (*hour * 60 * 60)) / 60;
  *tsec = sec % 60;
}

int
time2sec (int day, int hour, int min, int sec)
{
  return (day * SPERDAY + hour * 60 * 60 + min * 60 + sec);
}


void
ts_add (TIMESTAMP_STRUCT * ts, int n, const char *unit)
{
  int dummy;
  int32 day, sec;
  int oyear, omonth, oday, ohour, ominute, osecond;

  day = date2num (ts->year, ts->month, ts->day);
  sec = time2sec (0, ts->hour, ts->minute, ts->second);
  if (0 == stricmp (unit, "year"))
    {
      ts->year += n;
      return;
    }
  if (0 == stricmp (unit, "month"))
    {
      int m = (ts->month - 1) + n;
      if (m >= 0)
	{
	  ts->year += m / 12;
	  ts->month = 1 + (m % 12);
	}
      else
	{
	  ts->year -= 1 - ((m + 1) / 12);
	  ts->month = 12 + ((m + 1) % 12);
	}
      return;
    }

  if (0 == stricmp (unit, "second"))
    sec += n;
  else if (0 == stricmp (unit, "minute"))
    sec += 60 * n;
  else if (0 == stricmp (unit, "hour"))
    sec += 60 * 60 * n;
  else if (0 == stricmp (unit, "day"))
    day += n;

  if (sec < 0)
    {
      day = day - (1 + ((-sec) / SPERDAY));

      sec = sec % SPERDAY;

      if (sec == 0)
	day++;

      sec = SPERDAY + sec;
    }
  else
    {
      day = day + sec / SPERDAY;
      sec = sec % SPERDAY;
    }
  num2date (day, &oyear, &omonth, &oday);
  sec2time (sec, &dummy, &ohour, &ominute, &osecond);
  ts->year = oyear;
  ts->month = omonth;
  ts->day = oday;
  ts->hour = ohour;
  ts->minute = ominute;
  ts->second = osecond;
}


void
dt_to_timestamp_struct (caddr_t dt, TIMESTAMP_STRUCT * ts)
{
  int year, month, day;
  num2date (DT_DAY (dt), &year, &month, &day);
  ts->year = year;
  ts->month = month;
  ts->day = day;
  ts->hour = DT_HOUR (dt);
  ts->minute = DT_MINUTE (dt);
  ts->second = DT_SECOND (dt);
  ts->fraction = DT_FRACTION (dt);
  ts_add (ts, DT_TZ (dt), "minute");
}


int dt_validate (caddr_t dt)
{
  if (!IS_BOX_POINTER(dt))
    return 1;
  if (DT_LENGTH != box_length (dt))
    return 1;
  if ((23 < (unsigned)(DT_HOUR(dt))) || (59 < (unsigned)(DT_MINUTE(dt))) || (60 < (unsigned)(DT_SECOND(dt))))
    return 1;
  return 0;
}

void
timestamp_struct_to_dt (TIMESTAMP_STRUCT * ts_in, char *dt)
{
  uint32 day;
  TIMESTAMP_STRUCT ts_tmp;
  TIMESTAMP_STRUCT *ts = &ts_tmp;
  ts_tmp = *ts_in;
  ts_add (ts, -dt_local_tz, "minute");
  day = date2num (ts->year, ts->month, ts->day);
  DT_SET_DAY (dt, day);
  DT_SET_HOUR (dt, ts->hour);
  DT_SET_MINUTE (dt, ts->minute);
  DT_SET_SECOND (dt, ts->second);
  DT_SET_FRACTION (dt, ts->fraction);
  DT_SET_TZ (dt, dt_local_tz);
  DT_SET_DT_TYPE (dt, DT_TYPE_DATETIME);
}


void
dt_to_date_struct (char *dt, DATE_STRUCT * ots)
{
  TIMESTAMP_STRUCT ts;
  dt_to_timestamp_struct (dt, &ts);
  ots->year = ts.year;
  ots->month = ts.month;
  ots->day = ts.day;
}


void
date_struct_to_dt (DATE_STRUCT * ds, char *dt)
{
  TIMESTAMP_STRUCT ts;

  memset (&ts, 0, sizeof (ts));
  ts.year = ds->year;
  ts.month = ds->month;
  ts.day = ds->day;

  timestamp_struct_to_dt (&ts, dt);
  DT_SET_DT_TYPE (dt, DT_TYPE_DATE);
}


void
dt_to_time_struct (char *dt, TIME_STRUCT * ots)
{
  TIMESTAMP_STRUCT ts;
  dt_to_timestamp_struct (dt, &ts);
  ots->hour = ts.hour;
  ots->minute = ts.minute;
  ots->second = ts.second;
}


void
time_struct_to_dt (TIME_STRUCT * ts, char *dt)
{
   TIMESTAMP_STRUCT tss;
   memset (&tss, 0, sizeof (tss));
   tss.hour = ts->hour;
   tss.minute = ts->minute;
   tss.second = ts->second;
   timestamp_struct_to_dt (&tss, dt);
   DT_SET_DT_TYPE (dt, DT_TYPE_TIME);
}


void
dt_date_round (char *dt)
{
  TIMESTAMP_STRUCT ts;
  dt_to_timestamp_struct (dt, &ts);
  ts.hour = 0;
  ts.minute = 0;
  ts.second = 0;
  ts.fraction = 0;
  timestamp_struct_to_dt (&ts, dt);
  DT_SET_DT_TYPE (dt, DT_TYPE_DATE);
}

int isdts_mode = 1;

void
dt_init ()
{
  time_t lt, gt;
  struct tm ltm;
  struct tm gtm;
  time_t tim;
#if defined(HAVE_GMTIME_R)
  struct tm result;
#endif  

  tim = time (NULL);
  ltm = *localtime (&tim);
#if defined(HAVE_GMTIME_R)
  gtm = *gmtime_r (&tim, &result);
#else 
  gtm = *gmtime (&tim);
#endif  
  lt = mktime (&ltm);
  gt = mktime (&gtm);
  dt_local_tz = (int) (lt - gt) / 60;
  if (ltm.tm_isdst && isdts_mode)  /* Check daylight saving */
    dt_local_tz = dt_local_tz + 60;
}

long
dt_long_part_ck (char *str, long min, long max, int *err)
{
  long n;
  if (!str)
    n = 0;
  else
    {
      if (1 != sscanf (str, "%ld", &n))
	{
	  *err |= 1;
	  return 0;
	}
    }
  if (n < min || n > max)
    {
      *err |= 1;
      return 0;
    }
  return n;
}

int
dt_part_ck (char *str, int min, int max, int *err)
{
  int n;
  if (!str)
    n = 0;
  else
    {
      if (1 != sscanf (str, "%d", &n))
	{
	  *err |= 1;
	  return 0;
	}
    }
  if (n < min || n > max)
    {
      *err |= 1;
      return 0;
    }
  return n;
}

void
dt_to_string (char *dt, char *str, int len)
{
  int dt_type;
  TIMESTAMP_STRUCT ts;
  dt_to_timestamp_struct (dt, &ts);

  dt_type = DT_DT_TYPE (dt);
  switch (dt_type)
    {
      case DT_TYPE_DATE:
	  snprintf (str, len, "%04d-%02d-%02d",
	      ts.year, ts.month, ts.day);
	  break;
      case DT_TYPE_TIME:
	  snprintf (str, len, "%02d:%02d:%02d",
	      ts.hour, ts.minute, ts.second);
	  break;
      default:
	  snprintf (str, len, "%04d-%02d-%02d %02d:%02d:%02d.%06ld",
	      ts.year, ts.month, ts.day, ts.hour, ts.minute, ts.second, (long) ts.fraction);
    }
}

void
dt_to_iso8601_string (char *dt, char *str, int len)
{
  TIMESTAMP_STRUCT ts;
  int tz = DT_TZ (dt);
  int dt_type;
  dt_to_timestamp_struct (dt, &ts);

  dt_type = DT_DT_TYPE (dt);

  switch (dt_type)
    {
      case DT_TYPE_DATE:
	  snprintf (str, len, "%04d-%02d-%02d",
	      ts.year, ts.month, ts.day);
	  break;
      case DT_TYPE_TIME:
	    {
	      if (tz)
		snprintf (str, len, "%02d:%02d:%02d.%03d%+03d:%02d",
		    ts.hour, ts.minute, ts.second, (int)ts.fraction, tz / 60, abs (tz) % 60);
	      else
		snprintf (str, len, "%02d:%02d:%02d.%03dZ",
		    ts.hour, ts.minute, ts.second, (int)ts.fraction);
	    }
	  break;
      default:
	    {
	      if (tz)
		snprintf (str, len, "%04d-%02d-%02dT%02d:%02d:%02d.%03d%+03d:%02d",
		    ts.year, ts.month, ts.day, ts.hour, ts.minute, ts.second,
		    (int)ts.fraction, tz / 60, abs (tz) % 60);
	      else
		{
		  if (ts.fraction)
		    snprintf (str, len, "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ",
			ts.year, ts.month, ts.day, ts.hour, ts.minute, ts.second, (int)ts.fraction);
		  else
		    snprintf (str, len, "%04d-%02d-%02dT%02d:%02d:%02dZ",
			ts.year, ts.month, ts.day, ts.hour, ts.minute, ts.second);
		}
	    }
    }

}

void
dt_to_rfc1123_string (char *dt, char *str, int len)
{
  TIMESTAMP_STRUCT ts;
  char * wkday [] = {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"};
  char * monday [] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
  int tz = DT_TZ (dt);
  dt_to_timestamp_struct (dt, &ts);
  ts_add (&ts, -tz, "minute");

  /* Mon, 01 Feb 2000 00:00:00 GMT */
  snprintf (str, len, "%s, %02d %s %04d %02d:%02d:%02d GMT",
	   wkday [date2weekday (ts.year, ts.month, ts.day) - 1], ts.day, monday [ts.month - 1], ts.year, ts.hour, ts.minute, ts.second);
	   /*ts.year, ts.month, ts.day, ts.hour, ts.minute, ts.second, (long) ts.fraction);*/
}

void
dt_to_ms_string (char *dt, char *str, int len)
{
  TIMESTAMP_STRUCT ts;
  char * monday [] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
  dt_to_timestamp_struct (dt, &ts);

  /* 01-Feb-2000 00:00:00 */
  snprintf (str, len, "%02d-%s-%04d %02d:%02d:%02d",
	   ts.day, monday [ts.month - 1], ts.year, ts.hour, ts.minute, ts.second);
}

#define DT_SEP " -:./'TZ"

#define MATOI(str, err)  str == NULL ? (err |= 1, 0) : atoi (str)

int
string_to_dt (char *str, char *dt, const char **str_err)
{
  int err = 0;
  char *place = NULL;
  char *syear = NULL, *smonth = "1", *sday = "1", *shour = NULL, *sminute = NULL,
   *ssecond = NULL, *sfraction = NULL;
  TIMESTAMP_STRUCT ts;
  char tmp[31];
  int type = DT_TYPE_DATETIME;

  /* if(str==NULL || strlen(str)==0) return -1; */
  strncpy (tmp, str, sizeof (tmp)-1);
  tmp[30] = 0;

  if ((syear = strtok_r (tmp, DT_SEP, &place)) == NULL)
    {
      *str_err = "Missing date format or separator";
      return -1;
    }
  if (syear[0] == '{')
    {
      if (syear[1] == 'd')
	{
	  syear = strtok_r (NULL, DT_SEP, &place);
	  smonth = strtok_r (NULL, DT_SEP, &place);
	  sday = strtok_r (NULL, DT_SEP, &place);
	  type = DT_TYPE_DATE;
	}
      else if (syear[1] == 't')
	{
	  if (syear[2] == 's')
	    {
	      syear = strtok_r (NULL, DT_SEP, &place);
	      smonth = strtok_r (NULL, DT_SEP, &place);
	      sday = strtok_r (NULL, DT_SEP, &place);
	    }
	  else
	    {
	      syear = "1";
	      type = DT_TYPE_TIME;
	    }

	  shour = strtok_r (NULL, DT_SEP, &place);
	  sminute = strtok_r (NULL, DT_SEP, &place);
	  ssecond = strtok_r (NULL, DT_SEP, &place);
	  if ((sfraction = strtok_r (NULL, DT_SEP, &place)) == NULL)
	    {
	      *str_err = "Missing fraction or separator";
	      return -1;
	    }
	  if (sfraction[0] == '}')
	    sfraction = NULL;
	}
      else
	{
	  smonth = strtok_r (NULL, DT_SEP, &place);
	  sday = strtok_r (NULL, DT_SEP, &place);
	  shour = strtok_r (NULL, DT_SEP, &place);
	  sminute = strtok_r (NULL, DT_SEP, &place);
	  ssecond = strtok_r (NULL, DT_SEP, &place);
	  if ((sfraction = strtok_r (NULL, DT_SEP, &place)) == NULL)
	    {
	      *str_err = "Missing fraction or separator";
	      return -1;
	    }
	  if (sfraction[0] == '}')
	    sfraction = NULL;
	}
    }
  else
    {
      smonth = strtok_r (NULL, DT_SEP, &place);
      sday = strtok_r (NULL, DT_SEP, &place);
      shour = strtok_r (NULL, DT_SEP, &place);
      sminute = strtok_r (NULL, DT_SEP, &place);
      ssecond = strtok_r (NULL, DT_SEP, &place);
      sfraction = strtok_r (NULL, DT_SEP, &place);
    }

  ts.year = dt_part_ck (syear, 1, 10000, &err);
  if (err)
    {
      *str_err = "Year out of bounds";
      return -1;
    }
  if (ts.year < 13)
    {				/* imply US locale (m/d/y) whether the first element is a valid month */
      ts.month = ts.year;
      if (ts.month < 1 || ts.month > 12)
	{
	  ts.month = 0;
	  err = 1;
	  *str_err = "Month out of bounds";
	  goto finito;
	}
      ts.day = dt_part_ck (smonth, 1, 31, &err);
      if (err)
	{
	  *str_err = "Day out of bounds";
	  goto finito;
	}
      ts.year = dt_part_ck (sday, 1, 10000, &err);
      if (err)
	{
	  *str_err = "Year out of bounds";
	  goto finito;
	}
      ts.year += (ts.year < 1000) ? 1900 : 0;	/* as the US locale accepts 2 digit date */
    }
  else
    {				/* ODBC "locale" */
      ts.month = dt_part_ck (smonth, 1, 12, &err);
      if (err)
	{
	  *str_err = "Month out of bounds";
	  goto finito;
	}
      ts.day = dt_part_ck (sday, 1, 31, &err);
      if (err)
	{
	  *str_err = "Day out of bounds";
	  goto finito;
	}
    }
  dt_day_ck (ts.day, ts.month, ts.year, &err, str_err);
  if (err)
    {
      goto finito;
    }
  ts.hour = dt_part_ck (shour, 0, 23, &err);
  if (err)
    {
      *str_err = "Hour out of bounds";
      goto finito;
    }
  ts.minute = dt_part_ck (sminute, 0, 60, &err);
  if (err)
    {
      *str_err = "Minute out of bounds";
      goto finito;
    }
  ts.second = dt_part_ck (ssecond, 0, 60, &err);
  if (err)
    {
      *str_err = "Seconds out of bounds";
      goto finito;
    }
  ts.fraction = dt_long_part_ck (sfraction, 0, 999999999, &err);
  if (err)
    *str_err = "Fraction out of bounds";
finito:
  if (err)
    return -1;

  timestamp_struct_to_dt (&ts, dt);

  return 0;
}


int
string_to_time_dt (char *str, char *dt)
{
  int err = 0;
  char *place = NULL;
  char *syear = "1", *smonth = "1", *sday = "1", *shour = NULL, *sminute = NULL,
   *ssecond = NULL, *sfraction = NULL;
  TIMESTAMP_STRUCT ts;
  char tmp[30];

  /* if(str==NULL || strlen(str)==0) return -1; */
  strncpy (tmp, str, sizeof (tmp));

  if ((shour = strtok_r (tmp, DT_SEP, &place)) == NULL)
    return -1;
  if (shour[0] == '{')
    {
      if (shour[1] == 'd')
	{
	  syear = strtok_r (NULL, DT_SEP, &place);
	  smonth = strtok_r (NULL, DT_SEP, &place);
	  sday = strtok_r (NULL, DT_SEP, &place);
	}
      else if (shour[1] == 't')
	{
	  if (shour[2] == 's')
	    {
	      syear = strtok_r (NULL, DT_SEP, &place);
	      smonth = strtok_r (NULL, DT_SEP, &place);
	      sday = strtok_r (NULL, DT_SEP, &place);
	    }
	  else
	    syear = "1";
	  shour = strtok_r (NULL, DT_SEP, &place);
	  sminute = strtok_r (NULL, DT_SEP, &place);
	  ssecond = strtok_r (NULL, DT_SEP, &place);
	  if ((sfraction = strtok_r (NULL, DT_SEP, &place)) == NULL)
	    return -1;
	  if (sfraction[0] == '}')
	    sfraction = NULL;
	}
      else
	{
	  sminute = strtok_r (NULL, DT_SEP, &place);
	  ssecond = strtok_r (NULL, DT_SEP, &place);
	  if ((sfraction = strtok_r (NULL, DT_SEP, &place)) == NULL)
	    return -1;
	  if (sfraction[0] == '}')
	    sfraction = NULL;
	}
    }
  else
    {
      sminute = strtok_r (NULL, DT_SEP, &place);
      ssecond = strtok_r (NULL, DT_SEP, &place);
      sfraction = strtok_r (NULL, DT_SEP, &place);
    }

  ts.year = dt_part_ck (syear, 1, 10000, &err);
  if (ts.year < 13)
    {				/* imply US locale (m/d/y) whether the first element is a valid month */
      ts.month = ts.year;
      if (ts.month < 1 || ts.month > 12)
	{
	  ts.month = 0;
	  err = 1;
	}
      ts.day = dt_part_ck (smonth, 1, 31, &err);
      ts.year = dt_part_ck (sday, 1, 10000, &err);
      ts.year += (ts.year < 1000) ? 1900 : 0;	/* as the US locale accepts 2 digit date */
    }
  else
    {				/* ODBC "locale" */
      ts.month = dt_part_ck (smonth, 1, 12, &err);
      ts.day = dt_part_ck (sday, 1, 31, &err);
    }
  ts.hour = dt_part_ck (shour, 0, 23, &err);
  ts.minute = dt_part_ck (sminute, 0, 60, &err);
  ts.second = dt_part_ck (ssecond, 0, 60, &err);
  ts.fraction = dt_long_part_ck (sfraction, 0, 999999999, &err);
  if (err)
    return -1;

  timestamp_struct_to_dt (&ts, dt);
  dt_make_day_zero (dt);

  return 0;
}


int
iso8601_to_dt (char *str, char *dt, dtp_t dtp)
{
  int n_set;
  int year = 0, month = 0, date = 0, hour = 0, minute = 0, second = 0, frac = 0, tz_hour = 0, tz_minute = 0;
  char tmp[30];
  TIMESTAMP_STRUCT ts;

  if(str==NULL || strlen(str)==0) return -1;
  strncpy (tmp, str, sizeof (tmp));

  if (dtp == DV_DATETIME || dtp == DV_TIMESTAMP)
    {
      if (7 > (n_set = sscanf (tmp, "%4d-%2d-%2dT%2d:%2d:%2d.%3d%3d:%2d",
	    &year, &month, &date, &hour, &minute, &second, &frac, &tz_hour, &tz_minute)))
	{
	  if (6 > (n_set = sscanf (tmp, "%4d-%2d-%2dT%2d:%2d:%2d%3d:%2d",
		  &year, &month, &date, &hour, &minute, &second, &tz_hour, &tz_minute)))
	    {
	      if (6 > (n_set = sscanf (tmp, "%4d%2d%2dT%2d%2d%2d%3d%2d",
		      &year, &month, &date, &hour, &minute, &second, &tz_hour, &tz_minute)))
		{
		  if (6 > (n_set = sscanf (tmp, "%4d%2d%2dT%2d:%2d:%2d%3d:%2d",
			  &year, &month, &date, &hour, &minute, &second, &tz_hour, &tz_minute)))
		    return 0;
		}
	    }
	}
      if (n_set < 8)
	{
	  if (strchr (tmp, 'Z'))
	    {
	      tz_hour = 0; tz_minute = 0;
	    }
	  else
	    {
	      tz_hour = 0; tz_minute = dt_local_tz;
	    }
	}
    }
  else if (dtp == DV_DATE)
    {
      hour = minute = second = tz_minute = tz_hour = 0;
      if (3 > (n_set = sscanf (tmp, "%4d-%2d-%2d",
	    &year, &month, &date)))
	{
	  if (6 > (n_set = sscanf (tmp, "%4d%2d%2d",
		&year, &month, &date)))
	      return 0;
	}
    }
  else if (dtp == DV_TIME)
    {
      year = date = month = 0;
      if (4 > (n_set = sscanf (tmp, "%4d:%2d:%2d.%3d%2d:%2d",
	    &hour, &minute, &second, &frac, &tz_hour, &tz_minute)))
	{
	  if (3 > (n_set = sscanf (tmp, "%4d:%2d:%2d%2d:%2d",
		  &hour, &minute, &second, &tz_hour, &tz_minute)))
	    {
	      if (3 > (n_set = sscanf (tmp, "%4d%2d%2d%2d%2d",
		      &hour, &minute, &second, &tz_hour, &tz_minute)))
		return 0;
	    }
	}
      if (n_set < 6)
	{
	  if (strchr (tmp, 'Z'))
	    {
	      tz_hour = 0; tz_minute = 0;
	    }
	  else
	    {
	      tz_hour = 0; tz_minute = dt_local_tz;
	    }
	}
    }
  ts.year = year;
  ts.month = month;
  ts.day = date;
  ts.hour = hour;
  ts.minute = minute;
  ts.second = second;
  ts.fraction = frac;
  ts_add (&ts, dt_local_tz - (tz_hour * 60 + tz_minute), "minute");
  timestamp_struct_to_dt (&ts, dt);
  DT_SET_TZ (dt, (tz_hour * 60 + tz_minute));
  SET_DT_TYPE_BY_DTP (dt, dtp);
  return 1;
}


int
http_date_to_dt (const char *http_date, char *dt)
{
  char month[4] /*, weekday[10] */;
  unsigned day, year, hour, minute, second;
  int idx, fmt, month_number;
  TIMESTAMP_STRUCT ts_tmp, *ts = &ts_tmp;
  const char *http_end_of_weekday = http_date;

  day = year = hour = minute = second = 0;
  month[0] /* = weekday[0] = weekday[9] */ = 0;
  memset (ts, 0, sizeof (TIMESTAMP_STRUCT));

  for (idx = 0; isalpha (http_end_of_weekday[0]) && (idx < 9); idx++)
    http_end_of_weekday++;
  /*weekday[idx] = '\0';*/

  /* rfc 1123 */
  if (6 == sscanf (http_end_of_weekday, ", %2u %3s %4u %2u:%2u:%u GMT",
	&day, &(month[0]), &year, &hour, &minute, &second) &&
    (3 == (http_end_of_weekday - http_date)) )
    fmt = 1123;
  /* rfc 850 */
  else if (6 == sscanf (http_end_of_weekday, ", %2u-%3s-%2u %2u:%2u:%u GMT",
	&day, &(month[0]), &year, &hour, &minute, &second) &&
    (6 <= (http_end_of_weekday - http_date)) )
    {
      if (year > 0 && year < 100)
	year = year + 1900;
      fmt = 850;
    }
  /* asctime */
  else if (6 == sscanf (http_end_of_weekday, " %3s %2u %2u:%2u:%u %4u",
	 month, &day, &hour, &minute, &second, &year) &&
    (3 == (http_end_of_weekday - http_date)) )
    fmt = -1;
  else
    return 0;

  if (day > 31 || hour > 24 || minute > 60 || second > 60)
    return 0;

  if (!strncmp (month, "Jan", 3))
    month_number = 1;
  else if (!strncmp (month, "Feb", 3))
    month_number = 2;
  else if (!strncmp (month, "Mar", 3))
    month_number = 3;
  else if (!strncmp (month, "Apr", 3))
    month_number = 4;
  else if (!strncmp (month, "May", 3))
    month_number = 5;
  else if (!strncmp (month, "Jun", 3))
    month_number = 6;
  else if (!strncmp (month, "Jul", 3))
    month_number = 7;
  else if (!strncmp (month, "Aug", 3))
    month_number = 8;
  else if (!strncmp (month, "Sep", 3))
    month_number = 9;
  else if (!strncmp (month, "Oct", 3))
    month_number = 10;
  else if (!strncmp (month, "Nov", 3))
    month_number = 11;
  else if (!strncmp (month, "Dec", 3))
    month_number = 12;
  else
    return 0;

  ts->year = year;
  ts->month = month_number;
  ts->day = day;

  ts->hour = hour;
  ts->minute = minute;
  ts->second = second;
#if 0 /* This 'if' is NOT valid. Citation from RFC 2616:
All HTTP date/time stamps MUST be represented in Greenwich Mean Time (GMT), without exception.
For the purposes of HTTP, GMT is exactly equal to UTC (Coordinated Universal Time).
This is indicated in the first two formats by the inclusion of "GMT" as the three-letter abbreviation for time zone,
and MUST be assumed when reading the asctime format. */
  if (1123 == fmt || 850 == fmt) /* these formats are explicitly for GMT */
#endif
    ts_add (ts, dt_local_tz, "minute");
  timestamp_struct_to_dt (ts, dt);
  return 1;
}


void
dt_to_tv (char *dt, char *dv)
{
  time_t tt;
  long ttf;
  struct tm tm;
  TIMESTAMP_STRUCT ts;
  memset (&tm, 0, sizeof (tm));
  dt_to_timestamp_struct (dt, &ts);
  tm.tm_year = ts.year - 1900;
  tm.tm_mon = ts.month - 1;
  tm.tm_mday = ts.day;
  tm.tm_hour = ts.hour;
  tm.tm_min = ts.minute;
  tm.tm_sec = ts.second;
  tm.tm_isdst = -1;
  tt = mktime (&tm);
  ttf = DT_FRACTION (dt);
  ((uint32 *) dv)[0] = LONG_TO_EXT (tt);
  ((uint32 *) dv)[1] = LONG_TO_EXT (ttf);
}

void
dt_to_parts (char *dt, int *year, int *month, int *day, int *hour, int *minute, int *second, int *fraction)
{
  TIMESTAMP_STRUCT ts;
  dt_to_timestamp_struct (dt, &ts);
  if (year)
    *year = ts.year;
  if (month)
    *month = ts.month;
  if (day)
    *day = ts.day;
  if (hour)
    *hour = ts.hour;
  if (minute)
    *minute = ts.minute;
  if (second)
    *second = ts.second;
  if (fraction)
    *fraction = ts.fraction;
}

void
dt_from_parts (char *dt, int year, int month, int day, int hour, int minute, int second, int fraction, int tz)
{
  TIMESTAMP_STRUCT ts;
  ts.year = year;
  ts.month = month;
  ts.day = day;
  ts.hour = hour;
  ts.minute = minute;
  ts.second = second;
  ts.fraction = fraction;
  ts_add (&ts, dt_local_tz - tz, "minute");
  timestamp_struct_to_dt (&ts, dt);
  DT_SET_TZ (dt, tz);
}

void
dt_make_day_zero (char *dt)
{
  TIMESTAMP_STRUCT tss;
  dt_to_timestamp_struct (dt, &tss);
  ts_add (&tss, dt_local_tz, "minute");
  timestamp_struct_to_dt (&tss, dt);
  DT_SET_DAY (dt, DAY_ZERO);
  DT_SET_TZ (dt, 0);
  DT_SET_DT_TYPE (dt, DT_TYPE_TIME);
}
