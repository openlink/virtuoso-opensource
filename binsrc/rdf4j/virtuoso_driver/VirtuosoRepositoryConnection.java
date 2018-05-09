/*
 *  $Id$
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
package virtuoso.rdf4j.driver;

import org.eclipse.rdf4j.common.iteration.CloseableIteration;
import org.eclipse.rdf4j.common.iteration.CloseableIteratorIteration;
import org.eclipse.rdf4j.common.iteration.Iteration;
import org.eclipse.rdf4j.common.iteration.Iterations;
import org.eclipse.rdf4j.IsolationLevel;
import org.eclipse.rdf4j.IsolationLevels;
import org.eclipse.rdf4j.OpenRDFUtil;
import org.eclipse.rdf4j.model.*;
import org.eclipse.rdf4j.model.Statement;
import org.eclipse.rdf4j.model.impl.SimpleNamespace;
import org.eclipse.rdf4j.model.vocabulary.XMLSchema;
import org.eclipse.rdf4j.query.*;
import org.eclipse.rdf4j.query.algebra.evaluation.QueryBindingSet;
import org.eclipse.rdf4j.query.impl.IteratingGraphQueryResult;
import org.eclipse.rdf4j.query.impl.IteratingTupleQueryResult;
import org.eclipse.rdf4j.repository.*;
import org.eclipse.rdf4j.rio.*;

import java.io.*;
import java.net.URL;
import java.sql.*;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.*;

import org.eclipse.rdf4j.rio.helpers.AbstractRDFHandler;
import org.eclipse.rdf4j.rio.helpers.ParseErrorLogger;
import virtuoso.jdbc4.VirtuosoResultSet;
import virtuoso.sql.ExtendedString;
import virtuoso.sql.RdfBox;
import virtuoso.jdbc4.VirtuosoDate;
import virtuoso.jdbc4.VirtuosoTime;
import virtuoso.jdbc4.VirtuosoTimestamp;

/**
 * Main interface for updating data in and performing queries on a Sesame
 * repository. By default, a RepositoryConnection is in autoCommit mode, meaning
 * that each operation corresponds to a single transaction on the underlying
 * store. autoCommit can be switched off in which case it is up to the user to
 * handle transaction commit/rollback. Note that care should be taking to always
 * properly close a RepositoryConnection after one is finished with it, to free
 * up resources and avoid unnecessary locks.
 * <p>
 * Several methods take a vararg argument that optionally specifies a (set of)
 * context(s) on which the method should operate. Note that a vararg parameter
 * is optional, it can be completely left out of the method call, in which case
 * a method either operates on a provided statements context (if one of the
 * method parameters is a statement or collection of statements), or operates on
 * the repository as a whole, completely ignoring context. A vararg argument may
 * also be 'null' (cast to Resource) meaning that the method operates on those
 * statements which have no associated context only.
 * <p>
 * Examples:
 *
 * <pre>
 * // Ex 1: this method retrieves all statements that appear in either context1 or context2, or both.
 * RepositoryConnection.getStatements(null, null, null, true, context1, context2);
 *
 * // Ex 2: this method retrieves all statements that appear in the repository (regardless of context).
 * RepositoryConnection.getStatements(null, null, null, true);
 *
 * // Ex 3: this method retrieves all statements that have no associated context in the repository.
 * // Observe that this is not equivalent to the previous method call.
 * RepositoryConnection.getStatements(null, null, null, true, (Resource)null);
 *
 * // Ex 4: this method adds a statement to the store. If the statement object itself has
 * // a context (i.e. statement.getContext() != null) the statement is added to that context. Otherwise,
 * // it is added without any associated context.
 * RepositoryConnection.add(statement);
 *
 * // Ex 5: this method adds a statement to context1 in the store. It completely ignores any
 * // context the statement itself has.
 * RepositoryConnection.add(statement, context1);
 * </pre>
 *
 */
public class VirtuosoRepositoryConnection implements RepositoryConnection {

    private Resource nilContext;
    private Connection quadStoreConnection;
    protected VirtuosoRepository repository;
    static final String S_DELETE = "sparql delete from graph iri(??) {`iri(??)` `iri(??)` `bif:__rdf_long_from_batch_params(??,??,??)`}";
    static final String S_BATCH_INSERT = "DB.DBA.rdf_insert_triple_c (?,?,?,?,?,?)";
    static final String S_CLEAR_GRAPH = "DB.DBA.rdf_clear_graphs_c (?)";

    static final String S_TTLP_INSERT = "DB.DBA.TTLP_MT (?, '', ?, 255, 2, 3, ?)";

    static final int MAX_CMD_SIZE = 36000;

    private int BATCH_SIZE = 5000;
    private PreparedStatement psInsert;
    private PreparedStatement psInsert_BNode;
    private int psInsertCount = 0;
    private int psInsertBNodeCount = 0;

    private boolean useLazyAdd = false;
    private int prefetchSize = 100;
    private boolean useReprepare = true;
    private boolean insertBNodeAsVirtuosoIRI = false;
    private ValueFactory valueFactory = null;
    private boolean insertStringLiteralAsSimple = false;
    private int queryTimeout = 0;
    private String ruleSet;    
    private String macroLib;
    private String defGraph;
    private boolean useDefGraphForQueries;

    private volatile ParserConfig parserConfig = new ParserConfig();
    private IsolationLevel isolationLevel;
    private int concurencyMode;
    private int trn_concurrencyMode;

    public VirtuosoRepositoryConnection(VirtuosoRepository repository, Connection connection) throws RepositoryException {
        this.quadStoreConnection = connection;
        this.repository = repository;
        this.useLazyAdd = repository.useLazyAdd;
        this.prefetchSize = repository.prefetchSize;
        this.BATCH_SIZE = repository.batchSize;
        this.insertBNodeAsVirtuosoIRI = repository.insertBNodeAsVirtuosoIRI;
        this.insertStringLiteralAsSimple = repository.insertStringLiteralAsSimple;
        this.valueFactory = repository.getValueFactory();
        this.queryTimeout = repository.getQueryTimeout();
        this.ruleSet = repository.getRuleSet();
        this.macroLib = repository.getMacroLib();
        this.defGraph = repository.defGraph;
	this.useDefGraphForQueries = repository.useDefGraphForQueries;
        this.trn_concurrencyMode = this.concurencyMode = repository.concurencyMode;
        this.nilContext = valueFactory.createIRI(repository.defGraph);
        this.repository.initialize();

        try {
            virtuoso.jdbc4.Driver drv = new virtuoso.jdbc4.Driver();
            if (drv.getMajorVersion()>=3 && drv.getMinorVersion()>=72)
                useReprepare = false;
        } catch(Exception e) {}
    }



    /**
     * Returns the Repository object to which this connection belongs.
     */
    public Repository getRepository() {
        return repository;
    }


    /**
     * Set the parser configuration this connection should use for
     * RDFParser-based operations.
     *
     * @param parserConfig
     *        a Rio RDF Parser configuration.
     */
    public void setParserConfig(ParserConfig parserConfig) {
        this.parserConfig = parserConfig;
    }

    /**
     * Returns the parser configuration this connection uses for Rio-based
     * operations.
     *
     * @return a Rio RDF parser configuration.
     */
    public ParserConfig getParserConfig() {
        return parserConfig;
    }

    /**
     * Gets a ValueFactory for this RepositoryConnection.
     *
     * @return A repository-specific ValueFactory.
     */
    public ValueFactory getValueFactory() {
        return valueFactory;
    }

    /**
     * Checks whether this connection is open. A connection is open from the moment it is created until it is closed.
     *
     * @see #close()
     */
    public boolean isOpen() throws RepositoryException {
        try {
            return !this.getQuadStoreConnection().isClosed();
        }
        catch (SQLException e) {
            throw new RepositoryException("Problem inspecting connection", e);
        }
    }

    /**
     * Closes the connection, freeing resources. If the connection is not in
     * autoCommit mode, all non-committed operations will be lost.
     *
     * @throws RepositoryException
     *         If the connection could not be closed.
     */
    public void close() throws RepositoryException {
        try {
            if (!getQuadStoreConnection().isClosed()) {
                getQuadStoreConnection().close();
            }
        }
        catch (SQLException e) {
            throw new RepositoryException(e);
        }
    }


    /**
     * Prepares a query for evaluation on this repository (optional operation).
     * In case the query contains relative URIs that need to be resolved against
     * an external base URI, one should use
     * {@link #prepareQuery(QueryLanguage, String, String)} instead.
     *
     * @param ql
     *        The query language in which the query is formulated.
     * @param query
     *        The query string.
     * @return A query ready to be evaluated on this repository.
     * @throws MalformedQueryException
     *         If the supplied query is malformed.
     * @throws UnsupportedQueryLanguageException
     *         If the supplied query language is not supported.
     * @throws UnsupportedOperationException
     *         If the <tt>prepareQuery</tt> method is not supported by this
     *         repository.
     */
    public Query prepareQuery(QueryLanguage ql, String query) throws RepositoryException, MalformedQueryException {
        return prepareQuery(ql, query, null);
    }

    /**
     * Prepares a query for evaluation on this repository (optional operation).
     *
     * @param ql
     *        The query language in which the query is formulated.
     * @param query
     *        The query string.
     * @param baseURI
     *        The base URI to resolve any relative URIs that are in the query
     *        against, can be <tt>null</tt> if the query does not contain any
     *        relative URIs.
     * @return A query ready to be evaluated on this repository.
     * @throws MalformedQueryException
     *         If the supplied query is malformed.
     * @throws UnsupportedQueryLanguageException
     *         If the supplied query language is not supported.
     * @throws UnsupportedOperationException
     *         If the <tt>prepareQuery</tt> method is not supported by this
     *         repository.
     */
    public Query prepareQuery(QueryLanguage ql, String query, String baseURI) throws RepositoryException, MalformedQueryException {
        if (ql != QueryLanguage.SPARQL)
            throw new UnsupportedQueryLanguageException(" : Only SPARQL queries are supported");

        StringTokenizer st = new StringTokenizer(query);
        String type = null;

        while(st.hasMoreTokens()) {
            type = st.nextToken().toLowerCase();
            if (type.equals("select"))
                break;
            else if(type.equals("construct") || type.equals("describe"))
                break;
            else if(type.equals("ask"))
                break;
        }

        flushDelayAdd();
        if(type==null || type.equals("select"))
            return prepareTupleQuery(ql, query, baseURI);
        else if(type.equals("construct") || type.equals("describe"))
            return prepareGraphQuery(ql, query, baseURI);
        else if(type.equals("ask"))
            return prepareBooleanQuery(ql, query, baseURI);
        else
            return new VirtuosoQuery();
    }

    /**
     * Prepares a query that produces sets of value tuples. In case the query
     * contains relative URIs that need to be resolved against an external base
     * URI, one should use
     * {@link #prepareTupleQuery(QueryLanguage, String, String)} instead.
     *
     * @param ql
     *        The query language in which the query is formulated.
     * @param query
     *        The query string.
     * @throws IllegalArgumentException
     *         If the supplied query is not a tuple query.
     * @throws MalformedQueryException
     *         If the supplied query is malformed.
     * @throws UnsupportedQueryLanguageException
     *         If the supplied query language is not supported.
     */
    public TupleQuery prepareTupleQuery(QueryLanguage ql, String query) throws RepositoryException, MalformedQueryException {
        return prepareTupleQuery(ql, query, null);
    }

    /**
     * Prepares a query that produces sets of value tuples.
     *
     * @param ql
     *        The query language in which the query is formulated.
     * @param query
     *        The query string.
     * @param baseURI
     *        The base URI to resolve any relative URIs that are in the query
     *        against, can be <tt>null</tt> if the query does not contain any
     *        relative URIs.
     * @throws IllegalArgumentException
     *         If the supplied query is not a tuple query.
     * @throws MalformedQueryException
     *         If the supplied query is malformed.
     * @throws UnsupportedQueryLanguageException
     *         If the supplied query language is not supported.
     */
    public TupleQuery prepareTupleQuery(QueryLanguage ql, final String query, final String baseURI) throws RepositoryException, MalformedQueryException {
        if (ql != QueryLanguage.SPARQL)
            throw new UnsupportedQueryLanguageException(" : Only SPARQL queries are supported");

        return new VirtuosoTupleQuery() {
            public TupleQueryResult evaluate() throws QueryEvaluationException {
                return executeSPARQLForTupleResult(baseURI, query, getDataset(), getIncludeInferred(), getBindings(), getMaxExecutionTime());
            }

            public void evaluate(TupleQueryResultHandler handler) throws QueryEvaluationException, TupleQueryResultHandlerException {
                executeSPARQLForHandler(baseURI, handler, query, getDataset(), getIncludeInferred(), getBindings(), getMaxExecutionTime());
            }
        };
    }

    /**
     * Prepares queries that produce RDF graphs. In case the query contains
     * relative URIs that need to be resolved against an external base URI, one
     * should use {@link #prepareGraphQuery(QueryLanguage, String, String)}
     * instead.
     *
     * @param ql
     *        The query language in which the query is formulated.
     * @param query
     *        The query string.
     * @throws IllegalArgumentException
     *         If the supplied query is not a graph query.
     * @throws MalformedQueryException
     *         If the supplied query is malformed.
     * @throws UnsupportedQueryLanguageException
     *         If the supplied query language is not supported.
     */
    public GraphQuery prepareGraphQuery(QueryLanguage ql, String query) throws RepositoryException, MalformedQueryException {
        return prepareGraphQuery(ql, query, null);
    }

    /**
     * Prepares queries that produce RDF graphs.
     *
     * @param ql
     *        The query language in which the query is formulated.
     * @param query
     *        The query string.
     * @param baseURI
     *        The base URI to resolve any relative URIs that are in the query
     *        against, can be <tt>null</tt> if the query does not contain any
     *        relative URIs.
     * @throws IllegalArgumentException
     *         If the supplied query is not a graph query.
     * @throws MalformedQueryException
     *         If the supplied query is malformed.
     * @throws UnsupportedQueryLanguageException
     *         If the supplied query language is not supported.
     */
    public GraphQuery prepareGraphQuery(QueryLanguage ql, final String query, final String baseURI) throws RepositoryException, MalformedQueryException {
        if (ql != QueryLanguage.SPARQL)
            throw new UnsupportedQueryLanguageException(" : Only SPARQL queries are supported");

        return new VirtuosoGraphQuery() {
            public GraphQueryResult evaluate() throws QueryEvaluationException {
                return executeSPARQLForGraphResult(baseURI, query, getDataset(), getIncludeInferred(), getBindings(), getMaxExecutionTime());
            }

            public void evaluate(RDFHandler handler) throws QueryEvaluationException, RDFHandlerException {
                executeSPARQLForHandler(baseURI, handler, query, getDataset(), getIncludeInferred(), getBindings(), getMaxExecutionTime());
            }
        };
    }

    /**
     * Prepares <tt>true</tt>/<tt>false</tt> queries. In case the query
     * contains relative URIs that need to be resolved against an external base
     * URI, one should use
     * {@link #prepareBooleanQuery(QueryLanguage, String, String)} instead.
     *
     * @param ql
     *        The query language in which the query is formulated.
     * @param query
     *        The query string.
     * @throws IllegalArgumentException
     *         If the supplied query is not a boolean query.
     * @throws MalformedQueryException
     *         If the supplied query is malformed.
     * @throws UnsupportedQueryLanguageException
     *         If the supplied query language is not supported.
     */
    public BooleanQuery prepareBooleanQuery(QueryLanguage ql, String query) throws RepositoryException, MalformedQueryException {
        return prepareBooleanQuery(ql, query, null);
    }

    /**
     * Prepares <tt>true</tt>/<tt>false</tt> queries.
     *
     * @param ql
     *        The query language in which the query is formulated.
     * @param query
     *        The query string.
     * @param baseURI
     *        The base URI to resolve any relative URIs that are in the query
     *        against, can be <tt>null</tt> if the query does not contain any
     *        relative URIs.
     * @throws IllegalArgumentException
     *         If the supplied query is not a boolean query.
     * @throws MalformedQueryException
     *         If the supplied query is malformed.
     * @throws UnsupportedQueryLanguageException
     *         If the supplied query language is not supported.
     */
    public BooleanQuery prepareBooleanQuery(QueryLanguage ql, final String query, final String baseURI) throws RepositoryException, MalformedQueryException {
        if (ql != QueryLanguage.SPARQL)
            throw new UnsupportedQueryLanguageException(" : Only SPARQL queries are supported");

        return new VirtuosoBooleanQuery() {
            public boolean evaluate() throws QueryEvaluationException {
                return executeSPARQLForBooleanResult(baseURI, query, getDataset(), getIncludeInferred(), getBindings(), getMaxExecutionTime());
            }
        };
    }

    public Update prepareUpdate(QueryLanguage ql, String query) throws RepositoryException, MalformedQueryException {
        return prepareUpdate(ql, query, null);
    }

    public Update prepareUpdate(QueryLanguage ql, final String query, final String baseURI) throws RepositoryException, MalformedQueryException {
        if (ql != QueryLanguage.SPARQL)
            throw new UnsupportedQueryLanguageException(" : Only SPARQL queries are supported");

        return new VirtuosoUpdate() {
            public void execute() throws UpdateExecutionException {
                executeSPARUL(baseURI, query, getDataset(), getIncludeInferred(), getBindings(), -1);
            }
        };
    }

    /**
     * Gets all resources that are used as content identifiers. Care should be
     * taken that the returned {@link RepositoryResult} is closed to free any
     * resources that it keeps hold of.
     *
     * @return a RepositoryResult object containing Resources that are used as
     *         context identifiers.
     */
    public RepositoryResult<Resource> getContextIDs() throws RepositoryException {
        verifyIsOpen();
        flushDelayAdd();
        Vector<Resource> v = new Vector<Resource>();
        String query = "DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS()";
        try {
            java.sql.Statement stmt = createStatement(-1, false);
            ResultSet rs = stmt.executeQuery(query);

            // begin at onset one
            while (rs.next()) {
                Object obj = rs.getObject(1);
                try {
                    Value graphId = castValue(obj);
                    // add that graph to the results
                    v.add((Resource)graphId);
                }
                catch (IllegalArgumentException iiaex) {
                    throw new RepositoryException("VirtuosoRepositoryConnection.getContextIDs() Non-URI context encountered: " + obj);
                }
            }
            rs.close();
            stmt.close();

        }
        catch (Exception e) {
            throw new RepositoryException(": SPARQL execute failed." + "\n" + query, e);
        }
        return createRepositoryResult(v);
    }

    /**
     * Gets all statements with a specific subject, predicate and/or object from
     * the repository. The result is optionally restricted to the specified set
     * of named contexts.
     *
     * @param subj
     *        A Resource specifying the subject, or <tt>null</tt> for a
     *        wildcard.
     * @param pred
     *        A URI specifying the predicate, or <tt>null</tt> for a wildcard.
     * @param obj
     *        A Value specifying the object, or <tt>null</tt> for a wildcard.
     * @param includeInferred
     *        if false, no inferred statements are returned; if true, inferred
     *        statements are returned if available. The default is true.
     * @param contexts
     *        The context(s) to get the data from. Note that this parameter is a
     *        vararg and as such is optional. If no contexts are supplied the
     *        method operates on the entire repository.
     * @return The statements matching the specified pattern. The result object
     *         is a {@link RepositoryResult} object, a lazy Iterator-like object
     *         containing {@link Statement}s and optionally throwing a
     *         {@link RepositoryException} when an error when a problem occurs
     *         during retrieval.
     */
    public RepositoryResult<Statement> getStatements(Resource subj, IRI pred, Value obj, boolean includeInferred, Resource... contexts) throws RepositoryException {
        contexts = checkContext(contexts);
        return new RepositoryResult<Statement>(selectFromQuadStore(subj, pred, obj, includeInferred, false, contexts));
    }

    /**
     * Checks whether the repository contains statements with a specific subject,
     * predicate and/or object, optionally in the specified contexts.
     *
     * @param subj
     *        A Resource specifying the subject, or <tt>null</tt> for a
     *        wildcard.
     * @param pred
     *        A URI specifying the predicate, or <tt>null</tt> for a wildcard.
     * @param obj
     *        A Value specifying the object, or <tt>null</tt> for a wildcard.
     * @param includeInferred
     *        if false, no inferred statements are considered; if true, inferred
     *        statements are considered if available
     * @param contexts
     *        The context(s) the need to be searched. Note that this parameter is
     *        a vararg and as such is optional. If no contexts are supplied the
     *        method operates on the entire repository.
     * @return true If a matching statement is in the repository in the specified
     *         context, false otherwise.
     */
    public boolean hasStatement(Resource subj, IRI pred, Value obj, boolean includeInferred, Resource... contexts) throws RepositoryException {
        contexts = checkContext(contexts);
        CloseableIteration<Statement, RepositoryException> it;
        it = selectFromQuadStore(subj, pred, obj, includeInferred, true, contexts);
        try {
            return it.hasNext();
        } finally {
            it.close();
        }
    }

    /**
     * Checks whether the repository contains the specified statement, optionally
     * in the specified contexts.
     *
     * @param st
     *        The statement to look for. Context information in the statement is
     *        ignored.
     * @param includeInferred
     *        if false, no inferred statements are considered; if true, inferred
     *        statements are considered if available
     * @param contexts
     *        The context(s) to get the data from. Note that this parameter is a
     *        vararg and as such is optional. If no contexts are supplied the
     *        method operates on the entire repository.
     * @return true If the repository contains the specified statement, false
     *         otherwise.
     */
    public boolean hasStatement(Statement st, boolean includeInferred, Resource... contexts) throws RepositoryException {
        return hasStatement(st.getSubject(), st.getPredicate(), st.getObject(), includeInferred, contexts);
    }

    /**
     * Exports all statements with a specific subject, predicate and/or object
     * from the repository, optionally from the specified contexts.
     *
     * @param subj
     *        The subject, or null if the subject doesn't matter.
     * @param pred
     *        The predicate, or null if the predicate doesn't matter.
     * @param obj
     *        The object, or null if the object doesn't matter.
     * @param includeInferred
     *        if false, no inferred statements are returned; if true, inferred
     *        statements are returned if available
     * @param handler
     *        The handler that will handle the RDF data.
     * @param contexts
     *        The context(s) to get the data from. Note that this parameter is a
     *        vararg and as such is optional. If no contexts are supplied the
     *        method operates on the entire repository.
     * @throws RDFHandlerException
     *         If the handler encounters an unrecoverable error.
     */
    public void exportStatements(Resource subj, IRI pred, Value obj, boolean includeInferred, RDFHandler handler, Resource... contexts) throws RepositoryException, RDFHandlerException {
        contexts = checkContext(contexts);
        CloseableIteration<Statement, RepositoryException> it;
        handler.startRDF();

        // Export namespace information
        RepositoryResult<Namespace> nsIt = getNamespaces();
        try {
            while (nsIt.hasNext()) {
                Namespace ns = nsIt.next();
                handler.handleNamespace(ns.getPrefix(), ns.getName());
            }
        }
        finally {
            nsIt.close();
        }

        it = selectFromQuadStore(subj, pred, obj, includeInferred, false, contexts);
        try {
            while (it.hasNext())
                handler.handleStatement(it.next());
        }
        finally {
            it.close();
        }
        handler.endRDF();
    }

    private Resource[] checkDMLContext(Resource... contexts) throws RepositoryException {
        OpenRDFUtil.verifyContextNotNull(contexts);
        if(contexts.length == 1 && contexts[0] == null) {
            contexts = new Resource[] {nilContext};
        }
        else if (contexts.length == 0) {
            contexts = new Resource[] {nilContext};
        }
        return contexts;
    }

    private Resource[] checkContext(Resource... contexts) throws RepositoryException {
        OpenRDFUtil.verifyContextNotNull(contexts);
        if(contexts.length == 1 && contexts[0] == null) {
            contexts = new Resource[] {nilContext};
        }
        else if (contexts.length == 0) {
            contexts = new Resource[0];
        }
        return contexts;
    }


    /**
     * Exports all explicit statements in the specified contexts to the supplied
     * RDFHandler.
     *
     * @param handler
     *        The handler that will handle the RDF data.
     * @param contexts
     *        The context(s) to get the data from. Note that this parameter is a
     *        vararg and as such is optional. If no contexts are supplied the
     *        method operates on the entire repository.
     * @throws RDFHandlerException
     *         If the handler encounters an unrecoverable error.
     */
    public void export(RDFHandler handler, Resource... contexts) throws RepositoryException, RDFHandlerException {
        exportStatements(null, null, null, false, handler, contexts);
    }

    /**
     * Returns the number of (explicit) statements that are in the specified
     * contexts in this repository.
     *
     * @param contexts
     *        The context(s) to get the data from. Note that this parameter is a
     *        vararg and as such is optional. If no contexts are supplied the
     *        method operates on the entire repository.
     * @return The number of explicit statements from the specified contexts in
     *         this repository.
     */
    public long size(Resource... contexts) throws RepositoryException {
        long ret = 0;
        verifyIsOpen();
        flushDelayAdd();

        contexts = checkContext(contexts);
        StringBuilder query = new StringBuilder("select count(*) from (sparql define input:storage \"\" select * ");

        for (Resource context : contexts) {
            query.append("from named <");
            query.append(context.toString());
            query.append("> ");
        }
        query.append("where { graph ?g {?s ?p ?o }})f");
        try {
            java.sql.Statement st = createStatement(-1, false);
            ResultSet rs = st.executeQuery(query.toString());

            if (rs.next())
                ret = rs.getLong(1);
            rs.close();
            st.close();
        }
        catch (Exception e) {
            throw new RepositoryException(": SPARQL execute failed:["+query+"] \n Exception:"+e);
        }
        return ret;
    }

    /**
     * Returns <tt>true</tt> if this repository does not contain any (explicit)
     * statements.
     *
     * @return <tt>true</tt> if this repository is empty, <tt>false</tt>
     *         otherwise.
     * @throws RepositoryException
     *         If the repository could not be checked to be empty.
     */
    public boolean isEmpty() throws RepositoryException {
        verifyIsOpen();
        flushDelayAdd();
        boolean result;
        String query = "sparql define input:storage \"\" select * where {?s ?o ?p} limit 1";
        try {
            java.sql.Statement stmt = createStatement(-1, false);
            ResultSet rs = stmt.executeQuery(query);
            result = !rs.next();
            rs.close();
            stmt.close();
            return result;
        }
        catch (Exception e) {
            throw new RepositoryException(": SPARQL execute failed:["+query+"] \n Exception:"+e);
        }
    }


    /**
     * Enables or disables auto-commit mode for the connection. If a connection
     * is in auto-commit mode, then all updates will be executed and committed as
     * individual transactions. Otherwise, the updates are grouped into
     * transactions that are terminated by a call to either {@link #commit} or
     * {@link #rollback}. By default, new connections are in auto-commit mode.
     * <p>
     * <b>NOTE:</b> If this connection is switched to auto-commit mode during a
     * transaction, the transaction is committed.
     *
     * @throws RepositoryException
     *         In case the mode switch failed, for example because a currently
     *         active transaction failed to commit.
     * @see #commit
     * @deprecated since 2.7.0. Use {@link #begin()} instead.
     */
    @Deprecated
    public void setAutoCommit(boolean autoCommit) throws RepositoryException {
        verifyIsOpen();
        flushDelayAdd();

        try {
            getQuadStoreConnection().setAutoCommit(autoCommit);
        }
        catch (SQLException e) {
            throw new RepositoryException(e);
        }
    }

    /**
     * Checks whether the connection is in auto-commit mode.
     *
     * @see #setAutoCommit
     * @deprecated since 2.7.0. Use {@link #isActive()} instead.
     */
    @Deprecated
    public boolean isAutoCommit() throws RepositoryException {
        verifyIsOpen();
        try {
            return getQuadStoreConnection().getAutoCommit();
        }
        catch (SQLException e) {
            throw new RepositoryException(e);
        }
    }

    /**
     * Indicates if a transaction is currently active on the connection. A
     * transaction is active if {@link #begin()} has been called, and becomes
     * inactive after {@link #commit()} or {@link #rollback()} has been called.
     *
     * @since 2.7.0
     * @return <code>true</code> iff a transaction is active, <code>false</code>
     *         iff no transaction is active.
     * @throws UnknownTransactionStateException
     *         if the transaction state can not be determined. This can happen
     *         for instance when communication with a repository fails or times
     *         out.
     * @throws RepositoryException
     */
    public boolean isActive() throws RepositoryException {
        verifyIsOpen();
        try {
            return !getQuadStoreConnection().getAutoCommit();
        }
        catch (SQLException e) {
            throw new RepositoryException(e);
        }
    }

    /**
     * Sets the transaction isolation level for the next transaction(s) on this
     * connection. If the level is set to a value that is not supported by the
     * underlying repository, this method will still succeed but a subsequent
     * call to {@link #begin()} will result in an exception.
     *
     * @param level
     *        the transaction isolation level to set.
     * @throws IllegalStateException
     *         if the method is called while a transaction is already active.
     * @since 2.8.0
     */
    public void setIsolationLevel(IsolationLevel level) throws IllegalStateException {
        try {
            if (isActive()) {
                throw new IllegalStateException(
                        "Transaction isolation level can not be modified while transaction is active");
            }
            this.isolationLevel = level;
        }
        catch (UnknownTransactionStateException e) {
            throw new IllegalStateException(
                    "Transaction isolation level can not be modified while transaction state is unknown", e);

        }
        catch (RepositoryException e) {
            throw new IllegalStateException(
                    "Transaction isolation level can not be modified due to repository error", e);
        }
    }

    /**
     * Retrieves the current {@link IsolationLevel transaction isolation level}
     * of the connection.
     *
     * @return the current transaction isolation level.
     * @since 2.8.0
     */
    public IsolationLevel getIsolationLevel() {
        return this.isolationLevel;
    }

    /**
     * Begins a transaction requiring {@link #commit()} or {@link #rollback()} to
     * be called to end the transaction.
     *
     * @throws RepositoryException
     *         If the connection could not start a transaction.
     * @see #isActive()
     * @see #commit()
     * @see #rollback()
     * @since 2.7.0
     */
    public void begin() throws RepositoryException {
        verifyIsOpen();
        flushDelayAdd();
        verifyNotTxnActive("Connection already has an active transaction");

        try {
            Connection conn = getQuadStoreConnection();
            conn.setAutoCommit(false);

            if (isolationLevel == IsolationLevels.READ_UNCOMMITTED)
                conn.setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);
            else if (isolationLevel == IsolationLevels.READ_COMMITTED)
                conn.setTransactionIsolation(Connection.TRANSACTION_READ_COMMITTED);
            else if (isolationLevel == IsolationLevels.SNAPSHOT_READ)
                conn.setTransactionIsolation(Connection.TRANSACTION_READ_COMMITTED);
            else if (isolationLevel == IsolationLevels.SNAPSHOT)
                conn.setTransactionIsolation(Connection.TRANSACTION_READ_COMMITTED);
            else if (isolationLevel == IsolationLevels.SERIALIZABLE)
                conn.setTransactionIsolation(Connection.TRANSACTION_SERIALIZABLE);
        }
        catch (SQLException e) {
            throw new RepositoryException(e);
        }
    }

    /**
     * Begins a new transaction with the supplied {@link IsolationLevel},
     * requiring {@link #commit()} or {@link #rollback()} to be called to end the
     * transaction.
     *
     * @param level
     *        The {@link IsolationLevel} at which this transaction will operate.
     *        If set to <code>null</code> the default isolation level of the
     *        underlying store will be used. If the specified isolation level is
     *        not supported by the underlying store, it will attempt to use a
     *        supported {@link IsolationLevel#isCompatibleWith(IsolationLevel)
     *        compatible level} instead.
     * @throws RepositoryException
     *         If the connection could not start the transaction. Possible
     *         reasons this may happen are:
     *         <ul>
     *         <li>a transaction is already {@link #isActive() active} on the
     *         current connection.
     *         <li>the specified {@link IsolationLevel} is not supported by the
     *         store, and no compatible level could be found.
     *         </ul>
     * @see #begin()
     * @see #isActive()
     * @see #commit()
     * @see #rollback()
     * @see #setIsolationLevel(IsolationLevel)
     * @since 2.8.0
     */
    public void begin(IsolationLevel level) throws RepositoryException {
        setIsolationLevel(level);
        begin();
    }

    /**
     * Commits all updates that have been performed as part of this connection
     * sofar.
     *
     * @throws RepositoryException
     *         If the connection could not be committed.
     */
    public void commit() throws RepositoryException {
        verifyIsOpen();
        flushDelayAdd();
        try {
            getQuadStoreConnection().commit();
            getQuadStoreConnection().setAutoCommit(true);
        }
        catch (SQLException e) {
            throw new RepositoryException(e);
        }
    }

    /**
     * Rolls back all updates that have been performed as part of this connection
     * sofar.
     *
     * @throws RepositoryException
     *         If the connection could not be rolled back.
     */
    public void rollback() throws RepositoryException {
        verifyIsOpen();
        dropDelayAdd();
        try {
            getQuadStoreConnection().rollback();
            getQuadStoreConnection().setAutoCommit(true);
        }
        catch (SQLException e) {
            throw new RepositoryException("Problem with rollback", e);
        }
    }

    /**
     * Adds RDF data from an InputStream to the repository, optionally to one or
     * more named contexts.
     *
     * @param in
     *        An InputStream from which RDF data can be read.
     * @param baseURI
     *        The base URI to resolve any relative URIs that are in the data
     *        against.
     * @param dataFormat
     *        The serialization format of the data.
     * @param contexts
     *        The contexts to add the data to. If one or more contexts are
     *        supplied the method ignores contextual information in the actual
     *        data. If no contexts are supplied the contextual information in the
     *        input stream is used, if no context information is available the
     *        data is added without any context.
     * @throws IOException
     *         If an I/O error occurred while reading from the input stream.
     * @throws UnsupportedRDFormatException
     *         If no parser is available for the specified RDF format.
     * @throws RDFParseException
     *         If an error was found while parsing the RDF data.
     * @throws RepositoryException
     *         If the data could not be added to the repository, for example
     *         because the repository is not writable.
     */
    public void add(InputStream in, String baseURI, RDFFormat dataFormat, Resource... contexts) throws IOException, RDFParseException, RepositoryException {
        Reader reader = new InputStreamReader(in);
        add(reader, baseURI, dataFormat, contexts);
    }

    /**
     * Adds RDF data from a Reader to the repository, optionally to one or more
     * named contexts. <b>Note: using a Reader to upload byte-based data means
     * that you have to be careful not to destroy the data's character encoding
     * by enforcing a default character encoding upon the bytes. If possible,
     * adding such data using an InputStream is to be preferred.</b>
     *
     * @param reader
     *        A Reader from which RDF data can be read.
     * @param baseURI
     *        The base URI to resolve any relative URIs that are in the data
     *        against.
     * @param dataFormat
     *        The serialization format of the data.
     * @param contexts
     *        The contexts to add the data to. If one or more contexts are
     *        specified the data is added to these contexts, ignoring any context
     *        information in the data itself.
     * @throws IOException
     *         If an I/O error occurred while reading from the reader.
     * @throws UnsupportedRDFormatException
     *         If no parser is available for the specified RDF format.
     * @throws RDFParseException
     *         If an error was found while parsing the RDF data.
     * @throws RepositoryException
     *         If the data could not be added to the repository, for example
     *         because the repository is not writable.
     */
    public synchronized void add(Reader reader, String baseURI, RDFFormat dataFormat, final Resource... contexts) throws IOException, RDFParseException, RepositoryException {
        verifyIsOpen();
        flushDelayAdd();

        final boolean useStatementContext = (contexts != null && contexts.length == 0); // If no context are specified, each statement is added to statement context

        try {
            RDFParser parser = Rio.createParser(dataFormat, getValueFactory());
            parser.setParserConfig(getParserConfig());
            parser.setParseErrorListener(new ParseErrorLogger());

            // set up a handler for parsing the data from reader

            parser.setRDFHandler(new AbstractRDFHandler() {

                int count = 0;
                PreparedStatement ps = null;
                java.sql.Statement st_cmd = null;
                Resource[] _contexts = checkDMLContext(contexts);

                public void startRDF() throws RDFHandlerException {
                    if (!insertBNodeAsVirtuosoIRI) {
                        try {
                            st_cmd = createStatement(-1, false);
                            st_cmd.executeUpdate("connection_set ('RDF_INSERT_TRIPLE_C_BNODES', dict_new(1000))");
                        }
                        catch (SQLException e) {
                            throw new RDFHandlerException("Problem with creation of BNode cache: ", e);
                        }
                    }
                }

                public void endRDF() throws RDFHandlerException {
                    try {
                        if (count > 0)
                            ps = flushDelayAdd_batch(ps, count);
                    }
                    catch (RepositoryException e) {
                        throw new RDFHandlerException("Problem executing query: ", e);
                    }
                    try {
                        if (st_cmd!=null)
                            st_cmd.executeUpdate("connection_set ('RDF_INSERT_TRIPLE_C_BNODES', NULL)");
                    }
                    catch (SQLException e) {
                        throw new RDFHandlerException("Problem with clearing of BNode cache: ", e);
                    }
                    if (ps != null) {
                        try {
                            ps.close();
                        } catch (Exception e) {}
                    }
                    if (st_cmd != null) {
                        try {
                            st_cmd.close();
                        } catch (Exception e) {}
                    }
                    ps = null;
                    st_cmd = null;
                    count = 0;
                }

                public void handleNamespace(String prefix, String name) throws RDFHandlerException {
                    String query = "DB.DBA.XML_SET_NS_DECL(?, ?, 1)";
                    try {
                        PreparedStatement psn = prepareStatement(query, false);
                        psn.setString(1, prefix);
                        psn.setString(2, name);
                        psn.execute();
                        psn.close();
                    }
                    catch (SQLException e) {
                        throw new RDFHandlerException("Problem executing query: " + query, e);
                    }
                }

                public void handleStatement(Statement st) throws RDFHandlerException {
                    try {
                        Resource[] hcontexts;
                        if (st.getContext() != null && useStatementContext) {
                            hcontexts = new Resource[] {st.getContext()};
                        } else {
                            hcontexts = _contexts;
                        }

                        ps = addToQuadStore_batch(ps, st.getSubject(),
                                st.getPredicate(), st.getObject(), hcontexts);
                        count += hcontexts.length;

                        if (count > BATCH_SIZE) {
                            ps = flushDelayAdd_batch(ps, count);
                            count = 0;
                        }
                    }
                    catch(Exception e) {
                        throw new RDFHandlerException(e);
                    }
                }
            });
            parser.parse(reader, baseURI); // parse out each tripled to be handled by the handler above
        }
        catch (Exception e) {
            throw new RepositoryException("Problem parsing triples", e);
        }
    }

    /**
     * Adds the RDF data that can be found at the specified URL to the
     * repository, optionally to one or more named contexts.
     *
     * @param url
     *        The URL of the RDF data.
     * @param baseURI
     *        The base URI to resolve any relative URIs that are in the data
     *        against. This defaults to the value of {@link
     *        java.net.URL#toExternalForm() url.toExternalForm()} if the value is
     *        set to <tt>null</tt>.
     * @param dataFormat
     *        The serialization format of the data.
     * @param contexts
     *        The contexts to add the data to. If one or more contexts are
     *        specified the data is added to these contexts, ignoring any context
     *        information in the data itself.
     * @throws IOException
     *         If an I/O error occurred while reading from the URL.
     * @throws UnsupportedRDFormatException
     *         If no parser is available for the specified RDF format.
     * @throws RDFParseException
     *         If an error was found while parsing the RDF data.
     * @throws RepositoryException
     *         If the data could not be added to the repository, for example
     *         because the repository is not writable.
     */
    public void add(URL url, String baseURI, RDFFormat dataFormat, Resource... contexts) throws IOException, RDFParseException, RepositoryException {
        // add data to Sesame
        if (baseURI == null) {
            baseURI = url.toExternalForm();
        }
        Reader reader = new InputStreamReader(url.openStream());
        try {
            add(reader, baseURI, dataFormat, contexts);
        } finally {
            reader.close();
        }
    }

    /**
     * Adds RDF data from the specified file to a specific contexts in the
     * repository.
     *
     * @param file
     *        A file containing RDF data.
     * @param baseURI
     *        The base URI to resolve any relative URIs that are in the data
     *        against. This defaults to the value of
     *        {@link java.io.File#toURI() file.toURI()} if the value is set to
     *        <tt>null</tt>.
     * @param dataFormat
     *        The serialization format of the data.
     * @param contexts
     *        The contexts to add the data to. Note that this parameter is a
     *        vararg and as such is optional. If no contexts are specified, the
     *        data is added to any context specified in the actual data file, or
     *        if the data contains no context, it is added without context. If
     *        one or more contexts are specified the data is added to these
     *        contexts, ignoring any context information in the data itself.
     * @throws IOException
     *         If an I/O error occurred while reading from the file.
     * @throws UnsupportedRDFormatException
     *         If no parser is available for the specified RDF format.
     * @throws RDFParseException
     *         If an error was found while parsing the RDF data.
     * @throws RepositoryException
     *         If the data could not be added to the repository, for example
     *         because the repository is not writable.
     */
    public void add(File file, String baseURI, RDFFormat dataFormat, Resource... contexts) throws IOException, RDFParseException, RepositoryException {
        if (baseURI == null) {
            // default baseURI to file
            baseURI = file.toURI().toString();
        }
        InputStream reader = new FileInputStream(file);
        try {
            add(reader, baseURI, dataFormat, contexts);
        } finally {
            reader.close();
        }
    }

    /**
     * Adds a statement with the specified subject, predicate and object to this
     * repository, optionally to one or more named contexts.
     *
     * @param subject
     *        The statement's subject.
     * @param predicate
     *        The statement's predicate.
     * @param object
     *        The statement's object.
     * @param contexts
     *        The contexts to add the data to. Note that this parameter is a
     *        vararg and as such is optional. If no contexts are specified, the
     *        data is added to any context specified in the actual data file, or
     *        if the data contains no context, it is added without context. If
     *        one or more contexts are specified the data is added to these
     *        contexts, ignoring any context information in the data itself.
     * @throws RepositoryException
     *         If the data could not be added to the repository, for example
     *         because the repository is not writable.
     */
    public void add(Resource subject, IRI predicate, Value object, Resource... contexts) throws RepositoryException {
        contexts = checkDMLContext(contexts);
        addToQuadStore(subject, predicate, object, contexts);
    }
    public void addQuad(Resource subject, IRI predicate, Value object, Resource context) throws RepositoryException {
        addToQuadStore(subject, predicate, object, context);
    }

    /**
     * Adds the supplied statement to this repository, optionally to one or more
     * named contexts.
     *
     * @param statement
     *        The statement to add.
     * @param contexts
     *        The contexts to add the statements to. Note that this parameter is
     *        a vararg and as such is optional. If no contexts are specified, the
     *        statement is added to any context specified in each statement, or
     *        if the statement contains no context, it is added without context.
     *        If one or more contexts are specified the statement is added to
     *        these contexts, ignoring any context information in the statement
     *        itself.
     * @throws RepositoryException
     *         If the statement could not be added to the repository, for example
     *         because the repository is not writable.
     */
    public void add(Statement statement, Resource... contexts) throws RepositoryException {
        if (contexts != null && contexts.length == 0 &&  statement.getContext() != null) {
            contexts = new Resource[] { statement.getContext() }; // try the context given by the statement
        }
        add(statement.getSubject(), statement.getPredicate(), statement.getObject(), contexts);
    }

    /**
     * Adds the supplied statements to this repository, optionally to one or more
     * named contexts.
     *
     * @param statements
     *        The statements that should be added.
     * @param contexts
     *        The contexts to add the statements to. Note that this parameter is
     *        a vararg and as such is optional. If no contexts are specified,
     *        each statement is added to any context specified in the statement,
     *        or if the statement contains no context, it is added without
     *        context. If one or more contexts are specified each statement is
     *        added to these contexts, ignoring any context information in the
     *        statement itself. ignored.
     * @throws RepositoryException
     *         If the statements could not be added to the repository, for
     *         example because the repository is not writable.
     */
    public synchronized void add(Iterable<? extends Statement> statements, Resource... contexts) throws RepositoryException {
        verifyIsOpen();
        flushDelayAdd();

        Iterator<? extends Statement> it = statements.iterator();
        boolean useStatementContext = (contexts != null && contexts.length == 0); // If no context are specified, each statement is added to statement context
        Resource[] _contexts = checkDMLContext(contexts); // otherwise, either use all contexts, or do not specify a context

        int count = 0;
        PreparedStatement ps = null;
        java.sql.Statement st_cmd = null;

        try {
            if (!insertBNodeAsVirtuosoIRI) {
                st_cmd = createStatement(-1, false);
                st_cmd.executeUpdate("connection_set ('RDF_INSERT_TRIPLE_C_BNODES', dict_new(1000))");
            }

            while (it.hasNext()) {
                Statement st = it.next();

                if (st.getContext() != null && useStatementContext) {
                    contexts = new Resource[] {st.getContext()};
                } else {
                    contexts = _contexts;
                }

                ps = addToQuadStore_batch(ps, st.getSubject(),
                        st.getPredicate(), st.getObject(), contexts);
                count += contexts.length;

                if (count > BATCH_SIZE) {
                    ps = flushDelayAdd_batch(ps, count);
                    count = 0;
                }
            }
            if (count > 0)
                ps = flushDelayAdd_batch(ps, count);
            if (st_cmd!=null)
                st_cmd.executeUpdate("connection_set ('RDF_INSERT_TRIPLE_C_BNODES', NULL)");
        }
        catch(Exception e) {
            throw new RepositoryException(e);
        }
        finally {
            if (ps != null) {
                try {
                    ps.close();
                } catch (Exception e) {}
            }
            if (st_cmd != null) {
                try {
                    st_cmd.close();
                } catch (Exception e) {}
            }
        }
    }

    /**
     * Adds the supplied statements to this repository, optionally to one or more
     * named contexts.
     *
     * @param statements
     *        The statements to add. In case the iterator is a
     *        {@link CloseableIteration}, it will be closed before this method
     *        returns.
     * @param contexts
     *        The contexts to add the statements to. Note that this parameter is
     *        a vararg and as such is optional. If no contexts are specified,
     *        each statement is added to any context specified in the statement,
     *        or if the statement contains no context, it is added without
     *        context. If one or more contexts are specified each statement is
     *        added to these contexts, ignoring any context information in the
     *        statement itself. ignored.
     * @throws RepositoryException
     *         If the statements could not be added to the repository, for
     *         example because the repository is not writable.
     */
    public synchronized  <E extends Exception> void add(Iteration<? extends Statement, E> statements, Resource... contexts) throws RepositoryException, E {
        verifyIsOpen();
        flushDelayAdd();

        boolean useStatementContext = (contexts != null && contexts.length == 0); // If no context are specified, each statement is added to statement context
        Resource[] _contexts = checkDMLContext(contexts); // otherwise, either use all contexts, or do not specify a context

        int count = 0;
        PreparedStatement ps = null;
        java.sql.Statement st_cmd = null;

        try {
            if (!insertBNodeAsVirtuosoIRI) {
                st_cmd = createStatement(-1, false);
                st_cmd.executeUpdate("connection_set ('RDF_INSERT_TRIPLE_C_BNODES', dict_new(1000))");
            }

            while (statements.hasNext()) {
                Statement st = statements.next();

                if (st.getContext() != null && useStatementContext) {
                    contexts = new Resource[] {st.getContext()};
                } else {
                    contexts = _contexts;
                }

                ps = addToQuadStore_batch(ps, st.getSubject(),
                        st.getPredicate(), st.getObject(), contexts);
                count += contexts.length;

                if (count > BATCH_SIZE) {
                    ps = flushDelayAdd_batch(ps, count);
                    count = 0;
                }
            }

            if (count > 0)
                ps = flushDelayAdd_batch(ps, count);
            if (st_cmd!=null)
                st_cmd.executeUpdate("connection_set ('RDF_INSERT_TRIPLE_C_BNODES', NULL)");
        }
        catch(Exception e) {
            throw new RepositoryException(e);
        }
        finally {
            if (ps != null) {
                try {
                    ps.close();
                } catch (Exception e) {}
            }
            if (st_cmd != null) {
                try {
                    st_cmd.close();
                } catch (Exception e) {}
            }
            Iterations.closeCloseable(statements);
        }
    }

    /**
     * Removes the statement(s) with the specified subject, predicate and object
     * from the repository, optionally restricted to the specified contexts.
     *
     * @param subject
     *        The statement's subject, or <tt>null</tt> for a wildcard.
     * @param predicate
     *        The statement's predicate, or <tt>null</tt> for a wildcard.
     * @param object
     *        The statement's object, or <tt>null</tt> for a wildcard.
     * @param contexts
     *        The context(s) to remove the data from. Note that this parameter is
     *        a vararg and as such is optional. If no contexts are supplied the
     *        method operates on the entire repository.
     * @throws RepositoryException
     *         If the statement(s) could not be removed from the repository, for
     *         example because the repository is not writable.
     */
    public void remove(Resource subject, IRI predicate, Value object, Resource... contexts) throws RepositoryException {
        OpenRDFUtil.verifyContextNotNull(contexts);
        verifyIsOpen();
        flushDelayAdd();

        contexts = checkDMLContext(contexts);

        for (Resource context : contexts) removeContext(subject, predicate, object, context);
    }

    /**
     * Removes the supplied statement from the specified contexts in the
     * repository.
     *
     * @param statement
     *        The statement to remove.
     * @param contexts
     *        The context(s) to remove the data from. Note that this parameter is
     *        a vararg and as such is optional. If no contexts are supplied the
     *        method operates on the contexts associated with the statement
     *        itself, and if no context is associated with the statement, on the
     *        entire repository.
     * @throws RepositoryException
     *         If the statement could not be removed from the repository, for
     *         example because the repository is not writable.
     */
    public void remove(Statement statement, Resource... contexts) throws RepositoryException {
        if (contexts != null && contexts.length == 0 &&  statement.getContext() != null) {
            contexts = new Resource[] { statement.getContext() }; // try the context given by the statement
        }
        remove(statement.getSubject(), statement.getPredicate(), statement.getObject(), contexts);
    }

    /**
     * Removes the supplied statements from the specified contexts in this
     * repository.
     *
     * @param statements
     *        The statements that should be removed.
     * @param contexts
     *        The context(s) to remove the data from. Note that this parameter is
     *        a vararg and as such is optional. If no contexts are supplied the
     *        method operates on the contexts associated with the statement
     *        itself, and if no context is associated with the statement, on the
     *        entire repository.
     * @throws RepositoryException
     *         If the statements could not be added to the repository, for
     *         example because the repository is not writable.
     */
    public void remove(Iterable<? extends Statement> statements, Resource... contexts) throws RepositoryException {
        OpenRDFUtil.verifyContextNotNull(contexts);
        verifyIsOpen();
        flushDelayAdd();

        Resource[] _contexts;
        Iterator<? extends Statement> it = statements.iterator();
        int count = 0;
        HashMap<String, StringBuilder> map = new HashMap<String,StringBuilder>();

        while (it.hasNext()) {
            Statement st = it.next();

            if (contexts.length == 0 &&  st.getContext() != null)
                _contexts = new Resource[] { st.getContext() }; // try the context given by the statement
            else
                _contexts = contexts;
            _contexts = checkDMLContext(_contexts);

            for (Resource _context : _contexts) {
                String ctx = _context.toString();
                StringBuilder row = new StringBuilder(256);

                append(st.getSubject(), row, true);
                row.append(' ');
                append(st.getPredicate(), row, true);
                row.append(' ');
                append(st.getObject(), row, true);
                row.append(" .\n");

                StringBuilder data = map.get(ctx);
                if (count > 0 && data != null && data.length() + row.length() > MAX_CMD_SIZE) {
                    removeData(map);
                    map.clear();
                    count = 0;
                    data = null;
                }

                if (data == null)
                    data = new StringBuilder(256);
                data.append(row);
                map.put(ctx, data);
                count++;
            }
        }
        if (count > 0)
            removeData(map);
        map.clear();
    }

    /**
     * Removes the supplied statements from a specific context in this
     * repository, ignoring any context information carried by the statements
     * themselves.
     *
     * @param statements
     *        The statements to remove. In case the iterator is a
     *        {@link CloseableIteration}, it will be closed before this method
     *        returns.
     * @param contexts
     *        The context(s) to remove the data from. Note that this parameter is
     *        a vararg and as such is optional. If no contexts are supplied the
     *        method operates on the contexts associated with the statement
     *        itself, and if no context is associated with the statement, on the
     *        entire repository.
     * @throws RepositoryException
     *         If the statements could not be removed from the repository, for
     *         example because the repository is not writable.
     */
    public <E extends Exception> void remove(Iteration<? extends Statement, E> statements, Resource... contexts) throws RepositoryException, E {
        OpenRDFUtil.verifyContextNotNull(contexts);
        verifyIsOpen();
        flushDelayAdd();

        Resource[] _contexts;
        int count = 0;
        HashMap<String, StringBuilder> map = new HashMap<String,StringBuilder>();

        try {
            while (statements.hasNext()) {
                Statement st = statements.next();

                if (contexts.length == 0 &&  st.getContext() != null)
                    _contexts = new Resource[] { st.getContext() }; // try the context given by the statement
                else
                    _contexts = contexts;
                _contexts = checkDMLContext(_contexts);

                for (Resource _context : _contexts) {
                    String ctx = _context.toString();
                    StringBuilder row = new StringBuilder(256);

                    append(st.getSubject(), row, true);
                    row.append(' ');
                    append(st.getPredicate(), row, true);
                    row.append(' ');
                    append(st.getObject(), row, true);
                    row.append(" .\n");

                    StringBuilder data = map.get(ctx);
                    if (count > 0 && data != null && data.length() + row.length() > MAX_CMD_SIZE) {
                        removeData(map);
                        map.clear();
                        count = 0;
                        data = null;
                    }

                    if (data == null)
                        data = new StringBuilder(256);
                    data.append(row);
                    map.put(ctx, data);
                    count++;
                }
            }
            if (count > 0)
                removeData(map);
            map.clear();
        }
        finally {
            Iterations.closeCloseable(statements);
        }
    }

    /**
     * Removes all statements from a specific contexts in the repository.
     *
     * @param contexts
     *        The context(s) to remove the data from. Note that this parameter is
     *        a vararg and as such is optional. If no contexts are supplied the
     *        method operates on the entire repository.
     * @throws RepositoryException
     *         If the statements could not be removed from the repository, for
     *         example because the repository is not writable.
     */
    public void clear(Resource... contexts) throws RepositoryException {
        OpenRDFUtil.verifyContextNotNull(contexts);
        verifyIsOpen();
        flushDelayAdd();

        contexts = checkDMLContext(contexts);

        clearQuadStore(contexts);
    }

    /**
     * Gets all declared namespaces as a RepositoryResult of {@link Namespace}
     * objects. Each Namespace object consists of a prefix and a namespace name.
     *
     * @return A RepositoryResult containing Namespace objects. Care should be
     *         taken to close the RepositoryResult after use.
     * @throws RepositoryException
     *         If the namespaces could not be read from the repository.
     */
    public RepositoryResult<Namespace> getNamespaces() throws RepositoryException {
        verifyIsOpen();
        flushDelayAdd();
        List<Namespace> namespaceList = new ArrayList<Namespace>();
        String query = "DB.DBA.XML_SELECT_ALL_NS_DECLS (3)";
        try {
            java.sql.Statement stmt = createStatement(-1, false);
            ResultSet rs = stmt.executeQuery(query);

            // begin at onset one
            while (rs.next()) {
                String prefix = rs.getString(1);
                String name = rs.getString(2);
                if (name != null && prefix != null) {
                    Namespace ns = new SimpleNamespace(prefix, name);
                    namespaceList.add(ns);
                }
            }
            rs.close();
            stmt.close();
        }
        catch (Exception e) {
            throw new RepositoryException(e);
        }
        return createRepositoryResult(namespaceList);// new RepositoryResult<Namespace>(new IteratorWrapper(v.iterator()));
    }

    /**
     * Gets the namespace that is associated with the specified prefix, if any.
     *
     * @param prefix
     *        A namespace prefix.
     * @return The namespace name that is associated with the specified prefix,
     *         or <tt>null</tt> if there is no such namespace.
     * @throws RepositoryException
     *         If the namespace could not be read from the repository.
     */
    public String getNamespace(String prefix) throws RepositoryException {
        verifyIsOpen();
        flushDelayAdd();
        String retVal = null;
        String query = "SELECT __xml_get_ns_uri (?, 3)";
        try {
            PreparedStatement ps = prepareStatement(query, false);
            ps.setString(1, prefix);
            ResultSet rs = ps.executeQuery();

            // begin at onset one
            while (rs.next()) {
                retVal = rs.getString(1);
                break;
            }
            ps.close();
        }
        catch (Exception e) {
            throw new RepositoryException(e);
        }
        return retVal;
    }

    /**
     * Sets the prefix for a namespace.
     *
     * @param prefix
     *        The new prefix.
     * @param name
     *        The namespace name that the prefix maps to.
     * @throws RepositoryException
     *         If the namespace could not be set in the repository, for example
     *         because the repository is not writable.
     */
    public void setNamespace(String prefix, String name) throws RepositoryException {
        verifyIsOpen();
        flushDelayAdd();
        String query = "DB.DBA.XML_SET_NS_DECL(?, ?, 2)";
        try {
            PreparedStatement ps = prepareStatement(query, false);
            ps.setString(1, prefix);
            ps.setString(2, name);
            ps.execute();
            ps.close();
        }
        catch (SQLException e) {
            throw new RepositoryException("Problem executing query: " + query, e);
        }
    }

    /**
     * Removes a namespace declaration by removing the association between a
     * prefix and a namespace name.
     *
     * @param prefix
     *        The namespace prefix of which the assocation with a namespace name
     *        is to be removed.
     * @throws RepositoryException
     *         If the namespace prefix could not be removed.
     */
    public void removeNamespace(String prefix) throws RepositoryException {
        verifyIsOpen();
        flushDelayAdd();
        String query = "DB.DBA.XML_REMOVE_NS_BY_PREFIX(?, 2)";
        try {
            PreparedStatement ps = prepareStatement(query, false);
            ps.setString(1, prefix);
            ps.execute();
            ps.close();
        }
        catch (SQLException e) {
            throw new RepositoryException("Problem executing query: " + query, e);
        }
    }

    /**
     * Removes all namespace declarations from the repository.
     *
     * @throws RepositoryException
     *         If the namespace declarations could not be removed.
     */
    public void clearNamespaces() throws RepositoryException {
        verifyIsOpen();
        flushDelayAdd();
        String query = "DB.DBA.XML_CLEAR_ALL_NS_DECLS(2)";
        try {
            java.sql.Statement stmt = createStatement(-1, true);
            stmt.execute(query);
            stmt.close();
        }
        catch (SQLException e) {
            throw new RepositoryException("Problem executing query: " + query, e);
        }
    }


    protected TupleQueryResult executeSPARQLForTupleResult(String baseURI, String query,
                                                           Dataset dataset, boolean includeInferred, BindingSet bindings,
                                                           int maxQueryTime) throws QueryEvaluationException
    {

        List<String> names = new ArrayList<String>();
        try {
            PreparedStatement stmt = executeSPARQL(baseURI, query, dataset, includeInferred, bindings, maxQueryTime, false);
            ResultSet rs = stmt.executeQuery();
            ResultSetMetaData rsmd = rs.getMetaData();

            // begin at onset one
            for (int i = 1; i <= rsmd.getColumnCount(); i++) {
                String col = rsmd.getColumnName(i);
                if (names.indexOf(col) < 0)
                    names.add(col); // no duplicates
            }

            return new IteratingTupleQueryResult(names, new CloseableIterationBindingSet(stmt, rs));
        }
        catch (Exception e) {
            throw new QueryEvaluationException(": SPARQL execute failed:["+query+"] \n Exception:"+e);
        }
    }

    protected GraphQueryResult executeSPARQLForGraphResult(String baseURI, String query,
                                                           Dataset dataset, boolean includeInferred, BindingSet bindings,
                                                           int maxQueryTime) throws QueryEvaluationException
    {
//        HashMap<String,Integer> names = new HashMap<String,Integer>();
        try {
            PreparedStatement stmt = executeSPARQL(baseURI, query, dataset, includeInferred, bindings, maxQueryTime, false);
            ResultSet rs = stmt.executeQuery();
//            ResultSetMetaData rsmd = rs.getMetaData();

            // begin at onset one
/**
            for (int i = 1; i <= rsmd.getColumnCount(); i++)
                names.put(rsmd.getColumnName(i), new Integer(i));
**/
            return new IteratingGraphQueryResult(new HashMap<String,String>(), new CloseableIterationGraphResult(stmt, rs));
        }
        catch (Exception e) {
            throw new QueryEvaluationException(": SPARQL execute failed:["+query+"] \n Exception:"+e);
        }

    }

    protected boolean executeSPARQLForBooleanResult(String baseURI, String query,
                                                    Dataset dataset, boolean includeInferred, BindingSet bindings,
                                                    int maxQueryTime) throws QueryEvaluationException
    {
        boolean result = false;
        try {
            PreparedStatement stmt = executeSPARQL(baseURI, query, dataset, includeInferred, bindings, maxQueryTime, false);
            ResultSet rs = stmt.executeQuery();

            while(rs.next())
            {
                if (rs.getInt(1) == 1)
                    result = true;
            }
            stmt.close();

            return result;
        }
        catch (Exception e) {
            throw new QueryEvaluationException(": SPARQL execute failed:["+query+"] \n Exception:"+e);
        }
    }


    protected void executeSPARQLForHandler(String baseURI,  TupleQueryResultHandler tqrh,
                                           String query, Dataset dataset, boolean includeInferred,
                                           BindingSet bindings, int maxQueryTime) throws QueryEvaluationException, TupleQueryResultHandlerException
    {
        LinkedList<String> names = new LinkedList<String>();
        try {
            PreparedStatement stmt = executeSPARQL(baseURI, query, dataset, includeInferred, bindings, maxQueryTime, false);
            ResultSet rs = stmt.executeQuery();
            ResultSetMetaData rsmd = rs.getMetaData();
            // begin at onset one
            for (int i = 1; i <= rsmd.getColumnCount(); i++)
                names.add(rsmd.getColumnName(i));

            tqrh.startQueryResult(names);
            // begin at onset one
            while (rs.next()) {
                QueryBindingSet qbs = new QueryBindingSet();
                for (int i = 1; i <= rsmd.getColumnCount(); i++) {
                    // TODO need to parse these into appropriate resource values
                    String col = rsmd.getColumnName(i);
                    Object val = rs.getObject(i);
                    if (val!=null){
                        Value v = castValue(val);
                        qbs.addBinding(col, v);
                    }
                }
                tqrh.handleSolution(qbs);
            }
            tqrh.endQueryResult();
            stmt.close();
        }
        catch (Exception e) {
            throw new QueryEvaluationException(": SPARQL execute failed:["+query+"] \n Exception:"+e);
        }
    }


    protected void executeSPARQLForHandler(String baseURI, RDFHandler tqrh, String query,
                                           Dataset dataset, boolean includeInferred, BindingSet bindings,
                                           int maxQueryTime) throws QueryEvaluationException, RDFHandlerException
    {
        try {
            PreparedStatement stmt = executeSPARQL(baseURI, query, dataset, includeInferred, bindings, maxQueryTime, false);
            ResultSet rs = stmt.executeQuery();
            ResultSetMetaData rsmd = rs.getMetaData();
            int col_g = -1;
            int col_s = -1;
            int col_p = -1;
            int col_o = -1;

            // begin at onset one
            for (int i = 1; i <= rsmd.getColumnCount(); i++) {
                String label = rsmd.getColumnName(i);
                if (label.equalsIgnoreCase("g"))
                    col_g = i;
                else if (label.equalsIgnoreCase("s"))
                    col_s = i;
                else if (label.equalsIgnoreCase("p"))
                    col_p = i;
                else if (label.equalsIgnoreCase("o"))
                    col_o = i;
            }

            tqrh.startRDF();
            while (rs.next()) {
                Resource sval = null;
                IRI pval = null;
                Value oval = null;
                Resource gval = null;

                if (col_s != -1)
                    sval = (Resource) castValue(rs.getObject(col_s));

                if (col_p != -1)
                    pval = (IRI) castValue(rs.getObject(col_p));

                if (col_o != -1)
                    oval = castValue(rs.getObject(col_o));

                if (col_g != -1)
                    gval = (Resource) castValue(rs.getObject(col_g));

                Statement st = valueFactory.createStatement(sval, pval, oval, gval);
                tqrh.handleStatement(st);
            }
            tqrh.endRDF();
            stmt.close();
        }
        catch (Exception e) {
            throw new QueryEvaluationException(": SPARQL execute failed:["+query+"] \n Exception:"+e);
        }
    }


    private PreparedStatement executeSPARQL(String baseURI, String query,
                                            Dataset dataset, boolean includeInferred, BindingSet bindings,
                                            int maxQueryTime, boolean isIUD) throws RepositoryException, SQLException
    {
        verifyIsOpen();
        flushDelayAdd();
        List<Value> pstmtParams = new ArrayList<Value>();
        String fixedQuery = fixQuery(false, query, dataset, includeInferred, bindings, pstmtParams, baseURI);
        PreparedStatement stmt = prepareStatement(fixedQuery, maxQueryTime, isIUD);
        setQueryParams(stmt, pstmtParams);
        return stmt;
    }

    protected void executeSPARUL(String baseURI, String query, Dataset dataset,
                                 boolean includeInferred, BindingSet bindings, int maxQueryTime) throws UpdateExecutionException
    {
        try {
            PreparedStatement stmt = executeSPARQL(baseURI, query, dataset, includeInferred, bindings, maxQueryTime, true);
            stmt.execute();
            stmt.close();
        }
        catch (Exception e) {
            throw new UpdateExecutionException(": SPARQL execute failed:["+query+"] \n Exception:"+e);
        }
    }


    /**
     * Execute SPARUL query on this repository.
     *
     * @param query
     *        The query string.
     * @return A rowUpdateCount.
     * @throws RepositoryException
     *         If the <tt>prepareQuery</tt> method is not supported by this
     *         repository.
     */
    public int executeSPARUL(String query) throws RepositoryException {

        java.sql.Statement stmt = null;
        try {
            verifyIsOpen();
            flushDelayAdd();
            stmt = createStatement(-1, true);
            stmt.execute("sparql\n " + query);
            return stmt.getUpdateCount();
        }
        catch (SQLException e) {
            throw new RepositoryException(": SPARQL execute failed:["+query+"] \n Exception:"+e);
        }
        finally {
            try {
                if (stmt != null)
                    stmt.close();
            } catch (Exception e) {}
        }
    }

    /**
     * Get Reposetory Connection.
     *
     * @return Repository Connection
     */
    public Connection getQuadStoreConnection() {
        return quadStoreConnection;
    }

    /**
     * Set Repository Connection.
     *
     * @param quadStoreConnection
     *        The Repository Connection.
     */
    public void setQuadStoreConnection(Connection quadStoreConnection) {
        this.quadStoreConnection = quadStoreConnection;
    }

    private int getJdbcConcurrency(boolean isIUD) {
        if (isIUD)
            switch(this.concurencyMode) {
                case VirtuosoRepository.CONCUR_PESSIMISTIC:
                    return VirtuosoResultSet.CONCUR_UPDATABLE;
                case VirtuosoRepository.CONCUR_OPTIMISTIC:
                    return VirtuosoResultSet.CONCUR_VALUES;
                default:
                    return VirtuosoResultSet.CONCUR_READ_ONLY;
            }
        else
            return VirtuosoResultSet.CONCUR_READ_ONLY;
    }

    private java.sql.Statement createStatement(int maxQueryTime, boolean isIUD) throws java.sql.SQLException
    {
        java.sql.Statement stmt = quadStoreConnection.createStatement(ResultSet.TYPE_FORWARD_ONLY, getJdbcConcurrency(isIUD));
        int timeout = queryTimeout;
        if (timeout > 0)
            stmt.setQueryTimeout(timeout);
        if (maxQueryTime > 0)
            stmt.setQueryTimeout(timeout);
        stmt.setFetchSize(prefetchSize);
        return stmt;
    }

    private java.sql.PreparedStatement prepareStatement(String sql, boolean isIUD) throws java.sql.SQLException
    {
        java.sql.PreparedStatement stmt = quadStoreConnection.prepareStatement(sql, ResultSet.TYPE_FORWARD_ONLY, getJdbcConcurrency(isIUD));
        int timeout = queryTimeout;
        if (timeout > 0)
            stmt.setQueryTimeout(timeout);
        stmt.setFetchSize(prefetchSize);
        return stmt;
    }

    private java.sql.PreparedStatement prepareStatement(String sql, int maxQueryTime, boolean isIUD) throws java.sql.SQLException
    {
        java.sql.PreparedStatement stmt = quadStoreConnection.prepareStatement(sql, ResultSet.TYPE_FORWARD_ONLY, getJdbcConcurrency(isIUD));
        int timeout = queryTimeout;
        if (timeout > 0)
            stmt.setQueryTimeout(timeout);
        if (maxQueryTime > 0)
            stmt.setQueryTimeout(timeout);
        stmt.setFetchSize(prefetchSize);
        return stmt;
    }

    private void setQueryParams(PreparedStatement stmt, List<Value> params) throws RepositoryException
    {
        int i = 0;
        for (Value value : params) {
            try {
                if (value instanceof Resource)
                    bindResource(stmt, ++i, (Resource)value);
                else
                    bindValue(stmt, ++i, value);
            } catch(SQLException e) {
                throw new RepositoryException("Failed to bind parameter " + value.toString() + " to the query.", e);
            }
        }
    }


    private String substBindings(String query, BindingSet bindings, List<Value> pstmtParams, boolean isSPARUL)  throws RepositoryException
    {
        boolean use_setParams = insertBNodeAsVirtuosoIRI ? false : true;
        StringBuilder tok = new StringBuilder();
        StringBuilder buf = new StringBuilder();
        String delim = " \t\n\r\f,)(;.}{";
        int inCurly = 0;
        int i = 0;
        char ch;
        boolean afterFROM = false;
        int qlen = query.length();

        while( i < qlen) {
            ch = query.charAt(i++);
            if (ch == '\\') {
                buf.append(ch);
                tok.append(ch);
                if (i < qlen) {
                    ch = query.charAt(i++);
                    buf.append(ch);
                    tok.append(ch);
                }

            } else if (ch == '"' || ch == '\'') {
                tok.setLength(0);
                char end = ch;
                buf.append(ch);
                while (i < qlen) {
                    ch = query.charAt(i++);
                    buf.append(ch);
                    if (ch == end)
                        break;
                }
            } else if ( ch == '{' ) {
                inCurly++;
                buf.append(ch);
                tok.setLength(0);
            } else if ( ch == '{' ) {
                inCurly--;
                buf.append(ch);
                tok.setLength(0);
            } else  if ( ch == '?' ) {  //Parameter
                tok.setLength(0);
                String varData = null;
                int j = i;
                while(j < qlen && delim.indexOf(query.charAt(j)) < 0) j++;
                if (j != i) {
                    boolean useBackSlash = (isSPARUL || inCurly > 0);
                    String varName = query.substring(i, j);
                    Value val = bindings.getValue(varName);
                    if (val != null) {
                        if (use_setParams) {
                            if (inCurly>0) { 
                                // in triple pattern
                            pstmtParams.add(val);
                            if (val instanceof Resource)
                                varData = "`iri(??)`";
                            else
                                varData = "`bif:__rdf_long_from_batch_params(??,??,??)`";
                        } else {
                                if (isSPARUL || afterFROM)
                                    varData = stringForValue(val, useBackSlash);
                                else
                                    varData = stringForValue(val, useBackSlash)+" AS ?"+varName;
                            }
                        } else {
                            if (inCurly==0 && !isSPARUL && !afterFROM) //for values in SELECT before triple pattern
                                varData = stringForValue(val, useBackSlash)+" AS ?"+varName;
                            else
                                varData = stringForValue(val, useBackSlash);
                        }

                        i=j;
                    }
                }
                if (varData != null)
                    buf.append(varData);
                else
                    buf.append(ch);
            } else {
                buf.append(ch);
                if (delim.indexOf(ch) < 0) {
                    tok.append(ch);
                } else {
                    if (tok.length()==4 
                        && (tok.charAt(0)=='F' || tok.charAt(0)=='f')
                        && tok.toString().equalsIgnoreCase("FROM")
                       )
                        afterFROM = true;
                    tok.setLength(0);
                }
            }
        }
        return buf.toString();
    }


    private String fixQuery(boolean isSPARUL, String query, Dataset dataset, boolean includeInferred, BindingSet bindings, List<Value> pstmtParams, String baseURI)  throws RepositoryException
    {
        boolean added_def_graph = false;
        Set <IRI> list;
        String removeGraph = null;
        String insertGraph = null;

        if (dataset != null)
        {
            //TODO update later, when support of new defines will be added
            list = dataset.getDefaultRemoveGraphs();
            if (list!=null)
            {
                if (list.size()>1)
                    throw new RepositoryException("Only ONE DefaultRemoveGraph is supported");

                Iterator<IRI> it = list.iterator();
                while(it.hasNext())
                {
                    removeGraph = " <"+it.next().toString()+"> ";
                    break;
                }
            }

            IRI g = dataset.getDefaultInsertGraph();
            if (g!=null)
                insertGraph = " <"+g.toString()+"> ";
        }

        query = SubstGraphs(query, insertGraph, removeGraph);

        StringBuilder ret = new StringBuilder("sparql\n");

        if (baseURI!=null && baseURI.length()>0)
            ret.append(" define input:grab-base <" + baseURI + "> \n");

        if (includeInferred && ruleSet!=null && ruleSet.length() > 0)
            ret.append("define input:inference '"+ruleSet+"'\n ");

        if (includeInferred && macroLib!=null && macroLib.length() > 0)
            ret.append("define input:macro-lib <"+macroLib+">\n ");

        if (dataset != null)
        {
            list = dataset.getDefaultGraphs();
            if (list != null)
            {
                Iterator<IRI> it = list.iterator();
                while(it.hasNext())
                {
                    IRI v = it.next();
                    ret.append(" define input:default-graph-uri <" + v.toString() + "> \n");
                    added_def_graph = true;
                }
            }

            list = dataset.getNamedGraphs();
            if (list != null)
            {
                Iterator<IRI> it = list.iterator();
                while(it.hasNext())
                {
                    IRI v = it.next();
                    ret.append(" define input:named-graph-uri <" + v.toString() + "> \n");
                }
            }
        }

	if (!added_def_graph && useDefGraphForQueries)
            ret.append(" define input:default-graph-uri <" + defGraph + "> \n");

        ret.append(substBindings(query, bindings, pstmtParams, isSPARUL));
        return ret.toString();
    }


    private String SubstGraphs(String query, String gInsert, String gDelete)
    {
        ArrayList<String> lst = new ArrayList<String>(16);
        StringBuilder buf = new StringBuilder();
        String delim = "{} \t\n\r\f";
        int i = 0;
        char ch;
        int qlen = query.length();

        while( i < qlen) {
            ch = query.charAt(i++);

            if (delim.indexOf(ch)>=0) {
                if (buf.length()>0) {
                    lst.add(buf.toString());
                    buf.setLength(0);
                }
                lst.add(""+ch);
            }
            else if (ch == '\\') {
                buf.append(ch);
                if (i < qlen)
                    buf.append(query.charAt(i++));

            }
            else if (ch == '"' || ch == '\'') {
                char end = ch;
                buf.append(ch);
                while (i < qlen) {
                    ch = query.charAt(i++);
                    buf.append(ch);
                    if (ch == end)
                        break;
                }

            } else {
                buf.append(ch);
            }
        }

        if (buf.length()>0)
            lst.add(buf.toString());

        if (gInsert!=null)
            fixTermOp(lst, "INSERT", "INTO", gInsert);
        if (gDelete!=null)
            fixTermOp(lst, "DELETE", "FROM", gDelete);

        buf.setLength(0);
        for(i=0; i<lst.size(); i++)
            buf.append(lst.get(i));

        return buf.toString();
    }

    /**
     * NOTES:
     * if WITH exists, it doesn't use addTerm
     * if GRAPH exists, it doesn't use addTerm
     * if INSERT INTO exists, it doesn't use addTerm
     * if DELETE FROM exists, it doesn't use addTerm
     **/
    private void fixTermOp(ArrayList<String> lst, String term, String subTerm, String addTerm)
    {
        int i;
        boolean WITH_used = false;
        boolean subTerm_used = false;
        boolean GRAPH_used = false;
        int in_term = -1;
        int term_cb_start = -1;

        for(i=0; i<lst.size(); i++) {
            String t = lst.get(i);

            if (t.equalsIgnoreCase("WITH") && in_term==-1) {
                WITH_used = true;
            }
            else if (t.equalsIgnoreCase(term)) {
                in_term = 0;
            }
            else if (t.equalsIgnoreCase(subTerm) && in_term==0) {
                subTerm_used = true;
            }
            else if (t.equals("{")) {
                if (in_term >=0) in_term++;

                if (in_term == 1)
                    term_cb_start = i;
            }
            else if (t.equals("}")) {
                if (in_term == 1)
                    in_term = -1;
                else
                    in_term--;
            }
            else if (t.equalsIgnoreCase("GRAPH")){
                if (in_term == 1)
                    GRAPH_used = true;
            }
        }

        if (addTerm!=null && !WITH_used && !subTerm_used && !GRAPH_used
                && term_cb_start!=-1) {
            lst.add(term_cb_start, " "+subTerm + addTerm);
        }
    }


    private synchronized void addToQuadStore(Resource subject, IRI predicate, Value object, Resource... contexts) throws RepositoryException
    {
        if (contexts.length == 0)
            return;

        try {
            boolean isAutoCommit = getQuadStoreConnection().getAutoCommit();

            if (psInsert == null)
                psInsert = prepareStatement(S_BATCH_INSERT, true);

            if (!insertBNodeAsVirtuosoIRI) {
                if (psInsert_BNode == null)
                    psInsert_BNode = prepareStatement(S_TTLP_INSERT, true);

                Object bn_s = null;
                Object bn_o = null;

                if (subject instanceof BNode)
                    bn_s = "_:"+((BNode)subject).getID().replace(':','_').replace('-','z').replace('/','y');
                if (object instanceof BNode) {
                    bn_o = "_:"+((BNode)object).getID().replace(':','_').replace('-','z').replace('/','y');
                }

                if (bn_s!=null || bn_o!=null) {
                    addToQuadStore_BNode(
                            bn_s!=null?bn_s:subject,
                            predicate,
                            bn_o!=null?bn_o:object, contexts);
                    psInsertBNodeCount += contexts.length;
                } else {
                    addToQuadStore_asURI(subject, predicate, object, contexts);
                    psInsertCount += contexts.length;
                }

            } else {
                addToQuadStore_asURI(subject, predicate, object, contexts);
                psInsertCount += contexts.length;
            }

            if (!isAutoCommit && useLazyAdd) {
                if (psInsertCount >= BATCH_SIZE || psInsertBNodeCount >= BATCH_SIZE)
                    flushDelayAdd();
            } else {
                flushDelayAdd();
            }
        }
        catch (Exception e) {
            throw new RepositoryException(e);
        }
    }


    private synchronized void addToQuadStore_BNode(Object subject, IRI predicate,
                                                   Object object, Resource... contexts) throws RepositoryException
    {
        if (contexts.length == 0)
            return;

        verifyIsOpen();
        try {
            int transactional = quadStoreConnection.getAutoCommit()?0:1;

            for (Resource context : contexts) {

                String ctx = context.stringValue();
                StringBuilder sb = new StringBuilder(256);
                append(subject, sb, true);
                sb.append(' ');
                append(predicate, sb, true);
                sb.append(' ');
                append(object, sb, true);
                sb.append(" .\n");

                psInsert_BNode.setString(1, sb.toString());
                psInsert_BNode.setString(2, ctx);
                psInsert_BNode.setInt(3, transactional);
                psInsert_BNode.addBatch();
            }
        }
        catch (Exception e) {
            throw new RepositoryException(e);
        }
    }


    private synchronized void addToQuadStore_asURI(Resource subject, IRI predicate,
                                                   Value object, Resource... contexts) throws RepositoryException
    {
        verifyIsOpen();

        try {
            for (Resource context : contexts) {
                bindParams(psInsert, subject, predicate, object, context);
                psInsert.addBatch();
            }
        }
        catch (Exception e) {
            throw new RepositoryException(e);
        }
    }


    private void bindParams(PreparedStatement ps,
                            Resource subject, IRI predicate, Value object, Resource context) throws SQLException, RepositoryException
    {
        int flags = 0;

        if (!insertBNodeAsVirtuosoIRI && (object instanceof BNode))
            flags = 15;

        flags |= (subject instanceof BNode) ?0x0100:0;
        flags |= (object instanceof BNode) ?0x0200:0;

        ps.setString(1, subject.toString());
        ps.setString(2, predicate.toString());

        if (object instanceof Resource)
        {
            ps.setString(3,  object.toString());
            ps.setNull(4, java.sql.Types.VARCHAR);
        }
        else if (object instanceof Literal)
        {
            Literal lit = (Literal) object;
            Optional<String> lang = lit.getLanguage();
            ps.setString(3, lit.getLabel());

            if (lang.isPresent())
            {
                ps.setString(4, lang.get());
                flags |= 2;

            }
            else if (lit.getDatatype() != null)
            {
                IRI ltype = lit.getDatatype();

                if (insertStringLiteralAsSimple && ltype.equals(XMLSchema.STRING)) {
                    ps.setNull(4, java.sql.Types.VARCHAR);
                    flags |= 1;
                } else {
                  ps.setString(4, ltype.toString());

                  if (ltype.equals(XMLSchema.INTEGER))
                    flags |= 5;
                  else if (ltype.equals(XMLSchema.FLOAT))
                    flags |= 6;
                  else if (ltype.equals(XMLSchema.DOUBLE))
                    flags |= 7;
                  else if (ltype.equals(XMLSchema.DECIMAL))
                    flags |= 8;
                  else
                    flags |= 3;
                }
            }
            else
            {
                ps.setNull(4, java.sql.Types.VARCHAR);
                flags |= 1;
            }
        }
        else
        {
            throw new RepositoryException("Unknown value type: " + object.getClass());
        }

        ps.setInt(5, flags);

        ps.setString(6, context.toString());
    }


    private synchronized PreparedStatement addToQuadStore_batch(PreparedStatement ps,
                                                                Resource subject,
                                                                IRI predicate,
                                                                Value object,
                                                                Resource... contexts) throws RepositoryException
    {
        verifyIsOpen();

        try {
            if (ps == null)
                ps = prepareStatement(VirtuosoRepositoryConnection.S_BATCH_INSERT, true);

            for (Resource context : contexts) {
                bindParams(ps, subject, predicate, object, context);
                ps.addBatch();
            }
        }
        catch (Exception e) {
            throw new RepositoryException(e);
        }
        return ps;
    }



    private synchronized PreparedStatement flushDelayAdd_batch(PreparedStatement ps,
                                                               int psCount) throws RepositoryException
    {
        try {
            if (psCount > 0 && ps!=null) {
                ps.executeBatch();
                ps.clearBatch();
                if (useReprepare) {
                    try{
                        ps.close();
                    } catch(Exception e){}
                    ps = null;
                }
            }
        }
        catch (Exception e) {
            throw new RepositoryException(e);
        }
        return ps;
    }


    private synchronized PreparedStatement dropDelayAdd_batch(PreparedStatement ps,
                                                              int psCount) throws RepositoryException
    {
        try {
            if (psCount > 0 && ps!=null) {
                ps.clearBatch();
                if (useReprepare) {
                    try{
                        ps.close();
                    } catch(Exception e){}
                    ps = null;
                }
            }
        } catch (Exception e) {
            throw new RepositoryException(e);
        }
        return ps;
    }


    private synchronized void flushDelayAdd() throws RepositoryException
    {
        psInsert = flushDelayAdd_batch(psInsert, psInsertCount);
        psInsertCount = 0;
        if (psInsert_BNode!=null && psInsertBNodeCount > 0)
            try {
                psInsert_BNode.executeBatch();
                psInsert_BNode.clearBatch();
            }
            catch (Exception e) {
                throw new RepositoryException(e);
            }
        psInsertBNodeCount = 0;
    }

    private synchronized void dropDelayAdd() throws RepositoryException
    {
        psInsert = dropDelayAdd_batch(psInsert, psInsertCount);
        psInsertCount = 0;
        if (psInsertBNodeCount > 0 && psInsert_BNode!=null)
            try {
                psInsert_BNode.clearBatch();
            } catch (Exception e) {
                throw new RepositoryException(e);
            }
        psInsertBNodeCount = 0;
    }


    private void append(Object value, StringBuilder sb, boolean inTriplePattern)
            throws RepositoryException
    {
        if (value instanceof Resource) {
            append((Resource)value, sb, inTriplePattern);
        }
        else if (value instanceof Literal) {
            append((Literal)value, sb, inTriplePattern);
        }
        else if (value instanceof String) {
            sb.append((String)value);
        }
        else {
            throw new RepositoryException("Unknown value type: " + value.getClass());
        }
    }

    private void append(Resource resource, StringBuilder sb, boolean inTriplePattern)
            throws RepositoryException
    {
        if (resource instanceof IRI) {
            append((IRI)resource, sb, inTriplePattern);
        }
        else if (resource instanceof BNode) {
            append((BNode)resource, sb, inTriplePattern);
        }
        else {
            throw new RepositoryException("Unknown resource type: " + resource.getClass());
        }
    }

    private void append(IRI uri, StringBuilder sb, boolean inTriplePattern)
            throws RepositoryException
    {
        sb.append("<");
        escapeString(uri.toString(), sb);
        sb.append(">");
    }


    private void append(BNode bNode, StringBuilder sb, boolean inTriplePattern)
            throws RepositoryException
    {
        String bid = bNode.getID();
        if (bid.startsWith("nodeID://")) {
            if (inTriplePattern)
                sb.append("`");

            sb.append("iri('");
            sb.append(bid);
            sb.append("')");

            if (inTriplePattern)
                sb.append("`");
        } else {
            if (insertBNodeAsVirtuosoIRI) {
                sb.append("<");
                sb.append(bNode.toString());
                sb.append(">");
            } else {
                sb.append(bNode.toString());
            }
        }
    }


    private void append(Literal lit, StringBuilder sb, boolean inTriplePattern)
            throws RepositoryException
    {
        sb.append("\"");
        escapeString(lit.getLabel(), sb);
        sb.append("\"");

        if (lit.getDatatype() != null) {
            // Append the literal's datatype
            IRI ltype = lit.getDatatype();
            if (!(insertStringLiteralAsSimple && ltype.equals(XMLSchema.STRING))) {
                sb.append("^^");
                append(ltype, sb, inTriplePattern);
            }
        }
        else if (lit.getLanguage() != null) {
            // Append the literal's language
            sb.append("@");
            sb.append(lit.getLanguage());
        }
    }

    private String BNode2String(BNode bNode)
    {
        String bid = bNode.getID();
        if (bid.startsWith("nodeID://"))
            return bid;
        else
            return bNode.toString();
    }

    private void escapeString(String label, StringBuilder sb)
            throws RepositoryException
    {
        int labelLength = label.length();

        for (int i = 0; i < labelLength; i++) {
            char c = label.charAt(i);
            int cInt = c;

            if (c == '\\') {
                sb.append("\\\\");
            }
            else if (c == '"') {
                sb.append("\\\"");
            }
            else if (c == '\n') {
                sb.append("\\n");
            }
            else if (c == '\r') {
                sb.append("\\r");
            }
            else if (c == '\t') {
                sb.append("\\t");
            }
            else if (
                    cInt >= 0x0 && cInt <= 0x8 ||
                            cInt == 0xB || cInt == 0xC ||
                            cInt >= 0xE && cInt <= 0x1F ||
                            cInt >= 0x7F && cInt <= 0xFFFF)
            {
                sb.append("\\u");
                sb.append(toHexString(cInt, 4));
            }
            else if (cInt >= 0x10000 && cInt <= 0x10FFFF) {
                sb.append("\\U");
                sb.append(toHexString(cInt, 8));
            }
            else {
                sb.append(c);
            }
        }
    }

    private String toHexString(int decimal, int stringLength) {
        StringBuilder sb = new StringBuilder(stringLength);
        String hexVal = Integer.toHexString(decimal).toUpperCase();

        int nofZeros = stringLength - hexVal.length();
        for (int i = 0; i < nofZeros; i++)
            sb.append('0');

        sb.append(hexVal);
        return sb.toString();
    }



    private void clearQuadStore(Resource[] contexts) throws RepositoryException {

        if (contexts!=null && contexts.length > 0)
            try {
                String [] graphs = new String[contexts.length];
                PreparedStatement ps = prepareStatement(S_CLEAR_GRAPH, true);
                for (int i = 0; i < contexts.length; i++)
                    graphs[i] = contexts[i].stringValue();

                Array gArray = quadStoreConnection.createArrayOf ("VARCHAR", graphs);
                ps.setArray (1, gArray);
                ps.executeUpdate ();
                ps.close();
                gArray.free();
            }
            catch (Exception e) {
                throw new RepositoryException(e);
            }
    }


    private CloseableIteration<Statement, RepositoryException> selectFromQuadStore(Resource subject, IRI predicate, Value object, boolean includeInferred, boolean hasOnly, Resource... contexts) throws RepositoryException {
        verifyIsOpen();
        flushDelayAdd();

        ResultSet rs = null;
        StringBuilder query = new StringBuilder("sparql ");

        if (includeInferred && ruleSet != null && ruleSet.length() > 0)
            query.append("define input:inference '"+ruleSet+"' ");

        if (includeInferred && macroLib!=null && macroLib.length() > 0)
            query.append("define input:macro-lib <"+macroLib+">\n ");

        query.append("select * ");

        for (Resource context : contexts) {

            query.append("from named <");
            query.append(context.toString());
            query.append("> ");
        }

        query.append("where { graph ?g {");

        query.append(' ');
        if (subject != null)
            query.append("`iri(??)`");
        else
            query.append("?s");

        query.append(' ');
        if (predicate != null)
            query.append("`iri(??)`");
        else
            query.append("?p");

        query.append(' ');
        if (object != null)
            query.append("`bif:__rdf_long_from_batch_params(??,??,??)`");
        else
            query.append("?o");

        query.append(" }}");
        if (hasOnly)
            query.append(" LIMIT 1");

        PreparedStatement ps;
        try {
            ps = prepareStatement(query.toString(), false);
            int col = 1;

            if (subject != null)
                bindResource(ps, col++, subject);
            if (predicate != null)
                bindURI(ps, col++, predicate);
            if (object != null)
                bindValue(ps, col, object);

            rs = ps.executeQuery();
        }
        catch (Exception e) {
            throw new RepositoryException(getClass().getCanonicalName() + ": SPARQL execute failed." + "\n" + query.toString() + "[" + e + "]", e);
        }

        return new CloseableIterationStmt(ps, rs, subject, predicate, object);
    }



    private void removeData(Map<String,StringBuilder> data) throws RepositoryException
    {
        java.sql.Statement stmt = null;
        try {
            stmt = createStatement(-1, true);
            for(Map.Entry<String,StringBuilder> e : data.entrySet()) {

                StringBuilder sb = new StringBuilder(256);
                sb.append("sparql define output:format '_JAVA_' DELETE FROM <");
                sb.append(e.getKey());
                sb.append("> { ");
                sb.append(e.getValue().toString());
                sb.append(" }");

                stmt.execute(sb.toString());
            }
        }
        catch (Exception e) {
            throw new RepositoryException(e);
        }
        finally {
            try {
                if (stmt!=null)
                    stmt.close();
            } catch (Exception e) {}
        }
    }


    private void removeContext(Resource subject, IRI predicate, Value object, Resource context) throws RepositoryException
    {
        try {

            if (subject == null && predicate == null && object == null && context != null) {
                String  query = "sparql clear graph iri(??)";

                PreparedStatement ps = prepareStatement(query, true);
                ps.setString(1, context.toString());
                ps.execute();
                ps.close();

            } else if (subject != null && predicate != null && object != null && context != null) {

                PreparedStatement ps = prepareStatement(VirtuosoRepositoryConnection.S_DELETE, true);

                ps.setString(1, context.toString());
                bindResource(ps, 2, subject);
                bindURI(ps, 3, predicate);
                bindValue(ps, 4, object);
                ps.execute();
                ps.close();

            } else {

                if (context == null)
                    throw new RepositoryException("Context can't be NULL");

                StringBuilder stm = new StringBuilder();

                stm.append(' ');
                if (subject != null)
                    stm.append("`iri(??)`");
                else
                    stm.append("?s");

                stm.append(' ');
                if (predicate != null)
                    stm.append("`iri(??)`");
                else
                    stm.append("?p");

                stm.append(' ');
                if (object != null)
                    stm.append("`bif:__rdf_long_from_batch_params(??,??,??)`");
                else
                    stm.append("?o");

                String query = "sparql delete from <"+context+"> { "+
                        stm.toString()+" } where { "+stm.toString()+" }";

                java.sql.PreparedStatement ps = prepareStatement(query, true);
                int col = 1;

                if (subject != null)
                    bindResource(ps, col++, subject);
                if (predicate != null)
                    bindURI(ps, col++, predicate);
                if (object != null) {
                    bindValue(ps, col, object);
                    col +=3;
                }

                if (subject != null)
                    bindResource(ps, col++, subject);
                if (predicate != null)
                    bindURI(ps, col++, predicate);
                if (object != null)
                    bindValue(ps, col, object);

                ps.execute();
                ps.close();
            }
        }
        catch (Exception e) {
            throw new RepositoryException(e);
        }
    }


    // Used for Remove and Select
    private void bindResource(PreparedStatement ps, int col, Resource n) throws SQLException {
        if (n == null)
            return;
        if (n instanceof BNode)
            ps.setString(col, BNode2String((BNode)n));
        else
            ps.setString(col, n.toString());
    }


    private void bindURI(PreparedStatement ps, int col, IRI n) throws SQLException {
        if (n == null)
            return;
        ps.setString(col, n.toString());
    }


    private void bindValue(PreparedStatement ps, int col, Value n) throws SQLException {
        if (n == null)
            return;
        if (n instanceof IRI) {
            ps.setInt(col, 1);
            ps.setString(col+1, n.toString());
            ps.setNull(col+2, java.sql.Types.VARCHAR);
        }
        else if (n instanceof BNode) {
            ps.setInt(col, 1);  // must be 1 for search
            ps.setString(col+1, BNode2String((BNode)n));
            ps.setNull(col+2, java.sql.Types.VARCHAR);
        }
        else if (n instanceof Literal) {
            Literal lit = (Literal) n;
            Optional<String> lang = lit.getLanguage();
            if (lang.isPresent()) {
                ps.setInt(col, 5);
                ps.setString(col+1, lit.getLabel());
                ps.setString(col+2, lang.get());
            }
            else if (lit.getDatatype() != null) {
                IRI ltype = lit.getDatatype();
                if (!(insertStringLiteralAsSimple && ltype.equals(XMLSchema.STRING))) {
                    ps.setInt(col, 4);
                    ps.setString(col+1, lit.getLabel());
                    ps.setString(col+2, ltype.toString());
                } else {
                    ps.setInt(col, 3);
                    ps.setString(col+1, lit.getLabel());
                    ps.setNull(col+2, java.sql.Types.VARCHAR);
                }
            }
            else {
                ps.setInt(col, 3);
                ps.setString(col+1, lit.getLabel());
                ps.setNull(col+2, java.sql.Types.VARCHAR);
            }
        }
        else {
            ps.setInt(col, 3);
            ps.setString(col+1, n.toString());
            ps.setNull(col+2, java.sql.Types.VARCHAR);
        }
    }



    private String stringForValue(Value n, boolean inTriplePattern)  throws RepositoryException {
        StringBuilder sb = new StringBuilder(256);
        append(n, sb, inTriplePattern);
        return sb.toString();
    }


    private Value castValue(Object val) throws RepositoryException {
        if (val == null)
            return null;
        if (val instanceof ExtendedString) {
            ExtendedString ves = (ExtendedString) val;
            String valueString = ves.toString();
            if (ves.getIriType() == ExtendedString.IRI && (ves.getStrType() & 0x01)==0x01) {
                if (valueString.startsWith("_:")) {
                    valueString = valueString.substring(2);
                    return valueFactory.createBNode(valueString);
                }
                try {
                    if (valueString.indexOf(':') < 0)
                        return valueFactory.createIRI(":" + valueString);
                    else
                        return valueFactory.createIRI(valueString);
                }
                catch (IllegalArgumentException iaex) {
                    throw new RepositoryException("VirtuosoRepositoryConnection().castValue() Invalid value from Virtuoso: \"" + valueString + "\"", iaex);
                }
            }
            else if (ves.getIriType() == ExtendedString.BNODE) {
                try {
                    return valueFactory.createBNode(valueString);
                }
                catch (IllegalArgumentException iaex) {
                    throw new RepositoryException("VirtuosoRepositoryConnection().castValue() Invalid value from Virtuoso: \"" + valueString + "\"", iaex);
                }
            }
            else {
                try {
                    return valueFactory.createLiteral(valueString);
                }
                catch (IllegalArgumentException iaex) {
                    throw new RepositoryException("VirtuosoRepositoryConnection().castValue() Invalid value from Virtuoso: \"" + valueString + "\", STRTYPE = " + ves.getIriType(), iaex);
                }
            }
        }
        else if (val instanceof RdfBox) {
            RdfBox rb = (RdfBox) val;
            String rb_val = rb.toString();

            if (rb.getLang() != null) {
                return valueFactory.createLiteral(rb_val, rb.getLang());
            }
            else if (rb.getType() != null) {
                String rb_type = rb.getType();
                if (rb_val.length()==1 && (rb_val.charAt(0)=='1' || rb_val.charAt(0)=='0')) {
                    if (rb_type.equals("http://www.w3.org/2001/XMLSchema#boolean"))
                        return valueFactory.createLiteral(rb_val.charAt(0)=='1'?true:false); //  return getRepository().getValueFactory().createLiteral(rb_val.charAt(0)=='1'?"true":"false", this.getRepository().getValueFactory().createURI(rb_type));
                }
                return valueFactory.createLiteral(rb_val, valueFactory.createIRI(rb_type));
            }
            else {
                return getRepository().getValueFactory().createLiteral(rb_val);
            }
        }
        else if (val instanceof java.lang.Long) {
            return valueFactory.createLiteral(((Long) val).longValue());
        }
        else if (val instanceof java.lang.Integer) {
            return valueFactory.createLiteral(((Integer) val).intValue());
        }
        else if (val instanceof java.lang.Short) {
            return valueFactory.createLiteral(((Short) val).intValue());
        }
        else if (val instanceof java.lang.Float) {
            return valueFactory.createLiteral(((Float) val).floatValue());
        }
        else if (val instanceof java.lang.Double) {
            return valueFactory.createLiteral(((Double) val).doubleValue());
        }
        else if (val instanceof java.math.BigDecimal) {
            IRI type = valueFactory.createIRI("http://www.w3.org/2001/XMLSchema#decimal");
            return valueFactory.createLiteral(val.toString(), type);
        }
        else if (val instanceof java.sql.Blob) {
            IRI type = valueFactory.createIRI("http://www.w3.org/2001/XMLSchema#hexBinary");
            return valueFactory.createLiteral(val.toString(), type);
        }
        else if (val instanceof VirtuosoDate) {
            IRI type = valueFactory.createIRI("http://www.w3.org/2001/XMLSchema#date");
            return valueFactory.createLiteral(((VirtuosoDate)val).toXSD_String(), type);
        }
        else if (val instanceof VirtuosoTimestamp) {
            IRI type = valueFactory.createIRI("http://www.w3.org/2001/XMLSchema#dateTime");
            return valueFactory.createLiteral(((VirtuosoTimestamp)val).toXSD_String(), type);
        }
        else if (val instanceof VirtuosoTime) {
            IRI type = valueFactory.createIRI("http://www.w3.org/2001/XMLSchema#time");
            return valueFactory.createLiteral(((VirtuosoTime)val).toXSD_String(), type);
        }
        else if (val instanceof java.sql.Date) {
            IRI type = valueFactory.createIRI("http://www.w3.org/2001/XMLSchema#date");
            return valueFactory.createLiteral(val.toString(), type);
        }
        else if (val instanceof java.sql.Timestamp) {
            IRI type = valueFactory.createIRI("http://www.w3.org/2001/XMLSchema#dateTime");
            return valueFactory.createLiteral(Timestamp2String((java.sql.Timestamp)val), type);
        }
        else if (val instanceof java.sql.Time) {
            IRI type = valueFactory.createIRI("http://www.w3.org/2001/XMLSchema#time");
            return valueFactory.createLiteral(val.toString(), type);
        }
        else { // if(val instanceof String) {
            try {
                return getRepository().getValueFactory().createLiteral(val.toString());
            }
            catch (IllegalArgumentException iaex2) {
                throw new RepositoryException("VirtuosoRepositoryConnection().castValue() Could not parse resource: " + val, iaex2);
            }
        }
    }


    /**
     * Creates a RepositoryResult for the supplied element set.
     */
    protected <E> RepositoryResult<E> createRepositoryResult(Iterable<? extends E> elements) {
        return new RepositoryResult<E>(new CloseableIteratorIteration<E, RepositoryException>(elements.iterator()));
    }


    private void verifyIsOpen() throws RepositoryException {
        try {
            if (this.getQuadStoreConnection().isClosed())
                throw new IllegalStateException("Connection has been closed");
        }
        catch (SQLException e) {
            throw new RepositoryException(e);
        }
    }


    protected void verifyNotTxnActive(String msg)
            throws RepositoryException
    {
        if (!isAutoCommit()) {
            throw new RepositoryException(msg);
        }
    }

    /**
     protected void verifyTxnActive()
     throws StoreException
     {
     if (isAutoCommit()) {
     throw new RepositoryException("Connection does not have an active transaction");
     }
     }
     **/

    public abstract class CloseableIterationBase<E, X extends Exception> implements CloseableIteration<E, X>
    {
        E	  v_row;
        boolean	  v_finished = false;
        boolean	  v_prefetched = false;
        Resource  subject;
        IRI       predicate;
        Value 	  object;
        ResultSet v_rs;
        java.sql.Statement v_stmt;

        public CloseableIterationBase(java.sql.Statement stmt, ResultSet rs, Resource subject, IRI predicate, Value object)
        {
            v_stmt = stmt;
            v_rs = rs;
            this.subject = subject;
            this.predicate = predicate;
            this.object = object;
        }


        protected abstract X createException(Exception e);

        public boolean hasNext() throws X
        {
            if (!v_finished && !v_prefetched)
                moveForward();
            return !v_finished;
        }

        public E next() throws X
        {
            if (!v_finished && !v_prefetched)
                moveForward();

            v_prefetched = false;

            if (v_finished)
                throw new NoSuchElementException();

            return v_row;
        }

        public void remove() throws X
        {
            throw new UnsupportedOperationException();
        }

        public void close() throws X
        {
            if (!v_finished)
            {
                try
                {
                    v_rs.close();
                    v_stmt.close();
                }
                catch (SQLException e)
                {
                    throw createException(e);
                }
            }
            v_finished = true;
        }

        protected void finalize() throws Throwable
        {
            super.finalize();
            if (!v_finished)
                try {
                    close();
                } catch (Exception e) {}
        }

        protected void moveForward() throws X
        {
            try
            {
                if (!v_finished && v_rs.next())
                {
                    extractRow();
                    v_prefetched = true;
                }
                else
                    close();
            }
            catch (Exception e)
            {
                throw createException(e);
            }
        }

        protected abstract void extractRow() throws Exception;
    }


    public class CloseableIterationStmt extends CloseableIterationBase<Statement, RepositoryException> {

        int col_g = -1;
        int col_s = -1;
        int col_p = -1;
        int col_o = -1;

        public CloseableIterationStmt(java.sql.Statement stmt, ResultSet rs, Resource subject, IRI predicate, Value object) throws RepositoryException
        {
            super(stmt, rs, subject, predicate, object);
            try {
                ResultSetMetaData rsmd = rs.getMetaData();
                for (int i = 1; i <= rsmd.getColumnCount(); i++) {
                    String label = rsmd.getColumnName(i);
                    if (label.equalsIgnoreCase("g"))
                        col_g = i;
                    else if (label.equalsIgnoreCase("s"))
                        col_s = i;
                    else if (label.equalsIgnoreCase("p"))
                        col_p = i;
                    else if (label.equalsIgnoreCase("o"))
                        col_o = i;
                }
            } catch (Exception e) {
                throw createException(e);
            }
        }

        protected RepositoryException createException(Exception e) {
            return new RepositoryException(e);
        }

        protected void extractRow() throws Exception
        {
            Resource _graph = null;
            Resource _subject = subject;
            IRI _predicate = predicate;
            Value _object = object;
            Object val = null;

            try {
                if (col_g != -1) {
                    val = v_rs.getObject(col_g);
                    _graph = (Resource) castValue(val);
                }
            }
            catch (ClassCastException ccex) {
                throw new RepositoryException("Unexpected resource type encountered. Was expecting Resource: " + val, ccex);
            }

            if (_subject == null && col_s != -1)
                try {
                    val = v_rs.getObject(col_s);
                    _subject = (Resource) castValue(val);
                }
                catch (ClassCastException ccex) {
                    throw new RepositoryException("Unexpected resource type encountered. Was expecting Resource: " + val, ccex);
                }

            if (_predicate == null && col_p != -1)
                try {
                    val = v_rs.getObject(col_p);
                    _predicate = (IRI) castValue(val);
                }
                catch (ClassCastException ccex) {
                    throw new RepositoryException("Unexpected resource type encountered. Was expecting URI: " + val, ccex);
                }

            if (_object == null && col_o != -1)
                _object = castValue(v_rs.getObject(col_o));

            v_row = valueFactory.createStatement(_subject,_predicate,_object,_graph);
        }
    }



    public class CloseableIterationBindingSet extends CloseableIterationBase<BindingSet, QueryEvaluationException> {

        ResultSetMetaData rsmd;

        public CloseableIterationBindingSet(java.sql.Statement stmt, ResultSet rs) throws QueryEvaluationException
        {
            super(stmt, rs, null, null, null);
            try {
                rsmd = rs.getMetaData();
            } catch (Exception e) {
                throw createException(e);
            }
        }

        protected QueryEvaluationException createException(Exception e) {
            return new QueryEvaluationException(e);
        }

        protected void extractRow() throws Exception
        {
            v_row = new QueryBindingSet();
            for (int i = 1; i <= rsmd.getColumnCount(); i++) {
                String col = rsmd.getColumnName(i);
                Object val = v_rs.getObject(i);
                if (val!=null) {
                    Value v = castValue(val);
                    ((QueryBindingSet)v_row).setBinding(col, v);
                }
            }
        }
    }


    public class CloseableIterationGraphResult extends CloseableIterationBase<Statement, QueryEvaluationException> {

        int col_g = -1;
        int col_s = -1;
        int col_p = -1;
        int col_o = -1;

        public CloseableIterationGraphResult(java.sql.Statement stmt, ResultSet rs) throws QueryEvaluationException
        {
            super(stmt, rs, null, null, null);

            try {
                ResultSetMetaData rsmd = rs.getMetaData();

                // begin at onset one
                for (int i = 1; i <= rsmd.getColumnCount(); i++) {
                    String label = rsmd.getColumnName(i);
                    if (label.equalsIgnoreCase("G"))
                        col_g = i;
                    else if (label.equalsIgnoreCase("S"))
                        col_s = i;
                    else if (label.equalsIgnoreCase("P"))
                        col_p = i;
                    else if (label.equalsIgnoreCase("O"))
                        col_o = i;
                }
            } catch (Exception e) {
                throw createException(e);
            }
        }

        protected QueryEvaluationException createException(Exception e) {
            return new QueryEvaluationException(e);
        }

        protected void extractRow() throws Exception
        {
            Resource sval = null;
            IRI pval = null;
            Value oval = null;
            Resource gval = null;

            if (col_s != -1)
                sval = (Resource) castValue(v_rs.getObject(col_s));

            if (col_p != -1)
                pval = (IRI) castValue(v_rs.getObject(col_p));

            if (col_o != -1)
                oval = castValue(v_rs.getObject(col_o));

            if (col_g != -1)
                gval = (Resource) castValue(v_rs.getObject(col_g));

            v_row = valueFactory.createStatement(sval,pval,oval,gval);
        }
    }


    private String Timestamp2String(java.sql.Timestamp v)
    {
        GregorianCalendar cal = new GregorianCalendar();
        int timezone = cal.get(Calendar.ZONE_OFFSET)/60000; //min

        StringBuilder sb = new StringBuilder();
        DateFormat formatter= new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss");
        String nanosString;
        String timeZoneString = null;
        String zeros = "000000000";
        int nanos = v.getNanos();

        sb.append(formatter.format(v));

        if (nanos == 0) {
//            nanosString = "000";
            nanosString = "";
        } else {
            nanosString = Integer.toString(nanos);

            // Add leading zeros
            nanosString = zeros.substring(0, (9-nanosString.length())) +
                    nanosString;

            // Truncate trailing zeros
            char[] nanosChar = new char[nanosString.length()];
            nanosString.getChars(0, nanosString.length(), nanosChar, 0);
            int truncIndex = 8;
            while (nanosChar[truncIndex] == '0') {
                truncIndex--;
            }

            nanosString = new String(nanosChar, 0, truncIndex + 1);
        }

        if (nanosString.length()>0) {
            sb.append(".");
            sb.append(nanosString);
        }

        sb.append(timezone>0?'+':'-');

        int tz = Math.abs(timezone);
        int tzh = tz/60;
        int tzm = tz%60;

        if (tzh < 10)
            sb.append('0');

        sb.append(tzh);
        sb.append(':');

        if (tzm < 10)
            sb.append('0');

        sb.append(tzm);
        return sb.toString();
    }



}
