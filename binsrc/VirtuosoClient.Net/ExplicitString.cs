//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2018 OpenLink Software
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
using System.Collections;
using System.Diagnostics;
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
	internal sealed class ShortString : IMarshal
	{
		private byte[] bytes;

		internal ShortString (byte[] bytes)
		{
			Debug.Assert (bytes != null);
			Debug.Assert (bytes.Length < 256);
			this.bytes = bytes;
		}

		public void Marshal (Stream stream)
		{
			Debug.WriteLineIf (Marshaler.marshalSwitch.Enabled, "ShortString.Marshal ()");
			stream.WriteByte ((byte) BoxTag.DV_SHORT_STRING_SERIAL);
			stream.WriteByte ((byte) bytes.Length);
			stream.Write (bytes, 0, bytes.Length);
		}
	}

	internal sealed class LongString : IMarshal
	{
		private byte[] bytes;

		internal LongString (byte[] bytes)
		{
			Debug.Assert (bytes != null);
			this.bytes = bytes;
		}

		public void Marshal (Stream stream)
		{
			Debug.WriteLineIf (Marshaler.marshalSwitch.Enabled, "LongString.Marshal ()");
			stream.WriteByte ((byte) BoxTag.DV_STRING);
			Marshaler.MarshalLongInt (stream, bytes.Length);
			stream.Write (bytes, 0, bytes.Length);
		}
	}

	internal sealed class ShortWideString : IMarshal
	{
		private byte[] bytes;

		internal ShortWideString (byte[] bytes)
		{
			Debug.Assert (bytes != null);
			Debug.Assert (bytes.Length < 256);
			this.bytes = bytes;
		}

		public void Marshal (Stream stream)
		{
			Debug.WriteLineIf (Marshaler.marshalSwitch.Enabled, "ShortWideString.Marshal ()");
			stream.WriteByte ((byte) BoxTag.DV_WIDE);
			stream.WriteByte ((byte) bytes.Length);
			stream.Write (bytes, 0, bytes.Length);
		}
	}

	internal sealed class LongWideString : IMarshal
	{
		private byte[] bytes;

		internal LongWideString (byte[] bytes)
		{
			Debug.Assert (bytes != null);
			this.bytes = bytes;
		}

		public void Marshal (Stream stream)
		{
			Debug.WriteLineIf (Marshaler.marshalSwitch.Enabled, "LongWideString.Marshal ()");
			stream.WriteByte ((byte) BoxTag.DV_LONG_WIDE);
			Marshaler.MarshalLongInt (stream, bytes.Length);
			stream.Write (bytes, 0, bytes.Length);
		}
	}

	internal sealed class ExplicitString
	{
		private ExplicitString () {}

		internal static IMarshal CreateExecString (ManagedConnection connection, string value)
		{
			Debug.WriteLineIf (Marshaler.marshalSwitch.Enabled, "ExplicitString (" + value + ")");
            		byte[] bytes;
			if (connection.charset_utf8) 
			  bytes = WideToUTF8 (value);
			else
			  bytes = connection.utf8Execs
				? WideToUTF8 ("\n--utf8_execs=yes\n"+value)
				: WideToEscaped (connection.charsetMap, value);

			return ((bytes.Length < 256)
				? (IMarshal) new ShortString (bytes)
				: (IMarshal) new LongString (bytes));
		}


		internal static IMarshal CreateExplicitString (string s, BoxTag tag, ManagedConnection connection)
		{
			switch (tag)
			{
			case BoxTag.DV_WIDE:
			case BoxTag.DV_LONG_WIDE:
			case BoxTag.DV_BLOB_WIDE:
			{
				byte[] bytes = Encoding.UTF8.GetBytes (s);
				return ((bytes.Length < 256)
					? (IMarshal) new ShortWideString (bytes)
					: (IMarshal) new LongWideString (bytes));
			}

			case BoxTag.DV_STRING:
			case BoxTag.DV_SHORT_STRING_SERIAL:
			case BoxTag.DV_STRICT_STRING:
			case BoxTag.DV_C_STRING:
			case BoxTag.DV_BLOB:
			{
				byte[] bytes;
				if (connection.charset_utf8) 
					bytes = Encoding.UTF8.GetBytes (s);
				else
					bytes = Encoding.GetEncoding ("iso-8859-1").GetBytes (s);
				return ((bytes.Length < 256)
					? (IMarshal) new ShortString (bytes)
					: (IMarshal) new LongString (bytes));
			}

			case BoxTag.DV_BIN:
			case BoxTag.DV_BLOB_BIN:
			{
				byte[] bytes = Encoding.GetEncoding ("iso-8859-1").GetBytes (s);
				return ((bytes.Length < 256)
					? (IMarshal) new ShortString (bytes)
					: (IMarshal) new LongString (bytes));
			}

			default:
				// TODO:
				break;
			}

			return null;
		}

		private static byte[] WideToUTF8 (string value)
		{
			if (value == null)
				return null;
			if (value == String.Empty)
				return new byte[0];

		        return Encoding.UTF8.GetBytes(value);
		}

		private static byte[] WideToEscaped (Hashtable map, string value)
		{
			if (value == null)
				return null;
			if (value == String.Empty)
				return new byte[0];

			MemoryStream buffer = new MemoryStream (value.Length);
			StreamWriter writer = new StreamWriter (buffer, Encoding.GetEncoding ("iso-8859-1"));
			for (int i = 0; i < value.Length; i++)
			{
				char c = value[i];
				if (map == null)
				{
					if ((int) c < 256)
						writer.Write (c);
					else
						writer.Write ("\\x{0:x}", (int) c);
				}
				else
				{
					object b = map[c];
					if (b == null)
						writer.Write ("\\x{0:x}", (int) c);
					else
						writer.Write ((char) (byte) b);
				}
			}
			writer.Flush ();
			buffer.Close ();
			return buffer.ToArray ();
		}
	}
}
