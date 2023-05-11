/*
 *  $Id:$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2023 OpenLink Software
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
import java.util.*;


import org.apache.jena.graph.*;
import org.apache.jena.query.TxnType;
import org.apache.jena.shared.*;
import org.apache.jena.util.iterator.*;

import org.apache.jena.query.Dataset;
import org.apache.jena.shared.AlreadyExistsException;
import org.apache.jena.rdf.model.*;
import org.apache.jena.rdf.model.impl.ResourceImpl;
import org.apache.jena.shared.Lock;
import org.apache.jena.sparql.core.DatasetGraph;
import org.apache.jena.sparql.core.Quad;
import org.apache.jena.sparql.util.Context;
import org.apache.jena.query.ReadWrite;
import org.apache.jena.riot.system.PrefixMap;
import org.apache.jena.riot.system.PrefixMapAdapter;


public class VirtDataset extends VirtGraph implements Dataset {

    /**
     * Default model - may be null - according to Javadoc
     */
    private Model defaultModel = null;
    private Context m_context = new Context();
    private final HashSet<VirtGraph> graphs = new HashSet<>();


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
        setMacroLib(g.getMacroLib());
        setRuleSet(g.getRuleSet());
        this.connection = g.getConnection();
    }

    public VirtDataset(String url_hostlist, String user, String password) {
        super(url_hostlist, user, password);
    }

    /**
     * Get the default graph as a Jena Model
     */
    public synchronized Model getDefaultModel() {
        if (defaultModel==null) {
            VirtGraph g = new VirtGraph(null, this);
            defaultModel = new VirtModel(g);
            addLink(g);
        }
        return defaultModel;
    }

    @Override
    public Model getUnionModel() {
        throw new UnsupportedOperationException();
    }

    /**
     * Set the background graph.  Can be set to null for none.
     */
    public VirtDataset setDefaultModel(Model model) {
        if (model instanceof VirtModel && ((VirtGraph)model.getGraph()).getConnection()==this.connection ){
            VirtGraph g = (VirtGraph)model.getGraph();
            defaultModel = model;
            removeLink(g);
            return this;
        } else
            throw new IllegalArgumentException("VirtDataset supports only VirtModel with the same DB connection");
    }

    /**
     * Get a graph by name as a Jena Model
     */
    public synchronized Model getNamedModel(String name) {
        try {
            VirtGraph g = new VirtGraph(name, this);
            VirtModel m = new VirtModel(g);
            addLink(g);
            return m;
        } catch (Exception e) {
            throw new JenaException(e);
        }
    }

    /**
     * Get a graph by name as a Jena Model
     */
    public synchronized Model getNamedModel(Resource resource) {
        return this.getNamedModel(resource.toString());
    }

    /**
     * Does the dataset contain a model with the name supplied?
     */
    public boolean containsNamedModel(String name) {
        String query = "select count(*) from (sparql select * where { graph `iri(??)` { ?s ?p ?o }})f";
        ResultSet rs = null;
        PreparedStatement ps = null;
        int ret = 0;

        checkOpen();
        try {
            ps = prepareStatement(query, false);
            ps.setString(1, name);
            rs = ps.executeQuery();
            if (rs.next())
                ret = rs.getInt(1);
            rs.close();
        } catch (Exception e) {
            throw new JenaException(e);
        } finally {
          try {
            if (ps != null)
              ps.close();
          } catch(Exception e) {}
        }
        return (ret != 0);
    }


    /**
     * Does the dataset contain a model with the name supplied?
     */
    public boolean containsNamedModel(Resource resource) {
        return this.containsNamedModel(resource.toString());
    }

    
    /**
     * Set a named graph.
     */
    public VirtDataset addNamedModel(String name, Model model, boolean checkExists) {
        String query = "select count(*) from (sparql select * where { graph `iri(??)` { ?s ?p ?o }})f";
        ResultSet rs = null;
        int ret = 0;
        PreparedStatement ps = null;

        checkOpen();
        if (checkExists) {
            try {
                ps = prepareStatement(query, false);
                ps.setString(1, name);
                rs = ps.executeQuery();
                if (rs.next())
                    ret = rs.getInt(1);
                rs.close();
            } catch (Exception e) {
                throw new JenaException(e);
            } finally {
              try {
                if (ps != null)
                  ps.close();
              } catch(Exception e) {}
            }

            if (ret != 0)
                throw new AlreadyExistsException("A model with ID '" + name
                        + "' already exists.");
        }

        Graph g = model.getGraph();
        add(name, g.find(Node.ANY, Node.ANY, Node.ANY), null);
        return this;
    }

    /**
     * Set a named graph.
     */
    public VirtDataset addNamedModel(String name, Model model) {
        addNamedModel(name, model, true);
        return this;
    }

    /**
     * Add a named graph.
     *
     * @param resource the name of the graph to set
     * @param model the graph to set
     * @return this {@code Dataset} for continued usage
     */
    public Dataset addNamedModel(Resource resource, Model model) {
        return this.addNamedModel(resource.toString(), model);
    }

    /**
     * Remove a named graph.
     */
    public VirtDataset removeNamedModel(String name) {
        String exec_text = "sparql clear graph <" + name + ">";
        java.sql.Statement stmt = null;

        checkOpen();
        try {
            stmt = createStatement(true);
            stmt.executeQuery(exec_text);
            return this;
        } catch (Exception e) {
            throw new JenaException(e);
        } finally {
          try {
            if (stmt != null)
              stmt.close();
          } catch(Exception e) {}
        }
    }

    /**
     * Remove a named graph.
     *
     * @param resource the name of the graph to remove
     * @return this {@code Dataset} for continued usage
     */
    public Dataset removeNamedModel(Resource resource) {
        return this.removeNamedModel(resource.toString());
    }

    
    /**
     * Change a named graph for another uisng the same name
     */
    public VirtDataset replaceNamedModel(String name, Model model) {
        try {
            removeNamedModel(name);
            addNamedModel(name, model, false);
            return this;
        } catch (Exception e) {
            throw new JenaException("Could not replace model:", e);
        }
    }

    /**
     * Change a named graph for another using the same name
     *
     * @param resource the name of the graph to replace
     * @param model the graph with which to replace it
     * @return this {@code Dataset} for continued usage
     */
    public VirtDataset replaceNamedModel(Resource resource, Model model) {
        try {
            removeNamedModel(resource.toString());
            addNamedModel(resource.toString(), model, false);
            return this;
        } catch (Exception e) {
            throw new JenaException("Could not replace model", e);
        }
    }

    /**
     * List the names
     */
    public Iterator<String> listNames() {
        String exec_text = "DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS()";
        ResultSet rs = null;
        java.sql.Statement stmt = null;

        checkOpen();
        try {
            List<String> names = new LinkedList<String>();

            stmt = createStatement(false);
            rs = stmt.executeQuery(exec_text);
            while (rs.next())
                names.add(rs.getString(1));
            rs.close();
            return names.iterator();
        } catch (Exception e) {
            throw new JenaException(e);
        } finally {
          try {
            if (stmt != null)
              stmt.close();
          } catch(Exception e) {}
        }
    }


    /**
     * List the names
     */
    public Iterator<Resource> listModelNames() {
        String exec_text = "DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS()";
        ResultSet rs = null;
        java.sql.Statement stmt = null;

        checkOpen();
        try {
            List<Resource> names = new LinkedList<Resource>();

            stmt = createStatement(false);
            rs = stmt.executeQuery(exec_text);
            while (rs.next())
                names.add(new ResourceImpl(rs.getString(1)));
            rs.close();
            return names.iterator();
        } catch (Exception e) {
            throw new JenaException(e);
        } finally {
          try {
            if (stmt != null)
              stmt.close();
          } catch(Exception e) {}
        }
    }
    
    private Lock lock = null;

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

    public boolean supportsTransactionAbort() {
        TransactionHandler handler = getTransactionHandler();
        return handler.transactionsSupported();
    }


    @Override
    public void begin(TxnType txnType) {
        VirtTransactionHandler handler = getTransactionHandler();
        handler.begin(txnType);
    }

    /**
     * Start either a READ or WRITE transaction
     */
    public void begin(ReadWrite readWrite) {
        VirtTransactionHandler handler = getTransactionHandler();
        handler.begin(readWrite);
    }

    /**
     * Attempt to promote a transaction from "read" mode to "write" and the transaction. This
     * method allows the form of promotion to be specified. The transaction must not have been started
     * with {@code READ}, which is read-only. 
     * <p>
     * An argument of {@code READ_PROMOTE} treats the promotion as if the transaction was started
     * with {@code READ_PROMOTE} (any other writer commiting since the transaction started
     * blocks promotion) and {@code READ_COMMITTED_PROMOTE} treats the promotion as if the transaction was started
     * with {@code READ_COMMITTED_PROMOTE} (intemediate writer commits become visible).
     * <p> 
     * Returns "true" if the transaction is in write mode after the call. The method
     * always succeeds of the transaction is already "write".
     * <p>
     * This method returns true if a {@code READ_PROMOTE} or
     * {@code READ_COMMITTED_PROMOTE} is promoted.
     * <p>
     * This method returns false if a {@code READ_PROMOTE} can't be promoted - the
     * transaction is still valid and in "read" mode.
     * <p>
     * This method throws an exception if there is an attempt to promote a {@code READ}
     * transaction.
     */
    @Override
    public boolean promote(Promote promote) {
        return true;
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

    public void setIsolationLevel(VirtIsolationLevel level){
        VirtTransactionHandler handler = getTransactionHandler();
        handler.setIsolationLevel(level);
    }

    public VirtIsolationLevel getIsolationLevel(){
        VirtTransactionHandler handler = getTransactionHandler();
        return handler.getIsolationLevel();
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
     * Return the current mode of the transaction - "read" or "write".
     * If the caller is not in a transaction, this method returns null.
     */
    @Override
    public ReadWrite transactionMode() {
        VirtTransactionHandler handler = getTransactionHandler();
        return handler.getReadWrite();
    }


    /**
     * Return the transaction type used in {@code begin(TxnType)}.
     * If the caller is not in a transaction, this method returns null.
     */
    @Override
    public TxnType transactionType() {
        if (!isInTransaction())
            return null;
        VirtTransactionHandler handler = getTransactionHandler();
        return handler.getTxnType();
    }

    public synchronized void close() {
        synchronized (graphs){
            HashSet<VirtGraph> copy = (HashSet<VirtGraph>) graphs.clone();
            for (VirtGraph g : copy)
                try {
                    g.close();
                } catch (Exception e) {
                }
            graphs.clear();
            copy.clear();
        }
        super.close();
    }

    protected void addLink(VirtGraph obj)
    {
        synchronized (graphs) {
            graphs.add(obj);
        }
    }


    protected void removeLink(VirtGraph obj)
    {
        synchronized (graphs) {
            graphs.remove(obj);
        }
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

        /** Get the default graph as a Jena Graph */
        public Graph getDefaultGraph() {
            return vd;
        }

        /** Get the graph named by graphNode : returns null when there is no such graph.
         * NB Whether a dataset contains a graph if there are no triples is not defined - see the specific implementation.
         * Some datasets are "open" - they have all graphs even if no triples.
         */
        public Graph getGraph(Node graphNode) {
            try {
                return new VirtGraph(graphNode.toString(), vd.getGraphUrl(),
                        vd.getGraphUser(), vd.getGraphPassword());
            } catch (Exception e) {
                throw new JenaException(e);
            }
        }

        /**
         * Return a {@link Graph} that is the union of all named graphs in this dataset. This
         * union graph is read-only (its prefix mapping in the current JVM may be changed but
         * that may not persist).
         */
        @Override
        public Graph getUnionGraph() {
            throw new UnsupportedOperationException();
        }

        /**
         * Does the DatasetGraph contain a specific named graph?
         * Whether a dataset contains a graph if there are no triples is
         * not defined - see the specific implementation. Some datasets are "open" -
         * they have all graphs even if no triples and this returns true always.
         *
         * @param graphNode
         * @return boolean
         */
        public boolean containsGraph(Node graphNode) {
            return containsNamedModel(graphNode.toString());
        }

        protected List<Node> getListGraphNodes() {
            String exec_text = "DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS()";
            ResultSet rs = null;
            java.sql.Statement stmt = null;

            vd.checkOpen();
            try {
                List<Node> names = new LinkedList<Node>();

                stmt = vd.createStatement(false);
                rs = stmt.executeQuery(exec_text);
                while (rs.next())
                    names.add(NodeFactory.createURI(rs.getString(1))); //NodeFactory.createURI()
                rs.close();
                return names;
            } catch (Exception e) {
                throw new JenaException(e);
            } finally {
              try {
                if (stmt != null)
                  stmt.close();
              } catch(Exception e) {}
            }
        }

        /** Iterate over all names of named graphs */
        public Iterator<Node> listGraphNodes() {
            return getListGraphNodes().iterator();
        }

        /** Return a lock for the dataset to help with concurrency control
         * @see Lock
         */
        public Lock getLock() {
            return vd.getLock();
        }

        /** Get the size (number of named graphs) - may be -1 for unknown */
        public long size() {
            return vd.size();
        }

        /** Close the dataset */
        public void close() {
            vd.close();
        }

        /** Get the context associated with this object - may be null */
        public Context getContext() {
            return vd.m_context;
        }

        /** Prefixes for this DatasetGraph */
        public PrefixMap prefixes() {
            return new PrefixMapAdapter(new VirtPrefixMapping(vd));
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
                throw new JenaException("Error in addGraph", e);
            }
        }

        /**
         * Remove all data associated with the named graph
         */
        public void removeGraph(Node graphName) {
            try {
                vd.clear(graphName);
            } catch (Exception e) {
                throw new JenaException("Error in removeGraph", e);
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

            g = (g!=null? g: Node.ANY);
            s = (s!=null? s: Node.ANY);
            p = (p!=null? p: Node.ANY);
            o = (o!=null? o: Node.ANY);

            Triple t = new Triple(s, p, o);

            if (Node.ANY.equals(g)) {
                String exec_text = "DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS()";
                ResultSet rs = null;
                java.sql.Statement stmt = null;

                vd.checkOpen();
                try {

                    stmt = vd.createStatement(false);
                    rs = stmt.executeQuery(exec_text);
                    while (rs.next())
                        vd.delete_match(rs.getString(1), t);

                } catch (Exception e) {
                    throw new JenaException("Error in deleteAny():" + e);
                } finally {
                  try {
                    if (stmt != null)
                      stmt.close();
                  } catch(Exception e) {}
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
         */
        public Iterator<Quad> find(Quad quad) {
            if (quad == null)
                return find();
            return find(quad.getGraph(), quad.getSubject(), quad.getPredicate(), quad.getObject());
        }

        /**
         * Find matching quads in the dataset (including default graph) - may include wildcards, Node.ANY or null
         *
         * @see Graph#find(Node, Node, Node)
         */
        public Iterator<Quad> find(Node g, Node s, Node p, Node o) {

            s = (s!=null? s: Node.ANY);
            p = (p!=null? p: Node.ANY);
            o = (o!=null? o: Node.ANY);

            List<Node> graphs;
            if (isWildcard(g)) {
                graphs = getListGraphNodes();
            } else {
                graphs = new LinkedList<>();
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

            s = (s!=null? s: Node.ANY);
            p = (p!=null? p: Node.ANY);
            o = (o!=null? o: Node.ANY);

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

        boolean isWildcard(Node g) {
            return g == null || Node.ANY.equals(g);
        }


        /**
         * A {@code DatasetGraph} supports tranactions if it provides {@link #begin}/
         * {@link #commit}/{@link #end}. There core storage {@code DatasetGraph} that
         * provide fully serialized transactions.  {@code DatasetGraph} that provide
         * functionality acorss independent systems can not provide such strong guarantees.
         * For example, they may use MRSW locking and some isolation control.
         * Specifically, they do not necessarily provide {@link #abort}.
         * <p>
         * See {@link #supportsTransactionAbort()} for {@link #abort}.
         * In addition, check details of a specific implementation.
         */
        public boolean supportsTransactions() {
            return vd.supportsTransactions();
        }

        /** Declare whether {@link #abort} is supported.
         *  This goes along with clearing up after exceptions inside application transaction code.
         */
        public boolean supportsTransactionAbort() {
            return vd.supportsTransactionAbort();
        }


        /** Say whether inside a transaction. */ 
        public boolean isInTransaction() {
            return vd.isInTransaction();
        }

        @Override
        public void begin(TxnType txnType) {
            vd.begin(txnType);
        }

        /** Start either a READ or WRITE transaction */
        public void begin(ReadWrite readWrite) {
            vd.begin(readWrite);
        }

        @Override
        public boolean promote(Promote promote) {
            return vd.promote(promote);
        }

        /** Commit a transaction - finish the transaction and make any changes permanent (if a "write" transaction) */  
        public void commit() {
            vd.commit();
        }
    
        /** Abort a transaction - finish the transaction and undo any changes (if a "write" transaction) */  
        public void abort() {
            vd.abort();
        }

        /** Finish the transaction - if a write transaction and commit() has not been called, then abort */  
        public void end() {
            vd.end();
        }

        @Override
        public ReadWrite transactionMode() {
            return vd.transactionMode();
        }

        @Override
        public TxnType transactionType() {
            return vd.transactionType();
        }


    }

}
