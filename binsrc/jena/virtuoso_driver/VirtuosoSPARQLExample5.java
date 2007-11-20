package virtuoso_driver;

import java.util.*;

import com.hp.hpl.jena.query.*;
import com.hp.hpl.jena.util.iterator.ExtendedIterator;
import com.hp.hpl.jena.graph.Node;
import com.hp.hpl.jena.graph.Triple;

import virtuoso_driver.*;

public class VirtuosoSPARQLExample5
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

	VirtGraph graph = new VirtGraph ("Example5", "jdbc:virtuoso://virtuoso_server:1111", "dba", "dba");

	graph.clear ();

	System.out.println("graph.isEmpty() = " + graph.isEmpty());

	System.out.println("Add 3 triples to graph <Example5>.");

	graph.add(new Triple(foo1, bar1, baz1));
	graph.add(new Triple(foo2, bar2, baz2));
	graph.add(new Triple(foo3, bar3, baz3));
	graph.add(new Triple(foo1, bar2, baz2));
	graph.add(new Triple(foo1, bar3, baz3));

	System.out.println("graph.isEmpty() = " + graph.isEmpty());
	System.out.println("graph.getCount() = " + graph.getCount());

	ExtendedIterator iter = graph.find(foo1, Node.ANY, Node.ANY);
	System.out.println ("\ngraph.find(foo1, Node.ANY, Node.ANY) \nResult:");
	for ( ; iter.hasNext() ; )
	    System.out.println ((Triple) iter.next());

	iter = graph.find(Node.ANY, Node.ANY, baz3);
	System.out.println ("\ngraph.find(Node.ANY, Node.ANY, baz3) \nResult:");
	for ( ; iter.hasNext() ; )
	    System.out.println ((Triple) iter.next());

	iter = graph.find(foo1, Node.ANY, baz3);
	System.out.println ("\ngraph.find(foo1, Node.ANY, baz3) \nResult:");
	for ( ; iter.hasNext() ; )
	    System.out.println ((Triple) iter.next());

	graph.clear ();

    }
}
