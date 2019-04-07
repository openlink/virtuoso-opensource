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
using System;
using System.Data;
using System.Security.Permissions;
using OpenLink.Data.VirtuosoClient;

[assembly:VirtuosoPermission(SecurityAction.RequestMinimum, Unrestricted=true)]
namespace OpenLink.BPEL4WS {
  public class BpelVarsAdaptor {
    private VirtuosoConnection c;
    public BpelVarsAdaptor ()
    {
	  Object port = AppDomain.CurrentDomain.GetData("OpenLink.Virtuoso.InProcessPort");

	  if (port == null)
	    throw new Exception ("not running as a hosted module");
//	  Console.WriteLine ("HOST=localhost:" + port.ToString());

	  c = new VirtuosoConnection ("HOST=:in-process:" + port.ToString()
				      + ";UID=dummy;PWD=dummy");

    }
    public Object get_var_data (String var, String part, String query, String vars, String xmlnss)
    {
//      Console.WriteLine ("get_var_data:0");
      try 
	{
	  c.Open();
	}
      catch (Exception e)
	{
//	  Console.WriteLine("{0} Exception caught.", e);
	  throw;
	}

//      Console.WriteLine ("get_var_data:1");
      VirtuosoCommand cmd = new VirtuosoCommand ("select BPEL.BPEL.get_var_from_dump (?, ?, ?, ?, ?)", c);
//      Console.WriteLine ("get_var_data:2");
      cmd.Parameters.Add (":1", SqlDbType.VarChar);
      cmd.Parameters.Add (":2", SqlDbType.VarChar);
      cmd.Parameters.Add (":3", SqlDbType.VarChar);
      cmd.Parameters.Add (":4", SqlDbType.VarChar);
      cmd.Parameters.Add (":5", SqlDbType.VarChar);
//      Console.WriteLine ("get_var_data:3");

      cmd.Parameters[":1"].Value = var;
      cmd.Parameters[":2"].Value = part;
      cmd.Parameters[":3"].Value = query;
      cmd.Parameters[":4"].Value = vars;
      cmd.Parameters[":5"].Value = xmlnss;

//      Console.WriteLine ("get_var_data:4");
      String result = (String) cmd.ExecuteScalar();
//      Console.WriteLine (result);
//      Console.WriteLine ("get_var_data:7");

      c.Close();
//      Console.WriteLine ("get_var_data:8");

      return result;
    }
    public String set_var_data (String var, String part, String query, Object val, String vars, String xmlnss)
    {
      c.Open();
      VirtuosoCommand cmd = new VirtuosoCommand ("select BPEL.BPEL.set_var_to_dump (?, ?, ?, ?, ?, ?)", c);
      cmd.Parameters.Add (":1", SqlDbType.VarChar);
      cmd.Parameters.Add (":2", SqlDbType.VarChar);
      cmd.Parameters.Add (":3", SqlDbType.VarChar);
      cmd.Parameters.Add (":4", SqlDbType.VarChar);
      cmd.Parameters.Add (":5", SqlDbType.VarChar);
      cmd.Parameters.Add (":6", SqlDbType.VarChar);

      cmd.Parameters[":1"].Value = var;
      cmd.Parameters[":2"].Value = part;
      cmd.Parameters[":3"].Value = query;
      cmd.Parameters[":4"].Value = val;
      cmd.Parameters[":5"].Value = vars;
      cmd.Parameters[":6"].Value = xmlnss;

      String result = (String) cmd.ExecuteScalar();
      c.Close();

      return result;
    }
  }
}
