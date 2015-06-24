/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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

package virtuoso.jdbc2;

import java.sql.SQLException;
import javax.sql.XAConnection;
import javax.sql.XADataSource;
import javax.naming.*;

public class VirtuosoXADataSource
    extends VirtuosoConnectionPoolDataSource
    implements XADataSource {

    public VirtuosoXADataSource()
    {
      dataSourceName = "VirtuosoXADataSource";
      if (VirtuosoFuture.rpc_log != null)
       {
	     VirtuosoFuture.rpc_log.println ("new VirtuosoXADataSource () :" + hashCode());
       }
    }


//==================== interface Referenceable
    public Reference getReference() throws NamingException 
    {
#if JDK_VER < 14
      Reference ref = new Reference(getClass().getName(), "virtuoso.jdbc2.VirtuosoDataSourceFactory", null);
#elif JDK_VER < 16
      Reference ref = new Reference(getClass().getName(), "virtuoso.jdbc3.VirtuosoDataSourceFactory", null);
#else
      Reference ref = new Reference(getClass().getName(), "virtuoso.jdbc4.VirtuosoDataSourceFactory", null);
#endif
      addProperties(ref);
      return ref;
    }


    public XAConnection getXAConnection() throws SQLException
    {
      if (VirtuosoFuture.rpc_log != null)
       {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXADataSource.getXAConnection () :" + hashCode());
       }
      return getXAConnection(null, null);
    }

    public XAConnection getXAConnection(String user, String password)
        throws SQLException
    {
      if (VirtuosoFuture.rpc_log != null)
       {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXADataSource.getXAConnection (user=" + user + ", pass=" + password + ") :" + hashCode());
       }
      return new VirtuosoXAConnection((VirtuosoPooledConnection)getPooledConnection(user, password), getServerName(), getPortNumber());
    }
}
