/*
 *  $Id: VirtGraph.java,v 1.15.2.18 2012/03/15 12:56:34 source Exp $
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

package virtuoso.jena.driver;

import java.sql.*;
import java.util.*;
import javax.sql.*;

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


public class VirtGraph extends GraphBase
{
    static {
        VirtuosoQueryEngine.register();
    }

    static public final String DEFAULT = "virt:DEFAULT";
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
    static final String S_TTLP_INSERT = "DB.DBA.TTLP(?,'',?,255)";
    static final String sinsert = "sparql insert into graph iri(??) { `iri(??)` `iri(??)` `bif:__rdf_long_from_batch_params(??,??,??)` }";
    static final String sdelete = "sparql delete from graph iri(??) {`iri(??)` `iri(??)` `bif:__rdf_long_from_batch_params(??,??,??)`}";
    static final int BATCH_SIZE = 5000;
    static final String utf8 = "charset=utf-8";
    static final String charset = "UTF-8";

    private VirtuosoConnectionPoolDataSource pds = new VirtuosoConnectionPoolDataSource();
    private DataSource ds;


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
	    this.graphName = _graphName;
	    this.user = vds.getUser();
	    this.password = vds.getPassword();
	}

	if (this.graphName == null)
	    this.graphName = DEFAULT;

	try {
	    connection = _ds.getConnection();
	    ds = _ds;
	    ModelCom m = new ModelCom(this); //don't drop is it needed for initialize internal Jena classes
	    TypeMapper tm = TypeMapper.getInstance();
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
	    this.graphName = _graphName;
	    this.user = vds.getUser();
	    this.password = vds.getPassword();
	}

	if (this.graphName == null)
	    this.graphName = DEFAULT;

	try {
	    connection = _ds.getPooledConnection().getConnection();
	    ModelCom m = new ModelCom(this); //don't drop is it needed for initialize internal Jena classes
	    TypeMapper tm = TypeMapper.getInstance();
	} catch(Exception e) {
	    throw new JenaException(e);
	}
    }


    public VirtGraph(ConnectionPoolDataSource _ds) 
    {		
	this(null, _ds);
    }


    public VirtGraph(String graphName, String _url_hostlist, String user, 
    		String password, boolean _roundrobin)
    {
	super();

	this.url_hostlist = _url_hostlist.trim();
	this.roundrobin = _roundrobin;
	this.graphName = graphName;
	this.user = user;
	this.password = password;

	if(this.graphName == null)
	    this.graphName = DEFAULT;

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
	} catch(Exception e) {
	    throw new JenaException(e);
	}

    }

// getters
    public DataSource getDataSource() {
        return ds;
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



// GraphBase overrides
    public static String Node2Str(Node n)
    {
      if (n.isURI()) {
        return "<"+n+">";
      } else if (n.isBlank()) {
        return "<_:"+n+">"; 
      } else if (n.isLiteral()) {
        String s;
        StringBuffer sb = new StringBuffer();
        sb.append("\"");
        sb.append(escapeString(n.getLiteralValue().toString()));
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
        ps.setString(col, "_:"+n.toString());
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
      } else if (n .isBlank()) {
	ps.setInt(col, 1);
	ps.setString(col+1, "_:"+n.toString());
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
//--java5 or newer    @Override
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
//--java5 or newer    @Override
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


//--java5 or newer    @Override
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
        java.sql.PreparedStatement stmt;
        stmt = prepareStatement(sb.toString());
	return new VirtResSetIter(this, stmt.executeQuery(), tm);
      } catch (Exception e) {
        throw new JenaException(e);
      }
    }


//--java5 or newer    @Override
    public void close() 
    {
      try {
        super.close(); // will set closed = true
        connection.close();
      } catch (Exception e) {
        throw new JenaException(e);
      }
    }
    
    
// Extra functions

    public void clear()
    {
      clearGraph(this.graphName);
      getEventManager().notifyEvent( this, GraphEvents.removeAll );
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
      try {
        PreparedStatement ps = prepareStatement(S_TTLP_INSERT);
        StringBuilder sb = new StringBuilder(256);
        int count = 0;
	    
        while (it.hasNext())
        {
          Triple t = (Triple) it.next();

          if (list != null)
            list.add(t);

          sb.append(Node2Str(t.getSubject()));
          sb.append(' ');
          sb.append(Node2Str(t.getPredicate()));
          sb.append(' ');
          sb.append(Node2Str(t.getObject()));
          sb.append(" .\n");
          count++;

          if (count > BATCH_SIZE) {
	    ps.setString(1, sb.toString());
            ps.setString(2, (_gName!=null? _gName: this.graphName));
	    ps.executeUpdate();
	    sb.setLength(0);
            count = 0;
          }
        }

        if (count > 0) 
        {
          ps.setString(1, sb.toString());
          ps.setString(2, (_gName!=null? _gName: this.graphName));
          ps.executeUpdate();
        }
        ps.close();

      }	catch(Exception e) {
        throw new JenaException(e);
      }
    }



    void delete(Iterator<Triple> it, List<Triple> list)
    {
      try {
        while (it.hasNext())
        {
          Triple triple = (Triple) it.next();

          if (list != null)
            list.add(triple);

          performDelete (triple);
        }
      }	catch(Exception e) {
        throw new JenaException(e);
      }
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

          clearGraph((_gName!=null? _gName:this.graphName));

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


    void clearGraph(String name)
    {
      String query = "sparql clear graph iri(??)";

      checkOpen();

      try {
        java.sql.PreparedStatement ps = prepareStatement(query);
        ps.setString(1, name);
        ps.execute();
        ps.close();
      }	catch(Exception e) {
        throw new JenaException(e);
      }
    }


    public ExtendedIterator reifierTriples( TripleMatch m )
    { return NiceIterator.emptyIterator(); }

    public int reifierSize()
    { return 0; }

    
    
//--java5 or newer    @Override
    public TransactionHandler getTransactionHandler()
    {
      return new VirtTransactionHandler(this);
    }

//--java5 or newer    @Override
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
            return Node.createAnon(AnonId.create(vs.toString().substring(2))); // _:
          else
            return Node.createURI(vs.toString());

        } else if (vs.getIriType() == ExtendedString.BNODE) {
          return Node.createAnon(AnonId.create(vs.toString().substring(9))); // nodeID://

        } else {
          return Node.createLiteral(vs.toString()); 
        }

      } else if (o instanceof RdfBox) {

        RdfBox rb = (RdfBox)o;
        String rb_type = rb.getType();
        RDFDatatype dt = null;

        if ( rb_type != null)
          dt = TypeMapper.getInstance().getSafeTypeByName(rb_type);
        return Node.createLiteral(rb.toString(), rb.getLang(), dt);

      } else if (o instanceof java.lang.Integer) {

        RDFDatatype dt = null;
        dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#integer");
        return Node.createLiteral(o.toString(), null, dt);

      } else if (o instanceof java.lang.Short) {

        RDFDatatype dt = null;
//      dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#short");
        dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#integer");
        return Node.createLiteral(o.toString(), null, dt);

      } else if (o instanceof java.lang.Float) {

        RDFDatatype dt = null;
        dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#float");
        return Node.createLiteral(o.toString(), null, dt);

      } else if (o instanceof java.lang.Double) {

        RDFDatatype dt = null;
        dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#double");
        return Node.createLiteral(o.toString(), null, dt);

      } else if (o instanceof java.math.BigDecimal) {

        RDFDatatype dt = null;
        dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#decimal");
        return Node.createLiteral(o.toString(), null, dt);

      } else if (o instanceof java.sql.Blob) {

        RDFDatatype dt = null;
        dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#hexBinary");
        return Node.createLiteral(o.toString(), null, dt);

      } else if (o instanceof java.sql.Date) {

        RDFDatatype dt = null;
        dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#date");
        return Node.createLiteral(o.toString(), null, dt);

      } else if (o instanceof java.sql.Timestamp) {

        RDFDatatype dt = null;
        dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#dateTime");
        return Node.createLiteral(Timestamp2String((java.sql.Timestamp)o), null, dt);

      } else if (o instanceof java.sql.Time) {

        RDFDatatype dt = null;
        dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#time");
        return Node.createLiteral(o.toString(), null, dt);

      } else {

        return Node.createLiteral(o.toString());
      }
    }

    private static String Timestamp2String(java.sql.Timestamp v)
    {
      GregorianCalendar cal = new GregorianCalendar();
      cal.setTime(v);

      int year = cal.get(Calendar.YEAR);
      int month = cal.get(Calendar.MONTH) + 1;
      int day = cal.get(Calendar.DAY_OF_MONTH);
      int hour = cal.get(Calendar.HOUR_OF_DAY);
      int minute = cal.get(Calendar.MINUTE);
      int second = cal.get(Calendar.SECOND);
      int nanos = v.getNanos();

      String yearS;
      String monthS;
      String dayS;
      String hourS;
      String minuteS;
      String secondS;
      String nanosS;
      String zeros = "000000000";
      String yearZeros = "0000";
      StringBuffer timestampBuf;

      if (year < 1000) {
          yearS = "" + year;
          yearS = yearZeros.substring(0, (4-yearS.length())) + yearS;
      } else {
          yearS = "" + year;
      }

      if (month < 10)
          monthS = "0" + month;
      else
          monthS = Integer.toString(month);

      if (day < 10)
          dayS = "0" + day;
      else
          dayS = Integer.toString(day);

      if (hour < 10)
          hourS = "0" + hour;
      else
          hourS = Integer.toString(hour);

      if (minute < 10)
          minuteS = "0" + minute;
      else
          minuteS = Integer.toString(minute);
      
      if (second < 10)
          secondS = "0" + second;
      else
          secondS = Integer.toString(second);
      
      if (nanos == 0) {
          nanosS = "0";
      } else {
          nanosS = Integer.toString(nanos);

          // Add leading 0
          nanosS = zeros.substring(0, (9-nanosS.length())) + nanosS; 

          // Truncate trailing 0
          char[] nanosChar = new char[nanosS.length()];
          nanosS.getChars(0, nanosS.length(), nanosChar, 0);
          int truncIndex = 8;
          while (nanosChar[truncIndex] == '0') {
      	    truncIndex--;
          }
          nanosS = new String(nanosChar, 0, truncIndex + 1);
      }

      timestampBuf = new StringBuffer();
      timestampBuf.append(yearS);
      timestampBuf.append("-");
      timestampBuf.append(monthS);
      timestampBuf.append("-");
      timestampBuf.append(dayS);
      timestampBuf.append("T");
      timestampBuf.append(hourS);
      timestampBuf.append(":");
      timestampBuf.append(minuteS);
      timestampBuf.append(":");
      timestampBuf.append(secondS);
      timestampBuf.append(".");
      timestampBuf.append(nanosS);

      return (timestampBuf.toString());
    }

}

