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
import virtuoso.jdbc3.*;
import com.hp.hpl.jena.util.iterator.*;
import com.hp.hpl.jena.shared.*;
import com.hp.hpl.jena.graph.*;
import com.hp.hpl.jena.datatypes.*;
import com.hp.hpl.jena.rdf.model.*;

public class VirtResSetIter implements ExtendedIterator
{
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

    public VirtResSetIter(VirtGraph graph, ResultSet resultSet, TripleMatch in)
    {
        v_resultSet = resultSet;
	v_in = in;
	v_graph = graph;
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
            Object ret = next();
            remove();
	    return ret;
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


    private Node Object2Node(Object o)
    {
      if (o instanceof VirtuosoExtendedString) 
        {
          VirtuosoExtendedString vs = (VirtuosoExtendedString) o;
          if (vs.iriType == VirtuosoExtendedString.IRI) {
            if (vs.str.indexOf ("_:") == 0)
              return Node.createAnon(AnonId.create(vs.str.substring(2))); // _:
            else
              return Node.createURI(vs.str);
          } else if (vs.iriType == VirtuosoExtendedString.BNODE) {
            return Node.createAnon(AnonId.create(vs.str.substring(9))); // nodeID://
          } else {
            return Node.createLiteral(vs.str); 
          }
        }
      else if (o instanceof VirtuosoRdfBox)
        {
          VirtuosoRdfBox rb = (VirtuosoRdfBox)o;
          String rb_type = rb.getType();
          RDFDatatype dt = null;

          if ( rb_type != null)
            dt = TypeMapper.getInstance().getSafeTypeByName(rb_type);
          return Node.createLiteral(rb.toString(), rb.getLang(), dt);
        }
      else 
        {
          return Node.createLiteral(o.toString());
        }

    }

    protected void extractRow() throws Exception
    {
       Node NodeS, NodeP, NodeO;

       if (v_in.getMatchSubject() != null)
	   NodeS = v_in.getMatchSubject();
       else
           NodeS = Object2Node(v_resultSet.getObject("s"));

       if (v_in.getMatchPredicate() != null)
	   NodeP = v_in.getMatchPredicate();
       else
           NodeP = Object2Node(v_resultSet.getObject("p"));

       if (v_in.getMatchObject() != null)
	   NodeO = v_in.getMatchObject();
       else
           NodeO = Object2Node(v_resultSet.getObject("o"));

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
		    throw new JenaException(e);
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
