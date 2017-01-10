/*
 *  $Id$
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


import java.sql.*;
import java.util.Iterator;
import java.util.Vector;
import java.util.LinkedList;
import java.util.List;


import com.hp.hpl.jena.shared.*;
import com.hp.hpl.jena.graph.Graph;
import com.hp.hpl.jena.graph.Node;
import com.hp.hpl.jena.graph.Triple;
import com.hp.hpl.jena.query.DataSource;
import com.hp.hpl.jena.query.Dataset;
import com.hp.hpl.jena.query.LabelExistsException;
import com.hp.hpl.jena.rdf.model.Model;
import com.hp.hpl.jena.shared.Lock;
import com.hp.hpl.jena.sparql.core.DatasetGraph;

import virtuoso.jdbc3.VirtuosoDataSource;

public class VirtDataSource extends VirtGraph implements DataSource {

    /**
     * Default model - may be null - according to Javadoc
     */
    Model defaultModel = null;


    public VirtDataSource()
    {
      super();
    }

    public VirtDataSource(String _graphName, javax.sql.DataSource _ds)
    {
      super(_graphName, _ds);
    }

    protected VirtDataSource(VirtGraph g)
    {
      this.graphName = g.getGraphName();
      setReadFromAllGraphs(g.getReadFromAllGraphs());
      this.url_hostlist = g.getGraphUrl();
      this.user = g.getGraphUser();
      this.password = g.getGraphPassword();
      this.roundrobin = g.roundrobin;
      setFetchSize(g.getFetchSize());
      this.connection = g.getConnection();
    }

    public VirtDataSource(String url_hostlist, String user, String password)
    {
      super(url_hostlist, user, password);
    }

    /** Set the background graph.  Can be set to null for none.  */
    public void setDefaultModel(Model model) 
    {
      if (!(model instanceof VirtDataSource))
        throw new IllegalArgumentException("VirtDataSource supports only VirtModel as default model");
      defaultModel = model;
    }


    public void addNamedModel(String name, Model model, boolean checkExists) throws LabelExistsException 
    {
      String query = "select count(*) from (sparql select * where { graph `iri(??)` { ?s ?p ?o }})f";
      ResultSet rs = null;
      int ret = 0;

      checkOpen();
      if (checkExists) {
        try {
          java.sql.PreparedStatement ps = prepareStatement(query);
          ps.setString(1, name);
          rs = ps.executeQuery();
          if (rs.next())
            ret = rs.getInt(1);
          rs.close();
        } catch (Exception e) {
          throw new JenaException(e);
        }

        if (ret != 0)
          throw new LabelExistsException("A model with ID '" + name
					+ "' already exists.");
      }

      Graph g = model.getGraph();
      add(name, g.find(Node.ANY, Node.ANY, Node.ANY), null);
    }


    /** Set a named graph. */
    public void addNamedModel(String name, Model model)	throws LabelExistsException 
    {
      addNamedModel(name, model, true);
    }


    /** Remove a named graph. */
    public void removeNamedModel(String name) 
    {
      String exec_text ="sparql clear graph <"+ name + ">";

      checkOpen();
      try {
        java.sql.Statement stmt = createStatement();
        stmt.executeQuery(exec_text);
        stmt.close();
      } catch (Exception e) {
	throw new JenaException(e);
      }
    }


    /** Change a named graph for another uisng the same name */
    public void replaceNamedModel(String name, Model model) 
    {
      try {
        removeNamedModel(name);
        addNamedModel(name, model, false);
      } catch (Exception e) {
        throw new JenaException("Could not replace model:", e);
      }
    }


    /** Get the default graph as a Jena Model */
    public Model getDefaultModel() {
      return defaultModel;
    }


    /** Get a graph by name as a Jena Model */
    public Model getNamedModel(String name) 
    {
      try {
        javax.sql.DataSource _ds = getDataSource();
        if (_ds != null) 
	    return new VirtModel(new VirtGraph(name, _ds));
        else
	    return new VirtModel(new VirtGraph(name, this.getGraphUrl(), 
			this.getGraphUser(), this.getGraphPassword()));
      } catch (Exception e) {
	throw new JenaException(e);
      }
    }


    /** Does the dataset contain a model with the name supplied? */ 
    public boolean containsNamedModel(String name) 
    {
      String query = "select count(*) from (sparql select * where { graph `iri(??)` { ?s ?p ?o }})f";
      ResultSet rs = null;
      int ret = 0;

      checkOpen();
      try {
        java.sql.PreparedStatement ps = prepareStatement(query);
        ps.setString(1, name);
        rs = ps.executeQuery();
        if (rs.next())
          ret = rs.getInt(1);
        rs.close();
      } catch (Exception e) {
        throw new JenaException(e);
      }
      return (ret!=0);
    }


    /** List the names */
    public Iterator<String> listNames() 
    {
      String exec_text = "DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS()";
      ResultSet rs = null;
      int ret = 0;

      checkOpen();
      try {
        List<String> names=new LinkedList(); 

        java.sql.Statement stmt = createStatement();
        rs = stmt.executeQuery(exec_text);
        while(rs.next())
          names.add(rs.getString(1));
        rs.close();
        return names.iterator();
      } catch (Exception e) {
        throw new JenaException(e);
      }
    }


    Lock lock = null ;

    /** Get the lock for this dataset */
    public Lock getLock() 
    {
      if (lock == null)
        lock = new com.hp.hpl.jena.shared.LockNone();
      return lock;
    }


    /** Get the dataset in graph form */
    public DatasetGraph asDatasetGraph() 
    {
      return new VirtDataSetGraph(this);
    }


    public class VirtDataSetGraph implements DatasetGraph 
    {

      VirtDataSource vd = null;

      public VirtDataSetGraph(VirtDataSource vds) 
      {
        vd = vds;
      }

      public Graph getDefaultGraph() {
        return vd;
      }

      public Graph getGraph(Node graphNode) {
        try {
          return new VirtGraph(graphNode.toString(), vd.getGraphUrl(),
	     vd.getGraphUser(), vd.getGraphPassword());
	} catch (Exception e) {
	  throw new JenaException(e);
        }
      }

      public boolean containsGraph(Node graphNode) {
        return containsNamedModel(graphNode.toString());
      }

      public Iterator<Node> listGraphNodes() 
      {
        String exec_text = "DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS()";
        ResultSet rs = null;
        int ret = 0;

        vd.checkOpen();
        try {
	  List<Node> names=new LinkedList();

  	  java.sql.Statement stmt = vd.createStatement();
	  rs = stmt.executeQuery(exec_text);
	  while(rs.next())
	    names.add(Node.createURI(rs.getString(1)));
	  rs.close();
	  return names.iterator();
	} catch (Exception e) {
	  throw new JenaException(e);
        }
      }

      public Lock getLock() 
      {
        return vd.getLock();
      }

      public int size() 
      {
        return vd.size();
      }

      public void close() 
      {
        vd.close();
      }
    
    }

}
