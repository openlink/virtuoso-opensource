package virtuoso_driver;

import java.sql.*;
import java.io.*;
import java.util.*;
import java.util.Iterator;

import virtuoso.jdbc3.*;

import com.hp.hpl.jena.graph.*;
import com.hp.hpl.jena.db.GraphRDB;
import com.hp.hpl.jena.util.iterator.ExtendedIterator;
import com.hp.hpl.jena.util.iterator.NiceIterator;
import com.hp.hpl.jena.db.impl.ResultSetIterator;
import com.hp.hpl.jena.shared.*;
import com.hp.hpl.jena.db.impl.*;
import com.hp.hpl.jena.util.iterator.*;
import com.hp.hpl.jena.graph.query.*;


public class VirtGraph implements Graph
{
    private String graphName;
    private String url;
    private String user;
    private String password;
    private int connection_status = 0;
    private Connection connection = null;
    protected GraphRDB m_parent = null;

    public VirtGraph()
    {
    }

    public VirtGraph(String url, String user, String password)
    {
	this.url = url;
	this.user = user;
	this.password = password;
    }

    public VirtGraph(String graphName)
    {
	this.graphName = graphName;
    }

    public VirtGraph(String graphName, String url, String user, String password)
    {
	this.graphName = graphName;
	this.url = url;
	this.user = user;
	this.password = password;

	String exec_text ="create procedure jena_remove (in _G any, in _S any, in _P any, in _O any){delete from RDF_QUAD where G=DB.DBA.RDF_MAKE_IID_OF_QNAME (_G) and S=DB.DBA.RDF_MAKE_IID_OF_QNAME (_S) and P=DB.DBA.RDF_MAKE_IID_OF_QNAME (_P) and O=DB.DBA.RDF_MAKE_IID_OF_QNAME (_O);}";

	if (connection == null)
	{
	    try
	    {
		Class.forName("virtuoso.jdbc3.Driver");
		connection = DriverManager.getConnection(url, user, password);
		java.sql.Statement stmt = connection.createStatement();
		stmt.executeUpdate(exec_text);
		connection_status = 1;
	    }
	    catch(Exception e)
	    {
		System.out.println("Connection to " + url + " is FAILED.");
		e.printStackTrace();
		System.exit(-1);
	    }
	}
    }

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

    public void read (String url, String type)
    {
	String exec_text;

	exec_text ="sparql load \"" + url + "\" into graph <" + graphName + ">";

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

    public boolean isEmpty()
    {
	return getCount() == 0;
    }

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

    public void add(Triple t)
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

    public void performAdd(Triple t)
    {
	add (t);
    }

    public void remove(List triples)
    {
	Iterator it = triples.iterator();

	try
	{
	    while (it.hasNext())
	    {
		Triple triple = (Triple) it.next();
		remove (triple);
	    }
	}
	catch(Exception e)
	{
	    e.printStackTrace();
	}
    }

    public void remove(Triple t)
    {
	/*graph.delete(t);*/
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

    public void clear()
    {
	String exec_text ="delete from RDF_QUAD where G=DB.DBA.RDF_MAKE_IID_OF_QNAME ('" + this.graphName + "')";

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


    public int getCount()
    {
	String exec_text ="select count (*) from (sparql select * from <" + this.graphName + ">  where {?s ?p ?o})f";
	ResultSet rs = null;
	int ret = 0;

	try
	{
	    java.sql.Statement stmt = connection.createStatement();
	    rs = stmt.executeQuery(exec_text);
	    rs.next();
	    ret = rs.getInt(1);
	}
	catch(Exception e)
	{
	    e.printStackTrace();
	    System.exit(-1);
	}

	return ret;
    }

    public boolean isClosed()
    {
	return false;
    }

    public int size()
    {
	return  getCount();
    }

    public void close()
    {
	try
	{
	    connection.close();
	    connection_status = 0;
	}
	catch(Exception e)
	{
	    e.printStackTrace();
	}
    }

    public boolean contains (Node s, Node p, Node o)
    {
	return contains (Triple.create( s, p, o ) );
    }

    public ExtendedIterator find(Node s, Node p, Node o)
    {
	return find (Triple.createMatch( s, p, o ));
    }

    public void delete(Triple t)
    {
	remove (t);
    }

    public void performDelete (Triple t)
    {
	remove (t);
    }

    public boolean contains(Triple t)
    {
	ResultSet rs = null;
	String S, P, O;
	String exec_text;

	S = t.getSubject().toString();
	P = t.getPredicate().toString();
	O = t.getObject().toString();

	exec_text ="select count (*) from (sparql select * from <" + this.graphName + "> where {" +
	    "<" + S + "> <" + P + "> <" + O + ">})f";
	try
	{
	    java.sql.Statement stmt = connection.createStatement();
	    rs = stmt.executeQuery(exec_text);
	    rs.next();
	    return (rs.getInt(1) == 1);
	}
	catch(Exception e)
	{
	    e.printStackTrace();
	    System.exit(-1);
	}

	return false;
    }

    public ExtendedIterator find(TripleMatch tm)
    {
	String S, P, O;
	String exec_text;

	S = " ?s ";
	P = " ?p ";
	O = " ?o ";

	if (tm.getMatchSubject() != null)
	    S = " <" + tm.getMatchSubject().toString() + "> ";

	if (tm.getMatchPredicate() != null)
	    P = " <" + tm.getMatchPredicate().toString() + "> ";

	if (tm.getMatchObject() != null)
	    O = " <" + tm.getMatchObject().toString() + "> ";

	exec_text = "SPARQL SELECT * from <" + graphName + "> WHERE { " + S + P + O + " }";

	try
	{
	    java.sql.PreparedStatement stmt = connection.prepareStatement(exec_text);
	    return new VirtResSetIter (stmt.executeQuery(), tm);
	}
	catch(Exception e)
	{
	    e.printStackTrace();
	    System.exit(-1);
	}

	return null;
    }


    /* TODO */

    public boolean isIsomorphicWith(Graph g)
    {
	return false;
    }

    public PrefixMapping getPrefixMapping()
    {
	return m_parent.getPrefixMapping();
    }

    public Reifier getReifier()
    {
	return null;
    }

    public GraphStatisticsHandler getStatisticsHandler()
    {
	return null;
    }

    public GraphEventManager getEventManager()
    {
	return null;
    }

    public Capabilities getCapabilities()
    {
	return null;
    }

    public QueryHandler queryHandler()
    {
	return null;
    }

    public boolean dependsOn(Graph other)
    {
	return m_parent.dependsOn(other);
    }

    public TransactionHandler getTransactionHandler()
    {
	return m_parent.getTransactionHandler();
    }

    public BulkUpdateHandler getBulkUpdateHandler()
    {
	return m_parent.getBulkUpdateHandler();
    }

    public ExtendedIterator graphBaseFind
	(TripleMatch m)
	{
	    return new NiceIterator()
	    {
		public boolean hasNext()
		{
		    return true;
		}
		public Object next()
		{
		    return null;
		}
		public void remove()
		{
		}
	    };
	}

}

