/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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

import java.io.IOException;
import java.sql.Statement;
import java.sql.SQLException;
import java.sql.ResultSet;
import java.util.Vector;
import javax.transaction.xa.XAException;
import javax.transaction.xa.XAResource;
import javax.transaction.xa.Xid;

public class VirtuosoXAResource implements XAResource
{
    private final static int SQL_XA_ENLIST   = 0x00f6;
    private final static int SQL_XA_PREPARE  = 0x0f01;
    private final static int SQL_XA_COMMIT   = 0x0f02;
    private final static int SQL_XA_ROLLBACK = 0x0f03;
    private final static int SQL_XA_END      = 0x0f04;
    private final static int SQL_XA_JOIN     = 0x0f05;
    private final static int SQL_XA_RESUME   = 0x0f06;
    private final static int SQL_XA_SUSPEND  = 0x0f07;
    private final static int SQL_XA_WAIT     = 0x0f00;

    private final String GET_ALL_XIDS = "_2PC.DBA.XA_GET_ALL_XIDS()";

    private VirtuosoPooledConnection vConnection;
    private XAResourceManager manager;
    int txn_timeout = 0;

    private boolean stored_auto_commit;

    private Xid     r_currentXid = null;

    VirtuosoXAResource(VirtuosoPooledConnection vConnection, String server, int port) {
        this.vConnection = vConnection;
        this.manager = XAResourceManager.getManager(server, port);
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("new VirtuosoXAResource (+ con=" + vConnection.hashCode() + ") :" + hashCode() + ")");
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
    }


    void reset_XA()
    {
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXAResource.reset_XA () :" + hashCode());
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
      if (vConnection == null)
        return;

      if (r_currentXid != null)
        try {
          end(r_currentXid, XAResource.TMFAIL);
        }
        catch (Exception e) {}
    }


    public int getTransactionTimeout() throws XAException {
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXAResource.getTransactionTimeout () ret " + txn_timeout + " :" + hashCode() + ")");
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
        return txn_timeout;
    }


    public boolean setTransactionTimeout(int seconds) throws XAException {
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXAResource.setTransactionTimeout (" + seconds + ") :" + hashCode() + ")");
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
        if (seconds < 0) {
            XAException xaex = new XAException("Invalid number of seconds : " + seconds);
	    xaex.errorCode = XAException.XAER_INVAL;
	    throw xaex;
        } else if (seconds == 0) {
            try {
              txn_timeout = vConnection.getVirtuosoConnection().getTimeout();
            } catch (SQLException ex) {
              throw new XAException(ex.toString());
            }
        } else {
            txn_timeout = seconds;
        }
        return true;
    }


    public boolean isSameRM(XAResource xaResource) throws XAException {
	boolean ret;
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXAResource.isSameRM (res=" + xaResource.hashCode() + ") :" + hashCode() + ")");
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
        if (xaResource == null || !(xaResource instanceof VirtuosoXAResource))
            ret = false;
	else if (xaResource.equals (this))
	    ret = true;
	else
	{
	    VirtuosoXAResource that = (VirtuosoXAResource) xaResource;
	    ret = this.manager == that.manager;
	}
	return ret;
    }


    public void start(Xid xid, int param) throws XAException {
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXAResource.start (xid=" + xid.hashCode() + ", param=" + param + ") :" + hashCode() + ")");
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
        if (xid == null) {
            throw new XAException(XAException.XAER_INVAL);
        }
        if (param != XAResource.TMNOFLAGS
            && param != XAResource.TMJOIN
            && param != XAResource.TMRESUME) {
            throw new XAException(XAException.XAER_INVAL);
        }

        XATransaction transaction = null;
        int start_param;
        if (param == XAResource.TMJOIN) {
            transaction = manager.getTransaction(xid);
            if (transaction.getStatus() != XATransaction.ACTIVE
                && transaction.getStatus() != XATransaction.IDLE) {
                throw new XAException(XAException.XAER_PROTO);
            }
            start_param = SQL_XA_JOIN;
        } else if (param == XAResource.TMNOFLAGS) {
            transaction = manager.createTransaction(xid, XATransaction.ACTIVE);
            start_param = SQL_XA_ENLIST;
        } else if (param == XAResource.TMRESUME) {
            transaction = manager.getTransaction(xid);
            if (transaction.getStatus() != XATransaction.ACTIVE) {
                throw new XAException(XAException.XAER_PROTO);
            }
            start_param = SQL_XA_RESUME;
        } else {
            throw new XAException("Unsupported mode");
        }

        VirtuosoConnection con;

        try {
          con = vConnection.getVirtuosoConnection();
        } catch (SQLException ex) {
          throw new XAException(ex.toString());
        }

        enterGlobalTransaction(con);
        try {
            rpc(con, start_param, transaction.getXid().encode());
        } catch (XAException ex) {
            leaveGlobalTransaction(con);
            throw ex;
        }
        r_currentXid = xid;
    }


    public void end(Xid xid, int param) throws XAException {
     int end_param;
     int nstatus = XATransaction.IDLE;
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXAResource.end (xid=" + xid.hashCode() + ", param=" + param + ") :" + hashCode() + ")");
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
        if (xid == null)
            throw new XAException(XAException.XAER_INVAL);

        XATransaction ctx = manager.getTransaction(xid);

        if ((param & XAResource.TMSUSPEND) != 0)
	{
           end_param = SQL_XA_SUSPEND;
           nstatus = XATransaction.ACTIVE;
	}
	else if (param == XAResource.TMSUCCESS)
	{
           end_param = SQL_XA_END;
        }
	else if (param == XAResource.TMFAIL)
	{
           end_param = SQL_XA_END;
           nstatus = XATransaction.ROLLBACKONLY;
        }
	else
       	{
            throw new XAException("Invalid flag.");
        }

        ctx.checkNewStatus(nstatus);
        VirtuosoConnection con;
        try {
          con = vConnection.getVirtuosoConnection();
        } catch (SQLException ex) {
          throw new XAException(ex.toString());
        }

        rpc(con, end_param, ctx.getXid().encode());
        leaveGlobalTransaction(con);
        ctx.changeStatus(nstatus);
    }


    public int prepare(Xid xid) throws XAException {
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXAResource.prepare (xid=" + xid.hashCode() + ") :" + hashCode() + ")");
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
        if (xid == null)
            throw new XAException(XAException.XAER_INVAL);

        XATransaction ctx = manager.getTransaction(xid);

        ctx.checkNewStatus(XATransaction.PREPARED);
        VirtuosoConnection con;
        try {
	  con = vConnection.getVirtuosoConnection();
        } catch (SQLException ex) {
          throw new XAException(ex.toString());
        }

        rpc(con, SQL_XA_PREPARE, ctx.getXid().encode());
        ctx.changeStatus(XATransaction.PREPARED);
        return XAResource.XA_OK;
    }


    public void commit(Xid xid, boolean onePhase) throws XAException {
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXAResource.commit (xid=" + xid.hashCode() + ", onePhase=" + onePhase + ") :" + hashCode() + ")");
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
        if (xid == null)
            throw new XAException(XAException.XAER_INVAL);

        XATransaction ctx = manager.getTransaction(xid);
        ctx.checkNewStatus(XATransaction.COMMITTED, onePhase);

        transact(ctx, SQL_XA_COMMIT);
        ctx.changeStatus(XATransaction.COMMITTED, onePhase);
        manager.removeTransaction(xid);
    }


    public void rollback(Xid xid) throws XAException {
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXAResource.rollback (xid=" + xid.hashCode() + ") :" + hashCode() + ")");
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
        if (xid == null)
            throw new XAException(XAException.XAER_INVAL);

        XATransaction ctx = manager.getTransaction(xid);
        ctx.checkNewStatus(XATransaction.ROLLEDBACK);

        transact(ctx, SQL_XA_ROLLBACK);
        ctx.changeStatus(XATransaction.ROLLEDBACK);
        manager.removeTransaction(xid);
    }


    public Xid[] recover(int param) throws XAException {
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXAResource.recover (param=" + param + ") :" + hashCode() + ")");
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
        if (param != XAResource.TMSTARTRSCAN)
            return new Xid[0];

#if JDK_VER >= 16
        Vector<VirtuosoXid> xidv = new Vector<VirtuosoXid> ();
#else
        Vector xidv = new Vector ();
#endif

        try {
            VirtuosoConnection con = vConnection.getVirtuosoConnection();
            Statement stmt = con.createStatement();
            ResultSet rs = stmt.executeQuery (GET_ALL_XIDS);
            while (rs.next ()) {
            	String s = rs.getString (1);
            	VirtuosoXid xid = VirtuosoXid.decode (s);
	        xidv.add (xid);
                manager.createTransaction(xid, XATransaction.PREPARED);
            }
        } catch (SQLException e) {
            throw new XAException (e.toString());
        }

        Xid[] xids = new Xid[xidv.size()];
        for (int i = 0; i < xids.length; i++)
            xids[i] = (Xid) xidv.get (i);
        return xids;
    }


    public void forget(Xid xid) throws XAException {
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXAResource.forget (xid=" + xid.hashCode() + ") :" + hashCode() + ")");
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
        if (xid == null)
            throw new XAException(XAException.XAER_INVAL);
        manager.removeTransaction(xid);
    }


    private void enterGlobalTransaction(VirtuosoConnection connection) {
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXAResource.enterGlobalTransaction (conn=" + connection.hashCode() + ") :" + hashCode() + ")");
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
        if (connection == null)
            return;
        try {
            stored_auto_commit = connection.getAutoCommit();
            connection.setAutoCommit(false);
        } catch (Exception e) {
        }
        connection.setGlobalTransaction(true);
    }


    private void leaveGlobalTransaction(VirtuosoConnection connection) {
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("VirtuosoXAResource.leaveGlobalTransaction (conn=" + connection.hashCode() + ") :" + hashCode() + ")");
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
        if (connection == null)
            return;
        connection.setGlobalTransaction(false);
        try {
            connection.setAutoCommit(stored_auto_commit);
        } catch (Exception e) {
        }
        r_currentXid = null;
    }


    private void transact(XATransaction ctx, int action) throws XAException {
        Object encodedXid = ctx.getXid().encode();

        VirtuosoConnection con;
        try {
          con = vConnection.getVirtuosoConnection();
        } catch (SQLException ex) {
          throw new XAException(ex.toString());
        }
	
	rpc(con, action, encodedXid);
	rpc(con, SQL_XA_WAIT, encodedXid);
    }


    private void rpc(VirtuosoConnection connection, int action, Object encodedXid)
        throws XAException {
        Object[] args = new Object[2];
        args[0] = new Integer(action);
        args[1] = encodedXid;

        try {
            synchronized (connection) {
                VirtuosoFuture future =
                    connection.getFuture(
                        VirtuosoFuture.tp_transaction,
                        args,
                        connection.timeout);
                openlink.util.Vector res = future.nextResult();
                Object err = (res == null ? null : res.firstElement());
                if (err instanceof openlink.util.Vector) {
                    throw new XAException();
                }
                connection.removeFuture(future);
            }
        } catch (IOException ex) {
            //System.out.println("VirtuosoXAResource.rpc(): Exception caught: " + ex);
            throw new XAException(XAException.XAER_RMERR);
        } catch (VirtuosoException ex) {
            //System.out.println("VirtuosoXAResource.rpc(): Exception caught: " + ex);
            throw new XAException(ex.toString());
        }
    }
}
