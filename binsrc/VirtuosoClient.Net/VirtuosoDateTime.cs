//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2017 OpenLink Software
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
	public struct VirtuosoDateTime : IFormattable, IComparable
		, IComparable<VirtuosoDateTime>, IEquatable <VirtuosoDateTime>
	{
		private DateTime value;
		private int tz;
		private Era era;
		private TimeSpan offset;
		private DateTimeType dt_Type;

		private VirtuosoDateTime (DateTime val)
		{
			this.value = val;
			this.dt_Type = DateTimeType.DT_TYPE_DATETIME;
			this.offset = TimeSpan.Zero;
			this.tz = 0;
			this.era = Era.AD;
		}

		public VirtuosoDateTime (long ticks)
		{
			this.value = new DateTime(ticks);
			this.dt_Type = DateTimeType.DT_TYPE_DATETIME;
			this.offset = TimeSpan.Zero;
			this.tz = 0;
			this.era = Era.AD;
		}

		public VirtuosoDateTime (int year, int month, int day)
		{
			this.value = new DateTime(year, month, day);
			this.dt_Type = DateTimeType.DT_TYPE_DATETIME;
			this.offset = TimeSpan.Zero;
			this.tz = 0;
			this.era = Era.AD;
		}

		public VirtuosoDateTime (int year, int month, int day, int hour, int minute, int second)
		{
			this.value = new DateTime(year, month, day, hour, minute, second);
			this.dt_Type = DateTimeType.DT_TYPE_DATETIME;
			this.offset = TimeSpan.Zero;
			this.tz = 0;
			this.era = Era.AD;
		}

		public VirtuosoDateTime(int year, int month, int day, int hour, int minute, int second, long microsecond)
		{
			if (microsecond < 0 || microsecond > 999999)
				throw new ArgumentOutOfRangeException("Microsecond parameters describe an " +
									"unrepresentable VirtuosoDateTime.");
			DateTime t = new DateTime(year, month, day, hour, minute, second);

			long dateTick = (long)(t.Ticks + microsecond * 10);
			this.value = new DateTime(dateTick);
			this.dt_Type = DateTimeType.DT_TYPE_DATETIME;
			this.offset = TimeSpan.Zero;
			this.tz = 0;
			this.era = Era.AD;
		}

		internal VirtuosoDateTime(Era era, int year, int month, int day, int hour, int minute, int second, long microsecond, int tz, DateTimeType type)
		{
			if (microsecond < 0 || microsecond > 999999)
				throw new ArgumentOutOfRangeException("Microsecond parameters describe an " +
									"unrepresentable VirtuosoDateTime.");
			DateTime t = new DateTime(year, month, day, hour, minute, second);

			long dateTick = (long)(t.Ticks + microsecond * 10);
			this.dt_Type = type;
			this.tz = tz;
			this.era = era;
			this.offset = new TimeSpan(0, tz, 0);
			this.value = new DateTime(dateTick).Add(offset);
		}

		public VirtuosoDateTime(int year, int month, int day, Calendar calendar)
		{
			this.value = new DateTime(year, month, day, calendar);
			this.dt_Type = DateTimeType.DT_TYPE_DATETIME;
			this.offset = TimeSpan.Zero;
			this.tz = 0;
			this.era = Era.AD;
		}
		
		public VirtuosoDateTime (int year, int month, int day, int hour, int minute, int second, Calendar calendar)
		{
			this.value = new DateTime(year, month, day, hour, minute, second, calendar);
			this.dt_Type = DateTimeType.DT_TYPE_DATETIME;
			this.offset = TimeSpan.Zero;
			this.tz = 0;
			this.era = Era.AD;
		}

		public VirtuosoDateTime (int year, int month, int day, int hour, int minute, int second, long microsecond, Calendar calendar)
		{
			if (microsecond < 0 || microsecond > 999999)
				throw new ArgumentOutOfRangeException ("Microsecond parameters describe an " +
									"unrepresentable VirtuosoDateTime.");
			DateTime t = new DateTime(year, month, day, hour, minute, second, calendar);
			
			long dateTick = (long) (t.Ticks + microsecond * 10);
			this.value = new DateTime (dateTick);
			this.dt_Type = DateTimeType.DT_TYPE_DATETIME;
			this.offset = TimeSpan.Zero;
			this.tz = 0;
			this.era = Era.AD;
		}


		public VirtuosoDateTime (long ticks, DateTimeKind kind)
		{
			this.value = new DateTime(ticks, kind);
			this.dt_Type = DateTimeType.DT_TYPE_DATETIME;
			this.offset = TimeSpan.Zero;
			this.tz = 0;
			this.era = Era.AD;
		}

		public VirtuosoDateTime (int year, int month, int day, int hour, int minute, int second, DateTimeKind kind)
		{
			this.value = new DateTime(year, month, day, hour, minute, second, kind);
			this.dt_Type = DateTimeType.DT_TYPE_DATETIME;
			this.offset = TimeSpan.Zero;
			this.tz = 0;
			this.era = Era.AD;
		}

		public VirtuosoDateTime (int year, int month, int day, int hour, int minute, int second, int millisecond, DateTimeKind kind)
		{
			this.value = new DateTime(year, month, day, hour, minute, second, millisecond, kind);
			this.dt_Type = DateTimeType.DT_TYPE_DATETIME;
			this.offset = TimeSpan.Zero;
			this.tz = 0;
			this.era = Era.AD;
		}

        public VirtuosoDateTime(int year, int month, int day, int hour, int minute, int second, int millisecond, Calendar calendar, DateTimeKind kind)
		{
			this.value = new DateTime(year, month, day, hour, minute, second, millisecond, calendar, kind);
			this.dt_Type = DateTimeType.DT_TYPE_DATETIME;
			this.offset = TimeSpan.Zero;
			this.tz = 0;
			this.era = Era.AD;
		}			


		public DateTime Date 
		{
			get	
			{ 
				return value.Date;
			}
		}
        
		public int Month 
		{
			get	
			{ 
				return value.Month; 
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

		public TimeSpan TimeOfDay 
		{
			get	
			{ 
				return value.TimeOfDay;
			}
			
		}

		public int Hour 
		{
			get 
			{ 
				return value.Hour;
			}
		}

		public int Minute 
		{
			get 
			{ 
				return value.Minute;
			}
		}

		public int Second 
		{
			get	
			{ 
				return value.Second;
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
		
		public long Ticks
		{ 
			get	
			{ 
				return value.Ticks;
			}
		}
	
		public int Year 
		{
			get 
			{ 
				return value.Year; 
			}
		}

		public DateTimeKind Kind {
			get {
				return value.Kind;
			}
		}

		public DateTime Value {
			get {
				return value;
			}
		}

		public TimeSpan Offset
		{
			get
			{
				return this.offset;
			}
		}

		public Era Era
		{
			get
			{
				return this.era;
			}
		}

		/* methods */

		public VirtuosoDateTime Add (TimeSpan ts)
		{
			return new VirtuosoDateTime(value.Add(ts));
		}

		public VirtuosoDateTime AddDays (double days)
		{
			return new VirtuosoDateTime(value.AddDays(days));
		}
		
		public VirtuosoDateTime AddTicks (long t)
		{
			return new VirtuosoDateTime(value.AddTicks(t));
		}

		public VirtuosoDateTime AddHours (double hours)
		{
			return new VirtuosoDateTime(value.AddHours(hours));
		}

		public VirtuosoDateTime AddMilliseconds (double ms)
		{
			return new VirtuosoDateTime(value.AddMilliseconds(ms));
		}

		public VirtuosoDateTime AddMinutes (double minutes)
		{
			return new VirtuosoDateTime(value.AddMinutes(minutes));
		}
		
		public VirtuosoDateTime AddMonths (int months)
		{
			return new VirtuosoDateTime(value.AddMonths(months));
		}

		public VirtuosoDateTime AddSeconds (double seconds)
		{
			return new VirtuosoDateTime(value.AddSeconds(seconds));
		}

		public VirtuosoDateTime AddYears (int years )
		{
			return new VirtuosoDateTime(value.AddYears(years));
		}

		public int CompareTo (object v)
		{
			int rc;
			Era v_era = Era.AD;

			if (v == null)
				return 1;

			if (!(v is System.DateTime) && !(v is VirtuosoDateTime))
				throw new ArgumentException ("Value is not a System.DateTime or VirtuosoDateTime");

			if (v is VirtuosoDateTime)
			{
				rc = DateTime.Compare(value, ((VirtuosoDateTime)v).value);
				v_era = ((VirtuosoDateTime)v).Era;
			}
			else
				rc = DateTime.Compare(value, (DateTime)v);

			if (this.Era == Era.BC && v_era == Era.AD)
				return -1;
			else if (this.Era == Era.AD && v_era == Era.BC)
				return 1;
			else //this.Era == v_era
				return rc;
		}

		public int CompareTo (VirtuosoDateTime v)
		{
			return this.CompareTo((object)v);
		}

		public bool IsDaylightSavingTime ()
		{
		        return value.IsDaylightSavingTime ();
		}

		public int CompareTo (DateTime value)
		{
			return this.CompareTo((object)value);
		}

		public bool Equals (DateTime value)
		{
			return this.Equals((object)value);
		}

		public bool Equals (VirtuosoDateTime value)
		{
			return this.Equals((object)value);
		}

		public override bool Equals (object o)
		{
			Era v_era = Era.AD;

			if (!(o is System.DateTime) && !(o is VirtuosoDateTime))
				return false;

			if (o is VirtuosoDateTime)
				v_era = ((VirtuosoDateTime)o).Era;

			if (this.Era == v_era)
			{
				if (o is VirtuosoDateTime)
					return ((VirtuosoDateTime)o).Ticks == Ticks;
				else
					return ((DateTime)o).Ticks == Ticks;
			}
			else
				return false;
		}


		public string[] GetDateTimeFormats() 
		{
			return value.GetDateTimeFormats();
		}

		public string[] GetDateTimeFormats(char format)
		{
			return value.GetDateTimeFormats(format);
		}
		
		public string[] GetDateTimeFormats(IFormatProvider provider)
		{
			return value.GetDateTimeFormats(provider);
		}

		public string[] GetDateTimeFormats(char format,IFormatProvider provider	)
		{
			return value.GetDateTimeFormats(format, provider);
		}

		public override int GetHashCode ()
		{
			return value.GetHashCode ();
		}

		public TimeSpan Subtract(DateTime dt)
		{   
			return value.Subtract(dt);
		}

		public VirtuosoDateTime Subtract(TimeSpan ts)
		{
			return new VirtuosoDateTime(value.Subtract(ts));
		}

		public long ToFileTime()
		{
			return value.ToFileTime();
		}

		public long ToFileTimeUtc()
		{
			return value.ToFileTimeUtc();
		}

		public string ToLongDateString()
		{
			return value.ToString ("D");
		}

		public string ToLongTimeString()
		{
			return value.ToString ("T");
		}

		public double ToOADate ()
		{
			return value.ToOADate ();
		}

		public string ToShortDateString()
		{
			return value.ToShortDateString();
		}

		public string ToShortTimeString()
		{
			return value.ToShortTimeString();
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

		public VirtuosoDateTime ToLocalTime ()
		{
			return new VirtuosoDateTime(value.ToLocalTime ());
		}

		public VirtuosoDateTime ToUniversalTime()
		{
			return new VirtuosoDateTime(value.ToUniversalTime());
		}


		public string ToXSD_String()
		{
			String timeZoneString = null;
			StringBuilder sb = new StringBuilder();
			if (dt_Type == DateTimeType.DT_TYPE_DATE)
			{
			    if (era == Era.BC)
				  sb.Append(value.ToString("-yyy\\-MM\\-dd"));   //1999-05-31
			    else
				  sb.Append(value.ToString("yyyy\\-MM\\-dd"));   //1999-05-31
			}
			else
			{
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
			}


			if (timeZoneString != null)
				sb.Append(timeZoneString);

			return sb.ToString();
		}


    }
}
