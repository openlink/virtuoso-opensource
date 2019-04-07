/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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

package virtuoso.jena.driver;


import java.sql.*;

import com.hp.hpl.jena.graph.impl.*;
import com.hp.hpl.jena.shared.*;

public class VirtTransactionHandler extends TransactionHandlerBase {

	private VirtGraph graph = null;
	private Boolean m_transactionsSupported = null;
    

	public VirtTransactionHandler(VirtGraph _graph ) {
		super();
		this.graph = _graph;
	}

	public boolean transactionsSupported() {
		if (m_transactionsSupported != null) {
			return(m_transactionsSupported.booleanValue());	
		}
		
		try {
			Connection c = graph.getConnection();
			if ( c != null) {
				m_transactionsSupported = new Boolean(c.getMetaData().supportsMultipleTransactions());
				return(m_transactionsSupported.booleanValue());
			}
		} catch (Exception e) {
			throw new JenaException(e);
		}
		return (false);
	}

	public void begin() {
		if (transactionsSupported()) {
			try {
				Connection c = graph.getConnection();
				if (c.getTransactionIsolation() != Connection.TRANSACTION_READ_COMMITTED) {
					c.setTransactionIsolation(Connection.TRANSACTION_READ_COMMITTED);
				}
				if (c.getAutoCommit()) {
					c.setAutoCommit(false);
				}
			} catch (SQLException e) {
				throw new JenaException("Transaction begin failed: ", e);
			}
		} else {
			notSupported("begin transaction");
		}
	}

	public void abort() {
		if (transactionsSupported()) {
			try {
				Connection c = graph.getConnection();
				c.rollback();
				c.commit();
				c.setAutoCommit(true);
			} catch (SQLException e) {
				throw new JenaException("Transaction rollback failed: ", e);
			}
		} else {
			notSupported("abort transaction");
		}
	}

	public void commit() {
		if (transactionsSupported()) {
			try {
				Connection c = graph.getConnection();
				c.commit();
					c.setAutoCommit(true);
			} catch (SQLException e) {
				throw new JenaException("Transaction commit failed: ", e);
			}
		} else {
			notSupported("commit transaction");
		}
	}

	private void notSupported(String opName)
		{ throw new UnsupportedOperationException(opName); }

}
