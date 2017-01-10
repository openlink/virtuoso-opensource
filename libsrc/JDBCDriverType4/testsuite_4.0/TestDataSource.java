/*
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */

package testsuite;

import java.sql.*;
import javax.sql.*;
import java.util.*;
import javax.naming.*;
import virtuoso.jdbc4.*;

public class TestDataSource
{
   public static Context ctx;
   public static DataSource registerConnection () throws Exception
   {
     VirtuosoDataSource ds = new VirtuosoDataSource ();
     ds.setDescription ("test datasource");
     ds.setServerName ("localhost");
     ds.setPortNumber (1111);
     ds.setUser ("dba");
     ds.setPassword ("dba");
     ds.setDatabaseName ("DS1");

//     ctx.bind ("jdbc/virt_ds1", ds);
     return ds;
   }

   public static void main(String args[])
   {
      VirtuosoDataSource ds;
      try
      {
/*
	Hashtable env = new Hashtable();

        env.put (Context.INITIAL_CONTEXT_FACTORY, "com.sun.jndi.fscontext.RefFSContextFactory");
        env.put(Context.PROVIDER_URL, "file:///home/kgeorge/jndi");
	ctx = new InitialContext(env);
*/

	System.out.println("----------------------- Test of datasource ---------------------");
	System.out.print("Register connection jdbc/virt_ds1");
//	registerConnection ();
	ds = (VirtuosoDataSource) registerConnection ();
	System.out.println("    PASSED");


	System.out.print("Establish connection through jdbc/virt_ds1 datasource");
//        VirtuosoDataSource ds = (VirtuosoDataSource) ctx.lookup ("jdbc/virt_ds1");
        Connection c = ds.getConnection ();
	System.out.println("    PASSED");
        System.exit (0);
      }
      catch(Exception e)
      {
         System.out.println("    FAILED");
         e.printStackTrace();
         System.exit(-1);
      }
   }
}

