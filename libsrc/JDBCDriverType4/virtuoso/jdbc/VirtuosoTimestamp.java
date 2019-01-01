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

public class VirtuosoTimestamp extends java.sql.Timestamp
{
    int timezone = 0;
    boolean with_timezone = false;

    public VirtuosoTimestamp(long date) {
	super(date);
    }

    public VirtuosoTimestamp(long time, int tz) {
	super(time);
	this.timezone = tz;
	this.with_timezone = true;
    }

    public VirtuosoTimestamp(long time, int tz, boolean with_tz) {
	super(time);
	this.timezone = tz;
	this.with_timezone = with_tz;
    }


    public boolean withTimezone()
    {
    	return this.with_timezone;
    }

    public int getTimezone()
    {
        return this.timezone;
    }

    public VirtuosoTimestamp clone()
    {
        int nanos = getNanos();
        VirtuosoTimestamp _ts = new VirtuosoTimestamp(getTime(), timezone, with_timezone);
        _ts.setNanos(nanos);
        return _ts;
    }

    public String toXSD_String ()
    {
        StringBuilder sb = new StringBuilder();
        DateFormat formatter;
        String nanosString;
        String timeZoneString = null;
        String zeros = "000000000";
        int nanos = getNanos();
        java.util.Calendar cal = new java.util.GregorianCalendar ();

        cal.setTime(this);

        if (cal.get(Calendar.ERA) == GregorianCalendar.BC) {
            sb.append('-');
            formatter = new SimpleDateFormat("yyy-MM-dd'T'HH:mm:ss");
        }
        else
            formatter = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss");

        if (nanos == 0) {
//            nanosString = "000";
            nanosString = "";
        } else {
            nanosString = Integer.toString(nanos);

            // Add leading zeros
            nanosString = zeros.substring(0, (9-nanosString.length())) +
                    nanosString;

            // Truncate trailing zeros
            char[] nanosChar = new char[nanosString.length()];
            nanosString.getChars(0, nanosString.length(), nanosChar, 0);
            int truncIndex = 8;
            while (nanosChar[truncIndex] == '0') {
                truncIndex--;
            }

            nanosString = new String(nanosChar, 0, truncIndex + 1);
        }

        if (with_timezone)
        {
            StringBuffer s = new StringBuffer();
            if (timezone == 0) {
              timeZoneString = "Z";
              formatter.setTimeZone(TimeZone.getTimeZone("GMT-00:00"));
            } else {
              s.append(timezone>0?'+':'-');

              int tz = Math.abs(timezone);
              int tzh = tz/60;
              int tzm = tz%60;

              if (tzh < 10)
                s.append('0');

              s.append(tzh);
              s.append(':');

              if (tzm < 10)
                s.append('0');

              s.append(tzm);
              timeZoneString = s.toString();
              formatter.setTimeZone(TimeZone.getTimeZone("GMT"+timeZoneString));
            }
        }
        sb.append(formatter.format(this));

        if (nanosString.length()>0) {
          sb.append(".");
          sb.append(nanosString);
        }

        if (timeZoneString!=null)
            sb.append(timeZoneString);
        return sb.toString();
    }
}

