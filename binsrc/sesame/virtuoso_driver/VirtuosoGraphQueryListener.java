
package virtuoso_driver;

import java.io.IOException;

import org.openrdf.model.Resource;
import org.openrdf.model.URI;
import org.openrdf.model.Value;
import org.openrdf.sesame.query.GraphQueryResultListener;
import org.openrdf.sesame.query.QueryEvaluationException;

public class VirtuosoGraphQueryListener implements GraphQueryResultListener
{

    private int tripleCount;

    public void startGraphQueryResult() throws IOException
    {
	tripleCount = 0;
    }

    public void endGraphQueryResult() throws IOException
    {
	System.out.println("Found " + tripleCount + " triples.");
    }

    public void namespace(String prefix, String name) throws IOException
    {
	System.out.println("Namespace: " + prefix + " = " + name);
    }

    public void triple(Resource subj, URI pred, Value obj) throws IOException
    {
	System.out.println("Found triple: (" + subj + ", " + pred + ", " + obj + ")");
	tripleCount++;
    }

    public void reportError(String msg)
    {
	System.out.println("Error: " + msg);
    }

}
