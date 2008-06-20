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

	static int PASSED = 0;
	static int FAILED = 0;

	public static void START(String mess) {
	  System.out.println("== "+mess+" : Start");
	}

	public static void LOG(String mess) {
	  System.out.println("   "+mess);
	}

	public static void END(String mess, boolean OK) {
	  System.out.println("== "+mess+" : End");
	  System.out.println("**"+(OK? "PASSED":"FAILED")+"**\n");
	  if (OK)
	    PASSED++;
	  else
	    FAILED++;
	}

	public static void TOTAL() {
	  System.out.println("============================");
	  System.out.println("PASSED:"+PASSED+" FAILED:"+FAILED);
	}

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
			String query = null;
			String strurl = "http://www.openlinksw.com/dataspace/person/kidehen@openlinksw.com/foaf.rdf";
			URL url = new URL(strurl);
			URI context = repository.getValueFactory().createURI("http://demo.openlinksw.com/demo#this");
                        Value[][] results = null;


                        START("TEST 1a");
			// test query data
			query = "SELECT * FROM <"+context+"> WHERE {?s ?p ?o} LIMIT 1";
			try {
			  LOG("TEST 1a: Loading data from URL: " + strurl);
			  con.add(url, "", RDFFormat.RDFXML, context);
			  OK = true;
			  results = doQuery(con, query);
			} catch (Exception e) { 
			  LOG("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			END("TEST 1a", (OK && (results.length > 0))); // should return true

                        START("TEST 1b");
			try {
			  OK = true;
			  con.clear(context);
			  LOG("TEST 1b: Clearing triple store");
			  long sz = con.size(context);
			  OK = (sz == 0);
			} catch (Exception e) { 
			  LOG("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			END("TEST 1b", OK); // should return sz == 0

			// test add data from a flat file
			START("TEST 1c");
			String fstr = "virtuoso_driver" + File.separator + "data.nt";
			LOG("TEST 1c: Loading data from file: " + fstr);
			try {
			  OK = true;
			  File dataFile = new File(fstr);
			  con.add(dataFile, "", RDFFormat.NTRIPLES, context);
			  query = "SELECT * FROM <"+context+"> WHERE {?s ?p ?o} LIMIT 1";
			  results = doQuery(con, query);
			} catch (Exception e) { 
			  LOG("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			END("TEST 1c", (results != null && results.length > 0)); // should return true

			URI shermanmonroe = repository.getValueFactory().createURI("http://mso.monrai.com/foaf/shermanMonroe");
			BNode snode = repository.getValueFactory().createBNode("smonroeNode");
			URI name = repository.getValueFactory().createURI("http://mso.monrai.com/foaf/name");
			Literal nameValue = repository.getValueFactory().createLiteral("Sherman Monroe");

			START("TEST 1d");
			try {
			  OK = true;
			  con.clear(context);
			  LOG("TEST 1d: Loading single triple");
			  con.add(snode, name, nameValue, context);
			  query = "SELECT * FROM <"+context+"> WHERE {?s ?p ?o} LIMIT 1";
			  results = doQuery(con, query);
			} catch (Exception e) { 
			  LOG("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			END("TEST 1d", (OK && (results.length > 0))); // should return true

			if (results.length > 0) {
			        START("TEST 1e");
				LOG("TEST 1e: Casted value type");
				if (!((results[0][0] instanceof BNode) && (results[0][1] instanceof URI) && (results[0][2] instanceof Literal))) {
					LOG("TEST 1e Value types: " + (OK &&(results[0][0] == null) ? null : results[0][0].getClass().getName()) + ", " + ((results[0][1] == null) ? null : results[0][1].getClass().getName()) + ", " + ((results[0][2] == null) ? null : results[0][2].getClass().getName())); // should
				}
				END("TEST 1e", (OK && (results[0][0] instanceof BNode) && (results[0][1] instanceof URI) && (results[0][2] instanceof Literal))); // should return true
			}

                        START("TEST 2");
			try {
			  OK = true;
			  LOG("TEST 2: Selecting property");
			  query = "SELECT * FROM <"+context+"> WHERE {?s <http://mso.monrai.com/foaf/name> ?o} LIMIT 1";
			  results = doQuery(con, query);
			} catch (Exception e) { 
			  LOG("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			END("Test 2", (OK && (results.length > 0))); // should return true

		        boolean exists = false;
                        START("TEST 3");
			try {
			  OK = true;
			  con.add(shermanmonroe, name, nameValue, context);
			  exists = con.hasStatement(shermanmonroe, name, null, false, context);
			  if (!exists)
			    throw new Exception("Triple wasn't added");
			  // test remove a statement
			  con.remove(shermanmonroe, name, nameValue, (Resource) context);
			  // test statement removed
			  LOG("TEST 3: Statement does not exists");
			  exists = con.hasStatement(shermanmonroe, name, null, false, context);
			} catch (Exception e) { 
			  LOG("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			END("TEST 3", (OK && !exists)); // should return false

                        START("TEST 4");
			try {
			  OK = true;
			  LOG("TEST 4: Statement exists");
			  con.add(shermanmonroe, name, nameValue, context);
			  exists = con.hasStatement(shermanmonroe, name, null, false, context);
			  if (!exists)
			    throw new Exception("Triple wasn't added");
			  query = "SELECT * FROM <"+context+"> WHERE {?s <http://mso.monrai.com/foaf/name> ?o} LIMIT 1";
			  results = doQuery(con, query);
			} catch (Exception e) { 
			  LOG("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			END("Test 4", (OK && (results.length > 0))); // should return true

                        START("TEST 5");
			try {
			  OK = true;
 			  LOG("TEST 5: Statement exists");
			  exists = con.hasStatement(shermanmonroe, name, null, false, context);
			} catch (Exception e) { 
			  LOG("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			END("Test 5", (OK && exists)); // should return true

			// test getNamespace
			Namespace testns = null;
			RepositoryResult<Namespace> namespaces = null;
			boolean hasNamespaces = false;

			try {
			  namespaces = con.getNamespaces();
			  hasNamespaces = namespaces.hasNext();
			  while (namespaces.hasNext()) {
				Namespace ns = namespaces.next();
				// LOG("Namespace found: (" + ns.getName() + " " + ns.getPrefix() + ")");
				testns = ns;
			  }
			} catch (Exception e) { 
			  LOG("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}

			// test getNamespaces and RepositoryResult implementation
                        START("TEST 6");
			try {
			  OK = true;
			  LOG("TEST 6: Retrieving namespaces");
			  if (testns != null) {
				// LOG("Retrieving namespace (" + testns.getName() + " " + testns.getPrefix() + ")");
				String ns = con.getNamespace(testns.getPrefix());
				if (hasNamespaces) 
				  OK = (ns != null);
				else
				  OK = false;
			  }
			} catch (Exception e) { 
			  LOG("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			END("TEST 6", OK); // should return true

			RepositoryResult<Statement> statements = null;
			// test getStatements and RepositoryResult implementation
                        START("TEST 7");
			try {
			  OK = true;
			  LOG("TEST 7: Retrieving statement (" + shermanmonroe + " " + name + " " + null + ")");
			  statements = con.getStatements(shermanmonroe, name, null, false, context);
			} catch (Exception e) { 
			  LOG("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			END("TEST 7", (OK && statements.hasNext())); // should return true
			while (statements.hasNext()) {
				Statement st = statements.next();
				// System.out.println("Statement found: (" + st.getSubject() + " " + st.getPredicate() + " " + st.getObject() + ")");
			}

                        START("TEST 8");
			// test export and handlers
			File f = new File("results.n3.txt");
			try {
			  OK = true;
			  LOG("TEST 8: Writing the statements to file: (" + f.getAbsolutePath() + ")");
			  RDFHandler ntw = new NTriplesWriter(new FileOutputStream(f));
			  con.exportStatements(shermanmonroe, name, null, false, ntw);
			} catch (Exception e) { 
			  LOG("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			END("TEST 8", (OK && f.exists())); // should return true

                        START("TEST 9");
			RepositoryResult<Resource> contexts = null;
			// test retrieve graph ids
			try {
			  OK = true;
			  LOG("TEST 9: Retrieving graph ids");
			  contexts = con.getContextIDs();
			} catch (Exception e) { 
			  LOG("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			END("TEST 9", (OK && contexts != null ? contexts.hasNext():false)); // should return true
			if (contexts != null)
			  while (contexts.hasNext()) {
				Value id = contexts.next();
				if ((id instanceof Literal)) 
				  LOG("Literal value for graphid found: (" + ((Literal) id).getLabel() + ")");
			  }

                        START("TEST 10");
			// test get size
			try {
			  OK = true;
			  LOG("TEST 10: Retrieving triple store size");
			  // sz = con.size(context);
			  // System.out.println("TEST 10: Passed: " + (sz > 0)); // should return sz > 0 results
			} catch (Exception e) { 
			  System.out.println("Error["+e+"]");
			  e.printStackTrace();
			  OK = false;
			}
			END("TEST 10", OK); // should return sz > 0 results

                        TOTAL();

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
//			System.out.println("RESULT " + (row + 1) + ": ");
			BindingSet pairs = bindings.next();
			List<String> names = bindings.getBindingNames();
			Value[] rv = new Value[names.size()];
			for (int i = 0; i < names.size(); i++) {
				String name = names.get(i);
				Value value = pairs.getValue(name);
				rv[i] = value;
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

			stmt.execute("clear graph <gr>");
			ResultSet rs = stmt.getResultSet();
			while (rs.next());

			stmt.execute("insert into graph <gr> " + "{ <aa> <bb> \"cc\" . <xx> <yy> <zz> . " + "  <mm> <nn> \"Some long literal with language\"@en . " + "  <oo> <pp> \"12345\"^^<http://www.w3.org/2001/XMLSchema#int> }");
			rs = stmt.getResultSet();
			while (rs.next());

			// output:valmode "LONG" turns RDF box on output
			// boolean more = stmt.execute("define output:valmode \"LONG\" select * from <gr> where { ?x ?y ?z }");
			boolean more = stmt.execute("select * from <gr> where { ?x ?y ?z }");
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
