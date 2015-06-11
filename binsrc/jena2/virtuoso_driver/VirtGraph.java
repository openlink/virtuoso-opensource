/*
 *  $Id: VirtGraph.java,v 1.15.2.18 2012/03/15 12:56:34 source Exp $
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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
import java.util.*;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import javax.sql.*;
import javax.transaction.xa.*;

import com.hp.hpl.jena.rdf.model.Statement;
import virtuoso.sql.*;

import com.hp.hpl.jena.graph.*;
import com.hp.hpl.jena.graph.impl.*;
import com.hp.hpl.jena.shared.*;
import com.hp.hpl.jena.util.iterator.*;
import com.hp.hpl.jena.datatypes.*;
import com.hp.hpl.jena.rdf.model.*;
import com.hp.hpl.jena.rdf.model.impl.*;

import virtuoso.jdbc4.VirtuosoConnectionPoolDataSource;
import virtuoso.jdbc4.VirtuosoDataSource;
import virtuoso.jdbc4.VirtuosoXADataSource;
import virtuoso.jdbc4.VirtuosoDate;
import virtuoso.jdbc4.VirtuosoTime;
import virtuoso.jdbc4.VirtuosoTimestamp;


public class VirtGraph extends GraphBase {
    static {
        VirtuosoQueryEngine.register();
    }

    static final protected String S_BATCH_INSERT = "DB.DBA.rdf_insert_triple_c (?,?,?,?,?,?)";
//    static final protected String S_BATCH_DELETE = "DB.DBA.rdf_delete_triple_c (?,?,?,?,?,?)";
    static final String S_CLEAR_GRAPH = "DB.DBA.rdf_clear_graphs_c (?)";

//    static final String S_TTLP_INSERT = "DB.DBA.TTLP_MT (?, '', ?, 255, 2, 3, ?)";

//    static final String sinsert = "sparql insert into graph iri(??) { `iri(??)` `iri(??)` `bif:__rdf_long_from_batch_params(??,??,??)` }";
    static final String sdelete = "sparql delete from graph iri(??) {`iri(??)` `iri(??)` `bif:__rdf_long_from_batch_params(??,??,??)`}";
    static final protected int BATCH_SIZE = 5000;
    static final protected int MAX_CMD_SIZE = 36000;
    static final String utf8 = "charset=utf-8";
    static final String charset = "UTF-8";
    static public final String DEFAULT = "virt:DEFAULT";

    protected boolean isXA = false;
    protected String graphName;
    protected boolean readFromAllGraphs = false;
    protected String url_hostlist;
    protected String user;
    protected String password;
    protected boolean roundrobin = false;
    protected int prefetchSize = 100;
    protected int batchSize = BATCH_SIZE;
    protected Connection connection = null;
    protected String ruleSet = null;
    protected boolean useSameAs = false;
    protected int queryTimeout = 0;
    protected boolean useReprepare = true;
    protected String sparqlPrefix = null;
    protected boolean insertBNodeAsVirtuosoIRI = false;

    private VirtuosoConnectionPoolDataSource pds = new VirtuosoConnectionPoolDataSource();
    private DataSource ds;
    private XADataSource xa_ds;
    private javax.transaction.xa.XAResource xa_resource = null;
    private XAConnection xa_connection = null;
    protected VirtTransactionHandler tranHandler = null;
    private final Object lck_add = new Object();

    private boolean batch_add_executed = false;
    PreparedStatement psInsert = null;
    java.sql.Statement stInsert_Cmd = null;
    int psInsert_Count = 0;


    public VirtGraph() {
        this(null, "jdbc:virtuoso://localhost:1111/charset=UTF-8", null, null, false);
    }

    public VirtGraph(String graphName) {
        this(graphName, "jdbc:virtuoso://localhost:1111/charset=UTF-8", null, null, false);
    }

    public VirtGraph(String graphName, String _url_hostlist, String user,
                     String password) {
        this(graphName, _url_hostlist, user, password, false);
    }

    public VirtGraph(String url_hostlist, String user, String password) {
        this(null, url_hostlist, user, password, false);
    }


    public VirtGraph(String _graphName, DataSource _ds) {
        super();

        if (_ds instanceof VirtuosoDataSource) {
            VirtuosoDataSource vds = (VirtuosoDataSource) _ds;
            this.url_hostlist = vds.getServerName();
            this.user = vds.getUser();
            this.password = vds.getPassword();
        }

        this.graphName = _graphName == null ? DEFAULT : _graphName;

        try {
            connection = _ds.getConnection();
            ds = _ds;
            ModelCom m = new ModelCom(this); //don't drop is it needed for initialize internal Jena classes
            TypeMapper tm = TypeMapper.getInstance();

            virtuoso.jdbc4.Driver drv = new virtuoso.jdbc4.Driver();
            if (drv.getMajorVersion() >= 3 && drv.getMinorVersion() >= 72)
                useReprepare = false;
        } catch (Exception e) {
            throw new JenaException(e);
        }
    }

    public VirtGraph(DataSource _ds) {
        this(null, _ds);
    }


    public VirtGraph(String _graphName, ConnectionPoolDataSource _ds) {
        super();

        if (_ds instanceof VirtuosoConnectionPoolDataSource) {
            VirtuosoDataSource vds = (VirtuosoDataSource) _ds;
            this.url_hostlist = vds.getServerName();
            this.user = vds.getUser();
            this.password = vds.getPassword();
        }

        this.graphName = _graphName == null ? DEFAULT : _graphName;

        try {
            connection = _ds.getPooledConnection().getConnection();
            ModelCom m = new ModelCom(this); //don't drop is it needed for initialize internal Jena classes
            TypeMapper tm = TypeMapper.getInstance();

            virtuoso.jdbc4.Driver drv = new virtuoso.jdbc4.Driver();
            if (drv.getMajorVersion() >= 3 && drv.getMinorVersion() >= 72)
                useReprepare = false;
        } catch (Exception e) {
            throw new JenaException(e);
        }
    }


    public VirtGraph(ConnectionPoolDataSource _ds) {
        this(null, _ds);
    }


    public VirtGraph(String _graphName, XADataSource _ds) {
        super();

        if (_ds instanceof VirtuosoXADataSource) {
            VirtuosoXADataSource vds = (VirtuosoXADataSource) _ds;
            this.url_hostlist = vds.getServerName();
            this.user = vds.getUser();
            this.password = vds.getPassword();
        }

        this.graphName = _graphName == null ? DEFAULT : _graphName;

        try {
            xa_connection = _ds.getXAConnection();
            connection = xa_connection.getConnection();
            isXA = true;
            ModelCom m = new ModelCom(this); //don't drop is it needed for initialize internal Jena classes
            TypeMapper tm = TypeMapper.getInstance();

            virtuoso.jdbc4.Driver drv = new virtuoso.jdbc4.Driver();
            if (drv.getMajorVersion() >= 3 && drv.getMinorVersion() >= 72)
                useReprepare = false;
        } catch (Exception e) {
            throw new JenaException(e);
        }
    }


    public VirtGraph(XADataSource _ds) {
        this(null, _ds);
    }


    public VirtGraph(String _graphName, String _url_hostlist, String user,
                     String password, boolean _roundrobin) {
        super();

        this.url_hostlist = _url_hostlist.trim();
        this.roundrobin = _roundrobin;
        this.user = user;
        this.password = password;

        this.graphName = _graphName == null ? DEFAULT : _graphName;

        try {
            if (url_hostlist.startsWith("jdbc:virtuoso://")) {

                String url = url_hostlist;
                if (url.toLowerCase().indexOf(utf8) == -1) {
                    if (url.charAt(url.length() - 1) != '/')
                        url = url + "/charset=UTF-8";
                    else
                        url = url + "charset=UTF-8";
                }
                if (roundrobin && url.toLowerCase().indexOf("roundrobin=") == -1) {
                    if (url.charAt(url.length() - 1) != '/')
                        url = url + "/roundrobin=1";
                    else
                        url = url + "roundrobin=1";
                }
                Class.forName("virtuoso.jdbc4.Driver");
                connection = DriverManager.getConnection(url, user, password);
            } else {
                pds.setServerName(url_hostlist);
                pds.setUser(user);
                pds.setPassword(password);
                pds.setCharset(charset);
                pds.setRoundrobin(roundrobin);
                javax.sql.PooledConnection pconn = pds.getPooledConnection();
                connection = pconn.getConnection();
                ds = (javax.sql.DataSource) pds;
            }

            ModelCom m = new ModelCom(this); //don't drop is it needed for initialize internal Jena classes
            TypeMapper tm = TypeMapper.getInstance();

            virtuoso.jdbc4.Driver drv = new virtuoso.jdbc4.Driver();
            if (drv.getMajorVersion() >= 3 && drv.getMinorVersion() >= 72)
                useReprepare = false;
        } catch (Exception e) {
            throw new JenaException(e);
        }

    }

    // getters
    public DataSource getDataSource() {
        return ds;
    }

    public XAResource getXAResource() {
        try {
            if (xa_resource == null)
                xa_resource = (xa_connection != null) ? xa_connection.getXAResource() : null;
            return xa_resource;
        } catch (SQLException e) {
            throw new JenaException(e);
        }
    }

    public String getGraphName() {
        return this.graphName;
    }

    protected void setGraphName(String name) {
        this.graphName = name;
    }

    public String getGraphUrl() {
        return this.url_hostlist;
    }

    public String getGraphUser() {
        return this.user;
    }

    public String getGraphPassword() {
        return this.password;
    }

    public Connection getConnection() {
        return this.connection;
    }


    public int getFetchSize() {
        return this.prefetchSize;
    }


    public void setFetchSize(int sz) {
        this.prefetchSize = sz;
    }


    public int getQueryTimeout() {
        return this.queryTimeout;
    }


    public void setQueryTimeout(int seconds) {
        this.queryTimeout = seconds;
    }


    public int getBatchSize() {
        return this.batchSize;
    }


    public void setBatchSize(int sz) {
        this.batchSize = sz;
    }


    public String getSparqlPrefix() {
        return this.sparqlPrefix;
    }


    public void setSparqlPrefix(String val) {
        this.sparqlPrefix = val;
    }

    public boolean getInsertBNodeAsVirtuosoIRI() {
        return this.insertBNodeAsVirtuosoIRI;
    }


    public void setInsertBNodeAsVirtuosoIRI(boolean v) {
        this.insertBNodeAsVirtuosoIRI = v;
    }



    public int getCount() {
        return size();
    }


    public void remove(List triples) {
        delete(triples.iterator(), null);
    }

    public void remove(Triple t) {
        delete(t);
    }


    public boolean getReadFromAllGraphs() {
        return readFromAllGraphs;
    }

    public void setReadFromAllGraphs(boolean val) {
        readFromAllGraphs = val;
    }


    public String getRuleSet() {
        return ruleSet;
    }

    public void setRuleSet(String _ruleSet) {
        ruleSet = _ruleSet;
    }

    public boolean getSameAs() {
        return useSameAs;
    }

    public void setSameAs(boolean _sameAs) {
        useSameAs = _sameAs;
    }


    public void createRuleSet(String ruleSetName, String uriGraphRuleSet) {
        checkOpen();

        try {
            java.sql.Statement st = createStatement();
            st.execute("rdfs_rule_set('" + ruleSetName + "', '" + uriGraphRuleSet + "')");
            st.close();
        } catch (Exception e) {
            throw new JenaException(e);
        }
    }


    public void removeRuleSet(String ruleSetName, String uriGraphRuleSet) {
        checkOpen();

        try {
            java.sql.Statement st = createStatement();
            st.execute("rdfs_rule_set('" + ruleSetName + "', '" + uriGraphRuleSet + "', 1)");
            st.close();
        } catch (Exception e) {
            throw new JenaException(e);
        }
    }


    private static String escapeString(String s) {
        StringBuilder sb = new StringBuilder(s.length());
        int slen = s.length();

        for (int i = 0; i < slen; i++) {
            char c = s.charAt(i);
            int cInt = c;

            if (c == '\\') {
                sb.append("\\\\");
            } else if (c == '"') {
                sb.append("\\\"");
            } else if (c == '\n') {
                sb.append("\\n");
            } else if (c == '\r') {
                sb.append("\\r");
            } else if (c == '\t') {
                sb.append("\\t");
            } else if (
                    cInt >= 0x0 && cInt <= 0x8 ||
                            cInt == 0xB || cInt == 0xC ||
                            cInt >= 0xE && cInt <= 0x1F ||
                            cInt >= 0x7F && cInt <= 0xFFFF) {
                sb.append("\\u");
                sb.append(toHexString(cInt, 4));
            } else if (cInt >= 0x10000 && cInt <= 0x10FFFF) {
                sb.append("\\U");
                sb.append(toHexString(cInt, 8));
            } else {
                sb.append(c);
            }
        }
        return sb.toString();
    }

    private static String toHexString(int decimal, int stringLength) {
        StringBuilder sb = new StringBuilder(stringLength);
        String hexVal = Integer.toHexString(decimal).toUpperCase();

        int nofZeros = stringLength - hexVal.length();
        for (int i = 0; i < nofZeros; i++)
            sb.append('0');

        sb.append(hexVal);
        return sb.toString();
    }


    protected java.sql.Statement createStatement() throws SQLException {
        checkOpen();
        java.sql.Statement st = connection.createStatement();
        if (queryTimeout > 0)
            st.setQueryTimeout(queryTimeout);
        st.setFetchSize(prefetchSize);
        return st;
    }

    protected java.sql.PreparedStatement prepareStatement(String sql) throws SQLException {
        checkOpen();
        java.sql.PreparedStatement st = connection.prepareStatement(sql);
        if (queryTimeout > 0)
            st.setQueryTimeout(queryTimeout);
        st.setFetchSize(prefetchSize);
        return st;
    }


    protected void appendSparqlPrefixes(StringBuilder sb) {
        if (ruleSet != null)
            sb.append(" define input:inference '" + ruleSet + "'\n ");

        if (sparqlPrefix != null) {
            sb.append(sparqlPrefix);
            sb.append('\n');
        }

        if (useSameAs)
            sb.append(" define input:same-as \"yes\"\n ");
        sb.append('\n');
    }


    static String BNode2String(Node n) {
        String ns = n.toString();
        if (ns.startsWith("nodeID://"))
            return ns;
        else
            return "_:" + n.toString().replace(':', '_').replace('-', 'z').replace('/','y');
    }

    static String BNode2String_add(Node n) {
        String ns = n.toString();
        return "_:" + n.toString().replace(':', '_').replace('-', 'z').replace('/','y');
    }


    public String Node2Str(Node n) {
        if (n.isURI()) {
            return "<" + n + ">";
        } else if (n.isBlank()) {
            String ns = n.toString();
            if (ns.startsWith("nodeID://"))
                return "`iri('"+ns+"')`";
            else
                return insertBNodeAsVirtuosoIRI?("<" + BNode2String(n) + ">"):(BNode2String(n)); 
        } else if (n.isLiteral()) {
            String s;
            StringBuilder sb = new StringBuilder();
            sb.append("\"");
            sb.append(escapeString(n.getLiteralLexicalForm()));
            sb.append("\"");

            s = n.getLiteralLanguage();
            if (s != null && s.length() > 0) {
                sb.append("@");
                sb.append(s);
            }
            s = n.getLiteralDatatypeURI();
            if (s != null && s.length() > 0) {
                sb.append("^^<");
                sb.append(s);
                sb.append(">");
            }
            return sb.toString();
        } else {
            return "<" + n + ">";
        }
    }

    public String Node2Str_add(Object o) {
        if (o instanceof Node) {
            Node n = (Node)o;
            if (n.isURI()) {
                return "<" + n + ">";
            } else if (n.isBlank()) {
                if (!this.insertBNodeAsVirtuosoIRI) {
                    return BNode2String_add(n);
                } else {
                    return "<" + BNode2String_add(n) + ">";
                }
            } else if (n.isLiteral()) {
                String s;
                StringBuilder sb = new StringBuilder();
                sb.append("\"");
                sb.append(escapeString(n.getLiteralLexicalForm()));
                sb.append("\"");

                s = n.getLiteralLanguage();
                if (s != null && s.length() > 0) {
                    sb.append("@");
                    sb.append(s);
                }
                s = n.getLiteralDatatypeURI();
                if (s != null && s.length() > 0) {
                    sb.append("^^<");
                    sb.append(s);
                    sb.append(">");
                }
                return sb.toString();
            } else {
                return "<" + n + ">";
            }
        } else {
            return o.toString();
        }
    }

    void bindSubject(PreparedStatement ps, int col, Node n) throws SQLException {
        if (n == null)
            return;
        if (n.isURI())
            ps.setString(col, n.toString());
        else if (n.isBlank())
            ps.setString(col, BNode2String(n));
        else
            throw new SQLException("Only URI or Blank nodes can be used as subject");
    }


    void bindPredicate(PreparedStatement ps, int col, Node n) throws SQLException {
        if (n == null)
            return;
        if (n.isURI())
            ps.setString(col, n.toString());
        else
            throw new SQLException("Only URI nodes can be used as predicate");
    }

    void bindObject(PreparedStatement ps, int col, Node n) throws SQLException {
        if (n == null)
            return;
        if (n.isURI()) {
            ps.setInt(col, 1);
            ps.setString(col + 1, n.toString());
            ps.setNull(col + 2, java.sql.Types.VARCHAR);
        } else if (n.isBlank()) {
            ps.setInt(col, 1);  //?? must be 1 for search
            ps.setString(col + 1, BNode2String(n));
            ps.setNull(col + 2, java.sql.Types.VARCHAR);
        } else if (n.isLiteral()) {
            String llang = n.getLiteralLanguage();
            String ltype = n.getLiteralDatatypeURI();
            if (llang != null && llang.length() > 0) {
                ps.setInt(col, 5);
                ps.setString(col + 1, n.getLiteralLexicalForm());
                ps.setString(col + 2, n.getLiteralLanguage());
            } else if (ltype != null && ltype.length() > 0) {
                ps.setInt(col, 4);
                ps.setString(col + 1, n.getLiteralLexicalForm());
                ps.setString(col + 2, n.getLiteralDatatypeURI());
            } else {
                ps.setInt(col, 3);
                ps.setString(col + 1, n.getLiteralLexicalForm());
                ps.setNull(col + 2, java.sql.Types.VARCHAR);
            }
        } else {
            ps.setInt(col, 3);
            ps.setString(col + 1, n.toString());
            ps.setNull(col + 2, java.sql.Types.VARCHAR);
        }
    }


    @Override
    public void performAdd(Triple t) {
            performAdd(null, t.getSubject(), t.getPredicate(), t.getObject());
    }


    protected void performAdd(String _gName, Triple t) {
        performAdd(_gName, t.getSubject(), t.getPredicate(), t.getObject());
    }


    protected void performAdd(String _gName, Node nS, Node nP, Node nO) {
        _gName = (_gName != null ? _gName : this.graphName);

        try {
            if (this.batch_add_executed) {
                psInsert = addToQuadStore_batch(psInsert, nS, nP, nO, _gName);
                psInsert_Count++;

                if (psInsert_Count > BATCH_SIZE) {
                    psInsert = flushDelayAdd_batch(psInsert, psInsert_Count);
                    psInsert_Count = 0;
                }

            } else {
/**
                java.sql.PreparedStatement ps;
                ps = prepareStatement(S_TTLP_INSERT);
                int transactional = connection.getAutoCommit() ? 0 : 1;

                StringBuilder data = new StringBuilder(1024);
                data.append(Node2Str_add(nS));
                data.append(' ');
                data.append(Node2Str_add(nP));
                data.append(' ');
                data.append(Node2Str_add(nO));
                data.append(" .");

                ps.setString(1, data.toString());
                ps.setString(2, _gName);
                ps.setInt(3, transactional);
                ps.executeUpdate();
                ps.close();
**/
                java.sql.Statement st = createStatement();

                StringBuilder data = new StringBuilder(1024);
                data.append("sparql insert into <");
                data.append(_gName);
                data.append("> { ");
                data.append(Node2Str_add(nS));
                data.append(' ');
                data.append(Node2Str_add(nP));
                data.append(' ');
                data.append(Node2Str_add(nO));
                data.append(" .}");

                st.execute(data.toString());
                st.close();
            }
        } catch (Exception e) {
            throw new AddDeniedException(e.toString());
        }
    }


    @Override
    public void performDelete(Triple t) {
        performDelete(null, t.getSubject(), t.getPredicate(), t.getObject());
    }


    protected void performDelete(String _gName, Node s, Node p, Node o) {
        java.sql.PreparedStatement ps;

        try {
            ps = prepareStatement(sdelete);
            ps.setString(1, (_gName != null ? _gName : this.graphName));
            bindSubject(ps, 2, s);
            bindPredicate(ps, 3, p);
            bindObject(ps, 4, o);

            ps.execute();
            ps.close();
        } catch (Exception e) {
            throw new DeleteDeniedException(e.toString());
        }
    }


    /**
     * more efficient
     */
    @Override
    protected int graphBaseSize() {
        StringBuilder sb = new StringBuilder("select count(*) from (sparql define input:storage \"\" ");

        appendSparqlPrefixes(sb);

        if (readFromAllGraphs)
            sb.append(" select * where {?s ?p ?o })f");
        else
            sb.append(" select * where { graph `iri(??)` { ?s ?p ?o }})f");

        ResultSet rs = null;
        int ret = 0;

        checkOpen();

        try {
            java.sql.PreparedStatement ps = prepareStatement(sb.toString());

            if (!readFromAllGraphs)
                ps.setString(1, graphName);

            rs = ps.executeQuery();
            if (rs.next())
                ret = rs.getInt(1);
            rs.close();
            ps.close();
        } catch (Exception e) {
            throw new JenaException(e);
        }
        return ret;
    }


    /**
     * maybe more efficient than default impl
     */
    @Override
    protected boolean graphBaseContains(Triple t) {
        return graphBaseContains(null, t);
    }


    protected boolean graphBaseContains(String _gName, Triple t) {
        ResultSet rs = null;
        StringBuilder sb = new StringBuilder("sparql define input:storage \"\" ");
        Node nS, nP, nO;

        checkOpen();
        appendSparqlPrefixes(sb);

        if (readFromAllGraphs && _gName == null)
            sb.append(" select * where { ");
        else
            sb.append(" select * from <" + (_gName != null ? _gName : graphName) + "> where { ");

        nS = t.getSubject();
        nP = t.getPredicate();
        nO = t.getObject();

        if (nP.isBlank())
            throw new JenaException("BNode could not be used as Predicate");

        sb.append(' ');
        if (!Node.ANY.equals(nS))
            sb.append("`iri(??)`");
        else
            sb.append("?s");

        sb.append(' ');
        if (!Node.ANY.equals(nP))
            sb.append("`iri(??)`");
        else
            sb.append("?p");

        sb.append(' ');
        if (!Node.ANY.equals(nO))
            sb.append("`bif:__rdf_long_from_batch_params(??,??,??)`");
        else
            sb.append("?o");

        sb.append(" } limit 1");

        try {
            java.sql.PreparedStatement ps = prepareStatement(sb.toString());
            int col = 1;

            if (!Node.ANY.equals(nS))
                bindSubject(ps, col++, nS);
            if (!Node.ANY.equals(nP))
                bindPredicate(ps, col++, nP);
            if (!Node.ANY.equals(nO))
                bindObject(ps, col, nO);

            rs = ps.executeQuery();
            boolean ret = rs.next();
            rs.close();
            ps.close();
            return ret;

        } catch (Exception e) {
            throw new JenaException(e);
        }
    }


    @Override
    public ExtendedIterator<Triple> graphBaseFind(TripleMatch tm) {
        return graphBaseFind(null, tm);
    }


    protected ExtendedIterator<Triple> graphBaseFind(String _gName, TripleMatch tm) {
        StringBuilder sb = new StringBuilder("sparql ");
        Node nS, nP, nO;

        checkOpen();

        appendSparqlPrefixes(sb);


        if (readFromAllGraphs && _gName == null)
            sb.append(" select * where { ");
        else
            sb.append(" select * from <" + (_gName != null ? _gName : graphName) + "> where { ");

        nS = tm.getMatchSubject();
        nP = tm.getMatchPredicate();
        nO = tm.getMatchObject();

        if (nP != null && nP.isBlank())
            throw new JenaException("BNode could not be used as Predicate");

        sb.append(' ');
        if (nS != null)
            sb.append("`iri(??)`");
        else
            sb.append("?s");

        sb.append(' ');
        if (nP != null)
            sb.append("`iri(??)`");
        else
            sb.append("?p");

        sb.append(' ');
        if (nO != null)
            sb.append("`bif:__rdf_long_from_batch_params(??,??,??)`");
        else
            sb.append("?o");

        sb.append(" }");

        try {
            java.sql.PreparedStatement ps = prepareStatement(sb.toString());
            int col = 1;

            if (nS != null)
                bindSubject(ps, col++, nS);
            if (nP != null)
                bindPredicate(ps, col++, nP);
            if (nO != null)
                bindObject(ps, col, nO);

            return new VirtResSetIter(this, ps, ps.executeQuery(), tm);
        } catch (Exception e) {
            throw new JenaException(e);
        }
    }


    @Override
    public void close() {
        try {
            super.close(); // will set closed = true
            if (connection != null)
                connection.close();
            connection = null;
            if (xa_connection != null)
                xa_connection.close();
            xa_connection = null;
        } catch (Exception e) {
            throw new JenaException(e);
        }
    }


// Extra functions

    @Override
    public void clear() {
        clear(NodeFactory.createURI(this.graphName));
        getEventManager().notifyEvent(this, GraphEvents.removeAll);
    }


    public void clear(Node... graphs) {
        if (graphs != null && graphs.length > 0)
            try {
                String[] graphNames = new String[graphs.length];
                for (int i = 0; i < graphs.length; i++)
                    graphNames[i] = graphs[i].toString();

                java.sql.PreparedStatement ps = prepareStatement(S_CLEAR_GRAPH);

                Array gArray = connection.createArrayOf("VARCHAR", graphNames);
                ps.setArray(1, gArray);
                ps.executeUpdate();
                ps.close();
                gArray.free();
            } catch (Exception e) {
                throw new JenaException(e);
            }
    }


    public void read(String url, String type) {
        StringBuilder sb = new StringBuilder("sparql \n");

        appendSparqlPrefixes(sb);

        sb.append("load \"" + url + "\" into graph <" + graphName + ">");

        checkOpen();
        try {
            java.sql.Statement stmt = createStatement();
            stmt.execute(sb.toString());
            stmt.close();
        } catch (Exception e) {
            throw new JenaException(e);
        }
    }



    protected void startBatchAdd() {
        synchronized(lck_add) {
            if (batch_add_executed)
                throw new JenaException("Batch mode is started already");
            batch_add_executed = true;
            try {
                if (!insertBNodeAsVirtuosoIRI) {
                    stInsert_Cmd = createStatement();
                    stInsert_Cmd.executeUpdate("connection_set ('RDF_INSERT_TRIPLE_C_BNODES', dict_new(1000))");
                }
            } catch (SQLException e) {
                throw new JenaException(e);
            }
        }
    }

    protected void stopBatchAdd() {
        synchronized(lck_add) {
            if (!batch_add_executed)
                return;
            try {
                if (psInsert!=null && psInsert_Count>0) {
                    psInsert.executeBatch();
                    psInsert.clearBatch();
                    psInsert_Count = 0;
                }
                if (stInsert_Cmd!=null) {
                    stInsert_Cmd.executeUpdate("connection_set ('RDF_INSERT_TRIPLE_C_BNODES', NULL)");
                }
            } catch (SQLException e) {
                throw new JenaException(e);
            }

            if (psInsert!=null) {
                try {
                    psInsert.close();
                } catch (Exception e) {}
            }
            if (stInsert_Cmd!=null) {
                try {
                    stInsert_Cmd.close();
                } catch (Exception e) {}
            }
            psInsert = null;
            stInsert_Cmd = null;
            batch_add_executed = false;
        }
    }



    private synchronized PreparedStatement addToQuadStore_batch(PreparedStatement ps,
                                                                    Node subject, Node predicate,
                                                                    Node object, String _gName)
    {
        try {
            if (ps == null)
                ps = prepareStatement(S_BATCH_INSERT);
            bindBatchParams(ps, subject, predicate, object, _gName);
            ps.addBatch();
        } catch (Exception e) {
            throw new JenaException(e);
        }
        return ps;
    }

    private synchronized PreparedStatement flushDelayAdd_batch(PreparedStatement ps, int psCount) {
        try {
            if (psCount > 0 && ps != null) {
                ps.executeBatch();
                ps.clearBatch();
                if (useReprepare) {
                    try {
                        ps.close();
                    } catch (Exception e) {
                    }
                    ps = null;
                }
            }
        } catch (Exception e) {
            throw new JenaException(e);
        }
        return ps;
    }

/**
    private synchronized void flushDelayAdd_batch_BNode(java.sql.Statement st,
                                                        Map<String,StringBuilder> map) {
        try {
            for(Map.Entry<String,StringBuilder> e : map.entrySet()) {

                StringBuilder sb = new StringBuilder(256);
                sb.append("sparql define output:format '_JAVA_' insert into <");
                sb.append(e.getKey());
                sb.append("> { ");
                sb.append(e.getValue().toString());
                sb.append(" }");
                st.executeUpdate(sb.toString());
            }
            map.clear();
        } catch (Exception e) {
            throw new JenaException(e);
        }
    }
**/

    //--java5 or newer    @SuppressWarnings("unchecked")
    void add(String _gName, Iterator<Triple> it, List<Triple> list) {
        synchronized (lck_add) {
            PreparedStatement _ps = null;
            java.sql.Statement _st_cmd = null;
            _gName = (_gName != null ? _gName : graphName);

            checkOpen();

            try {
                if (!insertBNodeAsVirtuosoIRI) {
                    _st_cmd = createStatement();
                    _st_cmd.executeUpdate("connection_set ('RDF_INSERT_TRIPLE_C_BNODES', dict_new(1000))");
                }

                int count = 0;
                while (it.hasNext()) {
                    Triple t = it.next();

                    if (list != null)
                        list.add(t);

                    Node nS = t.getSubject();
                    Node nP = t.getPredicate();
                    Node nO = t.getObject();

                    _ps = addToQuadStore_batch(_ps, nS, nP, nO, _gName);
                    count++;
                    if (count > BATCH_SIZE) {
                        _ps = flushDelayAdd_batch(_ps, count);
                        count = 0;
                    }
                }

                if (count > 0)
                    _ps = flushDelayAdd_batch(_ps, count);
                if (_st_cmd!=null)
                    _st_cmd.executeUpdate("connection_set ('RDF_INSERT_TRIPLE_C_BNODES', NULL)");

            } catch (Exception e) {
                throw new JenaException(e);
            } finally {
                if (_ps != null) {
                    try {
                        _ps.close();
                    } catch (Exception e) {
                    }
                }
                if (_st_cmd != null) {
                    try {
                        _st_cmd.close();
                    } catch (Exception e) {
                    }
                }
            }
        }
    }


    protected void add(String _gName, Iterator<Statement> it) {
        synchronized (lck_add) {
            PreparedStatement _ps = null;
            java.sql.Statement _st_cmd = null;
            _gName = (_gName != null ? _gName : graphName);

            checkOpen();

            try {
                if (!insertBNodeAsVirtuosoIRI) {
                    _st_cmd = createStatement();
                    _st_cmd.executeUpdate("connection_set ('RDF_INSERT_TRIPLE_C_BNODES', dict_new(1000))");
                }

                int count = 0;
                while (it.hasNext()) {
                    Statement t = it.next();

                    Node nS = t.getSubject().asNode();
                    Node nP = t.getPredicate().asNode();
                    Node nO = t.getObject().asNode();

                    _ps = addToQuadStore_batch(_ps, nS, nP, nO, _gName);
                    count++;
                    if (count > BATCH_SIZE) {
                        _ps = flushDelayAdd_batch(_ps, count);
                        count = 0;
                    }
                }

                if (count > 0)
                    _ps = flushDelayAdd_batch(_ps, count);
                if (_st_cmd!=null)
                    _st_cmd.executeUpdate("connection_set ('RDF_INSERT_TRIPLE_C_BNODES', NULL)");

            } catch (Exception e) {
                throw new JenaException(e);
            } finally {
                if (_ps != null) {
                    try {
                        _ps.close();
                    } catch (Exception e) {
                    }
                }
                if (_st_cmd != null) {
                    try {
                        _st_cmd.close();
                    } catch (Exception e) {
                    }
                }
            }
        }
    }


    /***
/// disabled, because there is issue in DB.DBA.rdf_delete_triple_c

    void delete(Iterator<Triple> it, List<Triple> list) 
    {
      PreparedStatement ps = null;
      try {
        ps = prepareStatement(S_BATCH_DELETE);

        int count = 0;
	    
        while (it.hasNext())
        {
          Triple t = (Triple) it.next();

          if (list != null)
            list.add(t);

          bindBatchParams(ps, t.getSubject(), t.getPredicate(),
          		t.getObject(), this.graphName);
          ps.addBatch();
          count++;

          if (count > batchSize) {
	    ps.executeBatch();
	    ps.clearBatch();
            count = 0;
            if (useReprepare) {
               try {
                 ps.close();
                 ps = null;
               } catch(Exception e){}
               ps = prepareStatement(S_BATCH_DELETE);
            }
          }
        }

        if (count > 0) 
        {
	  ps.executeBatch();
	  ps.clearBatch();
        }

      }	catch(Exception e) {
        throw new JenaException(e);
      } finally {
        if (ps!=null)
          try {
            ps.close();
          } catch (SQLException e) {}
      }
    }
***/
    void delete(Iterator<Triple> it, List<Triple> list)
    {
        String del_start = "sparql define output:format '_JAVA_' DELETE FROM <";
        java.sql.Statement stmt = null;
        int count = 0;
        StringBuilder data = new StringBuilder(256);

        data.append(del_start);
        data.append(this.graphName);
        data.append("> { ");

        try {
            stmt = createStatement();

            while (it.hasNext()) {
                Triple t = (Triple) it.next();

                if (list != null)
                    list.add(t);

                StringBuilder row = new StringBuilder(256);
                row.append(Node2Str(t.getSubject()));
                row.append(' ');
                row.append(Node2Str(t.getPredicate()));
                row.append(' ');
                row.append(Node2Str(t.getObject()));
                row.append(" .\n");

                if (count > 0 && data.length() + row.length() > MAX_CMD_SIZE) {
                    data.append(" }");
                    stmt.execute(data.toString());

                    data.setLength(0);
                    data.append(del_start);
                    data.append(this.graphName);
                    data.append("> { ");
                    count = 0;
                }

                data.append(row);
                count++;
            }

            if (count > 0) {
                data.append(" }");
                stmt.execute(data.toString());
            }

        } catch (Exception e) {
            throw new JenaException(e);
        } finally {
            try {
                if (stmt!=null)
                  stmt.close();
            } catch (Exception e) {
            }
        }
    }


    protected void delete(String _gName, Iterator<Statement> it)
    {
        String del_start = "sparql define output:format '_JAVA_' DELETE FROM <";
        java.sql.Statement stmt = null;
        int count = 0;
        StringBuilder data = new StringBuilder(256);

        data.append(del_start);
        data.append(_gName);
        data.append("> { ");

        try {
            stmt = createStatement();

            while (it.hasNext()) {
                Statement t = it.next();

                StringBuilder row = new StringBuilder(256);
                row.append(Node2Str(t.getSubject().asNode()));
                row.append(' ');
                row.append(Node2Str(t.getPredicate().asNode()));
                row.append(' ');
                row.append(Node2Str(t.getObject().asNode()));
                row.append(" .\n");

                if (count > 0 && data.length() + row.length() > MAX_CMD_SIZE) {
                    data.append(" }");
                    stmt.execute(data.toString());

                    data.setLength(0);
                    data.append(del_start);
                    data.append(_gName);
                    data.append("> { ");
                    count = 0;
                }

                data.append(row);
                count++;
            }

            if (count > 0) {
                data.append(" }");
                stmt.execute(data.toString());
            }

        } catch (Exception e) {
            throw new JenaException(e);
        } finally {
            try {
                if (stmt!=null)
                    stmt.close();
            } catch (Exception e) {
            }
        }
    }


    protected void md_delete_Model(StmtIterator it)
    {
        LinkedList<DelItem> lst = new LinkedList<DelItem>();
        LinkedList<DelItem> cmd = new LinkedList<DelItem>();
        while(it.hasNext()) {
            Statement st = it.nextStatement();
            Node s = st.getSubject().asNode();
            Node p = st.getPredicate().asNode();
            Node o = st.getObject().asNode();
            if (!s.isBlank() && !p.isBlank() && !o.isBlank())
                cmd.add(new DelItem(s, p, o));
            else
                lst.add(new DelItem(s, p, o));
        }
        it.close();

        // process Non Blank items
        md_apply_delete(cmd, null, true);
        cmd.clear();

        // process Blank items
        while(lst.size() > 0) {
            HashMap<String,String> bnodes = new HashMap<String,String>();
            DelItem i = lst.removeFirst();
            md_load_Bnodes(bnodes, i);
            cmd.add(i);

            boolean added = false;
            do {
                Iterator<DelItem> iter = lst.iterator();
                added = false;
                while(iter.hasNext()) {
                    i = iter.next();
                    if (md_check_Item(bnodes, i)) {
                        cmd.add(i);
                        iter.remove();
                        added = true;
                    }
                }
            } while(added);

            md_apply_delete(cmd, bnodes, false);
            cmd.clear();
        }
    }


    void md_load_Bnodes(HashMap<String,String> bnodes, DelItem i)
    {
        if (i.s instanceof String)
            bnodes.put((String)i.s, (String)i.s);
        if (i.p instanceof String)
            bnodes.put((String)i.p, (String)i.p);
        if (i.o instanceof String)
            bnodes.put((String)i.o, (String)i.o);
    }


    boolean md_check_Item(HashMap<String,String> bnodes, DelItem i)
    {
        boolean add = false;

        if (i.s instanceof String && bnodes.containsKey((String)i.s))
            add = true;
        if (i.p instanceof String && bnodes.containsKey((String)i.p))
            add = true;
        if (i.o instanceof String && bnodes.containsKey((String)i.o))
            add = true;

        if (add)
            md_load_Bnodes(bnodes, i);

        return add;
    }

    void md_apply_delete(LinkedList<DelItem> cmd, HashMap<String,String> bnodes, boolean splitCmdData)
    {
        String del_start = null;

        if (bnodes!=null) {
            int id = 0;
            for(String key: bnodes.keySet()) {
                bnodes.put(key, "?a"+id);
                id++;
            }
        }

        if (bnodes!=null)
          del_start = "sparql define output:format '_JAVA_' DELETE WHERE { GRAPH <";
        else
          del_start = "sparql define output:format '_JAVA_' DELETE FROM <";

        java.sql.Statement stmt = null;
        int count = 0;
        StringBuilder data = new StringBuilder(256);

        data.append(del_start);
        data.append(this.graphName);
        data.append("> { ");

        try {
            stmt = createStatement();

            for(DelItem it : cmd) {
                StringBuilder row = new StringBuilder(256);
                if (bnodes!=null && it.s instanceof String) {
                    row.append(bnodes.get((String)it.s));
                } else {
                    row.append(Node2Str((Node)it.s));
                }
                row.append(' ');

                if (bnodes!=null && it.p instanceof String) {
                    row.append(bnodes.get((String)it.p));
                } else {
                    row.append(Node2Str((Node)it.p));
                }
                row.append(' ');

                if (bnodes!=null && it.o instanceof String) {
                    row.append(bnodes.get((String)it.o));
                } else {
                    row.append(Node2Str((Node)it.o));
                }
                row.append(" .\n");

                if (splitCmdData && count > 0 && data.length() + row.length() > MAX_CMD_SIZE) {
                    if (bnodes!=null)
                      data.append(" }}");
                    else
                      data.append(" }");

                    stmt.execute(data.toString());

                    data.setLength(0);
                    data.append(del_start);
                    data.append(this.graphName);
                    data.append("> { ");
                    count = 0;
                }

                data.append(row);
                count++;
            }

            if (count > 0) {
                if (bnodes!=null)
                  data.append(" }}");
                else
                  data.append(" }");

                stmt.execute(data.toString());
            }

        } catch (Exception e) {
            throw new JenaException(e+"\n"+data.toString());
        } finally {
            try {
                if (stmt!=null)
                    stmt.close();
            } catch (Exception e) {  }
        }
    }


    class DelItem {
        Object s;
        Object p;
        Object o;

        DelItem(Node _s, Node _p, Node _o) {
            s = _s.isBlank() ? _s.toString() : _s;
            p = _p.isBlank() ? _p.toString() : _p;
            o = _o.isBlank() ? _o.toString() : _o;
        }
    }


    protected void bindBatchParams(PreparedStatement ps,
                                   Node subject,
                                   Node predicate,
                                   Node object,
                                   String _graphName) throws SQLException {
        ps.setString(1, subject.isBlank() ? BNode2String(subject) : subject.toString());
        ps.setString(2, predicate.toString());

        if (object.isURI()) {
            ps.setString(3, object.toString());
            ps.setNull(4, java.sql.Types.VARCHAR);
            ps.setInt(5, 0);
        } else if (object.isBlank()) {
            ps.setString(3, BNode2String(object));
            ps.setNull(4, java.sql.Types.VARCHAR);
            ps.setInt(5, 0);
        } else if (object.isLiteral()) {
            ps.setString(3, object.getLiteralLexicalForm());
            String s_lang = object.getLiteralLanguage();
            String s_type = object.getLiteralDatatypeURI();
            if (s_type != null && s_type.length() > 0) {
                ps.setString(4, s_type);
                ps.setInt(5, 3);
            } else if (s_lang != null && s_lang.length() > 0) {
                ps.setString(4, s_lang);
                ps.setInt(5, 2);
            } else {
                ps.setNull(4, java.sql.Types.VARCHAR);
                ps.setInt(5, 1);
            }
        } else {
            ps.setString(3, object.toString());
            ps.setNull(4, java.sql.Types.VARCHAR);
            ps.setInt(5, 0);
        }

        ps.setString(6, _graphName);
    }


    void delete_match(TripleMatch tm) {
        delete_match(null, tm);
    }


    void delete_match(String _gName, TripleMatch tm) {
        Node nS, nP, nO;

        checkOpen();

        nS = tm.getMatchSubject();
        nP = tm.getMatchPredicate();
        nO = tm.getMatchObject();

        if (nP != null && nP.isBlank())
            throw new DeleteDeniedException("BNode could not be used as Predicate");

        try {
            if (nS == null && nP == null && nO == null) {

                String gr = (_gName != null ? _gName : this.graphName);
                clear(NodeFactory.createURI(gr));

            } else if (nS != null && nP != null && nO != null) {
                java.sql.PreparedStatement ps;

                ps = prepareStatement(sdelete);
                ps.setString(1, (_gName != null ? _gName : this.graphName));
                bindSubject(ps, 2, nS);
                bindPredicate(ps, 3, nP);
                bindObject(ps, 4, nO);

                ps.execute();
                ps.close();

            } else {

                java.sql.PreparedStatement ps;

                StringBuilder stm = new StringBuilder();

                stm.append(' ');
                if (nS != null)
                    stm.append("`iri(??)`");
                else
                    stm.append("?s");

                stm.append(' ');
                if (nP != null)
                    stm.append("`iri(??)`");
                else
                    stm.append("?p");

                stm.append(' ');
                if (nO != null)
                    stm.append("`bif:__rdf_long_from_batch_params(??,??,??)`");
                else
                    stm.append("?o");

                StringBuilder sb = new StringBuilder("sparql ");

                appendSparqlPrefixes(sb);
                sb.append("delete from <");
                sb.append((_gName != null ? _gName : this.graphName));
                sb.append("> { ");

                sb.append(stm.toString());
                sb.append(" } where { ");
                sb.append(stm.toString());

                sb.append(" }");

                ps = prepareStatement(sb.toString());
                int col = 1;

                if (nS != null)
                    bindSubject(ps, col++, nS);
                if (nP != null)
                    bindPredicate(ps, col++, nP);
                if (nO != null) {
                    bindObject(ps, col, nO);
                    col += 3;
                }


                if (nS != null)
                    bindSubject(ps, col++, nS);
                if (nP != null)
                    bindPredicate(ps, col++, nP);
                if (nO != null)
                    bindObject(ps, col, nO);

                ps.execute();
                ps.close();
            }
        } catch (Exception e) {
            throw new DeleteDeniedException(e.toString());
        }
    }


    public ExtendedIterator reifierTriples(TripleMatch m) {
        return NiceIterator.emptyIterator();
    }

    public int reifierSize() {
        return 0;
    }


    @Override
    public VirtTransactionHandler getTransactionHandler() {
        if (tranHandler == null)
            tranHandler = new VirtTransactionHandler(this);
        return tranHandler;
    }

    @Override
    public BulkUpdateHandler getBulkUpdateHandler() {
        if (bulkHandler == null)
            bulkHandler = new VirtBulkUpdateHandler(this);
        return bulkHandler;
    }

    protected VirtPrefixMapping m_prefixMapping = null;

    public PrefixMapping getPrefixMapping() {
        if (m_prefixMapping == null)
            m_prefixMapping = new VirtPrefixMapping(this);
        return m_prefixMapping;
    }


    public static Node Object2Node(Object o) {
        if (o == null)
            return null;

        if (o instanceof ExtendedString) {
            ExtendedString vs = (ExtendedString) o;

            if (vs.getIriType() == ExtendedString.IRI && (vs.getStrType() & 0x01) == 0x01) {
                if (vs.toString().indexOf("_:") == 0)
                    return NodeFactory.createAnon(AnonId.create(vs.toString().substring(2))); // _:
                else
                    return NodeFactory.createURI(vs.toString());

            } else if (vs.getIriType() == ExtendedString.BNODE) {
//          return NodeFactory.createAnon(AnonId.create(vs.toString().substring(9))); // nodeID://b1234
                return NodeFactory.createAnon(AnonId.create(vs.toString())); // nodeID://

            } else {
                return NodeFactory.createLiteral(vs.toString());
            }

        } else if (o instanceof RdfBox) {

            RdfBox rb = (RdfBox) o;
            String rb_type = rb.getType();
            RDFDatatype dt = null;
            String rb_val = rb.toString();


            if (rb_type != null) {
                dt = TypeMapper.getInstance().getSafeTypeByName(rb_type);
            
                if (rb_val.length()==1 && (rb_val.charAt(0)=='1' || rb_val.charAt(0)=='0')) {
                  if (rb_type.equals("http://www.w3.org/2001/XMLSchema#boolean")) 
                    return NodeFactory.createLiteral(rb_val.charAt(0)=='1'?"true":"false", rb.getLang(), dt);
                }
            }

            return NodeFactory.createLiteral(rb_val, rb.getLang(), dt);

        } else if (o instanceof java.lang.Long) {

            RDFDatatype dt = null;
            dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#long");
            return NodeFactory.createLiteral(o.toString(), null, dt);

        } else if (o instanceof java.lang.Integer) {

            RDFDatatype dt = null;
            dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#integer");
            return NodeFactory.createLiteral(o.toString(), null, dt);

        } else if (o instanceof java.lang.Short) {

            RDFDatatype dt = null;
//      dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#short");
            dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#integer");
            return NodeFactory.createLiteral(o.toString(), null, dt);

        } else if (o instanceof java.lang.Float) {

            RDFDatatype dt = null;
            dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#float");
            return NodeFactory.createLiteral(o.toString(), null, dt);

        } else if (o instanceof java.lang.Double) {

            RDFDatatype dt = null;
            dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#double");
            return NodeFactory.createLiteral(o.toString(), null, dt);

        } else if (o instanceof java.math.BigDecimal) {

            RDFDatatype dt = null;
            dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#decimal");
            return NodeFactory.createLiteral(o.toString(), null, dt);

        } else if (o instanceof java.sql.Blob) {

            RDFDatatype dt = null;
            dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#hexBinary");
            return NodeFactory.createLiteral(o.toString(), null, dt);

        } else if (o instanceof VirtuosoDate) {

            RDFDatatype dt = null;
            dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#date");
            return NodeFactory.createLiteral(((VirtuosoDate) o).toXSD_String(), null, dt);

        } else if (o instanceof VirtuosoTimestamp) {

            RDFDatatype dt = null;
            dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#dateTime");
            return NodeFactory.createLiteral(((VirtuosoTimestamp) o).toXSD_String(), null, dt);

        } else if (o instanceof VirtuosoTime) {

            RDFDatatype dt = null;
            dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#time");
            return NodeFactory.createLiteral(((VirtuosoTime) o).toXSD_String(), null, dt);

        } else if (o instanceof java.sql.Date) {

            RDFDatatype dt = null;
            dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#date");
            return NodeFactory.createLiteral(o.toString(), null, dt);

        } else if (o instanceof java.sql.Timestamp) {

            RDFDatatype dt = null;
            dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#dateTime");
            return NodeFactory.createLiteral(Timestamp2String((java.sql.Timestamp) o), null, dt);

        } else if (o instanceof java.sql.Time) {

            RDFDatatype dt = null;
            dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#time");
            return NodeFactory.createLiteral(o.toString(), null, dt);

        } else {

            return NodeFactory.createLiteral(o.toString());
        }
    }


    private static String Timestamp2String(java.sql.Timestamp v) {
        GregorianCalendar cal = new GregorianCalendar();
        int timezone = cal.get(Calendar.ZONE_OFFSET) / 60000; //min

        StringBuilder sb = new StringBuilder();
        DateFormat formatter = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss");
        String nanosString;
        String timeZoneString = null;
        String zeros = "000000000";
        int nanos = v.getNanos();

        sb.append(formatter.format(v));

        if (nanos == 0) {
//            nanosString = "000";
            nanosString = "";
        } else {
            nanosString = Integer.toString(nanos);

            // Add leading zeros
            nanosString = zeros.substring(0, (9 - nanosString.length())) +
                    nanosString;

            // Truncate trailing zeros
            char[] nanosChar = new char[nanosString.length()];
            nanosString.getChars(0, nanosString.length(), nanosChar, 0);
            int truncIndex = 8;
            while (nanosChar[truncIndex] == '0') {
                truncIndex--;
            }

            nanosString = new String(nanosChar, 0, truncIndex + 1);
        }

        if (nanosString.length()>0) {
          sb.append(".");
          sb.append(nanosString);
        }

        sb.append(timezone > 0 ? '+' : '-');

        int tz = Math.abs(timezone);
        int tzh = tz / 60;
        int tzm = tz % 60;

        if (tzh < 10)
            sb.append('0');

        sb.append(tzh);
        sb.append(':');

        if (tzm < 10)
            sb.append('0');

        sb.append(tzm);
        return sb.toString();
    }


}

