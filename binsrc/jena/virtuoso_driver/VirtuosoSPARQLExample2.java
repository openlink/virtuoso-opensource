/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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
import com.hp.hpl.jena.rdf.model.RDFNode;

import virtuoso.jena.driver.*;

public class VirtuosoSPARQLExample2 {

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
		VirtGraph graph = new VirtGraph ("Example2", url, "dba", "dba");

/*			STEP 2			*/
/*		Load data to Virtuoso		*/
		graph.clear ();

		System.out.print ("Begin read from 'http://www.w3.org/People/Berners-Lee/card#i'  ");
		graph.read("http://www.w3.org/People/Berners-Lee/card#i", "RDF/XML");
		System.out.println ("\t\t\t Done.");

		System.out.print ("Begin read from 'http://demo.openlinksw.com/dataspace/person/demo#this'  ");
		graph.read("http://demo.openlinksw.com/dataspace/person/demo#this", "RDF/XML");
		System.out.println ("\t Done.");

		System.out.print ("Begin read from 'http://kidehen.idehen.net/dataspace/person/kidehen#this'  ");
		graph.read("http://kidehen.idehen.net/dataspace/person/kidehen#this", "RDF/XML");
		System.out.println ("\t Done.");


/*			STEP 3			*/
/*		Select only from VirtGraph	*/
		Query sparql = QueryFactory.create("SELECT ?s ?p ?o WHERE { ?s ?p ?o }");

/*			STEP 4			*/
		VirtuosoQueryExecution vqe = VirtuosoQueryExecutionFactory.create (sparql, graph);

		ResultSet results = vqe.execSelect();
		while (results.hasNext()) {
			QuerySolution result = results.nextSolution();
		    RDFNode graph_name = result.get("graph");
		    RDFNode s = result.get("s");
		    RDFNode p = result.get("p");
		    RDFNode o = result.get("o");
		    System.out.println(graph_name + " { " + s + " " + p + " " + o + " . }");
		}

		System.out.println("graph.getCount() = " + graph.getCount());
	}
}
