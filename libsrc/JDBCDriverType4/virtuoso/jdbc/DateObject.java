/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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

package virtuoso.jdbc4;

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

          cal_gmt.set (Calendar.HOUR_OF_DAY, hour);
          cal_gmt.set (Calendar.MINUTE, minute);
          cal_gmt.set (Calendar.SECOND, second);
          cal_gmt.set (Calendar.MILLISECOND, fraction/1000);

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

          cal_dat.set (Calendar.HOUR_OF_DAY, hour);
          cal_dat.set (Calendar.MINUTE, minute);
          cal_dat.set (Calendar.SECOND, second);
          cal_dat.set (Calendar.MILLISECOND, fraction/1000);
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


    void
    num2date (int julian_days,  Calendar date)
    {
        long y_civ, m_civ, d_civ;
        long midhignt_jdn;
        long mj, g, dg, c, dc, b, db, a, da, y, m, d;
        long /*c, d, m,*/ e;
        midhignt_jdn = julian_days + 1721423;

        if (2299161 <= midhignt_jdn)
        {
            mj = midhignt_jdn + 32044;
            g = mj / 146097;
            dg = mj % 146097;
            c = (dg / 36524 + 1) * 3 / 4;
            dc = dg - c * 36524;
            b = dc / 1461;
            db = dc % 1461;
            a = (db / 365 + 1) * 3 / 4;
            da = db - a * 365;
            y = g * 400 + c * 100 + b * 4 + a;
            m = (da * 5 + 308) / 153 - 2;
            d = da - (m + 4) * 153 / 5 + 122;
            y_civ = y - 4800 + (m+2)/12;
            m_civ = (m+2)%12 + 1;
            d_civ = d+1;
        }
        else if (1722884 == midhignt_jdn)
        {
            d_civ = m_civ = 1; y_civ = 5;
        }
        else
        {
            c = midhignt_jdn + 32082;
            d = (4*c+3)/1461;
            e = c - (1461*d)/4;
            m = (5*e+2)/153;
            d_civ = e - (153*m+2)/5+1;
            m_civ = m + 3 - 12 * (m/10);
            y_civ = d - 4800 + m/10;
            if (y_civ < 0)
                y_civ--;
        }
        if (y_civ < 0) {
            date.set(Calendar.ERA, GregorianCalendar.BC);
            date.set (Calendar.YEAR, (int)-y_civ);
        }
        else
            date.set (Calendar.YEAR, (int)y_civ);

        date.set(Calendar.MONTH, (int)m_civ - 1);
        date.set(Calendar.DAY_OF_MONTH, (int)d_civ);
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

