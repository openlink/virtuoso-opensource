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
            throw new JenaException("Convert results are FAILED.:"+e);
	}
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
}
