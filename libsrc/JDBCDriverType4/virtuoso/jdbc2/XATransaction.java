/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

import javax.transaction.xa.XAException;

class XATransaction
{
    final static int ACTIVE = 1;
    final static int IDLE = 2;
    final static int PREPARED = 3;
    final static int COMMITTED = 4;
    final static int ROLLEDBACK = 5;
    final static int ROLLBACKONLY = 6;

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

    void changeStatus(int nstatus) throws XAException {
      changeStatus(nstatus, false);
    }


    void changeStatus(int nstatus, boolean onePhase) throws XAException {
      checkNewStatus(nstatus, onePhase);

      status = nstatus;

      if (VirtuosoFuture.rpc_log != null)
        {
	  synchronized (VirtuosoFuture.rpc_log)
	    {
	      VirtuosoFuture.rpc_log.println ("VirtuosoXATransaction.changeStatus (nstatus=" + nstatus + ") :" + hashCode() + ")");
	      VirtuosoFuture.rpc_log.flush();
	    }
        }
    }


    void checkNewStatus(int nstatus) throws XAException {
      checkNewStatus(nstatus, false);
    }

    void checkNewStatus(int nstatus, boolean onePhase) throws XAException {
      if (status == ACTIVE && nstatus != IDLE && nstatus != ACTIVE && nstatus != ROLLBACKONLY) {
          throw createException(nstatus);
      } else if (status == IDLE && (nstatus != PREPARED && nstatus != ROLLEDBACK && !(nstatus == COMMITTED && onePhase))) {
          throw createException(nstatus);
      } else if (status == PREPARED && (nstatus != COMMITTED && nstatus != ROLLEDBACK)) {
          throw createException(nstatus);
      } else if (status == ROLLBACKONLY && nstatus != ROLLEDBACK && nstatus != PREPARED) {
          throw createException(nstatus);
      } else if (status == COMMITTED || status == ROLLEDBACK) {
          throw createException(nstatus);
      }
    }


    private String getName(int _status) {
      switch(_status) {
        case ACTIVE:     return "ACTIVE";
        case IDLE:       return "IDLE";
        case PREPARED:   return "PREPARED";
        case COMMITTED:  return "COMMITED";
        case ROLLEDBACK: return "ROLLEDBACK";
        case ROLLBACKONLY: return "ROLLBACKONLY";
        default:         return "UNKNOWN";
      }
    }


    private XAException createException(int nstatus) {
      XAException ex = new XAException("Can't change transaction state from "+getName(status)+" to "+getName(nstatus));
      ex.errorCode = XAException.XAER_RMFAIL;
      return ex;
    }

}
