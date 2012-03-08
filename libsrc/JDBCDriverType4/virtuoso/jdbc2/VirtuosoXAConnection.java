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

import java.sql.Connection;
import java.sql.SQLException;
import javax.sql.XAConnection;
import javax.sql.ConnectionEventListener;
#if JDK_VER >= 16
import javax.sql.StatementEventListener;
#endif
import javax.transaction.xa.XAResource;

public class VirtuosoXAConnection implements XAConnection {

    private VirtuosoPooledConnection pconn;
    private VirtuosoXAResource resource;

    protected VirtuosoXAConnection(VirtuosoPooledConnection connection, String server, int port) throws SQLException
    {
        pconn = connection;
        pconn.getVirtuosoConnection().xa_connection = this;
        resource = new VirtuosoXAResource(pconn, server, port);
	if (VirtuosoFuture.rpc_log != null)
	{
	    synchronized (VirtuosoFuture.rpc_log)
	    {
		VirtuosoFuture.rpc_log.println ("new VirtuosoXAConnection (connection=" + connection.hashCode() + ") :" + hashCode() + ")");
		VirtuosoFuture.rpc_log.flush();
	    }
	}
    }

  /**
   * Retrieves an <code>XAResource</code> object that
   * the transaction manager will use
   * to manage this <code>XAConnection</code> object's participation in a
   * distributed transaction.
   *
   * @return the <code>XAResource</code> object
   * @exception SQLException if a database access error occurs
   */
    public XAResource getXAResource() throws SQLException
    {
      return (XAResource) getVirtuosoXAResource();
    }


    VirtuosoXAResource getVirtuosoXAResource() throws VirtuosoException
    {
     if (pconn.isClosed())
        throw new VirtuosoException("Connection is closed.",VirtuosoException.DISCONNECTED);
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


  /**
   * Creates and returns a <code>Connection</code> object that is a handle
   * for the physical connection that
   * this <code>PooledConnection</code> object represents.
   * The connection pool manager calls this method when an application has
   * called the method <code>DataSource.getConnection</code> and there are
   * no <code>PooledConnection</code> objects available. See the
   * {@link PooledConnection interface description} for more information.
   *
   * @return  a <code>Connection</code> object that is a handle to
   *          this <code>PooledConnection</code> object
   * @exception SQLException if a database access error occurs
   */
  public Connection getConnection() throws SQLException {
    if (pconn.isClosed())
      throw new VirtuosoException("Connection is closed.",VirtuosoException.DISCONNECTED);

    ConnectionWrapper conn = (ConnectionWrapper)pconn.getConnection();
    conn.setXAResource(resource);

    return (Connection)conn;

  }

  /**
   * Closes the physical connection that this <code>OPLXAConnection</code>
   * object represents.  An application never calls this method directly;
   * it is called by the connection pool module, or manager.
   * <P>
   * See the {@link PooledConnection interface description} for more
   * information.
   *
   * @exception SQLException if a database access error occurs
   */
  public void close() throws SQLException {
    pconn.close();
  }

  /**
   * Registers the given event listener so that it will be notified
   * when an event occurs on this <code>OPLXAConnection</code> object.
   *
   * @param listener a component, usually the connection pool manager,
   *        that has implemented the
   *        <code>ConnectionEventListener</code> interface and wants to be
   *        notified when the connection is closed or has an error
   * @see #removeConnectionEventListener
   */
  public void addConnectionEventListener(ConnectionEventListener listener) {
    pconn.addConnectionEventListener(listener);
  }

  /**
   * Removes the given event listener from the list of components that
   * will be notified when an event occurs on this
   * <code>OPLXAConnection</code> object.
   *
   * @param listener a component, usually the connection pool manager,
   *        that has implemented the
   *        <code>ConnectionEventListener</code> interface and
   *        been registered with this <code>PooledConnection</code> object as
   *        a listener
   * @see #addConnectionEventListener
   */
  public void removeConnectionEventListener(ConnectionEventListener listener) {
    pconn.removeConnectionEventListener(listener);
  }

#if JDK_VER >= 16
	/**
	 * Registers a <code>StatementEventListener</code> with this <code>PooledConnection</code> object.  Components that
	 * wish to be notified when  <code>PreparedStatement</code>s created by the
         * connection are closed or are detected to be invalid may use this method
         * to register a <code>StatementEventListener</code> with this <code>PooledConnection</code> object.
	 * <p>
	 * @param listener	an component which implements the <code>StatementEventListener</code>
	 *		interface that is to be registered with this <code>PooledConnection</code> object
	 * <p>
	 * @since 1.6
	 */
  public void addStatementEventListener(StatementEventListener listener)
  {
//??TODO    throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "addStatementEventListener(listener)");
  }

	/**
	 * Removes the specified <code>StatementEventListener</code> from the list of
	 * components that will be notified when the driver detects that a
	 * <code>PreparedStatement</code> has been closed or is invalid.
	 * <p>
	 * @param listener	the component which implements the
	 *	<code>StatementEventListener</code> interface that was previously
	 *	registered with this <code>PooledConnection</code> object
	 * <p>
	 * @since 1.6
	 */
  public void removeStatementEventListener(StatementEventListener listener)
  {
//??TODO    throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "removeStatementEventListener(listener)");
  }
#endif

}
