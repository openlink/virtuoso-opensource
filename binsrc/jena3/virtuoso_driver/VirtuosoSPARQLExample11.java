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
import org.apache.jena.rdf.model.*;
import org.apache.jena.util.iterator.*;
import org.apache.jena.graph.*;
import java.util.*;

import virtuoso.jena.driver.*;

public class VirtuosoSPARQLExample11 {


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
                VirtDataset ds =  new VirtDataset(url, "dba", "dba");

                Model md = ds.getNamedModel("gr");

        	Statement st;

        	st = statement( md, "D E F" );
        	md.add(st);
        	st = statement( md, "A B C" );
        	md.add(st);


                StmtIterator it = md.listStatements();
                while(it.hasNext()) {
                  st = it.nextStatement();
                  System.out.println(st);
                }

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
        { return m.asRDFNode( NodeFactory.createURI( "eh:/"+s ) ); }


}
