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
import java.util.Iterator;
import java.util.List;


import com.hp.hpl.jena.graph.Graph;
import com.hp.hpl.jena.graph.GraphUtil;
import com.hp.hpl.jena.graph.Node;
import com.hp.hpl.jena.graph.Triple;
import com.hp.hpl.jena.graph.impl.SimpleBulkUpdateHandler;
import com.hp.hpl.jena.util.iterator.ExtendedIterator;


public class VirtBulkUpdateHandler extends SimpleBulkUpdateHandler {

    public VirtBulkUpdateHandler(VirtGraph parent) {
	super(parent);
    }

    public void add( Triple [] triples ) { 
	VirtGraph _graph=(VirtGraph)this.graph;
	try {
		_graph.getConnection().setAutoCommit(false);

        	for (int i = 0; i < triples.length; i += 1) 
        		_graph.performAdd( triples[i] ); 
		_graph.getConnection().commit();
		_graph.getConnection().setAutoCommit(true);
	} catch (Exception e) {
		throw new RuntimeException("Couldn't create transaction",e);
	}
        manager.notifyAddArray( graph, triples );
    }

    @Override
    protected void add(List triples, boolean notify) {
	VirtGraph _graph=(VirtGraph)this.graph;
	try {
		_graph.getConnection().setAutoCommit(false);
		for (Iterator i = triples.iterator(); i.hasNext(); ) {
			Triple trip = (Triple) i.next();
			_graph.performAdd(trip);
		}
		_graph.getConnection().commit();
		_graph.getConnection().setAutoCommit(true);
	} catch (Exception e) {
		throw new RuntimeException("Couldn't create transaction",e);
	}
	if (notify) 
		manager.notifyAddList( graph, triples );
    }

    

    public void delete( Triple [] triples ) { 
	VirtGraph _graph=(VirtGraph)this.graph;
	try {
		_graph.getConnection().setAutoCommit(false);
        	for (int i = 0; i < triples.length; i += 1) 
        		_graph.performDelete( triples[i] ); 
		_graph.getConnection().commit();
		_graph.getConnection().setAutoCommit(true);
	} catch (Exception e) {
		throw new RuntimeException("Couldn't create transaction",e);
	}
        manager.notifyDeleteArray( graph, triples );
    }
    

    protected void delete( List triples, boolean notify ) { 
	VirtGraph _graph=(VirtGraph)this.graph;
	try {
		_graph.getConnection().setAutoCommit(false);
        	for (int i = 0; i < triples.size(); i += 1) 
        		graph.performDelete( (Triple) triples.get(i) );
		_graph.getConnection().commit();
		_graph.getConnection().setAutoCommit(true);
	} catch (Exception e) {
		throw new RuntimeException("Couldn't create transaction",e);
	}
        if (notify) 
        	manager.notifyDeleteList( graph, triples );
    }
    

}
