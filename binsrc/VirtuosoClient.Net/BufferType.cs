//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2014 OpenLink Software
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
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Xml;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal abstract class BufferType
	{
		internal readonly static BooleanSwitch Switch = 
		    new BooleanSwitch ("VirtuosoClient.BufferType", "Marshaling");

		/// <summary>
		/// Managed type that naturally maps to this native type.
		/// </summary>
		internal readonly System.Type type;

		/// <summary>
		/// ODBC buffer type.
		/// </summary>
		internal readonly CLI.SqlCType sqlCType;

		/// <summary>
		/// The necessary buffer alignment (in bytes).
		/// </summary>
		internal readonly int alignment;

		/// <summary>
		/// True if the buffer size is always the same regardless of the stored value.
		/// </summary>
		internal readonly bool isFixedSize;

		internal BufferType (System.Type type, CLI.SqlCType sqlCType, int alignment)
			: this (type, sqlCType, alignment, false)
		{
		}

		internal BufferType (System.Type type, CLI.SqlCType sqlCType, int alignment, bool isFixedSize)
		{
			this.type = type;
			this.sqlCType = sqlCType;
			this.alignment = alignment;
			this.isFixedSize = isFixedSize;
		}

		internal virtual int NullTermSize
		{
			get { return 0; }
		}

		internal abstract int GetBufferSize (object value);

		internal abstract int GetBufferSize (int valueSize);

		internal abstract int ManagedToNative (object value, IntPtr buffer, int length);

		internal abstract object NativeToManaged (IntPtr buffer, int length);

		internal virtual object NativeSizeToManaged (int length)
		{
			throw new NotSupportedException ();
		}

		internal virtual void NativePartToManaged (IntPtr buffer, int length, object value, ref int offset)
		{
			throw new NotSupportedException ();
		}

		internal virtual object ConvertValue (object value)
		{
			if (value == null || Convert.IsDBNull (value) || type == value.GetType ())
				return value;
			if (value is IConvertData)
				return ((IConvertData) value).ConvertData (type);
			if (value is IConvertible)
			  {
			        Debug.WriteIf (Switch.Enabled, String.Format ("ConvertValue({0}) :",  
				    this.GetType().Name));
			        Debug.WriteLineIf (Switch.Enabled, String.Format ("type={0}, {1} ({2})",  
				    type.Name, 
				    value.GetType().Name, 
				    value.ToString ()));
				return Convert.ChangeType (value, value.GetType());
			  }
            if (value is SqlExtendedString)
				return value;
            if (value is SqlRdfBox)
				return value;
            if (value is VirtuosoDateTime)
                return value;
            if (value is VirtuosoTimeSpan)
                return value;
#if ADONET3
            if (value is VirtuosoDateTimeOffset)
                return value;
#endif

            if (value is System.Byte[] && type != value.GetType())
                return value;
			if (type == typeof (string))
				return value.ToString ();

			throw new InvalidCastException ("Cannot convert parameter of type "
				+ value.GetType () + " into " + type.ToString ());
		}
	}

	internal abstract class BufferTypeFixed : BufferType
	{
		internal readonly int bufferSize;

		internal BufferTypeFixed (System.Type type, CLI.SqlCType sqlCType, int alignment, int bufferSize)
			: base (type, sqlCType, alignment, true)
		{
			this.bufferSize = bufferSize;
		}

		internal override int GetBufferSize (object value)
		{
			return bufferSize;
		}

		internal override int GetBufferSize (int valueSize)
		{
			return bufferSize;
		}
	}

	internal sealed class BufferTypeShort : BufferTypeFixed
	{
		internal BufferTypeShort ()
			: base (typeof (System.Int16), CLI.SqlCType.SQL_C_SHORT, 2, 2)
		{
		}

		internal override int ManagedToNative (object value, IntPtr buffer, int length)
		{
			Marshal.WriteInt16 (buffer, (short) value);
			return 0;
		}

		internal override object NativeToManaged (IntPtr buffer, int length)
		{
			return Marshal.ReadInt16 (buffer);
		}
	}

	internal sealed class BufferTypeBigInt : BufferTypeFixed
	{
		internal BufferTypeBigInt ()
			: base (typeof (System.Int64), CLI.SqlCType.SQL_C_BIGINT, 8, 8)
		{
		}

		internal override int ManagedToNative (object value, IntPtr buffer, int length)
		{
			Marshal.WriteInt64 (buffer, (long) value);
			return 0;
		}

		internal override object NativeToManaged (IntPtr buffer, int length)
		{
			return Marshal.ReadInt64 (buffer);
		}
	}

	internal sealed class BufferTypeLong : BufferTypeFixed
	{
		internal BufferTypeLong ()
			: base (typeof (System.Int32), CLI.SqlCType.SQL_C_LONG, 4, 4)
		{
		}

		internal override int ManagedToNative (object value, IntPtr buffer, int length)
		{
			Marshal.WriteInt32 (buffer, (int) value);
			return 0;
		}

		internal override object NativeToManaged (IntPtr buffer, int length)
		{
			return Marshal.ReadInt32 (buffer);
		}
	}

	internal sealed class BufferTypeFloat : BufferTypeFixed
	{
		internal BufferTypeFloat ()
			: base (typeof (System.Single), CLI.SqlCType.SQL_C_FLOAT, 4, 4)
		{
		}

		internal override int ManagedToNative (object value, IntPtr buffer, int length)
		{
			Marshal.StructureToPtr (value, buffer, false);
			return 0;
		}

		internal override object NativeToManaged (IntPtr buffer, int length)
		{
			return Marshal.PtrToStructure (buffer, typeof (System.Single));
		}
	}

	internal sealed class BufferTypeDouble : BufferTypeFixed
	{
		internal BufferTypeDouble ()
			: base (typeof (System.Double), CLI.SqlCType.SQL_C_DOUBLE, 8, 8)
		{
		}

		internal override int ManagedToNative (object value, IntPtr buffer, int length)
		{
			Marshal.StructureToPtr (value, buffer, false);
			return 0;
		}

		internal override object NativeToManaged (IntPtr buffer, int length)
		{
			return Marshal.PtrToStructure (buffer, typeof (System.Double));
		}
	}

	internal sealed class BufferTypeNumeric : BufferTypeFixed
	{
		internal BufferTypeNumeric ()
			: base (typeof (System.Decimal), CLI.SqlCType.SQL_C_NUMERIC, 4, 19)
		{
		}

		internal override int ManagedToNative (object value, IntPtr buffer, int length)
		{
			Decimal dec = (Decimal) value;
			int[] bits = System.Decimal.GetBits (dec);
			int lo = bits[0];
			int mid = bits[1];
			int hi = bits[2];
			byte sign = (byte) ((bits[3] & 0x80000000) != 0 ? 0 : 1);
			byte scale = (byte) ((bits[3] >> 16) & 0x7f);
			Marshal.WriteByte (buffer, 0, 0);
			Marshal.WriteByte (buffer, 1, scale);
			Marshal.WriteByte (buffer, 2, sign);
			Marshal.WriteInt32 (buffer, 3, lo);
			Marshal.WriteInt32 (buffer, 7, mid);
			Marshal.WriteInt32 (buffer, 11, hi);
			Marshal.WriteInt32 (buffer, 15, 0);
			return 0;
		}

		internal override object NativeToManaged (IntPtr buffer, int length)
		{
			//byte precision = Marshal.ReadByte (buffer, 0);
			byte scale = Marshal.ReadByte (buffer, 1);
			byte sign =  Marshal.ReadByte (buffer, 2);
			int lo = Marshal.ReadInt32 (buffer, 3);
			int mid = Marshal.ReadInt32 (buffer, 7);
			int hi = Marshal.ReadInt32 (buffer, 11);
			int extra = Marshal.ReadInt32 (buffer, 15);
			if (extra != 0)
				throw new Exception ("Too big decimal or numeric value");
			return new System.Decimal (lo, mid, hi, sign == 0, scale);
		}
	}

	internal sealed class BufferTypeDate : BufferTypeFixed
	{
		internal BufferTypeDate ()
			: base (typeof (System.DateTime), CLI.SqlCType.SQL_C_TYPE_DATE, 2, 6)
		{
		}

		internal override int ManagedToNative (object value, IntPtr buffer, int length)
		{
			DateTime dt = (System.DateTime) value;
			Marshal.WriteInt16 (buffer, 0, (short) dt.Year);
			Marshal.WriteInt16 (buffer, 2, (short) dt.Month);
			Marshal.WriteInt16 (buffer, 4, (short) dt.Day);
			return 6;
		}

		internal override object NativeToManaged (IntPtr buffer, int length)
		{
			short year = Marshal.ReadInt16 (buffer, 0);
			short month = Marshal.ReadInt16 (buffer, 2);
			short day = Marshal.ReadInt16 (buffer, 4);
			return new System.DateTime (year, month, day);
		}
	}

	internal sealed class BufferTypeTime : BufferTypeFixed
	{
		internal BufferTypeTime ()
			: base (typeof (System.TimeSpan), CLI.SqlCType.SQL_C_TYPE_TIME, 2, 6)
		{
		}

		internal override int ManagedToNative (object value, IntPtr buffer, int length)
		{
			TimeSpan ts = (System.TimeSpan) value;
			Marshal.WriteInt16 (buffer, 0, (short) ts.Hours);
			Marshal.WriteInt16 (buffer, 2, (short) ts.Minutes);
			Marshal.WriteInt16 (buffer, 4, (short) ts.Seconds);
			return 6;
		}

		internal override object NativeToManaged (IntPtr buffer, int length)
		{
			short hour = Marshal.ReadInt16 (buffer, 0);
			short minute = Marshal.ReadInt16 (buffer, 2);
			short second = Marshal.ReadInt16 (buffer, 4);
			return new System.TimeSpan (hour, minute, second);
		}
	}

	internal sealed class BufferTypeDateTime : BufferTypeFixed
	{
		internal BufferTypeDateTime ()
			: base (typeof (System.DateTime), CLI.SqlCType.SQL_C_TYPE_TIMESTAMP, 4, 16)
		{
		}

		internal override int ManagedToNative (object value, IntPtr buffer, int length)
		{
			DateTime dt = (System.DateTime) value;
			Marshal.WriteInt16 (buffer, 0, (short) dt.Year);
			Marshal.WriteInt16 (buffer, 2, (short) dt.Month);
			Marshal.WriteInt16 (buffer, 4, (short) dt.Day);
			Marshal.WriteInt16 (buffer, 6, (short) dt.Hour);
			Marshal.WriteInt16 (buffer, 8, (short) dt.Minute);
			Marshal.WriteInt16 (buffer, 10, (short) dt.Second);
			// ODBC timestamp fraction holds # of nanoseconds
			Marshal.WriteInt32 (buffer, 12, dt.Millisecond * Values.NanosPerMilliSec);
			return 16;
		}

		internal override object NativeToManaged (IntPtr buffer, int length)
		{
			short year = Marshal.ReadInt16 (buffer, 0);
			short month = Marshal.ReadInt16 (buffer, 2);
			short day = Marshal.ReadInt16 (buffer, 4);
			short hour = Marshal.ReadInt16 (buffer, 6);
			short minute = Marshal.ReadInt16 (buffer, 8);
			short second = Marshal.ReadInt16 (buffer, 10);
			int fraction = Marshal.ReadInt32 (buffer, 12);
			return new System.DateTime (year, month, day, hour, minute, second, fraction / Values.NanosPerMilliSec);
		}
	}

	internal sealed class BufferTypeChar : BufferType
	{
		internal BufferTypeChar ()
			: base (typeof (System.String), CLI.SqlCType.SQL_C_CHAR, 1)
		{
		}

		internal override int NullTermSize
		{
			get { return 1; }
		}

		internal override int GetBufferSize (object value)
		{
			Debug.Assert (value is string);
			return GetBufferSize (((string) value).Length);
		}

		internal override int GetBufferSize (int valueSize)
		{
			return valueSize + 1;
		}

		internal override int ManagedToNative (object value, IntPtr buffer, int length)
		{
			Encoding encoding = Encoding.GetEncoding (0);
			byte[] data = encoding.GetBytes ((string) value);
			int size = data.Length;
			if (size > length - 1)
				size = length - 1;
			Marshal.Copy (data, 0, buffer, size);
			return size;
		}

		internal override object NativeToManaged (IntPtr buffer, int length)
		{
			return Marshal.PtrToStringAnsi (buffer, length);
		}

		internal override object NativeSizeToManaged (int length)
		{
			return new char[length];
		}

		internal override void NativePartToManaged (IntPtr buffer, int length, object value, ref int offset)
		{
			string data = Marshal.PtrToStringAnsi (buffer, length);
			Array.Copy (data.ToCharArray (), 0, (char[]) value, offset, data.Length);
			offset += data.Length;
		}
	}

	internal sealed class BufferTypeWChar : BufferType
	{
		internal BufferTypeWChar ()
			: base (typeof (System.String), CLI.SqlCType.SQL_C_WCHAR, Platform.WideCharSize)
		{
		}

		internal override int NullTermSize
		{
			get { return Platform.WideCharSize; }
		}

		internal override int GetBufferSize (object value)
		{
			Debug.Assert (value is string);
			return GetBufferSize (((string) value).Length);
		}

		internal override int GetBufferSize (int valueSize)
		{
			return (valueSize + 1) * Platform.WideCharSize;
		}

		internal override int ManagedToNative (object value, IntPtr buffer, int length)
		{
			return Platform.StringToWideChars ((string) value, buffer, length);
		}

		internal override object NativeToManaged (IntPtr buffer, int length)
		{
			return Platform.WideCharsToString (buffer, length);
		}

		internal override object NativeSizeToManaged (int length)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "BufferTypeWChar.NativeSizeToManaged (length = " + length + ")");
			return new char[length / Platform.WideCharSize];
		}

		internal override void NativePartToManaged (IntPtr buffer, int length, object value, ref int offset)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "BufferTypeWChar.NativePartToManaged (length = " + length + ", offset = " + offset + ")");
			string data = Platform.WideCharsToString (buffer, length);
			Debug.WriteLineIf (Switch.Enabled, "value length = " + ((char[]) value).Length);
			Debug.WriteLineIf (Switch.Enabled, "data.Length = " + data.Length);
			Array.Copy (data.ToCharArray (), 0, (char[]) value, offset, data.Length);
			offset += data.Length;
		}
	}

	internal sealed class BufferTypeXml : BufferType
	{
		internal BufferTypeXml ()
			: base (typeof (SqlXml), CLI.SqlCType.SQL_C_WCHAR, Platform.WideCharSize)
		{
		}

		internal override int NullTermSize
		{
			get { return Platform.WideCharSize; }
		}

		internal override int GetBufferSize (object value)
		{
			Debug.Assert (value is SqlXml);
			return GetBufferSize (((SqlXml) value).ToString().Length);
		}

		internal override int GetBufferSize (int valueSize)
		{
			return (valueSize + 1) * Platform.WideCharSize;
		}

		internal override int ManagedToNative (object value, IntPtr buffer, int length)
		{
			return Platform.StringToWideChars (((SqlXml) value).ToString(), buffer, length);
		}

		internal override object NativeToManaged (IntPtr buffer, int length)
		{
			return new SqlXml (Platform.WideCharsToString (buffer, length));
		}

		internal override object NativeSizeToManaged (int length)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "BufferTypeWChar.NativeSizeToManaged (length = " + length + ")");
			return new char[length / Platform.WideCharSize];
		}

		internal override void NativePartToManaged (IntPtr buffer, int length, object value, ref int offset)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "BufferTypeWChar.NativePartToManaged (length = " + length + ", offset = " + offset + ")");
			string data = Platform.WideCharsToString (buffer, length);
			Debug.WriteLineIf (Switch.Enabled, "value length = " + ((char[]) value).Length);
			Debug.WriteLineIf (Switch.Enabled, "data.Length = " + data.Length);
			Array.Copy (data.ToCharArray (), 0, (char[]) value, offset, data.Length);
			offset += data.Length;
		}

		internal override object ConvertValue (object value)
		{
		        object ret = null;
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "BufferTypeSqlXml.ConvertValue (" + value + ")");
		        if (value is string)
			  ret = new SqlXml ((string) value);
			else if (value is XmlReader)
			  ret = new SqlXml ((XmlReader) value);
			else
			  ret = base.ConvertValue (value);
			return ret;
		}
	}

	internal sealed class BufferTypeBinary : BufferType
	{
		internal BufferTypeBinary ()
			: base (typeof (System.Byte[]), CLI.SqlCType.SQL_C_BINARY, 1)
		{
		}

		internal override int GetBufferSize (object value)
		{
			Debug.Assert (value is byte[]);
			return ((byte[]) value).Length;
		}

		internal override int GetBufferSize (int valueSize)
		{
			return valueSize;
		}

		internal override int ManagedToNative (object value, IntPtr buffer, int length)
		{
			byte[] data = (byte[]) value;
			if (length > data.Length)
				length = data.Length;
			Marshal.Copy (data, 0, buffer, length);
			return length;
		}

		internal override object NativeToManaged (IntPtr buffer, int length)
		{
			byte[] data = new byte[length];
			Marshal.Copy (buffer, data, 0, length);
			return data;
		}

		internal override object NativeSizeToManaged (int length)
		{
			return new byte[length];
		}

		internal override void NativePartToManaged (IntPtr buffer, int length, object value, ref int offset)
		{
			Marshal.Copy (buffer, (byte[]) value, offset, length);
			offset += length;
		}

		internal override object ConvertValue (object value)
		{
		        object ret = null;
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "BufferTypeBinary.ConvertValue (" + value + ")");
		        if (value != null && value is string)
			  ret = ConvertStringToBytes ((string) value, 
			      null, 
			      0, ((string)value).Length,
			      0);
			else
			  ret = base.ConvertValue (value);
			return ret;
		}

		internal static byte[] ConvertStringToBytes (string sv, 
		    byte [] buf, 
		    int bufferOffset, int length,
		    int fldOffset)
		  {

		    if (buf == null)
		      buf = new byte [length];
		    System.IO.MemoryStream ms = new System.IO.MemoryStream (
			buf, bufferOffset, length);
		    System.IO.BinaryWriter bw = new System.IO.BinaryWriter (ms, 
			System.Text.Encoding.GetEncoding ("iso-8859-1"));
		    bw.Write (sv.ToCharArray (fldOffset, length));
		    return buf;
		  }
	}

	internal sealed class BufferTypes
	{
		private BufferTypes () {} // Prevent instantiation

		internal static readonly BufferTypeShort Short = new BufferTypeShort ();
		internal static readonly BufferTypeLong Long = new BufferTypeLong ();
		internal static readonly BufferTypeBigInt BigInt = new BufferTypeBigInt ();
		internal static readonly BufferTypeFloat Float = new BufferTypeFloat ();
		internal static readonly BufferTypeDouble Double = new BufferTypeDouble ();
		internal static readonly BufferTypeNumeric Numeric = new BufferTypeNumeric ();
		internal static readonly BufferTypeDate Date = new BufferTypeDate ();
		internal static readonly BufferTypeTime Time = new BufferTypeTime ();
		internal static readonly BufferTypeDateTime DateTime = new BufferTypeDateTime ();
		internal static readonly BufferTypeChar Char = new BufferTypeChar ();
		internal static readonly BufferTypeWChar WChar = new BufferTypeWChar ();
		internal static readonly BufferTypeBinary Binary = new BufferTypeBinary ();
		internal static readonly BufferTypeXml Xml = new BufferTypeXml ();

		internal static BufferType InferBufferType (object value)
		{
			if (value == null)
				return null;

			Type type = value.GetType ();
			switch (Type.GetTypeCode (type))
			{
				case TypeCode.DBNull:			return null;
				case TypeCode.Int16:			return Short;
				case TypeCode.Int32:			return Long;
				case TypeCode.Int64:			return BigInt;
				case TypeCode.Single:			return Float;
				case TypeCode.Double:			return Double;
				case TypeCode.Decimal:			return Numeric;
				case TypeCode.DateTime:			return DateTime;
				case TypeCode.String:			return WChar;
				case TypeCode.Object:
					if (value is IConvertData)
						return ((IConvertData) value).GetDataType ();
					if (type == typeof (System.TimeSpan))
						return Time;
					if (type == typeof (VirtuosoTimeSpan))
						return Time;
					if (type == typeof (VirtuosoDateTime))
						return DateTime;
#if ADONET3
					if (type == typeof (VirtuosoDateTimeOffset))
						return DateTime;
#endif
					if (type == typeof (byte[]))
						return Binary;
					if (type == typeof (SqlXml))
					  	return Xml;
					break;
			}
			return null;
		}
	}
}
