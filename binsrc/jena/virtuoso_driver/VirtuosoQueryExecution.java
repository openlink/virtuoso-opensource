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

import virtuoso.sql.*;

import com.hp.hpl.jena.shared.*;
import com.hp.hpl.jena.query.ResultSet;
import com.hp.hpl.jena.query.Dataset;
import com.hp.hpl.jena.query.QueryExecution;

import com.hp.hpl.jena.rdf.model.RDFNode;
import com.hp.hpl.jena.graph.Node;
import com.hp.hpl.jena.graph.Triple;
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
import com.hp.hpl.jena.sparql.core.ResultBinding;
import com.hp.hpl.jena.sparql.util.Context;
import com.hp.hpl.jena.sparql.util.ModelUtils;
import com.hp.hpl.jena.util.FileManager;
import com.hp.hpl.jena.query.*;

import virtuoso.jdbc3.VirtuosoConnectionPoolDataSource;

public class VirtuosoQueryExecution  implements QueryExecution
{
    private QueryIterConcat output = null;
    String virt_graph = null;
    private VirtGraph graph;
    private String virt_query;

    int prefetchSize = 200;
    java.sql.Statement stmt = null;


    public VirtuosoQueryExecution (String query, VirtGraph _graph)
    {
	graph = _graph;
	virt_graph = graph.getGraphName ();
	prefetchSize = graph.getFetchSize ();

	StringTokenizer tok = new StringTokenizer(query);
	String s = "";

	while (tok.hasMoreTokens()) {
	  s = tok.nextToken().toLowerCase();
		  if (s.equals("describe") || s.equals("construct") || s.equals("ask"))
              break;
	}

	if (s.equals("describe") || s.equals("construct") || s.equals("ask"))
           virt_query = "sparql\n define output:format '_JAVA_'\n " + query;
        else
      	   virt_query = "sparql\n " + query;
    }


    public ResultSet execSelect()
    {
	ResultSet ret = null;

	try
	{

	    Connection connection = graph.getConnection();

	    stmt = connection.createStatement();
	    stmt.setFetchSize(prefetchSize);
	    java.sql.ResultSet rs = stmt.executeQuery(virt_query);

	    return new VResultSet(graph, rs);
	}
	catch(Exception e)
	{
            throw new JenaException("Can not create ResultSet.:"+e);
	}
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
	try {

	    Connection connection = graph.getConnection();

	    stmt = connection.createStatement();
	    stmt.setFetchSize(prefetchSize);
	    java.sql.ResultSet rs = stmt.executeQuery(virt_query);
	    ResultSetMetaData rsmd = rs.getMetaData();

	    while(rs.next())
	    {
	      Node s = VirtGraph.Object2Node(rs.getObject(1));
	      Node p = VirtGraph.Object2Node(rs.getObject(2));
	      Node o = VirtGraph.Object2Node(rs.getObject(3));
	      com.hp.hpl.jena.rdf.model.Statement st = ModelUtils.tripleToStatement(model, new Triple(s, p, o));
	      if (st != null)
	        model.add(st);
	    }	

	    stmt.close();
	    stmt = null;

	} catch (Exception e) {
            throw new JenaException("Convert results are FAILED.:"+e);
	}
	return model;
    }


	
    public Model execDescribe() {
	return execDescribe(ModelFactory.createDefaultModel());
    }

    public Model execDescribe(Model model)
    {
	try {
	    Connection connection = graph.getConnection();

	    stmt = connection.createStatement();
	    stmt.setFetchSize(prefetchSize);
	    java.sql.ResultSet rs = stmt.executeQuery(virt_query);
	    ResultSetMetaData rsmd = rs.getMetaData();
	    while(rs.next())
	    {
	      Node s = VirtGraph.Object2Node(rs.getObject(1));
	      Node p = VirtGraph.Object2Node(rs.getObject(2));
	      Node o = VirtGraph.Object2Node(rs.getObject(3));

	      com.hp.hpl.jena.rdf.model.Statement st = ModelUtils.tripleToStatement(model, new Triple(s, p, o));
	      if (st != null)
	        model.add(st);
	    }	

	    stmt.close();
	    stmt = null;

	} catch (Exception e) {
            throw new JenaException("Convert results are FAILED.:"+e);
	}
	return model;
    }


    public boolean execAsk() {
        boolean ret = false;

	try {
	    Connection connection = graph.getConnection();

	    stmt = connection.createStatement();
	    java.sql.ResultSet rs = stmt.executeQuery(virt_query);
	    ResultSetMetaData rsmd = rs.getMetaData();

	    while(rs.next())
	    {
	      if (rs.getInt(1) == 1)
	        ret = true;
	    }	

	    stmt.close();
	    stmt = null;

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


    ///=== Inner class ===========================================
    public class VResultSet implements com.hp.hpl.jena.query.ResultSet {
                                           
	ResultSetMetaData rsmd;
        java.sql.ResultSet rs;
	boolean	  v_finished = false;
	boolean	  v_prefetched = false;
	VirtModel m;
	Binding v_row;
	List<String> resVars;
	int row_id = 0;


	protected VResultSet(VirtGraph _g, java.sql.ResultSet _rs) 
	{
	  super();
	  rs = _rs;
	  m = new VirtModel(_g);

          try {
            rsmd = rs.getMetaData();

	    for(int i = 1; i <= rsmd.getColumnCount(); i++)
	      resVars.add(rsmd.getColumnLabel(i));

	    if (virt_graph != null && !virt_graph.equals("virt:DEFAULT"))
	      resVars.add("graph");
	  } 
	  catch(Exception e)
	  {
            throw new JenaException("ViruosoResultBindingsToJenaResults is FAILED.:"+e);
	  }
	}
        
        public boolean hasNext()
        {
       	  if (!v_finished && !v_prefetched) 
       	    moveForward();
	  return !v_finished;
        }
    
        public QuerySolution next()
        {
          Binding binding = nextBinding() ;

	  if (v_finished)
	    throw new NoSuchElementException();
  
          return new ResultBinding(m, binding) ;
        }

        public QuerySolution nextSolution()
        {
          return next();
        }

        public Binding nextBinding()
        {
          if (!v_finished && !v_prefetched)
	    moveForward();

	  v_prefetched = false;

	  if (v_finished)
	    throw new NoSuchElementException();
  
          return v_row;
        }
    
        public int getRowNumber()
        {
          return row_id;
        }
    
        public List<String> getResultVars()
        {
          return resVars;
        }

        public Model getResourceModel()
        {
          return m;
        }

	protected void finalize() throws Throwable
	{
	  if (!v_finished) 
	    try {
	      close();
	    } catch (Exception e) {}
	}

	protected void moveForward() throws JenaException
	{
	  try
	  {
	    if (!v_finished && rs.next())
	    {
		extractRow();
		v_prefetched = true;
	    }
	    else
		close();
	    }
	    catch (Exception e)
	    {
              throw new JenaException("Convert results are FAILED.:"+e);
	    }
	}

	protected void extractRow() throws Exception 
	{
          v_row = new BindingMap();
          row_id++;

          try {
	    for(int i = 1; i <= rsmd.getColumnCount(); i++)
	      v_row.add(Var.alloc(rsmd.getColumnLabel(i)), 
	        VirtGraph.Object2Node(rs.getObject(i)));

	    if (virt_graph != null && !virt_graph.equals("virt:DEFAULT"))
	      v_row.add(Var.alloc("graph"), Node.createURI(virt_graph));
	  } 
	  catch(Exception e)
	  {
            throw new JenaException("ViruosoResultBindingsToJenaResults is FAILED.:"+e);
	  }
	}

        public void remove() throws java.lang.UnsupportedOperationException
        {
          throw new UnsupportedOperationException(this.getClass().getName()+".remove") ;
        }

    }

}
