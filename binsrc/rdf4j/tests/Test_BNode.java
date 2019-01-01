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

import java.io.File;
import java.io.FileOutputStream;
import java.net.URL;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.util.*;

import org.eclipse.rdf4j.model.*;
import org.eclipse.rdf4j.model.impl.GraphImpl;
import org.eclipse.rdf4j.query.BindingSet;
import org.eclipse.rdf4j.query.BooleanQuery;
import org.eclipse.rdf4j.query.GraphQuery;
import org.eclipse.rdf4j.query.GraphQueryResult;
import org.eclipse.rdf4j.query.MalformedQueryException;
import org.eclipse.rdf4j.query.QueryEvaluationException;
import org.eclipse.rdf4j.query.QueryLanguage;
import org.eclipse.rdf4j.query.TupleQuery;
import org.eclipse.rdf4j.query.TupleQueryResult;
import org.eclipse.rdf4j.repository.Repository;
import org.eclipse.rdf4j.repository.RepositoryConnection;
import org.eclipse.rdf4j.repository.RepositoryException;
import org.eclipse.rdf4j.repository.RepositoryResult;
import org.eclipse.rdf4j.rio.RDFFormat;
import org.eclipse.rdf4j.rio.RDFHandler;
import org.eclipse.rdf4j.rio.ntriples.NTriplesWriter;
import org.eclipse.rdf4j.model.impl.ContextStatementImpl;

import virtuoso.sesame4.driver.*;

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
        VirtuosoRepository repository = new VirtuosoRepository("jdbc:virtuoso://" + sa[0] + ":" + sa[1], sa[2], sa[3]);
        repository.setInsertBNodeAsVirtuosoIRI(insertBNodeAsIRI);

        RepositoryConnection con = null;
        try {                            
            con = repository.getConnection();
            con.setAutoCommit(true);

            // test add data to the repository
            boolean ok = true;
            String query = null;
            RepositoryResult<Statement> rs;
            Statement st;
            ValueFactory vfac = repository.getValueFactory();
            URI context = vfac.createURI("test:blank");

            con.clear(context);

            // Data for one row operation
            BNode bn1 = vfac.createBNode();//"a1");
            BNode bn2 = vfac.createBNode();//"a2");
            URI ns1 = repository.getValueFactory().createURI("t:s1");
            URI np = repository.getValueFactory().createURI("t:p");
            URI no = repository.getValueFactory().createURI("t:o1");

            System.out.println("\n\n++++++++++++++++++++++++++++++++++++++++++++++++++++++++");
            if (insertBNodeAsIRI)
              System.out.println("Test with One Row operation (BNode as Virtuoso IRI)");
            else
              System.out.println("Test with One Row operation (BNode as Virtuoso Native BNode)");
            System.out.println("++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");


            startTest("1"); ok = true;
            try
            {
              log("Insert data with BNodes");

 	      con.add(ns1, np, bn1, context);
 	      con.add(bn2, np, no, context);

 	      log("Inserted data:");
 	      log("-----------------");
              rs = con.getStatements(null, null, null, false, context);
              while (rs.hasNext()) {
                log(rs.next().toString());
              }
 	      log("-----------------");
 	      rs.close();


              rs = con.getStatements(ns1, np, null, false, context);
              if (!rs.hasNext())
                throw new Exception("ResultSet is empty");
              st = rs.next();
              Object o = st.getObject();
              if (!(o instanceof BNode))
                throw new Exception("Value must be BNode");
              bn1 = (BNode)o;
              log("Got bn1="+bn1);

              rs = con.getStatements(null, np, no, false, context);
              if (!rs.hasNext())
                throw new Exception("ResultSet is empty");
              st = rs.next();
              o = st.getSubject();
              if (!(o instanceof BNode))
                throw new Exception("Value must be BNode");
              bn2 = (BNode)o;
              log("Got bn2="+bn2);

              if (bn1.equals(bn2))
                throw new Exception("Error bn1 == bn2");

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

              rc = con.hasStatement(ns1, np, bn1, false, context);
              if (!rc)
                throw new Exception("hasStatement return FALSE for bn1");
              log("hasStatement with bn1 OK");

              rc = con.hasStatement(bn2, np, no, false, context);
              if (!rc)
                throw new Exception("hasStatement return FALSE for bn2");
              log("hasStatement with bn2 OK");

            } catch (Exception e) {
              log("***FAILED Test "+e);
              ok = false;
            }
            endTest("2", ok);


            startTest("3"); ok = true;
            try
            {
              log("Try getStatements with BNodes");

              rs = con.getStatements(ns1, np, bn1, false, context);
              if (!rs.hasNext())
                throw new Exception("ResultSet is empty");
              st = rs.next();
              if (!st.getSubject().equals(ns1))
                throw new Exception("Subject must be :"+ns1);
              if (!st.getPredicate().equals(np))
                throw new Exception("Predicate must be :"+np);
              if (!st.getObject().equals(bn1))
                throw new Exception("Subject must be :"+bn1);
              log("getStatements with bn1 OK");


              rs = con.getStatements(bn2, np, no, false, context);
              if (!rs.hasNext())
                throw new Exception("ResultSet is empty");
              st = rs.next();
              if (!st.getSubject().equals(bn2))
                throw new Exception("Subject must be :"+ns1);
              if (!st.getPredicate().equals(np))
                throw new Exception("Predicate must be :"+np);
              if (!st.getObject().equals(no))
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

              con.remove((Resource)ns1, np, bn1, context);

 	      log("After remove triple:");
 	      log("-----------------");
              rs = con.getStatements(null, null, null, false, context);
              while (rs.hasNext()) {
                log(rs.next().toString());
              }
 	      log("-----------------");
 	      rs.close();

              rc = con.hasStatement(ns1, np, bn1, false, context);
              if (rc)
                throw new Exception("Triple with bn1 wasn't removed");
              log("remove with bn1 OK");


              con.remove((Resource)bn2, np, no, context);

 	      log("After remove triple:");
 	      log("-----------------");
              rs = con.getStatements(null, null, null, false, context);
              while (rs.hasNext()) {
                log(rs.next().toString());
              }
 	      log("-----------------");
 	      rs.close();

              rc = con.hasStatement(bn2, np, no, false, context);
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

 	      con.add(ns1, np, bn1, context);

 	      log("Inserted data:");
 	      log("-----------------");
              rs = con.getStatements(null, null, null, false, context);
              while (rs.hasNext()) {
                log(rs.next().toString());
              }
 	      log("-----------------");
 	      rs.close();


              rs = con.getStatements(ns1, np, null, false, context);
              if (!rs.hasNext())
                throw new Exception("ResultSet is empty");
              st = rs.next();
              Object o = st.getObject();
              if (!(o instanceof BNode))
                throw new Exception("Value must be BNode");
              BNode bnew = (BNode)o;
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


    public static void Test_Batch(String[] args, boolean insertBNodeAsIRI) {

        String[] sa = new String[4];
        sa[0] = VIRTUOSO_INSTANCE;
        sa[1] = VIRTUOSO_PORT + "";
        sa[2] = VIRTUOSO_USERNAME;
        sa[3] = VIRTUOSO_PASSWORD;
        for (int i = 0; i < sa.length && i < args.length; i++) {
            sa[i] = args[i];
        }
        VirtuosoRepository repository = new VirtuosoRepository("jdbc:virtuoso://" + sa[0] + ":" + sa[1], sa[2], sa[3]);
        repository.setInsertBNodeAsVirtuosoIRI(insertBNodeAsIRI);

        RepositoryConnection con = null;
        try {
            con = repository.getConnection();
            con.setAutoCommit(true);

            // test add data to the repository
            boolean ok = true;
            String query = null;
            RepositoryResult<Statement> rs;
            Statement st;
            ValueFactory vfac = repository.getValueFactory();
            URI context = vfac.createURI("test:blank");

            con.clear(context);

            // Data for one row operation
            BNode ba = vfac.createBNode();//"a");
            BNode bb = vfac.createBNode();//"b");
            URI np1 = repository.getValueFactory().createURI("t:p1");
            URI np2 = repository.getValueFactory().createURI("t:p2");
            URI np3 = repository.getValueFactory().createURI("t:p3");
            URI no1 = repository.getValueFactory().createURI("t:o1");
            URI no3 = repository.getValueFactory().createURI("t:o3");
/**************
  Try batch insert :

  _:a  t:p1 t:o1
  _:a  t:p2 _:b
  _:b  t:p3 t:o3

***************/

            System.out.println("\n\n++++++++++++++++++++++++++++++++++++++++++++++++++++++++");
            if (insertBNodeAsIRI)
              System.out.println("Test with Batch Operation (BNode as Virtuoso IRI)");
            else
              System.out.println("Test with Batch Operation (BNode as Virtuoso Native BNode)");
            System.out.println("++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");


            startTest("1"); ok = true;
            try
            {
              log("Insert data with BNodes");

              ArrayList<Statement> arr = new ArrayList<>();
              arr.add(new ContextStatementImpl(ba, np1, no1,context));
              arr.add(new ContextStatementImpl(ba, np2, bb,context));
              arr.add(new ContextStatementImpl(bb, np3, no3,context));

 	      con.add(arr, context);

 	      log("Inserted data:");
 	      log("-----------------");
              rs = con.getStatements(null, null, null, false, context);
              while (rs.hasNext()) {
                log(rs.next().toString());
              }
 	      log("-----------------");
 	      rs.close();

              rs = con.getStatements(null, np1, no1, false, context);
              if (!rs.hasNext())
                throw new Exception("ResultSet is empty");
              st = rs.next();
              Object o = st.getSubject();
              if (!(o instanceof BNode))
                throw new Exception("Value must be BNode");
              ba = (BNode)o;
              log("Got ba="+ba);

              rs = con.getStatements(null, np3, no3, false, context);
              if (!rs.hasNext())
                throw new Exception("ResultSet is empty");
              st = rs.next();
              o = st.getSubject();
              if (!(o instanceof BNode))
                throw new Exception("Value must be BNode");
              bb = (BNode)o;
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

              rc = con.hasStatement(ba, np1, no1, false, context);
              if (!rc)
                throw new Exception("hasStatement return FALSE for ba");
              log("hasStatement with ba OK");

              rc = con.hasStatement(ba, np2, bb, false, context);
              if (!rc)
                throw new Exception("hasStatement return FALSE for ba & bb");
              log("hasStatement with ba & bb OK");

              rc = con.hasStatement(bb, np3, no3, false, context);
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

              rs = con.getStatements(ba, np1, no1, false, context);
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


              rs = con.getStatements(ba, np2, bb, false, context);
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

              rs = con.getStatements(bb, np3, no3, false, context);
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

              ArrayList<Statement> arr = new ArrayList<>();
              arr.add(new ContextStatementImpl(ba, np1, no1,context));
              arr.add(new ContextStatementImpl(ba, np2, bb,context));

              con.remove(arr, context);

 	      log("After remove 2 triple:");
 	      log("-----------------");
              rs = con.getStatements(null, null, null, false, context);
              while (rs.hasNext()) {
                log(rs.next().toString());
              }
 	      log("-----------------");
 	      rs.close();

              rc = con.hasStatement(ba, np1, no1, false, context);
              if (rc)
                throw new Exception("Triple with ba wasn't removed");
              log("remove with ba OK");

              rc = con.hasStatement(ba, np2, bb, false, context);
              if (rc)
                throw new Exception("Triple with ba & bb wasn't removed");
              log("remove with ba & bb OK");


              arr = new ArrayList<>();
              arr.add(new ContextStatementImpl(bb, np3, no3,context));


              con.remove(arr, context);

 	      log("After remove triple:");
 	      log("-----------------");
              rs = con.getStatements(null, null, null, false, context);
              while (rs.hasNext()) {
                log(rs.next().toString());
              }
 	      log("-----------------");
 	      rs.close();

              rc = con.hasStatement(bb, np3, no3, false, context);
              if (rc)
                throw new Exception("Triple with bb wasn't removed");
              log("remove with bb OK");


            } catch (Exception e) {
              log("***FAILED Test "+e);
              ok = false;
            }
            endTest("4", ok);



            getTestTotal();

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



    public static void Test_ImportFromFile(String[] args, boolean insertBNodeAsIRI) {

        String[] sa = new String[4];
        sa[0] = VIRTUOSO_INSTANCE;
        sa[1] = VIRTUOSO_PORT + "";
        sa[2] = VIRTUOSO_USERNAME;
        sa[3] = VIRTUOSO_PASSWORD;
        for (int i = 0; i < sa.length && i < args.length; i++) {
            sa[i] = args[i];
        }
        VirtuosoRepository repository = new VirtuosoRepository("jdbc:virtuoso://" + sa[0] + ":" + sa[1], sa[2], sa[3]);
        repository.setInsertBNodeAsVirtuosoIRI(insertBNodeAsIRI);

        RepositoryConnection con = null;
        try {
            con = repository.getConnection();
            con.setAutoCommit(true);

            // test add data to the repository
            boolean ok = true;
            String query = null;
            RepositoryResult<Statement> rs;
            Statement st;
            ValueFactory vfac = repository.getValueFactory();
            URI context = vfac.createURI("test:blank");

            con.clear(context);

            URI ns = repository.getValueFactory().createURI("http://localhost/publications/journals/Journal3/1967");
            URI np = repository.getValueFactory().createURI("http://swrc.ontoware.org/ontology#editor");
            URI np1 = repository.getValueFactory().createURI("http://xmlns.com/foaf/0.1/name");


            System.out.println("\n\n++++++++++++++++++++++++++++++++++++++++++++++++++++++++");
            if (insertBNodeAsIRI)
              System.out.println("Test Import data from File (BNode as Virtuoso IRI)");
            else
              System.out.println("Test Import data from File (BNode as Virtuoso Native BNode)");
            System.out.println("++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");


            startTest("1"); ok = true;
            try
            {
              log("Insert data with BNodes from file sp2b.n3");

	      File dataFile = new File("sp2b.n3");
	      long start_time = System.currentTimeMillis(); 
	      con.begin();
	      con.add(dataFile, "", RDFFormat.N3, context);
   	      con.commit();
	      long end_time = System.currentTimeMillis(); 
 	      log("Time :"+(end_time-start_time)+" ms");

   	      long count = con.size(context);
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

              rs = con.getStatements(ns, np, null, false, context);
              if (!rs.hasNext())
                throw new Exception("ResultSet is empty");
              st = rs.next();
              if (!st.getSubject().equals(ns))
                throw new Exception("Subject must be :"+ns);
              if (!st.getPredicate().equals(np))
                throw new Exception("Predicate must be :"+np);

              BNode[] bn_arr = new BNode[3];
              bn_arr[0] = (BNode)st.getObject();
              if (!rs.hasNext())
                throw new Exception("ResultSet have not 2 row");
              
              st = rs.next();
              bn_arr[1] = (BNode)st.getObject();
              if (!rs.hasNext())
                throw new Exception("ResultSet have not 3 row");
              
              st = rs.next();
              bn_arr[2] = (BNode)st.getObject();
              rs.close();

              log("BNodes loaded OK");
              HashSet<String> data = new HashSet<String>();
              data.add("Rajab Sikora");
              data.add("Yukari Pitcairn");
              data.add("Reyes Kluesner");
              Object o_val;
              Literal l_val;

              rs = con.getStatements(bn_arr[0], np1, null, false, context);
              if (!rs.hasNext())
                throw new Exception("ResultSet is empty");
              st = rs.next();
              log("Got =["+st.getObject()+"]\n for BNode:"+bn_arr[0]+"\n");
              o_val = st.getObject();
              if (!(o_val instanceof Literal))
                  throw new Exception(""+o_val+" Must be Literal");
              l_val = (Literal)o_val;
              if (!data.contains(l_val.getLabel()))
                  throw new Exception("Wrong data was received ="+o_val);
              data.remove(l_val.getLabel());
              rs.close();

              rs = con.getStatements(bn_arr[1], np1, null, false, context);
              if (!rs.hasNext())
                throw new Exception("ResultSet is empty");
              st = rs.next();
              log("Got =["+st.getObject()+"]\n for BNode:"+bn_arr[1]+"\n");
              o_val = st.getObject();
              if (!(o_val instanceof Literal))
                  throw new Exception(""+o_val+" Must be Literal");
              l_val = (Literal)o_val;
              if (!data.contains(l_val.getLabel()))
                  throw new Exception("Wrong data was received ="+o_val);
              data.remove(l_val.getLabel());
              rs.close();

              rs = con.getStatements(bn_arr[2], np1, null, false, context);
              if (!rs.hasNext())
                throw new Exception("ResultSet is empty");
              st = rs.next();
              log("Got =["+st.getObject()+"]\n for BNode:"+bn_arr[2]+"\n");
              o_val = st.getObject();
              if (!(o_val instanceof Literal))
                  throw new Exception(""+o_val+" Must be Literal");
              l_val = (Literal)o_val;
              if (!data.contains(l_val.getLabel()))
                  throw new Exception("Wrong data was received ="+o_val);
              data.remove(l_val.getLabel());
              rs.close();

            } catch (Exception e) {
              log("***FAILED Test "+e);
              ok = false;
            }
            endTest("2", ok);


            getTestTotal();

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

}
