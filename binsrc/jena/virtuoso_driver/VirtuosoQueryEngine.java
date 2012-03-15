/*
 *  $Id$
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

import java.util.*;

import com.hp.hpl.jena.shared.*;
import com.hp.hpl.jena.graph.Node;

import com.hp.hpl.jena.query.Query;
import com.hp.hpl.jena.sparql.ARQInternalErrorException;
import com.hp.hpl.jena.sparql.ARQConstants ;
import com.hp.hpl.jena.sparql.algebra.Op;
import com.hp.hpl.jena.sparql.algebra.Transform;
import com.hp.hpl.jena.sparql.algebra.TransformCopy;
import com.hp.hpl.jena.sparql.algebra.Transformer;
import com.hp.hpl.jena.sparql.algebra.op.OpBGP;
import com.hp.hpl.jena.sparql.core.DatasetGraph;
import com.hp.hpl.jena.sparql.core.Var;
import com.hp.hpl.jena.sparql.engine.binding.BindingMap;
import com.hp.hpl.jena.sparql.engine.binding.Binding;
import com.hp.hpl.jena.sparql.engine.Plan;
import com.hp.hpl.jena.sparql.engine.QueryEngineFactory;
import com.hp.hpl.jena.sparql.engine.QueryEngineRegistry;
import com.hp.hpl.jena.sparql.engine.QueryIterator;
import com.hp.hpl.jena.sparql.engine.iterator.QueryIteratorBase;
import com.hp.hpl.jena.sparql.engine.binding.Binding;
import com.hp.hpl.jena.sparql.engine.main.QueryEngineMain;
import com.hp.hpl.jena.sparql.serializer.SerializationContext;
import com.hp.hpl.jena.sparql.util.Context;
import com.hp.hpl.jena.sparql.util.IndentedWriter;
import com.hp.hpl.jena.sparql.util.Utils;


public class VirtuosoQueryEngine extends QueryEngineMain
{
    private Query eQuery = null;

    
    public VirtuosoQueryEngine(Query query, DatasetGraph dataset, Binding initial, Context context)
    {
        super(query, dataset, initial, context) ;
        eQuery = query;
    }

    public VirtuosoQueryEngine(Query query, DatasetGraph dataset)
    { 
        this(query, dataset, null, null) ;
    }

    @Override
    public QueryIterator eval(Op op, DatasetGraph dsg, Binding initial, Context context)
    {
        // Extension point: access possible to all the parameters for execution.
        // Be careful to deal with initial bindings.
        Transform transform = new VirtTransform() ;
        op = Transformer.transform(transform, op) ;
        
        VirtGraph vg = (VirtGraph)dsg.getDefaultGraph();
        String query = fixQuery(eQuery.toString(), initial, vg);
	
	try
	{
	    java.sql.Statement  stmt = vg.createStatement();
	    java.sql.ResultSet rs = stmt.executeQuery(query);
	    return (QueryIterator)new VQueryIterator(vg, rs);
	}
	catch(Exception e)
	{
            throw new JenaException("Can not create QueryIterator.:"+e);
	}
    }
    

    private String substBindings(String query, Binding args) 
    {
      if (args == null)
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
            Node val = args.get(Var.alloc(varName));
            if (val != null) {
              varData = VirtGraph.Node2Str(val);
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

    
    private String fixQuery(String query, Binding args, VirtGraph vg)
    {
	StringBuffer sb = new StringBuffer("sparql\n ");

	if (vg.getRuleSet()!=null)
          sb.append(" define input:inference '"+vg.getRuleSet()+"'\n ");

        if (vg.getSameAs())
          sb.append(" define input:same-as \"yes\"\n ");

        if (!vg.getReadFromAllGraphs())
	  sb.append(" define input:default-graph-uri <" + vg.getGraphName() + "> \n");

        sb.append(substBindings(query, args));

      	return sb.toString();
    }


    @Override
    protected Op modifyOp(Op op)
    {
        // Extension point: possible place to alter the algebra expression.
        // Alternative to eval(). 
        op = super.modifyOp(op) ;
        return op ;
    }
    
    // ---- Registration of the factory for this query engine class. 
    
    // Query engine factory.
    // Call VirtQueryEngine.register() to add to the global query engine registry. 

    static QueryEngineFactory factory = new VirtQueryEngineFactory() ;

    static public QueryEngineFactory getFactory() { return factory ; } 
    static public void register()       { QueryEngineRegistry.addFactory(factory) ; }
    static public void unregister()     { QueryEngineRegistry.removeFactory(factory) ; }
    



    private class VirtTransform extends TransformCopy
    {
      // Example, do nothing tranform. 
      @Override
      public Op transform(OpBGP opBGP) { return opBGP; }
    }




    private static class VirtQueryEngineFactory implements QueryEngineFactory
    {
      // Accept any dataset for query execution 
      public boolean accept(Query query, DatasetGraph dataset, Context context) 
      { 
        if ( dataset instanceof VirtDataSource.VirtDataSetGraph )
          return true ;
        if (dataset.getDefaultGraph() instanceof VirtGraph )
          return true ;
        return false ;
      }

      public Plan create(Query query, DatasetGraph dataset, Binding initial, Context context)
      {
        if (!(dataset instanceof VirtDataSource.VirtDataSetGraph)) {
          if (!(dataset.getDefaultGraph() instanceof VirtGraph ))
            throw new ARQInternalErrorException("VirtQueryEngineFactory: only factory VirtuosoDatasetGraph is supported") ;
        }
        // Create a query engine instance.
        VirtuosoQueryEngine engine = new VirtuosoQueryEngine(query, dataset, initial, context);
        return engine.getPlan() ;
      }

      public boolean accept(Op op, DatasetGraph dataset, Context context)
      {   // Refuse to accept algebra expressions directly.
        return false ;
      }

      public Plan create(Op op, DatasetGraph dataset, Binding inputBinding, Context context)
      {   // Shodul notbe called because acceept/Op is false
        throw new ARQInternalErrorException("VirtQueryEngineFactory: factory calleddirectly with an algebra expression") ;
      }
    } 



    
    protected class VQueryIterator extends QueryIteratorBase {
      java.sql.ResultSetMetaData rsmd;
      java.sql.ResultSet rs;
      VirtGraph    vg;
      boolean	 v_finished = false;
      boolean	 v_prefetched = false;
      Binding 	 v_row;
      String virt_graph = null;


      protected VQueryIterator(VirtGraph _g, java.sql.ResultSet _rs) 
      {
        rs = _rs;
        vg = _g;
        virt_graph = vg.getGraphName ();

        try {
          rsmd = rs.getMetaData();
        } catch(Exception e) {
          throw new JenaException("VQueryIterator is FAILED.:"+e);
        }

      }


      public void output(IndentedWriter out, SerializationContext sCxt)
      {
        out.print(Utils.className(this)) ;
      }

      protected boolean hasNextBinding()
      {
        if (!v_finished && !v_prefetched) 
          moveForward();
        return !v_finished;
      }

      protected Binding moveToNextBinding()
      {
        if (!v_finished && !v_prefetched)
          moveForward();

        v_prefetched = false;

        if (v_finished)
          return null;

        return v_row;
      }

    
      protected void closeIterator()
      {
        if (!v_finished) {
          if (rs != null) {
  	    try {
              rs.close();
              rs = null;
            } catch (Exception e) { }
          }
        }
        v_finished = true;
      }


      protected void moveForward() throws JenaException
      {
        try {
          if (!v_finished && rs.next()) {
            extractRow();
            v_prefetched = true;
          } else
            closeIterator();
        } catch (Exception e) {
          throw new JenaException("Convert results are FAILED.:"+e);
        }
      }

      protected void extractRow() throws Exception 
      {
        v_row = new BindingMap();

        try {
          for(int i = 1; i <= rsmd.getColumnCount(); i++) {
            Node n = VirtGraph.Object2Node(rs.getObject(i));
            if (n != null)
              v_row.add(Var.alloc(rsmd.getColumnLabel(i)), n);
          }

          if (virt_graph != null && !virt_graph.equals("virt:DEFAULT"))
	    v_row.add(Var.alloc("graph"), Node.createURI(virt_graph));
        } 
        catch(Exception e) {
          throw new JenaException("extractRow is FAILED.:"+e);
        }
      }


      protected void finalize() throws Throwable
      {
        if (!v_finished) 
          try {
            close();
          } catch (Exception e) {}
      }
  
    }

}

