/*
 *  $Id: VirtuosoQueryExecutionFactory.java,v 1.4.2.4 2012/03/08 12:55:00 source Exp $
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

import java.util.List;

import com.hp.hpl.jena.query.Query;
import com.hp.hpl.jena.query.QueryExecution;
import com.hp.hpl.jena.query.QueryFactory;
import com.hp.hpl.jena.query.QuerySolution;
import com.hp.hpl.jena.query.ResultSet;
import com.hp.hpl.jena.rdf.model.RDFNode;
import com.hp.hpl.jena.rdf.model.Model;
import com.hp.hpl.jena.util.FileManager;
import com.hp.hpl.jena.query.Dataset;

import com.hp.hpl.jena.sparql.engine.QueryEngineFactory;
import com.hp.hpl.jena.sparql.engine.QueryEngineRegistry;
import com.hp.hpl.jena.sparql.engine.http.QueryEngineHTTP;
import com.hp.hpl.jena.sparql.core.DatasetImpl;
import com.hp.hpl.jena.sparql.util.Context;

public class VirtuosoQueryExecutionFactory {

    private VirtuosoQueryExecutionFactory() {
    }

    static public VirtuosoQueryExecution create(Query query, VirtGraph graph) {
        VirtuosoQueryExecution ret = new VirtuosoQueryExecution(query, graph);
        return ret;
    }

    static public VirtuosoQueryExecution create(String query, VirtGraph graph) {
        VirtuosoQueryExecution ret = new VirtuosoQueryExecution(query, graph);
        return ret;
    }

/* TODO */

    static public QueryExecution create(Query query, Dataset dataset) {
        if (dataset instanceof VirtDataset) {
            VirtuosoQueryExecution ret = new VirtuosoQueryExecution(query.toString(), (VirtGraph) dataset);
            return ret;
        } else {
            return make(query, dataset);
        }
    }

    static public QueryExecution create(String queryStr, Dataset dataset) {
        if (dataset instanceof VirtDataset) {
            VirtuosoQueryExecution ret = new VirtuosoQueryExecution(queryStr, (VirtGraph) dataset);
            return ret;
        } else {
            return make(makeQuery(queryStr), dataset);
        }
    }

    /**
     * static public QueryExecution create(Query query, FileManager fm)
     * {
     * checkArg(query) ;
     * QueryExecution qe = make(query) ;
     * if ( fm != null )
     * qe.setFileManager(fm) ;
     * return qe ;
     * }
     * <p/>
     * static public QueryExecution create(String queryStr, FileManager fm)
     * {
     * checkArg(queryStr) ;
     * return create(makeQuery(queryStr), fm) ;
     * }
     */

    // ---------------- Query + Model
    static public QueryExecution create(Query query, Model model) {
        checkArg(query);
        checkArg(model);

        if (model.getGraph() instanceof VirtGraph) {
            VirtuosoQueryExecution ret = new VirtuosoQueryExecution(query.toString(), (VirtGraph) model.getGraph());
            return ret;
        } else {
            return make(query, new DatasetImpl(model));
        }
    }

    static public QueryExecution create(String queryStr, Model model) {
        checkArg(queryStr);
        checkArg(model);
        if (model.getGraph() instanceof VirtGraph) {
            VirtuosoQueryExecution ret = new VirtuosoQueryExecution(queryStr, (VirtGraph) model.getGraph());
            return ret;
        } else {
            return create(makeQuery(queryStr), model);
        }
    }

    static public QueryExecution create(Query query, QuerySolution initialBinding) {
        checkArg(query);
        QueryExecution qe = make(query);
        if (initialBinding != null)
            qe.setInitialBinding(initialBinding);
        return qe;
    }

    static public QueryExecution create(String queryStr, QuerySolution initialBinding) {
        checkArg(queryStr);
        return create(makeQuery(queryStr), initialBinding);
    }

    //??
    static public QueryExecution create(Query query, Dataset dataset, QuerySolution initialBinding) {
        checkArg(query);
        QueryExecution qe = make(query, dataset);
        if (initialBinding != null)
            qe.setInitialBinding(initialBinding);
        return qe;
    }

    //??
    static public QueryExecution create(String queryStr, Dataset dataset, QuerySolution initialBinding) {
        checkArg(queryStr);
        return create(makeQuery(queryStr), dataset, initialBinding);
    }

    // ---------------- Remote query execution

    static public QueryExecution sparqlService(String service, Query query) {
        checkNotNull(service, "URL for service is null");
        checkArg(query);
        return makeServiceRequest(service, query);
    }

    static public QueryExecution sparqlService(String service, Query query, String defaultGraph) {
        checkNotNull(service, "URL for service is null");
        //checkNotNull(defaultGraph, "IRI for default graph is null") ;
        checkArg(query);
        QueryEngineHTTP qe = makeServiceRequest(service, query);
        qe.addDefaultGraph(defaultGraph);
        return qe;
    }

    static public QueryExecution sparqlService(String service, Query query, List defaultGraphURIs,
                                               List namedGraphURIs) {
        checkNotNull(service, "URL for service is null");
        //checkNotNull(defaultGraphURIs, "List of default graph URIs is null") ;
        //checkNotNull(namedGraphURIs, "List of named graph URIs is null") ;
        checkArg(query);

        QueryEngineHTTP qe = makeServiceRequest(service, query);

        if (defaultGraphURIs != null)
            qe.setDefaultGraphURIs(defaultGraphURIs);
        if (namedGraphURIs != null)
            qe.setNamedGraphURIs(namedGraphURIs);
        return qe;
    }

    // ---------------- Internal routines

    // Make query

    static private Query makeQuery(String queryStr) {
        return QueryFactory.create(queryStr);
    }

    // ---- Make executions

    static private QueryExecution make(Query query) {
        return make(query, null);
    }

    static private QueryExecution make(Query query, Dataset dataset) {
        return make(query, dataset, null);
    }

    static private QueryExecution make(Query query, Dataset dataset, Context context) {
        return null;
    }

    static private QueryEngineHTTP makeServiceRequest(String service, Query query) {
        return new QueryEngineHTTP(service, query);
    }

    static private void checkNotNull(Object obj, String msg) {
        if (obj == null)
            throw new IllegalArgumentException(msg);
    }

    static private void checkArg(Model model) {
        checkNotNull(model, "Model is a null pointer");
    }

    static private void checkArg(String queryStr) {
        checkNotNull(queryStr, "Query string is null");
    }

    static private void checkArg(Query query) {
        checkNotNull(query, "Query is null");
    }
}

