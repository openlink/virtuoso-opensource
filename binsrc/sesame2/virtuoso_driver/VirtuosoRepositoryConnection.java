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
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Vector;
import java.util.StringTokenizer;

import org.openrdf.model.BNode;
import org.openrdf.model.Graph;
import org.openrdf.model.Literal;
import org.openrdf.model.Namespace;
import org.openrdf.model.Resource;
import org.openrdf.model.Statement;
import org.openrdf.model.URI;
import org.openrdf.model.Value;
import org.openrdf.model.impl.GraphImpl;
import org.openrdf.model.impl.NamespaceImpl;
import org.openrdf.model.impl.ValueFactoryImpl;
import org.openrdf.query.BindingSet;
import org.openrdf.query.BooleanQuery;
import org.openrdf.query.GraphQuery;
import org.openrdf.query.MalformedQueryException;
import org.openrdf.query.Query;
import org.openrdf.query.QueryEvaluationException;
import org.openrdf.query.QueryLanguage;
import org.openrdf.query.TupleQuery;
import org.openrdf.query.TupleQueryResult;
import org.openrdf.query.TupleQueryResultHandler;
import org.openrdf.query.TupleQueryResultHandlerException;
import org.openrdf.query.algebra.evaluation.QueryBindingSet;
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

public class VirtuosoRepositoryConnection implements RepositoryConnection {
        private Resource  nilContext = new ValueFactoryImpl().createURI("urn:nil");
	private Connection quadStoreConnection;
	protected VirtuosoRepository repository;

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
	 * Checks whether this connection is open. A connection is open from the
	 * moment it is created until it is closed.
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


	public void close() throws RepositoryException {
		try {
			if (!getQuadStoreConnection().isClosed())
				getQuadStoreConnection().close();
		}
		catch (SQLException e) {
			throw new RepositoryException(e.toString());
		}
	}


	public Query prepareQuery(QueryLanguage language, String query) throws RepositoryException, MalformedQueryException {
		return prepareQuery(language, query, null);
	}

	public Query prepareQuery(QueryLanguage language, String query, String baseURI) throws RepositoryException, MalformedQueryException {
		Query q = new VirtuosoQuery();
		return q;
	}

	public TupleQuery prepareTupleQuery(QueryLanguage language, String query) throws RepositoryException, MalformedQueryException {
		return prepareTupleQuery(language, query, null);
	}

	public TupleQuery prepareTupleQuery(QueryLanguage langauge, final String query, String baseeURI) throws RepositoryException, MalformedQueryException {
		TupleQuery q = new VirtuosoTupleQuery() {
			public TupleQueryResult evaluate() throws QueryEvaluationException {
				return executeSPARQLForQueryResult(query);
			}
			
			public void evaluate(TupleQueryResultHandler handler) throws QueryEvaluationException, TupleQueryResultHandlerException {
				executeSPARQLForHandler(handler, query);
			}
		};
		return q;
	}

	public GraphQuery prepareGraphQuery(QueryLanguage language, String query) throws RepositoryException, MalformedQueryException {
		return prepareGraphQuery(language, query, null);
	}

	public GraphQuery prepareGraphQuery(QueryLanguage language, final String query, String baseURI) throws RepositoryException, MalformedQueryException {
		GraphQuery q = new VirtuosoGraphQuery();
		return q;
	}

	public BooleanQuery prepareBooleanQuery(QueryLanguage language, String query) throws RepositoryException, MalformedQueryException {
		return prepareBooleanQuery(language, query, null);
	}

	public BooleanQuery prepareBooleanQuery(QueryLanguage language, String query, String baseURI) throws RepositoryException, MalformedQueryException {
		BooleanQuery q = new VirtuosoBooleanQuery();
		return q;
	}

	public RepositoryResult<Resource> getContextIDs() throws RepositoryException {
		// this function performs SLOWLY, use with caution
		
		verifyIsOpen();
		Vector v = new Vector();
		String query = "DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS()";
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet rs = (VirtuosoResultSet) stmt.executeQuery(query);

			// begin at onset one
			while(rs.next()) {
				Object obj = rs.getObject(1);
				try {
					Value graphId = castValue(obj);
					// add that graph to the results
					v.add(graphId);
				} catch(IllegalArgumentException iiaex) {
					throw new RepositoryException("VirtuosoRepositoryConnection.getContextIDs() Non-URI context encountered: " + obj);
				}
			}
		}
		catch (Exception e) {
			throw new RepositoryException(": SPARQL execute failed." + "\n" + query.toString(), e);
		}
		return createRepositoryResult(v);
	}	

	public RepositoryResult<Statement> getStatements(Resource subject, URI predicate, Value object, boolean includeInferred, Resource... contexts) throws RepositoryException {
		Graph g = selectFromQuadStore(subject, predicate, object, includeInferred, contexts);
		return createRepositoryResult(g);
	}

	public boolean hasStatement(Resource subject, URI predicate, Value object, boolean includeInferred, Resource... contexts) throws RepositoryException {
		Graph g = selectFromQuadStore(subject, predicate, object, includeInferred, contexts);
		return g.iterator().hasNext();
	}

	public boolean hasStatement(Statement statement, boolean includeInferred, Resource... contexts) throws RepositoryException {
		if(contexts != null && contexts.length == 0) {
			if(statement.getContext() != null) {
				contexts = new Resource[] {statement.getContext()}; // try the context given by the statement
			}
			else {
				contexts = new Resource[] {nilContext};
			}
		}
		Graph g = selectFromQuadStore(statement.getSubject(), statement.getPredicate(), statement.getObject(), includeInferred, contexts);
		return g.iterator().hasNext();
	}

	public void exportStatements(Resource subject, URI predicate, Value object, boolean includeInferred, RDFHandler handler, Resource... contexts) throws RepositoryException, RDFHandlerException {
		Graph g = selectFromQuadStore(subject, predicate, object, includeInferred, contexts);
		handler.startRDF();
		Iterator<Statement> it = g.iterator();
		while(it.hasNext()) handler.handleStatement(it.next());
		handler.endRDF();
	}

	public void export(RDFHandler handler, Resource... contexts) throws RepositoryException, RDFHandlerException {
		exportStatements(null, null, null, false, handler, contexts);
	}

	public long size(Resource... contexts) throws RepositoryException {
		int ret = 0;

		verifyIsOpen();
		if(contexts == null || contexts.length == 0)
			contexts = new Resource[] {nilContext};

		for(int i = 0; i < contexts.length; i++) {
			StringBuffer query = new StringBuffer("select count (*) from (sparql select * from <");
			if(contexts[i] != null)
				query.append(contexts[i].stringValue());
			else
				query.append(nilContext.stringValue());

			query.append(">  where {?s ?p ?o})f");

			ResultSet rs = null;

			try {
				java.sql.Statement stmt = getQuadStoreConnection().createStatement();
				rs = stmt.executeQuery(query.toString());
				rs.next();
				ret += rs.getInt(1);
			}
			catch (Exception e) {
				throw new RepositoryException(e);
			}
		}
		return ret;
	}

	public boolean isEmpty() throws RepositoryException {
		verifyIsOpen();
		String query = "sparql select * where {?s ?o ?p} limit 1";
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet result_set = (VirtuosoResultSet) stmt.executeQuery(query);
			return result_set.next();
		}
		catch (Exception e) {
			throw new RepositoryException("Problem executing query: " + query, e);
		}
	}

	public void setAutoCommit(boolean autoCommit) throws RepositoryException {
		verifyIsOpen();
		try {
			getQuadStoreConnection().setAutoCommit(autoCommit);
		}
		catch (SQLException e) {
			throw new RepositoryException(e.toString());
		}
	}

	public boolean isAutoCommit() throws RepositoryException {
		verifyIsOpen();
		try {
			return getQuadStoreConnection().getAutoCommit();
		}
		catch (SQLException e) {
			throw new RepositoryException(e.toString());
		}
	}

	public void commit() throws RepositoryException {
		verifyIsOpen();
		try {
			getQuadStoreConnection().commit();
		}
		catch (SQLException e) {
			throw new RepositoryException(e.toString());
		}
	}

	public void rollback() throws RepositoryException {
		verifyIsOpen();
		try {
			this.getQuadStoreConnection().rollback();
		}
		catch (SQLException e) {
			throw new RepositoryException("Problem with rollback", e);
		}
	}

	public void add(InputStream dataStream, String baseURI, RDFFormat format, Resource... contexts) throws IOException, RDFParseException, RepositoryException {
		Reader reader = new InputStreamReader(dataStream);
		add(reader, baseURI, format, contexts);
	}

	public void add(Reader reader, String baseURI, RDFFormat format, final Resource... contexts) throws IOException, RDFParseException, RepositoryException {
		try {
			RDFParser parser = null;
			if(format.equals(RDFFormat.NTRIPLES)) {
				parser = new NTriplesParserFactory().getParser();
			}
			else if(format.equals(RDFFormat.N3)) {
				parser = new N3ParserFactory().getParser();
			}
			else if(format.equals(RDFFormat.RDFXML)) {
				parser = new RDFXMLParserFactory().getParser();
			}
			else if(format.equals(RDFFormat.TURTLE)) {
				parser = new TurtleParserFactory().getParser();
			}
			else if(format.equals(RDFFormat.TRIG)) {
				parser = new TriGParserFactory().getParser();
			}
			else if(format.equals(RDFFormat.TRIX)) {
				parser = new TriXParserFactory().getParser();
			}
			
			// set up a handler for parsing the data from reader
			parser.setDatatypeHandling(RDFParser.DatatypeHandling.IGNORE);
			parser.setRDFHandler(new RDFHandlerBase() {
				public void handleStatement(Statement st) {
					try {
						add(st, contexts); // send the parsed triple to the quad store
					}
					catch (RepositoryException e) {
						e.printStackTrace();
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

	public void add(URL dataURL, String baseURI, RDFFormat format, Resource... contexts) throws IOException, RDFParseException, RepositoryException {
		// add data to Sesame
		Reader reader = new InputStreamReader(dataURL.openStream());
		add(reader, baseURI, format, contexts);
	}

	public void add(File file, String baseURI, RDFFormat format, Resource... contexts) throws IOException, RDFParseException, RepositoryException {
		InputStream reader = new FileInputStream(file);
		add(reader, baseURI, format, contexts);
	}

	public void add(Resource subject, URI predicate, Value object, Resource... contexts) throws RepositoryException {
		addToQuadStore(subject, predicate, object, contexts);
	}

	public void add(Statement statement, Resource... contexts) throws RepositoryException {
		if(contexts != null && contexts.length == 0) {
			if(statement.getContext() != null) {
				contexts = new Resource[] {statement.getContext()}; // try the context given by the statement
			}
			else {
				contexts = new Resource[] {nilContext};
			}
		}
		add(statement.getSubject(), statement.getPredicate(), statement.getObject(), contexts);
	}

	public void add(Iterable<? extends Statement> statements, Resource... contexts) throws RepositoryException {
		Iterator it = statements.iterator();
		while(it.hasNext()) {
			Statement st = (Statement) it.next();
			add(st, contexts);
		}
	}

	public <E extends Exception> void add(Iteration<? extends Statement, E> statements, Resource... contexts) throws RepositoryException, E {
		while(statements.hasNext()) {
			Statement st = (Statement) statements.next();
			add(st, contexts);
		}
	}

	public void remove(Resource subject, URI predicate, Value object, Resource... contexts) throws RepositoryException {
		verifyIsOpen();
		String s = "?s";
		String p = "?p";
		String o = "?o";
		
		if (subject != null) 
		   s = Resource2Str(subject);

		if (predicate != null) 
		   p = URI2Str(predicate);

		if(object != null) 
		   o = Value2Str(object);

		if(contexts == null || contexts.length == 0) 
			contexts = new Resource[] {nilContext};

		for(int i = 0; i < contexts.length; i++) {
		        StringBuffer query = new StringBuffer("sparql delete from graph <");
			if(contexts[i] != null)
				query.append(contexts[i].stringValue());
			else
				query.append(nilContext.stringValue());
			query.append("> { ");

//			s = s.replaceAll("'", "''");
//			p = p.replaceAll("'", "''");
//			o = o.replaceAll("'", "''");
			query.append(s);
			query.append(" ");
			query.append(p);
			query.append(" ");
			query.append(o);
			query.append(" }");

			try {
				java.sql.Statement stmt = getQuadStoreConnection().createStatement();
				stmt.execute(query.toString());
			} catch (Exception e) {
				throw new RepositoryException(e.toString());
			}
		}
	}

	public void remove(Statement statement, Resource... contexts) throws RepositoryException {
		if(contexts != null && contexts.length == 0) {
			if(statement.getContext() != null) {
				contexts = new Resource[] {statement.getContext()}; // try the context given by the statement
			}
			else {
				contexts = new Resource[] {nilContext};
			}
		}
		remove(statement.getSubject(), statement.getPredicate(), statement.getObject(), contexts);
	}

	public void remove(Iterable<? extends Statement> statements, Resource... contexts) throws RepositoryException {
		Iterator<? extends Statement> it = statements.iterator();
		while(it.hasNext()) {
			Statement st = it.next();
			remove(st, contexts);
		}
	}

	public <E extends Exception> void remove(Iteration<? extends Statement, E> statements, Resource... contexts) throws RepositoryException, E {
		while(statements.hasNext()) {
			Statement st = statements.next();
			remove(st, contexts);
		}
	}


	public void clear(Resource... contexts) throws RepositoryException {
		clearQuadStore(contexts);
	}

	public RepositoryResult<Namespace> getNamespaces() throws RepositoryException {
		verifyIsOpen();
		List<Namespace> namespaceList = new ArrayList<Namespace>();
		StringBuffer query = new StringBuffer();
		query.append("DB.DBA.XML_SELECT_ALL_NS_DECLS (3)");
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet rs = (VirtuosoResultSet) stmt.executeQuery(query.toString());

			// begin at onset one
			while (rs.next()) {
				String prefix = rs.getString(1);
				String name = rs.getString(2);
				if(name != null && prefix != null) {
					Namespace ns =  new NamespaceImpl(prefix, name);
					namespaceList.add(ns);
				}
			}
		}
		catch (Exception e) {
			throw new RepositoryException(e.toString());
		}
		return  createRepositoryResult(namespaceList);// new RepositoryResult<Namespace>(new IteratorWrapper(v.iterator()));
	}

	public String getNamespace(String prefix) throws RepositoryException {
		verifyIsOpen();
		StringBuffer query = new StringBuffer();
		query.append("SELECT __xml_get_ns_uri ('");
		query.append(prefix);
		query.append("', 3)");
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet rs = (VirtuosoResultSet) stmt.executeQuery(query.toString());

			// begin at onset one
			while(rs.next()) {
				return rs.getString(1);
			}
		}
		catch (Exception e) {
			throw new RepositoryException(e.toString());
		}
		return null;
	}
	
	
	public void setNamespace(String prefix, String name) throws RepositoryException {
		verifyIsOpen();
		String query = "DB.DBA.XML_SET_NS_DECL('" + prefix + "','" + name + "', 1)";
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			stmt.execute(query);
		}
		catch (SQLException e) {
			throw new RepositoryException("Problem executing query: " + query, e);
		}
	}

	public void removeNamespace(String prefix) throws RepositoryException {
		verifyIsOpen();
		String query = "DB.DBA.XML_REMOVE_NS_BY_PREFIX('" + prefix + "', 1)";
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			stmt.execute(query);
		}
		catch (SQLException e) {
			throw new RepositoryException("Problem executing query: " + query, e);
		}
	}

	public void clearNamespaces() throws RepositoryException {
		verifyIsOpen();
		String query = "DB.DBA.XML_CLEAR_ALL_NS_DECLS()";
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			stmt.execute(query.toString());
		}
		catch (SQLException e) {
			throw new RepositoryException("Problem executing query: " + query, e);
		}
	}


	public TupleQueryResult executeSPARQLForQueryResult(String query) {

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
			while(rs.next()) {
				QueryBindingSet qbs = new QueryBindingSet();
				for (int i = 1; i <= rsmd.getColumnCount(); i++) {
					String col = rsmd.getColumnName(i);
					Object val = rs.getObject(i);
					Value v = castValue(val);
					qbs.setBinding(col, v);
				}
				bindings.add(qbs);
			}
		}
		catch (Exception e) {
		        throw new RuntimeException(e.toString());
		}
		TupleQueryResult tqr = new TupleQueryResultImpl(names, bindings.iterator());
		return tqr;
	}


	public void executeSPARQLForHandler(TupleQueryResultHandler tqrh, String query) {
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet rs = (VirtuosoResultSet) stmt.executeQuery(fixQuery(query));

			ResultSetMetaData rsmd = rs.getMetaData();
			
			// begin at onset one
			while(rs.next()) {
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
		}
		catch (Exception e) {
			throw new RuntimeException(e.toString());
		}
	}

	public int executeSPARUL(String query) {

		try {
			verifyIsOpen();
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			stmt.execute("sparql\n "+query);
			return stmt.getUpdateCount();
		}
		catch (Exception e) {
		        throw new RuntimeException(e.toString());
		}
	}


	public Connection getQuadStoreConnection() {
		return quadStoreConnection;
	}

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

	
	private void addToQuadStore(Statement st, Resource ... contexts) throws RepositoryException {
		if(contexts != null && contexts.length == 0) {
			if(st.getContext() != null) {
				contexts = new Resource[] {st.getContext()}; // try the context given by the statement
			}
			else {
				contexts = new Resource[] {nilContext};
			}
		}
		addToQuadStore(st.getSubject(), st.getPredicate(), st.getObject(), contexts);
	}
	

	private void addToQuadStore(Resource subject, URI predicate, Value object, Resource ... contexts) throws RepositoryException {
		verifyIsOpen();
		if(contexts == null || contexts.length == 0)
			contexts = new Resource[] {nilContext};
		
		String s = "";
		String p = "";
		String o = "";

		if (subject != null) 
		   s = Resource2Str(subject);

		if (predicate != null) 
		   p = URI2Str(predicate);

		if(object != null) 
		   o = Value2Str(object);


		for(int i = 0; i < contexts.length; i++) {
		        StringBuffer query = new StringBuffer("sparql insert into graph <");
			if(contexts[i] != null)
				query.append(contexts[i].stringValue());
			else
				query.append(nilContext.stringValue());
			query.append("> { ");

//			s = s.replaceAll("'", "''");
//			p = p.replaceAll("'", "''");
//			o = o.replaceAll("'", "''");
			query.append(s);
			query.append(" ");
			query.append(p);
			query.append(" ");
			query.append(o);
			query.append(" }");

			try {
				java.sql.Statement stmt = getQuadStoreConnection().createStatement();
				stmt.execute(query.toString());
			} catch (Exception e) {
				throw new RuntimeException(e.toString());
			}
		}
	}

	private void addToQuadStore(URL dataURL, Resource ... contexts) throws RepositoryException {
		verifyIsOpen();
		if(contexts == null || contexts.length == 0)
			contexts = new Resource[] {nilContext};
		
		for(int i = 0; i < contexts.length; i++) {
		        StringBuffer query = new StringBuffer("sparql load \"");
		        query.append(dataURL);
			query.append("\" into graph <");

			if(contexts[i] != null)
				query.append(contexts[i].stringValue());
			else
				query.append(nilContext.stringValue());

			query.append(">");

			try {
				java.sql.Statement stmt = getQuadStoreConnection().createStatement();
				stmt.execute(query.toString());
			} catch (Exception e) {
				throw new RepositoryException(e.toString());
			}
		}
	}
		
	private void clearQuadStore(Resource ... contexts) throws RepositoryException {
		verifyIsOpen();
		if(contexts == null || contexts.length == 0)
			contexts = new Resource[] {nilContext};

		for (int i = 0; i < contexts.length; i++) {
		        StringBuffer query = new StringBuffer("sparql clear graph <");
			if(contexts[i] != null)
				query.append(contexts[i].stringValue());
			else
				query.append(nilContext.stringValue());

			query.append(">");


			try {
				java.sql.Statement stmt = quadStoreConnection.createStatement();
				stmt.execute(query.toString());
			} catch (Exception e) {
				throw new RepositoryException(e.toString());
			}
		}
	}
	
	private Graph selectFromQuadStore(Resource ... contexts) throws RepositoryException {
		return selectFromQuadStore(null, null, null, false, contexts);
	}
	
	private Graph selectFromQuadStore(Resource subject, URI predicate, Value object, boolean includeInferred, Resource ... contexts) throws RepositoryException {
		verifyIsOpen();
		if(contexts == null || contexts.length == 0)
			contexts = new Resource[] {nilContext};
		
		Graph g = new GraphImpl();
		String S = "?s";
		String P = "?p";
		String O = "?o";

		if (subject != null)
		  S = Resource2Str(subject);
		if (predicate != null)
		  P = URI2Str(predicate);
		if (object != null)
		  O = Value2Str(object);

		for (int i = 0; i < contexts.length; i++) {
		  
		  StringBuffer query = new StringBuffer("sparql select * from <");
		  Resource context = contexts[i];

		  if (context == null)
			context = nilContext;

		  query.append(context.stringValue());
		  query.append("> where { ");
		  query.append(S);
		  query.append(" ");
		  query.append(P);
		  query.append(" ");
		  query.append(O);
		  query.append(" }");

		  try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet rs = (VirtuosoResultSet) stmt.executeQuery(query.toString());

			// begin at onset one
			while(rs.next()) {
				Resource _subject = subject;
				URI _predicate = predicate;
				Value _object = object;
				Object val = null;

				if (_subject == null)
				   try {
				     val = rs.getObject("s");
				     _subject = (Resource) castValue(val);
				   }
				   catch(ClassCastException ccex) {
					throw new RepositoryException("Unexpected resource type encountered. Was expecting Resource: " + val);
				   }

				if (_predicate == null)
				   try {
				     val = rs.getObject("p");
				     _predicate = (URI) castValue(val);
				   }
				   catch(ClassCastException ccex) {
					throw new RepositoryException("Unexpected resource type encountered. Was expecting URI: " + val);
				   }
				
				if (_object == null)
				     _object = castValue(rs.getObject("o"));

				g.add(_subject, _predicate, _object, context);
			}
		  }
		  catch (Exception e) {
                        throw new RepositoryException(getClass().getCanonicalName() + ": SPARQL execute failed." + "\n" + query.toString()+"["+e+"]");
		  }
		}
		return g;
	}
	
	
        private String Resource2Str(Resource n) {
           if (n instanceof URI)
             return "<"+n.stringValue()+">";
           else if (n instanceof BNode)
             return "<_:"+n.stringValue()+">";
           else 
             return "<"+n.stringValue()+">";
        }

        private String URI2Str(URI n) {
             return "<"+n.stringValue()+">";
        }

        private String Value2Str(Value n) {
           if (n instanceof BNode)
             return "<_:"+n.stringValue()+">";
           else if (n instanceof URI)
             return "<"+n.stringValue()+">";
           else if (n instanceof Literal)
             {
	       Literal lit = (Literal) n;
	       String o = "\"" + lit.stringValue() + "\"";
	       if (lit.getLanguage() != null)
                 o = "@" + lit.getLanguage();
               else if (lit.getDatatype() != null)
                 o = "^^" + "<" + lit.getDatatype() + ">";
               return o;
             }
           else
             return "\""+n.stringValue()+"\"";
        }

	
	private Value castValue(Object val) throws RepositoryException {
	    if (val == null) 
	      return null;
	    if (val instanceof VirtuosoRdfBox) {
		VirtuosoRdfBox rb = (VirtuosoRdfBox) val;
		if (rb.getLang() != null) {
		   return getRepository().getValueFactory().createLiteral(rb.rb_box.toString(), rb.getLang());
		}
		else if(rb.getType() != null) {
		   return getRepository().getValueFactory().createLiteral(rb.rb_box.toString(), this.getRepository().getValueFactory().createURI(rb.getType()));
		}
		else {
		   return getRepository().getValueFactory().createLiteral(rb.rb_box.toString());
		}
	    }
	    else if (val instanceof java.lang.Integer) {
		 return getRepository().getValueFactory().createLiteral(((Integer)val).intValue());
	    }
	    else if (val instanceof java.lang.Short) {
		 return getRepository().getValueFactory().createLiteral(((Short)val).intValue());
	    }
	    else if (val instanceof java.lang.Float) {
		 return getRepository().getValueFactory().createLiteral(((Float)val).floatValue());
	    }
	    else if (val instanceof java.lang.Double) {
		 return getRepository().getValueFactory().createLiteral(((Double)val).doubleValue());
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
	    else if(val instanceof VirtuosoExtendedString) {
		VirtuosoExtendedString ves = (VirtuosoExtendedString) val;
		String valueString = ves.str;
		if (ves.iriType == VirtuosoExtendedString.IRI) {
			if (valueString.startsWith("_:")) {
		    		valueString = valueString.substring(2);
				return getRepository().getValueFactory().createBNode(valueString);
		    	}
			try {
			        if (valueString.indexOf(':') < 0)
				  return getRepository().getValueFactory().createURI(":"+valueString);
				else
				  return getRepository().getValueFactory().createURI(valueString);
			}
			catch(IllegalArgumentException iaex) {
			        throw new RepositoryException("VirtuosoRepositoryConnection().castValue() Invalid value from Virtuoso: \"" + valueString + "\"");
			}
		}
		else if (ves.iriType == VirtuosoExtendedString.BNODE) {
			try {
				valueString = valueString.substring(9); // "nodeID://"
				return getRepository().getValueFactory().createBNode(valueString);
			}
			catch(IllegalArgumentException iaex) {
				throw new RepositoryException("VirtuosoRepositoryConnection().castValue() Invalid value from Virtuoso: \"" + valueString + "\"");
			}
		}
		else {
			try {
				return getRepository().getValueFactory().createLiteral(valueString);
			}
			catch(IllegalArgumentException iaex) {
				throw new RepositoryException("VirtuosoRepositoryConnection().castValue() Invalid value from Virtuoso: \"" + valueString + "\", STRTYPE = " + ves.iriType);
			}
		}
	    }
	    else { //if(val instanceof String) {
		try {
			return getRepository().getValueFactory().createLiteral((String)val);
		}
		catch(IllegalArgumentException iaex2) {
			throw new RepositoryException("VirtuosoRepositoryConnection().castValue() Could not parse resource: " + val);
		}
	    }
	}
	
	/**
	 * Creates a RepositoryResult for the supplied element set.
	 */
	protected <E> RepositoryResult<E> createRepositoryResult(Iterable<? extends E> elements) {
		return new RepositoryResult<E>(new CloseableIteratorIteration<E, RepositoryException>(
				elements.iterator()));
	}

	private void verifyIsOpen() throws RepositoryException {
		try {
			if (this.getQuadStoreConnection().isClosed())
				throw new IllegalStateException("Connection has been closed");
		} catch (SQLException e) {
		   throw new RepositoryException(e);
		}
	}

}
