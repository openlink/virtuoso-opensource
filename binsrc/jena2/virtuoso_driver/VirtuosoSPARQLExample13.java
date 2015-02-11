/*
 *  $Id$
 *
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

//package virtuoso.jena.driver;

import com.hp.hpl.jena.query.*;
import com.hp.hpl.jena.graph.Triple;
import com.hp.hpl.jena.graph.Node;
import com.hp.hpl.jena.graph.Graph;
import com.hp.hpl.jena.rdf.model.*;
import com.hp.hpl.jena.rdf.model.RDFNode;
import com.hp.hpl.jena.vocabulary.RDFS;
import java.util.*;

import virtuoso.jena.driver.*;

public class VirtuosoSPARQLExample13 {

    /**
     * Executes a SPARQL query against a virtuoso url and prints results.
     */
    public static void main(String[] args) 
    {
	String url;
	if(args.length == 0)
	    url = "jdbc:virtuoso://localhost:1111";
	else
	    url = args[0];

/*** LOADING data to http://exmpl13 graph  ***/
        
        VirtModel mdata = VirtModel.openDatabaseModel("http://exmpl13", url, "dba", "dba");
        mdata.removeAll();

        Statement st;

        st = statement(mdata, "http://localhost:8890/dataspace http://www.w3.org/1999/02/22-rdf-syntax-ns#type http://rdfs.org/sioc/ns#Space" );
       	mdata.add(st);

        st = statement(mdata, "http://localhost:8890/dataspace http://rdfs.org/sioc/ns#link http://localhost:8890/ods");
       	mdata.add(st);


        st = statement(mdata, "http://localhost:8890/dataspace/test2/weblog/test2tWeblog http://www.w3.org/1999/02/22-rdf-syntax-ns#type http://rdfs.org/sioc/types#Weblog");
       	mdata.add(st);
        st = statement(mdata, "http://localhost:8890/dataspace/test2/weblog/test2tWeblog http://rdfs.org/sioc/ns#link http://localhost:8890/dataspace/test2/weblog/test2tWeblog");
       	mdata.add(st);

        st = statement(mdata, "http://localhost:8890/dataspace/discussion/oWiki-test1Wiki http://www.w3.org/1999/02/22-rdf-syntax-ns#type http://rdfs.org/sioc/types#MessageBoard");
       	mdata.add(st);
        st = statement(mdata, "http://localhost:8890/dataspace/discussion/oWiki-test1Wiki http://rdfs.org/sioc/ns#link http://localhost:8890/dataspace/discussion/oWiki-test1Wiki");
       	mdata.add(st);


        // Query string.
        String queryString = "SELECT * WHERE {?s ?p ?o}" ; 
        System.out.println("Execute query=\n"+queryString) ;
        System.out.println() ;


        QueryExecution qexec = VirtuosoQueryExecutionFactory.create(queryString, mdata) ;
        try {
            ResultSet rs = qexec.execSelect() ;
            for ( ; rs.hasNext() ; ) {
		QuerySolution result = rs.nextSolution();
		    RDFNode s = result.get("s");
		    RDFNode p = result.get("p");
		    RDFNode o = result.get("o");
		    System.out.println(" { " + s + " " + p + " " + o + " . }");
            }
        } finally {
            qexec.close() ;
        }

        mdata.removeRuleSet("exmpl13_rules","http://:exmpl13_schema");


/*** LOADING rule to http://exmpl13_schema graph  ***/

        VirtModel mrule = VirtModel.openDatabaseModel("http://exmpl13_schema", url, "dba", "dba");
        mrule.removeAll();

        Resource r1 = mrule.createResource("http://rdfs.org/sioc/ns#Space") ;
        r1.addProperty(RDFS.subClassOf, rdfNode(mrule, "http://www.w3.org/2000/01/rdf-schema#Resource"));

        r1 = mrule.createResource("http://rdfs.org/sioc/ns#Container") ;
        r1.addProperty(RDFS.subClassOf, rdfNode(mrule, "http://rdfs.org/sioc/ns#Space"));

        r1 = mrule.createResource("http://rdfs.org/sioc/ns#Forum") ;
        r1.addProperty(RDFS.subClassOf, rdfNode(mrule, "http://rdfs.org/sioc/ns#Container"));

        r1 = mrule.createResource("http://rdfs.org/sioc/types#Weblog") ;
        r1.addProperty(RDFS.subClassOf, rdfNode(mrule, "http://rdfs.org/sioc/ns#Forum"));

        r1 = mrule.createResource("http://rdfs.org/sioc/types#MessageBoard") ;
        r1.addProperty(RDFS.subClassOf, rdfNode(mrule, "http://rdfs.org/sioc/ns#Forum"));

        r1 = mrule.createResource("http://rdfs.org/sioc/ns#link") ;
        r1.addProperty(RDFS.subPropertyOf, rdfNode(mrule, "http://rdfs.org/sioc/ns"));

        mrule.close();

        mdata.createRuleSet("exmpl13_rules","http://exmpl13_schema");
        mdata.close();



        VirtInfGraph infGraph = new VirtInfGraph("exmpl13_rules", false, 
        				"http://exmpl13", url, "dba", "dba");
        InfModel model = ModelFactory.createInfModel(infGraph);
        
        
        queryString = "SELECT ?s "+
                      "FROM <http://exmpl13> "+
                      "WHERE {?s <http://www.w3.org/1999/02/22-rdf-syntax-ns#type>  <http://rdfs.org/sioc/ns#Space> } ";
        System.out.println("\n\nExecute query=\n"+queryString) ;
        System.out.println() ;

        qexec = VirtuosoQueryExecutionFactory.create(queryString, model) ;
        try {
            ResultSet rs = qexec.execSelect() ;
            for ( ; rs.hasNext() ; ) {
		QuerySolution result = rs.nextSolution();
		    RDFNode s = result.get("s");
		    System.out.println(" " + s);
            }
        } finally {
            qexec.close() ;
        }



        queryString = "SELECT * "+
                      "FROM <http://exmpl13> "+
                      "WHERE "+
                      "{ "+
                      " ?s ?p <http://rdfs.org/sioc/ns#Space> . "+
                      " ?s ?p1 <http://localhost:8890/dataspace/test2/weblog/test2tWeblog> . "+
                      "} ";
        
        System.out.println("\n\nExecute query=\n"+queryString) ;
        System.out.println() ;

        qexec = VirtuosoQueryExecutionFactory.create(queryString, model) ;
        try {
            ResultSet rs = qexec.execSelect() ;
            for ( ; rs.hasNext() ; ) {
		QuerySolution result = rs.nextSolution();
		    RDFNode s = result.get("s");
		    RDFNode p = result.get("p");
		    RDFNode p1 = result.get("p1");
		    System.out.println(" " + s + " " + p + " " + p1);
            }
        } finally {
            qexec.close() ;
        }

        model.close();
    }



    public static Statement statement( Model m, String fact )
         {
         StringTokenizer st = new StringTokenizer( fact );
         Resource sub = resource( m, st.nextToken() );
         Property pred = property( m, st.nextToken() );
         RDFNode obj = rdfNode( m, st.nextToken() );
         return m.createStatement( sub, pred, obj );    
         }    

    public static Resource resource( Model m, String s )
        { return (Resource) rdfNode( m, s ); }

    public static Property property( Model m, String s )
        { return (Property) rdfNode( m, s ).as( Property.class ); }

    public static RDFNode rdfNode( Model m, String s )
        { return m.asRDFNode( Node.createURI( s ) ); }



}

