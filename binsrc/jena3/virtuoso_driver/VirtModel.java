/*
 *  $Id:$
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


import java.io.InputStream;
import java.io.Reader;
import java.util.Arrays;
import java.util.Iterator;
import java.util.List;
import javax.sql.*;

import org.apache.jena.graph.*;
import org.apache.jena.graph.impl.*;
import org.apache.jena.rdf.model.Statement;
import org.apache.jena.shared.*;
import org.apache.jena.util.iterator.*;
import org.apache.jena.datatypes.*;
import org.apache.jena.rdf.model.*;
import org.apache.jena.rdf.model.impl.*;


import virtuoso.jdbc4.VirtuosoDataSource;

public class VirtModel extends ModelCom {

    private final Object lck_add = new Object();

    /**
     * @param base
     */
    public VirtModel(VirtGraph base) {
        super(base);
    }


    public static VirtModel openDefaultModel(ConnectionPoolDataSource ds) {
        return new VirtModel(new VirtGraph(ds));
    }

    public static VirtModel openDatabaseModel(String graphName,
                                              ConnectionPoolDataSource ds) {
        return new VirtModel(new VirtGraph(graphName, ds));
    }


    public static VirtModel openDefaultModel(DataSource ds) {
        return new VirtModel(new VirtGraph(ds));
    }

    public static VirtModel openDatabaseModel(String graphName,
                                              DataSource ds) {
        return new VirtModel(new VirtGraph(graphName, ds));
    }


    public static VirtModel openDefaultModel(String url, String user,
                                             String password) {
        return new VirtModel(new VirtGraph(url, user, password));
    }

    public static VirtModel openDatabaseModel(String graphName, String url,
                                              String user, String password) {
        return new VirtModel(new VirtGraph(graphName, url, user, password));
    }

    @Override
    public Model removeAll() {
        try {
            VirtGraph _graph = (VirtGraph) this.graph;
            _graph.clear();
        } catch (ClassCastException e) {
            super.removeAll();
        }
        return this;
    }


    public void createRuleSet(String ruleSetName, String uriGraphRuleSet) {
        ((VirtGraph) this.graph).createRuleSet(ruleSetName, uriGraphRuleSet);
    }


    public void removeRuleSet(String ruleSetName, String uriGraphRuleSet) {
        ((VirtGraph) this.graph).removeRuleSet(ruleSetName, uriGraphRuleSet);
    }

    public void setRuleSet(String _ruleSet) {
        ((VirtGraph) this.graph).setRuleSet(_ruleSet);
    }

    public void setSameAs(boolean _sameAs) {
        ((VirtGraph) this.graph).setSameAs(_sameAs);
    }


    public int getBatchSize() {
        return ((VirtGraph) this.graph).getBatchSize();
    }


    public void setBatchSize(int sz) {
        ((VirtGraph) this.graph).setBatchSize(sz);
    }


    public String getSparqlPrefix() {
        return ((VirtGraph) this.graph).getSparqlPrefix();
    }


    public void setSparqlPrefix(String val) {
        ((VirtGraph) this.graph).setSparqlPrefix(val);
    }

    /**
     * Get the insertBNodeAsURI state for connection
     */
    public boolean getInsertBNodeAsVirtuosoIRI() {
        return ((VirtGraph) this.graph).getInsertBNodeAsVirtuosoIRI();
    }


    /**
     * Set the insertBNodeAsURI state for connection(default false) 
     * 
     * @param v
     *        true - insert BNode as Virtuoso IRI
     *        false - insert BNode as Virtuoso Native BNode
     */
    public void setInsertBNodeAsVirtuosoIRI(boolean v) {
        ((VirtGraph) this.graph).setInsertBNodeAsVirtuosoIRI(v);
    }


    /**
     * Get the resetBNodesDictAfterCall state for connection
     */
    public boolean getResetBNodesDictAfterCall() {
        return ((VirtGraph) this.graph).getResetBNodesDictAfterCall();
    }

    /**
     * Set the resetBNodesDictAfterCall (reset server side BNodes Dictionary,
     * that is used for map between Jena Bnodes and Virtuoso BNodes, after each
     * add call). The default state for connection is false 
     * 
     * @param v
     *        true  - reset BNodes Dictionary after each add(add batch) call
     *        false - not reset BNode Dictionary after each add(add batch) call
     */
    public void setResetBNodesDictAfterCall(boolean v) {
        ((VirtGraph) this.graph).setResetBNodesDictAfterCall(v);
    }


    /**
     * Get the resetBNodesDictAfterCommit state for connection
     */
    public boolean getResetBNodesDictAfterCommit() {
        return ((VirtGraph) this.graph).getResetBNodesDictAfterCommit();
    }

    /**
     * Set the resetBNodesDictAfterCommit (reset server side BNodes Dictionary,
     * that is used for map between Jena Bnodes and Virtuoso BNodes, 
     * after commit/rollback).
     * The default state for connection is true 
     * 
     * @param v
     *        true  - reset BNodes Dictionary after each commit/rollack
     *        false - not reset BNode Dictionary after each commit/rollback
     */
    public void setResetBNodesDictAfterCommit(boolean v) {
        ((VirtGraph) this.graph).setResetBNodesDictAfterCommit(v);
    }




    @Override
    public Model read(String url) {
        VirtGraph g = (VirtGraph)getGraph();
        synchronized (lck_add){
            g.startBatchAdd();
            Model ret = super.read(url);
            g.stopBatchAdd();
            return ret;
        }
    }

    @Override
    public Model read(Reader reader, String base) {
        VirtGraph g = (VirtGraph)getGraph();
        synchronized (lck_add){
            g.startBatchAdd();
            Model ret = super.read(reader, base);
            g.stopBatchAdd();
            return ret;
        }
    }

    @Override
    public Model read(InputStream reader, String base) {
        VirtGraph g = (VirtGraph)getGraph();
        synchronized (lck_add){
            g.startBatchAdd();
            Model ret = super.read(reader, base);
            g.stopBatchAdd();
            return ret;
        }
    }

    @Override
    public Model read(String url, String lang) {
        VirtGraph g = (VirtGraph)getGraph();
        synchronized (lck_add){
            g.startBatchAdd();
            Model ret = super.read(url, lang);
            g.stopBatchAdd();
            return ret;
        }
    }

    @Override
    public Model read(String url, String base, String lang) {
        VirtGraph g = (VirtGraph)getGraph();
        synchronized (lck_add){
            g.startBatchAdd();
            Model ret = super.read(url, base, lang);
            g.stopBatchAdd();
            return ret;
        }
    }

    @Override
    public Model read(Reader reader, String base, String lang) {
        VirtGraph g = (VirtGraph)getGraph();
        synchronized (lck_add){
            g.startBatchAdd();
            Model ret = super.read(reader, base, lang);
            g.stopBatchAdd();
            return ret;
        }
    }

    @Override
    public Model read(InputStream reader, String base, String lang) {
        VirtGraph g = (VirtGraph)getGraph();
        synchronized (lck_add){
            g.startBatchAdd();
            Model ret = super.read(reader, base, lang);
            g.stopBatchAdd();
            return ret;
        }
    }


    public Model add(Statement[] statements) {
        return add(Arrays.asList(statements).iterator());
    }

    @Override
    public Model add(List<Statement> statements) {
        return add(statements.iterator());
    }

    @Override
    public Model add(StmtIterator iter) {
        return add((Iterator<Statement>) iter);
    }

    protected Model add(Iterator<Statement> it) {
        VirtGraph _g = (VirtGraph) this.graph;
        _g.add(_g.getGraphName(), it);
        return this;
    }

    @Override
    public Model add(Model m) {
        return add(m.listStatements());
    }


    @Override
    public Model remove(Statement[] statements) {
        return remove(Arrays.asList(statements).iterator());
    }

    @Override
    public Model remove(List<Statement> statements) {
        return remove(statements.iterator());
    }

    protected Model remove(Iterator<Statement> it) {
        VirtGraph _g = (VirtGraph) this.graph;
        _g.delete(_g.getGraphName(), it);
        return this;
    }

    @Override
    public Model remove(Model m)
    {
        VirtGraph _g = (VirtGraph) this.graph;
        _g.md_delete_Model(m.listStatements());
        return this;
    }

}
