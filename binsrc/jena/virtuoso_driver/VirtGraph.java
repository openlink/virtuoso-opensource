/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2008 OpenLink Software
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
import java.io.*;
import java.util.*;
import java.util.Iterator;

import virtuoso.jdbc3.*;

import com.hp.hpl.jena.graph.*;
import com.hp.hpl.jena.graph.impl.*;
import com.hp.hpl.jena.graph.impl.LiteralLabel;
import com.hp.hpl.jena.util.iterator.ExtendedIterator;
import com.hp.hpl.jena.util.iterator.NiceIterator;
import com.hp.hpl.jena.db.impl.ResultSetIterator;
import com.hp.hpl.jena.shared.*;
import com.hp.hpl.jena.db.impl.*;
import com.hp.hpl.jena.util.iterator.*;
import com.hp.hpl.jena.graph.query.*;
import com.hp.hpl.jena.datatypes.*;
import com.hp.hpl.jena.rdf.model.*;


public class VirtGraph extends GraphBase
{
    static public final String DEFAULT = "virt:DEFAULT";
    private String graphName;
    private String url;
    private String user;
    private String password;
    private Connection connection = null;
    static final String sinsert = "sparql define output:format '_JAVA_' insert into graph iri(??) { `iri(??)` `iri(??)` `bif:__rdf_long_from_batch_params(??,??,??)` }";
    static final String sdelete = "sparql define output:format '_JAVA_' delete from graph iri(??) {`iri(??)` `iri(??)` `bif:__rdf_long_from_batch_params(??,??,??)`}";
    static final int BATCH_SIZE = 1000;
    static final String utf8 = "charset=UTF-8";


    public VirtGraph()
    {
	this(null, "jdbc:virtuoso://localhost:1111/charset=UTF-8", null, null);
    }

    public VirtGraph(String url, String user, String password)
    {
	this(null, url, user, password);
    }

    public VirtGraph(String graphName)
    {
	this(graphName, "jdbc:virtuoso://localhost:1111/charset=UTF-8", null, null);
    }

    public VirtGraph(String graphName, String _url, String user, String password)
    {
	super();

	this.url = _url.trim();
	if (url.indexOf(utf8) == -1) {
	   if (url.charAt(url.length()-1) != '/') 
	     url = url + "/" + utf8;
	   else
	     url = url + utf8;
	}

	this.graphName = graphName;
	this.user = user;
	this.password = password;

	if(this.graphName == null)
		this.graphName = DEFAULT;

	if (connection == null)
	{
	    try
	    {
		Class.forName("virtuoso.jdbc3.Driver");
		connection = DriverManager.getConnection(url, user, password);
	    }
	    catch(Exception e)
	    {
	        throw new JenaException(e);
	    }
	}
    }

// getters
    public String getGraphName()
    {
	return this.graphName;
    }

    public String getGraphUrl()
    {
	return this.url;
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



// GraphBase overrides
    String Node2Str(Node n)
    {
      if (n.isURI()) {
        return "<"+n+">";
      } else if (n.isBlank()) {
        return "<_:"+n+">"; 
      } else if (n.isLiteral()) {
        String s;
        StringBuilder sb = new StringBuilder();
        sb.append("\"");
        sb.append(n.getLiteralValue());
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
	ps.setString(col, n.toString());
    }

	
    void bindPredicate(PreparedStatement ps, int col, Node n) throws SQLException 
    {
      if (n == null)
        return;
      ps.setString(col, n.toString());
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

    
    
    @Override
    public void performAdd(Triple t)
    {
      java.sql.PreparedStatement ps;

      try
	{
            ps = connection.prepareStatement(sinsert);
            ps.setString(1, this.graphName);
            bindSubject(ps, 2, t.getSubject());
            bindPredicate(ps, 3, t.getPredicate());
            bindObject(ps, 4, t.getObject());

	    ps.execute();
	}
      catch(Exception e)
	{
            throw new AddDeniedException(e.toString());
	}
    }


    public void performDelete (Triple t)
    {
      java.sql.PreparedStatement ps;

      try
	{
            ps = connection.prepareStatement(sdelete);
            ps.setString(1, this.graphName);
            bindSubject(ps, 2, t.getSubject());
            bindPredicate(ps, 3, t.getPredicate());
            bindObject(ps, 4, t.getObject());

	    ps.execute();
	}
      catch(Exception e)
	{
            throw new DeleteDeniedException(e.toString());
	}
    }


    /**
     * more efficient
     */
    @Override
    protected int graphBaseSize() {
	String query = "select count(*) from (sparql select * where { graph `iri(??)` { ?s ?p ?o }})f";
	ResultSet rs = null;
	int ret = 0;

	checkOpen();

	try {
		java.sql.PreparedStatement ps = connection.prepareStatement(query);
		ps.setString(1, graphName);
		rs = ps.executeQuery();
		rs.next();
		ret = rs.getInt(1);
		rs.close();
	} catch (Exception e) {
	        throw new JenaException(e);
	}
	return ret;
    }


    /** maybe more efficient than default impl
     * 
     */
    @Override
    protected boolean graphBaseContains(Triple t) {
	ResultSet rs = null;
	String S, P, O;
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

	exec_text = "select count (*) from (sparql select * where { graph <"+ 
			this.graphName +"> { " + S +" "+ P +" "+ O +" }})f";

	try {
		java.sql.Statement stmt = connection.createStatement();
		rs = stmt.executeQuery(exec_text);
		rs.next();
		return (rs.getInt(1) != 0);
	} catch (Exception e) {
	        throw new JenaException(e);
	}
    }


    @Override
    public ExtendedIterator graphBaseFind(TripleMatch tm) {
	String S, P, O;
	String exec_text;

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

	exec_text = "sparql select * from <" + this.graphName + "> where { " 
			+ S +" "+ P +" "+ O + " }";

	try {
		java.sql.PreparedStatement stmt = connection
				.prepareStatement(exec_text);
		return new VirtResSetIter(this, stmt.executeQuery(), tm);
	} catch (Exception e) {
	        throw new JenaException(e);
	}
    }


    @Override
    public void close() {
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
	try
	{
	    java.sql.Statement stmt = connection.createStatement();
	    stmt.execute(exec_text);
	}
	catch(Exception e)
	{
            throw new JenaException(e);
	}

    }


    @SuppressWarnings("unchecked")
    void add(Iterator it, List list) 
    {
	try
	{
            PreparedStatement ps = connection.prepareStatement(sinsert);
            int count = 0;
	    
	    while (it.hasNext())
	    {
		Triple t = (Triple) it.next();

		if (list != null)
		  list.add(t);

                ps.setString(1, this.graphName);
                bindSubject(ps, 2, t.getSubject());
                bindPredicate(ps, 3, t.getPredicate());
                bindObject(ps, 4, t.getObject());
                ps.addBatch();
                count++;

                if (count > BATCH_SIZE) {
                  ps.executeBatch();
                  ps.clearBatch();
                  count = 0;
                }
	    }

            if (count > 0) 
            {
                ps.executeBatch();
                ps.clearBatch();
            }
	}
	catch(Exception e)
	{
            throw new JenaException(e);
	}
    }



    void delete(Iterator it, List list)
    {
	try
	{
	    while (it.hasNext())
	    {
		Triple triple = (Triple) it.next();

		if (list != null)
		  list.add(triple);

		performDelete (triple);
	    }
	}
	catch(Exception e)
	{
            throw new JenaException(e);
	}
    }


    void delete_match(TripleMatch tm)
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

       try
       {
	  if (nS == null && nP == null && nO == null) {

	    clearGraph(this.graphName);

	  } else if (nS != null && nP != null && nO != null) {
      	    java.sql.PreparedStatement ps;

            ps = connection.prepareStatement(sdelete);
            ps.setString(1, this.graphName);
            bindSubject(ps, 2, nS);
            bindPredicate(ps, 3, nP);
            bindObject(ps, 4, nO);

	    ps.execute();

	  } else  {

	    if (nS != null)
		S = Node2Str(nS);

	    if (nP != null)
		P = Node2Str(nP);

	    if (nO != null)
		O = Node2Str(nO);

            String query = "sparql delete from graph <"+this.graphName+
  		"> { "+S+" "+P+" "+O+" } from <"+this.graphName+"> where { "+S+" "+P+" "+O+" }";

	    java.sql.Statement stmt = connection.createStatement();
	    stmt.execute(query);
          }
      }
      catch(Exception e)
      {
          throw new DeleteDeniedException(e.toString());
      }
    }


    void clearGraph(String name)
    {
        String query = "sparql clear graph iri(??)";

	checkOpen();

	try
	{
	    java.sql.PreparedStatement ps = connection.prepareStatement(query);
	    ps.setString(1, name);
	    ps.execute();
	}
	catch(Exception e)
	{
            throw new JenaException(e);
	}
    }


    public ExtendedIterator reifierTriples( TripleMatch m )
        { return NullIterator.instance; }

    public int reifierSize()
        { return 0; }

    
    
    @Override
    public TransactionHandler getTransactionHandler()
    {
	return new VirtTransactionHandler(this);
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
	if( m_prefixMapping == null)
		m_prefixMapping = new VirtPrefixMapping( this );
	return m_prefixMapping; 
    }


    public static Node Object2Node(Object o)
    {
      if (o instanceof VirtuosoExtendedString) 
        {
          VirtuosoExtendedString vs = (VirtuosoExtendedString) o;
          if (vs.iriType == VirtuosoExtendedString.IRI) {
            if (vs.str.indexOf ("_:") == 0)
              return Node.createAnon(AnonId.create(vs.str.substring(2))); // _:
            else
              return Node.createURI(vs.str);
          } else if (vs.iriType == VirtuosoExtendedString.BNODE) {
            return Node.createAnon(AnonId.create(vs.str.substring(9))); // nodeID://
          } else {
            return Node.createLiteral(vs.str); 
          }
        }
      else if (o instanceof VirtuosoRdfBox)
        {
          VirtuosoRdfBox rb = (VirtuosoRdfBox)o;
          String rb_type = rb.getType();
          RDFDatatype dt = null;

          if ( rb_type != null)
            dt = TypeMapper.getInstance().getSafeTypeByName(rb_type);
          return Node.createLiteral(rb.toString(), rb.getLang(), dt);
        }
      else if (o instanceof java.lang.Integer)
        {
          RDFDatatype dt = null;
          dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#integer");
          return Node.createLiteral(o.toString(), null, dt);
        }
      else if (o instanceof java.lang.Short)
        {
          RDFDatatype dt = null;
//          dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#short");
          dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#integer");
          return Node.createLiteral(o.toString(), null, dt);
        }
      else if (o instanceof java.lang.Float)
        {
          RDFDatatype dt = null;
          dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#float");
          return Node.createLiteral(o.toString(), null, dt);
        }
      else if (o instanceof java.lang.Double)
        {
          RDFDatatype dt = null;
          dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#double");
          return Node.createLiteral(o.toString(), null, dt);
        }
      else if (o instanceof java.math.BigDecimal)
        {
          RDFDatatype dt = null;
          dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#decimal");
          return Node.createLiteral(o.toString(), null, dt);
        }
      else if (o instanceof java.sql.Blob)
        {
          RDFDatatype dt = null;
          dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#hexBinary");
          return Node.createLiteral(o.toString(), null, dt);
        }
      else if (o instanceof java.sql.Date)
        {
          RDFDatatype dt = null;
          dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#date");
          return Node.createLiteral(o.toString(), null, dt);
        }
      else if (o instanceof java.sql.Timestamp)
        {
          RDFDatatype dt = null;
          dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#dateTime");
          return Node.createLiteral(o.toString(), null, dt);
        }
      else if (o instanceof java.sql.Time)
        {
          RDFDatatype dt = null;
          dt = TypeMapper.getInstance().getSafeTypeByName("http://www.w3.org/2001/XMLSchema#time");
          return Node.createLiteral(o.toString(), null, dt);
        }
      else 
        {
          return Node.createLiteral(o.toString());
        }

    }

}

