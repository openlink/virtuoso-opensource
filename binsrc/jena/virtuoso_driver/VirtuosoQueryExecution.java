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

import java.util.*;
import java.io.*;
import java.net.*;
import java.sql.*;

import virtuoso.jdbc3.*;

import com.hp.hpl.jena.shared.*;
import com.hp.hpl.jena.query.ResultSet;
import com.hp.hpl.jena.query.Dataset;
import com.hp.hpl.jena.query.QueryExecution;

import com.hp.hpl.jena.rdf.model.RDFNode;
import com.hp.hpl.jena.graph.Node;
import com.hp.hpl.jena.rdf.model.*;

import com.hp.hpl.jena.sparql.engine.binding.BindingMap;
import com.hp.hpl.jena.sparql.engine.binding.Binding;
import com.hp.hpl.jena.sparql.engine.ResultSetStream;
import com.hp.hpl.jena.sparql.engine.QueryIterator;
import com.hp.hpl.jena.sparql.engine.iterator.QueryIterConcat;
import com.hp.hpl.jena.sparql.engine.http.QueryEngineHTTP;
import com.hp.hpl.jena.sparql.engine.iterator.QueryIterSingleton;
import com.hp.hpl.jena.sparql.engine.iterator.QueryIteratorResultSet;
import com.hp.hpl.jena.sparql.core.Var;
import com.hp.hpl.jena.sparql.util.Context;
import com.hp.hpl.jena.sparql.util.ModelUtils;
import com.hp.hpl.jena.util.FileManager;
import com.hp.hpl.jena.query.*;


public class VirtuosoQueryExecution  implements QueryExecution
{
    QueryIterConcat output = null;
    String virt_graph = null;
    String virt_query = null;
    String virt_url  = null;
    String virt_user = null;
    String virt_pass = null;
    java.sql.Statement stmt = null;

    public VirtuosoQueryExecution (String query, VirtGraph graph)
    {
	virt_graph = graph.getGraphName ();
	virt_url  = graph.getGraphUrl ();
	virt_pass = graph.getGraphPassword ();
	virt_user = graph.getGraphUser ();

        virt_query = "sparql\n " + query;
    }


    public ResultSet execSelect()
    {
	ResultSet ret = null;

	try
	{
	    Class.forName("virtuoso.jdbc3.Driver");
	    Connection connection = DriverManager.getConnection(virt_url, virt_user, virt_pass);

	    stmt = connection.createStatement();
	    VirtuosoResultSet result_set = (VirtuosoResultSet) stmt.executeQuery(virt_query);

	    ret = ViruosoResultBindingsToJenaResults (result_set);

	    stmt.close();
	    stmt = null;
	    connection.close();
	    return ret;
	}
	catch(Exception e)
	{
            throw new JenaException("Convert results are FAILED.:"+e);
	}
    }


    public com.hp.hpl.jena.query.ResultSet ViruosoResultBindingsToJenaResults (virtuoso.jdbc3.VirtuosoResultSet VirtuosoRes)
    {
	try
	{
	    ResultSetMetaData rsmd = VirtuosoRes.getMetaData();

	    while(VirtuosoRes.next())
	    {
		Binding b = new BindingMap();
		for(int i = 1; i <= rsmd.getColumnCount(); i++)
		{
		    b.add(Var.alloc(rsmd.getColumnLabel(i)), 
		       VirtGraph.Object2Node(VirtuosoRes.getObject(i)));
		}
		if (virt_graph != null && !virt_graph.equals("virt:DEFAULT"))
		    b.add(Var.alloc("graph"), Node.createURI(virt_graph));
		AddToRes (b);
	    }

	}
	catch(Exception e)
	{
            throw new JenaException("ViruosoResultBindingsToJenaResults is FAILED.:"+e);
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


    public void setFileManager(FileManager arg)
    {
      throw new JenaException("UnsupportedMethodException");
    }


    public void setInitialBinding(QuerySolution arg)
    {
      throw new JenaException("UnsupportedMethodException");
    }

    public Dataset getDataset()
    {
      return null;
    }


    public Context getContext()
    {
      return null;
    }


    public Model execConstruct() 
    {
	return execConstruct(ModelFactory.createDefaultModel());
    }


    public Model execConstruct(Model model)
    {
/************
	try {
	    Class.forName("virtuoso.jdbc3.Driver");
	    Connection connection = DriverManager.getConnection(virt_url, virt_user, virt_pass);

	    stmt = connection.createStatement();
	    VirtuosoResultSet rs = (VirtuosoResultSet) stmt.executeQuery(virt_query);
	    ResultSetMetaData rsmd = rs.getMetaData();

	    while(rs.next())
	    {
	      Node s = VirtGraph.Object2Node(rs.getObject(1));
	      Node p = VirtGraph.Object2Node(rs.getObject(2));
	      Node o = VirtGraph.Object2Node(rs.getObject(3));
	      Statement st = ModelUtils.tripleToStatement(model, new Triple(s, p, o));
	      if (st != null)
	        model.add(st);
	    }	

	    stmt.close();
	    stmt = null;
	    connection.close();

	} catch (Exception e) {
            throw new JenaException("Convert results are FAILED.:"+e);
	}
*****************/
	return model;
    }


	
    public Model execDescribe() {
	return execDescribe(ModelFactory.createDefaultModel());
    }

    public Model execDescribe(Model model)
    {
/***************
	try {
	    Class.forName("virtuoso.jdbc3.Driver");
	    Connection connection = DriverManager.getConnection(virt_url, virt_user, virt_pass);

	    stmt = connection.createStatement();
	    VirtuosoResultSet rs = (VirtuosoResultSet) stmt.executeQuery(virt_query);
	    ResultSetMetaData rsmd = rs.getMetaData();

	    while(rs.next())
	    {
	      Node s = VirtGraph.Object2Node(rs.getObject(1));
	      Node p = VirtGraph.Object2Node(rs.getObject(2));
	      Node o = VirtGraph.Object2Node(rs.getObject(3));
	      Statement st = ModelUtils.tripleToStatement(model, new Triple(s, p, o));
	      if (st != null)
	        model.add(st);
	    }	

	    stmt.close();
	    stmt = null;
	    connection.close();

	} catch (Exception e) {
            throw new JenaException("Convert results are FAILED.:"+e);
	}
******************/
	return model;
    }


    public boolean execAsk() {
        boolean ret = false;

	try {
	    Class.forName("virtuoso.jdbc3.Driver");
	    Connection connection = DriverManager.getConnection(virt_url, virt_user, virt_pass);

	    stmt = connection.createStatement();
	    VirtuosoResultSet rs = (VirtuosoResultSet) stmt.executeQuery(virt_query);
	    ResultSetMetaData rsmd = rs.getMetaData();

	    while(rs.next())
	    {
	      if (rs.getInt(1) == 1)
	        ret = true;
	    }	

	    stmt.close();
	    stmt = null;
	    connection.close();

	} catch (Exception e) {
            throw new JenaException("Convert results are FAILED.:"+e);
	}
	return ret;
    }


    public void abort() 
    {
	if (stmt != null)
	  try {
	      stmt.cancel();
	  } catch (Exception e) {}
    }


    public void close() 
    {
	if (stmt != null)
	  try {
	      stmt.cancel();
	  } catch (Exception e) {}
    }

}
