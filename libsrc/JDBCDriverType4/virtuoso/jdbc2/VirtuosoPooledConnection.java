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

import java.sql.Connection;
import java.sql.SQLException;
import java.util.ArrayList;
import javax.sql.ConnectionEvent;
import javax.sql.ConnectionEventListener;
import javax.sql.PooledConnection;
#if JDK_VER >= 16
import javax.sql.StatementEventListener;
#endif

public class VirtuosoPooledConnection implements PooledConnection {

    private VirtuosoDataSource ds;
    private VirtuosoConnection connection;
    private VirtuosoConnectionHandle connectionHandle;
    private ArrayList listeners;

    VirtuosoPooledConnection(VirtuosoDataSource ds, VirtuosoConnection connection) {
        this.ds = ds;
        this.connection = connection;
        this.connection.pooled_connection = this;
        this.listeners = new ArrayList();
    }

    public Connection getConnection() throws SQLException {
        synchronized (this) {
            if (connectionHandle != null) {
                connectionHandle.close();
            }
            connectionHandle = new VirtuosoConnectionHandle(this);
            return connectionHandle;
        }
    }

    public void close() throws SQLException {
        synchronized (this) {
            if(connectionHandle != null) {
                connectionHandle.close();
                connectionHandle = null;
            }
            if (connection != null) {
                connection.close();
                connection = null;
            }
        }
    }

    public void addConnectionEventListener(ConnectionEventListener listener) {
        synchronized (listeners) {
            listeners.add(listener);
        }
    }

    public void removeConnectionEventListener(ConnectionEventListener listener) {
        synchronized(listeners) {
            listeners.remove(listener);
        }
    }

    void notify_closed() {
        ConnectionEvent evt = new ConnectionEvent(this);
        Object[] listeners2;
        synchronized (listeners) {
            listeners2 = listeners.toArray();
        }
        for (int i = 0; i < listeners2.length; i++) {
            ((ConnectionEventListener) listeners2[i]).connectionClosed(evt);
        }
    }

    void notify_error(VirtuosoException e) {
        ConnectionEvent evt = new ConnectionEvent(this, e);
        Object[] listeners2;
        synchronized (listeners) {
            listeners2 = listeners.toArray();
        }
        for (int i = 0; i < listeners2.length; i++) {
            ((ConnectionEventListener) listeners2[i]).connectionErrorOccurred(evt);
        }
    }

    VirtuosoDataSource getVirtuosoDataSource() {
        return ds;
    }

    VirtuosoConnection getVirtuosoConnection() {
        return connection;
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
//??TODO
//??     throw new VirtuosoException ("addStatementEventListener(listener)  not supported", VirtuosoException.NOTIMPLEMENTED);
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
//??TODO
//??     throw new VirtuosoException ("removeStatementEventListener(listener)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }
#endif

}
