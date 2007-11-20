
package virtuoso_driver;

import java.io.IOException;

import org.openrdf.model.Value;
import org.openrdf.sesame.query.QueryErrorType;
import org.openrdf.sesame.query.TableQueryResultListener;

public class VirtuosoQueryListener implements TableQueryResultListener
{

    private int resultCount;

    public void startTableQueryResult() throws IOException
    {
	resultCount = 0;
    }

    public void startTableQueryResult(String[] arg0) throws IOException
    {
	System.out.println("Column headers:");
	for (int i = 0; i < arg0.length; i++)
	{
	    System.out.println("Column " + i + ": " + arg0[i]);
	}
	System.out.println();

	this.startTableQueryResult();
    }

    public void endTableQueryResult() throws IOException
    {
	System.out.println("Found " + resultCount + " results.");
    }

    public void startTuple() throws IOException
    {
	resultCount++;
	System.out.println("Tuple " + resultCount + ":");
    }

    public void endTuple() throws IOException
    {
    }

    public void tupleValue(Value arg0) throws IOException
    {
	System.out.println(arg0.getClass().getName() + " " + arg0);
    }

    public void reportError(String arg0)
    {
	System.out.println("Error: " + arg0);
    }

    public void error(QueryErrorType arg0, String arg1)
    {
	System.out.println("Error: " + arg1);
    }
}
