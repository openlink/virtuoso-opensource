/*
 *  $Id:$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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
import org.apache.jena.util.iterator.*;
import org.apache.jena.shared.*;
import org.apache.jena.graph.*;
import org.apache.jena.datatypes.*;
import org.apache.jena.rdf.model.*;
import org.apache.jena.sparql.core.Quad;


public class VirtResSetIter3 implements Iterator<Quad> {
    protected java.sql.Statement v_stmt;
    protected ResultSet v_resultSet;
    protected Quad v_row;
    protected boolean v_finished = false;
    protected boolean v_prefetched = false;
    protected VirtGraph v_graph = null;

    public VirtResSetIter3() {
        v_finished = true;
    }

    public VirtResSetIter3(VirtGraph graph, java.sql.Statement stmt, ResultSet resultSet) {
        v_stmt = stmt;
        v_resultSet = resultSet;
        v_graph = graph;
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
            if (!v_finished && v_resultSet.next()) {
                extractRow();
                v_prefetched = true;
            } else
                close();
        } catch (Exception e) {
            throw new JenaException(e);
        }
    }


    protected void extractRow() throws Exception {
        Node NodeG, NodeS, NodeP, NodeO;

        NodeS = VirtGraph.Object2Node(v_resultSet.getObject(1));
        NodeP = VirtGraph.Object2Node(v_resultSet.getObject(2));
        NodeO = VirtGraph.Object2Node(v_resultSet.getObject(3));
        NodeG = VirtGraph.Object2Node(v_resultSet.getObject(4));

        v_row = new Quad(NodeG, NodeS, NodeP, NodeO);
    }

    protected Quad getRow() {
        return v_row;
    }

    public void close() {
        if (!v_finished) {
            if (v_resultSet != null) {
                try {
                    v_resultSet.close();
                    v_resultSet = null;
                } catch (SQLException e) {
                    throw new JenaException(e);
                }
            }
            if (v_stmt != null) {
                try {
                    v_stmt.close();
                    v_stmt = null;
                } catch (SQLException e) {
                }
            }
        }
        v_finished = true;
    }


    protected void finalize() throws SQLException {
        if (!v_finished && v_resultSet != null) close();
    }

}
