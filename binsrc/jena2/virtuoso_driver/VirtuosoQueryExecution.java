/*
 *  $Id: VirtuosoQueryExecution.java,v 1.11.2.11 2012/03/15 12:56:34 source Exp $
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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
import java.sql.Connection;
import java.sql.Statement;
import java.sql.ResultSetMetaData;

import virtuoso.sql.*;

import com.hp.hpl.jena.graph.NodeFactory;
import com.hp.hpl.jena.shared.*;
import com.hp.hpl.jena.query.Query;
import com.hp.hpl.jena.query.ResultSet;
import com.hp.hpl.jena.query.Dataset;
import com.hp.hpl.jena.query.QueryExecution;

import com.hp.hpl.jena.rdf.model.RDFNode;
import com.hp.hpl.jena.graph.Node;
import com.hp.hpl.jena.graph.Triple;
import com.hp.hpl.jena.rdf.model.*;

import com.hp.hpl.jena.sparql.engine.binding.BindingFactory;
import com.hp.hpl.jena.sparql.engine.binding.Binding;
import com.hp.hpl.jena.sparql.engine.binding.BindingMap;
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
import java.util.concurrent.TimeUnit ;

import virtuoso.jdbc4.VirtuosoConnectionPoolDataSource;

public class VirtuosoQueryExecution  implements QueryExecution
{
    private QueryIterConcat output = null;
    private String virt_graph = null;
    private VirtGraph graph;
    private String virt_query;
    private QuerySolution m_arg = null;
    private Context m_context = new Context();
    private Query mj_query = null;
    protected long timeout = -1;

    private java.sql.Statement stmt = null;


    public VirtuosoQueryExecution (Query query, VirtGraph _graph)
    {
      this(query.toString(), _graph);
      mj_query = query;
    }

    public VirtuosoQueryExecution (String query, VirtGraph _graph)
    {
	graph = _graph;
	virt_graph = graph.getGraphName ();
	virt_query = query;
    }


    public ResultSet execSelect()
    {
      ResultSet ret = null;

      try {
        stmt = graph.createStatement();
        if (timeout > 0)
          stmt.setQueryTimeout((int)(timeout/1000));
        java.sql.ResultSet rs = stmt.executeQuery(getVosQuery());

        return new VResultSet(graph, stmt, rs);
      }	catch(Exception e) {
        throw new JenaException("Can not create ResultSet.:"+e);
      }
    }



    public void setFileManager(FileManager arg)
    {
      throw new JenaException("UnsupportedMethodException");
    }


    public void setInitialBinding(QuerySolution arg)
    {
      m_arg = arg;
    }

    public Dataset getDataset()
    {
      return new VirtDataset(graph);
    }


    public Context getContext()
    {
      return m_context;
    }

    public Query getQuery()
    {
      if (mj_query == null) {
        try {
          mj_query = QueryFactory.create(virt_query);
        } catch (Exception e) {}
      }
      return mj_query;
    }

    public Model execConstruct() 
    {
      return execConstruct(ModelFactory.createDefaultModel());
    }


    public Model execConstruct(Model model)
    {
      try {
        stmt = graph.createStatement();
        if (timeout > 0)
          stmt.setQueryTimeout((int)(timeout/1000));
        java.sql.ResultSet rs = stmt.executeQuery(getVosQuery());
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
        rs.close();
        stmt.close();
        stmt = null;

      } catch (Exception e) {
        throw new JenaException("Convert results are FAILED.:"+e);
      }
      return model;
    }

    /**
     * Execute a CONSTRUCT query, returning the results as an iterator of {@link Triple}.
     * <b>Caution:</b> This method may return duplicate Triples.  This method may be useful if you only
     * need the results for stream processing, as it can avoid having to place the results in a Model.
     * 
     * @return An iterator of Triple objects (possibly containing duplicates) generated
     * by applying the CONSTRUCT template of the query to the bindings in the WHERE clause.
     */
    public Iterator<Triple> execConstructTriples()
    {
      try {
        stmt = graph.createStatement();
        if (timeout > 0)
          stmt.setQueryTimeout((int)(timeout/1000));
        java.sql.ResultSet rs = stmt.executeQuery(getVosQuery());
        return new VirtResSetIter2(graph, stmt, rs);

      } catch (Exception e) {
        throw new JenaException("execConstructTriples was FAILED.:"+e);
      }
    }


	
    public Model execDescribe() 
    {
      return execDescribe(ModelFactory.createDefaultModel());
    }

    public Model execDescribe(Model model)
    {
      try {
        stmt = graph.createStatement();
        if (timeout > 0)
          stmt.setQueryTimeout((int)(timeout/1000));
        java.sql.ResultSet rs = stmt.executeQuery(getVosQuery());
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
        rs.close();
        stmt.close();
        stmt = null;

      } catch (Exception e) {
        throw new JenaException("Convert results are FAILED.:"+e);
      }
      return model;
    }


    /**
     * Execute a DESCRIBE query, returning the results as an iterator of {@link Triple}.
     * <b>Caution:</b> This method may return duplicate Triples.  This method may be useful if you only
     * need the results for stream processing, as it can avoid having to place the results in a Model.
     * 
     * @return An iterator of Triple objects (possibly containing duplicates) generated as the output of the DESCRIBE query.
     */
    public Iterator<Triple> execDescribeTriples()
    {
      try {
        stmt = graph.createStatement();
        if (timeout > 0)
          stmt.setQueryTimeout((int)(timeout/1000));
        java.sql.ResultSet rs = stmt.executeQuery(getVosQuery());
        return new VirtResSetIter2(graph, stmt, rs);

      } catch (Exception e) {
        throw new JenaException("execDescribeTriples was FAILED.:"+e);
      }
    }


    public boolean execAsk() 
    {
      boolean ret = false;

      try {
        stmt = graph.createStatement();
        if (timeout > 0)
          stmt.setQueryTimeout((int)(timeout/1000));
        java.sql.ResultSet rs = stmt.executeQuery(getVosQuery());
        ResultSetMetaData rsmd = rs.getMetaData();

        while(rs.next())
        {
          if (rs.getInt(1) == 1)
            ret = true;
        }	
        rs.close();
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
          stmt.close();
        } catch (Exception e) {}
    }

    public boolean isClosed()
    {
      return stmt==null;
    }


    /** Set a timeout on the query execution.
     * Processing will be aborted after the timeout (which starts when the approprate exec call is made).
     * Not all query execution systems support timeouts.
     * A timeout of less than zero means no timeout.
     */
	
    public void setTimeout(long timeout, TimeUnit timeoutUnits)
    {
       this.timeout = timeout;

    }
	
    /** Set time, in milliseconds 
     * @see #setTimeout(long, TimeUnit)
     */
    public void setTimeout(long timeout)
    {
       this.timeout = timeout;
    }
    
    /** Set timeouts on the query execution; the first timeout refers to time to first result, 
     * the second refers to overall query execution after the first result.  
     * Processing will be aborted if a timeout expires.
     * Not all query execution systems support timeouts.
     * A timeout of less than zero means no timeout; this can be used for timeout1 or timeout2.
     */

    public void setTimeout(long timeout1, TimeUnit timeUnit1, long timeout2, TimeUnit timeUnit2)
    {
       this.timeout = timeout1;
    }

    /** Set time, in milliseconds
     *  @see #setTimeout(long, TimeUnit, long, TimeUnit)
     */
    public void setTimeout(long timeout1, long timeout2)
    {
       this.timeout = timeout1;
    }


    /** Return the first timeout (time to first result), in millseconds: negative if unset */
    public long getTimeout1()
    {
      return timeout;
    }

    /** Return the second timeout (overall query execution after first result), in millseconds: negative if unset */
    public long getTimeout2()
    {
      return -1L;
    }

    private String substBindings(String query) 
    {
      if (m_arg == null)
        return query;

      StringBuffer buf = new StringBuffer();
      String delim = " ,)(;.";
      int i = 0;
      char ch;
      int qlen = query.length();
      while( i < qlen) {
        ch = query.charAt(i++);
        if (ch == '\\') {
	  buf.append(ch);
          if (i < qlen)
            buf.append(query.charAt(i++)); 

        } else if (ch == '"' || ch == '\'') {
          char end = ch;
      	  buf.append(ch);
      	  while (i < qlen) {
            ch = query.charAt(i++);
            buf.append(ch);
            if (ch == end)
              break;
      	  }
        } else  if ( ch == '?' ) {  //Parameter
      	  String varData = null;
      	  int j = i;
      	  while(j < qlen && delim.indexOf(query.charAt(j)) < 0) j++;
      	  if (j != i) {
            String varName = query.substring(i, j);
            RDFNode val = m_arg.get(varName);
            if (val != null) {
              varData = VirtGraph.Node2Str(val.asNode());
              i=j;
            }
          }
          if (varData != null)
            buf.append(varData);
          else
            buf.append(ch);
	} else {
      	  buf.append(ch);
    	}
      }
      return buf.toString();
    }

    
    private String getVosQuery()
    {
	StringBuffer sb = new StringBuffer("sparql\n ");
	
	if (graph.getRuleSet()!= null)
          sb.append(" define input:inference '"+graph.getRuleSet()+"'\n");

        if (graph.getSameAs())
          sb.append(" define input:same-as \"yes\"\n");

        if (!graph.getReadFromAllGraphs())
	  sb.append(" define input:default-graph-uri <" + graph.getGraphName() + "> \n");

      	sb.append(substBindings(virt_query));

      	return sb.toString();
    }

    
    ///=== Inner class ===========================================
    public class VResultSet implements com.hp.hpl.jena.query.ResultSet 
    {
      java.sql.Statement stmt;
      ResultSetMetaData rsmd;
      java.sql.ResultSet rs;
      boolean v_finished = false;
      boolean v_prefetched = false;
      VirtModel m;
      BindingMap v_row;
      List<String> resVars =new LinkedList();
      int row_id = 0;


        protected VResultSet(VirtGraph _g, java.sql.Statement _stmt, java.sql.ResultSet _rs) 
	{
	  stmt = _stmt;
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
          v_row = BindingFactory.create();
          row_id++;

          try {
	    for(int i = 1; i <= rsmd.getColumnCount(); i++) {
	      Node n = VirtGraph.Object2Node(rs.getObject(i));
	      if (n != null)
	        v_row.add(Var.alloc(rsmd.getColumnLabel(i)), n);
	    }

	    if (virt_graph != null && !virt_graph.equals("virt:DEFAULT"))
	      v_row.add(Var.alloc("graph"), NodeFactory.createURI(virt_graph));
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

        private void close()
        {
	  if (!v_finished)
	  {
	    if (rs != null)
	    {
	      try {
                rs.close();
                rs = null;
              } catch (Exception e) { }
            }
	    if (stmt != null)
	    {
	      try {
                stmt.close();
                stmt = null;
              } catch (Exception e) { }
            }
          }
          v_finished = true;
        }


    }

}
