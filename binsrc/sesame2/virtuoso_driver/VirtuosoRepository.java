/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

import javax.sql.*;
import java.io.File;
import java.sql.DriverManager;
import java.sql.SQLException;

import org.openrdf.model.ValueFactory;
import org.openrdf.model.impl.ValueFactoryImpl;
import org.openrdf.repository.Repository;
import org.openrdf.repository.RepositoryConnection;
import org.openrdf.repository.RepositoryException;

import virtuoso.jdbc3.VirtuosoConnectionPoolDataSource;

/**
 * A Sesame repository that contains RDF data that can be queried and updated.
 * Access to the repository can be acquired by openening a connection to it.
 * This connection can then be used to query and/or update the contents of the
 * repository. Depending on the implementation of the repository, it may or may
 * not support multiple concurrent connections.
 * <p>
 * Please note that a repository needs to be initialized before it can be used
 * and that it should be shut down before it is discarded/garbage collected.
 * Forgetting the latter can result in loss of data (depending on the Repository
 * implementation)!
 * 
 */
public class VirtuosoRepository implements Repository {
	
	ValueFactory valueFactory = new ValueFactoryImpl();
	File dataDir;
	
        private VirtuosoConnectionPoolDataSource pds = new VirtuosoConnectionPoolDataSource();
	private String url_hostlist;
	private String user;
	private String password;
	private int resultsHandlerType = 0;
	private boolean roundrobin;
	private String charset = "UTF-8";
        static final String utf8 = "charset=utf-8";
	private boolean initialized = false;

	private DataSource _ds;
	private ConnectionPoolDataSource _pds;
    
	boolean useLazyAdd = false;
	String defGraph;
	int prefetchSize = 200;
	int batchSize = 5000;
	int queryTimeout = 0;
	String ruleSet;
	
	public VirtuosoRepository(ConnectionPoolDataSource ds, String defGraph, boolean useLazyAdd) {
	        super();
		this.defGraph = defGraph;
		this.useLazyAdd = useLazyAdd;
		this._pds = ds;
	}

	public VirtuosoRepository(DataSource ds, String defGraph, boolean useLazyAdd) {
	        super();
		this.defGraph = defGraph;
		this.useLazyAdd = useLazyAdd;
		this._ds = ds;
	}

	/**
	 * Construct a VirtuosoRepository with a specified parameters
	 * 
	 * @param url_hostlist
	 *        the Virtuoso JDBC URL connection string or hostlist for poolled connection.
	 *        Virtuoso database hostlist 
	 *        <pre>
	 *        "hostone:1112,hosttwo:1113" 
	 *     or "hostone,hosttwo" if default port=1111 is used on hosts
	 *        </pre>
	 * @param user
	 *        the database user on whose behalf the connection is being made
	 * @param password
	 *        the user's password
	 * @param defGraph
	 *        a default Graph name, used for Sesame calls, when contexts list
	 *        is empty, exclude <tt>exportStatements, hasStatement, getStatements</tt> methods 
	 * @param useLazyAdd
	 *        set <tt>true</tt>  to enable using batch optimization for sequence of 
	 *        <pre>
	 *	  add(Resource subject, URI predicate, Value object, Resource... contexts);
         *        add(Statement statement, Resource... contexts);
	 *        </pre>
         *        methods, when autoCommit mode is off. The triples will be sent to DBMS on commit call
         *        or when batch size become more than predefined batch max_size. 
         *
	 */
	public VirtuosoRepository(String url_hostlist, String user, String password, String defGraph, boolean useLazyAdd) {
	        super();
		this.url_hostlist = url_hostlist.trim();
		this.user = user;
		this.password = password;
		this.defGraph = defGraph;
		this.useLazyAdd = useLazyAdd;
	}

	/**
	 * Construct a VirtuosoRepository with a specified parameters
	 * <tt>defGraph</tt> will be set to <tt>"sesame:nil"</tt>.
	 * 
	 * @param url_hostlist
	 *        the Virtuoso JDBC URL connection string or hostlist for poolled connection.
	 *        Virtuoso database hostlist 
	 *        <pre>
	 *        "hostone:1112,hosttwo:1113" 
	 *     or "hostone,hosttwo" if default port=1111 is used on hosts
	 *        </pre>
	 * @param user
	 *        the database user on whose behalf the connection is being made
	 * @param password
	 *        the user's password
	 * @param useLazyAdd
	 *        set <tt>true</tt>  to enable using batch optimization for sequence of 
	 *        <pre>
	 *	  add(Resource subject, URI predicate, Value object, Resource... contexts);
         *        add(Statement statement, Resource... contexts);
	 *        </pre>
         *        methods, when autoCommit mode is off. The triples will be sent to DBMS on commit call
         *        or when batch size become more than predefined batch max_size. 
         *
	 */
	public VirtuosoRepository(String url_hostlist, String user, String password, boolean useLazyAdd) {
	        this(url_hostlist, user, password, "sesame:nil", useLazyAdd);
	}

	/**
	 * Construct a VirtuosoRepository with a specified parameters.
	 * useLazyAdd will be set to <tt>false</tt>.
	 * 
	 * @param url_hostlist
	 *        the Virtuoso JDBC URL connection string or hostlist for poolled connection.
	 *        Virtuoso database hostlist 
	 *        <pre>
	 *        "hostone:1112,hosttwo:1113" 
	 *     or "hostone,hosttwo" if the default port=1111 is used for hosts
	 *        </pre>
	 * @param user
	 *        the database user on whose behalf the connection is being made
	 * @param password
	 *        the user's password
	 * @param defGraph
	 *        a default Graph name, used for Sesame calls, when contexts list
	 *        is empty, exclude <tt>exportStatements, hasStatement, getStatements</tt> methods 
         *
	 */
	public VirtuosoRepository(String url_hostlist, String user, String password, String defGraph) {
	        this(url_hostlist, user, password, defGraph, false);
	}

	/**
	 * Construct a VirtuosoRepository with a specified parameters.
	 * <tt>useLazyAdd</tt> will be set to <tt>false</tt>.
	 * <tt>defGraph</tt> will be set to <tt>"sesame:nil"</tt>.
	 * 
	 * @param url_hostlist
	 *        the Virtuoso JDBC URL connection string or hostlist for poolled connection.
	 *        Virtuoso database hostlist 
	 *        <pre>
	 *        "hostone:1112,hosttwo:1113" 
	 *     or "hostone,hosttwo" if the default port=1111 is used for hosts
	 *        </pre>
	 * @param user
	 *        the database user on whose behalf the connection is being made
	 * @param password
	 *        the user's password
	 */
	public VirtuosoRepository(String url_hostlist, String user, String password) {
	        this(url_hostlist, user, password, false);
	}

	/**
	 * Opens a connection to this repository that can be used for querying and
	 * updating the contents of the repository. Created connections need to be
	 * closed to make sure that any resources they keep hold of are released. The
	 * best way to do this is to use a try-finally-block as follows:
	 * 
	 * <pre>
	 * Connection con = repository.getConnection();
	 * try {
	 * 	// perform operations on the connection
	 * }
	 * finally {
	 * 	con.close();
	 * }
	 * </pre>
	 * 
	 * @return A connection that allows operations on this repository.
	 * @throws RepositoryException
	 *         If something went wrong during the creation of the Connection.
	 */
	public RepositoryConnection getConnection() throws RepositoryException {
	        if (_pds != null) {
	           try {
		     javax.sql.PooledConnection pconn = _pds.getPooledConnection();
		     java.sql.Connection connection = pconn.getConnection();
		     return new VirtuosoRepositoryConnection(this, connection);
		   }
		   catch (Exception e) {
		     System.out.println("Connection to " + url_hostlist + " is FAILED.");
		     throw new RepositoryException(e);
		   }
	        }
	        else if (_ds != null) {
	           try {
		     java.sql.Connection connection = _ds.getConnection();
		     return new VirtuosoRepositoryConnection(this, connection);
		   }
		   catch (Exception e) {
		     System.out.println("Connection to " + url_hostlist + " is FAILED.");
		     throw new RepositoryException(e);
		   }
	        }
		else if (url_hostlist.startsWith("jdbc:virtuoso://")) {
			try {
				Class.forName("virtuoso.jdbc3.Driver");
				String url = url_hostlist;
				if (url.toLowerCase().indexOf(utf8) == -1) {
	   				if (url.charAt(url.length()-1) != '/')
	     					url = url + "/charset=UTF-8";
	   				else
	     					url = url + "charset=UTF-8";
				}

				if (roundrobin && url.toLowerCase().indexOf("roundrobin=") == -1) {
	   				if (url.charAt(url.length()-1) != '/')
	     					url = url + "/roundrobin=1";
	   				else
	     					url = url + "roundrobin=1";
				}
		
				java.sql.Connection connection = DriverManager.getConnection(url, user, password);
				return new VirtuosoRepositoryConnection(this, connection);
			}
			catch (Exception e) {
				System.out.println("Connection to " + url_hostlist + " is FAILED.");
				throw new RepositoryException(e);
			}
		}
		else {
			try {
				pds.setServerName(url_hostlist);
				pds.setUser(user);
				pds.setPassword(password);
				pds.setCharset(charset);
				pds.setRoundrobin(roundrobin);
				javax.sql.PooledConnection pconn = pds.getPooledConnection();
				java.sql.Connection connection = pconn.getConnection();
				return new VirtuosoRepositoryConnection(this, connection);
			}
			catch (Exception e) {
				System.out.println("Connection to " + url_hostlist + " is FAILED.");
				throw new RepositoryException(e);
			}
		}	
	}

	/**
	 * Set the buffer fetch size(default 200) 
	 * 
	 * @param sz
	 *        buffer fetch size.
	 */
	public void setFetchSize(int sz) {
		this.prefetchSize = sz;
	}

	/**
	 * Get the buffer fetch size
	 */
	public int getFetchSize() {
		return this.prefetchSize;
	}

	/**
	 * Set the batch size for Inserts data(default 5000) 
	 * 
	 * @param sz
	 *        batch size.
	 */
	public void setBatchSize(int sz) {
		this.batchSize = sz;
	}

	/**
	 * Get the batch size for Insert data
	 */
	public int getBatchSize() {
		return this.batchSize;
	}

	/**
	 * Set the query timeout(default 0) 
	 * 
	 * @param seconds
	 *        queryTimeout seconds, 0 - unlimited.
	 */
	public void setQueryTimeout(int seconds) {
		this.queryTimeout = seconds;
	}

	/**
	 * Get the query timeout seconds
	 */
	public int getQueryTimeout() {
		return this.queryTimeout;
	}

	/**
	 * Set the RoundRobin state for connection(default false) 
	 * 
	 * @param sz
	 *        buffer fetch size.
	 */
	public void setRoundrobin(boolean v) {
		this.roundrobin = v;
	}

	/**
	 * Get the RoundRobin state for connection
	 */
	public boolean getRoundrobin() {
		return this.roundrobin;
	}

	
	/**
	 * Set inference RuleSet name
	 * 
	 * @param name
	 *        RuleSet name.
	 */
	public void setRuleSet(String name) {
		if (name != null && name.equals("null"))
		  	name = null;
		this.ruleSet = name;
	}

	/**
	 * Get the RoundRobin state for connection
	 */
	public String getRuleSet() {
		return this.ruleSet;
	}

	
	/**
	 * Get the directory where data and logging for this repository is stored.
	 * 
	 * @return the directory where data for this repository is stored.
	 */
	public File getDataDir() {
		return this.dataDir;
	}

	/**
	 * Gets a ValueFactory for this Repository.
	 * 
	 * @return A repository-specific ValueFactory.
	 */
	public ValueFactory getValueFactory() {
		return this.valueFactory;
	}

	/**
	 * Initializes this repository. A repository needs to be initialized before
	 * it can be used.
	 * 
	 * @throws RepositoryException
	 *         If the initialization failed.
	 */
	public void initialize() throws RepositoryException {
		initialized = true;
	}

        /**
         * Indicates if the Repository has been initialized. Note that the
         * initialization status may change if the Repository is shut down.
         * 
         * @return true iff the repository has been initialized.
         */
        public boolean isInitialized() {
                return initialized;
        }
    

	/**
	 * Checks whether this repository is writable, i.e. if the data contained in
	 * this repository can be changed. The writability of the repository is
	 * determined by the writability of the Sail that this repository operates
	 * on.
	 */
	public boolean isWritable() throws RepositoryException {
		if (!initialized) {
			throw new IllegalStateException("VirtuosoRepository not initialized.");
		}

		return true; // user login has authenticated this connection
	}

	/**
	 * Set the directory where data and logging for this repository is stored.
	 * 
	 * @param dataDir
	 *        the directory where data for this repository is stored
	 */
	public void setDataDir(File dataDir) {
		this.dataDir = dataDir;
	}

	/**
	 * Shuts the repository down, releasing any resources that it keeps hold of.
	 * Once shut down, the repository can no longer be used until it is
	 * re-initialized.
	 */
	public void shutDown() throws RepositoryException {
		initialized = false;
	}

	public int getResultsHandlerType() {
		return resultsHandlerType;
	}

	public void setResultsHandlerType(int handlerType) {
		this.resultsHandlerType = handlerType;
	}

        public void createRuleSet(String ruleSetName, String uriGraphRuleSet) throws RepositoryException
        {
          java.sql.Connection con = ((VirtuosoRepositoryConnection)getConnection()).getQuadStoreConnection();

          try {
	    java.sql.Statement st = con.createStatement();
	    st.execute("rdfs_rule_set('"+ruleSetName+"', '"+uriGraphRuleSet+"')");
	    st.close();
          } catch (Exception e) {
            throw new RepositoryException(e);
          }
        }


}
