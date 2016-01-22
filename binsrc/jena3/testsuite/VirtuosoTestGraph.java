import java.net.*;
import java.io.*;

import virtuoso.jena.driver.VirtGraph;
import org.apache.jena.graph.Graph;
import org.apache.jena.graph.test.AbstractTestGraph;

import org.apache.jena.rdf.model.Model ;
import org.apache.jena.rdf.model.ModelFactory ;

//----------------------------------------------
/**
import java.io.InputStream ;
import java.net.MalformedURLException ;
import java.net.URISyntaxException ;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Set;

import com.hp.hpl.jena.graph.Capabilities;
import com.hp.hpl.jena.graph.Factory;
import com.hp.hpl.jena.graph.Graph;
import com.hp.hpl.jena.graph.GraphEventManager;
import com.hp.hpl.jena.graph.GraphEvents;
import com.hp.hpl.jena.graph.GraphListener;
import com.hp.hpl.jena.graph.GraphStatisticsHandler;
import com.hp.hpl.jena.graph.GraphUtil;
import com.hp.hpl.jena.graph.Node;
import com.hp.hpl.jena.graph.TransactionHandler;
import com.hp.hpl.jena.graph.Triple;
import com.hp.hpl.jena.mem.TrackingTripleIterator ;
import com.hp.hpl.jena.rdf.model.Model ;
import com.hp.hpl.jena.rdf.model.ModelFactory ;
import com.hp.hpl.jena.rdf.model.impl.ReifierStd ;
import com.hp.hpl.jena.shared.Command ;
import com.hp.hpl.jena.shared.JenaException ;
import com.hp.hpl.jena.util.CollectionFactory ;
import com.hp.hpl.jena.util.iterator.ClosableIterator ;
import com.hp.hpl.jena.util.iterator.ExtendedIterator ;

import com.hp.hpl.jena.graph.test.*;
***/
//-----------------------------

public class VirtuosoTestGraph extends AbstractTestGraph {
    protected VirtGraph graph;
    protected VirtGraph graph1;
    String url;
	
    synchronized public void finalize () throws Throwable
    {
       if (graph!=null) {
         graph.clear();
         graph.close();
         graph = null;
       }
       if (graph1!=null) {
         graph1.clear();
         graph1.close();
         graph1 = null;
       }
    }


    public VirtuosoTestGraph(String name) {
		super(name);

		url = System.getProperty("url");
                if(url == null)
                    url = "jdbc:virtuoso://localhost:1111";

		graph = new VirtGraph("http://example.org/testing", url, "dba", "dba");
		graph.setInsertBNodeAsVirtuosoIRI(true);
		graph1 = new VirtGraph("http://example.org/testing1", url, "dba", "dba");
		graph1.setInsertBNodeAsVirtuosoIRI(true);
    }

//	public static TestSuite suite() {
//		return MetaTestGraph.suite(AbstractTestGraph.class, VirtGraph.class);
//	}

    @Override
    public Graph getGraph() {
        graph.clear();
	return graph;
    }

    public Graph getGraph1() {
        graph1.clear();
	return graph1;
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

    @Override
    public void testIsomorphismFile() {
	//skip
        testIsomorphismXMLFile(1,true);
        testIsomorphismXMLFile(2,true); //FAILED because XMLLiteral isn't supported properly
        testIsomorphismXMLFile(3,true);
        testIsomorphismXMLFile(4,true);
        testIsomorphismXMLFile(5,false);
        testIsomorphismXMLFile(6,false);
        testIsomorphismNTripleFile(7,true);
        testIsomorphismNTripleFile(8,false);
    }

    private void testIsomorphismNTripleFile(int i, boolean result) {
       testIsomorphismFile(i,"N-TRIPLE","nt",result);
    }

    private void testIsomorphismXMLFile(int i, boolean result) {
       testIsomorphismFile(i,"RDF/XML","rdf",result);
    }

    private InputStream getInputStream( int n, int n2, String suffix)
    {
    	String urlStr = String.format( "regression/testModelEquals/%s-%s.%s", n, n2, suffix);
    	return AbstractTestGraph.class.getClassLoader().getResourceAsStream(  urlStr );
    }
    
    private void testIsomorphismFile(int n, String lang, String suffix, boolean result) {

        Graph g1 = getGraph();
        Graph g2 = getGraph1();
        Model m1 = ModelFactory.createModelForGraph(g1);
        Model m2 = ModelFactory.createModelForGraph(g2);

        m1.read(
                getInputStream(n, 1, suffix),
                "http://www.example.org/",lang);
        m2.read(
                getInputStream(n, 2, suffix),
                "http://www.example.org/",lang);

        boolean rslt = g1.isIsomorphicWith(g2) == result;
        if (!rslt) {
            System.out.println("g1:");
            m1.write(System.out, "N-TRIPLE");
            System.out.println("g2:");
            m2.write(System.out, "N-TRIPLE");
        }
        assertTrue("Isomorphism test failed",rslt);
    }


}

