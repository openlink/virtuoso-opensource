package virtuoso_driver;

import java.util.*;

import com.hp.hpl.jena.query.*;
import com.hp.hpl.jena.rdf.model.RDFNode;
import com.hp.hpl.jena.graph.Node;
import com.hp.hpl.jena.graph.Triple;

import virtuoso_driver.*;

public class VirtuosoSPARQLExample3
{
    public static void main(String[] args)
    {

	Node foo1 = Node.createURI("http://example.org/#foo1");
	Node bar1 = Node.createURI("http://example.org/#bar1");
	Node baz1 = Node.createURI("http://example.org/#baz1");

	Node foo2 = Node.createURI("http://example.org/#foo2");
	Node bar2 = Node.createURI("http://example.org/#bar2");
	Node baz2 = Node.createURI("http://example.org/#baz2");

	Node foo3 = Node.createURI("http://example.org/#foo3");
	Node bar3 = Node.createURI("http://example.org/#bar3");
	Node baz3 = Node.createURI("http://example.org/#baz3");

	List <Triple> triples = new ArrayList <Triple> ();

	VirtGraph graph = new VirtGraph ("Example3", "jdbc:virtuoso://virtuoso_server:1111", "dba", "dba");

	graph.clear ();

	System.out.println("graph.isEmpty() = " + graph.isEmpty());
	System.out.println("Add 3 triples to graph <Example3>.");

	graph.add(new Triple(foo1, bar1, baz1));
	graph.add(new Triple(foo2, bar2, baz2));
	graph.add(new Triple(foo3, bar3, baz3));

	System.out.println("graph.isEmpty() = " + graph.isEmpty());
	System.out.println("graph.getCount() = " + graph.getCount());

	triples.add(new Triple(foo1, bar1, baz1));
	triples.add(new Triple(foo2, bar2, baz2));

	graph.isEmpty();

	System.out.println("Remove 2 triples from graph <Example3>");
	graph.remove(triples);
	System.out.println("graph.getCount() = " + graph.getCount());
	System.out.println("Please check result with isql tool.");

	/* EXPECTED RESULT:

SQL> sparql select ?s ?p ?o from <Example3> where {?s ?p ?o};
s                                                                                 p                                                                                 o
VARCHAR                                                                           VARCHAR                                                                           VARCHAR
_______________________________________________________________________________

http://example.org/#foo3                                                          http://example.org/#bar3                                                          http://example.org/#baz3

1 Rows. -- 26 msec.
SQL>

*/

	}
}

