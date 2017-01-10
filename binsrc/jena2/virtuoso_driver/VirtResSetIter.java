/*
 *  $Id: VirtResSetIter.java,v 1.8.2.3 2012/03/08 12:55:00 source Exp $
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

package virtuoso.jena.driver;

import java.sql.*;
import java.util.*;
import virtuoso.sql.*;
import com.hp.hpl.jena.util.iterator.*;
import com.hp.hpl.jena.shared.*;
import com.hp.hpl.jena.graph.*;
import com.hp.hpl.jena.datatypes.*;
import com.hp.hpl.jena.rdf.model.*;


public class VirtResSetIter extends NiceIterator<Triple>
{
    protected java.sql.Statement v_stmt;
    protected ResultSet 	v_resultSet;
    protected Triple 		v_row;
    protected TripleMatch 	v_in;
    protected boolean 		v_finished = false;
    protected boolean 		v_prefetched = false;
    protected VirtGraph         v_graph = null;

    public VirtResSetIter()
    {
        v_finished = true;
    }

    public VirtResSetIter(VirtGraph graph, java.sql.Statement stmt, ResultSet resultSet, TripleMatch in)
    {
        v_stmt = stmt;
        v_resultSet = resultSet;
	v_in = in;
	v_graph = graph;
    }


    public boolean hasNext()
    {
        if (!v_finished && !v_prefetched) moveForward();
        return !v_finished;
    }

    public Triple removeNext()
        {
            Triple ret = next();
            remove();
	    return ret;
	}

    public Triple next()
    {
        if (!v_finished && !v_prefetched)
	    moveForward();

        v_prefetched = false;

        if (v_finished)
            throw new NoSuchElementException();

        return getRow();
    }

    public void remove()
    {
        if (v_row != null && v_graph != null)
          {
            v_graph.delete(v_row);
            v_row = null;
          }
    }

    protected void moveForward()
    {
	try
	{
	    if (!v_finished && v_resultSet.next())
	    {
		extractRow();
		v_prefetched = true;
	    }
	    else
		close();
	}
	catch (Exception e)
	{
	    throw new JenaException(e);
	}
    }


    protected void extractRow() throws Exception
    {
       Node NodeS, NodeP, NodeO;

       if (v_in.getMatchSubject() != null)
	   NodeS = v_in.getMatchSubject();
       else
           NodeS = VirtGraph.Object2Node(v_resultSet.getObject("s"));

       if (v_in.getMatchPredicate() != null)
	   NodeP = v_in.getMatchPredicate();
       else
           NodeP = VirtGraph.Object2Node(v_resultSet.getObject("p"));

       if (v_in.getMatchObject() != null)
	   NodeO = v_in.getMatchObject();
       else
           NodeO = VirtGraph.Object2Node(v_resultSet.getObject("o"));

       v_row = new Triple(NodeS, NodeP, NodeO);
    }

    protected Triple getRow()
    {
        return v_row;
    }

    public void close()
    {
	if (!v_finished)
	{
	    if (v_resultSet != null)
	    {
		try
		{
		    v_resultSet.close();
		    v_resultSet = null;
		}
		catch (SQLException e)
		{
		    throw new JenaException(e);
		}
	    }
	    if (v_stmt != null)
	    {
		try
		{
		    v_stmt.close();
		    v_stmt = null;
		}
		catch (SQLException e) {}
	    }
	}
	v_finished = true;
    }


    protected void finalize() throws SQLException
    {
	if (!v_finished && v_resultSet != null) close();
    }

}
