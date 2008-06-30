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

	@Override
	public Graph getGraph() {
	        graph.clear();
		return graph;
	}

	@Override
	public void testContainsConcrete() {
	//skip
	}

	@Override
	public void testContainsByValue() {
	//skip
	}

	@Override
	public void testContainsNode() {
	//skip
	}

	@Override
	public void testIsomorphismFile() {
	//skip
	}
}

