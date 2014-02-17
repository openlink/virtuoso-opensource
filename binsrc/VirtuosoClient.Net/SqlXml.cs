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
using System.Xml;
using System.Diagnostics;
using System.Text;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
  /// <summary>
  /// Summary description for SqlXml.
  /// </summary>
  public sealed class SqlXml : IMarshal
    {
      private string m_string;
      private XmlReader m_reader;

      internal static TraceSwitch Switch = new TraceSwitch("SqlXml", "SqlXml support");

      public SqlXml (XmlReader x)
	{
	  Debug.WriteLineIf (CLI.FnTrace.Enabled, "SqlXml.ctor (XmlReader)");
	  m_reader = x;
	  m_string = null;
	}

      public SqlXml (String s)
	{
	  Debug.WriteLineIf (CLI.FnTrace.Enabled, "SqlXml.ctor (String)");
	  m_reader = null;
	  m_string = s;
	}

      public override string ToString()
	{
	  Debug.WriteLineIf (CLI.FnTrace.Enabled, "SqlXml.ToString ()");
	  if (m_string != null)
	    return m_string;
	  else
	    {
	      StringBuilder bld = new StringBuilder ();
	      while (m_reader.Read())
		{
		  bld.Append (m_reader.ReadOuterXml ());
		}
	      return bld.ToString ();
	    }
	}

      public XmlReader CreateReader ()
	{
	  Debug.WriteLineIf (CLI.FnTrace.Enabled, "SqlXml.CreateReader ()");
	  if (m_reader != null)
	    return m_reader;
	  else
	    return new XmlTextReader (
		m_string, 
		XmlNodeType.Element, 
		new XmlParserContext (
		  null, // NameTable
		  null, // NamespaceManager
		  null, // xml:lang
		  XmlSpace.None)
		);
	}

#region IMarshal implementation
      public void Marshal(System.IO.Stream stream)
	{ /* marshal it as DV_WIDE */
	  String str = ToString ();
	  byte [] bytes = Encoding.UTF8.GetBytes (str);
	  if (bytes.Length < 256)
	    {
	      stream.WriteByte ((byte) BoxTag.DV_WIDE);
	      stream.WriteByte ((byte) bytes.Length);
	    }
	  else
	    {
	      stream.WriteByte ((byte) BoxTag.DV_LONG_WIDE);
	      Marshaler.MarshalLongInt (stream, bytes.Length);
	    }
	  stream.Write (bytes, 0, bytes.Length);
	}
#endregion
    }
}
