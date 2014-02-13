/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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
import com.hp.hpl.jena.vocabulary.DC;
import java.util.Iterator;

import virtuoso.jena.driver.*;

public class VirtuosoSPARQLExample12 {

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

        Model m = VirtModel.openDatabaseModel("my:test", url, "dba", "dba");
        m.removeAll();

        Resource r1 = m.createResource("http://example.org/book#1") ;
        Resource r2 = m.createResource("http://example.org/book#2") ;
        
        r1.addProperty(DC.title, "SPARQL - the book")
          .addProperty(DC.description, "A book about SPARQL") ;
        
        r2.addProperty(DC.title, "Advanced techniques for SPARQL") ;

        String prolog = "PREFIX dc: <"+DC.getURI()+"> \n" ;
        
        // Query string.
        String queryString = prolog + "SELECT ?title WHERE {?x dc:title ?title}" ; 
        System.out.println("Execute query=\n"+queryString) ;
        System.out.println() ;

	Query query = QueryFactory.create(queryString) ;

System.out.println("\n==CASE 1 ==Parse ARQ  Execute ARQ  GraphStore Virtuoso");
//NOTE: query is parsed & executed by ARQ, so it works slow
// and you can't use Virtuoso SPARQL features
        QueryExecution qexec = QueryExecutionFactory.create(query, m) ;
        // Or QueryExecutionFactory.create(queryString, model) ;
        System.out.println("Titles: ") ;
        try {
            ResultSet rs = qexec.execSelect() ;
            for ( ; rs.hasNext() ; ) {
                QuerySolution rb = rs.nextSolution() ;
                RDFNode x = rb.get("title") ;
                if ( x.isLiteral() ) {
                    Literal titleStr = (Literal)x  ;
                    System.out.println("    "+titleStr) ;
                } else
                    System.out.println("Strange - not a literal: "+x) ;
            }
        } finally {
            qexec.close() ;
        }


System.out.println("\n==CASE 2a ==Parse ARQ  Execute Virtuoso  GraphStore Virtuoso");
//NOTE: query is parsed by ARQ, so you can't use Virtuoso SPARQL features
//      execution speed fast

        VirtuosoQueryEngine.register();
	
        qexec = QueryExecutionFactory.create(query, m) ;
        // Or QueryExecutionFactory.create(queryString, model) ;
        System.out.println("Titles: ") ;
        try {
            ResultSet rs = qexec.execSelect() ;
            for ( ; rs.hasNext() ; ) {
                QuerySolution rb = rs.nextSolution() ;
                RDFNode x = rb.get("title") ;
                if ( x.isLiteral() ) {
                    Literal titleStr = (Literal)x  ;
                    System.out.println("    "+titleStr) ;
                } else
                    System.out.println("Strange - not a literal: "+x) ;
            }
        } finally {
            qexec.close() ;
        }

        VirtuosoQueryEngine.unregister();
	

System.out.println("\n==CASE 2b ==Parse ARQ  Execute Virtuoso  GraphStore Virtuoso");
//NOTE: query is parsed by ARQ, so you can't use Virtuoso SPARQL features
//      execution speed fast
	
        qexec = VirtuosoQueryExecutionFactory.create(query, m) ;
        System.out.println("Titles: ") ;
        try {
            ResultSet rs = qexec.execSelect() ;
            for ( ; rs.hasNext() ; ) {
                QuerySolution rb = rs.nextSolution() ;
                RDFNode x = rb.get("title") ;
                if ( x.isLiteral() ) {
                    Literal titleStr = (Literal)x  ;
                    System.out.println("    "+titleStr) ;
                } else
                    System.out.println("Strange - not a literal: "+x) ;
            }
        } finally {
            qexec.close() ;
        }

	
System.out.println("\n==CASE 3 ==Parse & Execute Virtuoso  GraphStore Virtuoso");
//NOTE: query is parsed & executed by Virtuoso, so you can use all Virtuoso SPARQL features
//      execution speed fast

        qexec = VirtuosoQueryExecutionFactory.create(queryString, m) ;
        System.out.println("Titles: ") ;
        try {
            ResultSet rs = qexec.execSelect() ;
            for ( ; rs.hasNext() ; ) {
                QuerySolution rb = rs.nextSolution() ;
                RDFNode x = rb.get("title") ;
                if ( x.isLiteral() ) {
                    Literal titleStr = (Literal)x  ;
                    System.out.println("    "+titleStr) ;
                } else
                    System.out.println("Strange - not a literal: "+x) ;
            }
        } finally {
            qexec.close() ;
        }



    }
}
