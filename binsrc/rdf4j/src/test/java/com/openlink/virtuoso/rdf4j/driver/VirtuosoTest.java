
package com.openlink.virtuoso.rdf4j.driver;

import org.eclipse.rdf4j.common.iteration.Iterations;
import org.eclipse.rdf4j.model.*;
import org.eclipse.rdf4j.model.impl.LinkedHashModel;
import org.eclipse.rdf4j.query.*;
import org.eclipse.rdf4j.repository.RepositoryConnection;
import org.eclipse.rdf4j.repository.RepositoryException;
import org.eclipse.rdf4j.repository.RepositoryResult;
import org.eclipse.rdf4j.rio.RDFFormat;
import org.eclipse.rdf4j.rio.RDFHandler;
import org.eclipse.rdf4j.rio.ntriples.NTriplesWriter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestMethodOrder;

import java.io.File;
import java.io.FileOutputStream;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;


@TestMethodOrder(MethodOrderer.Alphanumeric.class)
public class VirtuosoTest extends TestBase {


    static String ctx = "http://demo.openlinksw.com/demo#this";
    static URL url;

    @BeforeEach
    public void setUp() throws Exception {
        super.setUp();

        String strUrl = "https://protege.stanford.edu/ontologies/pizza/pizza.owl";
        url = new URL(strUrl);
    }


    @Test
    public void test1() {
        RepositoryConnection con = null;
        try {
            // test add data to the repository
            IRI context = repository.getValueFactory().createIRI(ctx);

            con = repository.getConnection();

            con.clear(context);

            IRI subject = repository.getValueFactory().createIRI("urn:s");
            IRI predicate = repository.getValueFactory().createIRI("urn:p");
            IRI object = repository.getValueFactory().createIRI("urn:o");
            boolean rc;
            rc = con.getStatements(subject, predicate, object, false, context).hasNext();
            assertFalse(rc, "Graph wasn't cleared");

            con.begin();
            con.add(subject, predicate, object, context);
            rc = con.getStatements(subject, predicate, object, false, context).hasNext();
            assertTrue(rc, "Data wasn't inserted");
            con.rollback();
            rc = con.getStatements(subject, predicate, object, false, context).hasNext();
            assertFalse(rc, "Rollback doesn't work");

        } finally {
            if (con != null)
                con.close();
        }
    }


    @Test
    public void test2() throws Exception {
        RepositoryConnection con = null;
        try {
            // test add data to the repository
            IRI context = repository.getValueFactory().createIRI(ctx);
            Value[][] results;

            con = repository.getConnection();

            // test query data
            String query = "SELECT * FROM <" + context + "> WHERE {?s ?p ?o} LIMIT 1";

            log("Loading data from URL: " + url);
            con.add(url, "", RDFFormat.RDFXML, context);
            results = doTupleQuery(con, query);
            assertTrue((results.length > 0), "Empty ResultSet");

            con.clear(context);
            log("Clearing triple store");
            long sz = con.size(context);
            assertTrue((sz == 0), "Graph wasn't cleared");
        } finally {
            if (con != null)
                con.close();
        }
    }


    @Test
    public void test3() throws Exception {
        RepositoryConnection con = null;
        try {
            // test add data to the repository
            IRI context = repository.getValueFactory().createIRI(ctx);
            Value[][] results;

            con = repository.getConnection();

            ClassLoader classLoader = Thread.currentThread().getContextClassLoader();
            URL dataFile = classLoader.getResource("data.nt");

            con.add(dataFile, "", RDFFormat.NTRIPLES, context);
            String query = "SELECT * FROM <" + context + "> WHERE {?s ?p ?o} LIMIT 1";
            results = doTupleQuery(con, query);
            assertTrue((results.length > 0), "ResultSet is EMPTY");

            log("Execute query with parameter binding");
            query = "SELECT ?s ?o FROM <" + context + "> WHERE {?s ?p ?o} LIMIT 1";
            HashMap<String, Value> bind = new HashMap<>();
            bind.put("s", repository.getValueFactory().createIRI("http://dbpedia.org/resource/BatMan"));
            bind.put("o",
                    repository.getValueFactory().createIRI("http://sw.cyc.com/2006/07/27/cyc/Batman-TheComicStrip"));
            results = doTupleQuery(con, query, bind);
            assertTrue((results.length > 0), "ResultSet is EMPTY");
        } finally {
            if (con != null)
                con.close();
        }
    }


    @Test
    public void test4() {
        RepositoryConnection con = null;
        try {
            // test add data to the repository
            IRI context = repository.getValueFactory().createIRI(ctx);
            Value[][] results;

            con = repository.getConnection();

            byte[] utf8data = {(byte) 0xd0, (byte) 0xbf, (byte) 0xd1, (byte) 0x80,
                    (byte) 0xd0, (byte) 0xb8, (byte) 0xd0, (byte) 0xb2,
                    (byte) 0xd0, (byte) 0xb5, (byte) 0xd1, (byte) 0x82};
            String utf8str = new String(utf8data, StandardCharsets.UTF_8);

            IRI un_testuri = repository.getValueFactory().createIRI("http://myopenlink.net/foaf/unicodeTest");
            IRI un_name = repository.getValueFactory().createIRI("http://myopenlink.net/foaf/name");
            Literal un_Value = repository.getValueFactory().createLiteral(utf8str);

            con.clear(context);
            log("Loading UNICODE single triple");
            con.add(un_testuri, un_name, un_Value, context);
            String query = "SELECT * FROM <" + context + "> WHERE {?s ?p ?o} LIMIT 1";
            results = doTupleQuery(con, query);
            assertTrue(results.length > 0, "ResultSet is Empty");
            assertEquals(results[0][0].toString(), un_testuri.toString(), "Col1 must be :" + un_testuri.toString());
            assertEquals(results[0][1].toString(), un_name.toString(), "Col2 must be :" + un_name.toString());
            assertEquals(results[0][2].toString(), un_Value.toString(), "Col3 must be :" + un_Value.toString());

        } finally {
            if (con != null)
                con.close();
        }
    }


    @Test
    public void test5() throws Exception {
        RepositoryConnection con = null;
        try {
            // test add data to the repository
            IRI context = repository.getValueFactory().createIRI(ctx);
            Value[][] results;

            con = repository.getConnection();

            IRI kingsleyidehen = repository.getValueFactory()
                                           .createIRI("http://myopenlink.net/dataspace/person/kidehen");
            BNode snode = repository.getValueFactory().createBNode("kidehenNode");
            IRI name = repository.getValueFactory().createIRI("http://myopenlink.net/foaf/name");
            Literal nameValue = repository.getValueFactory().createLiteral("Kingsley Idehen");

            con.clear(context);
            log("Loading single triple");
            con.add(snode, name, nameValue, context);
            String query = "SELECT * FROM <" + context + "> WHERE {?s ?p ?o} LIMIT 1";
            results = doTupleQuery(con, query);
            assertTrue((results.length > 0), "ResultSet is EMPTY");

            log("Casted value type");
            assertTrue(results[0][0] instanceof BNode, "Col1 must be BNode");
            assertTrue(results[0][1] instanceof IRI, "Col2 must be IRI");
            assertTrue(results[0][2] instanceof Literal, "Col3 must be BNode");


            log("Selecting property");
            query = "SELECT * FROM <" + context + "> WHERE {?s <http://myopenlink.net/foaf/name> ?o} LIMIT 1";
            results = doTupleQuery(con, query);
            assertTrue((results.length > 0), "ResultSet is EMPTY");


            boolean exists;
            con.add(kingsleyidehen, name, nameValue, context);
            exists = con.hasStatement(kingsleyidehen, name, null, false, context);
            assertTrue(exists, "Statement wasn't added");
            // test remove a statement
            con.remove(kingsleyidehen, name, nameValue, context);
            // test statement removed
            exists = con.hasStatement(kingsleyidehen, name, null, false, context);
            assertFalse(exists, "Statement wasn't removed");


            log("Statement exists (by result set size)");
            con.add(kingsleyidehen, name, nameValue, context);
            exists = con.hasStatement(kingsleyidehen, name, null, false, context);
            assertTrue(exists, "Statement wasn't added");
            query = "SELECT * FROM <" + context + "> WHERE {?s <http://myopenlink.net/foaf/name> ?o} LIMIT 1";
            results = doTupleQuery(con, query);
            assertTrue((results.length > 0), "ResultSet is EMPTY");


            RepositoryResult<Statement> statements;
            // test getStatements and RepositoryResult implementation
            log("Retrieving statement (" + kingsleyidehen + " " + name + " " + null + ")");
            statements = con.getStatements(kingsleyidehen, name, null, false, context);
            assertTrue(statements.hasNext(), "ResultSet is EMPTY");
//            while (statements.hasNext()) {
//                Statement st = statements.next();
//                System.out.println("Statement found: (" + st.getSubject() + " " + st.getPredicate() + " " + st.getObject() + ")");
//            }


            // test export and handlers
            File f = File.createTempFile("results.n3", "txt");
            f.deleteOnExit();
            log("Writing the statements to file: (" + f.getAbsolutePath() + ")");
            RDFHandler ntw = new NTriplesWriter(new FileOutputStream(f));
            con.exportStatements(kingsleyidehen, name, null, false, ntw);
            assertTrue(f.exists(), "File " + f.getAbsolutePath() + " wasn't created");


            RepositoryResult<Resource> contexts;
            // test retrieve graph ids
            log("Retrieving graph ids");
            contexts = con.getContextIDs();
            assertTrue(contexts.hasNext(), "contexts list is EMPTY");
            while (contexts.hasNext()) {
                Value id = contexts.next();
                if ((id instanceof Literal))
                    log("Literal value for graphid found: (" + ((Literal) id).getLabel() + ")");
            }

            // test get size
            log("Retrieving triple store size");
            long sz = con.size(context);
            assertTrue((sz > 0), "Graph size must be > 0");

            // do ask
            boolean result;
            log("Sending ask query");
            query = "ASK FROM <" + context + "> {?s <http://myopenlink.net/foaf/name> ?o}";
            result = doBooleanQuery(con, query);
            assertTrue(result, " ASK must return TRUE");

            // do construct
            Model g;
            boolean statementFound;
            log("Sending construct query");
            query = "CONSTRUCT {?s <http://myopenlink.net/mlo/handle> ?o} FROM <" + context +
                    "> WHERE {?s <http://myopenlink.net/foaf/name> ?o}";
            g = doGraphQuery(con, query);
            Iterator<Statement> it = g.iterator();
            statementFound = true;
            while (it.hasNext()) {
                Statement st = it.next();
                if (!st.getPredicate().stringValue().equals("http://myopenlink.net/mlo/handle"))
                    statementFound = false;
            }
            assertTrue((g.size() > 0), "CONSTRUCT return EMPTY graph");
            assertTrue(statementFound);

            // do describe
            log("Sending describe query");
            query = "DESCRIBE ?s FROM <" + context + "> WHERE {?s <http://myopenlink.net/foaf/name> ?o}";
            g = doGraphQuery(con, query);
            Iterator<Statement> it1 = g.iterator();
            statementFound = it1.hasNext();
            assertTrue(statementFound, "DESCRIBE returns EMPTY resultSet");


        } finally {
            if (con != null)
                con.close();
        }
    }


    @Test
    public void test6() {
        RepositoryConnection con = null;
        try {
            // test add data to the repository
            IRI context = repository.getValueFactory().createIRI(ctx);

            con = repository.getConnection();

            // test getNamespace
            Namespace testns = null;
            RepositoryResult<Namespace> namespaces;

            namespaces = con.getNamespaces();
            while (namespaces.hasNext()) {
                // LOG("Namespace found: (" + ns.getName() + " " + ns.getPrefix() + ")");
                testns = namespaces.next();
            }


            // test getNamespaces and RepositoryResult implementation
            log("Retrieving namespaces");
            if (testns != null) {
                // LOG("Retrieving namespace (" + testns.getName() + " " + testns.getPrefix() + ")");
                String ns = con.getNamespace(testns.getPrefix());
                assertNotNull(ns, "con.getNamespace('" + testns.getPrefix() + "') doesn't return Namespace");
            }
        } finally {
            if (con != null)
                con.close();
        }
    }


    private static boolean doBooleanQuery(RepositoryConnection con, String query) throws RepositoryException,
            MalformedQueryException, QueryEvaluationException {
        BooleanQuery resultsTable = con.prepareBooleanQuery(QueryLanguage.SPARQL, query);
        return resultsTable.evaluate();
    }

    private static Value[][] doTupleQuery(RepositoryConnection con, String query) throws RepositoryException,
            MalformedQueryException, QueryEvaluationException {
        return doTupleQuery(con, query, new HashMap<>());
    }

    private static Value[][] doTupleQuery(RepositoryConnection con, String query, HashMap<String, Value> bind) throws
            RepositoryException, MalformedQueryException, QueryEvaluationException {
        TupleQuery resultsTable = con.prepareTupleQuery(QueryLanguage.SPARQL, query);
        Set<String> keys = bind.keySet();
        for (String bindName : keys) {
            resultsTable.setBinding(bindName, bind.get(bindName));
        }
        TupleQueryResult bindings = resultsTable.evaluate();
        Vector<Value[]> results = new Vector<>();
        while (bindings.hasNext()) {
            // System.out.println("RESULT " + (row + 1) + ": ");
            BindingSet pairs = bindings.next();

            List<String> names = bindings.getBindingNames();
            Value[] rv = new Value[names.size()];
            for (int i = 0; i < names.size(); i++) {
                String name = names.get(i);
                Value value = pairs.getValue(name);
                rv[i] = value;
            }
            results.add(rv);
        }
        return results.toArray(new Value[0][0]);
    }

    private static Model doGraphQuery(RepositoryConnection con, String query) throws RepositoryException,
            MalformedQueryException, QueryEvaluationException {
        GraphQuery resultsTable = con.prepareGraphQuery(QueryLanguage.SPARQL, query);
        GraphQueryResult statements = resultsTable.evaluate();
        Model model = new LinkedHashModel();

        while (statements.hasNext()) {
            Statement pairs = statements.next();
            model.add(pairs);
//			List<String> names = statements.getBindingNames();
//			Value[] rv = new Value[names.size()];
//			for (int i = 0; i < names.size(); i++) {
//				String name = names.get(i);
//				Value value = pairs.getValue(name);
//				rv[i] = value;
//			}
//			results.add(rv);
        }
//		return (Value[][]) results.toArray(new Value[0][0]);
        return model;
    }

    @Test
    void testMpp() {
        try (final RepositoryConnection connection = repository.getConnection()) {
            final TupleQuery tq = connection.prepareTupleQuery("SELECT * WHERE { ?x a <http://www.w3.org/2004/02/skos/core#Concept> . }");
            final TupleQueryResult result = tq.evaluate();
            final List<BindingSet> resultList = Iterations.asList(result);
            assertFalse(resultList.isEmpty());
            assertEquals(67, resultList.size());
        }
    }
}

