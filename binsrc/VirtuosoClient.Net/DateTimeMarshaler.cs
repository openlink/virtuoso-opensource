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

using System;
using System.Diagnostics;
using System.IO;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal class DateTimeMarshaler : IConvertData, IMarshal, IUnmarshal
	{
		private static int[] to_month_days =
			new int[] { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 };
		private static int[] to_month_days_leap =
			new int[] { 0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335 };

		private const int NicaeaShift =
			((Values.GREG_YEAR / 100 - Values.GREG_YEAR / 400)
			- (Values.GREG_LAST_DAY - Values.GREG_FIRST_DAY + 1));

		private byte[] bytes = null;

		public BufferType GetDataType()
		{
			if (bytes == null)
				throw new InvalidOperationException("The DateTimeMarshaler is not set.");

			DateTimeType type = (DateTimeType)(bytes[8] >> 5);
			if (type == DateTimeType.DT_TYPE_TIME)
				return BufferTypes.Time;
			if (type == DateTimeType.DT_TYPE_DATE)
				return BufferTypes.Date;
			if (type == DateTimeType.DT_TYPE_DATETIME)
				return BufferTypes.DateTime;
			return null;
		}

		public object ConvertData(Type type)
		{
			if (bytes == null)
				throw new InvalidOperationException("The DateTimeMarshaler is not set.");

			if (type == typeof(byte[]))
				return bytes;
			else if (type == typeof(DateTime) || type == typeof(TimeSpan))
				return BytesToObject();
			else if (type == typeof(String))
				return BytesToObject().ToString();
			else
				throw new InvalidCastException();

		}

		public void Marshal(Stream stream)
		{
			if (bytes == null)
				throw new InvalidOperationException("The DateTimeMarshaler is not set.");
			stream.WriteByte((byte)BoxTag.DV_DATETIME);
			stream.Write(bytes, 0, bytes.Length);
		}

		public void Unmarshal(Stream stream)
		{
			if (bytes == null)
				bytes = new byte[10];
			stream.Read(bytes, 0, bytes.Length);
		}

		internal static void MarshalDate(Stream stream, object value, DateTimeType type)
		{
			DateTimeMarshaler m = new DateTimeMarshaler();
			m.ObjectToBytes(value, type);
			m.Marshal(stream);
		}

		internal static object UnmarshalDate(Stream stream)
		{
			DateTimeMarshaler m = new DateTimeMarshaler();
			m.Unmarshal(stream);
			return m;
		}

		private void ObjectToBytes(Object value, DateTimeType type)
		{
			Debug.WriteLineIf(Marshaler.marshalSwitch.Enabled, "DateTimeMarshaler.ObjectToBytes(" + value + ", " + type + ")");

			int days, hour, minute, second, fraction, tz_offset_minutes;
			if (value is DateTime)
			{
				DateTime dt = (DateTime)value;

				TimeZone tz = TimeZone.CurrentTimeZone;
				TimeSpan tz_offset = tz.GetUtcOffset(dt);
				tz_offset_minutes = (int)(tz_offset.Hours * 60) + tz_offset.Minutes;

				dt -= tz_offset;

				int year = dt.Year;
				int month = dt.Month;
				int day_of_month = dt.Day;
				days = GetDays(year, month, day_of_month);

				if (type == DateTimeType.DT_TYPE_DATETIME)
				{
					hour = dt.Hour;
					minute = dt.Minute;
					second = dt.Second;
					fraction = (int)(dt.Ticks % TimeSpan.TicksPerSecond / 10L);// dt.Millisecond * Values.MicrosPerMilliSec;
				}
				else if (type == DateTimeType.DT_TYPE_DATE)
				{
					hour = minute = second = fraction = 0;
				}
				else
					throw new InvalidCastException();
			}
			else if (value is TimeSpan)
			{
				if (type != DateTimeType.DT_TYPE_TIME)
					throw new InvalidCastException();

				days = Values.DAY_ZERO;
				tz_offset_minutes = 0;

				TimeSpan ts = (TimeSpan)value;
				hour = ts.Hours;
				minute = ts.Minutes;
				second = ts.Seconds;
				fraction = (int)(ts.Ticks % TimeSpan.TicksPerSecond / 10L); //ts.Milliseconds * Values.MicrosPerMilliSec;
			}
			else if (value is VirtuosoDateTime)
			{
				VirtuosoDateTime dt = (VirtuosoDateTime)value;

				TimeZone tz = TimeZone.CurrentTimeZone;
				TimeSpan tz_offset = tz.GetUtcOffset(dt.Value);
				tz_offset_minutes = (int)(tz_offset.Hours * 60) + tz_offset.Minutes;

				long ticks = dt.Ticks - tz_offset.Ticks;
				dt = new VirtuosoDateTime(ticks);

				int year = dt.Year;
				int month = dt.Month;
				int day_of_month = dt.Day;
				days = GetDays(year, month, day_of_month);

				if (type == DateTimeType.DT_TYPE_DATETIME)
				{
					hour = dt.Hour;
					minute = dt.Minute;
					second = dt.Second;
					fraction = (int)dt.Microsecond;
				}
				else if (type == DateTimeType.DT_TYPE_DATE)
				{
					hour = minute = second = fraction = 0;
				}
				else
					throw new InvalidCastException();
			}
#if ADONET3
            else if (value is VirtuosoDateTimeOffset)
            {
                VirtuosoDateTimeOffset dt = (VirtuosoDateTimeOffset)value;

                TimeSpan tz_offset = dt.Offset;
                tz_offset_minutes = (int)(tz_offset.Hours * 60) + tz_offset.Minutes;

                long ticks = dt.Ticks - tz_offset.Ticks;
                dt = new VirtuosoDateTimeOffset(ticks, new TimeSpan(0));

                int year = dt.Year;
                int month = dt.Month;
                int day_of_month = dt.Day;
                days = GetDays(year, month, day_of_month);

                if (type == DateTimeType.DT_TYPE_DATETIME)
                {
                    hour = dt.Hour;
                    minute = dt.Minute;
                    second = dt.Second;
                    fraction = (int)dt.Microsecond;
                }
                else if (type == DateTimeType.DT_TYPE_DATE)
                {
                    hour = minute = second = fraction = 0;
                }
                else
                    throw new InvalidCastException();
            }
#endif
			else if (value is VirtuosoTimeSpan)
			{
				if (type != DateTimeType.DT_TYPE_TIME)
					throw new InvalidCastException();

				days = Values.DAY_ZERO;
				tz_offset_minutes = 0;

				VirtuosoTimeSpan ts = (VirtuosoTimeSpan)value;
				hour = ts.Hours;
				minute = ts.Minutes;
				second = ts.Seconds;
				fraction = (int)ts.Microseconds;
			}
			else
				throw new InvalidCastException();

			if (bytes == null)
				bytes = new byte[10];

			bytes[0] = (byte)(days >> 16);
			bytes[1] = (byte)(days >> 8);
			bytes[2] = (byte)days;
			bytes[3] = (byte)hour;
			bytes[4] = (byte)((minute << 2) | (second >> 4));
			bytes[5] = (byte)((second << 4) | (fraction >> 16));
			bytes[6] = (byte)(fraction >> 8);
			bytes[7] = (byte)fraction;
			bytes[8] = (byte)(((tz_offset_minutes >> 8) & 0x07) | ((int)type << 5));
			bytes[9] = (byte)tz_offset_minutes;
		}

		private object BytesToObject()
		{
			Debug.WriteLineIf(Marshaler.marshalSwitch.Enabled, "DateTimeMarshaler.BytesToObject()");

			int days = (bytes[0] << 16) | (bytes[1] << 8) | bytes[2];
			int hour = bytes[3];
			int minute = bytes[4] >> 2;
			int second = ((bytes[4] & 0x03) << 4) | (bytes[5] >> 4);
			long fraction = ((bytes[5] & 0x0f) << 16) | (bytes[6] << 8) | bytes[7];
			int[] tz_bytes = new int[2];
			int tz_interm;
			int tzless = hour >> 7;

			days = (int) (((uint)days) | ((bytes[0] & 0x80)!=0 ? 0xff000000 : 0));

			hour &= 0x1F;

			tz_bytes[0] = bytes[8];
			tz_bytes[1] = bytes[9];

			int tz_offset_minutes = (((int)(tz_bytes[0] & 0x07)) << 8) | tz_bytes[1];
			DateTimeType type = (DateTimeType)(tz_bytes[0] >> 5);

			if ((tz_bytes[0] & 0x4) != 0)
			{
				tz_interm = tz_bytes[0] & 0x07;
				tz_interm |= 0xF8;
			}
			else
				tz_interm = tz_bytes[0] & 0x03;

			tz_offset_minutes = ((int)(tz_interm << 8)) | tz_bytes[1];

			if (tz_offset_minutes > 32767)
				tz_offset_minutes -= 65536;

			Debug.WriteLineIf(Marshaler.marshalSwitch.Enabled, "type: " + type);

			if (type == DateTimeType.DT_TYPE_TIME)
			{
				VirtuosoTimeSpan ts = new VirtuosoTimeSpan(0, hour, minute, second, fraction, tz_offset_minutes);
				Debug.WriteLineIf(Marshaler.marshalSwitch.Enabled, "TimeSpan: " + ts);
				return ts;
			}
#if ADONET3
			else if (type == DateTimeType.DT_TYPE_DATETIME)
			{
				int year, month, day_of_month;
				Era era;
				GetDate(days, out year, out month, out day_of_month, out era);

				VirtuosoDateTimeOffset dt = new VirtuosoDateTimeOffset(era, year, month, day_of_month, hour, minute, second, fraction, tz_offset_minutes);

				Debug.WriteLineIf(Marshaler.marshalSwitch.Enabled, "DateTime: " + dt);
				return dt;
			}
			else if (type == DateTimeType.DT_TYPE_DATE)
			{
				int year, month, day_of_month;
				Era era;
				GetDate(days, out year, out month, out day_of_month, out era);

				VirtuosoDateTime dt = new VirtuosoDateTime(era, year, month, day_of_month, hour, minute, second, fraction, tz_offset_minutes, type);
				Debug.WriteLineIf(Marshaler.marshalSwitch.Enabled, "DateTime: " + dt);
				return dt;
			}
#else
			else if (type == DateTimeType.DT_TYPE_DATETIME || type == DateTimeType.DT_TYPE_DATE)
			{
				int year, month, day_of_month;
				Era era;
				GetDate(days, out year, out month, out day_of_month, out era);

				VirtuosoDateTime dt = new VirtuosoDateTime(era, year, month, day_of_month, hour, minute, second, fraction, tz_offset_minutes, type);
				Debug.WriteLineIf(Marshaler.marshalSwitch.Enabled, "DateTime: " + dt);
				return dt;
			}
#endif
			else
				throw new InvalidCastException();
		}

		private static int GetDays(int year, int month, int day_of_month)
		{
			int prev_year = year - 1;
			int days = prev_year * 365 + prev_year / 4;
			if (year > Values.GREG_YEAR
				|| (year == Values.GREG_YEAR
				&& (month > Values.GREG_MONTH
				|| (month == Values.GREG_MONTH
				&& day_of_month > Values.GREG_LAST_DAY))))
				days += prev_year / 400 - prev_year / 100 + NicaeaShift;

			int[] mdays = IsLeapYear(year) ? to_month_days_leap : to_month_days;
			days += mdays[month - 1];
			days += day_of_month;

			return days;
		}

		private static void GetDate(int days, out int year, out int month, out int day_of_month, out Era era)
		{
			long y_civ, m_civ, d_civ;
			long midhignt_jdn;
			long mj, g, dg, c, dc, b, db, a, da, y, m, d;
			long e;
			
			midhignt_jdn = days + 1721423;

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
				y_civ = y - 4800 + (m + 2) / 12;
				m_civ = (m + 2) % 12 + 1;
				d_civ = d + 1;
			}
			else if (1722884 == midhignt_jdn)
			{
				d_civ = m_civ = 1; y_civ = 5;
			}
			else
			{
				c = midhignt_jdn + 32082;
				d = (4 * c + 3) / 1461;
				e = c - (1461 * d) / 4;
				m = (5 * e + 2) / 153;
				d_civ = e - (153 * m + 2) / 5 + 1;
				m_civ = m + 3 - 12 * (m / 10);
				y_civ = d - 4800 + m / 10;
				if (y_civ < 0)
					y_civ--;
			}
			if (y_civ < 0)
			{
				era = Era.BC;
				year = (int)-y_civ;
			}
			else
			{
				era = Era.AD;
				year = (int)y_civ;
			}

			month = (int)m_civ;
			day_of_month = (int)d_civ;
		}

		private static bool IsLeapYear(int year)
		{
			if ((year % 4) != 0)
				return false;
			if (year > Values.GREG_YEAR)
			{
				if ((year % 100) == 0)
				{
					if ((year % 400) == 0)
						return true;
					return false;
				}
			}
			else if (year == 4)
			{
				// Exception, the year 4 AD was historically NO leap year!
				return false;
			}
			return true;
		}

#if TEST_DATES
		public static void Main (string[] args)
		{
			for (int i = 1; i <= 9999; i++)
			{
				TestDate (i, 1, 1);
				TestDate (i, 1, 2);
				if (IsLeapYear (i))
					TestDate (i, 2, 29);
				else
					TestDate (i, 2, 28);
				TestDate (i, 3, 1);
				TestDate (i, 12, 30);
				TestDate (i, 12, 31);
				Console.WriteLine ("");
			}
		}

		private static void TestDate (int year, int month, int day)
		{
			int days = GetDays (year, month, day);
			Console.WriteLine ("{0} {1} {2} {3}", year, month, day, days);

			int year2, month2, day2;
			GetDate (days, out year2, out month2, out day2);
			Console.WriteLine ("{0} {1} {2}", year2, month2, day2);
			if (year != year2 || month != month2 || day != day2)
				Console.WriteLine ("***FAIL");
			Console.WriteLine ("");
		}
#endif
	}
}
