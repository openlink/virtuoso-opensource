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

//package virtuoso.sesame2.driver;

import java.io.File;
import java.io.FileOutputStream;
import java.net.URL;
import java.util.List;
import java.util.Vector;

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

import virtuoso.sesame2.driver.*;

public class VirtuosoExample {

	public static final String EC2_INSTANCE = "localhost"; //"ec2-75-101-210-102.compute-1.amazonaws.com";
	public static final int PORT = 1111;
	
	public static void main(String[] args) {
		try {
			Repository repository = new VirtuosoRepository("jdbc:virtuoso://" + VirtuosoExample.EC2_INSTANCE + ":" + VirtuosoExample.PORT, "dba", "dba");
			RepositoryConnection con = repository.getConnection();
			con.setAutoCommit(true);
			
//			// test ask query
//			String ask = "ask { ?s <http://mso.monrai.com/foaf/name> ?o }";
//			doQuery(con, ask);
			
			// test add data to the repository
			URL url = new URL("http://overdogg.com/rdf?fUserIds=null&type=rss_1.0&requestId=1&uid=null&facetSetType=null");
			URI context = repository.getValueFactory().createURI("http://demo.openlinksw.com/demo#this");
			con.add(url, "", RDFFormat.RDFXML, context);
			
			// test add data from a flat file
		    File dataFile = new File ("virtuoso_driver/data.nt");
			con.add(dataFile, "", RDFFormat.NTRIPLES, context);
			
			URI shermanmonroe = repository.getValueFactory().createURI("http://mso.monrai.com/people/shermanMonroe");
			URI name = repository.getValueFactory().createURI("http://mso.monrai.com/foaf/name");
			Literal nameValue = repository.getValueFactory().createLiteral("Sherman Monroe");
			con.add(shermanmonroe, name, nameValue, context);
			
			// test query data
			String query = "sparql SELECT * WHERE {?s ?p ?o} LIMIT 1";
			doQuery(con, query);
			query = "sparql SELECT * WHERE {?s <http://mso.monrai.com/foaf/name> ?o} LIMIT 1";
			doQuery(con, query);
			
			// test remove a statement
			con.remove(shermanmonroe, name, nameValue, (Resource) null);
			
			// test statement removed
			boolean exists = con.hasStatement(shermanmonroe, name, null, false, context);
			System.out.println("Test for query returned " + exists); // should return false
			query = "sparql SELECT * WHERE {?s <http://mso.monrai.com/foaf/name> ?o} LIMIT 1";
			doQuery(con, query);
			
			exists = con.hasStatement(shermanmonroe, name, null, false, context);
			System.out.println("Test for query returned " + exists); // should return true
			
			// test getNamespace
			Namespace testns = null;
			RepositoryResult<Namespace> namespaces = con.getNamespaces();
			while(namespaces.hasNext()){
				Namespace ns = namespaces.next();
				System.out.println("Namespace found: (" + ns.getName() + " " + ns.getPrefix() + ")");
				testns = ns;
			}
			
			// test getNamespaces and RepositoryResult implementation
			System.out.println("Retrieving namespaces");
			if(testns != null) {
				System.out.println("Retrieving namespace (" + testns.getName() + " " + testns.getPrefix() + ")");
				String ns = con.getNamespace(testns.getPrefix());
				if(ns != null) System.out.println("Found namespace (" + ns + ")");
				else System.out.println("Could not find namespace");
			}
			
			// test getStatements and RepositoryResult implementation
			System.out.println("Retrieving statement (" + shermanmonroe + " " + name + " " + null + ")");
			RepositoryResult<Statement> statements = con.getStatements(shermanmonroe, name, null, false);
			while(statements.hasNext()){
				Statement st = statements.next();
				System.out.println("Statement found: (" + st.getSubject() + " " + st.getPredicate() + " " + st.getObject() + ")");
			}
			
			// test export and handlers
			File f = new File("results.n3.txt");
			System.out.println("Writing the statements to file: (" + f.getAbsolutePath() + ")");
			RDFHandler ntw = new NTriplesWriter(new FileOutputStream(f));
			con.exportStatements(shermanmonroe, name, null, false, ntw);
			
			// test retrieve graph ids
			System.out.println("Retrieving graph ids");
			RepositoryResult<Resource> contexts = con.getContextIDs();
			while(contexts.hasNext()){
				Resource id = contexts.next();
				System.out.println("Graph id found: (" + id + ")");
			}
//			con.close();
		}
		catch(Exception e) {
			e.printStackTrace();
		}
	}

	private static Vector<Vector<Value>> doQuery(RepositoryConnection con, String query) throws RepositoryException, MalformedQueryException, QueryEvaluationException {
		TupleQuery resultsTable = con.prepareTupleQuery(QueryLanguage.SPARQL, query);
		TupleQueryResult bindings = resultsTable.evaluate();

		Vector<Vector<Value>> results = new Vector<Vector<Value>>();
		for (int row = 0; bindings.hasNext(); row++) {
			System.out.println("RESULT " + (row + 1) + ": ");
			Vector<Value> vars = new Vector<Value>();
			BindingSet pairs = bindings.next();
			List<String> names = bindings.getBindingNames();
			for (int column = 0; column < names.size(); column++) {
				String name = names.get(column);
				Value value = pairs.getValue(name);
//					if(column > 0) 	System.out.print(", ");
				System.out.println("\t" + name + "=" + value);
				vars.add(value);
//					if(column + 1 == names.size())	System.out.println(";");
			}
			results.add(vars);
		}
		return results;
	}
	
}
