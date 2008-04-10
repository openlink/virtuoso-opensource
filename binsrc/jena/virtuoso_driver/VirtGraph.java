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
//import com.hp.hpl.jena.db.GraphRDB;
import com.hp.hpl.jena.util.iterator.ExtendedIterator;
import com.hp.hpl.jena.util.iterator.NiceIterator;
import com.hp.hpl.jena.db.impl.ResultSetIterator;
import com.hp.hpl.jena.shared.*;
import com.hp.hpl.jena.db.impl.*;
import com.hp.hpl.jena.util.iterator.*;
import com.hp.hpl.jena.graph.query.*;


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

	String exec_text ="create procedure jena_remove (in _G any, in _S any, in _P any, in _O any){delete from RDF_QUAD where G=DB.DBA.RDF_MAKE_IID_OF_QNAME (_G) and S=DB.DBA.RDF_MAKE_IID_OF_QNAME (_S) and P=DB.DBA.RDF_MAKE_IID_OF_QNAME (_P) and O=DB.DBA.RDF_MAKE_IID_OF_QNAME (_O);}";

	if (connection == null)
	{
	    try
	    {
//??TOD FIXME create procedure twice
		Class.forName("virtuoso.jdbc3.Driver");
		connection = DriverManager.getConnection(url, user, password);
		java.sql.Statement stmt = connection.createStatement();
		stmt.executeUpdate(exec_text);
	    }
	    catch(Exception e)
	    {
		System.out.println("Connection to " + url + " is FAILED.");
		e.printStackTrace();
		System.exit(-1);
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

    @Override
    public void performAdd(Triple t)
    {
	String S, P, O;
	String exec_text;

	S = t.getSubject().toString();
	P = t.getPredicate().toString();
	O = t.getObject().toString();

	exec_text ="DB.DBA.RDF_QUAD_URI ('" + this.graphName +
	    				  "', '" + S +
	    				  "', '" + P +
	    				  "', '" + O +
					  "')";

	try
	{
	    java.sql.Statement stmt = connection.createStatement();
	    stmt.executeQuery(exec_text);
	}
	catch(Exception e)
	{
	    e.printStackTrace();
	    System.exit(-1);
	}
    }


    public void performDelete (Triple t)
    {
	String S, P, O;
	String exec_text;

	S = t.getSubject().toString();
	P = t.getPredicate().toString();
	O = t.getObject().toString();

	exec_text ="jena_remove (" +
	    	   "'" + this.graphName + "', " +
		   "'" + S + "', " +
		   "'" + P + "', " +
		   "'" + O + "')";

	try
	{
	    java.sql.Statement stmt = connection.createStatement();
	    stmt.executeQuery(exec_text);
	}
	catch(Exception e)
	{
	    e.printStackTrace();
	    System.exit(-1);
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
		e.printStackTrace();
		System.exit(-1);
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
	S = t.getSubject().toString();
	P = t.getPredicate().toString();
	O = t.getObject().toString();

	exec_text = "select count (*) from (sparql select * from <"
			+ this.graphName + "> where {" + "<" + S + "> <" + P + "> <"
				+ O + ">})f";
	try {
		java.sql.Statement stmt = connection.createStatement();
		rs = stmt.executeQuery(exec_text);
		rs.next();
		return (rs.getInt(1) == 1);
	} catch (Exception e) {
		e.printStackTrace();
		System.exit(-1);
	}

	return false;
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
		S = " <" + tm.getMatchSubject().toString() + "> ";

	if (tm.getMatchPredicate() != null)
		P = " <" + tm.getMatchPredicate().toString() + "> ";

	if (tm.getMatchObject() != null)
		O = " <" + tm.getMatchObject().toString() + "> ";

	exec_text = "SPARQL SELECT * from <" + graphName + "> WHERE { " + S + P
			+ O + " }";

	try {
		java.sql.PreparedStatement stmt = connection
				.prepareStatement(exec_text);
		return new VirtResSetIter(stmt.executeQuery(), tm);
	} catch (Exception e) {
		e.printStackTrace();
		System.exit(-1);
	}

	return null;
    }


    @Override
    public void close() {
	try {
		super.close(); // will set closed = true
		connection.close();
	} catch (Exception e) {
		e.printStackTrace();
	}
    }
    
    
// Extra functions

    public void clear()
    {
	String exec_text ="delete from RDF_QUAD where G=DB.DBA.RDF_MAKE_IID_OF_QNAME ('" + this.graphName + "')";

	checkOpen();
	try
	{
	    java.sql.Statement stmt = connection.createStatement();
	    stmt.executeUpdate(exec_text);
	}
	catch(Exception e)
	{
	    e.printStackTrace();
	    System.exit(-1);
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
	    e.printStackTrace();
	    System.exit(-1);
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
	    e.printStackTrace();
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
	    e.printStackTrace();
	}
    }



    public ExtendedIterator reifierTriples( TripleMatch m )
        { return NullIterator.instance; }

    public int reifierSize()
        { return 0; }

    
    
    /* TODO */

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

}

