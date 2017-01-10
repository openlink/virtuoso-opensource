/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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
