/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2007 OpenLink Software
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

package virtuoso.sesame2.driver;

import info.aduna.iteration.CloseableIteratorIteration;
import info.aduna.iteration.Iteration;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.net.URL;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.PreparedStatement;
import java.sql.CallableStatement;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.StringTokenizer;
import java.util.Vector;

import org.openrdf.model.BNode;
import org.openrdf.model.Graph;
import org.openrdf.model.Literal;
import org.openrdf.model.Namespace;
import org.openrdf.model.Resource;
import org.openrdf.model.Statement;
import org.openrdf.model.URI;
import org.openrdf.model.Value;
import org.openrdf.model.impl.ContextStatementImpl;
import org.openrdf.model.impl.GraphImpl;
import org.openrdf.model.impl.NamespaceImpl;
import org.openrdf.model.impl.ValueFactoryImpl;
import org.openrdf.query.BindingSet;
import org.openrdf.query.BooleanQuery;
import org.openrdf.query.GraphQuery;
import org.openrdf.query.GraphQueryResult;
import org.openrdf.query.MalformedQueryException;
import org.openrdf.query.Query;
import org.openrdf.query.QueryEvaluationException;
import org.openrdf.query.QueryLanguage;
import org.openrdf.query.TupleQuery;
import org.openrdf.query.TupleQueryResult;
import org.openrdf.query.TupleQueryResultHandler;
import org.openrdf.query.TupleQueryResultHandlerException;
import org.openrdf.query.algebra.evaluation.QueryBindingSet;
import org.openrdf.query.impl.GraphQueryResultImpl;
import org.openrdf.query.impl.TupleQueryResultImpl;
import org.openrdf.repository.Repository;
import org.openrdf.repository.RepositoryConnection;
import org.openrdf.repository.RepositoryException;
import org.openrdf.repository.RepositoryResult;
import org.openrdf.rio.RDFFormat;
import org.openrdf.rio.RDFHandler;
import org.openrdf.rio.RDFHandlerException;
import org.openrdf.rio.RDFParseException;
import org.openrdf.rio.RDFParser;
import org.openrdf.rio.helpers.RDFHandlerBase;
import org.openrdf.rio.n3.N3ParserFactory;
import org.openrdf.rio.ntriples.NTriplesParserFactory;
import org.openrdf.rio.rdfxml.RDFXMLParserFactory;
import org.openrdf.rio.trig.TriGParserFactory;
import org.openrdf.rio.trix.TriXParserFactory;
import org.openrdf.rio.turtle.TurtleParserFactory;

import virtuoso.jdbc3.VirtuosoExtendedString;
import virtuoso.jdbc3.VirtuosoRdfBox;
import virtuoso.jdbc3.VirtuosoResultSet;


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
	private static Resource nilContext = new ValueFactoryImpl().createURI("urn:nil");
	private Connection quadStoreConnection;
	protected VirtuosoRepository repository;
	static final String S_INSERT = "sparql define output:format '_JAVA_'  insert into graph iri(??) { `iri(??)` `iri(??)` `bif:__rdf_long_from_batch_params(??,??,??)` }";
        static final String S_DELETE = "sparql define output:format '_JAVA_' delete from graph iri(??) {`iri(??)` `iri(??)` `bif:__rdf_long_from_batch_params(??,??,??)`}";
	static final int BATCH_SIZE = 1000;


	public VirtuosoRepositoryConnection(VirtuosoRepository repository, Connection connection) {
		this.quadStoreConnection = connection;
		this.repository = repository;
		try {
			this.repository.initialize();
		}
		catch (RepositoryException e) {
			throw new RuntimeException(e.toString());
		}

	}

	/**
	 * Returns the Repository object to which this connection belongs.
	 */
	public Repository getRepository() {
		return repository;
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
			throw new RepositoryException(e.toString());
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
	public Query prepareQuery(QueryLanguage language, String query) throws RepositoryException, MalformedQueryException {
		return prepareQuery(language, query, null);
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
	public Query prepareQuery(QueryLanguage language, String query, String baseURI) throws RepositoryException, MalformedQueryException {
		Query q = new VirtuosoQuery();
		
		StringTokenizer st = new StringTokenizer(query);
		String type = st.nextToken().toLowerCase();
		if(type.equals("select")) {
			return prepareTupleQuery(language, query, baseURI);
		}
		else if(type.equals("construct") || type.equals("describe")) {
			return prepareGraphQuery(language, query, baseURI);
		}
		else if(type.equals("ask")) {
			return prepareBooleanQuery(language, query, baseURI);
		}
		
		return q;
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
	public TupleQuery prepareTupleQuery(QueryLanguage language, String query) throws RepositoryException, MalformedQueryException {
		return prepareTupleQuery(language, query, null);
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
	public TupleQuery prepareTupleQuery(QueryLanguage langauge, final String query, String baseeURI) throws RepositoryException, MalformedQueryException {
		TupleQuery q = new VirtuosoTupleQuery() {
			public TupleQueryResult evaluate() throws QueryEvaluationException {
				return executeSPARQLForTupleResult(query);
			}

			public void evaluate(TupleQueryResultHandler handler) throws QueryEvaluationException, TupleQueryResultHandlerException {
				executeSPARQLForHandler(handler, query);
			}
		};
		return q;
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
	public GraphQuery prepareGraphQuery(QueryLanguage language, String query) throws RepositoryException, MalformedQueryException {
		return prepareGraphQuery(language, query, null);
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
	public GraphQuery prepareGraphQuery(QueryLanguage language, final String query, String baseURI) throws RepositoryException, MalformedQueryException {
		GraphQuery q = new VirtuosoGraphQuery() {
			public GraphQueryResult evaluate() throws QueryEvaluationException {
				return executeSPARQLForGraphResult(query);
			}

			public void evaluate(RDFHandler handler) throws QueryEvaluationException, RDFHandlerException {
				executeSPARQLForHandler(handler, query);
			}
		};
		return q;
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
	public BooleanQuery prepareBooleanQuery(QueryLanguage language, String query) throws RepositoryException, MalformedQueryException {
		return prepareBooleanQuery(language, query, null);
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
	public BooleanQuery prepareBooleanQuery(QueryLanguage language, final String query, String baseURI) throws RepositoryException, MalformedQueryException {
		BooleanQuery q = new VirtuosoBooleanQuery() {
			public boolean evaluate() throws QueryEvaluationException {
				return executeSPARQLForBooleanResult(query);
			}
		};
		return q;
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
		Vector v = new Vector();
		String query = "DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS()";
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet rs = (VirtuosoResultSet) stmt.executeQuery(query);

			// begin at onset one
			while (rs.next()) {
				Object obj = rs.getObject(1);
				try {
					Value graphId = castValue(obj);
					// add that graph to the results
					v.add(graphId);
				}
				catch (IllegalArgumentException iiaex) {
					throw new RepositoryException("VirtuosoRepositoryConnection.getContextIDs() Non-URI context encountered: " + obj);
				}
			}
			rs.close();

		}
		catch (Exception e) {
			throw new RepositoryException(": SPARQL execute failed." + "\n" + query.toString(), e);
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
	 * @param contexts
	 *        The context(s) to get the data from. Note that this parameter is a
	 *        vararg and as such is optional. If no contexts are supplied the
	 *        method operates on the entire repository.
	 * @param includeInferred
	 *        if false, no inferred statements are returned; if true, inferred
	 *        statements are returned if available. The default is true.
	 * @return The statements matching the specified pattern. The result object
	 *         is a {@link RepositoryResult} object, a lazy Iterator-like object
	 *         containing {@link Statement}s and optionally throwing a
	 *         {@link RepositoryException} when an error when a problem occurs
	 *         during retrieval.
	 */
	public RepositoryResult<Statement> getStatements(Resource subject, URI predicate, Value object, boolean includeInferred, Resource... contexts) throws RepositoryException {
		contexts = checkContext(contexts);
		Graph g = selectFromQuadStore(subject, predicate, object, includeInferred, contexts);
		return createRepositoryResult(g);
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
	 * @param contexts
	 *        The context(s) the need to be searched. Note that this parameter is
	 *        a vararg and as such is optional. If no contexts are supplied the
	 *        method operates on the entire repository.
	 * @param includeInferred
	 *        if false, no inferred statements are considered; if true, inferred
	 *        statements are considered if available
	 * @return true If a matching statement is in the repository in the specified
	 *         context, false otherwise.
	 */
	public boolean hasStatement(Resource subject, URI predicate, Value object, boolean includeInferred, Resource... contexts) throws RepositoryException {
		contexts = checkContext(contexts);
		Graph g = selectFromQuadStore(subject, predicate, object, includeInferred, contexts);
		return g.iterator().hasNext();
	}

	/**
	 * Checks whether the repository contains the specified statement, optionally
	 * in the specified contexts.
	 * 
	 * @param st
	 *        The statement to look for. Context information in the statement is
	 *        ignored.
	 * @param contexts
	 *        The context(s) to get the data from. Note that this parameter is a
	 *        vararg and as such is optional. If no contexts are supplied the
	 *        method operates on the entire repository.
	 * @param includeInferred
	 *        if false, no inferred statements are considered; if true, inferred
	 *        statements are considered if available
	 * @return true If the repository contains the specified statement, false
	 *         otherwise.
	 */
	public boolean hasStatement(Statement statement, boolean includeInferred, Resource... contexts) throws RepositoryException {
		contexts = checkContext(contexts);
		Graph g = selectFromQuadStore(statement.getSubject(), statement.getPredicate(), statement.getObject(), includeInferred, contexts);
		return g.iterator().hasNext();
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
	 * @param contexts
	 *        The context(s) to get the data from. Note that this parameter is a
	 *        vararg and as such is optional. If no contexts are supplied the
	 *        method operates on the entire repository.
	 * @param handler
	 *        The handler that will handle the RDF data.
	 * @param includeInferred
	 *        if false, no inferred statements are returned; if true, inferred
	 *        statements are returned if available
	 * @throws RDFHandlerException
	 *         If the handler encounters an unrecoverable error.
	 */
	public void exportStatements(Resource subject, URI predicate, Value object, boolean includeInferred, RDFHandler handler, Resource... contexts) throws RepositoryException, RDFHandlerException {
		contexts = checkContext(contexts);
		Graph g = selectFromQuadStore(subject, predicate, object, includeInferred, contexts);
		handler.startRDF();
		Iterator<Statement> it = g.iterator();
		while (it.hasNext())
			handler.handleStatement(it.next());
		handler.endRDF();
	}

	private Resource[] checkContext(Resource... contexts) throws RepositoryException {
		if(contexts != null && contexts.length == 1 && contexts[0] == null && contexts[0] instanceof Resource) {
			contexts = new Resource[] {nilContext};
		}
		else if (contexts == null || contexts.length == 0) {
			contexts = getContexts();
		}
		return contexts;
	}

	/**
	 * Exports all explicit statements in the specified contexts to the supplied
	 * RDFHandler.
	 * 
	 * @param contexts
	 *        The context(s) to get the data from. Note that this parameter is a
	 *        vararg and as such is optional. If no contexts are supplied the
	 *        method operates on the entire repository.
	 * @param handler
	 *        The handler that will handle the RDF data.
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
		int ret = 0;
		String query = "select count(*) from (sparql select * where { graph `iri(??)` { ?s ?p ?o }})f";

		verifyIsOpen();
		if(contexts == null || contexts.length == 0) contexts = getContexts(); // special check for RepositoryConnection.size()

		try {
		        PreparedStatement ps = getQuadStoreConnection().prepareStatement(query);

			for (int i = 0; i < contexts.length; i++) {
					ps.setString(1, contexts[i].stringValue());
				ResultSet rs = ps.executeQuery();
				rs.next();
				ret += rs.getInt(1);
                                rs.close();
			}
		}
		catch (Exception e) {
			throw new RepositoryException(e);
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
		boolean result = false;
		String query = "sparql select * where {?s ?o ?p} limit 1";
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet rs = (VirtuosoResultSet) stmt.executeQuery(query);
			result = rs.next();
                        rs.close();
                        return result;
		}
		catch (Exception e) {
			throw new RepositoryException("Problem executing query: " + query, e);
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
	 */
	public void setAutoCommit(boolean autoCommit) throws RepositoryException {
		verifyIsOpen();
		try {
			getQuadStoreConnection().setAutoCommit(autoCommit);
		}
		catch (SQLException e) {
			throw new RepositoryException(e.toString());
		}
	}

	/**
	 * Checks whether the connection is in auto-commit mode.
	 * 
	 * @see #setAutoCommit
	 */
	public boolean isAutoCommit() throws RepositoryException {
		verifyIsOpen();
		try {
			return getQuadStoreConnection().getAutoCommit();
		}
		catch (SQLException e) {
			throw new RepositoryException(e.toString());
		}
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
		try {
			getQuadStoreConnection().commit();
		}
		catch (SQLException e) {
			throw new RepositoryException(e.toString());
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
		try {
			this.getQuadStoreConnection().rollback();
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
	public void add(InputStream dataStream, String baseURI, RDFFormat format, Resource... contexts) throws IOException, RDFParseException, RepositoryException {
		Reader reader = new InputStreamReader(dataStream);
		add(reader, baseURI, format, contexts);
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
	public void add(Reader reader, String baseURI, RDFFormat format, final Resource... contexts) throws IOException, RDFParseException, RepositoryException {
		try {
			RDFParser parser = null;
			if (format.equals(RDFFormat.NTRIPLES)) {
				parser = new NTriplesParserFactory().getParser();
			}
			else if (format.equals(RDFFormat.N3)) {
				parser = new N3ParserFactory().getParser();
			}
			else if (format.equals(RDFFormat.RDFXML)) {
				parser = new RDFXMLParserFactory().getParser();
			}
			else if (format.equals(RDFFormat.TURTLE)) {
				parser = new TurtleParserFactory().getParser();
			}
			else if (format.equals(RDFFormat.TRIG)) {
				parser = new TriGParserFactory().getParser();
			}
			else if (format.equals(RDFFormat.TRIX)) {
				parser = new TriXParserFactory().getParser();
			}

			verifyIsOpen();
			// set up a handler for parsing the data from reader
			parser.setDatatypeHandling(RDFParser.DatatypeHandling.IGNORE);
			final PreparedStatement ps = quadStoreConnection.prepareStatement(VirtuosoRepositoryConnection.S_INSERT);
			final Resource[] _contexts = checkContext(contexts);

			parser.setRDFHandler(new RDFHandlerBase() {
				
				int count = 0;

				public void startRDF() {
				}

				public void endRDF() throws RDFHandlerException {
					try {
						if (count > 0) {
							ps.executeBatch();
							ps.clearBatch();
							count = 0;
						}
					}
					catch (SQLException e) {
						throw new RDFHandlerException("Problem executing query: ", e);
					}
				}

				public void handleNamespace(String prefix, String name) throws RDFHandlerException {
					String query = "DB.DBA.XML_SET_NS_DECL(?, ?, 1)";
					try {
						PreparedStatement psn = getQuadStoreConnection().prepareStatement(query);
						psn.setString(1, prefix);
						psn.setString(2, name);
						psn.execute();
					}
					catch (SQLException e) {
						throw new RDFHandlerException("Problem executing query: " + query, e);
					}
				}

				public void handleStatement(Statement st) throws RDFHandlerException {
				   try {
					for (int i = 0; i < _contexts.length; i++) {
						ps.setString(1, _contexts[i].stringValue());
						bindResource(ps, 2, st.getSubject());
						bindURI(ps, 3, st.getPredicate());
						bindValue(ps, 4, st.getObject());
						ps.addBatch();
						count++;
					}
					if (count > BATCH_SIZE) {
						ps.executeBatch();
						ps.clearBatch();
						count = 0;
					}
				   }	
				   catch(Exception e) {
				   	throw new RDFHandlerException(e);
				   }
				}
			});

			parser.parse(reader, ""); // parse out each tripled to be handled by the handler above

		}
		catch (Exception e) {
			throw new RepositoryException("Problem parsing triples", e);
		}
		finally {
			reader.close();
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
	public void add(URL dataURL, String baseURI, RDFFormat format, Resource... contexts) throws IOException, RDFParseException, RepositoryException {
		// add data to Sesame
		Reader reader = new InputStreamReader(dataURL.openStream());
		add(reader, baseURI, format, contexts);
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
	public void add(File file, String baseURI, RDFFormat format, Resource... contexts) throws IOException, RDFParseException, RepositoryException {
		InputStream reader = new FileInputStream(file);
		add(reader, baseURI, format, contexts);
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
	public void add(Resource subject, URI predicate, Value object, Resource... contexts) throws RepositoryException {
		contexts = checkContext(contexts);
		addToQuadStore(subject, predicate, object, contexts);
	}

	/**
	 * Adds the supplied statement to this repository, optionally to one or more
	 * named contexts.
	 * 
	 * @param st
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
		if (contexts == null || contexts.length == 0 &&  statement.getContext() != null) {
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
	public void add(Iterable<? extends Statement> statements, Resource... contexts) throws RepositoryException {
		Iterator it = statements.iterator();

		try {
			PreparedStatement ps = quadStoreConnection.prepareStatement(VirtuosoRepositoryConnection.S_INSERT);
			int count = 0;
			boolean useStatementContext = contexts == null || contexts.length == 0; // If no context are specified, each statement is added to statement context
			Resource[] _contexts = checkContext(contexts); // otherwise, either use all contexts, or do not specify a context

			while (it.hasNext()) {
				Statement st = (Statement) it.next();

				if (st.getContext() != null && useStatementContext) {
					contexts = new Resource[] {st.getContext()};
				} else {
					contexts = _contexts;
				}

				for (int i = 0; i < contexts.length; i++) {
					ps.setString(1, contexts[i].stringValue());
					bindResource(ps, 2, st.getSubject());
					bindURI(ps, 3, st.getPredicate());
					bindValue(ps, 4, st.getObject());
					ps.addBatch();
					count++;
				}

				if (count > BATCH_SIZE) {
					ps.executeBatch();
					ps.clearBatch();
					count = 0;
				}
			}
			if (count > 0) {
				ps.executeBatch();
				ps.clearBatch();
			}
		}	
		catch(Exception e) {
		   	throw new RepositoryException(e);
		}
	}

	/**
	 * Adds the supplied statements to this repository, optionally to one or more
	 * named contexts.
	 * 
	 * @param statementIter
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
	public <E extends Exception> void add(Iteration<? extends Statement, E> statements, Resource... contexts) throws RepositoryException, E {

		try {
			PreparedStatement ps = quadStoreConnection.prepareStatement(VirtuosoRepositoryConnection.S_INSERT);
			int count = 0;
			boolean useStatementContext = contexts == null || contexts.length == 0; // If no context are specified, each statement is added to statement context
			Resource[] _contexts = checkContext(contexts); // otherwise, either use all contexts, or do not specify a context

			while (statements.hasNext()) {
				Statement st = (Statement) statements.next();

				if (st.getContext() != null && useStatementContext) {
					contexts = new Resource[] {st.getContext()};
				}

				for (int i = 0; i < _contexts.length; i++) {

					ps.setString(1, _contexts[i].stringValue());
					bindResource(ps, 2, st.getSubject());
					bindURI(ps, 3, st.getPredicate());
					bindValue(ps, 4, st.getObject());
					ps.addBatch();
					count++;
				}

				if (count > BATCH_SIZE) {
					ps.executeBatch();
					ps.clearBatch();
					count = 0;
				}
			}
			if (count > 0) {
				ps.executeBatch();
				ps.clearBatch();
			}
		}
		catch(Exception e) {
		   	throw new RepositoryException(e);
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
	public void remove(Resource subject, URI predicate, Value object, Resource... contexts) throws RepositoryException {
		contexts = checkContext(contexts);

		for (int i = 0; i < contexts.length; i++)
		     removeContext(subject, predicate, object, contexts[i]);
	}

	/**
	 * Removes the supplied statement from the specified contexts in the
	 * repository.
	 * 
	 * @param st
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
		if (contexts == null || contexts.length == 0) {
			if (statement.getContext() != null)
				contexts = new Resource[] { statement.getContext() }; // try the context given by the statement
		}
		remove(statement.getSubject(), statement.getPredicate(), statement.getObject(), contexts);
	}

	/**
	 * Removes the supplied statements from the specified contexts in this
	 * repository.
	 * 
	 * @param statements
	 *        The statements that should be added.
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
		Iterator<? extends Statement> it = statements.iterator();
		while (it.hasNext()) {
			Statement st = it.next();
			remove(st, contexts);
		}
	}

	/**
	 * Removes the supplied statements from a specific context in this
	 * repository, ignoring any context information carried by the statements
	 * themselves.
	 * 
	 * @param statementIter
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
		while (statements.hasNext()) {
			Statement st = statements.next();
			remove(st, contexts);
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
		contexts = checkContext(contexts);

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
		List<Namespace> namespaceList = new ArrayList<Namespace>();
		String query = "DB.DBA.XML_SELECT_ALL_NS_DECLS (3)";
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet rs = (VirtuosoResultSet) stmt.executeQuery(query);

			// begin at onset one
			while (rs.next()) {
				String prefix = rs.getString(1);
				String name = rs.getString(2);
				if (name != null && prefix != null) {
					Namespace ns = new NamespaceImpl(prefix, name);
					namespaceList.add(ns);
				}
			}
                        rs.close();
		}
		catch (Exception e) {
			throw new RepositoryException(e.toString());
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
		String retVal = null;
		String query = "SELECT __xml_get_ns_uri (?, 3)";
		try {
			PreparedStatement ps = getQuadStoreConnection().prepareStatement(query);
			ps.setString(1, prefix);
			VirtuosoResultSet rs = (VirtuosoResultSet) ps.executeQuery();

			// begin at onset one
			while (rs.next()) {
				retVal = rs.getString(1);
			}
			rs.close();
		}
		catch (Exception e) {
			throw new RepositoryException(e.toString());
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
		String query = "DB.DBA.XML_SET_NS_DECL(?, ?, 1)";
		try {
			PreparedStatement ps = getQuadStoreConnection().prepareStatement(query);
			ps.setString(1, prefix);
			ps.setString(2, name);
			ps.execute();
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
		String query = "DB.DBA.XML_REMOVE_NS_BY_PREFIX(?, 1)";
		try {
			PreparedStatement ps = getQuadStoreConnection().prepareStatement(query);
			ps.setString(1, prefix);
			ps.execute(query);
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
		String query = "DB.DBA.XML_CLEAR_ALL_NS_DECLS()";
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			stmt.execute(query);
		}
		catch (SQLException e) {
			throw new RepositoryException("Problem executing query: " + query, e);
		}
	}

	protected TupleQueryResult executeSPARQLForTupleResult(String query) {

		Vector<String> names = new Vector();
		Vector<BindingSet> bindings = new Vector();
		try {
			verifyIsOpen();
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet rs = (VirtuosoResultSet) stmt.executeQuery(fixQuery(query));

			ResultSetMetaData rsmd = rs.getMetaData();

			// begin at onset one
			for (int i = 1; i <= rsmd.getColumnCount(); i++) {
				String col = rsmd.getColumnName(i);
				if (names.indexOf(col) < 0) 
					names.add(col); // no duplicates
			}
			while (rs.next()) {
				QueryBindingSet qbs = new QueryBindingSet();
				for (int i = 1; i <= rsmd.getColumnCount(); i++) {
					String col = rsmd.getColumnName(i);
					Object val = rs.getObject(i);
					Value v = castValue(val);
					qbs.setBinding(col, v);
				}
				bindings.add(qbs);
			}
			stmt.close();
		}
		catch (Exception e) {
			throw new RuntimeException(e.toString());
		}
		TupleQueryResult tqr = new TupleQueryResultImpl(names, bindings.iterator());
		return tqr;
	}
	
	protected GraphQueryResult executeSPARQLForGraphResult(String query) {

		HashMap<String,Integer> names = new HashMap();
		Vector<Statement> statements = new Vector<Statement>();
		try {
			verifyIsOpen();
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet rs = (VirtuosoResultSet) stmt.executeQuery(fixQuery(query));
			ResultSetMetaData rsmd = rs.getMetaData();

			// begin at onset one
			for (int i = 1; i <= rsmd.getColumnCount(); i++)
				names.put(rsmd.getColumnName(i), new Integer(i));

			while (rs.next()) {
			        Integer col = null;
				Resource sval = null;
				URI pval = null;
				Value oval = null;
				Resource gval = null;

			        col = names.get("S");
			        if (col != null)
				  sval = (Resource) castValue(rs.getObject(col.intValue()));
				
			        col = names.get("P");
			        if (col != null)
				  pval = (URI) castValue(rs.getObject(col.intValue()));
				
			        col = names.get("O");
			        if (col != null)
				   oval = castValue(rs.getObject(col.intValue()));
				
			        col = names.get("G");
			        if (col != null)
				  gval = (Resource) castValue(rs.getObject(col.intValue()));
				
				Statement st = new ContextStatementImpl(sval,pval,oval,gval);
				statements.add(st);
			}
			stmt.close();
		}
		catch (Exception e) {
			throw new RuntimeException(e);
		}
		
		GraphQueryResult gqr = new GraphQueryResultImpl(new HashMap<String,String>(), statements);
		return gqr;
	}

	protected boolean executeSPARQLForBooleanResult(String query) {
		Vector<String> names = new Vector();
		Vector<BindingSet> bindings = new Vector();
		boolean result = false;
		try {
			verifyIsOpen();
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet rs = (VirtuosoResultSet) stmt.executeQuery(fixQuery(query));

			while(rs.next())
			{
			  if (rs.getInt(1) == 1)
			  	result = true;
			}
			stmt.close();

			return result;
		}
		catch (Exception e) {
			throw new RuntimeException(e.toString());
		}
	}


	protected void executeSPARQLForHandler(TupleQueryResultHandler tqrh, String query) {
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet rs = (VirtuosoResultSet) stmt.executeQuery(fixQuery(query));

			ResultSetMetaData rsmd = rs.getMetaData();

			// begin at onset one
			while (rs.next()) {
				QueryBindingSet qbs = new QueryBindingSet();
				for (int i = 1; i <= rsmd.getColumnCount(); i++) {
					// TODO need to parse these into appropriate resource values
					String col = rsmd.getColumnName(i);
					Object val = rs.getObject(i);
					Value v = castValue(val);
					qbs.addBinding(col, v);
				}
				tqrh.handleSolution(qbs);
			}
                        stmt.close();
		}
		catch (Exception e) {
			throw new RuntimeException(e.toString());
		}
	}


	protected void executeSPARQLForHandler(RDFHandler tqrh, String query) {
		HashMap<String,Integer> names = new HashMap();
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet rs = (VirtuosoResultSet) stmt.executeQuery(fixQuery(query));
			ResultSetMetaData rsmd = rs.getMetaData();

			// begin at onset one
			for (int i = 1; i <= rsmd.getColumnCount(); i++)
				names.put(rsmd.getColumnName(i), new Integer(i));

			while (rs.next()) {
			        Integer col = null;
				Resource sval = null;
				URI pval = null;
				Value oval = null;
				Resource gval = null;

			        col = names.get("S");
			        if (col != null)
				  sval = (Resource) castValue(rs.getObject(col.intValue()));
				
			        col = names.get("P");
			        if (col != null)
				  pval = (URI) castValue(rs.getObject(col.intValue()));
				
			        col = names.get("O");
			        if (col != null)
				   oval = castValue(rs.getObject(col.intValue()));
				
			        col = names.get("G");
			        if (col != null)
				  gval = (Resource) castValue(rs.getObject(col.intValue()));

				Statement st = new ContextStatementImpl(sval,pval,oval,gval);
				tqrh.handleStatement(st);
			}
			stmt.close();
		}
		catch (Exception e) {
			throw new RuntimeException(e.toString());
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

		try {
			verifyIsOpen();
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			stmt.execute("sparql\n define output:format '_JAVA_'\n " + query);
			return stmt.getUpdateCount();
		}
		catch (Exception e) {
			throw new RepositoryException(e);
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

	private String fixQuery(String query) {
		StringTokenizer tok = new StringTokenizer(query);
		String s = tok.nextToken().toLowerCase();
		if (s.equals("describe") || s.equals("construct") || s.equals("ask")) 
			return "sparql\n define output:format '_JAVA_'\n " + query;
		else 
			return "sparql\n " + query;
	}


	private void addToQuadStore(Resource subject, URI predicate, Value object, Resource... contexts) throws RepositoryException {
		verifyIsOpen();

		try {
			PreparedStatement ps = getQuadStoreConnection().prepareStatement(VirtuosoRepositoryConnection.S_INSERT);

			contexts = checkContext(contexts);

			for (int i = 0; i < contexts.length; i++) {

					ps.setString(1, contexts[i].stringValue());

				bindResource(ps, 2, subject);
				bindURI(ps, 3, predicate);
				bindValue(ps, 4, object);

				ps.addBatch();
			}
			ps.executeBatch();
			ps.clearBatch();
		}
		catch (Exception e) {
			throw new RuntimeException(e.toString());
		}
	}


	private void clearQuadStore(Resource[] contexts) throws RepositoryException {
		verifyIsOpen();
		String  query = "sparql clear graph iri(??)";

		try {
			PreparedStatement ps = quadStoreConnection.prepareStatement(query);
			for (int i = 0; i < contexts.length; i++) {
					ps.setString(1, contexts[i].stringValue());
				ps.execute();
			}
		}
		catch (Exception e) {
			throw new RepositoryException(e);
		}
	}

	private Graph selectFromQuadStore(Resource... contexts) throws RepositoryException {
		return selectFromQuadStore(null, null, null, false, contexts);
	}

	private Graph selectFromQuadStore(Resource subject, URI predicate, Value object, boolean includeInferred, Resource... contexts) throws RepositoryException {
		verifyIsOpen();

		Graph g = new GraphImpl();
		String s = "?s";
		String p = "?p";
		String o = "?o";

		if (subject != null) 
			s = stringForResource(subject);
		if (predicate != null) 
			p = stringForURI(predicate);
		if (object != null) 
			o = stringForValue(object);

		for (int i = 0; i < contexts.length; i++) {

			StringBuffer query = new StringBuffer("sparql select * from <");
			Resource context = contexts[i];

			query.append(context.stringValue());
			query.append("> where { ");
			query.append(s);
			query.append(" ");
			query.append(p);
			query.append(" ");
			query.append(o);
			query.append(" }");

			try {
				java.sql.Statement stmt = getQuadStoreConnection().createStatement();
				VirtuosoResultSet rs = (VirtuosoResultSet) stmt.executeQuery(query.toString());

				// begin at onset one
				while (rs.next()) {
					Resource _subject = subject;
					URI _predicate = predicate;
					Value _object = object;
					Object val = null;

					if (_subject == null) 
					  try {
						val = rs.getObject("s");
						_subject = (Resource) castValue(val);
					  }
					  catch (ClassCastException ccex) {
						throw new RepositoryException("Unexpected resource type encountered. Was expecting Resource: " + val);
					  }

					if (_predicate == null) 
					  try {
						val = rs.getObject("p");
						_predicate = (URI) castValue(val);
					  }
					  catch (ClassCastException ccex) {
						throw new RepositoryException("Unexpected resource type encountered. Was expecting URI: " + val);
					  }

					if (_object == null) 
					  _object = castValue(rs.getObject("o"));

					g.add(_subject, _predicate, _object, context);
				}
                                stmt.close();
			}
			catch (Exception e) {
				throw new RepositoryException(getClass().getCanonicalName() + ": SPARQL execute failed." + "\n" + query.toString() + "[" + e + "]");
			}
		}
		return g;
	}


	private void removeContext(Resource subject, URI predicate, Value object, Resource context) throws RepositoryException {
		verifyIsOpen();
		PreparedStatement ps = null;

		String S = "";
		String P = "";
		String O = "";

		try {

		    if (subject == null && predicate == null && object == null && context != null) {
			String  query = "sparql clear graph iri(??)";

			ps = getQuadStoreConnection().prepareStatement(query);
			ps.setString(1, context.stringValue());
			ps.execute();

		    } else if (subject != null && predicate != null && object != null && context != null) {

		    	ps = getQuadStoreConnection().prepareStatement(VirtuosoRepositoryConnection.S_DELETE);

			ps.setString(1, context.stringValue());
			bindResource(ps, 2, subject);
			bindURI(ps, 3, predicate);
			bindValue(ps, 4, object);
			ps.execute();

		    } else {

			if (subject != null)
				S = stringForResource(subject)+" ?p ?o ."  ;

			if (predicate != null)
				P = "?s "+stringForURI(predicate)+" ?o .";

			if (object != null)
				O = "?s ?p "+stringForValue(object)+" .";

			// s = s.replaceAll("'", "''");
			// p = p.replaceAll("'", "''");
			// o = o.replaceAll("'", "''");
		    	
		    	// context should not be null at this point, at the least, it will be a wildcard

		        String query = "sparql delete from graph <"+context+
  				"> {?s ?p ?o} where {?s ?p ?o . "
  				+ S +" "+ P +" "+ O +" }";

		    	java.sql.Statement stmt = getQuadStoreConnection().createStatement();
		    	stmt.execute(query);
		    }
		}
		catch (Exception e) {
		    throw new RepositoryException(e.toString());
		}
	}

	
	private void bindResource(PreparedStatement ps, int col, Resource n) throws SQLException {
		if (n == null)
			return;
		if (n instanceof URI) 
			ps.setString(col, n.stringValue());
		else if (n instanceof BNode) 
			ps.setString(col, "_:"+((BNode)n).getID());
		else 
			ps.setString(col, n.stringValue());
	}

	
	private void bindURI(PreparedStatement ps, int col, URI n) throws SQLException {
		if (n == null)
			return;
		ps.setString(col, n.stringValue());
	}

	
	private void bindValue(PreparedStatement ps, int col, Value n) throws SQLException {
		if (n == null)
			return;
		if (n instanceof URI) {
			ps.setInt(col, 1);
			ps.setString(col+1, n.stringValue());
			ps.setNull(col+2, java.sql.Types.VARCHAR);
		}
		else if (n instanceof BNode) {
			ps.setInt(col, 1);
			ps.setString(col+1, "_:"+((BNode)n).getID());
			ps.setNull(col+2, java.sql.Types.VARCHAR);
		}
		else if (n instanceof Literal) {
			Literal lit = (Literal) n;
			if (lit.getLanguage() != null) {
				ps.setInt(col, 5);
				ps.setString(col+1, lit.stringValue());
				ps.setString(col+2, lit.getLanguage());
			} 
			else if (lit.getDatatype() != null) {
				ps.setInt(col, 4);
				ps.setString(col+1, lit.stringValue());
				ps.setString(col+2, lit.getDatatype().toString());
		 	}
		 	else {
				ps.setInt(col, 3);
				ps.setString(col+1, n.stringValue());
				ps.setNull(col+2, java.sql.Types.VARCHAR);
		 	}	
		}
		else {
			ps.setInt(col, 3);
			ps.setString(col+1, n.stringValue());
			ps.setNull(col+2, java.sql.Types.VARCHAR);
		}
	}
	

	private String stringForResource(Resource n) {
		if (n instanceof URI) 
			return stringForURI((URI) n);
		else if (n instanceof BNode) 
			return stringForBNode((BNode) n);
		else 
			return "<" + n.stringValue() + ">";
	}

	
	private String stringForURI(URI n) {
		return "<" + n.stringValue() + ">";
	}

	
	private String stringForBNode(BNode n) {
		return "<_:" + n.getID() + ">";
	}

	
	private String stringForValue(Value n) {
		if (n instanceof Resource) 
			return stringForResource((Resource) n);
		else if (n instanceof Literal) {
			Literal lit = (Literal) n;
			String o = "\"" + lit.stringValue() + "\"";
			if (lit.getLanguage() != null) 
				o = "@" + lit.getLanguage();
			else if (lit.getDatatype() != null) 
				o = "^^<" + lit.getDatatype() + ">";
			return o;
		}
		else return "\"" + n.stringValue() + "\"";
	}

	
	private Value castValue(Object val) throws RepositoryException {
		if (val == null) 
			return null;
		if (val instanceof VirtuosoRdfBox) {
			VirtuosoRdfBox rb = (VirtuosoRdfBox) val;
			if (rb.getLang() != null) {
				return getRepository().getValueFactory().createLiteral(rb.rb_box.toString(), rb.getLang());
			}
			else if (rb.getType() != null) {
				return getRepository().getValueFactory().createLiteral(rb.rb_box.toString(), this.getRepository().getValueFactory().createURI(rb.getType()));
			}
			else {
				return getRepository().getValueFactory().createLiteral(rb.rb_box.toString());
			}
		}
		else if (val instanceof java.lang.Integer) {
			return getRepository().getValueFactory().createLiteral(((Integer) val).intValue());
		}
		else if (val instanceof java.lang.Short) {
			return getRepository().getValueFactory().createLiteral(((Short) val).intValue());
		}
		else if (val instanceof java.lang.Float) {
			return getRepository().getValueFactory().createLiteral(((Float) val).floatValue());
		}
		else if (val instanceof java.lang.Double) {
			return getRepository().getValueFactory().createLiteral(((Double) val).doubleValue());
		}
		else if (val instanceof java.math.BigDecimal) {
			URI type = getRepository().getValueFactory().createURI("http://www.w3.org/2001/XMLSchema#decimal");
			return getRepository().getValueFactory().createLiteral(val.toString(), type);
		}
		else if (val instanceof java.sql.Blob) {
			URI type = getRepository().getValueFactory().createURI("http://www.w3.org/2001/XMLSchema#hexBinary");
			return getRepository().getValueFactory().createLiteral(val.toString(), type);
		}
		else if (val instanceof java.sql.Date) {
			URI type = getRepository().getValueFactory().createURI("http://www.w3.org/2001/XMLSchema#date");
			return getRepository().getValueFactory().createLiteral(val.toString(), type);
		}
		else if (val instanceof java.sql.Timestamp) {
			URI type = getRepository().getValueFactory().createURI("http://www.w3.org/2001/XMLSchema#dateTime");
			return getRepository().getValueFactory().createLiteral(val.toString(), type);
		}
		else if (val instanceof java.sql.Time) {
			URI type = getRepository().getValueFactory().createURI("http://www.w3.org/2001/XMLSchema#time");
			return getRepository().getValueFactory().createLiteral(val.toString(), type);
		}
		else if (val instanceof VirtuosoExtendedString) {
			VirtuosoExtendedString ves = (VirtuosoExtendedString) val;
			String valueString = ves.str;
			if (ves.iriType == VirtuosoExtendedString.IRI) {
				if (valueString.startsWith("_:")) {
					valueString = valueString.substring(2);
					return getRepository().getValueFactory().createBNode(valueString);
				}
				try {
					if (valueString.indexOf(':') < 0) 
						return getRepository().getValueFactory().createURI(":" + valueString);
					else 
						return getRepository().getValueFactory().createURI(valueString);
				}
				catch (IllegalArgumentException iaex) {
					throw new RepositoryException("VirtuosoRepositoryConnection().castValue() Invalid value from Virtuoso: \"" + valueString + "\"");
				}
			}
			else if (ves.iriType == VirtuosoExtendedString.BNODE) {
				try {
					valueString = valueString.substring(9); // "nodeID://"
					return getRepository().getValueFactory().createBNode(valueString);
				}
				catch (IllegalArgumentException iaex) {
					throw new RepositoryException("VirtuosoRepositoryConnection().castValue() Invalid value from Virtuoso: \"" + valueString + "\"");
				}
			}
			else {
				try {
					return getRepository().getValueFactory().createLiteral(valueString);
				}
				catch (IllegalArgumentException iaex) {
					throw new RepositoryException("VirtuosoRepositoryConnection().castValue() Invalid value from Virtuoso: \"" + valueString + "\", STRTYPE = " + ves.iriType);
				}
			}
		}
		else { // if(val instanceof String) {
			try {
				return getRepository().getValueFactory().createLiteral((String) val);
			}
			catch (IllegalArgumentException iaex2) {
				throw new RepositoryException("VirtuosoRepositoryConnection().castValue() Could not parse resource: " + val);
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

	private Resource[] getContexts() throws RepositoryException {
		Resource[] contexts;
		
		List<Resource> ctx = getContextIDs().asList();
	        contexts = new Resource[ctx.size()];
	        ctx.toArray(contexts);
	        return contexts;
	}
}
