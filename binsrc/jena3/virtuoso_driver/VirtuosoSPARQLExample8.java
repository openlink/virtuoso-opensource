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

import virtuoso.jena.driver.*;

public class VirtuosoSPARQLExample8 {

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
System.out.println("\nexecute: CLEAR GRAPH <http://test1>");
                String str = "CLEAR GRAPH <http://test1>";
                VirtuosoUpdateRequest vur = VirtuosoUpdateFactory.create(str, set);
                vur.exec();                  

System.out.println("\nexecute: INSERT INTO GRAPH <http://test1> { <aa> <bb> 'cc' . <aa1> <bb1> 123. }");
                str = "INSERT INTO GRAPH <http://test1> { <aa> <bb> 'cc' . <aa1> <bb1> 123. }";
                vur = VirtuosoUpdateFactory.create(str, set);
                vur.exec();                  

/*			STEP 3			*/
/*		Select all data in virtuoso	*/
System.out.println("\nexecute: SELECT * FROM <http://test1> WHERE { ?s ?p ?o }");
		Query sparql = QueryFactory.create("SELECT * FROM <http://test1> WHERE { ?s ?p ?o }");

/*			STEP 4			*/
		QueryExecution vqe = VirtuosoQueryExecutionFactory.create (sparql, set);

		ResultSet results = vqe.execSelect();
		while (results.hasNext()) {
			QuerySolution rs = results.nextSolution();
		    RDFNode s = rs.get("s");
		    RDFNode p = rs.get("p");
		    RDFNode o = rs.get("o");
		    System.out.println(" { " + s + " " + p + " " + o + " . }");
		}


System.out.println("\nexecute: DELETE FROM GRAPH <http://test1> { <aa> <bb> 'cc' }");
                str = "DELETE FROM GRAPH <http://test1> { <aa> <bb> 'cc' }";
                vur = VirtuosoUpdateFactory.create(str, set);
                vur.exec();                  

System.out.println("\nexecute: SELECT * FROM <http://test1> WHERE { ?s ?p ?o }");
		vqe = VirtuosoQueryExecutionFactory.create (sparql, set);
                results = vqe.execSelect();
		while (results.hasNext()) {
			QuerySolution rs = results.nextSolution();
		    RDFNode s = rs.get("s");
		    RDFNode p = rs.get("p");
		    RDFNode o = rs.get("o");
		    System.out.println(" { " + s + " " + p + " " + o + " . }");
		}

	
	}
}
