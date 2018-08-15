/*
 *  $Id:$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

import java.util.List;

import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.InputStream;
import java.io.Reader;

import org.apache.jena.update.*;
import org.apache.jena.util.FileUtils;
import org.apache.jena.rdf.model.Model;
import org.apache.jena.query.Dataset;

public class VirtuosoUpdateFactory {

    private VirtuosoUpdateFactory() {
    }

    /**
     * Create an UpdateRequest by parsing the given string
     */
    static public VirtuosoUpdateRequest create(String query, VirtGraph graph) {
        return new VirtuosoUpdateRequest(query, graph);
    }

    static public VirtuosoUpdateRequest create(String query, Dataset dataset) {
        checkNotNull(dataset, "dataset is a null pointer");
        checkNotNull(query, "query string is null");
        if (dataset instanceof VirtDataset) {
            return new VirtuosoUpdateRequest(query, (VirtGraph) dataset);
        } else {
            throw new UpdateException("Only VirtDataset is supported");
        }
    }

    static public VirtuosoUpdateRequest create(String queryStr, Model model) {
        checkNotNull(model, "model is a null pointer");
        checkNotNull(queryStr, "query string is null");
        if (model.getGraph() instanceof VirtGraph) {
            return new VirtuosoUpdateRequest(queryStr, (VirtGraph) model.getGraph());
        } else {
            throw new UpdateException("Only VirtModel is supported");
        }
    }


    /**
     * Create an UpdateRequest by reading it from a file
     */
    public static VirtuosoUpdateRequest read(String fileName, VirtGraph graph) {
        InputStream in = null;
        if (fileName.equals("-"))
            in = System.in;
        else
            try {
                in = new FileInputStream(fileName);
            } catch (FileNotFoundException ex) {
                throw new UpdateException("File nout found: " + fileName);
            }
        return read(in, graph);
    }

    /**
     * Create an UpdateRequest by reading it from an InputStream (note that conversion to UTF-8 will be applied automatically)
     */
    public static VirtuosoUpdateRequest read(InputStream in, VirtGraph graph) {
        Reader r = FileUtils.asBufferedUTF8(in);
        StringBuffer b = new StringBuffer();
        char ch;
        try {
            while ((ch = (char) r.read()) != -1)
                b.append(ch);
        } catch (Exception e) {
            throw new UpdateException(e);
        }
        return new VirtuosoUpdateRequest(b.toString(), graph);
    }


    static private void checkNotNull(Object obj, String msg) {
        if (obj == null)
            throw new IllegalArgumentException(msg);
    }
}

