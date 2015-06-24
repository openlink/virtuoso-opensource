/*
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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
import com.hp.hpl.jena.graph.NodeFactory;
import com.hp.hpl.jena.query.*;
import com.hp.hpl.jena.rdf.model.*;
import com.hp.hpl.jena.rdf.model.ResourceFactory;
import com.hp.hpl.jena.util.FileManager;
import com.hp.hpl.jena.util.iterator.*;
import com.hp.hpl.jena.graph.*;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.*;
import com.hp.hpl.jena.sparql.core.DatasetGraph ;
import virtuoso.jena.driver.VirtGraph;
import virtuoso.jena.driver.VirtModel;

public class Test_BNode {

    public static final String VIRTUOSO_INSTANCE = "localhost";
    public static final int VIRTUOSO_PORT = 1111;
    public static final String VIRTUOSO_USERNAME = "dba";
    public static final String VIRTUOSO_PASSWORD = "dba";


    static int g_PASSED = 0;
    static int g_FAILED = 0;
    static int g_testCounter = 0;

    static int PASSED = 0;
    static int FAILED = 0;
    static int testCounter = 0;

    public static void resetTests() {
        PASSED = 0;
        FAILED = 0;
        testCounter = 0;
    }

    public static void startTest(String id) {
        testCounter++;
        System.out.println("== TEST " + id + ": " + " : Start");
    }

    public static void endTest(String id, boolean OK) {
        System.out.println("== TEST " + id + ": " + " : End");
        System.out.println((OK ? "PASSED:" : "***FAILED:") + " TEST " + id + "\n");
        if (OK) PASSED++;
        else FAILED++;
    }

    public static void getTestTotal() {
        System.out.println("============================");
        System.out.println("PASSED:" + PASSED + " FAILED:" + FAILED);
        g_PASSED += PASSED;
        g_FAILED += FAILED;
        g_testCounter += testCounter;
        resetTests();
    }

    public static void getTotal() {
        System.out.println("\n=======TOTAL===================");
        System.out.println("PASSED:" + g_PASSED + " FAILED:" + g_FAILED);
    }

    public static void log(String mess) {
        System.out.println("   " + mess);
    }

    public static void main(String[] args) {
        Test_OneRow(args, false);
        Test_OneRow(args, true);

        Test_Batch(args, false);
        Test_Batch(args, true);

        Test_Batch_Model(args, false);
        Test_Batch_Model(args, true);

        Test_ImportFromFile(args, false);
        Test_ImportFromFile(args, true);

        getTotal();
    }


    public static void Test_OneRow(String[] args, boolean insertBNodeAsIRI) {

        String[] sa = new String[4];
        sa[0] = VIRTUOSO_INSTANCE;
        sa[1] = VIRTUOSO_PORT + "";
        sa[2] = VIRTUOSO_USERNAME;
        sa[3] = VIRTUOSO_PASSWORD;
        for (int i = 0; i < sa.length && i < args.length; i++) {
            sa[i] = args[i];
        }
        VirtGraph vg = new VirtGraph("test:jbnode", "jdbc:virtuoso://" + sa[0] + ":" + sa[1], sa[2], sa[3]);
        vg.setInsertBNodeAsVirtuosoIRI(insertBNodeAsIRI);

        try {
            boolean ok = true;
            String query = null;
            ExtendedIterator<Triple> rs;
            Triple t;

            vg.clear();

            // Data for one row operation
            Node bn1 = NodeFactory.createAnon(); //"a1");
            Node bn2 = NodeFactory.createAnon();//"a2");
            Node ns1 = NodeFactory.createURI("t:s1");
            Node np = NodeFactory.createURI("t:p");
            Node no = NodeFactory.createURI("t:o1");

            System.out.println("\n\n++++++++++++++++++++++++++++++++++++++++++++++++++++++++");
            if (insertBNodeAsIRI)
                System.out.println("Test with One Row operation (BNode as IRI)");
            else
                System.out.println("Test with One Row operation (BNode as Virtuoso Native BNode)");
            System.out.println("++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");

            startTest("1"); ok = true;
            try
            {
                log("Insert data with BNodes");

                vg.add(new Triple(ns1, np, bn1));
                vg.add(new Triple(bn2, np, no));

                log("Inserted data:");
                log("-----------------");
                rs = vg.find(Triple.createMatch(null, null, null));
                while(rs.hasNext()) {
                    log(rs.next().toString());
                }
                log("-----------------");
                rs.close();


                rs = vg.find(ns1, np, null);
                if (!rs.hasNext())
                    throw new Exception("ResultSet is empty");
                t = rs.next();
                Node o = t.getObject();
                if (!o.isBlank())
                    throw new Exception("Value must be BNode");
                bn1 = o;
                log("Got bn1="+bn1);

                rs = vg.find(null, np, no);
                if (!rs.hasNext())
                    throw new Exception("ResultSet is empty");
                t = rs.next();
                o = t.getSubject();
                if (!o.isBlank())
                    throw new Exception("Value must be BNode");
                bn2 = o;
                log("Got bn2="+bn2);

                if (bn1.equals(bn2))
                    throw new Exception("Error bn1 == bn2");

            } catch (Exception e) {
                log("***FAILED Test " + e);
                ok = false;
            }
            endTest("1", ok);


            startTest("2"); ok = true;
            try
            {
                log("Try hasStatement with BNodes");
                boolean rc;

                rc = vg.contains(ns1, np, bn1);
                if (!rc)
                    throw new Exception("hasStatement return FALSE for bn1");
                log("hasStatement with bn1 OK");

                rc = vg.contains(bn2, np, no);
                if (!rc)
                    throw new Exception("hasStatement return FALSE for bn2");
                log("hasStatement with bn2 OK");

            } catch (Exception e) {
                log("***FAILED Test "+e);
                ok = false;
            }
            endTest("2",ok);


            startTest("3"); ok = true;
            try
            {
                log("Try getStatements with BNodes");

                rs = vg.find(ns1, np, bn1);
                if (!rs.hasNext())
                    throw new Exception("ResultSet is empty");
                t = rs.next();
                if (!t.getSubject().equals(ns1))
                    throw new Exception("Subject must be :"+ns1);
                if (!t.getPredicate().equals(np))
                    throw new Exception("Predicate must be :"+np);
                if (!t.getObject().equals(bn1))
                    throw new Exception("Subject must be :"+bn1);
                log("getStatements with bn1 OK");


                rs = vg.find(bn2, np, no);
                if (!rs.hasNext())
                    throw new Exception("ResultSet is empty");
                t = rs.next();
                if (!t.getSubject().equals(bn2))
                    throw new Exception("Subject must be :"+ns1);
                if (!t.getPredicate().equals(np))
                    throw new Exception("Predicate must be :"+np);
                if (!t.getObject().equals(no))
                    throw new Exception("Subject must be :"+no);
                log("getStatements with bn2 OK");

            } catch (Exception e) {
                log("***FAILED Test "+e);
                ok = false;
            }
            endTest("3", ok);


            startTest("4"); ok = true;
            try
            {
                boolean rc;
                log("Try remove with BNodes");

                vg.remove(ns1, np, bn1);

                log("After remove triple:");
                log("-----------------");
                rs = vg.find(null, null, null);
                while (rs.hasNext()) {
                    log(rs.next().toString());
                }
                log("-----------------");
                rs.close();

                rc = vg.contains(ns1, np, bn1);
                if (rc)
                    throw new Exception("Triple with bn1 wasn't removed");
                log("remove with bn1 OK");


                vg.remove(bn2, np, no);

                log("After remove triple:");
                log("-----------------");
                rs = vg.find(null, null, null);
                while (rs.hasNext()) {
                    log(rs.next().toString());
                }
                log("-----------------");
                rs.close();

                rc = vg.contains(bn2, np, no);
                if (rc)
                    throw new Exception("Triple with bn2 wasn't removed");
                log("remove with bn2 OK");


            } catch (Exception e) {
                log("***FAILED Test "+e);
                ok = false;
            }
            endTest("4", ok);


            if (!insertBNodeAsIRI) {
                startTest("5"); ok = true;
                try
                {
                    log("Insert data with BNode bn1 again (new BNode ID must be assigned)");

                    vg.add(new Triple(ns1, np, bn1));

                    log("Inserted data:");
                    log("-----------------");
                    rs = vg.find(null, null, null);
                    while (rs.hasNext()) {
                        log(rs.next().toString());
                    }
                    log("-----------------");
                    rs.close();


                    rs = vg.find(ns1, np, null);
                    if (!rs.hasNext())
                        throw new Exception("ResultSet is empty");
                    t = rs.next();
                    Node o = t.getObject();
                    if (!o.isBlank())
                        throw new Exception("Value must be BNode");
                    Node bnew = o;
                    log("Got bnew="+bnew);

                    if (bn1.equals(bnew))
                        throw new Exception("Error bn1 == bnew");

                } catch (Exception e) {
                    log("***FAILED Test "+e);
                    ok = false;
                }
                endTest("5", ok);
            }


            getTestTotal();

        }catch (Exception e){
            System.out.println("ERROR Test Failed.");
            e.printStackTrace();
        }
        finally {
            try {
                vg.close();
            }
            catch (Exception e) {}
        }
    }


    public static void Test_Batch(String[] args, boolean insertBNodeAsIRI) {
        String[] sa = new String[4];
        sa[0] = VIRTUOSO_INSTANCE;
        sa[1] = VIRTUOSO_PORT + "";
        sa[2] = VIRTUOSO_USERNAME;
        sa[3] = VIRTUOSO_PASSWORD;
        for (int i = 0; i < sa.length && i < args.length; i++) {
            sa[i] = args[i];
        }
        VirtGraph vg = new VirtGraph("test:jbnode", "jdbc:virtuoso://" + sa[0] + ":" + sa[1], sa[2], sa[3]);
        vg.setInsertBNodeAsVirtuosoIRI(insertBNodeAsIRI);

        try {
            boolean ok = true;
            String query = null;
            ExtendedIterator<Triple> rs;
            Triple t;

            vg.clear();

            // Data for batch operation
            Node ba = NodeFactory.createAnon();//"a");
            Node bb = NodeFactory.createAnon();//"b");
            Node np1 = NodeFactory.createURI("t:p1");
            Node np2 = NodeFactory.createURI("t:p2");
            Node np3 = NodeFactory.createURI("t:p3");
            Node no1 = NodeFactory.createURI("t:o1");
            Node no3 = NodeFactory.createURI("t:o3");
/**************
 Try batch insert :

 _:a  t:p1 t:o1
 _:a  t:p2 _:b
 _:b  t:p3 t:o3

 ***************/
            System.out.println("\n\n++++++++++++++++++++++++++++++++++++++++++++++++++++++++");
            if (insertBNodeAsIRI)
                System.out.println("Test with Batch Operation (BNode as IRI)");
            else
                System.out.println("Test with Batch Operation (BNode as Virtuoso Native BNode)");
            System.out.println("++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");

            startTest("1"); ok = true;
            try
            {
                log("Insert data with BNodes");

                ArrayList<Triple> arr = new ArrayList<Triple>();
                arr.add(new Triple(ba, np1, no1));
                arr.add(new Triple(ba, np2, bb));
                arr.add(new Triple(bb, np3, no3));

                BulkUpdateHandler bu = vg.getBulkUpdateHandler();
                bu.add(arr);

                log("Inserted data:");
                log("-----------------");
                rs = vg.find(null, null, null);
                while (rs.hasNext()) {
                    log(rs.next().toString());
                }
                log("-----------------");
                rs.close();

                rs = vg.find(null, np1, no1);
                if (!rs.hasNext())
                    throw new Exception("ResultSet is empty");
                t = rs.next();
                Node o = t.getSubject();
                if (!o.isBlank())
                    throw new Exception("Value must be BNode");
                ba = o;
                log("Got ba="+ba);

                rs = vg.find(null, np3, no3);
                if (!rs.hasNext())
                    throw new Exception("ResultSet is empty");
                t = rs.next();
                o = t.getSubject();
                if (!o.isBlank())
                    throw new Exception("Value must be BNode");
                bb = o;
                log("Got bb="+bb);

                if (ba.equals(bb))
                    throw new Exception("Error ba == bb");

            } catch (Exception e) {
                log("***FAILED Test "+e);
                ok = false;
            }
            endTest("1", ok);


            startTest("2"); ok = true;
            try
            {
                log("Try hasStatement with BNodes");
                boolean rc;

                rc = vg.contains(ba, np1, no1);
                if (!rc)
                    throw new Exception("hasStatement return FALSE for ba");
                log("hasStatement with ba OK");

                rc = vg.contains(ba, np2, bb);
                if (!rc)
                    throw new Exception("hasStatement return FALSE for ba & bb");
                log("hasStatement with ba & bb OK");

                rc = vg.contains(bb, np3, no3);
                if (!rc)
                    throw new Exception("hasStatement return FALSE for bb");
                log("hasStatement with ba OK");

            } catch (Exception e) {
                log("***FAILED Test "+e);
                ok = false;
            }
            endTest("2", ok);


            startTest("3"); ok = true;
            try
            {
                log("Try getStatements with BNodes");

                rs = vg.find(ba, np1, no1);
                if (!rs.hasNext())
                    throw new Exception("ResultSet is empty");
                t = rs.next();
                if (!t.getSubject().equals(ba))
                    throw new Exception("Subject must be :"+ba);
                if (!t.getPredicate().equals(np1))
                    throw new Exception("Predicate must be :"+np1);
                if (!t.getObject().equals(no1))
                    throw new Exception("Subject must be :"+no1);
                log("getStatements with ba OK");


                rs = vg.find(ba, np2, bb);
                if (!rs.hasNext())
                    throw new Exception("ResultSet is empty");
                t = rs.next();
                if (!t.getSubject().equals(ba))
                    throw new Exception("Subject must be :"+ba);
                if (!t.getPredicate().equals(np2))
                    throw new Exception("Predicate must be :"+np2);
                if (!t.getObject().equals(bb))
                    throw new Exception("Subject must be :"+bb);
                log("getStatements with ba & bb OK");

                rs = vg.find(bb, np3, no3);
                if (!rs.hasNext())
                    throw new Exception("ResultSet is empty");
                t = rs.next();
                if (!t.getSubject().equals(bb))
                    throw new Exception("Subject must be :"+bb);
                if (!t.getPredicate().equals(np3))
                    throw new Exception("Predicate must be :"+np3);
                if (!t.getObject().equals(no3))
                    throw new Exception("Subject must be :"+no3);
                log("getStatements with bn2 OK");

            } catch (Exception e) {
                log("***FAILED Test "+e);
                ok = false;
            }
            endTest("3", ok);


            startTest("4"); ok = true;
            try
            {
                boolean rc;
                log("Try remove with BNodes");

                ArrayList<Triple> arr = new ArrayList<Triple>();
                arr.add(new Triple(ba, np1, no1));
                arr.add(new Triple(ba, np2, bb));

                BulkUpdateHandler bu = vg.getBulkUpdateHandler();
                bu.delete(arr);

                log("After remove 2 triple:");
                log("-----------------");
                rs = vg.find(null, null, null);
                while (rs.hasNext()) {
                    log(rs.next().toString());
                }
                log("-----------------");
                rs.close();

                rc = vg.contains(ba, np1, no1);
                if (rc)
                    throw new Exception("Triple with ba wasn't removed");
                log("remove with ba OK");

                rc = vg.contains(ba, np2, bb);
                if (rc)
                    throw new Exception("Triple with ba & bb wasn't removed");
                log("remove with ba & bb OK");


                arr = new ArrayList<Triple>();
                arr.add(new Triple(bb, np3, no3));


                bu.delete(arr);

                log("After remove triple:");
                log("-----------------");
                rs = vg.find(null, null, null);
                while (rs.hasNext()) {
                    log(rs.next().toString());
                }
                log("-----------------");
                rs.close();

                rc = vg.contains(bb, np3, no3);
                if (rc)
                    throw new Exception("Triple with bb wasn't removed");
                log("remove with bb OK");


            } catch (Exception e) {
                log("***FAILED Test "+e);
                ok = false;
            }
            endTest("4", ok);


            getTestTotal();
        }catch (Exception e){
            System.out.println("ERROR Test Failed.");
            e.printStackTrace();
        }
        finally {
            try {
                vg.close();
            }
            catch (Exception e) {}
        }
    }



    public static void Test_Batch_Model(String[] args, boolean insertBNodeAsIRI) {
        String[] sa = new String[4];
        sa[0] = VIRTUOSO_INSTANCE;
        sa[1] = VIRTUOSO_PORT + "";
        sa[2] = VIRTUOSO_USERNAME;
        sa[3] = VIRTUOSO_PASSWORD;
        for (int i = 0; i < sa.length && i < args.length; i++) {
            sa[i] = args[i];
        }

        VirtModel vm = VirtModel.openDatabaseModel("test:jbnode", "jdbc:virtuoso://" + sa[0] + ":" + sa[1], sa[2], sa[3]);
        vm.setInsertBNodeAsVirtuosoIRI(insertBNodeAsIRI);

        try {
            boolean ok = true;
            StmtIterator rs;
            Statement st;

            vm.removeAll();

            // Data for batch operation
            Resource ba = ResourceFactory.createResource();
            Resource bb = ResourceFactory.createResource();
            Property np1 = ResourceFactory.createProperty("t:p1");
            Property np2 = ResourceFactory.createProperty("t:p2");
            Property np3 = ResourceFactory.createProperty("t:p3");
            RDFNode no1 = ResourceFactory.createResource("t:o1");
            RDFNode no3 = ResourceFactory.createResource("t:o3");

/**************
 Try batch insert :

 _:a  t:p1 t:o1
 _:a  t:p2 _:b
 _:b  t:p3 t:o3

 ***************/
            System.out.println("\n\n++++++++++++++++++++++++++++++++++++++++++++++++++++++++");
            if (insertBNodeAsIRI)
                System.out.println("Test with Batch Operation (BNode as IRI)");
            else
                System.out.println("Test with Batch Operation (BNode as Virtuoso Native BNode)");
            System.out.println("++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");

            startTest("1"); ok = true;
            try
            {
                log("Insert data with BNodes");

                ArrayList<Statement> arr = new ArrayList<Statement>();
                arr.add(ResourceFactory.createStatement(ba, np1, no1));
                arr.add(ResourceFactory.createStatement(ba, np2, bb));
                arr.add(ResourceFactory.createStatement(bb, np3, no3));

                vm.add(arr);

                log("Inserted data:");
                log("-----------------");
                rs = vm.listStatements();
                while (rs.hasNext()) {
                    log(rs.next().toString());
                }
                log("-----------------");
                rs.close();

                rs = vm.listStatements(null, np1, no1);
                if (!rs.hasNext())
                    throw new Exception("ResultSet is empty");
                st = rs.next();
                Resource o = st.getSubject();
                if (!o.isAnon())
                    throw new Exception("Value must be BNode");
                ba = o;
                log("Got ba="+ba);

                rs = vm.listStatements(null, np3, no3);
                if (!rs.hasNext())
                    throw new Exception("ResultSet is empty");
                st = rs.next();
                o = st.getSubject();
                if (!o.isAnon())
                    throw new Exception("Value must be BNode");
                bb = o;
                log("Got bb="+bb);

                if (ba.equals(bb))
                    throw new Exception("Error ba == bb");

            } catch (Exception e) {
                log("***FAILED Test "+e);
                ok = false;
            }
            endTest("1", ok);


            startTest("2"); ok = true;
            try
            {
                log("Try hasStatement with BNodes");
                boolean rc;

                rc = vm.contains(ba, np1, no1);
                if (!rc)
                    throw new Exception("hasStatement return FALSE for ba");
                log("hasStatement with ba OK");

                rc = vm.contains(ba, np2, bb);
                if (!rc)
                    throw new Exception("hasStatement return FALSE for ba & bb");
                log("hasStatement with ba & bb OK");

                rc = vm.contains(bb, np3, no3);
                if (!rc)
                    throw new Exception("hasStatement return FALSE for bb");
                log("hasStatement with ba OK");

            } catch (Exception e) {
                log("***FAILED Test "+e);
                ok = false;
            }
            endTest("2", ok);


            startTest("3"); ok = true;
            try
            {
                log("Try getStatements with BNodes");

                rs = vm.listStatements(ba, np1, no1);
                if (!rs.hasNext())
                    throw new Exception("ResultSet is empty");
                st = rs.next();
                if (!st.getSubject().equals(ba))
                    throw new Exception("Subject must be :"+ba);
                if (!st.getPredicate().equals(np1))
                    throw new Exception("Predicate must be :"+np1);
                if (!st.getObject().equals(no1))
                    throw new Exception("Subject must be :"+no1);
                log("getStatements with ba OK");


                rs = vm.listStatements(ba, np2, bb);
                if (!rs.hasNext())
                    throw new Exception("ResultSet is empty");
                st = rs.next();
                if (!st.getSubject().equals(ba))
                    throw new Exception("Subject must be :"+ba);
                if (!st.getPredicate().equals(np2))
                    throw new Exception("Predicate must be :"+np2);
                if (!st.getObject().equals(bb))
                    throw new Exception("Subject must be :"+bb);
                log("getStatements with ba & bb OK");

                rs = vm.listStatements(bb, np3, no3);
                if (!rs.hasNext())
                    throw new Exception("ResultSet is empty");
                st = rs.next();
                if (!st.getSubject().equals(bb))
                    throw new Exception("Subject must be :"+bb);
                if (!st.getPredicate().equals(np3))
                    throw new Exception("Predicate must be :"+np3);
                if (!st.getObject().equals(no3))
                    throw new Exception("Subject must be :"+no3);
                log("getStatements with bn2 OK");

            } catch (Exception e) {
                log("***FAILED Test "+e);
                ok = false;
            }
            endTest("3", ok);


            startTest("4"); ok = true;
            try
            {
                boolean rc;
                log("Try remove with BNodes");

                ArrayList<Statement> arr = new ArrayList<Statement>();
                arr.add(ResourceFactory.createStatement(ba, np1, no1));
                arr.add(ResourceFactory.createStatement(ba, np2, bb));

                vm.remove(arr);

                log("After remove 2 triple:");
                log("-----------------");
                rs = vm.listStatements();
                while (rs.hasNext()) {
                    log(rs.next().toString());
                }
                log("-----------------");
                rs.close();

                rc = vm.contains(ba, np1, no1);
                if (rc)
                    throw new Exception("Triple with ba wasn't removed");
                log("remove with ba OK");

                rc = vm.contains(ba, np2, bb);
                if (rc)
                    throw new Exception("Triple with ba & bb wasn't removed");
                log("remove with ba & bb OK");


                arr = new ArrayList<Statement>();
                arr.add(ResourceFactory.createStatement(bb, np3, no3));


                vm.remove(arr);

                log("After remove triple:");
                log("-----------------");
                rs = vm.listStatements();
                while (rs.hasNext()) {
                    log(rs.next().toString());
                }
                log("-----------------");
                rs.close();

                rc = vm.contains(bb, np3, no3);
                if (rc)
                    throw new Exception("Triple with bb wasn't removed");
                log("remove with bb OK");


            } catch (Exception e) {
                log("***FAILED Test "+e);
                ok = false;
            }
            endTest("4", ok);


            getTestTotal();
        }catch (Exception e){
            System.out.println("ERROR Test Failed.");
            e.printStackTrace();
        }
        finally {
            try {
                vm.close();
            }
            catch (Exception e) {}
        }
    }


    public static void Test_ImportFromFile(String[] args, boolean insertBNodeAsIRI) {
        String[] sa = new String[4];
        sa[0] = VIRTUOSO_INSTANCE;
        sa[1] = VIRTUOSO_PORT + "";
        sa[2] = VIRTUOSO_USERNAME;
        sa[3] = VIRTUOSO_PASSWORD;
        for (int i = 0; i < sa.length && i < args.length; i++) {
            sa[i] = args[i];
        }

        VirtModel vm = VirtModel.openDatabaseModel("test:jbnode", "jdbc:virtuoso://" + sa[0] + ":" + sa[1], sa[2], sa[3]);
        vm.setInsertBNodeAsVirtuosoIRI(insertBNodeAsIRI);

        try {
            boolean ok = true;
            StmtIterator rs;
            Statement st;

            vm.removeAll();

            Resource ns = ResourceFactory.createResource("http://localhost/publications/journals/Journal3/1967");
            Property np = ResourceFactory.createProperty("http://swrc.ontoware.org/ontology#editor");
            Property np1 = ResourceFactory.createProperty("http://xmlns.com/foaf/0.1/name");


            System.out.println("\n\n++++++++++++++++++++++++++++++++++++++++++++++++++++++++");
            if (insertBNodeAsIRI)
                System.out.println("Test Import data from File (BNode as IRI)");
            else
                System.out.println("Test Import data from File (BNode as Virtuoso Native BNode)");
            System.out.println("++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");


            startTest("1"); ok = true;
            try
            {
                log("Insert data with BNodes from file sp2b.n3");
                String nfile = "sp2b.n3";

                InputStream in = FileManager.get().open(nfile);
                if (in == null) {
                    throw new IllegalArgumentException( "File: " + nfile + " not found");
                }
                vm.read(new InputStreamReader(in), null, "N3");

                long count = vm.size();
                log("Inserted :"+count+" triples");

            } catch (Exception e) {
                log("***FAILED Test "+e);
                ok = false;
            }
            endTest("1", ok);

            startTest("2"); ok = true;
            try
            {
                log("Try getStatements with BNodes");

                rs = vm.listStatements(ns, np, (RDFNode)null);
                if (!rs.hasNext())
                    throw new Exception("ResultSet is empty");
                st = rs.next();
                if (!st.getSubject().equals(ns))
                    throw new Exception("Subject must be :"+ns);
                if (!st.getPredicate().equals(np))
                    throw new Exception("Predicate must be :"+np);

                RDFNode[] bn_arr = new RDFNode[3];
                bn_arr[0] = st.getObject();
                if (!rs.hasNext())
                    throw new Exception("ResultSet have not 2 row");

                st = rs.next();
                bn_arr[1] = st.getObject();
                if (!rs.hasNext())
                    throw new Exception("ResultSet have not 3 row");

                st = rs.next();
                bn_arr[2] = st.getObject();
                rs.close();

                log("BNodes loaded OK");
                HashSet<String> data = new HashSet<String>();
                data.add("Rajab Sikora");
                data.add("Yukari Pitcairn");
                data.add("Reyes Kluesner");
                RDFNode o_val;
                Literal l_val;
                String s_val;

                rs = vm.listStatements((Resource)bn_arr[0], np1, (RDFNode)null);
                if (!rs.hasNext())
                    throw new Exception("ResultSet is empty");
                st = rs.next();
                log("Got =["+st.getObject()+"]\n for BNode:"+bn_arr[0]+"\n");
                o_val = st.getObject();
                if (!o_val.isLiteral())
                    throw new Exception(""+o_val+" Must be literal");
                l_val = (Literal)o_val;
                if (!data.contains(l_val.getString()))
                    throw new Exception("Wrong data was received ="+o_val);
                data.remove(l_val.getString());
                rs.close();

                rs = vm.listStatements((Resource)bn_arr[1], np1, (RDFNode)null);
                if (!rs.hasNext())
                    throw new Exception("ResultSet is empty");
                st = rs.next();
                log("Got =["+st.getObject()+"]\n for BNode:"+bn_arr[1]+"\n");
                o_val = st.getObject();
                if (!o_val.isLiteral())
                    throw new Exception(""+o_val+" Must be literal");
                l_val = (Literal)o_val;
                if (!data.contains(l_val.getString()))
                    throw new Exception("Wrong data was received ="+o_val);
                data.remove(l_val.getString());
                rs.close();

                rs = vm.listStatements((Resource)bn_arr[2], np1, (RDFNode)null);
                if (!rs.hasNext())
                    throw new Exception("ResultSet is empty");
                st = rs.next();
                log("Got =["+st.getObject()+"]\n for BNode:"+bn_arr[2]+"\n");
                o_val = st.getObject();
                if (!o_val.isLiteral())
                    throw new Exception(""+o_val+" Must be literal");
                l_val = (Literal)o_val;
                if (!data.contains(l_val.getString()))
                    throw new Exception("Wrong data was received ="+o_val);
                data.remove(l_val.getString());
                rs.close();

            } catch (Exception e) {
                log("***FAILED Test "+e);
                ok = false;
            }
            endTest("2", ok);


            getTestTotal();
        }catch (Exception e){
            System.out.println("ERROR Test Failed.");
            e.printStackTrace();
        }
        finally {
            try {
                vm.close();
            }
            catch (Exception e) {}
        }
    }


 }
