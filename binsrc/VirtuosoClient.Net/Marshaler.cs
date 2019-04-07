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

//#define IGNORE_ENCODING

using System;
using System.Collections;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal sealed class Marshaler
	{
		private Marshaler () {}

		internal readonly static BooleanSwitch marshalSwitch;

		static Marshaler ()
		{
			marshalSwitch = new BooleanSwitch ("VirtuosoClient.Marshal", "Marshaling");
			Debug.AutoFlush = true; // work around web.config ignoring autoflush
		}

		internal static byte[] Encode (Hashtable map, string value)
		{
			if (value == null)
				return null;

			byte[] bytes = new byte[value.Length];
			for (int i = 0; i < value.Length; i++)
			{
				char c = value[i];
				if (map == null)
					bytes[i] = (byte) c;
				else
				{
					object b = map[c];
					if (b == null)
						bytes[i] = (byte) '?';
					else
						bytes[i] = (byte) b;
				}
				Debug.WriteLineIf (marshalSwitch.Enabled, "Encode: " + c + " -> " + (char) bytes[i]);
			}
			return bytes;
		}

		internal static string Decode (string table, byte[] value)
		{
			if (value == null)
				return null;
			if (value.Length == 0)
				return String.Empty;

			StringBuilder sb = new StringBuilder ();
			for (int i = 0; i < value.Length; i++)
			{
				byte b = value[i];
				if (table == null || b == 0 || b > table.Length)
					sb.Append ((char) b);
				else
					sb.Append (table[b - 1]);
			}
			return sb.ToString ();
		}

		internal static void Marshal (Stream stream, Hashtable map, object value)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "Marshaler.Marshal ()");

			if (value == null)
			{
				Debug.WriteLineIf (marshalSwitch.Enabled, "value: null");
#if false
				throw new ArgumentNullException ("value");
#else
				stream.WriteByte ((byte) BoxTag.DV_NULL);
				return;
#endif
			}

			Debug.WriteLineIf (marshalSwitch.Enabled, "value: " + value);

			if (value is IMarshal)
			{
				Debug.WriteLineIf (marshalSwitch.Enabled, "type: " + value.GetType ());
				((IMarshal) value).Marshal (stream);
				return;
			}

			Type type = value.GetType ();
			TypeCode typeCode = Type.GetTypeCode (type);
			Debug.WriteLineIf (marshalSwitch.Enabled, "type: " + type);
			Debug.WriteLineIf (marshalSwitch.Enabled, "typeCode: " + typeCode);
#if !WIN32_ONLY
			// Work around Mono bug returning TypeCode Object for DBNull.
			if (value == DBNull.Value && typeCode != TypeCode.DBNull)
			    typeCode = TypeCode.DBNull;
#endif
			switch (typeCode)
			{
			case TypeCode.DBNull:
				stream.WriteByte ((byte) BoxTag.DV_DB_NULL);
				return;

			case TypeCode.Int16:
				MarshalInt (stream, (short) value);
				return;

			case TypeCode.Int32:
				MarshalInt (stream, (int) value);
				return;

			case TypeCode.Int64:
			        stream.WriteByte ((byte) BoxTag.DV_INT64);
				MarshalLongInt64 (stream, (Int64) value);
				return;

			case TypeCode.Single:
				stream.WriteByte ((byte) BoxTag.DV_SINGLE_FLOAT);
				MarshalSingle (stream, (float) value);
				return;

			case TypeCode.Double:
				stream.WriteByte ((byte) BoxTag.DV_DOUBLE_FLOAT);
				MarshalDouble (stream, (double) value);
				return;

			case TypeCode.String:
			{
				string s = (string) value;
#if IGNORE_ENCODING
				byte[] bytes = Encoding.GetEncoding ("iso-8859-1").GetBytes (s);
#else
				byte[] bytes = Encode (map, s);
#endif
				if (bytes.Length < 256)
				{
					stream.WriteByte ((byte) BoxTag.DV_SHORT_STRING_SERIAL);
					stream.WriteByte ((byte) bytes.Length);
				}
				else
				{
					stream.WriteByte ((byte) BoxTag.DV_STRING);
					MarshalLongInt (stream, bytes.Length);
				}
				stream.Write (bytes, 0, bytes.Length);
				return;
			}

			case TypeCode.Decimal:
			{
				MarshalNumeric (stream, (decimal) value);
				return;
			}

			case TypeCode.DateTime:
			{
				DateTimeMarshaler.MarshalDate (stream, value, DateTimeType.DT_TYPE_DATETIME);
				return;
			}

			case TypeCode.Object:
				if (type == typeof (TimeSpan))
				{
					DateTimeMarshaler.MarshalDate (stream, value, DateTimeType.DT_TYPE_TIME);
				}
				else if (type == typeof (VirtuosoTimeSpan))
				{
					DateTimeMarshaler.MarshalDate (stream, value, DateTimeType.DT_TYPE_TIME);
				}
				else if (type == typeof(VirtuosoDateTime))
				{
					DateTimeMarshaler.MarshalDate (stream, value, DateTimeType.DT_TYPE_DATETIME);
				}
#if ADONET3
				else if (type == typeof(VirtuosoDateTimeOffset))
				{
					DateTimeMarshaler.MarshalDate (stream, value, DateTimeType.DT_TYPE_DATETIME);
				}
#endif
				else if (type == typeof (int[]))
				{
					stream.WriteByte ((byte) BoxTag.DV_ARRAY_OF_LONG);

					int[] array = (int[]) value;
					MarshalInt (stream, array.Length);
					for (int i = 0; i < array.Length; i++)
						MarshalLongInt (stream, array[i]);
				}
				else if (type == typeof (float[]))
				{
					stream.WriteByte ((byte) BoxTag.DV_ARRAY_OF_FLOAT);

					float[] array = (float[]) value;
					MarshalInt (stream, array.Length);
					for (int i = 0; i < array.Length; i++)
						MarshalSingle (stream, array[i]);
				}
				else if (type == typeof (double[]))
				{
					stream.WriteByte ((byte) BoxTag.DV_ARRAY_OF_DOUBLE);

					double[] array = (double[]) value;
					MarshalInt (stream, array.Length);
					for (int i = 0; i < array.Length; i++)
						MarshalDouble (stream, array[i]);
				}
				else if (type == typeof (object[]))
				{
					stream.WriteByte ((byte) BoxTag.DV_ARRAY_OF_POINTER);

					object[] array = (object[]) value;
					MarshalInt (stream, array.Length);
					for (int i = 0; i < array.Length; i++)
						Marshal (stream, map, array[i]);
				}
				else if (type == typeof (BlobHandle))
				{
					MarshalBlobHandle (stream, (BlobHandle) value);
				}
				else if (type == typeof (byte[]))
				{
					byte[] bytes = (byte[]) value;
#if true
					if (bytes.Length < 256)
					{
						stream.WriteByte ((byte) BoxTag.DV_BIN);
						stream.WriteByte ((byte) bytes.Length);
					}
					else
					{
						stream.WriteByte ((byte) BoxTag.DV_LONG_BIN);
						MarshalLongInt (stream, bytes.Length);
					}
					stream.Write (bytes, 0, bytes.Length);
#else
					stream.Write (bytes, 0, bytes.Length);
#endif
				}
				else
					goto default;
				return;

			default:
				throw new ArgumentException ("Unsupported value type", "value");
			}
		}

		internal static object Unmarshal (Stream stream, ManagedConnection connection)
		{
		        string table = connection == null ? null : connection.charsetTable;
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "Marshaler.Unmarshal ()");

			BoxTag tag = (BoxTag) ReadByte (stream);
			Debug.WriteLineIf (marshalSwitch.Enabled, "tag: " + tag);

			switch (tag)
			{
			case BoxTag.DV_NULL:
#if false
				return null;
#else
				return 0;
#endif

			case BoxTag.DV_DB_NULL:
				return DBNull.Value;

			case BoxTag.DV_ARRAY_OF_POINTER:
			case BoxTag.DV_LIST_OF_POINTER:
			{
				int n = UnmarshalInt (stream);
				object[] array = new object[n];
				Debug.WriteLineIf (marshalSwitch.Enabled, "array start [" + n + "] {");
				for (int i = 0; i < n; i++)
					array[i] = Unmarshal (stream, connection);
				Debug.WriteLineIf (marshalSwitch.Enabled, "array end");
				return array;
			}

			case BoxTag.DV_ARRAY_OF_LONG:
			{
				int n = UnmarshalInt (stream);
				int[] array = new int[n];
				Debug.WriteLineIf (marshalSwitch.Enabled, "array start [" + n + "] {");
				for (int i = 0; i < n; i++)
					array[i] = UnmarshalLongInt (stream);
				Debug.WriteLineIf (marshalSwitch.Enabled, "array end");
				return array;
			}

			case BoxTag.DV_ARRAY_OF_LONG_PACKED:
			{
				int n = UnmarshalInt (stream);
				int[] array = new int[n];
				Debug.WriteLineIf (marshalSwitch.Enabled, "array start [" + n + "] {");
				for (int i = 0; i < n; i++)
					array[i] = UnmarshalLongInt (stream);
				Debug.WriteLineIf (marshalSwitch.Enabled, "array end");
				return array;
			}

			case BoxTag.DV_ARRAY_OF_FLOAT:
			{
				int n = UnmarshalInt (stream);
				float[] array = new float[n];
				Debug.WriteLineIf (marshalSwitch.Enabled, "array start [" + n + "] {");
				for (int i = 0; i < n; i++)
					array[i] = UnmarshalSingle (stream);
				Debug.WriteLineIf (marshalSwitch.Enabled, "array end");
				return array;
			}

			case BoxTag.DV_ARRAY_OF_DOUBLE:
			{
				int n = UnmarshalInt (stream);
				double[] array = new double[n];
				Debug.WriteLineIf (marshalSwitch.Enabled, "array start [" + n + "] {");
				for (int i = 0; i < n; i++)
					array[i] = UnmarshalDouble (stream);
				Debug.WriteLineIf (marshalSwitch.Enabled, "array end");
				return array;
			}

			case BoxTag.DV_LONG_WIDE:
			{
				int i = 0, n = UnmarshalLongInt (stream);
				byte[] bytes = new byte[n];
				while (i < n)
					i += stream.Read (bytes, i, n - i);
				return Encoding.UTF8.GetString (bytes);
			}

			case BoxTag.DV_WIDE:
			{
				int i = 0, n = UnmarshalShortInt (stream);
				byte[] bytes = new byte[n];
				while (i < n)
					i += stream.Read (bytes, i, n - i);
				return Encoding.UTF8.GetString (bytes);
			}

			case BoxTag.DV_C_STRING:
			case BoxTag.DV_STRING:
			case BoxTag.DV_LONG_CONT_STRING:
			{
				int i = 0, n = UnmarshalLongInt (stream);
				byte[] bytes = new byte[n];
				while (i < n)
					i += stream.Read (bytes, i, n - i);
#if IGNORE_ENCODING
				return Encoding.GetEncoding("iso-8859-1").GetString (bytes);
#else
				if (connection.charset_utf8)
                                  return Encoding.UTF8.GetString (bytes);
				else
				  return Decode (table, bytes);
#endif
			}

			case BoxTag.DV_BOX_FLAGS:
			{
				int flags = UnmarshalLongInt (stream);
				object str = Unmarshal (stream, connection);
				return new SqlExtendedString(str.ToString(), flags);
			}

			case BoxTag.DV_RDF:
			{
      				int flags = ReadByte (stream);
				object box;
      				short type;
      				short lang;
      				bool is_complete = false;
      				long ro_id = 0L;

      				if (0 != (flags & (int)SqlRdfBoxFlags.RBS_CHKSUM))
				    throw new SystemException ("Invalid rdf box received.");

      				box = Unmarshal (stream, connection);
      				if (0 != (flags & (int)SqlRdfBoxFlags.RBS_OUTLINED))
      				  {
				    if (0 != (flags & (int)SqlRdfBoxFlags.RBS_64))
	  				ro_id = UnmarshalInt64 (stream);
				    else
	  				ro_id = UnmarshalLongInt (stream);
      				  }

      				if (0 != (flags & (int)SqlRdfBoxFlags.RBS_COMPLETE))
				    is_complete = true; 

      				if (0 != (flags & (int)SqlRdfBoxFlags.RBS_HAS_TYPE))
				    type = UnmarshalShort (stream);
      				else 
				    type = SqlRdfBox.DEFAULT_TYPE;

      				if (0 != (flags & (int)SqlRdfBoxFlags.RBS_HAS_LANG))
				    lang = UnmarshalShort (stream);
      				else 
				    lang = SqlRdfBox.DEFAULT_LANG;
      				return new SqlRdfBox (connection, box, is_complete, type, lang, ro_id);
			}

			case BoxTag.DV_C_SHORT:
			case BoxTag.DV_SHORT_STRING_SERIAL:
			case BoxTag.DV_SHORT_CONT_STRING:
			{
				int i = 0, n = UnmarshalShortInt (stream);
				byte[] bytes = new byte[n];
				while (i < n)
					i += stream.Read (bytes, i, n - i);
#if IGNORE_ENCODING
				return Encoding.GetEncoding("iso-8859-1").GetString (bytes);
#else
				if (connection.charset_utf8)
                                  return Encoding.UTF8.GetString (bytes);
				else
				  return Decode (table, bytes);
#endif
			}

			case BoxTag.DV_LONG_BIN:
			{
				int i = 0, n = UnmarshalLongInt (stream);
				byte[] bytes = new byte[n];
				while (i < n)
					i += stream.Read (bytes, i, n - i);
				return bytes;
			}

			case BoxTag.DV_BIN:
			{
				int i = 0, n = UnmarshalShortInt (stream);
				byte[] bytes = new byte[n];
				while (i < n)
					i += stream.Read (bytes, i, n - i);
				return bytes;
			}

			case BoxTag.DV_SINGLE_FLOAT:
				return UnmarshalSingle (stream);

			case BoxTag.DV_IRI_ID:
				return UnmarshalLongInt (stream);

			case BoxTag.DV_IRI_ID_8:
			case BoxTag.DV_INT64:
				return UnmarshalInt64 (stream);

			case BoxTag.DV_DOUBLE_FLOAT:
				return UnmarshalDouble (stream);

			case BoxTag.DV_SHORT_INT:
			{
				int i = UnmarshalShortInt (stream);
				if (i > 127)
					i -= 256;
				return i;
			}

			case BoxTag.DV_LONG_INT:
				return UnmarshalLongInt (stream);

			case BoxTag.DV_DATETIME:
			case BoxTag.DV_DATE:
			case BoxTag.DV_TIME:
			case BoxTag.DV_TIMESTAMP:
			case BoxTag.DV_TIMESTAMP_OBJ:
				return DateTimeMarshaler.UnmarshalDate (stream);

			case BoxTag.DV_NUMERIC:
				return UnmarshalNumeric (stream);

			case BoxTag.DV_BLOB_HANDLE:
			case BoxTag.DV_BLOB_WIDE_HANDLE:
				return UnmarshalBlobHandle (stream, tag);

			case BoxTag.DV_OBJECT:
				return UnmarshalObject (stream);

			case BoxTag.DV_STRING_SESSION:
				return UnmarshalStrses (stream);

			default:
				throw new SystemException ("Unknown data type " + tag + ".");
			}
		}

		internal static byte ReadByte (Stream stream)
		{
			int i = stream.ReadByte ();
			if (i == -1)
				throw new EndOfStreamException ();
			return (byte) i;
		}

		internal static void MarshalInt (Stream stream, int value)
		{
			if (value > 127 || value < -128)
			{
				stream.WriteByte ((byte) BoxTag.DV_LONG_INT);
				MarshalLongInt (stream, value);
			}
			else
			{
				stream.WriteByte ((byte) BoxTag.DV_SHORT_INT);
				MarshalShortInt (stream, value);
			}
		}

		internal static int UnmarshalInt (Stream stream)
		{
			BoxTag tag = (BoxTag) ReadByte (stream);
			return tag == BoxTag.DV_SHORT_INT ? UnmarshalShortInt (stream) : UnmarshalLongInt (stream);
		}

		internal static void MarshalShortInt (Stream stream, int value)
		{
			stream.WriteByte ((byte) value);
		}

		internal static int UnmarshalShortInt (Stream stream)
		{
			return ReadByte (stream);
		}

		internal static void MarshalShort (Stream stream, short value)
		{
			stream.WriteByte ((byte) (value >> 8));
			stream.WriteByte ((byte) value);
		}

		internal static void MarshalLongInt (Stream stream, int value)
		{
			stream.WriteByte ((byte) (value >> 24));
			stream.WriteByte ((byte) (value >> 16));
			stream.WriteByte ((byte) (value >> 8));
			stream.WriteByte ((byte) value);
		}

		internal static void MarshalLongInt64 (Stream stream, Int64 value)
		{
			stream.WriteByte ((byte) (value >> 56));
			stream.WriteByte ((byte) (value >> 48));
			stream.WriteByte ((byte) (value >> 40));
			stream.WriteByte ((byte) (value >> 32));
			stream.WriteByte ((byte) (value >> 24));
			stream.WriteByte ((byte) (value >> 16));
			stream.WriteByte ((byte) (value >> 8));
			stream.WriteByte ((byte) value);
		}

		internal static short UnmarshalShort (Stream stream)
		{
			int b1 = ReadByte (stream);
			int b2 = ReadByte (stream);
			return (short)((b1 << 8) | b2);
		}

		internal static int UnmarshalLongInt (Stream stream)
		{
			int b1 = ReadByte (stream);
			int b2 = ReadByte (stream);
			int b3 = ReadByte (stream);
			int b4 = ReadByte (stream);
			return (b1 << 24) | (b2 << 16) | (b3 << 8) | b4;
		}

		internal static Int64 UnmarshalInt64 (Stream stream)
		{
			long ret;
			ret = ((long)ReadByte(stream) & 0xff) << 56;
			ret |= ((long)ReadByte(stream) & 0xff) << 48;
			ret |= ((long)ReadByte(stream) & 0xff) << 40;
			ret |= ((long)ReadByte(stream) & 0xff) << 32;
			ret |= ((long)ReadByte(stream) & 0xff) << 24;
			ret |= ((long)ReadByte(stream) & 0xff) << 16;
			ret |= ((long)ReadByte(stream) & 0xff) << 8;
			ret |= ((long)ReadByte(stream) & 0xff);
			return ret;
		} 

		internal static unsafe void MarshalSingle (Stream stream, float value)
		{
			int* ip = (int*) &value;
			MarshalLongInt (stream, *ip);
		}

		internal static unsafe float UnmarshalSingle (Stream stream)
		{
			int i = UnmarshalLongInt (stream);
			float* fp = (float*) &i;
			return *fp;
		}

		internal static unsafe void MarshalDouble (Stream stream, double value)
		{
			ulong* lp = (ulong*) &value;
			MarshalLongInt (stream, (int) (*lp >> 32));
			MarshalLongInt (stream, (int) *lp);
		}

		internal static unsafe double UnmarshalDouble (Stream stream)
		{
			ulong l = ((ulong) (uint) UnmarshalLongInt (stream) << 32) | (ulong) (uint) UnmarshalLongInt (stream);
			double* dp = (double*) &l;
			return *dp;
		}

		internal static void MarshalNumeric (Stream stream, decimal value)
		{
			NumericFlags flags = 0;
			if (value < 0)
			{
				flags |= NumericFlags.NDF_NEG;
				value = -value;
			}

			string s = value.ToString ();
			int length = s.Length;
			int point_index = s.IndexOf ('.');
			int integer_length = point_index < 0 ? length : point_index;
			int byte_length = length / 2;
			int byte_integer_length = integer_length / 2;
			if ((integer_length & 1) != 0)
			{
				byte_length++;
				byte_integer_length++;
				flags |= NumericFlags.NDF_LEAD0;
			}
			int fraction_length = point_index < 0 ? 0 : length - point_index - 1;
			if ((fraction_length & 1) != 0)
			{
				byte_length++;
				flags |= NumericFlags.NDF_TRAIL0;
			}

			stream.WriteByte ((byte) BoxTag.DV_NUMERIC);
			stream.WriteByte ((byte) (byte_length + 2));
			stream.WriteByte ((byte) flags);
			stream.WriteByte ((byte) byte_integer_length);

			int i = 0;
			if ((flags & NumericFlags.NDF_LEAD0) != 0)
				stream.WriteByte ((byte) (s[i++] - '0'));
			for (; i < integer_length; i += 2)
				stream.WriteByte ((byte) (((s[i] - '0') << 4) | (s[i + 1] - '0')));
			if (fraction_length == 0)
				return;

			int even_end = (flags & NumericFlags.NDF_TRAIL0) != 0 ? length - 1 : length;
			for (i++; i < even_end; i += 2)
				stream.WriteByte ((byte) (((s[i] - '0') << 4) | (s[i + 1] - '0')));
			if (i < length)
				stream.WriteByte ((byte) ((s[i] - '0') << 4));
		}

		internal static object UnmarshalNumeric (Stream stream)
		{
			char[] chars;
			int byte_length = ReadByte (stream);
			NumericFlags flags = (NumericFlags) ReadByte (stream);
			int byte_integer_length = ReadByte (stream);
			byte_length -= 2;

			int length = byte_length * 2;
			int integer_length = byte_integer_length * 2;
			if (length == 0 && integer_length == 0 
				&& flags == 0)
			{
				chars = new char[1];
				chars[0] = '0';
			}
			else
			{
				if ((flags & NumericFlags.NDF_LEAD0) != 0)
				{
					length--;
					integer_length--;
				}
				if ((flags & NumericFlags.NDF_TRAIL0) != 0)
				{
					length--;
				}
        
				int fraction_length = length - integer_length;
				if (fraction_length != 0)
					length++; // for decimal point
        
				chars = new char[length];
        
				int i = 0;
				byte read;
				if ((flags & NumericFlags.NDF_LEAD0) != 0)
				{
					read = ReadByte (stream);
					chars[i++] = (char) ((read & 0x0f) + '0');
				}
				while (i < integer_length)
				{
					read = ReadByte (stream);
					chars[i++] = (char) (((read >> 4) & 0x0f) + '0');
					chars[i++] = (char) ((read & 0x0f) + '0');
				}
				if (fraction_length != 0)
				{
					chars[i++] = '.';
					int even_fraction_length = ((flags & NumericFlags.NDF_TRAIL0) != 0
						? length - 1 : length);
					while (i < even_fraction_length)
					{
						read = ReadByte (stream);
						chars[i++] = (char) (((read >> 4) & 0x0f) + '0');
						chars[i++] = (char) ((read & 0x0f) + '0');
					}
					if (i < length)
					{
						read = (byte) ReadByte (stream);
						chars[i++] = (char) (((read >> 4) & 0x0f) + '0');
					}
				}
        
				if ((flags & NumericFlags.NDF_NAN) != 0)
					throw new InvalidCastException ("Cannot convert a NAN value to Decimal.");
				if ((flags & NumericFlags.NDF_INF) != 0)
					throw new InvalidCastException ("Cannot convert an INF value to Decimal.");
			}
        
			String s = new String (chars);
			Decimal value = Decimal.Parse (s, NumberStyles.AllowDecimalPoint, NumberFormatInfo.InvariantInfo);
			if ((flags & NumericFlags.NDF_NEG) != 0)
				value = -value;
			return value;
		}

		internal static void MarshalBlobHandle (Stream stream, BlobHandle blob)
		{
			stream.WriteByte ((byte) blob.tag);
			MarshalLongInt (stream, blob.ask);
			MarshalLongInt (stream, blob.page);
			MarshalLongInt (stream, blob.length);
			MarshalLongInt (stream, blob.keyId);
			MarshalLongInt (stream, blob.fragNo);
			MarshalLongInt (stream, blob.dirPage);
			MarshalLongInt (stream, blob.timeStamp);
			Marshal (stream, null, blob.pages);
		}

		internal static object UnmarshalBlobHandle (Stream stream, BoxTag tag)
		{
			int ask = UnmarshalLongInt (stream);
			int page = UnmarshalLongInt (stream);
			int length = UnmarshalLongInt (stream);
			int keyId = UnmarshalLongInt (stream);
			int fragNo = UnmarshalLongInt (stream);
			int dirPage = UnmarshalLongInt (stream);
			int timeStamp = UnmarshalLongInt (stream);
			object pages  = Unmarshal (stream, null);
			return new BlobHandle (ask, page, length, keyId, fragNo, dirPage, timeStamp, pages, tag);
		}

		internal static object UnmarshalObject (Stream stream)
		{
			/*
			int objId = ReadLongInt ();
			object value = Unmarshal ();
			if (value is string)
			{
				try
				{
				}
				catch (Exception)
				{
					value = null;
				}
			}
			return value;
			*/
			throw new NotImplementedException ("Session::ReadObject() is not yet implemented.");
		}

		internal static object UnmarshalStrses (Stream stream)
		  {
		    StringBuilder sb = new StringBuilder ();

		    int flags = ReadByte (stream);

		    System.Text.Encoding enc = System.Text.Encoding.GetEncoding (
			(flags & 0x1) != 0 ? "utf-8" : "iso-8859-1");
		    do
		      {
			BoxTag part_tag = (BoxTag) ReadByte (stream);

			if (part_tag != BoxTag.DV_STRING &&
			    part_tag != BoxTag.DV_SHORT_STRING_SERIAL)
			  {
			    throw new SystemException (
				"Invalid data (tag=" + 
				part_tag + 
				") in deserializing a string session");
			  }
			int n = (part_tag == BoxTag.DV_STRING) ? 
			    UnmarshalLongInt (stream) : ReadByte (stream);

			if (n > 0)
			  {
			    byte [] buffer = new byte[n];
			    for (int ofs = stream.Read (buffer, 0, n); 
				ofs != n; 
				ofs += stream.Read(buffer, ofs, n - ofs));

			    sb.Append (enc.GetString (buffer));
			  }
			else
			  break;
		      }
		    while (true);
		    return sb.ToString (); 
		  }
	}
}
