
package virtuoso_driver;

import java.io.*;
import java.util.HashMap;
import java.net.URL;

import org.openrdf.sesame.query.QueryEvaluationException;
import org.openrdf.sesame.Sesame;
import org.openrdf.sesame.config.AccessDeniedException;
import org.openrdf.sesame.config.ConfigurationException;
import org.openrdf.sesame.config.RepositoryConfig;
import org.openrdf.sesame.config.SailConfig;
import org.openrdf.sesame.config.UnknownRepositoryException;
import org.openrdf.sesame.constants.QueryLanguage;
import org.openrdf.sesame.query.MalformedQueryException;
import org.openrdf.sesame.repository.local.LocalService;
import org.openrdf.sesame.server.SesameServer;
import org.openrdf.sesame.sail.Sail;
import org.openrdf.sesame.admin.AdminListener;
import org.openrdf.sesame.constants.RDFFormat;
import org.openrdf.sesame.Sesame;
import org.openrdf.sesame.repository.SesameService;
import org.openrdf.sesame.repository.SesameRepository;
import org.openrdf.sesame.query.QueryResultsTable;
import org.openrdf.sesame.constants.QueryLanguage;

import org.openrdf.model.Value;
import org.openrdf.util.Enumeration;


public class VirtuosoExample2
{

    public static void main(String[] args)
    {

	// example query
	String query = "SELECT ?s ?p ?o from <sesame> WHERE { ?s ?p ?o }";

	try {


	    VirtuosoAdminListener _report = null;

	    VirtuosoRepository rep = new VirtuosoRepository ("sesame",
		    "jdbc:virtuoso://virtuoso_server:1111", "dba", "dba");

	    rep.clear (_report);

	    File dataFile = new File ("data.nt");
	    rep.addData (dataFile, null, RDFFormat.NTRIPLES, false, _report);

	    // execute query

	    QueryResultsTable result = rep.performTableQuery(null, query);

	    System.out.println("result.getRowCount = " + result.getRowCount());

	}
	catch (AccessDeniedException ade)
	{
	    System.out.println("Access denied.");
	    System.out.println(ade.getMessage());
	}
	catch (FileNotFoundException fnfe)
	{
	    System.out.println("File not found.");
	    System.out.println(fnfe.getMessage());
	}
	catch (IOException ioe)
	{
	    System.out.println("I/O error.");
	    System.out.println(ioe.getMessage());
	}
	catch (QueryEvaluationException qee)
	{
	    System.out.println("QueryEvaluationException.");
	    System.out.println(qee.getMessage());
	}
	catch (MalformedQueryException mqe)
	{
	    System.out.println("Malformed query - SimpleExample.");
	    System.out.println(mqe.getMessage());
	    mqe.printStackTrace();
	}
	catch (ClassCastException cce)
	{
	    System.out.println("ClassCastException repository.");
	    System.out.println(cce.getMessage());
	    cce.printStackTrace();
	}
    }
}
