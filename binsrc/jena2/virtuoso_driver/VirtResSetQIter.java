/*
 *  $Id: VirtResSetQIter.java,v 1.8.2.3 2012/03/08 12:55:00 source Exp $
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

package virtuoso.jena.driver;

import java.sql.*;
import java.util.*;

import virtuoso.sql.*;
import com.hp.hpl.jena.util.iterator.*;
import com.hp.hpl.jena.shared.*;
import com.hp.hpl.jena.graph.*;
import com.hp.hpl.jena.datatypes.*;
import com.hp.hpl.jena.rdf.model.*;
import com.hp.hpl.jena.sparql.core.*;


public class VirtResSetQIter implements ClosableIterator<Quad> {
    protected Quad v_row;
    protected TripleMatch v_in;
    protected boolean v_finished = false;
    protected boolean v_prefetched = false;
    protected VirtGraph v_graph = null;
    protected Iterator<Node> v_gList = null;
    protected Node v_curGraph = null;
    protected ExtendedIterator<Triple> v_curTriples = null;

    public VirtResSetQIter() {
        v_finished = true;
    }

    public VirtResSetQIter(VirtGraph graph, Iterator<Node> graphList, TripleMatch in) {
        v_in = in;
        v_graph = graph;
        v_gList = graphList;
        if (v_gList.hasNext()) {
            v_curGraph = v_gList.next();
            v_curTriples = v_graph.graphBaseFind(v_curGraph.toString(), v_in);
        }
    }

    public boolean hasNext() {
        if (!v_finished && !v_prefetched) moveForward();
        return !v_finished;
    }


    public Quad next() {
        if (!v_finished && !v_prefetched)
            moveForward();

        v_prefetched = false;

        if (v_finished)
            throw new NoSuchElementException();

        return getRow();
    }

    public void remove() {
        if (v_row != null && v_graph != null) {
            v_graph.performDelete(v_row.getGraph().toString(), v_row.getSubject(), v_row.getPredicate(), v_row.getObject());
            v_row = null;
        }
    }

    protected void moveForward() {
        try {
            if (!v_finished && v_curTriples != null) {
                if (v_curTriples.hasNext()) {
                    extractRow();
                    v_prefetched = true;
                } else if (v_gList.hasNext()) {
                    while (true) {
                        v_curTriples.close();
                        v_curGraph = v_gList.next();
                        v_curTriples = v_graph.graphBaseFind(v_curGraph.toString(), v_in);
                        if (v_curTriples.hasNext()) {
                            extractRow();
                            v_prefetched = true;
                            break;
                        }
                    }
                } else {
                    close();
                }
            } else
                close();
        } catch (Exception e) {
            throw new JenaException(e);
        }
    }


    protected void extractRow() throws Exception {
        Triple t = v_curTriples.next();
        v_row = new Quad(v_curGraph, t.getSubject(), t.getPredicate(), t.getObject());
    }

    protected Quad getRow() {
        return v_row;
    }

    public void close() {
        if (!v_finished) {
            if (v_curTriples != null) {
                try {
                    v_curTriples.close();
                    v_curTriples = null;
                } catch (Exception e) {
                    throw new JenaException(e);
                }
            }
        }
        v_finished = true;
    }


    protected void finalize() throws SQLException {
        if (!v_finished && v_curTriples != null) close();
    }

}
