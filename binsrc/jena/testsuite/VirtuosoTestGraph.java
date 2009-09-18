import virtuoso.jena.driver.VirtGraph;
import com.hp.hpl.jena.graph.Graph;
import com.hp.hpl.jena.graph.test.AbstractTestGraph;

public class VirtuosoTestGraph extends AbstractTestGraph {
	protected VirtGraph graph;
	String url;
	
	public VirtuosoTestGraph(String name) {
		super(name);

		url = System.getProperty("url");
                if(url == null)
                    url = "jdbc:virtuoso://localhost:1111";

		graph = new VirtGraph("http://example.org/testing", url, "dba", "dba");
	}

//	public static TestSuite suite() {
//		return MetaTestGraph.suite(AbstractTestGraph.class, VirtGraph.class);
//	}

	//--java5 or newer @Override
	public Graph getGraph() {
	        graph.clear();
		return graph;
	}

	//--java5 or newer @Override
	public void testContainsConcrete() {
	//skip
	}

	//--java5 or newer @Override
	public void testContainsByValue() {
	//skip
	}

	//--java5 or newer @Override
	public void testContainsNode() {
	//skip
	}

	//--java5 or newer @Override
	public void testIsomorphismFile() {
	//skip
	}
}

