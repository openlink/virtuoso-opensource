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



    public VirtGraph()
    {
	this(null, "jdbc:virtuoso://localhost:1111", null, null);
    }

    public VirtGraph(String url, String user, String password)
    {
	this(null, url, user, password);
    }

    public VirtGraph(String graphName)
    {
	this(graphName, "jdbc:virtuoso://localhost:1111", null, null);
    }

    public VirtGraph(String graphName, String url, String user, String password)
    {
	super();

	this.graphName = graphName;
	this.url = url;
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
        delete(triples);
    }

    public void remove(Triple t)
    {
        delete(t);
    }



// GraphBase overrides
    String Node2Str(Node n)
    {
      if (n instanceof Node_URI) {
        return "<"+n+">";
      } else if (n instanceof Node_Blank) {
        return "<_:"+n+">"; 
      } else {
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
      }
    }

    @Override
    public void performAdd(Triple t)
    {
      String S, P, O;
      String exec_text;

      S = Node2Str(t.getSubject());
      P = Node2Str(t.getPredicate());
      O = Node2Str(t.getObject());

      exec_text = "sparql insert into graph <"+this.graphName+"> { "+
      		    S+" "+P+" "+O+" }";

      try
	{
	    java.sql.Statement stmt = connection.createStatement();
	    stmt.executeQuery(exec_text);
	}
      catch(Exception e)
	{
            throw new JenaException(e);
	}
    }


    public void performDelete (Triple t)
    {
      String S, P, O;
      String exec_text;

      S = Node2Str(t.getSubject());
      P = Node2Str(t.getPredicate());
      O = Node2Str(t.getObject());

      exec_text = "sparql delete from graph <"+this.graphName+"> { "+
      		    S+" "+P+" "+O+" }";

      try
	{
	    java.sql.Statement stmt = connection.createStatement();
	    stmt.executeQuery(exec_text);
	}
      catch(Exception e)
	{
            throw new JenaException(e);
	}
    }


    /**
     * more efficient
     */
    @Override
    protected int graphBaseSize() {
	String exec_text = "select count (*) from (sparql select * from <"
			+ this.graphName + ">  where {?s ?p ?o})f";
	ResultSet rs = null;
	int ret = 0;

	checkOpen();

	try {
		java.sql.Statement stmt = connection.createStatement();
		rs = stmt.executeQuery(exec_text);
		rs.next();
		ret = rs.getInt(1);
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

	exec_text = "select count (*) from (sparql select * from <"
			+ this.graphName + "> where { " 
			+ S +" "+ P +" "+ O +" })f";

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
	String exec_text ="sparql clear graph <" + this.graphName + ">";

	checkOpen();

	try
	{
	    java.sql.Statement stmt = connection.createStatement();
	    stmt.executeQuery(exec_text);
	}
	catch(Exception e)
	{
            throw new JenaException(e);
	}
	;
    }


    public void read (String url, String type)
    {
	String exec_text;

	exec_text ="sparql load \"" + url + "\" into graph <" + graphName + ">";

	checkOpen();
	try
	{
	    java.sql.Statement stmt = connection.createStatement();
	    stmt.executeQuery(exec_text);
	}
	catch(Exception e)
	{
            throw new JenaException(e);
	}

    }


    @SuppressWarnings("unchecked")
    public void add(List triples)
    {
	Iterator it = triples.iterator();

	try
	{
	    while (it.hasNext())
	    {
		Triple triple = (Triple) it.next();
		add (triple);
	    }
	}
	catch(Exception e)
	{
            throw new JenaException(e);
	}
    }



    public void delete(List triples)
    {
	Iterator it = triples.iterator();

	try
	{
	    while (it.hasNext())
	    {
		Triple triple = (Triple) it.next();
		delete (triple);
	    }
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

