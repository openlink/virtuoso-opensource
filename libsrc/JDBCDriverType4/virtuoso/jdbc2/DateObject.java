/*
 *  $Id$
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

package virtuoso.jdbc2;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.*;
import java.sql.*;

class DateObject 
{
    java.util.Calendar cal_dat = new java.util.GregorianCalendar ();
    int day;
    int hour;
    int minute;
    int second;
    int fraction;
    int tz;
    int type;

    protected DateObject(int _day, int _hour, int _minute, int _second,
        int _fraction, int _tz, int _type) 
    {
      this.day = _day;
      this.hour = _hour;
      this.minute = _minute;
      this.second = _second;
      this.fraction = _fraction;
      this.tz = _tz;
      this.type = _type;
    }


    protected Object getValue (boolean sparql_executed)
    {
       if (sparql_executed)
       {
          java.util.Calendar cal_gmt = new java.util.GregorianCalendar(TimeZone.getTimeZone("GMT"));

          num2date(day, cal_gmt);
          if (type!=VirtuosoTypes.DT_TYPE_DATE) 
          {
             cal_gmt.set (Calendar.HOUR_OF_DAY, hour);
             cal_gmt.set (Calendar.MINUTE, minute);
             cal_gmt.set (Calendar.SECOND, second);
             cal_gmt.set (Calendar.MILLISECOND, fraction/1000);
          }
          // Convert to Local GMT
          cal_dat.setTime(cal_gmt.getTime());
       }
       else
       {
          if(tz != 0)
          {
             int sec = time_to_sec (0, hour, minute, second);
             sec += 60 * tz;

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

             int dummy_day = sec / SPERDAY;
             hour = (sec - (dummy_day * SPERDAY)) / (60 * 60);
             minute = (sec - (dummy_day * SPERDAY) - (hour * 60 * 60)) / 60;
             second = sec % 60;
          }

          num2date(day, cal_dat);
          if (type!=VirtuosoTypes.DT_TYPE_DATE) 
          {
             cal_dat.set (Calendar.HOUR_OF_DAY, hour);
             cal_dat.set (Calendar.MINUTE, minute);
             cal_dat.set (Calendar.SECOND, second);
             cal_dat.set (Calendar.MILLISECOND, fraction/1000);
          }
       }

       switch(type)
       {
         case VirtuosoTypes.DT_TYPE_DATE:
           return new VirtuosoDate(cal_dat.getTime().getTime(), tz, sparql_executed);
         case VirtuosoTypes.DT_TYPE_TIME:
           return new VirtuosoTime(cal_dat.getTime().getTime(), tz, sparql_executed);
         default:
           {
              Timestamp ts = new VirtuosoTimestamp(cal_dat.getTime().getTime(), tz, sparql_executed);
              int nanos = fraction * 1000;
              if (nanos > 999999999)
                ts.setNanos(fraction);
              else
                ts.setNanos(nanos);
              return ts;
           }
       }
    }


   static final int SPERDAY = (24 * 60 * 60);
   static int time_to_sec (int day, int hour, int min, int sec)
     {
       return (day * SPERDAY + hour * 60 * 60 + min * 60 + sec);
     }

   public static void num2date(int julian_days, Calendar date)
   {
      double x;
      int i, year;
      boolean sign = false;

      if ((julian_days & 0x800000)!=0){
        sign = true;
        julian_days = ((~julian_days)+1)& 0xFFFFFF;
      }

      if(julian_days > 577737)
         julian_days += 10;
      x = ((double)julian_days) / 365.25;
      i = (int)x;
      if((double)i != x)
         year = i + 1;
      else
	{
	  year = i;
	  i--;
	}
      if(julian_days > 577737)
      {
         julian_days -= ((year / 400) - (1582 / 400));
         julian_days += ((year / 100) - (1582 / 100));
         x = ((double)julian_days) / 365.25;
         i = (int)x;
         if((double)i != x)
            year = i + 1;
         else
	   {
	     year = i;
	     i--;
	   }
         if((year % 400) != 0 && (year % 100) == 0)
            julian_days--;
      }
      i = (int)(julian_days - ((int) (i * 365.25)));
      if((year > 1582)
	  && (year % 400) != 0
	  && (year % 100) == 0
	  && (i < ((year / 100) - (1582 / 100)) - ((year / 400) - (1582 / 400))))
	i++;
      if (sign)
        date.set(Calendar.ERA, GregorianCalendar.BC);
      date.set (Calendar.YEAR, year);
      //System.out.println ("Year=" + year);
      yearday2date(i,(VirtuosoOutputStream.days_in_february(year) == 29),date);
   }

   static final int GREG_JDAYS = 577737;
   static final int GREG_LAST_DAY = 14;
   static final int GREG_FIRST_DAY = 5;
   static final int GREG_MONTH = 10;
   static final int GREG_YEAR = 1582;
   static final int DAY_LAST = 365;
   static final int DAY_MIN = 1;
   static final int MONTH_MIN = 1;
   static final int MONTH_MAX = 12;
   static final int MONTH_LAST = 31;
   static final int days_in_month[] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

   static void yearday2date(int yday, boolean is_leap_year, Calendar date)
     {
       int i;
       boolean decrement_date;
       int month, day;

       if (yday > DAY_LAST + (is_leap_year ? 1 : 0) || yday < DAY_MIN)
	 return;

       decrement_date = (is_leap_year && (yday > 59));
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
       month = i;
       day = yday;
       if (decrement_date && month == 2 && day == 28)
	 day = day + 1;

       //System.err.println (" day=" + day + " month=" + month);
       date.set(Calendar.MONTH, month - 1);
       date.set(Calendar.DAY_OF_MONTH, day);
       return;
     }

}

