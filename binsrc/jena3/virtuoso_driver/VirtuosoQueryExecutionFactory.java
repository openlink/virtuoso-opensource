/*
 *  $Id:$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2022 OpenLink Software
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

import org.apache.jena.query.Query;
import org.apache.jena.query.QueryExecution;
import org.apache.jena.query.QueryFactory;
import org.apache.jena.query.QuerySolution;
import org.apache.jena.rdf.model.Model;
import org.apache.jena.query.Dataset;

import org.apache.jena.sparql.core.DatasetImpl;
import org.apache.jena.sparql.util.Context;

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

    static public QueryExecution create(Query query, VirtGraph graph, QuerySolution initialBinding) {
        checkArg(query);
        VirtuosoQueryExecution qe = new VirtuosoQueryExecution(query.toString(), graph);
        if (initialBinding != null)
            qe.setInitialBinding(initialBinding);
        return qe;
    }

    static public QueryExecution create(String query, VirtGraph graph, QuerySolution initialBinding) {
        checkArg(query);
        VirtuosoQueryExecution qe = new VirtuosoQueryExecution(query, graph);
        if (initialBinding != null)
            qe.setInitialBinding(initialBinding);
        return qe;
    }

    static public QueryExecution create(Query query, Dataset dataset, QuerySolution initialBinding) {
        checkArg(query);
        if (dataset instanceof VirtDataset) {
            VirtuosoQueryExecution qe = new VirtuosoQueryExecution(query.toString(), (VirtGraph) dataset);
            if (initialBinding != null)
                qe.setInitialBinding(initialBinding);
            return qe;
        } else {
            return make(query, dataset);
        }
    }

    static public QueryExecution create(String queryStr, Dataset dataset, QuerySolution initialBinding) {
        checkArg(queryStr);
        if (dataset instanceof VirtDataset) {
            VirtuosoQueryExecution qe = new VirtuosoQueryExecution(queryStr, (VirtGraph) dataset);
            if (initialBinding != null)
                qe.setInitialBinding(initialBinding);
            return qe;
        } else {
            return make(makeQuery(queryStr), dataset);
        }
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

