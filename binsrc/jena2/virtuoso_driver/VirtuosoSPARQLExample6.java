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

import java.util.*;

import com.hp.hpl.jena.query.*;
import com.hp.hpl.jena.util.iterator.ExtendedIterator;
import com.hp.hpl.jena.graph.Node;
import com.hp.hpl.jena.graph.Triple;

import virtuoso.jena.driver.*;

public class VirtuosoSPARQLExample6
{

    public static void main(String[] args)
    {
	String url;
	if(args.length == 0)
	    url = "jdbc:virtuoso://localhost:1111";
	else
	    url = args[0];

	Node foo1 = Node.createURI("http://example.org/#foo1");
	Node bar1 = Node.createURI("http://example.org/#bar1");
	Node baz1 = Node.createURI("http://example.org/#baz1");

	Node foo2 = Node.createURI("http://example.org/#foo2");
	Node bar2 = Node.createURI("http://example.org/#bar2");
	Node baz2 = Node.createURI("http://example.org/#baz2");

	Node foo3 = Node.createURI("http://example.org/#foo3");
	Node bar3 = Node.createURI("http://example.org/#bar3");
	Node baz3 = Node.createURI("http://example.org/#baz3");

	VirtGraph graph = new VirtGraph ("Example6", url, "dba", "dba");

	graph.clear ();

	System.out.println("graph.isEmpty() = " + graph.isEmpty());

	System.out.println("test Transaction Commit.");
	graph.getTransactionHandler().begin();
	System.out.println("begin Transaction.");
	System.out.println("Add 3 triples to graph <Example6>.");

	graph.add(new Triple(foo1, bar1, baz1));
	graph.add(new Triple(foo2, bar2, baz2));
	graph.add(new Triple(foo3, bar3, baz3));

	graph.getTransactionHandler().commit();
	System.out.println("commit Transaction.");
	System.out.println("graph.isEmpty() = " + graph.isEmpty());
	System.out.println("graph.getCount() = " + graph.getCount());

	ExtendedIterator iter = graph.find(Node.ANY, Node.ANY, Node.ANY);
	System.out.println ("\ngraph.find(Node.ANY, Node.ANY, Node.ANY) \nResult:");
	for ( ; iter.hasNext() ; )
	    System.out.println ((Triple) iter.next());

	graph.clear ();
	System.out.println("\nCLEAR graph <Example6>");
	System.out.println("graph.isEmpty() = " + graph.isEmpty());

	System.out.println("Add 1 triples to graph <Example6>.");
	graph.add(new Triple(foo1, bar1, baz1));

	System.out.println("\nStart test Transaction Abort.");
	graph.getTransactionHandler().begin();
	System.out.println("begin Transaction.");
	System.out.println("Add 2 triples to graph <Example6>.");

	graph.add(new Triple(foo2, bar2, baz2));
	graph.add(new Triple(foo3, bar3, baz3));

	graph.getTransactionHandler().abort();
	System.out.println("abort Transaction.");
	System.out.println("End test Transaction Abort.\n");

	System.out.println("graph.isEmpty() = " + graph.isEmpty());
	System.out.println("graph.getCount() = " + graph.getCount());

	iter = graph.find(Node.ANY, Node.ANY, Node.ANY);
	System.out.println ("\ngraph.find(Node.ANY, Node.ANY, Node.ANY) \nResult:");
	for ( ; iter.hasNext() ; )
	    System.out.println ((Triple) iter.next());

	graph.clear ();
	System.out.println("\nCLEAR graph <Example6>");

    }
}
