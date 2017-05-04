/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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
package virtuoso.sesame4.driver;

import org.openrdf.model.ValueFactory;
import org.openrdf.model.impl.SimpleValueFactory;
import org.openrdf.repository.Repository;
import org.openrdf.repository.RepositoryConnection;
import org.openrdf.repository.RepositoryException;
import virtuoso.jdbc4.VirtuosoConnectionPoolDataSource;
import virtuoso.jdbc4.VirtuosoDataSource;
import virtuoso.jdbc4.VirtuosoXADataSource;

import java.sql.DriverManager;


public class VirtuosoRepositoryConnectionFactory  {

    VirtuosoRepository rep;
    private String drv_url;
    private String _user;
    private String _password;
    private String _delegate;
    private String charset_utf8 = "UTF-8";
    static final String utf8 = "charset=utf-8";

    private VirtuosoDataSource _ds;
    private VirtuosoConnectionPoolDataSource _pds;
    private VirtuosoXADataSource _xads;

    boolean useLazyAdd = true;
    String defGraph = "sesame:nil";


    public VirtuosoRepositoryConnectionFactory(VirtuosoConnectionPoolDataSource ds) {
        super();
        this._pds = ds;
        rep = new VirtuosoRepository((javax.sql.ConnectionPoolDataSource)ds, defGraph, useLazyAdd);
    }

    public VirtuosoRepositoryConnectionFactory(VirtuosoDataSource ds) {
        super();
        this._ds = ds;
        rep = new VirtuosoRepository((javax.sql.DataSource)ds, defGraph, true);
    }

    public VirtuosoRepositoryConnectionFactory(VirtuosoXADataSource ds) {
        super();
        this._xads = ds;
        this.useLazyAdd = false;
        rep = new VirtuosoRepository((javax.sql.ConnectionPoolDataSource)ds, defGraph, useLazyAdd);
    }

    public VirtuosoRepositoryConnectionFactory(String url) {
        super();
        this.drv_url = url.trim();
        rep = new VirtuosoRepository(drv_url, null, null);
    }


    public RepositoryConnection getConnection(String delegate) throws RepositoryException {
        return getConnection(null, null, delegate);
    }

    public RepositoryConnection getConnection(String user, String password) throws RepositoryException {
        return getConnection(user, password, null);
    }

    public synchronized RepositoryConnection getConnection(String user, String password, String delegate) throws RepositoryException {
        String v;
        String uid = (user!=null)?user:_user;
        String pwd = (password!=null)?password:_password;
        String dlg = (delegate!=null)?delegate:_delegate;

        if (_xads != null) {
            try {
                _xads.setRoundrobin(rep.getRoundrobin());
                _xads.setLog_Enable(2);

                v = _xads.getCharset();
                if (v!=null && !v.equalsIgnoreCase(charset_utf8))
                    _xads.setCharset(charset_utf8);

                if (dlg!=null)
                   _xads.setDelegate(dlg);

                javax.sql.XAConnection xconn = _xads.getXAConnection(uid, pwd);
                java.sql.Connection connection = xconn.getConnection();
                return new VirtuosoRepositoryConnection(rep, connection);
            }
            catch (Exception e) {
                System.out.println("Connection has FAILED.");
                throw new RepositoryException(e);
            }
        }
        else if (_pds != null) {
            try {
                _pds.setRoundrobin(rep.getRoundrobin());
                _pds.setLog_Enable(2);

                v = _pds.getCharset();
                if (v!=null && !v.equalsIgnoreCase(charset_utf8))
                    _pds.setCharset(charset_utf8);

                if (dlg!=null)
                    _pds.setDelegate(dlg);

                javax.sql.PooledConnection pconn = _pds.getPooledConnection(uid, pwd);
                java.sql.Connection connection = pconn.getConnection();
                return new VirtuosoRepositoryConnection(rep, connection);
            }
            catch (Exception e) {
                System.out.println("Connection has FAILED.");
                throw new RepositoryException(e);
            }
        }
        else if (_ds != null) {
            try {
                _ds.setRoundrobin(rep.getRoundrobin());
                _ds.setLog_Enable(2);

                v = _ds.getCharset();
                if (v!=null && !v.equalsIgnoreCase(charset_utf8))
                    _ds.setCharset(charset_utf8);

                if (dlg!=null)
                    _ds.setDelegate(dlg);

                java.sql.Connection connection = _ds.getConnection(uid, pwd);
                return new VirtuosoRepositoryConnection(rep, connection);
            }
            catch (Exception e) {
                System.out.println("Connection has FAILED.");
                throw new RepositoryException(e);
            }
        }
        else {
            try {
                Class.forName("virtuoso.jdbc4.Driver");
                String url = drv_url;

                if (dlg!=null) {
                    if (url.charAt(url.length()-1) != '/')
                        url = url + "/delegate='"+dlg+"'";
                    else
                        url = url + "delegate='"+dlg+"'";
                }

                if (url.toLowerCase().indexOf(utf8) == -1) {
                    if (url.charAt(url.length()-1) != '/')
                        url = url + "/charset=UTF-8";
                    else
                        url = url + "charset=UTF-8";
                }

                if (rep.getRoundrobin() && url.toLowerCase().indexOf("roundrobin=") == -1) {
                    if (url.charAt(url.length()-1) != '/')
                        url = url + "/roundrobin=1";
                    else
                        url = url + "roundrobin=1";
                }

                if (url.toLowerCase().indexOf("log_enable=") == -1) {
                    if (url.charAt(url.length()-1) != '/')
                        url = url + "/log_enable=1";
                    else
                        url = url + "log_enable=1";
                }

                java.sql.Connection connection = DriverManager.getConnection(url, user, password);
                return new VirtuosoRepositoryConnection(rep, connection);
            }
            catch (Exception e) {
                System.out.println("Connection to " + drv_url + " has FAILED.");
                throw new RepositoryException(e);
            }
        }
    }


    /**
     * Set the default username
     *
     * @param user
     *        username.
     */
    public void setUser(String user) {
        this._user = user;
    }

    /**
     * Get the default username
     */
    public String getUser() {
        return this._user;
    }


    /**
     * Set the default password
     *
     * @param pwd
     *        password.
     */
    public void setPassword(String pwd) {
        this._password = pwd;
    }

    /**
     * Get the default password
     */
    public String getPassword() {
        return this._password;
    }


    /**
     * Set the default delegate
     *
     * @param dlg
     *        delegate.
     */
    public void setDelegate(String dlg) {
        this._delegate = dlg;
    }

    /**
     * Get the default delegate
     */
    public String getDelegate() {
        return this._delegate;
    }


    /**
     * Set the buffer fetch size(default 100)
     *
     * @param sz
     *        buffer fetch size.
     */
    public void setFetchSize(int sz) {
         rep.setFetchSize(sz);
    }

    /**
     * Get the buffer fetch size
     */
    public int getFetchSize() {
        return rep.getFetchSize();
    }

    /**
     * Set the batch size for Inserts data(default 5000)
     *
     * @param sz
     *        batch size.
     */
    public void setBatchSize(int sz) {
         rep.setBatchSize(sz);
    }

    /**
     * Get the batch size for Insert data
     */
    public int getBatchSize() {
         return rep.getBatchSize();
    }

    /**
     * Set the query timeout(default 0)
     *
     * @param seconds
     *        queryTimeout seconds, 0 - unlimited.
     */
    public void setQueryTimeout(int seconds) {
         rep.setQueryTimeout(seconds);
    }

    /**
     * Get the query timeout seconds
     */
    public int getQueryTimeout() {
        return rep.getQueryTimeout();
    }

    /**
     * Set the UseLazyAdd state for connection(default true)
     * for XADataSource connection set false and can't be changed
     * @param v
     *        true - useLazyAdd
     */
    public void setUseLazyAdd(boolean v) {
        rep.setUseLazyAdd(v);
    }

    /**
     * Get the UseLazyAdd state for connection
     */
    public boolean getUseLazyAdd() {
        return rep.getUseLazyAdd();
    }


    /**
     * Set the RoundRobin state for connection(default false)
     *
     * @param v
     *        true - use roundrobin
     */
    public void setRoundrobin(boolean v) {
        rep.setRoundrobin(v);
    }

    /**
     * Get the RoundRobin state for connection
     */
    public boolean getRoundrobin() {
        return rep.getRoundrobin();
    }


    /**
     * Set the insertBNodeAsURI state for connection(default false)
     *
     * @param v
     *        true - insert BNode as Virtuoso IRI
     *        false - insert BNode as Virtuoso Native BNode
     */
    public void setInsertBNodeAsVirtuosoIRI(boolean v) {
        rep.setInsertBNodeAsVirtuosoIRI(v);
    }

    /**
     * Get the insertBNodeAsURI state for connection
     */
    public boolean getInsertBNodeAsVirtuosoIRI() {
        return rep.getInsertBNodeAsVirtuosoIRI();
    }



    /**
     * Get the insertStringLiteralAsSimple state for connection
     *
     * @return insertStringLiteralAsSimple state
     */
    public boolean getInsertStringLiteralAsSimple() {
        return rep.getInsertStringLiteralAsSimple();
    }

    /**
     * Set the insertStringLiteralAsSimple state for connection(default false) 
     * 
     * @param v
     *        true - insert String Literals as Simple Literals
     *        false - insert String Literals as is
     */
    public void setInsertStringLiteralAsSimple(boolean v) {
        rep.setInsertStringLiteralAsSimple(v);
    }




    /**
     * Set inference RuleSet name
     *
     * @param name
     *        RuleSet name.
     */
    public void setRuleSet(String name) {
        rep.setRuleSet(name);
    }

    /**
     * Get the RoundRobin state for connection
     */
    public String getRuleSet() {
        return rep.getRuleSet();
    }


    /**
     * Set inference MacroLib name
     *
     * @param name
     *        macroLib name.
     */
    public void setMacroLib(String name) {
        rep.setMacroLib(name);
    }

    /**
     * Get the inference MacroLib name
     *
     * @return macroLib name
     */
    public String getMacroLib() {
        return rep.getMacroLib();
    }

    /**
     * Set the concurrency mode for Insert/Update/Delete operations and SPARUL queries
     *
     * @param mode
     *        Concurrency mode
     */
    public void setConcurrencyMode(int mode) throws RepositoryException
    {
        rep.setConcurrencyMode(mode);
    }

    /**
     * Get the concurrency mode for Insert/Update/Delete operations and SPARUL queries
     *
     * @return concurrency mode
     */
    public int getConcurrencyMode() {
        return rep.getConcurrencyMode();
    }



    /**
     * Use defGraph with SPARQL queries, if query default graph wasn't set (default false) 
     * @param v
     *        true - useDefGraphForQueries
     */
    public void setUseDefGraphForQueries(boolean v) {
	rep.setUseDefGraphForQueries(v);
    }

    /**
     * Get the UseDefGraphForQueries state for connection
     */
    public boolean getUseDefGraphForQueries() {
	return rep.getUseDefGraphForQueries();
    }


    public ValueFactory getValueFactory() {
        return rep.getValueFactory();
    }

}
