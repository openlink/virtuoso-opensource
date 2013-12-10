//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2013 OpenLink Software
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
  public enum SqlExtendedStringType {
	IRI = 1,
	BNODE = 2,
  }

  public sealed class SqlExtendedString
    {
      private string str;
      private SqlExtendedStringType strType;
      private SqlExtendedStringType iriType;

      
      public SqlExtendedStringType StrType 
      {
        get { return strType; }
      }
      
      public SqlExtendedStringType IriType 
      {
        get { return iriType; }
      }


      public override string ToString()
      {
          Debug.WriteLineIf(CLI.FnTrace.Enabled, "SqlExtendedString.ToString ()");
          return str;
      }

      internal static TraceSwitch Switch = new TraceSwitch("SqlExtendedString", "ExtendedString support");


      public SqlExtendedString (string s, int stype)
	{
	  Debug.WriteLineIf (CLI.FnTrace.Enabled, "SqlExtendedString.ctor (s, stype)");
	  str = s;
	  strType = (SqlExtendedStringType)stype;
          if (str.StartsWith("nodeID://"))
            iriType = SqlExtendedStringType.BNODE;
          else
            iriType = SqlExtendedStringType.IRI;
	}

    }
}
