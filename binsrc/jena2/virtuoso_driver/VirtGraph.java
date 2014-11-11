/*
 *  $Id: VirtGraph.java,v 1.15.2.18 2012/03/15 12:56:34 source Exp $
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

package virtuoso.jena.driver;

import java.sql.*;
import java.util.*;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import javax.sql.*;
import javax.transaction.xa.*;

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


public class VirtGraph extends GraphBase
{
    static {
        VirtuosoQueryEngine.register();
    }

    static public final String DEFAULT = "virt:DEFAULT";
    protected boolean isXA = false;
    protected String graphName;
    protected boolean readFromAllGraphs = false;
    protected String url_hostlist;
    protected String user;
    protected String password;
    protected boolean roundrobin = false;
    protected int prefetchSize = 200;
    protected Connection connection = null;
    protected String ruleSet = null;
    protected boolean useSameAs = false;
    protected int queryTimeout = 0;
    protected boolean useReprepare = true;
//    static final String S_TTLP_INSERT = "DB.DBA.TTLP_MT (?, '', ?, 255, 2, 3, ?)";
    static final String S_BATCH_INSERT = "DB.DBA.rdf_insert_triple_c (?,?,?,?,?,?)";
    static final String S_BATCH_DELETE = "DB.DBA.rdf_delete_triple_c (?,?,?,?,?,?)";
    static final String S_CLEAR_GRAPH = "DB.DBA.rdf_clear_graphs_c (?)";

    static final String sinsert = "sparql insert into graph iri(??) { `iri(??)` `iri(??)` `bif:__rdf_long_from_batch_params(??,??,??)` }";
    static final String sdelete = "sparql delete from graph iri(??) {`iri(??)` `iri(??)` `bif:__rdf_long_from_batch_params(??,??,??)`}";
    static final int BATCH_SIZE = 5000;
    static final int MAX_CMD_SIZE = 36000;
    static final String utf8 = "charset=utf-8";
    static final String charset = "UTF-8";

    private VirtuosoConnectionPoolDataSource pds = new VirtuosoConnectionPoolDataSource();
    private DataSource ds;
    private XADataSource xa_ds;
    private javax.transaction.xa.XAResource xa_resource = null;
    private XAConnection xa_connection = null;
    protected VirtTransactionHandler tranHandler = null;


    public VirtGraph()
    {
	this(null, "jdbc:virtuoso://localhost:1111/charset=UTF-8", null, null, false);
    }

    public VirtGraph(String graphName)
    {
	this(graphName, "jdbc:virtuoso://localhost:1111/charset=UTF-8", null, null, false);
    }

    public VirtGraph(String graphName, String _url_hostlist, String user, 
    		String password)
    {
	this(graphName, _url_hostlist, user, password, false);
    }

    public VirtGraph(String url_hostlist, String user, String password)
    {
	this(null, url_hostlist, user, password, false);
    }


    public VirtGraph(String _graphName, DataSource _ds) 
    {
	super();

	if (_ds instanceof VirtuosoDataSource) {
	    VirtuosoDataSource vds = (VirtuosoDataSource)_ds;
	    this.url_hostlist = vds.getServerName();
	    this.user = vds.getUser();
	    this.password = vds.getPassword();
	}

	this.graphName = _graphName==null?DEFAULT: _graphName;

	try {
	    connection = _ds.getConnection();
	    ds = _ds;
	    ModelCom m = new ModelCom(this); //don't drop is it needed for initialize internal Jena classes
	    TypeMapper tm = TypeMapper.getInstance();

            virtuoso.jdbc4.Driver drv = new virtuoso.jdbc4.Driver();
            if (drv.getMajorVersion()>=3 && drv.getMinorVersion()>=72)
                useReprepare = false;
	} catch(Exception e) {
	    throw new JenaException(e);
	}
    }

    public VirtGraph(DataSource _ds) 
    {		
	this(null, _ds);
    }


    public VirtGraph(String _graphName, ConnectionPoolDataSource _ds) 
    {
	super();

	if (_ds instanceof VirtuosoConnectionPoolDataSource) {
	    VirtuosoDataSource vds = (VirtuosoDataSource)_ds;
	    this.url_hostlist = vds.getServerName();
	    this.user = vds.getUser();
	    this.password = vds.getPassword();
	}

	this.graphName = _graphName==null?DEFAULT: _graphName;

	try {
	    connection = _ds.getPooledConnection().getConnection();
	    ModelCom m = new ModelCom(this); //don't drop is it needed for initialize internal Jena classes
	    TypeMapper tm = TypeMapper.getInstance();

            virtuoso.jdbc4.Driver drv = new virtuoso.jdbc4.Driver();
            if (drv.getMajorVersion()>=3 && drv.getMinorVersion()>=72)
                useReprepare = false;
	} catch(Exception e) {
	    throw new JenaException(e);
	}
    }


    public VirtGraph(ConnectionPoolDataSource _ds) 
    {		
	this(null, _ds);
    }


    public VirtGraph(String _graphName, XADataSource _ds) 
    {
	super();

	if (_ds instanceof VirtuosoXADataSource) {
	    VirtuosoXADataSource vds = (VirtuosoXADataSource)_ds;
	    this.url_hostlist = vds.getServerName();
	    this.user = vds.getUser();
	    this.password = vds.getPassword();
	}

	this.graphName = _graphName==null?DEFAULT: _graphName;

	try {
	    xa_connection = _ds.getXAConnection();
	    connection = xa_connection.getConnection();
	    isXA = true;
	    ModelCom m = new ModelCom(this); //don't drop is it needed for initialize internal Jena classes
	    TypeMapper tm = TypeMapper.getInstance();

            virtuoso.jdbc4.Driver drv = new virtuoso.jdbc4.Driver();
            if (drv.getMajorVersion()>=3 && drv.getMinorVersion()>=72)
                useReprepare = false;
	} catch(Exception e) {
	    throw new JenaException(e);
	}
    }


    public VirtGraph(XADataSource _ds) 
    {		
	this(null, _ds);
    }



    
    public VirtGraph(String _graphName, String _url_hostlist, String user, 
    		String password, boolean _roundrobin)
    {
	super();

	this.url_hostlist = _url_hostlist.trim();
	this.roundrobin = _roundrobin;
	this.user = user;
	this.password = password;

	this.graphName = _graphName==null?DEFAULT: _graphName;

	try {
	    if (url_hostlist.startsWith("jdbc:virtuoso://")) {

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
                ds = (javax.sql.DataSource)pds;
	    }

	    ModelCom m = new ModelCom(this); //don't drop is it needed for initialize internal Jena classes
	    TypeMapper tm = TypeMapper.getInstance();

            virtuoso.jdbc4.Driver drv = new virtuoso.jdbc4.Driver();
            if (drv.getMajorVersion()>=3 && drv.getMinorVersion()>=72)
                useReprepare = false;
	} catch(Exception e) {
	    throw new JenaException(e);
	}

    }

// getters
    public DataSource getDataSource() {
        return ds;
    }

    public XAResource getXAResource() {
    	try{
            if (xa_resource==null)
        	xa_resource = (xa_connection!=null)?xa_connection.getXAResource():null;
            return xa_resource;
        } catch(SQLException e) {
            throw new JenaException(e);
        }
    }

    public String getGraphName()
    {
	return this.graphName;
    }

    protected void setGraphName(String name)
    {
	this.graphName = name;
    }

    public String getGraphUrl()
    {
	return this.url_hostlist;
    }

    public String getGraphUser()
    {
	return this.user;
    }

    public String getGraphPassword()
    {
	return this.password;
    }

    public Connection getConnection()
    {
    	return this.connection;
    }


    public int getFetchSize()
    {
    	return this.prefetchSize;
    }


    public void setFetchSize(int sz)
    {
    	this.prefetchSize = sz;
    }


    public int getQueryTimeout()
    {
    	return this.queryTimeout;
    }


    public void setQueryTimeout(int seconds)
    {
    	this.queryTimeout = seconds;
    }


    public int getCount()
    {
        return size();
    }


    public void remove(List triples)
    {
        delete(triples.iterator(), null);
    }

    public void remove(Triple t)
    {
        delete(t);
    }


    public boolean getReadFromAllGraphs() 
    {
      return readFromAllGraphs;
    }

    public void setReadFromAllGraphs(boolean val) 
    {
      readFromAllGraphs = val;
    }


    public String getRuleSet()
    {
	return ruleSet;
    }

    public void setRuleSet(String _ruleSet)
    {
	ruleSet = _ruleSet;
    }

    public boolean getSameAs()
    {
	return useSameAs;
    }

    public void setSameAs(boolean _sameAs)
    {
	useSameAs = _sameAs;
    }



    public void createRuleSet(String ruleSetName, String uriGraphRuleSet) 
    {
      checkOpen();

      try {
	java.sql.Statement st = createStatement();
	st.execute("rdfs_rule_set('"+ruleSetName+"', '"+uriGraphRuleSet+"')");
	st.close();
      } catch (Exception e) {
        throw new JenaException(e);
      }
    }


    public void removeRuleSet(String ruleSetName, String uriGraphRuleSet) 
    {
      checkOpen();

      try {
	java.sql.Statement st = createStatement();
	st.execute("rdfs_rule_set('"+ruleSetName+"', '"+uriGraphRuleSet+"', 1)");
	st.close();
      } catch (Exception e) {
        throw new JenaException(e);
      }
    }



    private static String escapeString(String s) 
    {
      StringBuilder sb = new StringBuilder(s.length());
      int slen = s.length();

      for (int i = 0; i < slen; i++) {
	char c = s.charAt(i);
	int cInt = c;

	if (c == '\\') {
	  sb.append("\\\\");
	}
	else if (c == '"') {
	  sb.append("\\\"");
	}
	else if (c == '\n') {
	  sb.append("\\n");
	}
	else if (c == '\r') {
	  sb.append("\\r");
	}
	else if (c == '\t') {
	  sb.append("\\t");
	}
	else if (
	        cInt >= 0x0 && cInt <= 0x8 ||
		cInt == 0xB || cInt == 0xC ||
		cInt >= 0xE && cInt <= 0x1F ||
		cInt >= 0x7F && cInt <= 0xFFFF)
	{
	  sb.append("\\u");
	  sb.append(toHexString(cInt, 4));
	}
	else if (cInt >= 0x10000 && cInt <= 0x10FFFF) {
	  sb.append("\\U");
	  sb.append(toHexString(cInt, 8));
	}
	else {
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


    protected java.sql.Statement createStatement() throws java.sql.SQLException
    {
      checkOpen();
      java.sql.Statement st = connection.createStatement();
      if (queryTimeout > 0)
        st.setQueryTimeout(queryTimeout);
      st.setFetchSize(prefetchSize);
      return st;
    }

    protected java.sql.PreparedStatement prepareStatement(String sql) throws java.sql.SQLException
    {
      checkOpen();
      java.sql.PreparedStatement st = connection.prepareStatement(sql);
      if (queryTimeout > 0)
        st.setQueryTimeout(queryTimeout);
      st.setFetchSize(prefetchSize);
      return st;
    }




    static String Blank2String(Node n) 
    {
      return "_:"+ n.toString().replace(':','_').replace('-','z');
    }


// GraphBase overrides
    public static String Node2Str(Node n)
    {
      if (n.isURI()) {
        return "<"+n+">";
      } else if (n.isBlank()) {
        return Blank2String(n); 
      } else if (n.isLiteral()) {
        String s;
        StringBuffer sb = new StringBuffer();
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
        return "<"+n+">";
      }
    }

    void bindSubject(PreparedStatement ps, int col, Node n) throws SQLException 
    {
      if (n == null)
	return;
      if (n.isURI()) 
	ps.setString(col, n.toString());
      else if (n.isBlank()) 
        ps.setString(col, Blank2String(n));
      else 
        throw new SQLException("Only URI or Blank nodes can be used as subject");
    }

	
    void bindPredicate(PreparedStatement ps, int col, Node n) throws SQLException 
    {
      if (n == null)
        return;
      if (n.isURI()) 
        ps.setString(col, n.toString());
      else
        throw new SQLException("Only URI nodes can be used as predicate");
    }

    void bindObject(PreparedStatement ps, int col, Node n) throws SQLException 
    {
      if (n == null)
        return;
      if (n.isURI()) {
	ps.setInt(col, 1);
        ps.setString(col+1, n.toString());
	ps.setNull(col+2, java.sql.Types.VARCHAR);
      } else if (n.isBlank()) {
	ps.setInt(col, 1);
	ps.setString(col+1, Blank2String(n));
	ps.setNull(col+2, java.sql.Types.VARCHAR);
      }	else if (n.isLiteral()) {
        String llang = n.getLiteralLanguage();
        String ltype = n.getLiteralDatatypeURI();
	if (llang != null && llang.length() > 0) {
          ps.setInt(col, 5);
          ps.setString(col+1, n.getLiteralValue().toString());
          ps.setString(col+2, n.getLiteralLanguage());
        } else if (ltype != null && ltype.length() > 0) {
          ps.setInt(col, 4);
          ps.setString(col+1, n.getLiteralValue().toString());
          ps.setString(col+2, n.getLiteralDatatypeURI());
        } else {
          ps.setInt(col, 3);
          ps.setString(col+1, n.getLiteralValue().toString());
          ps.setNull(col+2, java.sql.Types.VARCHAR);
        }	
      }	else {
	ps.setInt(col, 3);
        ps.setString(col+1, n.toString());
	ps.setNull(col+2, java.sql.Types.VARCHAR);
      }
    }

    
//--java5 or newer    @Override
    public void performAdd(Triple t)
    {
      performAdd(null, t.getSubject(), t.getPredicate(), t.getObject());
    }


    protected void performAdd(String _gName, Triple t)
    {
      performAdd(_gName, t.getSubject(), t.getPredicate(), t.getObject());
    }


    protected void performAdd(String _gName, Node s, Node p, Node o)
    {
      java.sql.PreparedStatement ps;

      try {
        ps = prepareStatement(sinsert);
        ps.setString(1, (_gName!=null? _gName: this.graphName));
        bindSubject(ps, 2, s);
        bindPredicate(ps, 3, p);
        bindObject(ps, 4, o);

	ps.execute();
	ps.close();
      } catch(Exception e) {
        throw new AddDeniedException(e.toString());
      }
    }


    public void performDelete (Triple t)
    {
      performDelete(null, t.getSubject(), t.getPredicate(), t.getObject());
    }


    protected void performDelete (String _gName, Node s, Node p, Node o)
    {
      java.sql.PreparedStatement ps;

      try {
        ps = prepareStatement(sdelete);
        ps.setString(1, (_gName!=null? _gName: this.graphName));
        bindSubject(ps, 2, s);
        bindPredicate(ps, 3, p);
        bindObject(ps, 4, o);

	ps.execute();
	ps.close();
      } catch(Exception e) {
        throw new DeleteDeniedException(e.toString());
      }
    }


    /**
     * more efficient
     */
    @Override
    protected int graphBaseSize() 
    {
      StringBuffer sb = new StringBuffer("select count(*) from (sparql define input:storage \"\" ");
        
      if (ruleSet!=null)
        sb.append(" define input:inference '"+ruleSet+"'\n ");
        
      if (useSameAs)
        sb.append(" define input:same-as \"yes\"\n ");

      if ( readFromAllGraphs )
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


    /** maybe more efficient than default impl
     * 
     */
    @Override
    protected boolean graphBaseContains(Triple t) 
    {
      return graphBaseContains(null, t);
    }


    protected boolean graphBaseContains(String _gName, Triple t) 
    {
      ResultSet rs = null;
      String S, P, O;
      StringBuffer sb = new StringBuffer("sparql define input:storage \"\" "); 
      String exec_text;

      checkOpen();

      S = " ?s ";
      P = " ?p ";
      O = " ?o ";

      if (!Node.ANY.equals(t.getSubject()))
        S = Node2Str(t.getSubject());

      if (!Node.ANY.equals(t.getPredicate()))
        P = Node2Str(t.getPredicate());

      if (!Node.ANY.equals(t.getObject()))
        O = Node2Str(t.getObject());
      
      if (ruleSet!=null)
        sb.append(" define input:inference '"+ruleSet+"'\n ");

      if (useSameAs)
        sb.append(" define input:same-as \"yes\"\n ");

      if ( readFromAllGraphs && _gName != null)
 	sb.append(" select * where { " + S +" "+ P +" "+ O +" } limit 1");
      else
        sb.append(" select * where { graph <"+ (_gName!=null?_gName:graphName) +"> { " + S +" "+ P +" "+ O +" }} limit 1");

      try {
	java.sql.Statement stmt = createStatement();
	rs = stmt.executeQuery(sb.toString());
	boolean ret = rs.next();
	rs.close();
	stmt.close();
	return ret;
      } catch (Exception e) {
        throw new JenaException(e);
      }
    }


    @Override
    public ExtendedIterator<Triple> graphBaseFind(TripleMatch tm) 
    {
      return graphBaseFind(null, tm);
    }


    protected ExtendedIterator<Triple> graphBaseFind(String _gName, TripleMatch tm) 
    {
      String S, P, O;
      StringBuffer sb = new StringBuffer("sparql "); 

      checkOpen();

      S = " ?s ";
      P = " ?p ";
      O = " ?o ";

      if (tm.getMatchSubject() != null)
        S = Node2Str(tm.getMatchSubject());

      if (tm.getMatchPredicate() != null)
        P = Node2Str(tm.getMatchPredicate());

      if (tm.getMatchObject() != null)
        O = Node2Str(tm.getMatchObject());

      if (ruleSet!=null)
        sb.append(" define input:inference '"+ruleSet+"'\n ");

      if (useSameAs)
        sb.append(" define input:same-as \"yes\"\n ");

      if ( readFromAllGraphs && _gName == null)
        sb.append(" select * where { "+ S +" "+ P +" "+ O + " }");
      else
        sb.append(" select * from <" + (_gName!=null?_gName:graphName) + "> where { " + S +" "+ P +" "+ O + " }");

      try 
      {
        java.sql.Statement stmt = createStatement();
	return new VirtResSetIter(this, stmt, stmt.executeQuery(sb.toString()), tm);
      } catch (Exception e) {
        throw new JenaException(e);
      }
    }


    @Override
    public void close() 
    {
      try {
        super.close(); // will set closed = true
        if (connection!=null)
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

    public void clear()
    {
      clear(NodeFactory.createURI(this.graphName));
      getEventManager().notifyEvent( this, GraphEvents.removeAll );
    }


    public void clear(Node... graphs)
    {
      if (graphs!=null && graphs.length > 0)
        try {
          String [] graphNames = new String[graphs.length];
          for (int i = 0; i < graphs.length; i++) 
            graphNames[i] = graphs[i].toString();

          java.sql.PreparedStatement ps = prepareStatement(S_CLEAR_GRAPH);

          Array gArray = connection.createArrayOf ("VARCHAR", graphNames);
          ps.setArray (1, gArray);
          ps.executeUpdate ();
          ps.close();
          gArray.free();
	}
	catch (Exception e) {
          throw new JenaException(e);
        }
    }



    public void read (String url, String type)
    {
      String exec_text;

      exec_text ="sparql load \"" + url + "\" into graph <" + graphName + ">";

      checkOpen();
      try {
        java.sql.Statement stmt = createStatement();
        stmt.execute(exec_text);
        stmt.close();
      }	catch(Exception e) {
        throw new JenaException(e);
      }
    }


//--java5 or newer    @SuppressWarnings("unchecked")
    void add(String _gName, Iterator<Triple> it, List<Triple> list) 
    {
      PreparedStatement ps = null;
      try {
        ps = prepareStatement(S_BATCH_INSERT);

        int count = 0;
	    
        while (it.hasNext())
        {
          Triple t = (Triple) it.next();

          if (list != null)
            list.add(t);

          bindBatchParams(ps, t.getSubject(), t.getPredicate(),
          		t.getObject(), _gName);
          ps.addBatch();
          count++;

          if (count > BATCH_SIZE) {
	    ps.executeBatch();
	    ps.clearBatch();
            count = 0;
            if (useReprepare) {
               try {
                 ps.close();
                 ps = null;
               } catch(Exception e){}
               ps = prepareStatement(S_BATCH_INSERT);
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
          } catch (SQLException e){}
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

          if (count > BATCH_SIZE) {
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

        while (it.hasNext())
        {
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

          if (count > 0 && data.length()+row.length() > MAX_CMD_SIZE) {
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

        if (count > 0) 
        {
          data.append(" }");
	  stmt.execute(data.toString());
        }

      }	catch(Exception e) {
        throw new JenaException(e);
      } finally {
        try {
          stmt.close();
        } catch (Exception e) {}
      }
    }



    private void bindBatchParams(PreparedStatement ps, 
    				Node subject, 
    				Node predicate, 
    				Node object, 
    				String _graphName) throws SQLException
    {
      ps.setString(1, subject.isBlank()?Blank2String(subject):subject.toString());
      ps.setString(2, predicate.isBlank()?Blank2String(predicate):predicate.toString());

      if (object.isURI()) 
      {
        ps.setString(3, object.toString());
        ps.setNull(4, java.sql.Types.VARCHAR);
        ps.setInt(5, 0);
      }
      else if (object.isBlank()) 
      {
        ps.setString(3, Blank2String(object));
        ps.setNull(4, java.sql.Types.VARCHAR);
        ps.setInt(5, 0);
      }
      else if (object.isLiteral())
      {
        String s;
        ps.setString(3, object.getLiteralLexicalForm());
        String s_lang = object.getLiteralLanguage();
        String s_type = object.getLiteralDatatypeURI();
        if (s_type !=null && s_type.length() > 0) 
        {
          ps.setString(4, s_type);
          ps.setInt(5, 3);
        }
        else if (s_lang != null && s_lang.length() > 0) 
        {
          ps.setString(4, s_lang);
          ps.setInt(5, 2);
        }
        else
        {
          ps.setNull(4,java.sql.Types.VARCHAR);
          ps.setInt(5, 1);
        }
      }
      else
      {
        ps.setString(3, object.toString());
        ps.setNull(4, java.sql.Types.VARCHAR);
        ps.setInt(5, 0);
      }

      ps.setString(6, _graphName);
    }



    void delete_match(TripleMatch tm)
    {
      delete_match(null, tm);
    }

    void delete_match(String _gName, TripleMatch tm)
    {
      String S, P, O;
      Node nS, nP, nO;

      checkOpen();

      S = "?s";
      P = "?p";
      O = "?o";

      nS = tm.getMatchSubject();
      nP = tm.getMatchPredicate();
      nO = tm.getMatchObject();

      try {
        if (nS == null && nP == null && nO == null) {

          String gr = (_gName!=null? _gName:this.graphName);
          clear(NodeFactory.createURI(gr));

        } else if (nS != null && nP != null && nO != null) {
          java.sql.PreparedStatement ps;

          ps = prepareStatement(sdelete);
          ps.setString(1, (_gName!=null? _gName:this.graphName));
          bindSubject(ps, 2, nS);
          bindPredicate(ps, 3, nP);
          bindObject(ps, 4, nO);

          ps.execute();
          ps.close();

        } else  {

          if (nS != null)
            S = Node2Str(nS);

          if (nP != null)
            P = Node2Str(nP);

          if (nO != null)
            O = Node2Str(nO);

          String query = "sparql delete from <"+
             (_gName!=null? _gName:this.graphName)+
             "> { "+S+" "+P+" "+O+" } where { "+S+" "+P+" "+O+" }";

          java.sql.Statement stmt = createStatement();
          stmt.execute(query);
          stmt.close();
        }
      } catch(Exception e) {
        throw new DeleteDeniedException(e.toString());
      }
    }


    public ExtendedIterator reifierTriples( TripleMatch m )
    { return NiceIterator.emptyIterator(); }

    public int reifierSize()
    { return 0; }

    
    
    @Override
    public VirtTransactionHandler getTransactionHandler()
    {
      if (tranHandler == null)
        tranHandler = new VirtTransactionHandler(this);
      return tranHandler;
    }

    @Override
    public BulkUpdateHandler getBulkUpdateHandler()
    {
      if (bulkHandler == null) 
        bulkHandler = new VirtBulkUpdateHandler(this); 
      return bulkHandler;
    }

    protected VirtPrefixMapping m_prefixMapping = null;

    public PrefixMapping getPrefixMapping() 
    { 
      if ( m_prefixMapping == null)
        m_prefixMapping = new VirtPrefixMapping( this );
      return m_prefixMapping; 
    }


    public static Node Object2Node(Object o)
    {
      if (o == null) 
        return null;

      if (o instanceof ExtendedString) 
      {
        ExtendedString vs = (ExtendedString) o;

        if (vs.getIriType() == ExtendedString.IRI && (vs.getStrType() & 0x01)== 0x01) 
        {
          if (vs.toString().indexOf ("_:") == 0)
            return NodeFactory.createAnon(AnonId.create(vs.toString().substring(2))); // _:
          else
            return NodeFactory.createURI(vs.toString());

        } else if (vs.getIriType() == ExtendedString.BNODE) {
          return NodeFactory.createAnon(AnonId.create(vs.toString().substring(9))); // nodeID://

        } else {
          return NodeFactory.createLiteral(vs.toString()); 
        }

      } else if (o instanceof RdfBox) {

        RdfBox rb = (RdfBox)o;
        String rb_type = rb.getType();
        RDFDatatype dt = null;

        if ( rb_type != null)
          dt = TypeMapper.getInstance().getSafeTypeByName(rb_type);
        return NodeFactory.createLiteral(rb.toString(), rb.getLang(), dt);

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

      } else if (o instanceof java.sql.Date) {

        RDFDatatype dt = null;
        dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#date");
        return NodeFactory.createLiteral(o.toString(), null, dt);

      } else if (o instanceof java.sql.Timestamp) {

        RDFDatatype dt = null;
        dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#dateTime");
        return NodeFactory.createLiteral(Timestamp2String((java.sql.Timestamp)o), null, dt);

      } else if (o instanceof java.sql.Time) {

        RDFDatatype dt = null;
        dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#time");
        return NodeFactory.createLiteral(o.toString(), null, dt);

      } else if (o instanceof VirtuosoDate) {

        RDFDatatype dt = null;
        dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#date");
        return NodeFactory.createLiteral(((VirtuosoDate)o).toXSD_String(), null, dt);

      }	else if (o instanceof VirtuosoTimestamp) {

        RDFDatatype dt = null;
        dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#dateTime");
        return NodeFactory.createLiteral(((VirtuosoTimestamp)o).toXSD_String(), null, dt);

      }	else if (o instanceof VirtuosoTime) {

        RDFDatatype dt = null;
        dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#time");
        return NodeFactory.createLiteral(((VirtuosoTime)o).toXSD_String(), null, dt);

      } else {

        return NodeFactory.createLiteral(o.toString());
      }
    }


    private static String Timestamp2String(java.sql.Timestamp v)
    {
        GregorianCalendar cal = new GregorianCalendar();
        int timezone = cal.get(Calendar.ZONE_OFFSET)/60000; //min

        StringBuilder sb = new StringBuilder();
        DateFormat formatter= new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss");
        String nanosString;
        String timeZoneString = null;
        String zeros = "000000000";
        int nanos = v.getNanos();

        sb.append(formatter.format(v));

        if (nanos == 0) {
            nanosString = "000";
        } else {
            nanosString = Integer.toString(nanos);

            // Add leading zeros
            nanosString = zeros.substring(0, (9-nanosString.length())) +
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

        sb.append(".");
        sb.append(nanosString);
        sb.append(timezone>0?'+':'-');

        int tz = Math.abs(timezone);
        int tzh = tz/60;
        int tzm = tz%60;

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

