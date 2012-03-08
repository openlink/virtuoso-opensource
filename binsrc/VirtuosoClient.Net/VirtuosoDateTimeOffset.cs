//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2012 OpenLink Software
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

		private VirtuosoDateTimeOffset (DateTimeOffset dt)
		{
			this.value = dt;
		}

		public VirtuosoDateTimeOffset (long ticks, TimeSpan offset)
		{
			this.value = new DateTimeOffset(ticks, offset);
		}

		public VirtuosoDateTimeOffset (DateTime dt)
		{
			this.value = new DateTimeOffset(dt);
		}

		public VirtuosoDateTimeOffset (DateTime dt, TimeSpan offset)
		{
			this.value = new DateTimeOffset(dt, offset);
		}

		public VirtuosoDateTimeOffset (int year, int month, int day, int hour, int minute, int second, TimeSpan offset)
		{
			this.value = new DateTimeOffset(year, month, day, hour, minute, second, offset);
		}

		public VirtuosoDateTimeOffset (int year, int month, int day, int hour, int minute, int second, long microsecond, TimeSpan offset)
		{
			if (microsecond < 0 || microsecond > 999999)
				throw new ArgumentOutOfRangeException ("Microsecond parameters describe an " +
									"unrepresentable VirtuosoDateTimeOffset.");
			DateTimeOffset t = new DateTimeOffset(year, month, day, hour, minute, second, offset);
			
			long dateTick = (long) (t.Ticks + microsecond * 10L);
			this.value = new DateTimeOffset (dateTick, offset);
		}

		public VirtuosoDateTimeOffset (int year, int month, int day, int hour, int minute, int second, int millisecond, Calendar calendar, TimeSpan offset)
		{
			this.value = new DateTimeOffset(year, month, day, hour, minute, second, millisecond, calendar, offset);
		}

		public VirtuosoDateTimeOffset (int year, int month, int day, int hour, int minute, int second, long microsecond, Calendar calendar, TimeSpan offset)
		{
			if (microsecond < 0 || microsecond > 999999)
				throw new ArgumentOutOfRangeException ("Microsecond parameters describe an " +
									"unrepresentable VirtuosoDateTime.");
			DateTimeOffset t = new DateTimeOffset(year, month, day, hour, minute, second, 0, calendar, offset);
			
			long dateTick = (long) (t.Ticks + microsecond * 10);
			this.value = new DateTimeOffset (dateTick, offset);
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

		public int CompareTo (object v)
		{
			if ( v == null)
				return 1;

			if (!(v is System.DateTimeOffset) || !(v is VirtuosoDateTimeOffset))
				throw new ArgumentException ("Value is not a System.DateTimeOffset or VirtuosoDateTimeOffset");

			if (v is VirtuosoDateTimeOffset)
			  return DateTimeOffset.Compare (value, ((VirtuosoDateTimeOffset) v).value);
			else
			  return DateTimeOffset.Compare (value, (DateTimeOffset) v);
		}

		public int CompareTo (VirtuosoDateTimeOffset v)
		{
			if (!(v is VirtuosoDateTimeOffset))
				throw new ArgumentException ("Value is not a VirtuosoDateTimeOffset");

			return DateTimeOffset.Compare (value, (DateTimeOffset) v.value);
		}

		public int CompareTo (DateTimeOffset val)
		{
			return value.CompareTo (val);
		}

		public bool Equals (DateTimeOffset val)
		{
			return value.Equals(val);
		}

		public bool Equals (VirtuosoDateTimeOffset val)
		{
			return value.Equals(val.value);
		}

		public override bool Equals (object o)
		{
			if (!(o is System.DateTimeOffset) && !(o is VirtuosoDateTimeOffset))
				return false;

                        if (o is VirtuosoDateTimeOffset)
			   return ((VirtuosoDateTimeOffset) o).Ticks == Ticks;
			else
			   return ((DateTimeOffset) o).Ticks == Ticks;
		}


		public bool EqualsExact (DateTimeOffset val)
		{
			return value.EqualsExact(val);
		}

		public bool EqualsExact (VirtuosoDateTimeOffset val)
		{
			return value.EqualsExact(val.value);
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



    }
}
#endif
