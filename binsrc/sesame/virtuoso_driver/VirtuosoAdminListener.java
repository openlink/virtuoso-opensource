/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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

package virtuoso.sesame.driver;

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
