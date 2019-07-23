/*
 *  $Id: VirtuosoUpdateRequest.java,v 1.4.2.6 2012/03/15 12:56:34 source Exp $
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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

import java.util.*;
import java.io.*;
import java.net.*;
import java.sql.*;

import virtuoso.sql.*;

import com.hp.hpl.jena.update.*;
import com.hp.hpl.jena.shared.*;

import virtuoso.jdbc4.VirtuosoConnectionPoolDataSource;

public class VirtuosoUpdateRequest {
    private List requests = new ArrayList();
    private VirtGraph graph;
    private String virt_query;

    java.sql.Statement stmt = null;


    public VirtuosoUpdateRequest(VirtGraph _graph) {
        graph = _graph;
    }

    public VirtuosoUpdateRequest(String query, VirtGraph _graph) {
        this(_graph);
        virt_query = query;
        requests.add((Object) query);
    }

    public void exec() {
        try {
            stmt = graph.createStatement();

            for (Iterator iter = requests.iterator(); iter.hasNext(); ) {
                StringBuilder sb = new StringBuilder("sparql\n");
                graph.appendSparqlPrefixes(sb);
                sb.append((String) iter.next());
                stmt.addBatch(sb.toString());
            }
            stmt.executeBatch();
            stmt.clearBatch();
            requests.clear();
            stmt.close();
            stmt = null;
        } catch (Exception e) {
            throw new UpdateException("Convert results are FAILED.:", e);
        }

    }


    public void addUpdate(String update) {
        requests.add(update);
    }

    public Iterator iterator() {
        return requests.iterator();
    }

    public String toString() {
        StringBuffer b = new StringBuffer();

        for (Iterator iter = requests.iterator(); iter.hasNext(); ) {
            b.append((String) iter.next());
            b.append("\n");
        }
        return b.toString();
    }

}
