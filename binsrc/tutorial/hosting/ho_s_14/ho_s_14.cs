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
using System;
using System.Data;
using OpenLink.Data.VirtuosoClient;
namespace OpenLink.Virtuoso.Tutorial
{
  public class ho_s_14
    {
      public static int add_data (int nrows)
	{
	  Object port = AppDomain.CurrentDomain.GetData("OpenLink.Virtuoso.InProcessPort");

	  if (port == null)
	    throw new Exception ("not running as a hosted module");

	  VirtuosoConnection c = new VirtuosoConnection ("HOST=:in-process:" + port.ToString()
	      + ";UID=dummy;PWD=dummy");
	  int i;

	  c.Open();
          new VirtuosoCommand ("exec_result_names (vector ('x'))", c).ExecuteNonQuery ();
	  
	  VirtuosoCommand cmd = new VirtuosoCommand ("result (?)", c);
	  cmd.Parameters.Add (":1", SqlDbType.Int);

	  for (i = 0; i < nrows; i++)
	    {
	      cmd.Parameters[":1"].Value = i;
	      cmd.ExecuteNonQuery ();
	    }
	  cmd = null;
	  c.Close();
	  return 0;
	}
    }
}
