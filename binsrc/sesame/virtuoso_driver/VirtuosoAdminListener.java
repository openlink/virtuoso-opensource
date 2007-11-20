
package virtuoso_driver;

import org.openrdf.sesame.admin.AdminListener;
import org.openrdf.model.Statement;

public class VirtuosoAdminListener implements AdminListener
{

    public void transactionStart()
    {
	System.out.println("Transaction start.");
    }

    public void transactionEnd()
    {
	System.out.println("Transaction end.");
    }

    public void status(String arg0, int arg1, int arg2)
    {
	System.out.println(
		"Status message at line "
		+ arg1
		+ ", column "
		+ arg2
		+ ": "
		+ arg0);
    }

    public void notification(String arg0, int arg1, int arg2, Statement arg3)
    {
	System.out.println(
		"Notification message at line "
		+ arg1
		+ ", column "
		+ arg2
		+ ": "
		+ arg0);
	if (arg3 != null)
	{
	    System.out.println(
		    "Statement is: "
		    + arg3.getSubject()
		    + " "
		    + arg3.getPredicate().getURI()
		    + " "
		    + arg3.getObject());
	}
    }

    public void warning(String arg0, int arg1, int arg2, Statement arg3)
    {
	System.out.println(
		"Warning message at line "
		+ arg1
		+ ", column "
		+ arg2
		+ ": "
		+ arg0);
	if (arg3 != null)
	{
	    System.out.println(
		    "Statement is: "
		    + arg3.getSubject()
		    + " "
		    + arg3.getPredicate().getURI()
		    + " "
		    + arg3.getObject());
	}
    }

    public void error(String arg0, int arg1, int arg2, Statement arg3)
    {
	System.out.println(
		"Error message at line " + arg1 + ", column " + arg2 + ": " + arg0);
	if (arg3 != null)
	{
	    System.out.println(
		    "Statement is: "
		    + arg3.getSubject()
		    + " "
		    + arg3.getPredicate().getURI()
		    + " "
		    + arg3.getObject());
	}
    }
}
