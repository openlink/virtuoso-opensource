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
    
    
	public void add(Statement statement, Resource... contexts) throws RepositoryException {
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

	public void add(InputStream dataStream, String baseURI, RDFFormat format, Resource... contexts) throws IOException, RDFParseException, RepositoryException {
		Reader reader = new InputStreamReader(dataStream);
		add(reader, baseURI, format, contexts);
	}

	public void add(Reader reader, String baseURI, RDFFormat format, Resource... contexts) throws IOException, RDFParseException, RepositoryException {
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
						add(st); // send the parsed triple to the quad store
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

	public void clear(Resource... contexts) throws RepositoryException {
		clearQuadStore(contexts);
	}

	public void clearNamespaces() throws RepositoryException {
		String query = "DB.DBA.XML_CLEAR_ALL_NS_DECLS()";
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			stmt.execute(query.toString());
		}
		catch (SQLException e) {
			throw new RepositoryException("Problem executing query: " + query, e);
		}
	}

	public void close() throws RepositoryException {
		// TODO check close() implementation
		try {
			getQuadStoreConnection().close();
		}
		catch (SQLException e) {
			throw new RepositoryException(e.toString());
		}
	}

	public void commit() throws RepositoryException {
		// TODO check commit() implementation
		try {
			getQuadStoreConnection().commit();
		}
		catch (SQLException e) {
			throw new RepositoryException(e.toString());
		}
	}

	public void export(RDFHandler handler, Resource... contexts) throws RepositoryException, RDFHandlerException {
		exportStatements(null, null, null, false, handler, contexts);
	}

	public void exportStatements(Resource subject, URI predicate, Value object, boolean includeInferred, RDFHandler handler, Resource... contexts) throws RepositoryException, RDFHandlerException {
		Graph g = selectFromQuadStore(subject, predicate, object, includeInferred, contexts);
		handler.startRDF();
		Iterator<Statement> it = g.iterator();
		while(it.hasNext()) handler.handleStatement(it.next());
		handler.endRDF();
	}

	public RepositoryResult<Resource> getContextIDs() throws RepositoryException {
		// this function performs SLOWLY, use with caution
		
		Vector v = new Vector();
		StringBuffer query = new StringBuffer();
		query.append("sparql select distinct ?g where {graph ?g {?s ?o ?p.}}");		
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet results = (VirtuosoResultSet) stmt.executeQuery(query.toString());

			ResultSetMetaData data = results.getMetaData();
			String[] col_names = new String[data.getColumnCount()];
			
			// begin at onset one
			while(results.next()) {
				for (int meta_count = 1; meta_count <= data.getColumnCount(); meta_count++) {
					String col = data.getColumnName(meta_count);
					Object obj = results.getObject(col);
					if(col.equals("g")) {
						// TODO need to be able to parse BNode value also
						try {
							Value graphId = castValue(obj);
							// add that graph to the results
							v.add(graphId);
						}
						catch(IllegalArgumentException iiaex) {
							throw new RepositoryException("VirtuosoRepositoryConnection.getContextIDs() Non-URI context encountered: " + obj);
//							System.out.println("VirtuosoRepositoryConnection.getContextIDs() Ignoring context: " + obj);
						}
					}
				}
			}
		}
		catch (Exception e) {
			throw new RepositoryException(": SPARQL execute failed." + "\n" + query.toString(), e);
		}
		return createRepositoryResult(v);
	}	

	public String getNamespace(String prefix) throws RepositoryException {
		// TODO verify that this query is correct
		// SELECT distinct RP_NAME, RP_ID from DB.DBA.RDF_PREFIX
		StringBuffer query = new StringBuffer();
		query.append("SELECT __xml_get_ns_uri ('");
		query.append(prefix);
		query.append("', 3)");
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet results = (VirtuosoResultSet) stmt.executeQuery(query.toString());

			ResultSetMetaData data = results.getMetaData();
// String[] col_names = new String[data.getColumnCount()];
			// begin at onset one
			while(results.next()) {
				return results.getString(data.getColumnName(1));
			}
		}
		catch (Exception e) {
			throw new RepositoryException(e.toString());
		}
		return null;
	}
	
	
	public RepositoryResult<Namespace> getNamespaces() throws RepositoryException {
		List<Namespace> namespaceList = new ArrayList<Namespace>();
		StringBuffer query = new StringBuffer();
		query.append("DB.DBA.XML_SELECT_ALL_NS_DECLS (3)");
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet results = (VirtuosoResultSet) stmt.executeQuery(query.toString());

			ResultSetMetaData data = results.getMetaData();
			// begin at onset one
			while (results.next()) {
				String name = null;
				String prefix = null;
				for (int meta_count = 1; meta_count <= data.getColumnCount(); meta_count++) {
					// TODO need to parse these into appropriate resource values
					String col = data.getColumnName(meta_count);
					if(col.equals("URI")) {
						name = results.getString(col);
					}
					else if(col.equals("PREFIX")) {
						prefix = results.getString(col);
					}
				}
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

	public Repository getRepository() {
		// TODO is this the repository connected to this connection?
		return repository;
	}

	public RepositoryResult<Statement> getStatements(Resource subject, URI predicate, Value object, boolean includeInferred, Resource... contexts) throws RepositoryException {
		Graph g = selectFromQuadStore(subject, predicate, object, includeInferred, contexts);
		return createRepositoryResult(g);
	}

	public boolean hasStatement(Statement statement, boolean includeInferred, Resource... contexts) throws RepositoryException {
		Graph g = selectFromQuadStore(statement.getSubject(), statement.getPredicate(), statement.getObject(), includeInferred, contexts);
		return g.iterator().hasNext();
	}

	public boolean hasStatement(Resource subject, URI predicate, Value object, boolean includeInferred, Resource... contexts) throws RepositoryException {
		Graph g = selectFromQuadStore(subject, predicate, object, includeInferred, contexts);
		return g.iterator().hasNext();
	}

	public boolean isAutoCommit() throws RepositoryException {
		try {
			return getQuadStoreConnection().getAutoCommit();
		}
		catch (SQLException e) {
			throw new RepositoryException(e.toString());
		}
//		return false;
	}

	public boolean isEmpty() throws RepositoryException {
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

	public boolean isOpen() throws RepositoryException {
		try {
			return !this.getQuadStoreConnection().isClosed();
		}
		catch (SQLException e) {
			throw new RepositoryException("Problem inspecting connection", e);
		}
	}

	public BooleanQuery prepareBooleanQuery(QueryLanguage language, String query) throws RepositoryException, MalformedQueryException {
		return prepareBooleanQuery(language, query, null);
	}

	public BooleanQuery prepareBooleanQuery(QueryLanguage language, String query, String baseURI) throws RepositoryException, MalformedQueryException {
		BooleanQuery q = new VirtuosoBooleanQuery();
		return q;
	}

	public GraphQuery prepareGraphQuery(QueryLanguage language, String query) throws RepositoryException, MalformedQueryException {
		return prepareGraphQuery(language, query, null);
	}

	public GraphQuery prepareGraphQuery(QueryLanguage language, final String query, String baseURI) throws RepositoryException, MalformedQueryException {
		GraphQuery q = new VirtuosoGraphQuery();
		return q;
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

	public void remove(Statement statement, Resource... contexts) throws RepositoryException {
		remove(statement.getSubject(), statement.getPredicate(), statement.getObject(), contexts);
	}

	public void remove(Iterable<? extends Statement> statements, Resource... contexts) throws RepositoryException {
		Iterator<? extends Statement> it = statements.iterator();
		while(it.hasNext()) {
			Statement statement = it.next();
			remove(statement.getSubject(), statement.getPredicate(), statement.getObject(), contexts);
		}
	}

	public <E extends Exception> void remove(Iteration<? extends Statement, E> statements, Resource... contexts) throws RepositoryException, E {
		while(statements.hasNext()) {
			Statement statement = statements.next();
			remove(statement.getSubject(), statement.getPredicate(), statement.getObject(), contexts);
		}
	}

	public void remove(Resource subject, URI predicate, Value object, Resource... contexts) throws RepositoryException {
//		String S, P, O;
//		StringBuffer query = new StringBuffer();
//
//		S = subject.toString();
//		P = predicate.toString();
//		O = object.toString();
//		
//		java.sql.Statement stmt;
//		try {
//			if (contexts == null || contexts.length == 0) {
//				query.append("jena_remove (" + "'?g', " + "'" + S + "', " + "'" + P + "', " + "'" + O + "')");
//// query.append("sparql ");
//// query.append("delete graph <");
//// query.append(context.stringValue());
//// query.append(">");
//				stmt = getQuadStoreConnection().createStatement();
//				stmt.executeUpdate(query.toString());
//			}
//			else {
//				for (int i = 0; i < contexts.length; i++) {
//					// TODO check this jena_remove procedure, looks fishy
//					// TODO insert the procedure before using it
//					query.append("jena_remove (" + "'" + contexts[i] + "', " + "'" + S + "', " + "'" + P + "', " + "'" + O + "')");
//					stmt = getQuadStoreConnection().createStatement();
//					stmt.executeUpdate(query.toString());
//				}
//			}
//		}
//		catch (SQLException e) {
//			throw new RepositoryException("Problem executing 'remove' query: " + query, e);
//		}
		String s = "";
		String p = "";
		String o = "";
		StringBuffer query = new StringBuffer();
		if(subject == null) s = "?s";
		else if(subject instanceof URI) s = "<" + ((URI)subject).stringValue() + ">";
		else if(subject instanceof BNode) s = "<_:" + ((BNode)subject).stringValue() + ">";
		else if(predicate == null) p = "?p";
		if(predicate instanceof URI) p = "<" + ((URI)predicate).stringValue() + ">";
		if(object == null) o = "?o";
		else if(object instanceof URI) o = "<" + ((URI)object).stringValue() + ">";
		else if(object instanceof BNode) o = "<_:" + ((BNode)object).stringValue() + ">";
		else if(object instanceof Literal) {
			Literal lit = (Literal) object;
			o = "\"" + lit.stringValue() + "\"";
			if(lit.getLanguage() != null) {
				o = "@" + lit.getLanguage();
			}
			else if(lit.getDatatype() != null) {
				o = "^^" + "<" + lit.getDatatype() + ">";
			}
		}

		if(contexts == null || contexts.length == 0) {
			contexts = new Resource[] {new ValueFactoryImpl().createURI("virt:DEFAULT")};
		}
		addTriplesToEachContext:
		for(int i = 0; i < contexts.length; i++) {
			String g = "from graph <virt:DEFAULT>";
			if(contexts[i] != null) {
				// TODO need to pass a wildcard for context
//				continue addTriplesToEachContext;
				if(contexts[i] instanceof URI) {
					g = "from graph <" + contexts[i].stringValue() + ">";
				}
			}
//			else if(contexts[i] instanceof URI) {
//				URI context = (URI)contexts[i];
				s = s.replaceAll("'", "''");
				p = p.replaceAll("'", "''");
				o = o.replaceAll("'", "''");
				query.append("sparql delete " + g + "{ ");
				query.append(s);
				query.append(" ");
				query.append(p);
				query.append(" ");
				query.append(o);
				query.append(" }");
				try {
					java.sql.Statement stmt = getQuadStoreConnection().createStatement();
					stmt.execute(query.toString());
				}
				catch (Exception e) {
					throw new RepositoryException(e.toString());
				}
//			}
		}
	}

	public void removeNamespace(String prefix) throws RepositoryException {
// String query = "delete from table DB.DBA.RDF_PREFIX WHERE RP_ID = '" + prefix + "'";
		String query = "DB.DBA.XML_REMOVE_NS_BY_PREFIX('" + prefix + "', 1)";
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			stmt.execute(query.toString());
		}
		catch (SQLException e) {
			throw new RepositoryException("Problem executing query: " + query, e);
		}
	}

	public void rollback() throws RepositoryException {
		try {
			this.getQuadStoreConnection().rollback();
		}
		catch (SQLException e) {
			throw new RepositoryException("Problem with rollback", e);
		}
	}

	public void setAutoCommit(boolean autoCommit) throws RepositoryException {
		try {
			getQuadStoreConnection().setAutoCommit(autoCommit);
		}
		catch (SQLException e) {
			throw new RepositoryException(e.toString());
		}
	}

	public void setNamespace(String prefix, String name) throws RepositoryException {
		String query = "DB.DBA.XML_SET_NS_DECL('" + prefix + "','" + name + "', 1)";
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			stmt.execute(query.toString());
		}
		catch (SQLException e) {
			throw new RepositoryException("Problem executing query: " + query, e);
		}
	}

	public long size(Resource... contexts) throws RepositoryException {
		int ret = 0;
		for(int i = 0; i < contexts.length; i++) {
			String exec_text = "select count (*) from (sparql select * from <"
				+ contexts[i] + ">  where {?s ?p ?o})f";
			ResultSet rs = null;

//			checkOpen();

			try {
				java.sql.Statement stmt = getQuadStoreConnection().createStatement();
				rs = stmt.executeQuery(exec_text);
				rs.next();
				ret += rs.getInt(1);
			}
			catch (Exception e) {
				throw new RepositoryException(e);
			}
		}
		return ret;
//		return new Integer(selectFromQuadStore(contexts).size()).longValue();
	}

	private void addToQuadStore(Statement st, Resource ... contexts) {
		if(contexts != null && contexts.length == 0) {
			if(st.getContext() != null) {
				contexts = new Resource[] {st.getContext()}; // try the context given by the statement
			}
			else {
			}
		}
		addToQuadStore(st.getSubject(), st.getPredicate(), st.getObject(), contexts);
	}
	
	private void addToQuadStore(Resource subject, URI predicate, Value object, Resource ... contexts) {
		if(contexts == null) {
			contexts = new Resource[] {new ValueFactoryImpl().createURI("virt:DEFAULT")}; // retrieve all statements under no context
		}
		else if(contexts.length == 0) {
			contexts = new Resource[] {new ValueFactoryImpl().createURI("virt:DEFAULT")}; // retrieve all statements under no context
		}
		
//		String S;
//		String P;
//		String O;
//		StringBuffer query = new StringBuffer();
//		S = subject.stringValue();
//		P = predicate.stringValue();
//		O = object.stringValue();
//		S = S.replaceAll("'", "''");
//		P = P.replaceAll("'", "''");
//		O = O.replaceAll("'", "''");
//
//		addTriplesToEachContext:
//		for(int i = 0; i < contexts.length; i++) {
//			if(contexts[i] == null) {
//				// TODO need to pass a wildcard for context
//				continue addTriplesToEachContext;
//			}
//			else if(contexts[i] instanceof URI) {
//				URI context = (URI)contexts[i];
//				query.append("DB.DBA.RDF_QUAD_URI ('");
//				query.append(context.stringValue());
//				query.append("', '");
//				query.append(S);
//				query.append("', '");
//				query.append(P);
//				query.append("', '");
//				query.append(O);
//				query.append("')");
//				try {
//					java.sql.Statement stmt = getQuadStoreConnection().createStatement();
//					stmt.executeUpdate(query.toString());
//				}
//				catch (Exception e) {
//					e.printStackTrace();
//				}
//			}
//		}
		
		

		String s = "";
		String p = "";
		String o = "";
		StringBuffer query = new StringBuffer();
		if(subject instanceof URI) s = "<" + ((URI)subject).stringValue() + ">";
		else if(subject instanceof BNode) s = "<_:" + ((BNode)subject).stringValue() + ">";
		if(predicate instanceof URI) p = "<" + ((URI)predicate).stringValue() + ">";
		if(object instanceof URI) o = "<" + ((URI)object).stringValue() + ">";
		else if(object instanceof BNode) o = "<_:" + ((BNode)object).stringValue() + ">";
		else if(object instanceof Literal) {
			Literal lit = (Literal) object;
			o = "\"" + lit.stringValue() + "\"";
			if(lit.getLanguage() != null) {
				o = "@" + lit.getLanguage();
			}
			else if(lit.getDatatype() != null) {
				o = "^^" + "<" + lit.getDatatype() + ">";
			}
		}

		addTriplesToEachContext:
		for(int i = 0; i < contexts.length; i++) {
			String g = "";
			if(contexts[i] != null) {
				// TODO need to pass a wildcard for context
				if(contexts[i] instanceof URI) g = "into graph <" + contexts[i].stringValue() + ">";
//				continue addTriplesToEachContext;
			}
//			else if(contexts[i] instanceof URI) {
//				URI context = (URI)contexts[i];
				s = s.replaceAll("'", "''");
				p = p.replaceAll("'", "''");
				o = o.replaceAll("'", "''");
				query.append("sparql insert " + g + " { ");
				query.append(s);
				query.append(" ");
				query.append(p);
				query.append(" ");
				query.append(o);
				query.append(" }");
				try {
					java.sql.Statement stmt = getQuadStoreConnection().createStatement();
					stmt.execute(query.toString());
				}
				catch (Exception e) {
					throw new RuntimeException(e.toString());
				}
//			}
		}
	}

	private void addToQuadStore(URL dataURL, Resource ... contexts) {
		if(contexts == null) {
			contexts = new Resource[] {null}; // retrieve all statements under no context
		}
		else if(contexts.length == 0) {
			// TODO need to pass a wildcard context
		}
		
		loadEachContext:
		for(int i = 0; i < contexts.length; i++) {
			if(contexts[i] == null) {
				// TODO need to pass a wildcard for context
				continue loadEachContext;
			}
			else if(contexts[i] instanceof URI) {
				URI context = (URI) contexts[i];
				StringBuffer query = new StringBuffer();
				query.append("sparql load \"");
				query.append(dataURL);
				query.append("\" into graph <");
				query.append(context.stringValue());
				query.append(">");
				try {
					java.sql.Statement stmt = getQuadStoreConnection().createStatement();
					stmt.execute(query.toString());
				}
				catch (Exception e) {
					throw new RuntimeException(e.toString());
				}
			}
		}
	}
		
	private void clearQuadStore(Resource ... contexts) {
		if(contexts == null) {
			contexts = new Resource[] {null}; // retrieve all statements under no context
		}
		else if(contexts.length == 0) {
			// TODO need to pass a wildcard context
		}
		
		clearEachContext:
		for (int i = 0; i < contexts.length; i++) {
			if(contexts[i] == null) {
				// TODO need to pass a wildcard for context
				continue clearEachContext;
			}
			else if (contexts[i] instanceof URI) {
				URI context = (URI) contexts[i];
				try {
					StringBuffer query = new StringBuffer();
					// updated to use SPARUL
					// query.append("delete from RDF_QUAD where G=DB.DBA.RDF_MAKE_IID_OF_QNAME ('");
					// query.append(context.stringValue());
					// query.append("')");
					
					query.append("sparql ");
					query.append("clear graph <");
					query.append(context.stringValue());
					query.append(">");
					java.sql.Statement stmt = quadStoreConnection.createStatement();
					stmt.execute(query.toString());
				}
				catch (Exception e) {
					throw new RuntimeException(e.toString());
				}
			}
		}
	}
	
	private Graph selectFromQuadStore(Resource ... contexts) {
		return selectFromQuadStore(null, null, null, false, contexts);
	}
	
	private Graph selectFromQuadStore(Resource subject, URI predicate, Value object, boolean includeInferred, Resource ... contexts) {
		if(contexts == null) {
			contexts = new Resource[] {null}; // retrieve all statements under no context
		}
		else if(contexts.length == 0) {
			// TODO need to pass a wildcard context
		}
		
		Graph g = new GraphImpl();
		StringBuffer query = buildQuery(VirtuosoRepositoryConnection.TRANSACTION_SELECT, subject, predicate, object, contexts);
		
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet results = (VirtuosoResultSet) stmt.executeQuery(query.toString());

			ResultSetMetaData data = results.getMetaData();
			
			// begin at onset one
			while(results.next()) {
				for (int meta_count = 1; meta_count <= data.getColumnCount(); meta_count++) {
					// TODO need to parse these into appropriate resource values
					Object value = results.getObject(meta_count);
					if(data.getColumnName(meta_count).equals("s")) {
						try {
							subject = (Resource) castValue(value);
						}
						catch(ClassCastException ccex) {
							throw new RepositoryException("Unexpected resource type encountered. Was expecting Resource: " + value);
//							ccex.printStackTrace();
						}
					}
					else if(data.getColumnName(meta_count).equals("p")) {
						try {
							predicate = (URI) castValue(value);
						}
						catch(ClassCastException ccex) {
							throw new RepositoryException("Unexpected resource type encountered. Was expecting URI: " + value);
//							ccex.printStackTrace();
						}
					}
					else if(data.getColumnName(meta_count).equals("o")) {
						object = castValue(value);
					}
				}
				g.add(subject, predicate, object);
			}
		}
		catch (Exception e) {
                        throw new RuntimeException(getClass().getCanonicalName() + ": SPARQL execute failed." + "\n" + query.toString()+"["+e+"]");
//			e.printStackTrace();
		}
		return g;
	}
	
	private boolean deleteFromQuadStore(Resource subject, URI predicate, Value object, boolean includeInferred, Resource ... contexts) {
		StringBuffer query = buildQuery(VirtuosoRepositoryConnection.TRANSACTION_DELETE, subject, predicate, object, contexts);
		return false;
	}
	
	private boolean insertInQuadStore(Resource subject, URI predicate, Value object, boolean includeInferred, Resource ... contexts) {
		StringBuffer query = buildQuery(VirtuosoRepositoryConnection.TRANSACTION_INSERT, subject, predicate, object, contexts);
		return false;
	}
	
	final static int TRANSACTION_SELECT = 100;
	final static int TRANSACTION_DELETE = 110;
	final static int TRANSACTION_INSERT = 120;

	private StringBuffer buildQuery(int transactionType, Resource subject, URI predicate, Value object, Resource... contexts) {
		StringBuffer query = new StringBuffer();
		
		String s = "", p = "<" + predicate + ">", o = "";
		Vector<String> vars = new Vector<String>();
		
		if(subject == null || subject instanceof BNode) {
			s = "?s";
			vars.add(s);
		}
		else if(subject instanceof URI) {
			s = "<" + ((URI) subject).toString() + ">";
		}

		if(predicate == null || predicate instanceof BNode) {
			p = "?p";
			vars.add(p);
		}
		
		if(object == null || object instanceof BNode) {
			o = "?o";
			vars.add(o);
		}
		else if(object instanceof URI) {
			o = "<" + ((URI) object).toString() + ">";
		}
		else if(object instanceof Literal) {
			Literal lit = ((Literal)object);
			String label = lit.getLabel();
			String lang = lit.getLanguage();
			URI datatype = lit.getDatatype();
			try {
				o = Integer.parseInt(label) + "";
			}
			catch(NumberFormatException nfex) {
				o = "\"" + label + "\"";
				if(lang != null) o += "@" + lang;
				else if(datatype != null) o += "^^" + "<" + datatype + ">";
			}
			
		}		
		
		switch(transactionType) {
			case VirtuosoRepositoryConnection.TRANSACTION_SELECT: query.append("sparql select "); break;
			case VirtuosoRepositoryConnection.TRANSACTION_DELETE: query.append("sparql delete "); break;
			case VirtuosoRepositoryConnection.TRANSACTION_INSERT: query.append("sparql insert "); break;
		}
		
		// if no variables, use the 'data' keyword to insert/delete explicit triples
// if(vars.size() == 0) {
		if(transactionType == VirtuosoRepositoryConnection.TRANSACTION_SELECT) {
			for(int i = 0; i < vars.size(); i++) query.append(vars.elementAt(i) + " ");
		}
		else {
			query.append(" data ");
			if(transactionType == VirtuosoRepositoryConnection.TRANSACTION_DELETE) {
				query.append(" from ");
			}
			else if(transactionType == VirtuosoRepositoryConnection.TRANSACTION_INSERT) {
				query.append(" into ");
			}
			s = s.replaceAll("'", "''");
			p = p.replaceAll("'", "''");
			o = o.replaceAll("'", "''");
			query.append("{");
			query.append(s);
			query.append(" ");
			query.append(p);
			query.append(" ");
			query.append(o);
			query.append("}");
		}
// }
		
		query.append("where { ");
		
		boolean addGraphClause = false;
// for (int i = 0; i < contexts.length; i++) {
// if(contexts[i] == null) {
// query.append("graph ?g {");
// addGraphClause = true;
// }
// else if (contexts[i] instanceof URI) {
// URI context = (URI) contexts[i];
// query.append("graph <" + context + "> {");
// addGraphClause = true;
// }
// }
		if(contexts != null && contexts.length == 1) {
			if(!addGraphClause) addGraphClause = true;
			query.append("graph <" + contexts[0] + "> {");
		}
		query.append(s);
		query.append(" ");
		query.append(p);
		query.append(" ");
		query.append(o);
		if(addGraphClause) query.append(".} "); // close graph
		query.append("} "); // close where
		
		if(vars.size() == 0) {
			try {
				throw new RepositoryException("No projection found: " + query);
			}
			catch (RepositoryException e) {
				e.printStackTrace();
				return new StringBuffer();
			}
		}
		return query;
	}

	
	
	public TupleQueryResult executeSPARQLForQueryResult(String query) {
		Vector<String> names = new Vector();
		Vector<BindingSet> bindings = new Vector();
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet results = (VirtuosoResultSet) stmt.executeQuery(query);

			ResultSetMetaData data = results.getMetaData();
			String[] col_names = new String[data.getColumnCount()];
			
			// begin at onset one
			for (int meta_count = 1; meta_count <= data.getColumnCount(); meta_count++) {
				String col = data.getColumnName(meta_count);
				if(names.indexOf(col) < 0) names.add(col); // no duplicates
			}
			while(results.next()) {
				QueryBindingSet qbs = new QueryBindingSet();
				for (int meta_count = 1; meta_count <= data.getColumnCount(); meta_count++) {
					// TODO need to parse these into appropriate resource values
					String col = data.getColumnName(meta_count);
					Object val = results.getObject(col);
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


	private Value castValue(Object val) {
		if(val == null) return null;
	    if (val instanceof VirtuosoRdfBox) {
			VirtuosoRdfBox rb = (VirtuosoRdfBox) val;
			Literal lit = getRepository().getValueFactory().createLiteral(rb.rb_box.toString());
			if(rb.getLang() != null) {
				lit = getRepository().getValueFactory().createLiteral(rb.rb_box.toString(), rb.getLang());
			}
			else if(rb.getType() != null) {
				lit = getRepository().getValueFactory().createLiteral(rb.rb_box.toString(), this.getRepository().getValueFactory().createURI(rb.getType()));
			}
			// System.out.println(rb.rb_box + " lang=" + rb.getLang() + " type=" + rb.getType() + " ro_id=" + rb.rb_ro_id);
			return lit;
	    }
		else if (val instanceof java.lang.Integer) {
			 URI type = getRepository().getValueFactory().createURI("http://www.w3.org/2001/XMLSchema#integer");
			 Literal lit = getRepository().getValueFactory().createLiteral(val.toString(), type);
		     return lit;
		}
		else if (val instanceof java.lang.Short) {
			 URI type = getRepository().getValueFactory().createURI("http://www.w3.org/2001/XMLSchema#integer");
			 Literal lit = getRepository().getValueFactory().createLiteral(val.toString(), type);
		     return lit;
		}
		else if (val instanceof java.lang.Float) {
			 URI type = getRepository().getValueFactory().createURI("http://www.w3.org/2001/XMLSchema#float");
			 Literal lit = getRepository().getValueFactory().createLiteral(val.toString(), type);
		     return lit;
		}
		else if (val instanceof java.lang.Double) {
			 URI type = getRepository().getValueFactory().createURI("http://www.w3.org/2001/XMLSchema#double");
			 Literal lit = getRepository().getValueFactory().createLiteral(val.toString(), type);
		     return lit;
		}
		else if (val instanceof java.math.BigDecimal) {
			 URI type = getRepository().getValueFactory().createURI("http://www.w3.org/2001/XMLSchema#decimal");
			 Literal lit = getRepository().getValueFactory().createLiteral(val.toString(), type);
		     return lit;
		}
		else if (val instanceof java.sql.Blob) {
			 URI type = getRepository().getValueFactory().createURI("http://www.w3.org/2001/XMLSchema#hexBinary");
			 Literal lit = getRepository().getValueFactory().createLiteral(val.toString(), type);
		     return lit;
		}
		else if (val instanceof java.sql.Date) {
			 URI type = getRepository().getValueFactory().createURI("http://www.w3.org/2001/XMLSchema#date");
			 Literal lit = getRepository().getValueFactory().createLiteral(val.toString(), type);
		     return lit;
		}
		else if (val instanceof java.sql.Timestamp) {
			 URI type = getRepository().getValueFactory().createURI("http://www.w3.org/2001/XMLSchema#dateTime");
			 Literal lit = getRepository().getValueFactory().createLiteral(val.toString(), type);
		     return lit;
		}
		else if (val instanceof java.sql.Time) {
			 URI type = getRepository().getValueFactory().createURI("http://www.w3.org/2001/XMLSchema#time");
			 Literal lit = getRepository().getValueFactory().createLiteral(val.toString(), type);
		     return lit;
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
					return getRepository().getValueFactory().createURI(valueString);
				}
				catch(IllegalArgumentException iaex) {
				        throw new RuntimeException("VirtuosoRepositoryConnection().castValue() Invalid value from Virtuoso: \"" + valueString + "\", STRTYPE = " + ves.iriType);
				}
		    }
		    else if (ves.iriType == VirtuosoExtendedString.BNODE) {
//				if(valueString.startsWith("nodeID://")) {
					try {
						valueString = valueString.substring(9); // parse bnode id
						return getRepository().getValueFactory().createBNode(valueString);
					}
					catch(IllegalArgumentException iaex) {
						throw new RuntimeException("VirtuosoRepositoryConnection().castValue() Invalid value from Virtuoso: \"" + valueString + "\", STRTYPE = " + ves.iriType);
					}
//				}
		    }
		    else {
				try {
					return getRepository().getValueFactory().createLiteral(valueString);
				}
				catch(IllegalArgumentException iaex) {
					throw new RuntimeException("VirtuosoRepositoryConnection().castValue() Invalid value from Virtuoso: \"" + valueString + "\", STRTYPE = " + ves.iriType);
				}
		    }
		}
		else { //if(val instanceof String) {
		String s = (String) val;
			if(s.length() == 0) return null;
			try {
				return getRepository().getValueFactory().createLiteral(s);
			}
			catch(IllegalArgumentException iaex2) {
				throw new RuntimeException("VirtuosoRepositoryConnection().castValue() Could not parse resource: " + s);
			}
		}
//		return null;
	}
	
	public void executeSPARQLForHandler(TupleQueryResultHandler tqrh, String query) {
		try {
			java.sql.Statement stmt = getQuadStoreConnection().createStatement();
			VirtuosoResultSet results = (VirtuosoResultSet) stmt.executeQuery(query);

			ResultSetMetaData data = results.getMetaData();
			String[] col_names = new String[data.getColumnCount()];
			
			// begin at onset one
			for (int meta_count = 1; meta_count <= data.getColumnCount(); meta_count++) {
				col_names[meta_count - 1] = data.getColumnLabel(meta_count);
			}
			while(results.next()) {
				QueryBindingSet qbs = new QueryBindingSet();
				for (int meta_count = 1; meta_count <= data.getColumnCount(); meta_count++) {
					// TODO need to parse these into appropriate resource values
					String col = data.getColumnName(meta_count);
					Object val = results.getObject(col);
					Value v = castValue(val);
					qbs.addBinding(col, v);
				}
				tqrh.handleSolution(qbs);
			}
		}
		catch (Exception e) {
			throw new RuntimeException(e.toString());
// System.exit(-1);
		}
	}

	public Connection getQuadStoreConnection() {
		return quadStoreConnection;
	}

	public void setQuadStoreConnection(Connection quadStoreConnection) {
		this.quadStoreConnection = quadStoreConnection;
	}

	/**
	 * Creates a RepositoryResult for the supplied element set.
	 */
	protected <E> RepositoryResult<E> createRepositoryResult(Iterable<? extends E> elements) {
		return new RepositoryResult<E>(new CloseableIteratorIteration<E, RepositoryException>(
				elements.iterator()));
	}

}
