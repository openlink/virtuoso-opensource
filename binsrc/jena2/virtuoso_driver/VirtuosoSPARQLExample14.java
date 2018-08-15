/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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


import com.hp.hpl.jena.query.*;
import com.hp.hpl.jena.ontology.*;
import com.hp.hpl.jena.rdf.model.*;
import com.hp.hpl.jena.reasoner.ReasonerRegistry;
import com.hp.hpl.jena.util.PrintUtil;
import com.hp.hpl.jena.vocabulary.RDFS;

import virtuoso.jena.driver.*;


public class VirtuosoSPARQLExample14 {

    static String URL = "jdbc:virtuoso://localhost:1111";
    static final String uid = "dba";
    static final String pwd = "dba";


    public static void print_model(String header, Model m) {
        String h = header==null?"Model":header;
        System.out.println("===========["+h+"]==========");
        StmtIterator it = m.listStatements((Resource)null, (Property)null, (RDFNode)null);
        while(it.hasNext()) {
            Statement st = it.nextStatement();
            System.out.println(st);
        }
        System.out.println("============================\n");
    }

    public static void print_model(String header, StmtIterator it) {
        String h = header==null?"Model iterator":header;
        System.out.println("===========["+h+"]==========");
        while(it.hasNext()) {
            Statement st = it.nextStatement();
            System.out.println(st);
        }
        System.out.println("============================\n");
    }

    public static void exec_select(String header, Model m, String query) {
        String h = header==null?"":header;
        System.out.println("===========["+h+"]==========");
        System.out.println("Exec: "+ query);
        Query jquery = QueryFactory.create(query) ;
        QueryExecution qexec = QueryExecutionFactory.create(jquery, m) ;
        ResultSet results =  qexec.execSelect();
        ResultSetFormatter.out(System.out, results, jquery);
        qexec.close();
        System.out.println("============================\n");

    }

    public static void main(String[] args) {
        if (args.length != 0)
            URL = args[0];

        try {
            test1();
            test2();
            test3();
            test4();
        } catch (Exception e) {
            System.out.println("ERROR Test Failed.");
            e.printStackTrace();
        }

    }



    public static void test1() {
        try {
            System.out.println("--------------- TEST 1 -------------------");
            VirtModel vdata = VirtModel.openDatabaseModel("test:inf1", URL, uid, pwd);
            vdata.removeAll();

            String NS = PrintUtil.egNS;
            Resource c1 = vdata.createResource(NS + "C1");
            Resource c2 = vdata.createResource(NS + "C2");
            Resource c3 = vdata.createResource(NS + "C3");
            vdata.add(c2, RDFS.subClassOf, c3);
            InfModel im = ModelFactory.createInfModel(ReasonerRegistry.getRDFSReasoner(), vdata);
            print_model("Data in DB", vdata);
            print_model("Data in Inferenced Model", im);

            Model premise = ModelFactory.createDefaultModel();
            premise.add(c1, RDFS.subClassOf, c2);
            print_model("Test listStatements",im.listStatements(c1, RDFS.subClassOf, null, premise));

        } catch (Exception e) {
            System.out.println("ERROR Test Failed.");
            e.printStackTrace();
        }
    }


    public static void test2() {
        try {
            System.out.println("--------------- TEST 2 -------------------");
            VirtModel vdata = VirtModel.openDatabaseModel("test:inf2", URL, uid, pwd);
            vdata.removeAll();

            String NS = PrintUtil.egNS;
            Resource c1 = vdata.createResource(NS + "C1");
            Resource c2 = vdata.createResource(NS + "C2");
            Resource c3 = vdata.createResource(NS + "C3");
            vdata.add(c2, RDFS.subClassOf, c3);
            OntModel om = ModelFactory.createOntologyModel(OntModelSpec.RDFS_MEM_RDFS_INF, vdata);

            print_model("Data in DB", vdata);
            print_model("Data in Ontology Model", om);

            Model premise = ModelFactory.createDefaultModel();
            premise.add(c1, RDFS.subClassOf, c2);
            print_model("Test listStatements",om.listStatements(c1, RDFS.subClassOf, null, premise));

        } catch (Exception e) {
            System.out.println("ERROR Test Failed.");
            e.printStackTrace();
        }
    }


    public static void test3() {
        try {
            System.out.println("--------------- TEST 3 -------------------");
            VirtModel vdata = VirtModel.openDatabaseModel("test:inf3", URL, uid, pwd);
            vdata.removeAll();

            String NS = PrintUtil.egNS;
            Resource c1 = vdata.createResource(NS + "C1");
            Resource c2 = vdata.createResource(NS + "C2");
            Resource c3 = vdata.createResource(NS + "C3");
            vdata.add(c2, RDFS.subClassOf, c3);
            vdata.add(c1, RDFS.subClassOf, c2);
            InfModel im = ModelFactory.createInfModel(ReasonerRegistry.getRDFSReasoner(), vdata);

            exec_select("Data in DB", vdata, "select * where {?s ?p ?o}");

            exec_select("Data in Inferenced Model", im, "select * where {?s ?p ?o}");

            exec_select("Data in Inferenced Model", im, "select * where {<"+c1+"> <"+RDFS.subClassOf+"> ?o}");

        } catch (Exception e) {
            System.out.println("ERROR Test Failed.");
            e.printStackTrace();
        }
    }


    public static void test4() {
        try {
            System.out.println("--------------- TEST 4 -------------------");
            VirtModel vdata = VirtModel.openDatabaseModel("test:inf4", URL, uid, pwd);
            vdata.removeAll();

            String NS = PrintUtil.egNS;
            Resource c1 = vdata.createResource(NS + "C1");
            Resource c2 = vdata.createResource(NS + "C2");
            Resource c3 = vdata.createResource(NS + "C3");
            vdata.add(c2, RDFS.subClassOf, c3);
            vdata.add(c1, RDFS.subClassOf, c2);
            OntModel om = ModelFactory.createOntologyModel(OntModelSpec.RDFS_MEM_RDFS_INF, vdata);

            exec_select("Data in DB", vdata, "select * where {?s ?p ?o}");

            exec_select("Data in Ontology Model", om, "select * where {?s ?p ?o}");

            exec_select("Data in Ontology", om, "select * where {<"+c1+"> <"+RDFS.subClassOf+"> ?o}");

        } catch (Exception e) {
            System.out.println("ERROR Test Failed.");
            e.printStackTrace();
        }
    }

}

