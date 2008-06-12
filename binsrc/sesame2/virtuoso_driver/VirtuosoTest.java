/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2008 OpenLink Software
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

//package virtuoso.sesame.driver;

import java.io.File;
import java.io.FileOutputStream;
import java.net.URL;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.util.List;
import java.util.Vector;

import org.openrdf.model.BNode;
import org.openrdf.model.Literal;
import org.openrdf.model.Namespace;
import org.openrdf.model.Resource;
import org.openrdf.model.Statement;
import org.openrdf.model.URI;
import org.openrdf.model.Value;
import org.openrdf.query.BindingSet;
import org.openrdf.query.MalformedQueryException;
import org.openrdf.query.QueryEvaluationException;
import org.openrdf.query.QueryLanguage;
import org.openrdf.query.TupleQuery;
import org.openrdf.query.TupleQueryResult;
import org.openrdf.repository.Repository;
import org.openrdf.repository.RepositoryConnection;
import org.openrdf.repository.RepositoryException;
import org.openrdf.repository.RepositoryResult;
import org.openrdf.rio.RDFFormat;
import org.openrdf.rio.RDFHandler;
import org.openrdf.rio.ntriples.NTriplesWriter;

import virtuoso.jdbc3.VirtuosoExtendedString;
import virtuoso.jdbc3.VirtuosoRdfBox;

import virtuoso.sesame2.driver.*;

public class VirtuosoTest {

	public static final String VIRTUOSO_INSTANCE = "localhost"; 
	public static final int VIRTUOSO_PORT = 1111;
	public static final String VIRTUOSO_USERNAME = "dba";
	public static final String VIRTUOSO_PASSWORD = "dba";

	public static void main(String[] args) {
		
		
		String[] sa = new String[4];
		sa[0] = VIRTUOSO_INSTANCE;
		sa[1] = VIRTUOSO_PORT + "";
		sa[2] = VIRTUOSO_USERNAME;
		sa[3] = VIRTUOSO_PASSWORD;
		for (int i = 0; i < sa.length && i < args.length; i++) {
			sa[i] = args[i];
		}
		Repository repository = new VirtuosoRepository("jdbc:virtuoso://" + sa[0] + ":" + sa[1], sa[2], sa[3]);
		RepositoryConnection con = null;
		try {
			con = repository.getConnection();
			con.setAutoCommit(true);

			// // test ask query
			// String ask = "ask { ?s <http://mso.monrai.com/foaf/name> ?o }";
			// doQuery(con, ask);

			// test add data to the repository
			boolean OK = true;
			String strurl = "http://www.openlinksw.com/dataspace/person/kidehen@openlinksw.com/foaf.rdf";
			System.out.println("TEST 1a: Loading data from URL: " + strurl);
			URL url = new URL(strurl);
			URI context = repository.getValueFactory().createURI("http://demo.openlinksw.com/demo#this");
			con.add(url, "", RDFFormat.RDFXML, context);

                        Value[][] results = null;
			// test query data
			String query = "sparql SELECT * WHERE {?s ?p ?o} LIMIT 1";
			try {
			  OK = true;
			  results = doQuery(con, query);
			} catch (Exception e) { 
			  System.out.println("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			System.out.println("TEST 1a Passed: " + (OK && (results.length > 0))); // should return true

			try {
			  OK = true;
			  con.clear();
			  System.out.println("TEST 1b: Clearing triple store");
			  // long sz = con.size();
			  // System.out.println("TEST 1b: Passed: " + (sz == 0)); // should return sz == 0
			} catch (Exception e) { 
			  System.out.println("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			System.out.println("TEST 1b: Passed: N/A "+ OK); // should return sz == 0

			// test add data from a flat file
			String fstr = "virtuoso_driver" + File.separator + "data.nt";
			System.out.println("TEST 1c: Loading data from file: " + fstr);
			try {
			  OK = true;
			  File dataFile = new File(fstr);
			  con.add(dataFile, "", RDFFormat.NTRIPLES, context);
			  query = "sparql SELECT * WHERE {?s ?p ?o} LIMIT 1";
			  results = doQuery(con, query);
			} catch (Exception e) { 
			  System.out.println("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			System.out.println("TEST 1c Passed: " + (results.length > 0)); // should return true


			URI shermanmonroe = repository.getValueFactory().createURI("http://mso.monrai.com/foaf/shermanMonroe");
			BNode snode = repository.getValueFactory().createBNode("smonroeNode");
			URI name = repository.getValueFactory().createURI("http://mso.monrai.com/foaf/name");
			Literal nameValue = repository.getValueFactory().createLiteral("Sherman Monroe");

			try {
			  OK = true;
			  con.clear();
			  System.out.println("TEST 1d: Loading single triple");
			  con.add(snode, name, nameValue, context);
			  query = "sparql SELECT * WHERE {?s ?p ?o} LIMIT 1";
			  results = doQuery(con, query);
			} catch (Exception e) { 
			  System.out.println("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			System.out.println("TEST 1d Passed: " + (OK && (results.length > 0))); // should return true

			if (results.length > 0) {
				System.out.println("TEST 1e: Casted value type");
				System.out.println("TEST 1e Passed: " + (OK && (results[0][0] instanceof BNode) && (results[0][1] instanceof URI) && (results[0][2] instanceof Literal))); // should return true
				if (!((results[0][0] instanceof BNode) && (results[0][1] instanceof URI) && (results[0][2] instanceof Literal))) {
					System.out.println("TEST 1e Value types: " + (OK &&(results[0][0] == null) ? null : results[0][0].getClass().getName()) + ", " + ((results[0][1] == null) ? null : results[0][1].getClass().getName()) + ", " + ((results[0][2] == null) ? null : results[0][2].getClass().getName())); // should
																																																																										// return
																																																																										// true
				}
			}

			try {
			  OK = true;
			  System.out.println("TEST 2: Selecting property");
			  query = "sparql SELECT * WHERE {?s <http://mso.monrai.com/foaf/name> ?o} LIMIT 1";
			  results = doQuery(con, query);
			} catch (Exception e) { 
			  System.out.println("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			System.out.println("Test 2 Passed: " + (OK && (results.length > 0))); // should return true

		        boolean exists = false;
			try {
			  OK = true;
			  // test remove a statement
			  con.remove(shermanmonroe, name, nameValue, (Resource) null);
			  // test statement removed
			  System.out.println("TEST 3: Statement does not exists");
			  exists = con.hasStatement(shermanmonroe, name, null, false, context);
			} catch (Exception e) { 
			  System.out.println("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			System.out.println("TEST 3 Passed: " + (OK && !exists)); // should return false

			try {
			  OK = true;
			  System.out.println("TEST 4: Statement exists");
			  query = "sparql SELECT * WHERE {?s <http://mso.monrai.com/foaf/name> ?o} LIMIT 1";
			  results = doQuery(con, query);
			} catch (Exception e) { 
			  System.out.println("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			System.out.println("Test 4 Passed: " + (OK && (results.length > 0))); // should return true

			try {
			  OK = true;
 			  System.out.println("TEST 5: Statement exists");
			  exists = con.hasStatement(shermanmonroe, name, null, false, context);
			} catch (Exception e) { 
			  System.out.println("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			System.out.println("Test 5 Passed: " + (OK && exists)); // should return true

			// test getNamespace
			Namespace testns = null;
			RepositoryResult<Namespace> namespaces = null;
			boolean hasNamespaces = false;
			try {
			  namespaces = con.getNamespaces();
			  hasNamespaces = namespaces.hasNext();
			  while (namespaces.hasNext()) {
				Namespace ns = namespaces.next();
				// System.out.println("Namespace found: (" + ns.getName() + " " + ns.getPrefix() + ")");
				testns = ns;
			  }
			} catch (Exception e) { 
			  System.out.println("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}

			// test getNamespaces and RepositoryResult implementation
			try {
			  OK = true;
			  System.out.println("TEST 6: Retrieving namespaces");
			  if (testns != null) {
				// System.out.println("Retrieving namespace (" + testns.getName() + " " + testns.getPrefix() + ")");
				String ns = con.getNamespace(testns.getPrefix());
				if (hasNamespaces) System.out.println("TEST 6 Passed: " + (OK && (ns != null))); // should return true
			  }
			} catch (Exception e) { 
			  System.out.println("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}

			RepositoryResult<Statement> statements = null;
			// test getStatements and RepositoryResult implementation
			try {
			  OK = true;
			  System.out.println("TEST 7: Retrieving statement (" + shermanmonroe + " " + name + " " + null + ")");
			  statements = con.getStatements(shermanmonroe, name, null, false);
			} catch (Exception e) { 
			  System.out.println("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			System.out.println("TEST 7 Passed: " + (OK && statements.hasNext())); // should return true
			while (statements.hasNext()) {
				Statement st = statements.next();
				// System.out.println("Statement found: (" + st.getSubject() + " " + st.getPredicate() + " " + st.getObject() + ")");
			}

			// test export and handlers
			File f = new File("results.n3.txt");
			try {
			  OK = true;
			  System.out.println("TEST 8: Writing the statements to file: (" + f.getAbsolutePath() + ")");
			  RDFHandler ntw = new NTriplesWriter(new FileOutputStream(f));
			  con.exportStatements(shermanmonroe, name, null, false, ntw);
			} catch (Exception e) { 
			  System.out.println("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			System.out.println("TEST 8 Passed: " + (OK && f.exists())); // should return true

			RepositoryResult<Resource> contexts = null;
			// test retrieve graph ids
			try {
			  OK = true;
			  System.out.println("TEST 9: Retrieving graph ids");
			  contexts = con.getContextIDs();
			} catch (Exception e) { 
			  System.out.println("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			System.out.println("TEST 9: Passed: " + (OK && contexts != null ? contexts.hasNext():false)); // should return true
			if (contexts != null)
			  while (contexts.hasNext()) {
				Value id = contexts.next();
				if ((id instanceof Literal)) System.out.println("Literal value for graphid found: (" + ((Literal) id).getLabel() + ")");
			  }

			// test get size
			try {
			  OK = true;
			  System.out.println("TEST 10: Retrieving triple store size");
			  // sz = con.size();
			  // System.out.println("TEST 10: Passed: " + (sz > 0)); // should return sz > 0 results
			} catch (Exception e) { 
			  System.out.println("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			System.out.println("TEST 10: Passed: N/A"); // should return sz > 0 results

		}
		catch (Exception e) {
			System.out.println("ERROR Test Failed.");
			e.printStackTrace();
		}
		finally {
			if (con != null) try {
				con.close();
			}
			catch (RepositoryException e) {
				e.printStackTrace();
			}
		}
	}

	private static Value[][] doQuery(RepositoryConnection con, String query) throws RepositoryException, MalformedQueryException, QueryEvaluationException {
		TupleQuery resultsTable = con.prepareTupleQuery(QueryLanguage.SPARQL, query);
		TupleQueryResult bindings = resultsTable.evaluate();

		Vector<Value[]> results = new Vector<Value[]>();
		for (int row = 0; bindings.hasNext(); row++) {
			// System.out.println("RESULT " + (row + 1) + ": ");
			BindingSet pairs = bindings.next();
			List<String> names = bindings.getBindingNames();
			Value[] rv = new Value[names.size()];
			for (int column = 0; column < names.size(); column++) {
				String name = names.get(column);
				Value value = pairs.getValue(name);
				rv[row] = value;
				// if(column > 0) System.out.print(", ");
				// System.out.println("\t" + name + "=" + value);
				// vars.add(value);
				// if(column + 1 == names.size()) System.out.println(";");
			}
			results.add(rv);
		}
		return (Value[][]) results.toArray(new Value[0][0]);
	}

	public static void test(String args[]) {
		try {
			String url;
			url = "jdbc:virtuoso://localhost:1111";
			Class.forName("virtuoso.jdbc3.Driver");
			Connection connection = DriverManager.getConnection(url, "dba", "123456");
			java.sql.Statement stmt = connection.createStatement();

			stmt.execute("sparql clear graph <gr>");
			ResultSet rs = stmt.getResultSet();
			while (rs.next());

			stmt.execute("sparql insert into graph <gr> " + "{ <aa> <bb> \"cc\" . <xx> <yy> <zz> . " + "  <mm> <nn> \"Some long literal with language\"@en . " + "  <oo> <pp> \"12345\"^^<http://www.w3.org/2001/XMLSchema#int> }");
			rs = stmt.getResultSet();
			while (rs.next());

			// output:valmode "LONG" turns RDF box on output
			// boolean more = stmt.execute("sparql define output:valmode \"LONG\" select * from <gr> where { ?x ?y ?z }");
			boolean more = stmt.execute("sparql select * from <gr> where { ?x ?y ?z }");
			ResultSetMetaData data = stmt.getResultSet().getMetaData();
			for (int i = 1; i <= data.getColumnCount(); i++)
				System.out.println(data.getColumnLabel(i) + "\t" + data.getColumnTypeName(i));
			System.out.println("===");
			if (more) {
				rs = stmt.getResultSet();
				while (rs.next()) {
					for (int i = 1; i <= data.getColumnCount(); i++) {
						String s = stmt.getResultSet().getString(i);
						Object o = stmt.getResultSet().getObject(i);
//						Value casted = 
						System.out.print("Object type is " + o.getClass().getName() + " ");
						System.out.print(data.getColumnLabel(i) + " = ");
						if (o instanceof VirtuosoRdfBox) // Typed literal
						{
							VirtuosoRdfBox rb = (VirtuosoRdfBox) o;
							System.out.println(rb.rb_box + " lang=" + rb.getLang() + " type=" + rb.getType() + " ro_id=" + rb.rb_ro_id);
						}
						else if (o instanceof VirtuosoExtendedString) // String representing an IRI
						{
							VirtuosoExtendedString vs = (VirtuosoExtendedString) o;
							if (vs.iriType == VirtuosoExtendedString.IRI) System.out.println("<" + vs.str + ">");
							else if (vs.iriType == VirtuosoExtendedString.BNODE) System.out.println("<" + vs.str + ">");
							else // not reached atm, literals are String or RdfBox
							System.out.println("\"" + vs.str + "\"");
						}
						else if (stmt.getResultSet().wasNull()) System.out.println("NULL\t");
						else System.out.println(s + " (No extended type availible)\t");
					}
					System.out.println("---");
				}
				more = stmt.getMoreResults();
			}
			stmt.close();

			// Try making new typed literal
			// System.out.println("---");
			// VirtuosoRdfBox rb = new VirtuosoRdfBox (connection, "Some literal with many symbols over 20", null, "cz");
			// System.out.println (rb.rb_box + " lang=" + rb.getLang() + " type=" + rb.getType() + " ro_id=" + rb.rb_ro_id );

			connection.close();
		}
		catch (Exception e) {
			e.printStackTrace();
			System.exit(-1);
		}
		System.out.println("eof");
		System.exit(0);
	}

}
