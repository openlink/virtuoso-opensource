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
package virtuoso.jena.driver;

import java.sql.*;
import java.util.Iterator;
import java.util.List;
import java.util.Arrays;
import java.util.ArrayList;


import com.hp.hpl.jena.shared.*;
import com.hp.hpl.jena.graph.*;
import com.hp.hpl.jena.graph.impl.SimpleBulkUpdateHandler;
import com.hp.hpl.jena.util.iterator.ExtendedIterator;
import com.hp.hpl.jena.util.IteratorCollection;


public class VirtBulkUpdateHandler extends SimpleBulkUpdateHandler {

    public VirtBulkUpdateHandler(VirtGraph parent) {
	super(parent);
    }

//--java5 or newer    @Override
    public void add( Triple [] triples ) { 
        addIterator(Arrays.asList(triples).iterator(), false);
        manager.notifyAddArray( graph, triples );
    }

//--java5 or newer    @Override
    protected void add(List<Triple> triples, boolean notify) {
        addIterator(triples.iterator(), false);
        if (notify)
        	manager.notifyAddList( graph, triples );
    }

//--java5 or newer    @Override
    public void addIterator(Iterator<Triple> it, boolean notify) {
	VirtGraph _graph=(VirtGraph)this.graph;
	List list = notify ? new ArrayList() : null;

	_graph.add(null, it, list);

	if (notify)
		manager.notifyAddIterator( graph, list);
    }
    

    public void delete( Triple [] triples ) { 
	deleteIterator(Arrays.asList(triples).iterator(), false);
        manager.notifyDeleteArray( graph, triples );
    }
    

    protected void delete( List<Triple> triples, boolean notify ) { 
        deleteIterator(triples.iterator(), false);
        if (notify)
        	manager.notifyDeleteList( graph, triples );
    }
    

    public void deleteIterator( Iterator<Triple> it, boolean notify ) { 
	VirtGraph _graph=(VirtGraph)this.graph;
	List list = notify ? new ArrayList() : null;

	_graph.delete(it, list);

        if (notify) 
        	manager.notifyDeleteIterator( graph, list);
    }
    
    public void removeAll() { 
	VirtGraph _graph=(VirtGraph)this.graph;
        _graph.clearGraph(_graph.getGraphName()); 
        notifyRemoveAll(); 
    }

    public void remove( Node s, Node p, Node o ) { 
	VirtGraph _graph=(VirtGraph)this.graph;
        _graph.delete_match(Triple.createMatch(s, p, o));
        manager.notifyEvent( graph, GraphEvents.remove( s, p, o ) ); 
    }
}
