/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2007 OpenLink Software
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

package virtuoso.sesame2.driver;

import java.io.File;
import java.sql.DriverManager;

import org.openrdf.model.ValueFactory;
import org.openrdf.model.impl.ValueFactoryImpl;
import org.openrdf.repository.Repository;
import org.openrdf.repository.RepositoryConnection;
import org.openrdf.repository.RepositoryException;

public class VirtuosoRepository implements Repository {
	
	VirtuosoRepositoryConnection connection;
	ValueFactory valueFactory = new ValueFactoryImpl();
	File dataDir;
	
	public String url;
	public String user;
	public String password;
	private int connection_status = 0;
	public int resultsHandlerType = 0;
    
    static {
		try {
			Class.forName("virtuoso.jdbc3.Driver");
		}
		catch (ClassNotFoundException e) {
			e.printStackTrace();
		}
    }
	
	public VirtuosoRepository(String url, String user, String password) {
		this.url = url;
		this.user = user;
		this.password = password;
		
		try {
			java.sql.Connection connection = DriverManager.getConnection(url, user, password);
			connection_status = 1;
			
			this.connection = new VirtuosoRepositoryConnection(this, connection);
			
			// insert the jena_remove procedure
			String query = "create procedure jena_remove (in _G any, in _S any, in _P any, in _O any){delete from RDF_QUAD where G=DB.DBA.RDF_MAKE_IID_OF_QNAME (_G) and S=DB.DBA.RDF_MAKE_IID_OF_QNAME (_S) and P=DB.DBA.RDF_MAKE_IID_OF_QNAME (_P) and O=DB.DBA.RDF_MAKE_IID_OF_QNAME (_O);}";
			java.sql.Statement stmt = connection.createStatement();
			stmt.executeUpdate(query);
		}
		catch (Exception e) {
			System.out.println("Connection to " + url + " is FAILED.");
//			e.printStackTrace();
//			System.exit(-1);
		}
	}

	public RepositoryConnection getConnection() throws RepositoryException {
		return this.connection;
	}

	public File getDataDir() {
		return this.dataDir;
	}

	public ValueFactory getValueFactory() {
		return this.valueFactory;
	}

	public void initialize() throws RepositoryException {
	}

	public boolean isWritable() throws RepositoryException {
		return true; // user login has authenticated this connection
	}

	public void setDataDir(File dataDir) {
		this.dataDir = dataDir;
	}

	public void shutDown() throws RepositoryException {
	}

	public int getResultsHandlerType() {
		return resultsHandlerType;
	}

	public void setResultsHandlerType(int handlerType) {
		this.resultsHandlerType = handlerType;
	}

}
