/*
 *  $Id: VirtPrefixMapping.java,v 1.3.2.3 2012/03/08 12:55:00 source Exp $
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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
import java.io.*;
import java.util.*;
import java.util.Iterator;

import virtuoso.sql.*;

import java.util.Iterator;
import java.util.Map;

import com.hp.hpl.jena.shared.*;
import com.hp.hpl.jena.shared.PrefixMapping;
import com.hp.hpl.jena.shared.impl.PrefixMappingImpl;

public class VirtPrefixMapping extends PrefixMappingImpl {

	protected VirtGraph m_graph = null;
	
	/**
	 * Constructor for a persistent prefix mapping.
	 * 
	 */
	public VirtPrefixMapping( VirtGraph graph) 
	{
	  super();
	  m_graph = graph;
		
	  // Populate the prefix map using data from the 
	  // persistent graph properties
	  String query = "DB.DBA.XML_SELECT_ALL_NS_DECLS (3)";
	  try {
	    Statement stmt = m_graph.createStatement();
	    ResultSet rs = stmt.executeQuery(query);

  	    while (rs.next()) {
	      String prefix = rs.getString(1);
	      String uri = rs.getString(2);
	      if (uri != null && uri != null)
	        super.setNsPrefix(prefix, uri);
	    }
	    rs.close();
	  } catch (Exception e) {
	     throw new JenaException(e);
	  } 
	}

        public PrefixMapping removeNsPrefix( String prefix )
        {
	  String query = "DB.DBA.XML_REMOVE_NS_BY_PREFIX(?, 1)";
          super.removeNsPrefix( prefix );

	  try {
	    PreparedStatement ps = m_graph.prepareStatement(query);
	    ps.setString(1, prefix);
	    ps.execute();
	    ps.close();
	  } catch (Exception e) {
	     throw new JenaException(e);
	  } 

          return this;
        }
    
	/* (non-Javadoc)
	 * Override the default implementation so we can catch the write operation
	 * and update the persistent store.
	 * @see com.hp.hpl.jena.shared.PrefixMapping#setNsPrefix(java.lang.String, java.lang.String)
	 */
	public PrefixMapping setNsPrefix(String prefix, String uri) 
	{
	  super.setNsPrefix(prefix, uri);

	  String query = "DB.DBA.XML_SET_NS_DECL(?, ?, 1)";
		
	  // All went well, so persist the prefix by adding it to the graph properties
	  // (the addPrefix call will overwrite any existing mapping with the same prefix
	  // so it matches the behaviour of the prefixMappingImpl).
	  try {
	    PreparedStatement ps = m_graph.prepareStatement(query);
	    ps.setString(1, prefix);
	    ps.setString(2, uri);
	    ps.execute();
	    ps.close();
	  } catch (Exception e) {
	     throw new JenaException(e.toString());
	  } 
          return this;
	}

	public PrefixMapping setNsPrefixes(PrefixMapping other) 
	{
	  return setNsPrefixes(other.getNsPrefixMap());
	}

	public PrefixMapping setNsPrefixes(Map other) 
	{
          checkUnlocked();
	  Iterator it = other.entrySet().iterator();
	  while (it.hasNext()) {
	 	Map.Entry e = (Map.Entry) it.next();
		setNsPrefix((String) e.getKey(), (String) e.getValue());
	  }
          return this;
	}
}
