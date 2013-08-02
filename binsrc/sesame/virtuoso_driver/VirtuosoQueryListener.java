/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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
