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

//package virtuoso.jena.driver;

import org.apache.jena.query.*;
import org.apache.jena.rdf.model.RDFNode;
import org.apache.jena.graph.Triple;
import org.apache.jena.graph.Node;
import org.apache.jena.graph.Graph;
import org.apache.jena.rdf.model.*;
import java.util.Iterator;

import virtuoso.jena.driver.*;

public class VirtuosoSPARQLExample9 {

	/**
	 * Executes a SPARQL query against a virtuoso url and prints results.
	 */
	public static void main(String[] args) {

		String url;
		if(args.length == 0)
		    url = "jdbc:virtuoso://localhost:1111";
		else
		    url = args[0];

/*			STEP 1			*/
		VirtGraph set = new VirtGraph (url, "dba", "dba");

/*			STEP 2			*/
                String str = "CLEAR GRAPH <http://test1>";
                VirtuosoUpdateRequest vur = VirtuosoUpdateFactory.create(str, set);
                vur.exec();                  

                str = "INSERT INTO GRAPH <http://test1> { <http://aa> <http://bb> 'cc' . <http://aa1> <http://bb> 123. }";
                vur = VirtuosoUpdateFactory.create(str, set);
                vur.exec();                  


/*		Select all data in virtuoso	*/
		Query sparql = QueryFactory.create("SELECT * FROM <http://test1> WHERE { ?s ?p ?o }");
		QueryExecution vqe = VirtuosoQueryExecutionFactory.create (sparql, set);
		ResultSet results = vqe.execSelect();
                System.out.println("\nSELECT results:");
		while (results.hasNext()) {
			QuerySolution rs = results.nextSolution();
		    RDFNode s = rs.get("s");
		    RDFNode p = rs.get("p");
		    RDFNode o = rs.get("o");
		    System.out.println(" { " + s + " " + p + " " + o + " . }");
		}

		sparql = QueryFactory.create("DESCRIBE <http://aa> FROM <http://test1>");
		vqe = VirtuosoQueryExecutionFactory.create (sparql, set);

		Model model = vqe.execDescribe();
 	        Graph g = model.getGraph();
                System.out.println("\nDESCRIBE results:");
	        for (Iterator i = g.find(Node.ANY, Node.ANY, Node.ANY); i.hasNext();) 
	           {
	              Triple t = (Triple)i.next();
		      System.out.println(" { " + t.getSubject() + " " + 
		      				 t.getPredicate() + " " + 
		      				 t.getObject() + " . }");
	        }



		sparql = QueryFactory.create("CONSTRUCT { ?x <http://test> ?y } FROM <http://test1> WHERE { ?x <http://bb> ?y }");
		vqe = VirtuosoQueryExecutionFactory.create (sparql, set);

		model = vqe.execConstruct();
 	        g = model.getGraph();
                System.out.println("\nCONSTRUCT results:");
	        for (Iterator i = g.find(Node.ANY, Node.ANY, Node.ANY); i.hasNext();) 
	           {
	              Triple t = (Triple)i.next();
		      System.out.println(" { " + t.getSubject() + " " + 
		      				 t.getPredicate() + " " + 
		      				 t.getObject() + " . }");
	        }


		sparql = QueryFactory.create("ASK FROM <http://test1> WHERE { <http://aa> <http://bb> ?y }");
		vqe = VirtuosoQueryExecutionFactory.create (sparql, set);

		boolean res = vqe.execAsk();
                System.out.println("\nASK results: "+res);


	}
}
