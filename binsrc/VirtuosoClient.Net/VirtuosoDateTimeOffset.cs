//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2019 OpenLink Software
//  
//  This project is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the
//  Free Software Foundation; only version 2 of the License, dated June 1991.
//  
//  This program is distributed in the hope that it will be useful, but
//  WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//  General Public License for more details.
//  
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
//  
//  
//
// $Id$
//

#if ADONET3

using System;
using System.Data;
using System.Data.Common;
using System.Text;
using System.Globalization;

using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Collections;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{

	[Serializable]
	[StructLayout (LayoutKind.Auto)]
	public struct VirtuosoDateTimeOffset : IFormattable, IComparable
		, IComparable<VirtuosoDateTimeOffset>, IEquatable <VirtuosoDateTimeOffset>
	{
		private DateTimeOffset value;
		private int tz;
		private Era era;

		private VirtuosoDateTimeOffset (DateTimeOffset dt)
		{
			this.value = dt;
			this.tz = 0;
			this.era = Era.AD;
		}

		public VirtuosoDateTimeOffset (long ticks, TimeSpan offset)
		{
			this.value = new DateTimeOffset(ticks, offset);
			this.tz = 0;
			this.era = Era.AD;
		}

		public VirtuosoDateTimeOffset (DateTime dt)
		{
			this.value = new DateTimeOffset(dt);
			this.tz = 0;
			this.era = Era.AD;
		}

		public VirtuosoDateTimeOffset (DateTime dt, TimeSpan offset)
		{
			this.value = new DateTimeOffset(dt, offset);
			this.tz = 0;
			this.era = Era.AD;
		}

		public VirtuosoDateTimeOffset (int year, int month, int day, int hour, int minute, int second, TimeSpan offset)
		{
			this.value = new DateTimeOffset(year, month, day, hour, minute, second, offset);
			this.tz = 0;
			this.era = Era.AD;
		}

		public VirtuosoDateTimeOffset (int year, int month, int day, int hour, int minute, int second, long microsecond, TimeSpan offset)
		{
			if (microsecond < 0 || microsecond > 999999)
				throw new ArgumentOutOfRangeException ("Microsecond parameters describe an " +
									"unrepresentable VirtuosoDateTimeOffset.");
			DateTimeOffset t = new DateTimeOffset(year, month, day, hour, minute, second, offset);
			
			long dateTick = (long) (t.Ticks + microsecond * 10L);
			this.value = new DateTimeOffset (dateTick, offset);
			this.tz = offset.Minutes;
			this.era = Era.AD;
		}

		public VirtuosoDateTimeOffset (int year, int month, int day, int hour, int minute, int second, int millisecond, Calendar calendar, TimeSpan offset)
		{
			this.value = new DateTimeOffset(year, month, day, hour, minute, second, millisecond, calendar, offset);
			this.tz = offset.Minutes;
			this.era = Era.AD;
		}

		public VirtuosoDateTimeOffset (int year, int month, int day, int hour, int minute, int second, long microsecond, Calendar calendar, TimeSpan offset)
		{
			if (microsecond < 0 || microsecond > 999999)
				throw new ArgumentOutOfRangeException ("Microsecond parameters describe an " +
									"unrepresentable VirtuosoDateTime.");
			DateTimeOffset t = new DateTimeOffset(year, month, day, hour, minute, second, 0, calendar, offset);
			
			long dateTick = (long) (t.Ticks + microsecond * 10);
			this.value = new DateTimeOffset (dateTick, offset);
			this.tz = offset.Minutes;
			this.era = Era.AD;
		}

		internal VirtuosoDateTimeOffset(Era era, int year, int month, int day, int hour, int minute, int second, long microsecond, int tz)
		{
			if (microsecond < 0 || microsecond > 999999)
				throw new ArgumentOutOfRangeException("Microsecond parameters describe an " +
									"unrepresentable VirtuosoDateTime.");
			DateTime t = new DateTime(year, month, day, hour, minute, second);
			t = t.Add(new TimeSpan(0, tz, 0));

			long dateTick = (long)(t.Ticks + microsecond * 10);
			this.value = new DateTimeOffset(dateTick, new TimeSpan(0, tz, 0));
			this.tz = tz;
			this.era = era;
		}



		public DateTime Date 
		{
			get	
			{ 
				return value.Date;
			}
		}
        
		public DateTime DateTime 
		{
			get	
			{ 
				return value.DateTime;
			}
		}
        
		public int Day 
		{
			get	
			{ 
				return value.Day;
			}
		}
        
		public DayOfWeek DayOfWeek 
		{
			get 
			{ 
				return value.DayOfWeek;
			}
		}

		public int DayOfYear 
		{
			get 
			{ 
				return value.DayOfYear; 
			}
		}

		public int Hour 
		{
			get 
			{ 
				return value.Hour;
			}
		}

		public DateTime LocalDateTime 
		{
			get 
			{ 
				return value.LocalDateTime;
			}
		}

		public int Millisecond 
		{
			get 
			{ 
				return value.Millisecond;
			}
		}
		
		public long Microsecond 
		{
			get 
			{ 
			        return (int) (value.Ticks % TimeSpan.TicksPerSecond / 10L);
			}
		}
		
		public int Minute 
		{
			get 
			{ 
				return value.Minute;
			}
		}

		public int Month 
		{
			get	
			{ 
				return value.Month; 
			}
		}

	       
		public TimeSpan Offset 
		{
			get	
			{ 
				return value.Offset; 
			}
		}

		public int Second 
		{
			get	
			{ 
				return value.Second;
			}
		}

		public long Ticks
		{ 
			get	
			{ 
				return value.Ticks;
			}
		}
	
		public TimeSpan TimeOfDay 
		{
			get	
			{ 
				return value.TimeOfDay;
			}
			
		}

		public DateTime UtcDateTime
		{
			get	
			{ 
				return value.UtcDateTime;
			}
			
		}

		public long UtcTicks
		{ 
			get	
			{ 
				return value.UtcTicks;
			}
		}
	
		public int Year 
		{
			get 
			{ 
				return value.Year; 
			}
		}


		public DateTimeOffset Value {
			get {
				return value;
			}
		}

		public Era Era
		{
			get
			{
				return this.era;
			}
		}


		public VirtuosoDateTimeOffset Add (TimeSpan ts)
		{
			return new VirtuosoDateTimeOffset(value.Add(ts));
		}

		public VirtuosoDateTimeOffset AddDays (double days)
		{
			return new VirtuosoDateTimeOffset(value.AddDays(days));
		}
		
		public VirtuosoDateTimeOffset AddHours (double hours)
		{
			return new VirtuosoDateTimeOffset(value.AddHours(hours));
		}

		public VirtuosoDateTimeOffset AddMilliseconds (double ms)
		{
			return new VirtuosoDateTimeOffset(value.AddMilliseconds(ms));
		}

		public VirtuosoDateTimeOffset AddMinutes (double minutes)
		{
			return new VirtuosoDateTimeOffset(value.AddMinutes(minutes));
		}
		
		public VirtuosoDateTimeOffset AddMonths (int months)
		{
			return new VirtuosoDateTimeOffset(value.AddMonths(months));
		}

		public VirtuosoDateTimeOffset AddSeconds (double seconds)
		{
			return new VirtuosoDateTimeOffset(value.AddSeconds(seconds));
		}

		public VirtuosoDateTimeOffset AddTicks (long t)
		{
			return new VirtuosoDateTimeOffset(value.AddTicks(t));
		}

		public VirtuosoDateTimeOffset AddYears (int years )
		{
			return new VirtuosoDateTimeOffset(value.AddYears(years));
		}

//??TODO
		public int CompareTo (object v)
		{
			int rc;
			Era v_era = Era.AD;

			if ( v == null)
				return 1;

			if (!(v is System.DateTimeOffset) && !(v is VirtuosoDateTimeOffset))
				throw new ArgumentException ("Value is not a System.DateTimeOffset or VirtuosoDateTimeOffset");

			if (v is VirtuosoDateTimeOffset)
			{
				rc = DateTimeOffset.Compare(value, ((VirtuosoDateTimeOffset)v).value);
				v_era = ((VirtuosoDateTime)v).Era;
			}
			else
				rc = DateTimeOffset.Compare(value, (DateTimeOffset)v);

			if (this.Era == Era.BC && v_era == Era.AD)
				return -1;
			else if (this.Era == Era.AD && v_era == Era.BC)
				return 1;
			else //this.Era == v_era
				return rc;
		}

		public int CompareTo (VirtuosoDateTimeOffset v)
		{
			return this.CompareTo((object)v);
		}

		public int CompareTo (DateTimeOffset v)
		{
			return this.CompareTo((object)v);
		}

		public bool Equals (DateTimeOffset val)
		{
			return this.Equals((object)val);
		}

		public bool Equals (VirtuosoDateTimeOffset val)
		{
			return this.Equals((object)val);
		}

		public override bool Equals (object o)
		{
			Era v_era = Era.AD;

			if (!(o is System.DateTimeOffset) && !(o is VirtuosoDateTimeOffset))
				return false;

			if (o is VirtuosoDateTimeOffset)
				v_era = ((VirtuosoDateTimeOffset)o).Era;

			if (this.Era == v_era)
			{
				if (o is VirtuosoDateTimeOffset)
					return ((VirtuosoDateTimeOffset)o).Ticks == Ticks;
				else
					return ((DateTimeOffset)o).Ticks == Ticks;
			}
			else
				return false;
		}


		public bool EqualsExact (DateTimeOffset val)
		{
			if (this.Era == Era.BC)
				return false;
			else
			    return value.EqualsExact(val);
		}

		public bool EqualsExact (VirtuosoDateTimeOffset val)
		{
			if (this.Era == val.Era)
				return value.EqualsExact(val.value);
			else
				return false;
		}

		public override int GetHashCode ()
		{
			return value.GetHashCode ();
		}

		public TimeSpan Subtract(DateTimeOffset dt)
		{   
			return value.Subtract(dt);
		}

		public VirtuosoDateTimeOffset Subtract(TimeSpan ts)
		{
			return new VirtuosoDateTimeOffset(value.Subtract(ts));
		}

		public long ToFileTime()
		{
			return value.ToFileTime();
		}

		public VirtuosoDateTimeOffset ToLocalTime()
		{
			return new VirtuosoDateTimeOffset(value.ToLocalTime());
		}

		public VirtuosoDateTimeOffset ToOffset(TimeSpan offset)
		{
			return new VirtuosoDateTimeOffset(value.ToOffset (offset));
		}

		public override string ToString ()
		{
			return value.ToString ("o");
		}

		public string ToString (IFormatProvider fp)
		{
			return value.ToString (fp);
		}

		public string ToString (string format)
		{
			return value.ToString (format);
		}

		public string ToString (string format, IFormatProvider fp)

		{
			return value.ToString (format, fp);
		}

		public VirtuosoDateTimeOffset ToUniversalTime ()
		{
			return new VirtuosoDateTimeOffset(value.ToUniversalTime());
		}


		public string ToXSD_String()
		{
			String timeZoneString = null;
			StringBuilder sb = new StringBuilder();

			if (era == Era.BC)
				sb.Append(value.ToString("-yyy\\-MM\\-dd\\THH\\:mm\\:ss\\.FFF"));
			else
			    sb.Append(value.ToString("yyyy\\-MM\\-dd\\THH\\:mm\\:ss\\.FFF"));

			if (tz == 0)
			{
				timeZoneString = "Z";
			}
			else
			{
				StringBuilder s = new StringBuilder();
				s.Append(tz > 0 ? '+' : '-');

				int _tz = Math.Abs(tz);
				int _tzh = _tz / 60;
				int _tzm = _tz % 60;

				if (_tzh < 10)
					s.Append('0');

				s.Append(_tzh);
				s.Append(':');

				if (_tzm < 10)
					s.Append('0');

				s.Append(_tzm);
				timeZoneString = s.ToString();
			}

			if (timeZoneString != null)
				sb.Append(timeZoneString);

			return sb.ToString();
		}


    }
}
#endif
