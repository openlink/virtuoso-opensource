/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

import com.hp.hpl.jena.update.*;
import com.hp.hpl.jena.util.FileUtils;

public class VirtuosoUpdateFactory
{

    private VirtuosoUpdateFactory()
    {
    }

    /** Create an UpdateRequest by parsing the given string */
    static public VirtuosoUpdateRequest create(String query, VirtGraph graph)
    {
	return new VirtuosoUpdateRequest (query, graph);
    }


    /** Create an UpdateRequest by reading it from a file */
    public static VirtuosoUpdateRequest read(String fileName, VirtGraph graph)
    { 
        InputStream in = null ;
        if ( fileName.equals("-") )
            in = System.in ;
        else
            try
            {
                in = new FileInputStream(fileName) ;
            } catch (FileNotFoundException ex)
            {
                throw new UpdateException("File nout found: "+fileName) ;
            }
        return read(in, graph) ;
    }
    
    /** Create an UpdateRequest by reading it from an InputStream (note that conversion to UTF-8 will be applied automatically) */
    public static VirtuosoUpdateRequest read(InputStream in, VirtGraph graph)
    {
        Reader r= FileUtils.asBufferedUTF8(in);
        StringBuffer b = new StringBuffer();
        char ch;
        try {
          while( (ch = (char)r.read()) != -1) 
             b.append(ch);
        } catch (Exception e) {
           throw new UpdateException(e) ;
        }
        return new VirtuosoUpdateRequest(b.toString(), graph);
    }

}

