
package virtuoso_driver;

import java.util.*;
import java.io.*;
import java.net.*;
import java.sql.*;

import virtuoso.jdbc3.*;

import com.hp.hpl.jena.query.ResultSet;
import com.hp.hpl.jena.query.Dataset;

import com.hp.hpl.jena.rdf.model.RDFNode;
import com.hp.hpl.jena.graph.Node;
import com.hp.hpl.jena.rdf.model.Model;

import com.hp.hpl.jena.sparql.engine.binding.BindingMap;
import com.hp.hpl.jena.sparql.engine.binding.Binding;
import com.hp.hpl.jena.sparql.engine.ResultSetStream;
import com.hp.hpl.jena.sparql.engine.QueryIterator;
import com.hp.hpl.jena.sparql.engine.iterator.QueryIterConcat;
import com.hp.hpl.jena.sparql.engine.http.QueryEngineHTTP;
import com.hp.hpl.jena.sparql.engine.iterator.QueryIterSingleton;
import com.hp.hpl.jena.sparql.core.Var;

public class VirtuosoQueryExecution
{
    QueryIterConcat output = null;
    String virt_graph = null;
    String virt_query = null;
    String virt_url  = null;
    String virt_user = null;
    String virt_pass = null;

    public VirtuosoQueryExecution (String query)
    {
	virt_query = "sparql " + query;
    }

    public VirtuosoQueryExecution (String query, VirtGraph graph)
    {
	virt_graph = graph.getGraphName ();
	virt_query = "sparql\n define input:default-graph-uri <" + virt_graph + "> \n"
	    + query;
	virt_url  = graph.getGraphUrl ();
	virt_pass = graph.getGraphPassword ();
	virt_user = graph.getGraphUser ();
    }

    public ResultSet execSelect()
    {
	ResultSet ret = null;

	try
	{
	    Class.forName("virtuoso.jdbc3.Driver");
	    Connection connection = DriverManager.getConnection(virt_url, virt_user, virt_pass);

	    java.sql.Statement stmt = connection.createStatement();
	    VirtuosoResultSet result_set = (VirtuosoResultSet) stmt.executeQuery(virt_query);

	    ret = ViruosoResultBindingsToJenaResults (result_set);

	    connection.close();
	    return ret;
	}
	catch(Exception e)
	{
	    System.out.println("Convert results are FAILED.");
	    e.printStackTrace();
	    System.exit(-1);
	}

	return null;
    }

    public com.hp.hpl.jena.query.ResultSet ViruosoResultBindingsToJenaResults (virtuoso.jdbc3.VirtuosoResultSet VirtuosoRes)
    {
	try
	{
	    ResultSetMetaData data = VirtuosoRes.getMetaData();

	    while(VirtuosoRes.next())
	    {
		Binding b = new BindingMap();
		for(int meta_count = 1;meta_count <= data.getColumnCount();meta_count++)
		{
		    b.add(Var.alloc(data.getColumnLabel(meta_count)), Node.createURI(VirtuosoRes.getString(meta_count)));
		}
		if (virt_graph != null)
		    b.add(Var.alloc("graph"), Node.createURI(virt_graph));
		AddToRes (b);
	    }

	}
	catch(Exception e)
	{
	    System.out.println("ViruosoResultBindingsToJenaResults is FAILED.");
	    e.printStackTrace();
	    System.exit(-1);
	}

	return new ResultSetStream(null, null, output);
    }

    private void AddToRes (Binding b)
    {
	QueryIterator qIter = new QueryIterSingleton(b, null);

	if (output == null)
	  output = new QueryIterConcat(null);

	output.add(qIter);
    }
}
