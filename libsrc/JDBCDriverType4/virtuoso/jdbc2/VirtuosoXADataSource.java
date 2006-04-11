/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
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
 *  
*/
//
// $Id$
//

package virtuoso.jdbc2;

import java.sql.SQLException;
import javax.sql.XAConnection;
import javax.sql.XADataSource;

public class VirtuosoXADataSource
    extends VirtuosoConnectionPoolDataSource
    implements XADataSource {

    public XAConnection getXAConnection() throws SQLException {
        VirtuosoConnection connection = (VirtuosoConnection) super.getConnection();
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("new VirtuosoXADataSource () :" + hashCode());
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
        return new VirtuosoXAConnection(this, connection);
    }

    public XAConnection getXAConnection(String user, String password)
        throws SQLException {
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXADataSource.getXAConnection (user=" + user + ", pass=" + password + ") :" + hashCode());
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
        VirtuosoConnection connection =
            (VirtuosoConnection) super.getConnection(user, password);
        return new VirtuosoXAConnection(this, connection);
    }
}
