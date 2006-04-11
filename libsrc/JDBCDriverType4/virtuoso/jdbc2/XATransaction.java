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

class XATransaction
{
    final static int ACTIVE = 1;
    final static int PREPARED = 2;
    final static int COMMITTED = 3;
    final static int ROLLEDBACK = 4;

    private VirtuosoXid xid;
    private int status;

    XATransaction (VirtuosoXid xid, int status) {
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("new VirtuosoXATransaction (xid=" + xid.hashCode() + ", status=" + status + ") :" + hashCode());
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
        this.xid = xid;
        this.status = status;
    }

    VirtuosoXid getXid() {
        return xid;
    }

    int getStatus() {
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXATransaction.getStatus () ret=" + status + " :" + hashCode() + ")");
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
        return status;
    }

    void setStatus(int status) {
        this.status = status;
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXATransaction.setStatus (status=" + status + ") :" + hashCode() + ")");
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
    }
}
