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
import javax.transaction.xa.XAResource;

public class VirtuosoXAConnection
    extends VirtuosoPooledConnection
    implements XAConnection {

    private VirtuosoXAResource resource = new VirtuosoXAResource(this);

    VirtuosoXAConnection(VirtuosoXADataSource ds, VirtuosoConnection connection) {
        super(ds, connection);
	if (VirtuosoFuture.rpc_log != null)
	{
	    synchronized (VirtuosoFuture.rpc_log)
	    {
		VirtuosoFuture.rpc_log.println ("new VirtuosoXAConnection (ds=" + ds.hashCode() + ", connection=" + connection.hashCode() + ") :" + hashCode() + ")");
		VirtuosoFuture.rpc_log.flush();
	    }
	}
    }

    public XAResource getXAResource() throws SQLException {
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXAConnection.getXAResource () ret " + resource.hashCode() + " :" + hashCode());
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
        return resource;
    }

    VirtuosoXAResource getVirtuosoXAResource() {
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXAConnection.getVirtuosoXAResource () ret " + resource.hashCode() + " :" + hashCode());
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
        return resource;
    }
}
