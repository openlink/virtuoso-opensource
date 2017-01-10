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

		private VirtuosoDateTime (DateTime val)
		{
			this.value = val;
		}

		public VirtuosoDateTime (long ticks)
		{
			this.value = new DateTime(ticks);
		}

		public VirtuosoDateTime (int year, int month, int day)
		{
			this.value = new DateTime(year, month, day);
		}

		public VirtuosoDateTime (int year, int month, int day, int hour, int minute, int second)
		{
			this.value = new DateTime(year, month, day, hour, minute, second);
		}

		public VirtuosoDateTime (int year, int month, int day, int hour, int minute, int second, long microsecond)
		{
			if (microsecond < 0 || microsecond > 999999)
				throw new ArgumentOutOfRangeException ("Microsecond parameters describe an " +
									"unrepresentable VirtuosoDateTime.");
			DateTime t = new DateTime(year, month, day, hour, minute, second);
			
			long dateTick = (long) (t.Ticks + microsecond * 10);
			this.value = new DateTime (dateTick);
		}

		public VirtuosoDateTime (int year, int month, int day, Calendar calendar)
		{
			this.value = new DateTime(year, month, day, calendar);
		}
		
		public VirtuosoDateTime (int year, int month, int day, int hour, int minute, int second, Calendar calendar)
		{
			this.value = new DateTime(year, month, day, hour, minute, second, calendar);
		}

		public VirtuosoDateTime (int year, int month, int day, int hour, int minute, int second, long microsecond, Calendar calendar)
		{
			if (microsecond < 0 || microsecond > 999999)
				throw new ArgumentOutOfRangeException ("Microsecond parameters describe an " +
									"unrepresentable VirtuosoDateTime.");
			DateTime t = new DateTime(year, month, day, hour, minute, second, calendar);
			
			long dateTick = (long) (t.Ticks + microsecond * 10);
			this.value = new DateTime (dateTick);
		}


		public VirtuosoDateTime (long ticks, DateTimeKind kind)
		{
			this.value = new DateTime(ticks, kind);
		}

		public VirtuosoDateTime (int year, int month, int day, int hour, int minute, int second, DateTimeKind kind)
		{
			this.value = new DateTime(year, month, day, hour, minute, second, kind);
		}

		public VirtuosoDateTime (int year, int month, int day, int hour, int minute, int second, int millisecond, DateTimeKind kind)
		{
			this.value = new DateTime(year, month, day, hour, minute, second, millisecond, kind);
		}

                public VirtuosoDateTime(int year, int month, int day, int hour, int minute, int second, int millisecond, Calendar calendar, DateTimeKind kind)
		{
			this.value = new DateTime(year, month, day, hour, minute, second, millisecond, calendar, kind);
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
			if ( v == null)
				return 1;

			if (!(v is System.DateTime) || !(v is VirtuosoDateTime))
				throw new ArgumentException ("Value is not a System.DateTime or VirtuosoDateTime");

			if (v is VirtuosoDateTime)
			  return DateTime.Compare (value, ((VirtuosoDateTime) v).value);
			else
			  return DateTime.Compare (value, (DateTime) v);
		}

		public int CompareTo (VirtuosoDateTime v)
		{
			if (!(v is VirtuosoDateTime))
				throw new ArgumentException ("Value is not a VirtuosoDateTime");

			return DateTime.Compare (value, (DateTime) v.value);
		}

		public bool IsDaylightSavingTime ()
		{
		        return value.IsDaylightSavingTime ();
		}

		public int CompareTo (DateTime value)
		{
			return value.CompareTo (value);
		}

		public bool Equals (DateTime value)
		{
			return value.Equals(value);
		}

		public bool Equals (VirtuosoDateTime val)
		{
			return value.Equals(val.value);
		}

		public override bool Equals (object o)
		{
			if (!(o is System.DateTime) && !(o is VirtuosoDateTime))
				return false;

                        if (o is VirtuosoDateTime)
			   return ((VirtuosoDateTime) o).Ticks == Ticks;
			else
			   return ((DateTime) o).Ticks == Ticks;
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


    }
}
