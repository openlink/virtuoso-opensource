/*
 *  $Id: VirtDataSource.java,v 1.7.2.8 2012/03/08 12:55:00 source Exp $
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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
import javax.sql.*;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;


import org.apache.jena.graph.*;
import org.apache.jena.shared.*;
import org.apache.jena.util.iterator.*;

import org.apache.jena.query.Dataset;
import org.apache.jena.query.LabelExistsException;
import org.apache.jena.rdf.model.Model;
import org.apache.jena.shared.Lock;
import org.apache.jena.sparql.core.DatasetGraph;
import org.apache.jena.sparql.core.Quad;
import org.apache.jena.sparql.util.Context;
import org.apache.jena.query.ReadWrite;

import virtuoso.jdbc4.VirtuosoDataSource;

public class VirtDataset extends VirtGraph implements Dataset {

    /**
     * Default model - may be null - according to Javadoc
     */
    Model defaultModel = null;
    private Context m_context = new Context();


    public VirtDataset() {
        super();
    }

    public VirtDataset(String _graphName, DataSource _ds) {
        super(_graphName, _ds);
    }

    public VirtDataset(DataSource _ds) {
        super(_ds);
    }

    public VirtDataset(String _graphName, ConnectionPoolDataSource _ds) {
        super(_graphName, _ds);
    }

    public VirtDataset(ConnectionPoolDataSource _ds) {
        super(_ds);
    }

    public VirtDataset(String _graphName, XADataSource _ds) {
        super(_graphName, _ds);
    }

    public VirtDataset(XADataSource _ds) {
        super(_ds);
    }

    protected VirtDataset(VirtGraph g) {
        this.graphName = g.getGraphName();
        setReadFromAllGraphs(g.getReadFromAllGraphs());
        this.url_hostlist = g.getGraphUrl();
        this.user = g.getGraphUser();
        this.password = g.getGraphPassword();
        this.roundrobin = g.roundrobin;
        setFetchSize(g.getFetchSize());
        this.connection = g.getConnection();
    }

    public VirtDataset(String url_hostlist, String user, String password) {
        super(url_hostlist, user, password);
    }

    /**
     * Get the default graph as a Jena Model
     */
    public Model getDefaultModel() {
        return defaultModel;
    }

    /**
     * Set the background graph.  Can be set to null for none.
     */
    public void setDefaultModel(Model model) {
        if (!(model instanceof VirtDataset))
            throw new IllegalArgumentException("VirtDataSource supports only VirtModel as default model");
        defaultModel = model;
    }

    /**
     * Get a graph by name as a Jena Model
     */
    public Model getNamedModel(String name) {
        try {
            DataSource _ds = getDataSource();
            if (_ds != null)
                return new VirtModel(new VirtGraph(name, _ds));
            else
                return new VirtModel(new VirtGraph(name, this.getGraphUrl(),
                        this.getGraphUser(), this.getGraphPassword()));
        } catch (Exception e) {
            throw new JenaException(e);
        }
    }

    /**
     * Does the dataset contain a model with the name supplied?
     */
    public boolean containsNamedModel(String name) {
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
        return (ret != 0);
    }


    /**
     * Set a named graph.
     */
    public void addNamedModel(String name, Model model, boolean checkExists) throws LabelExistsException {
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

    /**
     * Set a named graph.
     */
    public void addNamedModel(String name, Model model) throws LabelExistsException {
        addNamedModel(name, model, true);
    }

    /**
     * Remove a named graph.
     */
    public void removeNamedModel(String name) {
        String exec_text = "sparql clear graph <" + name + ">";

        checkOpen();
        try {
            java.sql.Statement stmt = createStatement();
            stmt.executeQuery(exec_text);
            stmt.close();
        } catch (Exception e) {
            throw new JenaException(e);
        }
    }

    /**
     * Change a named graph for another uisng the same name
     */
    public void replaceNamedModel(String name, Model model) {
        try {
            removeNamedModel(name);
            addNamedModel(name, model, false);
        } catch (Exception e) {
            throw new JenaException("Could not replace model:", e);
        }
    }

    /**
     * List the names
     */
    public Iterator<String> listNames() {
        String exec_text = "DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS()";
        ResultSet rs = null;
        int ret = 0;

        checkOpen();
        try {
            List<String> names = new LinkedList<String>();

            java.sql.Statement stmt = createStatement();
            rs = stmt.executeQuery(exec_text);
            while (rs.next())
                names.add(rs.getString(1));
            rs.close();
            return names.iterator();
        } catch (Exception e) {
            throw new JenaException(e);
        }
    }

    Lock lock = null;

    /**
     * Get the lock for this dataset
     */
    public Lock getLock() {
        if (lock == null)
            lock = new org.apache.jena.shared.LockNone();
        return lock;
    }

    public Context getContext() {
        return m_context;
    }

    public boolean supportsTransactions() {
        TransactionHandler handler = getTransactionHandler();
        return handler.transactionsSupported();
    }

    public boolean supportsXATransactions() {
        VirtTransactionHandler handler = getTransactionHandler();
        return handler.transactionsXASupported();
    }

    /**
     * Start either a READ or WRITE transaction
     */
    public void begin(ReadWrite readWrite) {
        TransactionHandler handler = getTransactionHandler();
        handler.begin();
    }


    /**
     * Commit a transaction - finish the transaction and make any changes permanent (if a "write" transaction)
     */
    public void commit() {
        TransactionHandler handler = getTransactionHandler();
        handler.commit();
    }

    /**
     * Abort a transaction - finish the transaction and undo any changes (if a "write" transaction)
     */
    public void abort() {
        TransactionHandler handler = getTransactionHandler();
        handler.abort();
    }

    /**
     * Say whether a transaction is active
     */
    public boolean isInTransaction() {
        try {
            return (!(getConnection().getAutoCommit()));
        } catch (Exception e) {
            return false;
        }

    }

    /**
     * Finish the transaction - if a write transaction and commit() has not been called, then abort
     */
    public void end() {
        TransactionHandler handler = getTransactionHandler();
        handler.abort();
/**
 try {
 getConnection().rollback();
 getConnection().setAutoCommit(true);
 } catch (Exception e) {}
 **/
    }

    /**
     * Get the dataset in graph form
     */
    public DatasetGraph asDatasetGraph() {
        return new VirtDataSetGraph(this);
    }


    public class VirtDataSetGraph implements DatasetGraph {

        VirtDataset vd = null;

        public VirtDataSetGraph(VirtDataset vds) {
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

        protected List<Node> getListGraphNodes() {
            String exec_text = "DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS()";
            ResultSet rs = null;
            int ret = 0;

            vd.checkOpen();
            try {
                List<Node> names = new LinkedList<Node>();

                java.sql.Statement stmt = vd.createStatement();
                rs = stmt.executeQuery(exec_text);
                while (rs.next())
                    names.add(NodeFactory.createURI(rs.getString(1))); //NodeFactory.createURI()
                rs.close();
                return names;
            } catch (Exception e) {
                throw new JenaException(e);
            }
        }

        public Iterator<Node> listGraphNodes() {
            return getListGraphNodes().iterator();
        }

        public Lock getLock() {
            return vd.getLock();
        }

        public long size() {
            return vd.size();
        }

        public void close() {
            vd.close();
        }

        public Context getContext() {
            return vd.m_context;
        }


        /**
         * Set the default graph.  Set the active graph if it was null.
         * This replaces the contents default graph, not merge data into it.
         * Do not assume that the same object is returned by {@link #getDefaultGraph}
         */
        public void setDefaultGraph(Graph g) {
            if (!(g instanceof VirtGraph))
                throw new IllegalArgumentException("VirtDataSetGraph.setDefaultGraph() supports only VirtGraph as default graph");

            vd = new VirtDataset((VirtGraph) g);
        }

        /**
         * Add the given graph to the dataset.
         * <em>Replaces</em> any existing data for the named graph; to add data,
         * get the graph and add triples to it, or add quads to the dataset.
         * Do not assume that the same Java object is returned by {@link #getGraph}
         */
        public void addGraph(Node graphName, Graph graph) {
            try {
                vd.clear(graphName);
//??todo add optimize  when graph is VirtGraph
                ExtendedIterator<Triple> it = graph.find(Node.ANY, Node.ANY, Node.ANY);
                vd.add(graphName.toString(), it, null);
            } catch (Exception e) {
                throw new JenaException("Error in addGraph:" + e);
            }
        }

        /**
         * Remove all data associated with the named graph
         */
        public void removeGraph(Node graphName) {
            try {
                vd.clear(graphName);
            } catch (Exception e) {
                throw new JenaException("Error in removeGraph:" + e);
            }
        }


        /**
         * Add a quad
         */
        public void add(Quad quad) {
            vd.performAdd(quad.getGraph().toString(), quad.getSubject(), quad.getPredicate(), quad.getObject());
        }

        /**
         * Delete a quad
         */
        public void delete(Quad quad) {
            vd.performDelete(quad.getGraph().toString(), quad.getSubject(), quad.getPredicate(), quad.getObject());
        }

        /**
         * Add a quad
         */
        public void add(Node g, Node s, Node p, Node o) {
            vd.performAdd(g.toString(), s, p, o);
        }

        /**
         * Delete a quad
         */
        public void delete(Node g, Node s, Node p, Node o) {
            vd.performDelete(g.toString(), s, p, o);
        }

        /**
         * Delete any quads matching the pattern
         */
        public void deleteAny(Node g, Node s, Node p, Node o) {
            Triple t = new Triple(s, p, o);

            if (Node.ANY.equals(g)) {
                String exec_text = "DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS()";
                ResultSet rs = null;
                java.sql.Statement stmt = null;

                vd.checkOpen();
                try {

                    stmt = vd.createStatement();
                    rs = stmt.executeQuery(exec_text);
                    while (rs.next())
                        vd.delete_match(rs.getString(1), t);

                } catch (Exception e) {
                    throw new JenaException("Error in deleteAny():" + e);
                } finally {
                    if (stmt != null)
                        try {
                            stmt.close();
                        } catch (Exception e) {
                        }
                }

            } else {
                vd.delete_match(g.toString(), t);
            }
        }

        /**
         * Iterate over all quads in the dataset graph
         */
        public Iterator<Quad> find() {
            return find(Node.ANY, Node.ANY, Node.ANY, Node.ANY);
        }

        /**
         * Find matching quads in the dataset - may include wildcards, Node.ANY or null
         *
         * @see Graph#find(TripleMatch)
         */
        public Iterator<Quad> find(Quad quad) {
            return find(quad.getGraph(), quad.getSubject(), quad.getPredicate(), quad.getObject());
        }

        /**
         * Find matching quads in the dataset (including default graph) - may include wildcards, Node.ANY or null
         *
         * @see Graph#find(Node, Node, Node)
         */
        public Iterator<Quad> find(Node g, Node s, Node p, Node o) {
            List<Node> graphs;
            if (isWildcard(g)) {
                graphs = getListGraphNodes();
            } else {
                graphs = new LinkedList();
                graphs.add(g);
            }

            return new VirtResSetQIter(vd, graphs.iterator(), new Triple(s, p, o));
        }

        /**
         * Find matching quads in the dataset in named graphs only - may include wildcards, Node.ANY or null
         *
         * @see Graph#find(Node, Node, Node)
         */
        public Iterator<Quad> findNG(Node g, Node s, Node p, Node o) {
            return find(g, s, p, o);
        }

        /**
         * Test whether the dataset  (including default graph) contains a quad - may include wildcards, Node.ANY or null
         */
        public boolean contains(Node g, Node s, Node p, Node o) {
            if (isWildcard(g)) {
                boolean save = vd.getReadFromAllGraphs();
                vd.setReadFromAllGraphs(true);
                boolean ret = vd.graphBaseContains(null, new Triple(s, p, o));
                vd.setReadFromAllGraphs(save);
                return ret;
            } else {
                return vd.graphBaseContains(g.toString(), new Triple(s, p, o));
            }
        }

        /**
         * Test whether the dataset contains a quad  (including default graph)- may include wildcards, Node.ANY or null
         */
        public boolean contains(Quad quad) {
            return contains(quad.getGraph(), quad.getSubject(), quad.getPredicate(), quad.getObject());
        }

        public void clear() {
            vd.clear();
        }

        /**
         * Test whether the dataset is empty
         */
        public boolean isEmpty() {
            return contains(Node.ANY, Node.ANY, Node.ANY, Node.ANY);
        }

        protected boolean isWildcard(Node g) {
            return g == null || Node.ANY.equals(g);
        }

    }

}
