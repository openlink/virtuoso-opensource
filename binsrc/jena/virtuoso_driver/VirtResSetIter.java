/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2008 OpenLink Software
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
import com.hp.hpl.jena.util.iterator.*;
import com.hp.hpl.jena.shared.*;
import com.hp.hpl.jena.graph.*;

public class VirtResSetIter implements ExtendedIterator
{
//??Compare with 
//??  return new ExtendedStatementIterator(new IteratorWrapper<Statement>(stit.asCollection().iterator()));

    protected ResultSet 	v_resultSet;
    protected Triple 		v_row;
    protected TripleMatch 	v_in;
    protected boolean 		v_finished = false;
    protected boolean 		v_prefetched = false;

    public VirtResSetIter()
    {
        v_finished = true;
    }

    public VirtResSetIter(ResultSet resultSet, TripleMatch in)
    {
        v_resultSet = resultSet;
	v_in = in;
    }

    public void reset(ResultSet resultSet, PreparedStatement sourceStatement)
    {
        v_resultSet = resultSet;
        v_finished = false;
        v_prefetched = false;
        v_row = null;
    }

    public boolean hasNext()
    {
        if (!v_finished && !v_prefetched) moveForward();
        return !v_finished;
    }

    public Object removeNext()
        {
	    return null;
	}

    public Object next()
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
	    e.printStackTrace();
	    System.exit(-1);
	}
    }

    protected void extractRow() throws Exception
    {
       Node NodeS, NodeP, NodeO;

       if (v_in.getMatchSubject() != null)
	   NodeS = v_in.getMatchSubject();
       else
	   NodeS = Node.createURI (v_resultSet.getString("s"));

       if (v_in.getMatchPredicate() != null)
	   NodeP = v_in.getMatchPredicate();
       else
	   NodeP = Node.createURI (v_resultSet.getString("p"));

       if (v_in.getMatchObject() != null)
	   NodeO = v_in.getMatchObject();
       else
	   NodeO = Node.createURI (v_resultSet.getString("o"));

       v_row = new Triple(NodeS, NodeP, NodeO);
    }

    protected Object getRow()
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
		    e.printStackTrace();
		    System.exit(-1);
		}
	    }
	}
	v_finished = true;
    }

    public Object getSingleton() throws SQLException
    {
        List row = (List) next();
        close();
        return row.get(0);
    }

    protected void finalize() throws SQLException
    {
	if (!v_finished && v_resultSet != null) close();
    }

    public ExtendedIterator andThen(ClosableIterator other)
    {
	return NiceIterator.andThen (this, other);
    }

    public Set toSet()
    {
	return NiceIterator.asSet (this);
    }

    public List toList()
    {
	return NiceIterator.asList (this);
    }

    public ExtendedIterator filterKeep (Filter f)
    {
	return new FilterIterator (f, this);
    }

    public ExtendedIterator filterDrop (final Filter f)
    {
	return new FilterIterator (null, this);
    }

    public ExtendedIterator mapWith (Map1 map1)
    {
	return new Map1Iterator (map1, this);
    }

}
