/*
 *  $Id$
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

package virtuoso.sesame3.driver;

import info.aduna.iteration.CloseableIteration;
import info.aduna.iteration.CloseableIteratorIteration;
import info.aduna.iteration.Iteration;
import info.aduna.io.GZipUtil;
import info.aduna.io.ZipUtil;

import java.io.File;
import java.io.FileInputStream;
import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.io.BufferedInputStream;
import java.util.zip.GZIPInputStream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import java.util.Set;

import java.net.URL;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.PreparedStatement;
import java.sql.CallableStatement;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.StringTokenizer;
import java.util.Vector;
import java.util.NoSuchElementException;
import java.util.Calendar;
import java.util.GregorianCalendar;

import org.openrdf.OpenRDFUtil;
import org.openrdf.cursor.Cursor;
import org.openrdf.cursor.CollectionCursor;
import org.openrdf.model.BNode;
import org.openrdf.model.Literal;
import org.openrdf.model.Namespace;
import org.openrdf.model.Resource;
import org.openrdf.model.Statement;
import org.openrdf.model.URI;
import org.openrdf.model.Value;
import org.openrdf.model.ValueFactory;
import org.openrdf.model.URIFactory;
import org.openrdf.model.LiteralFactory;
import org.openrdf.model.impl.StatementImpl;
import org.openrdf.model.impl.NamespaceImpl;
import org.openrdf.model.impl.ValueFactoryImpl;
import org.openrdf.model.impl.LiteralFactoryImpl;
import org.openrdf.model.impl.URIFactoryImpl;
import org.openrdf.query.Dataset;
import org.openrdf.query.BindingSet;
import org.openrdf.query.BooleanQuery;
import org.openrdf.query.GraphQuery;
import org.openrdf.query.MalformedQueryException;
import org.openrdf.query.Query;
import org.openrdf.query.QueryLanguage;
import org.openrdf.query.TupleQuery;
import org.openrdf.query.TupleQueryResultHandler;
import org.openrdf.query.TupleQueryResultHandlerException;
import org.openrdf.query.algebra.evaluation.QueryBindingSet;
import org.openrdf.repository.Repository;
import org.openrdf.repository.RepositoryConnection;
import org.openrdf.repository.base.RepositoryConnectionBase;
import org.openrdf.result.ContextResult;
import org.openrdf.result.ModelResult;
import org.openrdf.result.NamespaceResult;
import org.openrdf.result.GraphResult;
import org.openrdf.result.TupleResult;
import org.openrdf.result.impl.NamespaceResultImpl;
import org.openrdf.result.impl.ContextResultImpl;
import org.openrdf.result.impl.ModelResultImpl;
import org.openrdf.result.impl.TupleResultImpl;
import org.openrdf.result.impl.GraphResultImpl;
import org.openrdf.rio.RDFFormat;
import org.openrdf.rio.RDFHandler;
import org.openrdf.rio.RDFHandlerException;
import org.openrdf.rio.RDFParseException;
import org.openrdf.rio.RDFParser;
import org.openrdf.rio.Rio;
import org.openrdf.rio.helpers.RDFHandlerBase;
import org.openrdf.rio.n3.N3ParserFactory;
import org.openrdf.rio.ntriples.NTriplesParserFactory;
import org.openrdf.rio.rdfxml.RDFXMLParserFactory;
import org.openrdf.rio.trig.TriGParserFactory;
import org.openrdf.rio.trix.TriXParserFactory;
import org.openrdf.rio.turtle.TurtleParserFactory;
import org.openrdf.store.StoreException;
import org.openrdf.store.Isolation;



import virtuoso.sql.ExtendedString;
import virtuoso.sql.RdfBox;


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
	private ValueFactoryImpl vf;
	private static Resource nilContext;
	private Connection quadStoreConnection;
	protected VirtuosoRepository repository;
	static final String S_INSERT = "sparql insert into graph iri(??) { `iri(??)` `iri(??)` `bif:__rdf_long_from_batch_params(??,??,??)` }";
        static final String S_DELETE = "sparql delete from graph iri(??) {`iri(??)` `iri(??)` `bif:__rdf_long_from_batch_params(??,??,??)`}";
	static final int BATCH_SIZE = 5000;
	private PreparedStatement psInsert;
	private int psInsertCount = 0;
	private boolean useLazyAdd = false;
	private int prefetchSize = 200;



	protected VirtuosoRepositoryConnection(VirtuosoRepository repository, Connection connection) throws StoreException {
		this.quadStoreConnection = connection;
		this.repository = repository;
		this.useLazyAdd = repository.useLazyAdd;
		this.prefetchSize = repository.prefetchSize;
		URIFactory uf = repository.getURIFactory();
		LiteralFactory lf = repository.getLiteralFactory();
		this.vf = new ValueFactoryImpl(uf, lf);
		this.nilContext = getValueFactory().createURI(repository.defGraph);
		this.repository.initialize();

	}

	/**
	 * Verifies that the connection is not in read-only mode, throws a
	 * {@link StoreException} if it is.
	 */
	protected void verifyNotReadOnly()
		throws StoreException
	{
		if (isReadOnly()) {
			throw new StoreException("Connection is in read-only mode");
		}
	}


	/**
	 * Verifies that the connection has an active transaction, throws a
	 * {@link StoreException} if it hasn't.
	 */
	protected void verifyTxnActive()
		throws StoreException
	{
		if (isAutoCommit()) {
			throw new StoreException("Connection does not have an active transaction");
		}
	}

	/**
	 * Verifies that the connection does not have an active transaction, throws a
	 * {@link StoreException} if the connection is it has.
	 */
	protected void verifyNotTxnActive(String msg)
		throws StoreException
	{
		if (!isAutoCommit()) {
			throw new StoreException(msg);
		}
	}

	/**
	 * Returns the Repository object to which this connection belongs.
	 */
	public Repository getRepository() {
		return repository;
	}


	/**
	 * Gets a ValueFactory for this RepositoryConnection.
	 * 
	 * @return A repository-specific ValueFactory.
	 */
	public ValueFactory getValueFactory() {
		return vf;
        }

	/**
	 * Checks whether this connection is open. A connection is open from the
	 * moment it is created until it is closed.
	 * 
	 * @see #close()
	 */
	public boolean isOpen() throws StoreException {
		try {
			return !this.getQuadStoreConnection().isClosed();
		}
		catch (SQLException e) {
			throw new StoreException("Problem inspecting connection", e);
		}
	}

	/**
	 * Closes the connection, freeing resources. If the connection is not in
	 * autoCommit mode, all non-committed operations will be lost.
	 * 
	 * @throws StoreException
	 *         If the connection could not be closed.
	 */
	public void close() throws StoreException {
		dropDelayAdd();
		try {
			if (!getQuadStoreConnection().isClosed()) {
				getQuadStoreConnection().close();
			}
		}
		catch (SQLException e) {
			throw new StoreException(e);
		}
	}



	protected void finalize() throws Throwable
	{
		try {
			if (isOpen()) {
				close();
			}
		}
		finally {
			super.finalize();
		}
	}


	/**
	 * Retrieves this connection's current transaction isolation level.
	 * 
	 * @return The current transaction isolation level.
	 * @exception StoreException
	 *            If an access error occurs or this method is called on a closed
	 *            connection
	 * @see #setTransactionIsolation
	 */
	public Isolation getTransactionIsolation()
		throws StoreException
	{
		verifyIsOpen();
		try {
			int level = getQuadStoreConnection().getTransactionIsolation();
			switch(level) {
			    case Connection.TRANSACTION_NONE:
				return Isolation.NONE;
			    case Connection.TRANSACTION_READ_UNCOMMITTED:
				return Isolation.READ_UNCOMMITTED;
			    case Connection.TRANSACTION_READ_COMMITTED:
				return Isolation.READ_COMMITTED;
			    case Connection.TRANSACTION_REPEATABLE_READ:
				return Isolation.REPEATABLE_READ;
			    case Connection.TRANSACTION_SERIALIZABLE:
				return Isolation.SERIALIZABLE;
			    default:
				return Isolation.NONE;
			}
		}
		catch (SQLException e) {
			throw new StoreException(e);
		}
	}

	/**
	 * Attempts to change the transaction isolation level for this connection to
	 * the specified value.
	 * <P>
	 * <B>Note:</B> If this method is called during a transaction, the result is
	 * implementation-defined.
	 * 
	 * @param isolation
	 *        Any Isolation except for {@link Isolation#NONE NONE}, since that
	 *        indicates that transactions are not supported.
	 * @exception StoreException
	 *            If an access error occurs, this method is called on a closed
	 *            connection
	 * @see #getTransactionIsolation
	 */
	public void setTransactionIsolation(Isolation isolation)
		throws StoreException
	{
		verifyIsOpen();
		try {
			switch(isolation) {
			    case NONE:
				getQuadStoreConnection().setTransactionIsolation(Connection.TRANSACTION_NONE);
				break;
			    case READ_UNCOMMITTED:
				getQuadStoreConnection().setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);
				break;
			    case READ_COMMITTED:
				getQuadStoreConnection().setTransactionIsolation(Connection.TRANSACTION_READ_COMMITTED);
				break;
			    case REPEATABLE_READ:
				getQuadStoreConnection().setTransactionIsolation(Connection.TRANSACTION_REPEATABLE_READ);
				break;
			    case SERIALIZABLE:
				getQuadStoreConnection().setTransactionIsolation(Connection.TRANSACTION_SERIALIZABLE);
				break;
			    default:
				throw new SQLException("Unsupported isolation level "+isolation);
			}
		}
		catch (SQLException e) {
			throw new StoreException(e);
		}
	}

	/**
	 * Indicates whether this connection is in read-only mode.
	 * 
	 * @return <tt>true</tt> if this Connection object is read-only;
	 *         <tt>false</tt> otherwise.
	 * @throws StoreException
	 *         If a repository access error occurs.
	 */
	public boolean isReadOnly()
		throws StoreException
	{
		verifyIsOpen();
		try {
			return getQuadStoreConnection().isReadOnly();
		}
		catch (SQLException e) {
			throw new StoreException(e);
		}
	}

	/**
	 * Puts this connection in read-only mode as a hint to the driver to enable
	 * repository optimizations.
	 * <p>
	 * <b>Note:</b> This method cannot be called during a transaction.
	 * 
	 * @param readOnly
	 *        <tt>true</tt> enables read-only mode; <tt>false</tt> disables it
	 * @throws StoreException
	 *         If a repository access error occurs or this method is called
	 *         during a transaction.
	 */
	public void setReadOnly(boolean readOnly)
		throws StoreException
	{
		verifyIsOpen();
		try {
			getQuadStoreConnection().setReadOnly(readOnly);
		}
		catch (SQLException e) {
			throw new StoreException(e);
		}
	}


	/**
	 * Prepares a query for evaluation on this repository (optional operation).
	 * In case the query contains relative URIs that need to be resolved against
	 * an external base URI, one should use
	 * {@link #prepareQuery(QueryLanguage, String, String)} instead.
	 * 
	 * @param language
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
	public Query prepareQuery(QueryLanguage language, String query) 
		throws StoreException, MalformedQueryException 
	{
		return prepareQuery(language, query, null);
	}

	/**
	 * Prepares a query for evaluation on this repository (optional operation).
	 * 
	 * @param language
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
	public Query prepareQuery(QueryLanguage language, String query, String baseURI) 
		throws StoreException, MalformedQueryException 
	{
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

		if(type.equals("select"))
			return prepareTupleQuery(language, query, baseURI);
		else if(type.equals("construct") || type.equals("describe"))
			return prepareGraphQuery(language, query, baseURI);
		else if(type.equals("ask"))
			return prepareBooleanQuery(language, query, baseURI);
		else
			return new VirtuosoQuery();
	}

	/**
	 * Prepares a query that produces sets of value tuples. In case the query
	 * contains relative URIs that need to be resolved against an external base
	 * URI, one should use
	 * {@link #prepareTupleQuery(QueryLanguage, String, String)} instead.
	 * 
	 * @param language
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
	public TupleQuery prepareTupleQuery(QueryLanguage language, String query) 
		throws StoreException, MalformedQueryException 
	{
		return prepareTupleQuery(language, query, null);
	}

	/**
	 * Prepares a query that produces sets of value tuples.
	 * 
	 * @param language
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
	public TupleQuery prepareTupleQuery(QueryLanguage langauge, final String query, String baseeURI) 
		throws StoreException, MalformedQueryException 
	{
//??TODO use another new options limit,offset,timeout
		TupleQuery q = new VirtuosoTupleQuery() {
			public TupleResult evaluate() throws StoreException
			{
				return executeSPARQLForTupleResult(query, getDataset(), getIncludeInferred(), getBindings());
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
	 * @param language
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
	public GraphQuery prepareGraphQuery(QueryLanguage language, String query) 
		throws StoreException, MalformedQueryException 
	{
		return prepareGraphQuery(language, query, null);
	}

	/**
	 * Prepares queries that produce RDF graphs.
	 * 
	 * @param language
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
//??TODO use another new options timeout
	public GraphQuery prepareGraphQuery(QueryLanguage language, final String query, String baseURI) 
		throws StoreException, MalformedQueryException 
	{
		GraphQuery q = new VirtuosoGraphQuery() {
			public GraphResult evaluate() throws StoreException {
				return executeSPARQLForGraphResult(query, getDataset(), getIncludeInferred(), getBindings());
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
	 * @param language
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
	public BooleanQuery prepareBooleanQuery(QueryLanguage language, String query) 
		throws StoreException, MalformedQueryException 
	{
		return prepareBooleanQuery(language, query, null);
	}

	/**
	 * Prepares <tt>true</tt>/<tt>false</tt> queries.
	 * 
	 * @param language
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
//??TODO use another new options timeout
	public BooleanQuery prepareBooleanQuery(QueryLanguage language, final String query, String baseURI) 
		throws StoreException, MalformedQueryException 
	{
		BooleanQuery q = new VirtuosoBooleanQuery() {
			public boolean ask() throws StoreException {
				return executeSPARQLForBooleanResult(query, getDataset(), getIncludeInferred(), getBindings());
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
	public ContextResult getContextIDs()
		throws StoreException 
	{
		verifyIsOpen();
		flushDelayAdd();
		List<Resource> v = new LinkedList<Resource>();

		String query = "DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS()";
		try {
			java.sql.Statement stmt = createStatement();
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
					throw new StoreException("VirtuosoRepositoryConnection.getContextIDs() Non-URI context encountered: " + obj, iiaex);
				}
			}
			rs.close();

		}
		catch (SQLException e) {
			throw new StoreException(": SPARQL execute failed." + "\n" + query.toString(), e);
		}
		return new ContextResultImpl(new CollectionCursor<Resource>(v));

	}


	/**
	 * Gets all statements with a specific subject, predicate and/or object from
	 * the repository. The result is optionally restricted to the specified set
	 * of named contexts.
	 * 
	 * @param subj
	 *        A Resource specifying the subject, or <tt>null</tt> for a wildcard.
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
	 *         is a {@link ModelResult} object, a lazy Iterator-like object
	 *         containing {@link Statement}s and optionally throwing a
	 *         {@link StoreException} when an error when a problem occurs during
	 *         retrieval.
	 * @deprecated Use {@link #match(Resource,URI,Value,boolean,Resource...)}
	 *             instead
	 */
	@Deprecated
	public ModelResult getStatements(Resource subj, URI pred, Value obj, boolean includeInferred, Resource... contexts) 
		throws StoreException 
	{
		return match(subj, pred, obj, includeInferred, contexts);
	}


	/**
	 * Gets all statements with a specific subject, predicate and/or object from
	 * the repository. The result is optionally restricted to the specified set
	 * of named contexts.
	 * 
	 * @param subj
	 *        A Resource specifying the subject, or <tt>null</tt> for a wildcard.
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
	 *         is a {@link ModelResult} object, a lazy Iterator-like object
	 *         containing {@link Statement}s and optionally throwing a
	 *         {@link StoreException} when an error when a problem occurs during
	 *         retrieval.
	 */
	public ModelResult match(Resource subj, URI pred, Value obj, boolean includeInferred, Resource... contexts)
		throws StoreException
	{
		contexts = checkContext(contexts);
		return new ModelResultImpl(selectFromQuadStore(subj, pred, obj, includeInferred, false, contexts));
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
	@Deprecated
	public boolean hasStatement(Resource subject, URI predicate, Value object, boolean includeInferred, Resource... contexts) 
		throws StoreException 
	{
		return hasMatch(subject, predicate, object, includeInferred, contexts);
	}


	/**
	 * Checks whether the repository contains statements with a specific subject,
	 * predicate and/or object, optionally in the specified contexts.
	 * 
	 * @param subj
	 *        A Resource specifying the subject, or <tt>null</tt> for a wildcard.
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
	public boolean hasMatch(Resource subj, URI pred, Value obj, boolean includeInferred, Resource... contexts)
		throws StoreException
	{
		contexts = checkContext(contexts);
                Cursor<Statement> it;
                it = selectFromQuadStore(subj, pred, obj, includeInferred, true, contexts);
                try {
                	return (it.next() != null);
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
	public boolean hasStatement(Statement st, boolean includeInferred, Resource... contexts) 
		throws StoreException 
	{
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
	@Deprecated
	public void exportStatements(Resource subj, URI pred, Value obj, boolean includeInferred, RDFHandler handler, Resource... contexts) 
		throws StoreException, RDFHandlerException 
	{
		exportMatch(subj, pred, obj, includeInferred, handler, contexts);
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
	public <H extends RDFHandler> H exportMatch(Resource subj, URI pred, Value obj, 
			boolean includeInferred, H handler, Resource... contexts)
		throws StoreException, RDFHandlerException
	{
		handler.startRDF();

		// Export namespace information
		NamespaceResult nsIt = getNamespaces();
		try {
			while (nsIt.hasNext()) {
				Namespace ns = nsIt.next();
				handler.handleNamespace(ns.getPrefix(), ns.getName());
			}
		}
		finally {
			nsIt.close();
		}

		// Export statements
		ModelResult stIt = match(subj, pred, obj, includeInferred, contexts);
		try {
			while (stIt.hasNext()) {
				handler.handleStatement(stIt.next());
			}
		}
		finally {
			stIt.close();
		}

		handler.endRDF();
		return handler;
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
	public <H extends RDFHandler> H export(H handler, Resource... contexts)
		throws StoreException, RDFHandlerException
	{
		return exportMatch(null, null, null, false, handler, contexts);
	}



	public void verifyContextNotNull(Resource... contexts) throws StoreException {
		if (contexts == null) {
			throw new StoreException(
					"Illegal value null array for contexts argument; either the value should be cast to Resource or an empty array should be supplied");
		}
	}

	private Resource[] checkDMLContext(Resource... contexts) 
		throws StoreException 
	{
		verifyContextNotNull(contexts);
		if(contexts != null && contexts.length == 1 && contexts[0] == null) {
			contexts = new Resource[] {nilContext};
		}
		else if (contexts == null || contexts.length == 0) {
			contexts = new Resource[] {nilContext};
		}
		return contexts;
	}

	private Resource[] checkContext(Resource... contexts) 
		throws StoreException 
	{
		verifyContextNotNull(contexts);
		if(contexts != null && contexts.length == 1 && contexts[0] == null) {
			contexts = new Resource[] {nilContext};
		}
		else if (contexts == null || contexts.length == 0) {
			contexts = new Resource[0];
		}
		return contexts;
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
	public long size(Resource... contexts) throws StoreException 
	{
		return sizeMatch(null, null, null, false, contexts);
	}


	/**
	 * Returns the number of statements that match in the specified pattern in
	 * this repository.
	 * 
	 * @param subj
	 *        The subject, or null if the subject doesn't matter.
	 * @param pred
	 *        The predicate, or null if the predicate doesn't matter.
	 * @param obj
	 *        The object, or null if the object doesn't matter.
	 * @param includeInferred
	 *        Indicates whether inferred statements should be counted.
	 * @param contexts
	 *        The context(s) to get the data from. Note that this parameter is a
	 *        vararg and as such is optional. If no contexts are supplied the
	 *        method matches the pattern on the entire repository.
	 * @return The number of explicit statements from the specified pattern in
	 *         this repository.
	 * @deprecated Use {@link #sizeMatch(Resource,URI,Value,boolean,Resource...)}
	 *             instead
	 */
	@Deprecated
	public long size(Resource subj, URI pred, Value obj, boolean includeInferred, Resource... contexts)
		throws StoreException
	{
		return sizeMatch(subj, pred, obj, includeInferred, contexts);
	}

	/**
	 * Returns the number of statements that match in the specified pattern in
	 * this repository.
	 * 
	 * @param subj
	 *        The subject, or null if the subject doesn't matter.
	 * @param pred
	 *        The predicate, or null if the predicate doesn't matter.
	 * @param obj
	 *        The object, or null if the object doesn't matter.
	 * @param includeInferred
	 *        Indicates whether inferred statements should be counted.
	 * @param contexts
	 *        The context(s) to get the data from. Note that this parameter is a
	 *        vararg and as such is optional. If no contexts are supplied the
	 *        method matches the pattern on the entire repository.
	 * @return The number of explicit statements from the specified pattern in
	 *         this repository.
	 */
	public long sizeMatch(Resource subj, URI pred, Value obj, boolean includeInferred, Resource... contexts)
		throws StoreException
	{
		return selectCountFromQuadStore(subj, pred, obj, includeInferred, contexts);
	}


	/**
	 * Returns <tt>true</tt> if this repository does not contain any (explicit)
	 * statements.
	 * 
	 * @return <tt>true</tt> if this repository is empty, <tt>false</tt>
	 *         otherwise.
	 * @throws StoreException
	 *         If the repository could not be checked to be empty.
	 */
	public boolean isEmpty() throws StoreException 
	{
		verifyIsOpen();
		flushDelayAdd();
		boolean result = false;
		String query = "sparql define input:storage \"\" select * where {?s ?o ?p} limit 1";
		try {
			java.sql.Statement stmt = createStatement();
			ResultSet rs = stmt.executeQuery(query);
			result = !rs.next();
                        rs.close();
                        return result;
		}
		catch (SQLException e) {
			throw new StoreException("Problem executing query: " + query, e);
		}
	}


	/**
	 * Checks whether the connection is in auto-commit mode.
	 * 
	 * @see #setAutoCommit
	 */
	public boolean isAutoCommit() throws StoreException 
	{
		verifyIsOpen();
		try {
			return getQuadStoreConnection().getAutoCommit();
		}
		catch (SQLException e) {
			throw new StoreException(e);
		}
	}

	/**
	 * Begins a transaction requiring {@link #commit()} or {@link #rollback()} to
	 * be called to close the transaction.
	 * 
	 * @throws StoreException
	 *         If the connection could not start a transaction, or if it already
	 *         has an active transaction.
	 * @see #isAutoCommit()
	 */
	public void begin() throws StoreException
	{
		verifyIsOpen();
		verifyNotTxnActive("Connection already has an active transaction");
		flushDelayAdd();
		try {
			getQuadStoreConnection().setAutoCommit(false);
		}
		catch (SQLException e) {
			throw new StoreException(e);
		}
	}

	/**
	 * Commits all updates that have been performed as part of this connection
	 * sofar.
	 * 
	 * @throws StoreException
	 *         If the connection could not be committed.
	 */
	public void commit() throws StoreException 
	{
		verifyIsOpen();
//--		verifyTxnActive();
		flushDelayAdd();
		try {
			getQuadStoreConnection().commit();
			getQuadStoreConnection().setAutoCommit(true);
		}
		catch (SQLException e) {
			throw new StoreException(e);
		}
	}

	/**
	 * Rolls back all updates that have been performed as part of this connection
	 * sofar.
	 * 
	 * @throws StoreException
	 *         If the connection could not be rolled back.
	 */
	public void rollback() throws StoreException 
	{
		verifyIsOpen();
//--		verifyTxnActive();
		dropDelayAdd();
		try {
			getQuadStoreConnection().rollback();
			getQuadStoreConnection().setAutoCommit(true);
		}
		catch (SQLException e) {
			throw new StoreException("Problem with rollback", e);
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
	 * @throws StoreException
	 *         If the data could not be added to the repository, for example
	 *         because the repository is not writable.
	 */
	public void add(InputStream in, String baseURI, RDFFormat format, Resource... contexts) 
		throws IOException, RDFParseException, StoreException 
	{
		verifyIsOpen();
		verifyNotReadOnly();

		if (repository.isReadOnly()) {
			throw new StoreException("Repository is ReadOnly");
		}

		if (!in.markSupported()) {
			in = new BufferedInputStream(in, 1024);
		}

		if (ZipUtil.isZipStream(in)) {
			addZip(in, baseURI, format, contexts);
		}
		else if (GZipUtil.isGZipStream(in)) {
			add(new InputStreamReader(new GZIPInputStream(in)), baseURI, format, contexts);
		}
		else {
			add(new InputStreamReader(in), baseURI, format, contexts);
		}

	}


	private void addZip(InputStream in, String baseURI, RDFFormat dataFormat, Resource... contexts)
		throws IOException, RDFParseException, StoreException
	{
		boolean autoCommit = isAutoCommit();

		if (autoCommit) {
			// Add the zip in a single transaction
			begin();
		}

		try {
			ZipInputStream zipIn = new ZipInputStream(in);

			try {
				for (ZipEntry entry = zipIn.getNextEntry(); entry != null; entry = zipIn.getNextEntry()) {
					if (entry.isDirectory()) {
						continue;
					}

					RDFFormat format = Rio.getParserFormatForFileName(entry.getName(), dataFormat);

					try {
						// Prevent parser (Xerces) from closing the input stream
						FilterInputStream wrapper = new FilterInputStream(zipIn) {

							public void close() {
							}
						};
						add(new InputStreamReader(wrapper), baseURI, format, contexts);
					}
					catch (RDFParseException e) {
						String msg = e.getMessage() + " in " + entry.getName();
						RDFParseException pe = new RDFParseException(msg, e.getLineNumber(), e.getColumnNumber());
						pe.initCause(e);
						throw pe;
					}
					finally {
						zipIn.closeEntry();
					}
				}
			}
			finally {
				zipIn.close();
			}

			if (autoCommit) {
				commit();
			}
		}
		finally {
			if (autoCommit && !isAutoCommit()) {
				// restore auto-commit by rolling back
				rollback();
			}
		}
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
	 * @param format
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
	 * @throws StoreException
	 *         If the data could not be added to the repository, for example
	 *         because the repository is not writable.
	 */
	public void add(Reader reader, String baseURI, RDFFormat format, final Resource... contexts) 
		throws IOException, RDFParseException, StoreException 
	{
		verifyIsOpen();
		verifyNotReadOnly();

		if (repository.isReadOnly()) {
			throw new StoreException("Repository is ReadOnly");
		}

		sendDelayAdd();

		final boolean useStatementContext = (contexts != null && contexts.length == 0); // If no context are specified, each statement is added to statement context
		boolean autoCommit = isAutoCommit();
		if (autoCommit) {
			// Add the stream in a single transaction
			begin();
                }

		try {
			RDFParser parser = Rio.createParser(format, getValueFactory());

			// set up a handler for parsing the data from reader
			parser.setVerifyData(true);
			parser.setStopAtFirstError(true);
			parser.setDatatypeHandling(RDFParser.DatatypeHandling.IGNORE);

                        RDFHandlerBase rdfInserter = new RDFHandlerBase() {
				
				int count = 0;
				PreparedStatement ps = null;
				Resource[] _contexts = checkDMLContext(contexts);

				public void startRDF() throws RDFHandlerException {
					if (ps == null) 
						try {
				        		ps = prepareStatement(VirtuosoRepositoryConnection.S_INSERT);
				        	} catch (java.sql.SQLException e) {
							throw new RDFHandlerException("Problem PrepareStatement: ", e);
				        	}
				}


				public void endRDF() throws RDFHandlerException {
					try {
						if (count > 0) {
							ps.executeBatch();
							ps.clearBatch();
							count = 0;
						}
						if (ps != null) {
							ps.close();
							ps = null;
						}
					}
					catch (SQLException e) {
						throw new RDFHandlerException("Problem executing query: ", e);
					}
				}

				public void handleNamespace(String prefix, String name) throws RDFHandlerException {
					String query = "DB.DBA.XML_SET_NS_DECL(?, ?, 1)";
					try {
						PreparedStatement psn = prepareStatement(query);
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
					for (int i = 0; i < hcontexts.length; i++) {
						ps.setString(1, hcontexts[i].stringValue());
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
			};

			parser.setRDFHandler(rdfInserter);
			parser.parse(reader, baseURI); // parse out each tripled to be handled by the handler above

			if (autoCommit)
				commit();

		}
		catch (Exception e) {
			if (autoCommit)
				rollback();
			throw new StoreException("Problem parsing triples", e);
		}
		finally {
			if (autoCommit && !isAutoCommit()) {
				// restore auto-commit by rolling back
				rollback();
			}
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
	 * @param format
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
	 * @throws StoreException
	 *         If the data could not be added to the repository, for example
	 *         because the repository is not writable.
	 */
	public void add(URL dataURL, String baseURI, RDFFormat format, Resource... contexts) 
		throws IOException, RDFParseException, StoreException 
	{
		// add data to Sesame
		if (baseURI == null) {
			baseURI = dataURL.toExternalForm();
		}
		if (format == null) {
			format = Rio.getParserFormatForFileName(dataURL.getPath());
		}
		Reader reader = new InputStreamReader(dataURL.openStream());
		try {
			add(reader, baseURI, format, contexts);
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
	 * @param format
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
	 * @throws StoreException
	 *         If the data could not be added to the repository, for example
	 *         because the repository is not writable.
	 */
	public void add(File file, String baseURI, RDFFormat format, Resource... contexts) 
		throws IOException, RDFParseException, StoreException 
	{
		if (baseURI == null) {
			// default baseURI to file
			baseURI = file.toURI().toString();
		}
		InputStream reader = new FileInputStream(file);
		try {
			add(reader, baseURI, format, contexts);
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
	 * @throws StoreException
	 *         If the data could not be added to the repository, for example
	 *         because the repository is not writable.
	 */
	public void add(Resource subject, URI predicate, Value object, Resource... contexts) 
		throws StoreException 
	{
		contexts = checkDMLContext(contexts);
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
	 * @throws StoreException
	 *         If the statement could not be added to the repository, for example
	 *         because the repository is not writable.
	 */
	public void add(Statement st, Resource... contexts) 
		throws StoreException 
	{
		if (contexts != null && contexts.length == 0 &&  st.getContext() != null) {
				contexts = new Resource[] { st.getContext() }; // try the context given by the statement
		}
		add(st.getSubject(), st.getPredicate(), st.getObject(), contexts);
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
	 * @throws StoreException
	 *         If the statements could not be added to the repository, for
	 *         example because the repository is not writable.
	 */
	public void add(Iterable<? extends Statement> statements, Resource... contexts) 
		throws StoreException 
	{
		verifyIsOpen();
		verifyNotReadOnly();

		if (repository.isReadOnly()) {
			throw new StoreException("Repository is ReadOnly");
		}

		sendDelayAdd();

		Iterator it = statements.iterator();

		boolean useStatementContext = (contexts != null && contexts.length == 0); // If no context are specified, each statement is added to statement context
		Resource[] _contexts = checkDMLContext(contexts); // otherwise, either use all contexts, or do not specify a context

		boolean autoCommit = isAutoCommit();
		if (autoCommit) {
			// Add the statements in a single transaction
			begin();
		}

		try {
			PreparedStatement ps = prepareStatement(VirtuosoRepositoryConnection.S_INSERT);
			int count = 0;

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
			ps.close();
			if (autoCommit) {
				commit();
			}
		}	
		catch(SQLException e) {
			if (autoCommit)
				rollback();
		   	throw new StoreException(e);
		}
		finally {
			if (autoCommit && !isAutoCommit()) {
				// restore auto-commit by rolling back
				rollback();
			}
		}
	}



	/**
	 * Adds the supplied statements to this repository, optionally to one or more
	 * named contexts.
	 * 
	 * @param statementIter
	 *        The statements to add. It will be closed before this method
	 *        returns.
	 * @param contexts
	 *        The contexts to add the statements to. Note that this parameter is
	 *        a vararg and as such is optional. If no contexts are specified,
	 *        each statement is added to any context specified in the statement,
	 *        or if the statement contains no context, it is added without
	 *        context. If one or more contexts are specified each statement is
	 *        added to these contexts, ignoring any context information in the
	 *        statement itself. ignored.
	 * @throws StoreException
	 *         If the statements could not be added to the repository, for
	 *         example because the repository is not writable.
	 */
	public void add(Cursor<? extends Statement> statementIter, Resource... contexts)
		throws StoreException 
        {
	        verifyIsOpen();
		verifyNotReadOnly();

		if (repository.isReadOnly()) {
			throw new StoreException("Repository is ReadOnly");
		}

		sendDelayAdd();
  
		boolean useStatementContext = (contexts != null && contexts.length == 0); // If no context are specified, each statement is added to statement context
		Resource[] _contexts = checkDMLContext(contexts); // otherwise, either use all contexts, or do not specify a context
  
		boolean autoCommit = isAutoCommit();
		if (autoCommit) {
			// Add the statements in a single transaction
			begin();
		}
  
		try {
			PreparedStatement ps = prepareStatement(VirtuosoRepositoryConnection.S_INSERT);
			int count = 0;

			Statement st;
			while ((st = statementIter.next()) != null) {

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
			ps.close();

			if (autoCommit) {
				commit();
			}
		}
		catch(SQLException e) {
			if (autoCommit)
				rollback();
		   	throw new StoreException(e);
		}
		finally {
			try {
				if (autoCommit && !isAutoCommit()) {
					// restore auto-commit by rolling back
					rollback();
				}
			}
			finally {
				statementIter.close();
			}
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
	 * @throws StoreException
	 *         If the statement(s) could not be removed from the repository, for
	 *         example because the repository is not writable.
	 */
	@Deprecated
	public void remove(Resource subject, URI predicate, Value object, Resource... contexts) 
		throws StoreException 
	{
		removeMatch(subject, predicate, object, contexts);
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
	 * @throws StoreException
	 *         If the statement(s) could not be removed from the repository, for
	 *         example because the repository is not writable.
	 */
	public void removeMatch(Resource subject, URI predicate, Value object, Resource... contexts)
		throws StoreException
	{
		verifyContextNotNull(contexts);
	        verifyIsOpen();
		verifyNotReadOnly();

		if (repository.isReadOnly()) {
			throw new StoreException("Repository is ReadOnly");
		}

		flushDelayAdd();

		contexts = checkDMLContext(contexts);
		boolean autoCommit = isAutoCommit();
		if (autoCommit) {
			// Add the statements in a single transaction
			begin();
		}

		try {
			for (int i = 0; i < contexts.length; i++)
		     		removeContext(subject, predicate, object, contexts[i]);
			if (autoCommit) {
				commit();
			}
		}
		catch(StoreException e) {
			if (autoCommit)
				rollback();
		   	throw e;
		}
		finally {
			if (autoCommit && !isAutoCommit()) {
				// restore auto-commit by rolling back
				rollback();
			}
		}
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
	 * @throws StoreException
	 *         If the statement could not be removed from the repository, for
	 *         example because the repository is not writable.
	 */
	public void remove(Statement st, Resource... contexts) 
		throws StoreException 
	{
		if (contexts != null && contexts.length == 0 &&  st.getContext() != null) {
			contexts = new Resource[] { st.getContext() }; // try the context given by the statement
		}
		remove(st.getSubject(), st.getPredicate(), st.getObject(), contexts);
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
	 * @throws StoreException
	 *         If the statements could not be added to the repository, for
	 *         example because the repository is not writable.
	 */
	public void remove(Iterable<? extends Statement> statements, Resource... contexts) 
		throws StoreException 
	{
		verifyContextNotNull(contexts);
		verifyIsOpen();
		verifyNotReadOnly();

		if (repository.isReadOnly()) {
			throw new StoreException("Repository is ReadOnly");
		}

		flushDelayAdd();

		Resource[] _contexts;
		Iterator<? extends Statement> it = statements.iterator();

		boolean autoCommit = isAutoCommit();
		if (autoCommit) {
			// Add the statements in a single transaction
			begin();
		}

		try {
			while (it.hasNext()) {
				Statement st = it.next();

				if (contexts != null && contexts.length == 0 &&  st.getContext() != null) {
					_contexts = new Resource[] { st.getContext() }; // try the context given by the statement
				} else {
					_contexts = contexts;
				}
				_contexts = checkDMLContext(_contexts);

				for (int i = 0; i < _contexts.length; i++)
		     			removeContext(st.getSubject(), st.getPredicate(), st.getObject(), _contexts[i]);
		     	}
			
			if (autoCommit)
				commit();
		}
		catch(StoreException e) {
			if (autoCommit)
				rollback();
		   	throw e;
		}
		catch(RuntimeException e) {
			if (autoCommit)
				rollback();
		   	throw e;
		}
		finally {
			if (autoCommit && !isAutoCommit()) {
				// restore auto-commit by rolling back
				rollback();
			}
		}
	}



	/**
	 * Removes the supplied statements from a specific context in this
	 * repository, ignoring any context information carried by the statements
	 * themselves.
	 * 
	 * @param stIter
	 *        The statements to remove. It will be closed before this method
	 *        returns.
	 * @param contexts
	 *        The context(s) to remove the data from. Note that this parameter is
	 *        a vararg and as such is optional. If no contexts are supplied the
	 *        method operates on the contexts associated with the statement
	 *        itself, and if no context is associated with the statement, on the
	 *        entire repository.
	 * @throws StoreException
	 *         If the statements could not be removed from the repository, for
	 *         example because the repository is not writable.
	 */
	public void remove(Cursor<? extends Statement> stIter, Resource... contexts)
		throws StoreException
	{
		verifyContextNotNull(contexts);
		verifyIsOpen();
		verifyNotReadOnly();

		if (repository.isReadOnly()) {
			throw new StoreException("Repository is ReadOnly");
		}

		flushDelayAdd();

		boolean autoCommit = isAutoCommit();
		if (autoCommit) {
			// Add the statements in a single transaction
			begin();
		}

		try {
			Statement st;
			while ((st = stIter.next()) != null) {
				remove(st, contexts);
			}

			if (autoCommit) {
				commit();
			}
		}
		catch(StoreException e) {
			if (autoCommit)
				rollback();
		   	throw e;
		}
		catch(RuntimeException e) {
			if (autoCommit)
				rollback();
		   	throw e;
		}
		finally {
			try {
				if (autoCommit && !isAutoCommit()) {
					// restore auto-commit by rolling back
					rollback();
				}
			}
			finally {
				stIter.close();
			}
		}
	}



	/**
	 * Removes all statements from a specific contexts in the repository.
	 * 
	 * @param contexts
	 *        The context(s) to remove the data from. Note that this parameter is
	 *        a vararg and as such is optional. If no contexts are supplied the
	 *        method operates on the entire repository.
	 * @throws StoreException
	 *         If the statements could not be removed from the repository, for
	 *         example because the repository is not writable.
	 */
	public void clear(Resource... contexts) throws StoreException 
	{
		verifyContextNotNull(contexts);
		verifyIsOpen();
		verifyNotReadOnly();

		if (repository.isReadOnly()) {
			throw new StoreException("Repository is ReadOnly");
		}

		flushDelayAdd();

		contexts = checkDMLContext(contexts);

		boolean autoCommit = isAutoCommit();
		if (autoCommit) {
			// Add the zip in a single transaction
			begin();
		}

		try {
			clearQuadStore(contexts);
			if (autoCommit) {
				commit();
			}
		}
		catch(StoreException e) {
			if (autoCommit)
				rollback();
		   	throw e;
		}
		catch(RuntimeException e) {
			if (autoCommit)
				rollback();
		   	throw e;
		}
		finally {
			if (autoCommit && !isAutoCommit()) {
				// restore auto-commit by rolling back
				rollback();
			}
		}
	}

	/**
	 * Gets all declared namespaces as a RepositoryResult of {@link Namespace}
	 * objects. Each Namespace object consists of a prefix and a namespace name.
	 * 
	 * @return A RepositoryResult containing Namespace objects. Care should be
	 *         taken to close the RepositoryResult after use.
	 * @throws StoreException
	 *         If the namespaces could not be read from the repository.
	 */
	public NamespaceResult getNamespaces()
		throws StoreException 
	{
		verifyIsOpen();
		flushDelayAdd();
		List<Namespace> namespaceList = new LinkedList<Namespace>();
		String query = "DB.DBA.XML_SELECT_ALL_NS_DECLS (3)";
		try {
			java.sql.Statement stmt = createStatement();
			ResultSet rs = stmt.executeQuery(query);

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
		catch (SQLException e) {
			throw new StoreException(e);
		}
		return new NamespaceResultImpl(new CollectionCursor<Namespace>(namespaceList));
	}

	/**
	 * Gets the namespace that is associated with the specified prefix, if any.
	 * 
	 * @param prefix
	 *        A namespace prefix.
	 * @return The namespace name that is associated with the specified prefix,
	 *         or <tt>null</tt> if there is no such namespace.
	 * @throws StoreException
	 *         If the namespace could not be read from the repository.
	 */
	public String getNamespace(String prefix) throws StoreException 
	{
		verifyIsOpen();
		flushDelayAdd();
		String retVal = null;
		String query = "SELECT __xml_get_ns_uri (?, 3)";
		try {
			PreparedStatement ps = prepareStatement(query);
			ps.setString(1, prefix);
			ResultSet rs = ps.executeQuery();

			// begin at onset one
			while (rs.next()) {
				retVal = rs.getString(1);
				break;
			}
			rs.close();
		}
		catch (SQLException e) {
			throw new StoreException(e);
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
	 * @throws StoreException
	 *         If the namespace could not be set in the repository, for example
	 *         because the repository is not writable.
	 */
	public void setNamespace(String prefix, String name) 
		throws StoreException 
	{
		verifyIsOpen();
		flushDelayAdd();
		if (repository.isReadOnly()) {
			throw new StoreException("Repository is ReadOnly");
		}
		String query = "DB.DBA.XML_SET_NS_DECL(?, ?, 1)";
		try {
			PreparedStatement ps = prepareStatement(query);
			ps.setString(1, prefix);
			ps.setString(2, name);
			ps.execute();
			ps.close();
		}
		catch (SQLException e) {
			throw new StoreException("Problem executing query: " + query, e);
		}
	}

	/**
	 * Removes a namespace declaration by removing the association between a
	 * prefix and a namespace name.
	 * 
	 * @param prefix
	 *        The namespace prefix of which the assocation with a namespace name
	 *        is to be removed.
	 * @throws StoreException
	 *         If the namespace prefix could not be removed.
	 */
	public void removeNamespace(String prefix) throws StoreException 
	{
		verifyIsOpen();
		verifyNotReadOnly();

		if (repository.isReadOnly()) {
			throw new StoreException("Repository is ReadOnly");
		}
		flushDelayAdd();
		String query = "DB.DBA.XML_REMOVE_NS_BY_PREFIX(?, 1)";
		try {
			PreparedStatement ps = prepareStatement(query);
			ps.setString(1, prefix);
			ps.execute(query);
			ps.close();
		}
		catch (SQLException e) {
			throw new StoreException("Problem executing query: " + query, e);
		}
	}

	/**
	 * Removes all namespace declarations from the repository.
	 * 
	 * @throws StoreException
	 *         If the namespace declarations could not be removed.
	 */
	public void clearNamespaces() throws StoreException 
	{
		verifyIsOpen();
		verifyNotReadOnly();

		if (repository.isReadOnly()) {
			throw new StoreException("Repository is ReadOnly");
		}

		flushDelayAdd();
		String query = "DB.DBA.XML_CLEAR_ALL_NS_DECLS()";
		try {
			java.sql.Statement stmt = createStatement();
			stmt.execute(query);
			stmt.close();
		}
		catch (SQLException e) {
			throw new StoreException("Problem executing query: " + query, e);
		}
	}


	protected TupleResult executeSPARQLForTupleResult(String query, Dataset dataset, boolean includeInferred, BindingSet bindings) throws StoreException
	{
		List<String> names = new LinkedList<String>();
		try {
			verifyIsOpen();
			flushDelayAdd();
			java.sql.Statement stmt = createStatement();
			ResultSet rs = stmt.executeQuery(fixQuery(query, dataset, includeInferred, bindings));

			ResultSetMetaData rsmd = rs.getMetaData();

			// begin at onset one
			for (int i = 1; i <= rsmd.getColumnCount(); i++) {
				String col = rsmd.getColumnName(i);
				if (names.indexOf(col) < 0) 
					names.add(col); // no duplicates
			}
			return new TupleResultImpl(names, new CursorBindingSet(rs));
		}
		catch (SQLException e) {
			throw new StoreException(": SPARQL execute failed:["+query+"] \n Exception:"+e);
		}
	}
	
	protected GraphResult executeSPARQLForGraphResult(String query, Dataset dataset, boolean includeInferred, BindingSet bindings) throws StoreException
	{
		try {
			verifyIsOpen();
			flushDelayAdd();
			java.sql.Statement stmt = createStatement();
			ResultSet rs = stmt.executeQuery(fixQuery(query, dataset, includeInferred, bindings));
			return new GraphResultImpl(new HashMap<String,String>(), new CursorGraphResult(rs));
		}
		catch (SQLException e) {
			throw new StoreException(": SPARQL execute failed:["+query+"] \n Exception:"+e);
		}
		
	}

	protected boolean executeSPARQLForBooleanResult(String query, Dataset dataset, boolean includeInferred, BindingSet bindings) throws StoreException
	{
		boolean result = false;
		try {
			verifyIsOpen();
			flushDelayAdd();
			java.sql.Statement stmt = createStatement();
			ResultSet rs = stmt.executeQuery(fixQuery(query, dataset, includeInferred, bindings));

			while(rs.next())
			{
			  if (rs.getInt(1) == 1)
			  	result = true;
			}
			stmt.close();

			return result;
		}
		catch (SQLException e) {
			throw new StoreException(": SPARQL execute failed:["+query+"] \n Exception:"+e);
		}
	}


	/**
	 * Execute SPARUL query on this repository.
	 * 
	 * @param query
	 *        The query string.
	 * @return A rowUpdateCount.
	 * @throws StoreException
	 *         If the <tt>prepareQuery</tt> method is not supported by this
	 *         repository.
	 */
	public int executeSPARUL(String query) throws StoreException 
	{
		java.sql.Statement stmt = null;
		verifyIsOpen();
		verifyNotReadOnly();

		if (repository.isReadOnly()) {
			throw new StoreException("Repository is ReadOnly");
		}

		try {
			flushDelayAdd();
			stmt = createStatement();
			stmt.execute("sparql\n " + query);
			return stmt.getUpdateCount();
		}
		catch (SQLException e) {
			throw new StoreException(e);
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
	public Connection getQuadStoreConnection() 
	{
		return quadStoreConnection;
	}

	/**
	 * Set Repository Connection.
	 * 
	 * @param quadStoreConnection
	 *        The Repository Connection.
	 */
	public void setQuadStoreConnection(Connection quadStoreConnection) 
	{
		this.quadStoreConnection = quadStoreConnection;
	}


	private java.sql.Statement createStatement() throws java.sql.SQLException
	{
	  java.sql.Statement stmt = quadStoreConnection.createStatement();
	  int timeout = repository.getQueryTimeout();
          if (timeout > 0)
            stmt.setQueryTimeout(timeout);
          stmt.setFetchSize(prefetchSize);
          return stmt;
	}

	private java.sql.PreparedStatement prepareStatement(String sql) throws java.sql.SQLException
	{
	  java.sql.PreparedStatement stmt = quadStoreConnection.prepareStatement(sql);
	  int timeout = repository.getQueryTimeout();
          if (timeout > 0)
            stmt.setQueryTimeout(timeout);
          stmt.setFetchSize(prefetchSize);
          return stmt;
	}
	
	
	private String substBindings(String query, BindingSet bindings) 
	{
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
	        			Value val = bindings.getValue(varName);
	        			if (val != null) {
                  				varData = stringForValue(val);
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

	private String fixQuery(String query, Dataset dataset, boolean includeInferred, BindingSet bindings) 
	{
		StringBuffer ret = new StringBuffer("sparql\n ");

		if (includeInferred && repository.ruleSet!=null && repository.ruleSet.length() > 0)
		  ret.append("define input:inference '"+repository.ruleSet+"'\n ");

		if (dataset != null)
		{
		   Set<URI> list = dataset.getDefaultGraphs();
		   if (list != null)
		   {
		     Iterator<URI> it = list.iterator();
		     while(it.hasNext())
		     {
		       URI v = it.next();
		       ret.append(" define input:default-graph-uri <" + v.stringValue() + "> \n");
		     }
		   }

		   list = dataset.getNamedGraphs();
		   if (list != null)
		   {
		     Iterator<URI> it = list.iterator();
		     while(it.hasNext())
		     {
		       URI v = it.next();
		       ret.append(" define input:named-graph-uri <" + v.stringValue() + "> \n");
		     }
		   }
		}
		ret.append(substBindings(query, bindings));
		return ret.toString();
	}


	private void addToQuadStore(Resource subject, URI predicate, Value object, Resource... contexts) 
		throws StoreException 
	{
		verifyIsOpen();
		verifyNotReadOnly();

		if (repository.isReadOnly()) {
			throw new StoreException("Repository is ReadOnly");
		}

		try {
			boolean isAutoCommit = getQuadStoreConnection().getAutoCommit();
		        synchronized(this) {
		        	if (!isAutoCommit && useLazyAdd) {
		        		if (psInsert == null)
						psInsert = prepareStatement(VirtuosoRepositoryConnection.S_INSERT);

					for (int i = 0; i < contexts.length; i++) {
						psInsert.setString(1, contexts[i].stringValue());
						bindResource(psInsert, 2, subject);
						bindURI(psInsert, 3, predicate);
						bindValue(psInsert, 4, object);

						psInsert.addBatch();
						psInsertCount++;
					}
					if (psInsertCount >= BATCH_SIZE) {
						psInsert.executeBatch();
						psInsert.clearBatch();
						psInsertCount = 0;
					}
		        	} else {
		        		if (psInsert == null)
						psInsert = prepareStatement(VirtuosoRepositoryConnection.S_INSERT);

					for (int i = 0; i < contexts.length; i++) {
						psInsert.setString(1, contexts[i].stringValue());
						bindResource(psInsert, 2, subject);
						bindURI(psInsert, 3, predicate);
						bindValue(psInsert, 4, object);

						psInsert.addBatch();
					}
					psInsert.executeBatch();
					psInsert.clearBatch();
		        	}
		        }
		}
		catch (SQLException e) {
			throw new StoreException(e);
		}
	}

	private void sendDelayAdd() throws StoreException 
	{
		synchronized(this) {
			try {
				if (psInsertCount >= BATCH_SIZE && psInsert!=null) {
					psInsert.executeBatch();
					psInsert.clearBatch();
					psInsertCount = 0;
				}
			}
			catch (Exception e) {
			}
		}
	}

	private void flushDelayAdd() throws StoreException 
	{
		synchronized(this) {
			try {
				if (psInsertCount > 0 && psInsert!=null) {
					psInsert.executeBatch();
					psInsert.clearBatch();
					psInsertCount = 0;
				}
			}
			catch (Exception e) {
			}
		}
	}

	private void dropDelayAdd() throws StoreException 
	{
		synchronized(this) {
			try {
				if (psInsertCount >= BATCH_SIZE && psInsert!=null) {
					psInsert.clearBatch();
					psInsertCount = 0;
				}
			} catch (Exception e) {}
		}
	}

	private void clearQuadStore(Resource[] contexts) throws StoreException 
	{
		String  query = "sparql clear graph iri(??)";

                if (contexts!=null && contexts.length > 0)
		  try {
			PreparedStatement ps = prepareStatement(query);
			for (int i = 0; i < contexts.length; i++) {
				ps.setString(1, contexts[i].stringValue());
				ps.execute();
			}
			ps.close();
		  }
		  catch (SQLException e) {
			throw new StoreException(e);
		  }
	}



	private long selectCountFromQuadStore(Resource subject, URI predicate, Value object, boolean includeInferred, Resource... contexts) 
		throws StoreException 
	{
		verifyIsOpen();
		flushDelayAdd();

		String s = "?s";
		String p = "?p";
		String o = "?o";
		long ret = 0;

		if (subject != null) 
			s = stringForResource(subject);
		if (predicate != null) 
			p = stringForURI(predicate);
		if (object != null) 
			o = stringForValue(object);

		StringBuffer query = new StringBuffer("select count(*) from (sparql define input:storage \"\" select * ");

		for (int i = 0; i < contexts.length; i++) {
			query.append("from named <");
			query.append(contexts[i].stringValue());
			query.append("> ");
	        }

		query.append("where { graph ?g {");
		query.append(s);
		query.append(" ");
		query.append(p);
		query.append(" ");
		query.append(o);
		query.append(" }})f");


		try {
		        java.sql.Statement st = createStatement();
		        ResultSet rs = st.executeQuery(query.toString());

			if (rs.next())
			    ret = rs.getLong(1);
                        rs.close();
		}
		catch (SQLException e) {
			throw new StoreException(getClass().getCanonicalName() + ": SPARQL execute failed." + "\n" + query.toString() + "[" + e + "]", e);
		}
		return ret;
	}


	private Cursor<Statement> selectFromQuadStore(Resource subject, URI predicate, Value object, boolean includeInferred, boolean hasOnly, Resource... contexts) 
		throws StoreException 
	{
		verifyIsOpen();
		flushDelayAdd();

		ResultSet rs = null;
		String s = "?s";
		String p = "?p";
		String o = "?o";

		if (subject != null) 
			s = stringForResource(subject);
		if (predicate != null) 
			p = stringForURI(predicate);
		if (object != null) 
			o = stringForValue(object);

		StringBuffer query = new StringBuffer("sparql select * ");

		for (int i = 0; i < contexts.length; i++) {

			query.append("from named <");
			query.append(contexts[i].stringValue());
			query.append("> ");
	        }

		query.append("where { graph ?g {");
		query.append(s);
		query.append(" ");
		query.append(p);
		query.append(" ");
		query.append(o);
		query.append(" }}");
		if (hasOnly)
			query.append(" LIMIT 1");

		try {
			java.sql.Statement stmt = createStatement();
			rs = stmt.executeQuery(query.toString());
		}
		catch (SQLException e) {
			throw new StoreException(getClass().getCanonicalName() + ": SPARQL execute failed." + "\n" + query.toString() + "[" + e + "]",e);
		}

		return new CursorStmt(rs, subject, predicate, object);
	}


	private void removeContext(Resource subject, URI predicate, Value object, Resource context) 
		throws StoreException 
	{
		String S = "?s";
		String P = "?p";
		String O = "?o";

		try {

		    if (subject == null && predicate == null && object == null && context != null) {
			String  query = "sparql clear graph iri(??)";

			PreparedStatement ps = prepareStatement(query);
			ps.setString(1, context.stringValue());
			ps.execute();
			ps.close();

		    } else if (subject != null && predicate != null && object != null && context != null) {

		    	PreparedStatement ps = prepareStatement(VirtuosoRepositoryConnection.S_DELETE);

			ps.setString(1, context.stringValue());
			bindResource(ps, 2, subject);
			bindURI(ps, 3, predicate);
			bindValue(ps, 4, object);
			ps.execute();
			ps.close();

		    } else {

			if (subject != null)
				S = stringForResource(subject);

			if (predicate != null)
				P = stringForURI(predicate);

			if (object != null)
				O = stringForValue(object);

			// s = s.replaceAll("'", "''");
			// p = p.replaceAll("'", "''");
			// o = o.replaceAll("'", "''");
		    	
		    	// context should not be null at this point, at the least, it will be a wildcard
		        String query = "sparql delete from graph <"+context+
  				"> { "+S+" "+P+" "+O+" } from <"+context+
  				"> where { "+S+" "+P+" "+O+" }";

		    	java.sql.Statement stmt = createStatement();
		    	stmt.execute(query);
		    	stmt.close();
		    }
		}
		catch (SQLException e) {
		    throw new StoreException(e);
		}
	}

	
	private void bindResource(PreparedStatement ps, int col, Resource n) 
		throws SQLException 
	{
		if (n == null)
			return;
		if (n instanceof URI) 
			ps.setString(col, n.stringValue());
		else if (n instanceof BNode) 
			ps.setString(col, "_:"+((BNode)n).getID());
		else 
			ps.setString(col, n.stringValue());
	}

	
	private void bindURI(PreparedStatement ps, int col, URI n) 
		throws SQLException 
	{
		if (n == null)
			return;
		ps.setString(col, n.stringValue());
	}

	
	private void bindValue(PreparedStatement ps, int col, Value n) 
		throws SQLException 
	{
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
	

	private String escapeString(String s) {
		StringBuffer buf = new StringBuffer(s.length());
	  	int i = 0;
	  	char ch;
	  	while( i < s.length()) {
	    		ch = s.charAt(i++);
	    		if (ch == '\'') 
				buf.append('\\');
			buf.append(ch);
	  	}
		return buf.toString();
	}

	private String stringForResource(Resource n) 
	{
		if (n instanceof URI) 
			return stringForURI((URI) n);
		else if (n instanceof BNode) 
			return stringForBNode((BNode) n);
		else 
			return "<" + n.stringValue() + ">";
	}

	
	private String stringForURI(URI n) 
	{
		return "<" + n.stringValue() + ">";
	}

	
	private String stringForBNode(BNode n) 
	{
		return "<_:" + n.getID() + ">";
	}

	
	private String stringForValue(Value n) 
	{
		if (n instanceof Resource) 
			return stringForResource((Resource) n);
		else if (n instanceof Literal) {
			Literal lit = (Literal) n;
			String o = "'" + escapeString(lit.stringValue()) + "'";
			if (lit.getLanguage() != null) 
				return o + "@" + lit.getLanguage();
			else if (lit.getDatatype() != null) 
				return o + "^^<" + lit.getDatatype() + ">";
			return o;
		}
		else return "'" + escapeString(n.stringValue()) + "'";
	}

	
	private Value castValue(Object val) throws StoreException 
	{
		if (val == null) 
			return null;
		if (val instanceof ExtendedString) {
			ExtendedString ves = (ExtendedString) val;
			String valueString = ves.toString();
			if (ves.getIriType() == ExtendedString.IRI && (ves.getStrType() & 0x01)==0x01) {
				if (valueString.startsWith("_:")) {
					valueString = valueString.substring(2);
					return getValueFactory().createBNode(valueString);
				}
				try {
					if (valueString.indexOf(':') < 0) 
						return getValueFactory().createURI(":" + valueString);
					else 
						return getValueFactory().createURI(valueString);
				}
				catch (IllegalArgumentException iaex) {
					throw new StoreException("VirtuosoRepositoryConnection().castValue() Invalid value from Virtuoso: \"" + valueString + "\"", iaex);
				}
			}
			else if (ves.getIriType() == ExtendedString.BNODE) {
				try {
					valueString = valueString.substring(9); // "nodeID://"
					return getValueFactory().createBNode(valueString);
				}
				catch (IllegalArgumentException iaex) {
					throw new StoreException("VirtuosoRepositoryConnection().castValue() Invalid value from Virtuoso: \"" + valueString + "\"", iaex);
				}
			}
			else {
				try {
					return getValueFactory().createLiteral(valueString);
				}
				catch (IllegalArgumentException iaex) {
					throw new StoreException("VirtuosoRepositoryConnection().castValue() Invalid value from Virtuoso: \"" + valueString + "\", STRTYPE = " + ves.getIriType(), iaex);
				}
			}
		}
		else if (val instanceof RdfBox) {
			RdfBox rb = (RdfBox) val;
			if (rb.getLang() != null) {
				return getValueFactory().createLiteral(rb.toString(), rb.getLang());
			}
			else if (rb.getType() != null) {
				return getValueFactory().createLiteral(rb.toString(), getValueFactory().createURI(rb.getType()));
			}
			else {
				return getValueFactory().createLiteral(rb.toString());
			}
		}
		else if (val instanceof java.lang.Integer) {
			return getValueFactory().createLiteral(((Integer) val).intValue());
		}
		else if (val instanceof java.lang.Short) {
			return getValueFactory().createLiteral(((Short) val).intValue());
		}
		else if (val instanceof java.lang.Float) {
			return getValueFactory().createLiteral(((Float) val).floatValue());
		}
		else if (val instanceof java.lang.Double) {
			return getValueFactory().createLiteral(((Double) val).doubleValue());
		}
		else if (val instanceof java.math.BigDecimal) {
			URI type = getValueFactory().createURI("http://www.w3.org/2001/XMLSchema#decimal");
			return getValueFactory().createLiteral(val.toString(), type);
		}
		else if (val instanceof java.sql.Blob) {
			URI type = getValueFactory().createURI("http://www.w3.org/2001/XMLSchema#hexBinary");
			return getValueFactory().createLiteral(val.toString(), type);
		}
		else if (val instanceof java.sql.Date) {
			URI type = getValueFactory().createURI("http://www.w3.org/2001/XMLSchema#date");
			return getValueFactory().createLiteral(val.toString(), type);
		}
		else if (val instanceof java.sql.Timestamp) {
			URI type = getValueFactory().createURI("http://www.w3.org/2001/XMLSchema#dateTime");
			return getValueFactory().createLiteral(Timestamp2String((java.sql.Timestamp)val), type);
		}
		else if (val instanceof java.sql.Time) {
			URI type = getValueFactory().createURI("http://www.w3.org/2001/XMLSchema#time");
			return getValueFactory().createLiteral(val.toString(), type);
		}
		else { // if(val instanceof String) {
			try {
				return getValueFactory().createLiteral((String) val);
			}
			catch (IllegalArgumentException iaex2) {
				throw new StoreException("VirtuosoRepositoryConnection().castValue() Could not parse resource: " + val, iaex2);
			}
		}
	}


	private void verifyIsOpen() throws StoreException 
	{
		try {
			if (this.getQuadStoreConnection().isClosed()) 
				throw new StoreException("Connection has been closed");
		}
		catch (SQLException e) {
			throw new StoreException(e);
		}
	}


        public class CursorBase<E> implements Cursor<E> 
	{
		E	  v_row;
		boolean	  v_finished = false;
		boolean	  v_prefetched = false;
		Resource  subject;
		URI       predicate;
		Value 	  object;
		ResultSet v_rs;

        	public CursorBase(ResultSet rs, Resource subject, URI predicate, Value object)
        	{
        	  v_rs = rs;
        	  this.subject = subject;
        	  this.predicate = predicate;
        	  this.object = object;	
        	}


		public E next() throws StoreException 
		{
		        if (!v_finished && !v_prefetched)
			    moveForward();

		        v_prefetched = false;

		        if (v_finished)
		            return null;

		        return v_row;
		}

		public void close() throws StoreException
		{
			if (!v_finished)
			{
				try
				{
				    v_rs.close();
				}
				catch (SQLException e)
				{
				    throw new StoreException(e);
				}
			}
			v_finished = true;
		}

		protected void finalize() throws Throwable
		{
			if (!v_finished) 
				try {
				    close();
				} catch (Exception e) {}
		}

		protected void moveForward() throws StoreException
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
			    throw new StoreException(e);
			}
		}

		protected void extractRow() throws Exception 
		{
		}
	}


        public class CursorStmt extends CursorBase<Statement> 
	{
                                           
                int col_g = -1;
                int col_s = -1;
                int col_p = -1;
                int col_o = -1;

        	public CursorStmt(ResultSet rs, Resource subject, URI predicate, Value object) throws StoreException
        	{
        	  super(rs, subject, predicate, object);
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
		     throw new StoreException(e);
		  }
        	}

		protected void extractRow() throws Exception 
		{
			Resource _graph = null;
			Resource _subject = subject;
			URI _predicate = predicate;
			Value _object = object;
			Object val = null;

			try {
			        if (col_g != -1) {
				  val = v_rs.getObject(col_g);
				  _graph = (Resource) castValue(val);
				}
			}
			catch (ClassCastException ccex) {
				throw new StoreException("Unexpected resource type encountered. Was expecting Resource: " + val, ccex);
			}

			if (_subject == null && col_s != -1) 
			  try {
				val = v_rs.getObject(col_s);
				_subject = (Resource) castValue(val);
			  }
			  catch (ClassCastException ccex) {
				throw new StoreException("Unexpected resource type encountered. Was expecting Resource: " + val, ccex);
			  }

			if (_predicate == null && col_p != -1) 
			  try {
				val = v_rs.getObject(col_p);
				_predicate = (URI) castValue(val);
			  }
			  catch (ClassCastException ccex) {
				throw new StoreException("Unexpected resource type encountered. Was expecting URI: " + val, ccex);
			  }

			if (_object == null && col_o != -1) 
			  _object = castValue(v_rs.getObject(col_o));

			v_row = new StatementImpl(_subject,_predicate,_object,_graph);
		}
	}

        

        public class CursorBindingSet extends CursorBase<BindingSet> 
	{
 		ResultSetMetaData rsmd;

        	public CursorBindingSet(ResultSet rs) throws StoreException
        	{
        	  super(rs, null, null, null);
        	  try {
 		  	rsmd = rs.getMetaData();
		  } catch (Exception e) {
		     throw new StoreException(e);
		  }
        	}

		protected void extractRow() throws Exception 
		{
			v_row = new QueryBindingSet();
			for (int i = 1; i <= rsmd.getColumnCount(); i++) {
				String col = rsmd.getColumnName(i);
				Object val = v_rs.getObject(i);
				Value v = castValue(val);
				((QueryBindingSet)v_row).setBinding(col, v);
			}
		}
	}


        public class CursorGraphResult extends CursorBase<Statement> 
	{
                int col_g = -1;
                int col_s = -1;
                int col_p = -1;
                int col_o = -1;

        	public CursorGraphResult(ResultSet rs) throws StoreException
        	{
        	  super(rs, null, null, null);

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
		     throw new StoreException(e);
		  }
        	}

		protected void extractRow() throws Exception 
		{
			Resource sval = null;
			URI pval = null;
			Value oval = null;
			Resource gval = null;

			if (col_s != -1)
				sval = (Resource) castValue(v_rs.getObject(col_s));
				
			if (col_p != -1)
				pval = (URI) castValue(v_rs.getObject(col_p));
				
			if (col_o != -1)
				oval = castValue(v_rs.getObject(col_o));
				
			if (col_g != -1)
				gval = (Resource) castValue(v_rs.getObject(col_g));

			v_row = new StatementImpl(sval,pval,oval,gval);
		}
	}


    	private String Timestamp2String(java.sql.Timestamp v)
    	{
      		GregorianCalendar cal = new GregorianCalendar();
      		cal.setTime(v);

      		int year = cal.get(Calendar.YEAR);
      		int month = cal.get(Calendar.MONTH) + 1;
      		int day = cal.get(Calendar.DAY_OF_MONTH);
      		int hour = cal.get(Calendar.HOUR_OF_DAY);
      		int minute = cal.get(Calendar.MINUTE);
      		int second = cal.get(Calendar.SECOND);
      		int nanos = v.getNanos();

      		String yearS;
      		String monthS;
      		String dayS;
      		String hourS;
      		String minuteS;
      		String secondS;
      		String nanosS;
      		String zeros = "000000000";
      		String yearZeros = "0000";
      		StringBuffer timestampBuf;

      		if (year < 1000) {
          		yearS = "" + year;
          		yearS = yearZeros.substring(0, (4-yearS.length())) + yearS;
      		} else {
          		yearS = "" + year;
      		}

      		if (month < 10)
          		monthS = "0" + month;
      		else
          		monthS = Integer.toString(month);

      		if (day < 10)
          		dayS = "0" + day;
      		else
          		dayS = Integer.toString(day);

      		if (hour < 10)
          		hourS = "0" + hour;
      		else
          		hourS = Integer.toString(hour);

      		if (minute < 10)
          		minuteS = "0" + minute;
      		else
          		minuteS = Integer.toString(minute);
      
      		if (second < 10)
          		secondS = "0" + second;
      		else
          		secondS = Integer.toString(second);
      
      		if (nanos == 0) {
          		nanosS = "0";
      		} else {
          		nanosS = Integer.toString(nanos);

          		// Add leading 0
          		nanosS = zeros.substring(0, (9-nanosS.length())) + nanosS; 

          		// Truncate trailing 0
          		char[] nanosChar = new char[nanosS.length()];
          		nanosS.getChars(0, nanosS.length(), nanosChar, 0);
          		int truncIndex = 8;
          		while (nanosChar[truncIndex] == '0') {
      	    			truncIndex--;
          		}
          		nanosS = new String(nanosChar, 0, truncIndex + 1);
      		}

      		timestampBuf = new StringBuffer();
      		timestampBuf.append(yearS);
      		timestampBuf.append("-");
      		timestampBuf.append(monthS);
      		timestampBuf.append("-");
      		timestampBuf.append(dayS);
      		timestampBuf.append("T");
      		timestampBuf.append(hourS);
      		timestampBuf.append(":");
      		timestampBuf.append(minuteS);
      		timestampBuf.append(":");
      		timestampBuf.append(secondS);
      		timestampBuf.append(".");
      		timestampBuf.append(nanosS);

      		return (timestampBuf.toString());
    	}
}

