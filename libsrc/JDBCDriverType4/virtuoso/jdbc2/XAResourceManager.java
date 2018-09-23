/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

import java.util.ArrayList;
import java.util.HashMap;
import javax.transaction.xa.XAException;
import javax.transaction.xa.Xid;

class XAResourceManager {

    private String serverName;
    private int portNumber;

    private HashMap<VirtuosoXid,XATransaction> transactions = new HashMap<VirtuosoXid,XATransaction>();
    private static ArrayList<XAResourceManager> managers = new ArrayList<XAResourceManager>();

    private XAResourceManager(String serverName, int portNumber) {
     if (VirtuosoFuture.rpc_log != null)
       {
	     VirtuosoFuture.rpc_log.println ("new XAResourceManager (serverName=" + serverName + ", portNumber=" + portNumber + ") :" + hashCode());
       }
        this.serverName = serverName;
        this.portNumber = portNumber;
    }

    static synchronized XAResourceManager getManager(
        String serverName,
        int portNumber) {
     if (VirtuosoFuture.rpc_log != null)
       {
	     VirtuosoFuture.rpc_log.println ("XAResourceManager.getManager (serverName=" + serverName + ", portNumber=" + portNumber + ")");
       }
        XAResourceManager manager;

	for (int i = 0; i < managers.size(); i++) {
	    manager = (XAResourceManager) managers.get(i);
	    if (manager.serverName == serverName && manager.portNumber == portNumber) {
		return manager;
	    }
	}

	manager = new XAResourceManager(serverName, portNumber);
	managers.add(manager);
        return manager;
    }

    XATransaction createTransaction(Xid xid, int status) throws XAException {
        XATransaction transaction = null;
     if (VirtuosoFuture.rpc_log != null)
       {
	     VirtuosoFuture.rpc_log.println ("XAResourceManager.createTransaction (xid=" + xid.hashCode() + ", status=" + status + ") :" + hashCode());
       }
        VirtuosoXid vxid = new VirtuosoXid(xid);
        synchronized (transactions) {
            if (transactions.containsKey(vxid) && status != XATransaction.PREPARED) {
                throw new XAException (XAException.XAER_DUPID);
            } else {
              transaction = new XATransaction(vxid, status);
              transactions.put(vxid, transaction);
            }
        }
        return transaction;
    }

    void removeTransaction(Xid xid) throws XAException {
     if (VirtuosoFuture.rpc_log != null)
       {
	     VirtuosoFuture.rpc_log.println ("XAResourceManager.removeTransaction (xid=" + xid.hashCode() + ") :" + hashCode());
       }
        VirtuosoXid vxid = new VirtuosoXid(xid);
        synchronized (transactions) {
            transactions.remove(vxid);
        }
    }

    XATransaction getTransaction(Xid xid) throws XAException {
     if (VirtuosoFuture.rpc_log != null)
       {
	     VirtuosoFuture.rpc_log.println ("XAResourceManager.getTransaction (xid=" + xid.hashCode() + ") :" + hashCode());
       }
        XATransaction transaction;
        VirtuosoXid vxid = new VirtuosoXid(xid);
        synchronized (transactions) {
            transaction = (XATransaction) transactions.get(vxid);
        }
        if (transaction == null)
            throw new XAException(XAException.XAER_NOTA);
        return transaction;
    }
}
