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

//package virtuoso.jena.driver;

import org.apache.jena.query.*;
import org.apache.jena.rdf.model.RDFNode;

import virtuoso.jena.driver.*;

public class VirtuosoSPARQLExample10 {

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
		VirtGraph set = new VirtGraph ("gr", url, "dba", "dba");

/*			STEP 2			*/
		set.clear ();

		System.out.print ("Begin read from 'http://www.w3.org/People/Berners-Lee/card#i'  ");
		set.read("http://www.w3.org/People/Berners-Lee/card#i", "RDF/XML");
		System.out.println ("\t\t\t Done.");


/*			STEP 3			*/
/*		Select all data in virtuoso	*/
		String query = "SELECT * WHERE { ?s ?p ?o } limit 100";

/*			STEP 4			*/
		QueryExecution vqe = VirtuosoQueryExecutionFactory.create (query, set);

		ResultSet results = vqe.execSelect();
		while (results.hasNext()) {
			QuerySolution result = results.nextSolution();
		    RDFNode graph = result.get("graph");
		    RDFNode s = result.get("s");
		    RDFNode p = result.get("p");
		    RDFNode o = result.get("o");
		    System.out.println(graph + " { " + s + " " + p + " " + o + " . }");
		}
	}
}
