/*
 *  $Id:$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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

import org.apache.jena.atlas.json.JsonArray;
import org.apache.jena.atlas.json.JsonObject;
/**
import org.apache.jena.atlas.json.JsonValue;
import org.apache.jena.sparql.lib.RDFTerm2Json;
**/
import virtuoso.sql.*;

import org.apache.jena.graph.NodeFactory;
import org.apache.jena.shared.*;
import org.apache.jena.query.Query;
import org.apache.jena.query.ResultSet;
import org.apache.jena.query.Dataset;
import org.apache.jena.query.QueryExecution;

import org.apache.jena.rdf.model.RDFNode;
import org.apache.jena.graph.Node;
import org.apache.jena.graph.Triple;
import org.apache.jena.graph.Graph ;
import org.apache.jena.rdf.model.*;

import org.apache.jena.sparql.core.DatasetGraph;
import org.apache.jena.sparql.core.Quad;
import org.apache.jena.sparql.engine.binding.BindingFactory;
import org.apache.jena.sparql.engine.binding.Binding;
import org.apache.jena.sparql.engine.binding.BindingMap;
import org.apache.jena.sparql.engine.ResultSetStream;
import org.apache.jena.sparql.engine.QueryIterator;
import org.apache.jena.sparql.engine.iterator.QueryIterConcat;
import org.apache.jena.sparql.engine.http.QueryEngineHTTP;
import org.apache.jena.sparql.engine.iterator.QueryIterSingleton;
import org.apache.jena.sparql.engine.iterator.QueryIteratorResultSet;
import org.apache.jena.sparql.core.Var;
import org.apache.jena.sparql.core.ResultBinding;
import org.apache.jena.sparql.util.Context;
import org.apache.jena.sparql.util.ModelUtils;
import org.apache.jena.util.FileManager;
import org.apache.jena.query.*;

import java.util.concurrent.TimeUnit;

import virtuoso.jdbc4.VirtuosoConnectionPoolDataSource;

public class VirtuosoQueryExecution implements QueryExecution {
    private QueryIterConcat output = null;
    private String virt_graph = null;
    private VirtGraph graph;
    private String virt_query;
    private QuerySolution m_arg = null;
    private Context m_context = new Context();
    private Query mj_query = null;
    protected long timeout = -1;

    private java.sql.Statement stmt = null;


    public VirtuosoQueryExecution(Query query, VirtGraph _graph) {
        this(query.toString(), _graph);
        mj_query = query;
    }

    public VirtuosoQueryExecution(String query, VirtGraph _graph) {
        graph = _graph;
        virt_graph = graph.getGraphName();
        virt_query = query;
    }


    public ResultSet execSelect() {
        ResultSet ret = null;

        try {
            stmt = graph.createStatement(false);
            if (timeout > 0)
                stmt.setQueryTimeout((int) (timeout / 1000));
            java.sql.ResultSet rs = stmt.executeQuery(getVosQuery());

            return new VResultSet(graph, stmt, rs);
        } catch (Exception e) {
            throw new JenaException("Can not create ResultSet.:" + e);
        }
    }


    public void setFileManager(FileManager arg) {
        throw new JenaException("UnsupportedMethodException");
    }


    public void setInitialBinding(QuerySolution arg) {
        m_arg = arg;
    }

    public Dataset getDataset() {
        return new VirtDataset(graph);
    }


    public Context getContext() {
        return m_context;
    }

    public Query getQuery() {
        if (mj_query == null) {
            try {
                mj_query = QueryFactory.create(virt_query);
            } catch (Exception e) {
            }
        }
        return mj_query;
    }


    /**
     * Execute a CONSTRUCT query, returning the results as an iterator of {@link Quad}.
     * <p>
     * <b>Caution:</b> This method may return duplicate Quads.  This method may be useful if you only
     * need the results for stream processing, as it can avoid having to place the results in a Model.
     * </p>
     * @return An iterator of Quad objects (possibly containing duplicates) generated
     * by applying the CONSTRUCT template of the query to the bindings in the WHERE clause.
     * </p>
     * <p>
     * See {@link #execConstructTriples} for usage and features.
     */
    public Iterator<Quad> execConstructQuads() {
        throw new JenaException("execConstructQuads isn't supported.");
//??todo
/*** we don't support return Quad else
        try {
            stmt = graph.createStatement();
            if (timeout > 0)
                stmt.setQueryTimeout((int) (timeout / 1000));
            java.sql.ResultSet rs = stmt.executeQuery(getVosQuery());
            return new VirtResSetIter3(graph, stmt, rs);

        } catch (Exception e) {
            throw new JenaException("execConstructQuads has FAILED.:" + e);
        }
***/
    }


    /** Execute a CONSTRUCT query, putting the statements into 'dataset'.
     *  This maybe an exetended synatx query (if supported).
     */
    public Dataset execConstructDataset() {
        return execConstructDataset(DatasetFactory.create()) ;
    }

    /** Execute a CONSTRUCT query, putting the statements into 'dataset'.
     *  This maybe an exetended synatx query (if supported).
     */
    public Dataset execConstructDataset(Dataset dataset) {
//??todo
/***** we don't support return Quad else
        DatasetGraph dsg = dataset.asDatasetGraph() ;
        try {
            execConstructQuads().forEachRemaining(dsg::add);
//??todo            insertPrefixesInto(dataset);
        } finally {
            this.close();
        }
        return dataset ;
*****/
        DatasetGraph dsg = dataset.asDatasetGraph() ;
        Graph g = dsg.getDefaultGraph();
        try {
            for(Iterator<Triple> it = execConstructTriples(); it.hasNext(); )
              g.add(it.next());
        } finally {
            this.close();
        }
        return dataset ;
    }



    public Model execConstruct() {
        return execConstruct(ModelFactory.createDefaultModel());
    }


    public Model execConstruct(Model model) {
        try {
            stmt = graph.createStatement(false);
            if (timeout > 0)
                stmt.setQueryTimeout((int) (timeout / 1000));
            java.sql.ResultSet rs = stmt.executeQuery(getVosQuery());
            ResultSetMetaData rsmd = rs.getMetaData();

            while (rs.next()) {
                Node s = VirtGraph.Object2Node(rs.getObject(1));
                Node p = VirtGraph.Object2Node(rs.getObject(2));
                Node o = VirtGraph.Object2Node(rs.getObject(3));
                org.apache.jena.rdf.model.Statement st = ModelUtils.tripleToStatement(model, new Triple(s, p, o));
                if (st != null)
                    model.add(st);
            }
            rs.close();
            stmt.close();
            stmt = null;

        } catch (Exception e) {
            throw new JenaException("Convert results has FAILED.:" + e);
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
    public Iterator<Triple> execConstructTriples() {
        try {
            stmt = graph.createStatement(false);
            if (timeout > 0)
                stmt.setQueryTimeout((int) (timeout / 1000));
            java.sql.ResultSet rs = stmt.executeQuery(getVosQuery());
            return new VirtResSetIter2(graph, stmt, rs);

        } catch (Exception e) {
            throw new JenaException("execConstructTriples has FAILED.:" + e);
        }
    }


    public Model execDescribe() {
        return execDescribe(ModelFactory.createDefaultModel());
    }

    public Model execDescribe(Model model) {
        try {
            stmt = graph.createStatement(false);
            if (timeout > 0)
                stmt.setQueryTimeout((int) (timeout / 1000));
            java.sql.ResultSet rs = stmt.executeQuery(getVosQuery());
            ResultSetMetaData rsmd = rs.getMetaData();
            while (rs.next()) {
                Node s = VirtGraph.Object2Node(rs.getObject(1));
                Node p = VirtGraph.Object2Node(rs.getObject(2));
                Node o = VirtGraph.Object2Node(rs.getObject(3));

                org.apache.jena.rdf.model.Statement st = ModelUtils.tripleToStatement(model, new Triple(s, p, o));
                if (st != null)
                    model.add(st);
            }
            rs.close();
            stmt.close();
            stmt = null;

        } catch (Exception e) {
            throw new JenaException("Convert results are FAILED.:" + e);
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
    public Iterator<Triple> execDescribeTriples() {
        try {
            stmt = graph.createStatement(false);
            if (timeout > 0)
                stmt.setQueryTimeout((int) (timeout / 1000));
            java.sql.ResultSet rs = stmt.executeQuery(getVosQuery());
            return new VirtResSetIter2(graph, stmt, rs);

        } catch (Exception e) {
            throw new JenaException("execDescribeTriples has FAILED.:" + e);
        }
    }


    public boolean execAsk() {
        boolean ret = false;

        try {
            stmt = graph.createStatement(false);
            if (timeout > 0)
                stmt.setQueryTimeout((int) (timeout / 1000));
            java.sql.ResultSet rs = stmt.executeQuery(getVosQuery());
            ResultSetMetaData rsmd = rs.getMetaData();

            while (rs.next()) {
                if (rs.getInt(1) == 1)
                    ret = true;
            }
            rs.close();
            stmt.close();
            stmt = null;

        } catch (Exception e) {
            throw new JenaException("Convert results has FAILED.:" + e);
        }
        return ret;
    }

    @Override
    public JsonArray execJson() {
        throw new JenaException("Unsupported Operation");
/*** checkme
        JsonArray jsonArray = new JsonArray() ;
        try {
            stmt = graph.createStatement(false);
            if (timeout > 0)
                stmt.setQueryTimeout((int) (timeout / 1000));
            java.sql.ResultSet rs = stmt.executeQuery(getVosQuery());

            VResultSet vrs = new VResultSet(graph, stmt, rs);

            List<String> resultVars = vrs.getResultVars();
            while(vrs.hasNext())
            {
                Binding binding = vrs.nextBinding();
                JsonObject jsonObject = new JsonObject() ;
                for (String resultVar : resultVars) {
                    Node n = binding.get(Var.alloc(resultVar)) ;
                    JsonValue value = RDFTerm2Json.fromNode(n) ;
                    jsonObject.put(resultVar, value) ;
                }
                jsonArray.add(jsonObject) ;
            }
            return jsonArray;
        } catch (Exception e) {
            throw new JenaException("Can not create ResultSet.:" + e);
        }
 ***/
    }


    @Override
    public Iterator<JsonObject> execJsonItems() {
        throw new JenaException("Unsupported Operation");
    }


    public void abort() {
        if (stmt != null)
            try {
                stmt.cancel();
            } catch (Exception e) {
            }
    }


    public void close() {
        if (stmt != null)
            try {
                stmt.cancel();
                stmt.close();
            } catch (Exception e) {
            }
    }

    public boolean isClosed() {
        return stmt == null;
    }


    /**
     * Set a timeout on the query execution.
     * Processing will be aborted after the timeout (which starts when the approprate exec call is made).
     * Not all query execution systems support timeouts.
     * A timeout of less than zero means no timeout.
     */

    public void setTimeout(long timeout, TimeUnit timeoutUnits) {
        this.timeout = timeout;

    }

    /**
     * Set time, in milliseconds
     *
     * @see #setTimeout(long, TimeUnit)
     */
    public void setTimeout(long timeout) {
        this.timeout = timeout;
    }

    /**
     * Set timeouts on the query execution; the first timeout refers to time to first result,
     * the second refers to overall query execution after the first result.
     * Processing will be aborted if a timeout expires.
     * Not all query execution systems support timeouts.
     * A timeout of less than zero means no timeout; this can be used for timeout1 or timeout2.
     */

    public void setTimeout(long timeout1, TimeUnit timeUnit1, long timeout2, TimeUnit timeUnit2) {
        this.timeout = timeout1;
    }

    /**
     * Set time, in milliseconds
     *
     * @see #setTimeout(long, TimeUnit, long, TimeUnit)
     */
    public void setTimeout(long timeout1, long timeout2) {
        this.timeout = timeout1;
    }


    /**
     * Return the first timeout (time to first result), in millseconds: negative if unset
     */
    public long getTimeout1() {
        return timeout;
    }

    /**
     * Return the second timeout (overall query execution after first result), in millseconds: negative if unset
     */
    public long getTimeout2() {
        return -1L;
    }

    private String substBindings(String query) {
        if (m_arg == null)
            return query;

        StringBuffer buf = new StringBuffer();
        String delim = " ,)(;.}{";
        int i = 0;
        char ch;
        int qlen = query.length();
        while (i < qlen) {
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
            } else if (ch == '?') {  //Parameter
                String varData = null;
                int j = i;
                while (j < qlen && delim.indexOf(query.charAt(j)) < 0) j++;
                if (j != i) {
                    String varName = query.substring(i, j);
                    RDFNode val = m_arg.get(varName);
                    if (val != null) {
                        varData = graph.Node2Str(val.asNode());
                        i = j;
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


    private String getVosQuery() {
        StringBuilder sb = new StringBuilder("sparql\n ");

        graph.appendSparqlPrefixes(sb, true);

        if (!graph.getReadFromAllGraphs())
            sb.append(" define input:default-graph-uri <" + graph.getGraphName() + "> \n");

        sb.append(substBindings(virt_query));

        return sb.toString();
    }


    ///=== Inner class ===========================================
    public class VResultSet implements org.apache.jena.query.ResultSet {
        java.sql.Statement stmt;
        ResultSetMetaData rsmd;
        java.sql.ResultSet rs;
        boolean v_finished = false;
        boolean v_prefetched = false;
        VirtModel m;
        BindingMap v_row;
        List<String> resVars = new LinkedList();
        int row_id = 0;


        protected VResultSet(VirtGraph _g, java.sql.Statement _stmt, java.sql.ResultSet _rs) {
            stmt = _stmt;
            rs = _rs;
            m = new VirtModel(_g);

            try {
                rsmd = rs.getMetaData();
                for (int i = 1; i <= rsmd.getColumnCount(); i++)
                    resVars.add(rsmd.getColumnLabel(i));

                if (virt_graph != null && !virt_graph.equals("virt:DEFAULT"))
                    resVars.add("graph");
            } catch (Exception e) {
                throw new JenaException("ViruosoResultBindingsToJenaResults has FAILED.:" + e);
            }
        }

        public boolean hasNext() {
            if (!v_finished && !v_prefetched)
                moveForward();
            return !v_finished;
        }

        public QuerySolution next() {
            Binding binding = nextBinding();

            if (v_finished)
                throw new NoSuchElementException();

            return new ResultBinding(m, binding);
        }

        public QuerySolution nextSolution() {
            return next();
        }

        public Binding nextBinding() {
            if (!v_finished && !v_prefetched)
                moveForward();

            v_prefetched = false;

            if (v_finished)
                throw new NoSuchElementException();

            return v_row;
        }

        public int getRowNumber() {
            return row_id;
        }

        public List<String> getResultVars() {
            return resVars;
        }

        public Model getResourceModel() {
            return m;
        }

        protected void finalize() throws Throwable {
            if (!v_finished)
                try {
                    close();
                } catch (Exception e) {
                }
        }

        protected void moveForward() throws JenaException {
            try {
                if (!v_finished && rs.next()) {
                    extractRow();
                    v_prefetched = true;
                } else
                    close();
            } catch (Exception e) {
                throw new JenaException("Convert results are FAILED.:" + e);
            }
        }

        protected void extractRow() throws Exception {
            v_row = BindingFactory.create();
            row_id++;

            try {
                for (int i = 1; i <= rsmd.getColumnCount(); i++) {
                    Node n = VirtGraph.Object2Node(rs.getObject(i));
                    if (n != null)
                        v_row.add(Var.alloc(rsmd.getColumnLabel(i)), n);
                }

                if (virt_graph != null && !virt_graph.equals("virt:DEFAULT"))
                    v_row.add(Var.alloc("graph"), NodeFactory.createURI(virt_graph));
            } catch (Exception e) {
                throw new JenaException("ViruosoResultBindingsToJenaResults has FAILED.:" + e);
            }
        }

        public void remove() throws java.lang.UnsupportedOperationException {
            throw new UnsupportedOperationException(this.getClass().getName() + ".remove");
        }

        private void close() {
            if (!v_finished) {
                if (rs != null) {
                    try {
                        rs.close();
                        rs = null;
                    } catch (Exception e) {
                    }
                }
                if (stmt != null) {
                    try {
                        stmt.close();
                        stmt = null;
                    } catch (Exception e) {
                    }
                }
            }
            v_finished = true;
        }


    }

}
