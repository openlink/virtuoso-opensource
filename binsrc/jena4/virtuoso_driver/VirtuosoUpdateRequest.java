/*
 *  $Id:$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2023 OpenLink Software
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

import org.apache.jena.update.*;

public class VirtuosoUpdateRequest {
    private List<String> requests = new ArrayList<String>();
    private VirtGraph graph;
    private String virt_query;


    public VirtuosoUpdateRequest(VirtGraph _graph) {
        graph = _graph;
    }

    public VirtuosoUpdateRequest(String query, VirtGraph _graph) {
        this(_graph);
        virt_query = query;
        requests.add(query);
    }

    public void exec() {
        java.sql.Statement stmt = null;
        try {
            stmt = graph.createStatement(true);
            for ( Iterator<String> iter = requests.iterator() ; iter.hasNext(); )
            {
                StringBuilder sb = new StringBuilder();
                sb.append("sparql\n");
                graph.appendSparqlPrefixes(sb, false);
                sb.append((String) iter.next());
                stmt.addBatch(sb.toString());
            }
            stmt.executeBatch();
            stmt.clearBatch();
            requests.clear();
        } catch (Exception e) {
            throw new UpdateException("Convert results are FAILED.:", e);
        } finally {
          try {
            if (stmt != null)
              stmt.close();
          } catch (Exception e) { }
          stmt = null;
        }
    }


    public void addUpdate(String update) {
        requests.add(update);
    }

    public Iterator<String> iterator() {
        return requests.iterator();
    }

    public String toString() {
        StringBuffer b = new StringBuffer();

        for (Iterator<String> iter = requests.iterator(); iter.hasNext(); ) {
            b.append((String) iter.next());
            b.append("\n");
        }
        return b.toString();
    }

}
