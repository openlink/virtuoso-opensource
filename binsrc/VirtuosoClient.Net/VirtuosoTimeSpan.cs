//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2015 OpenLink Software
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
	public struct VirtuosoTimeSpan : IComparable
		, IComparable<VirtuosoTimeSpan>, IEquatable <VirtuosoTimeSpan>
	{
		private TimeSpan value;

		public VirtuosoTimeSpan (long val)
		{
			this.value = new TimeSpan(val);
		}

		public VirtuosoTimeSpan (int hours, int minutes, int seconds)
		{
			this.value = new TimeSpan(hours, minutes, seconds);
		}

		public VirtuosoTimeSpan (int days, int hours, int minutes, int seconds)
		{
			this.value = new TimeSpan(days, hours, minutes, seconds);
		}

		public VirtuosoTimeSpan (int days, int hours, int minutes, int seconds, long microseconds)
		{
			if (microseconds < 0 || microseconds > 999999)
				throw new ArgumentOutOfRangeException ("Microseconds parameters describe an " +
									"unrepresentable VirtuosoTimeSpan.");
			TimeSpan t = new TimeSpan(days, hours, minutes, seconds);
			
			long dateTick = (long) (t.Ticks + microseconds * 10);
			this.value = new TimeSpan (dateTick);
		}


		public int Days {
			get {
				return value.Days;
			}
		}

		public int Hours {
			get {
				return value.Hours;
			}
		}

		public int Milliseconds {
			get {
				return value.Milliseconds;
			}
		}

		public long Microseconds {
			get {
				return (long) (value.Ticks % TimeSpan.TicksPerSecond / 10L);
			}
		}

		public int Minutes {
			get {
				return value.Minutes;
			}
		}

		public int Seconds {
			get {
				return value.Seconds;
			}
		}

		public long Ticks {
			get {
				return value.Ticks;
			}
		}

		public double TotalDays {
			get {
				return value.TotalDays;
			}
		}

		public double TotalHours {
			get {
				return value.TotalHours;
			}
		}

		public double TotalMilliseconds {
			get {
				return value.TotalMilliseconds;
			}
		}

		public double TotalMinutes {
			get {
				return value.TotalMinutes;
			}
		}

		public double TotalSeconds {
			get {
				return value.TotalSeconds;
			}
		}

		public TimeSpan Value {
			get {
				return value;
			}
		}

	
		
		public TimeSpan Add (TimeSpan ts)
		{
			return value.Add(ts);
		}


		public static int Compare (VirtuosoTimeSpan t1, VirtuosoTimeSpan t2)
		{
			if (t1.Ticks < t2.Ticks)
				return -1;
			if (t1.Ticks > t2.Ticks)
				return 1;
			return 0;
		}

		public int CompareTo (object val)
		{
			if (val == null)
				return 1;

			if (!(val is TimeSpan) || !(val is VirtuosoTimeSpan)) {
				throw new ArgumentException ("Argument has to be a TimeSpan.", "value");
			}

			if (val is VirtuosoTimeSpan)
			   return Compare (this, (VirtuosoTimeSpan) val);
			else
			   return TimeSpan.Compare (this.value, (TimeSpan) val);
		}

	        public int CompareTo(VirtuosoTimeSpan value)
        	{
	            return Compare(this, value);
	        }

	        public bool Equals(TimeSpan val)
		{
			return value.Ticks == val.Ticks;
		}

		public bool Equals (VirtuosoTimeSpan val)
		{
			return value.Ticks == val.Ticks;
		}

		public TimeSpan Duration ()
		{
			return value.Duration();
		}

		public override bool Equals (object val)
		{
			if (!(val is TimeSpan) || !(val is VirtuosoTimeSpan))
				return false;

			if (val is VirtuosoTimeSpan)
			  return value.Ticks == ((VirtuosoTimeSpan) val).Ticks;
			else
			  return value.Ticks == ((TimeSpan) val).Ticks;
		}

		public static VirtuosoTimeSpan FromDays (double val)
		{
			return new VirtuosoTimeSpan(TimeSpan.FromDays (val).Ticks);
		}

		public static VirtuosoTimeSpan FromHours (double val)
		{
			return new VirtuosoTimeSpan(TimeSpan.FromHours (val).Ticks);
		}

		public static VirtuosoTimeSpan FromMinutes (double val)
		{
			return new VirtuosoTimeSpan(TimeSpan.FromMinutes (val).Ticks);
		}

		public static VirtuosoTimeSpan FromSeconds (double val)
		{
			return new VirtuosoTimeSpan(TimeSpan.FromSeconds(val).Ticks);
		}

		public static VirtuosoTimeSpan FromMilliseconds (double val)
		{
			return new VirtuosoTimeSpan(TimeSpan.FromMilliseconds (val).Ticks);
		}

		public static VirtuosoTimeSpan FromTicks (long value)
		{
			return new VirtuosoTimeSpan(TimeSpan.FromTicks(value).Ticks);
		}

		public override int GetHashCode ()
		{
			return value.Ticks.GetHashCode ();
		}

		public VirtuosoTimeSpan Negate ()
		{
		        return new VirtuosoTimeSpan(value.Negate().Ticks);
		}

		public VirtuosoTimeSpan Subtract (TimeSpan ts)
		{
		        return new VirtuosoTimeSpan(value.Subtract(ts).Ticks);
		}

		public override string ToString ()
		{
		        return value.ToString();
		}

    }
}
