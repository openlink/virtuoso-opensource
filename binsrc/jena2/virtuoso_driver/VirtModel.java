/*
 *  $Id: VirtModel.java,v 1.1.2.6 2012/03/08 12:55:00 source Exp $
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


import javax.sql.*;
import com.hp.hpl.jena.graph.Graph;
import com.hp.hpl.jena.rdf.model.Model;
import com.hp.hpl.jena.rdf.model.impl.ModelCom;

import virtuoso.jdbc4.VirtuosoDataSource;

public class VirtModel extends ModelCom {

    /**
     * @param base
     */
    public VirtModel(VirtGraph base) 
    {
        super(base);
    }
	
	
    public static VirtModel openDefaultModel(ConnectionPoolDataSource ds) 
    {
    	return new VirtModel(new VirtGraph(ds));
    }

    public static VirtModel openDatabaseModel(String graphName, 
	ConnectionPoolDataSource ds)
    {
	return new VirtModel(new VirtGraph(graphName, ds));
    }


    public static VirtModel openDefaultModel(DataSource ds) 
    {
    	return new VirtModel(new VirtGraph(ds));
    }

    public static VirtModel openDatabaseModel(String graphName, 
	DataSource ds)
    {
	return new VirtModel(new VirtGraph(graphName, ds));
    }


    public static VirtModel openDefaultModel(String url, String user, 
	String password) 
    {
    	return new VirtModel(new VirtGraph(url, user, password));
    }

    public static VirtModel openDatabaseModel(String graphName, String url, 
    	String user, String password) 
    {
	return new VirtModel(new VirtGraph(graphName, url, user, password));
    }

    @Override
    public Model removeAll() 
    {
	try {
	        VirtGraph _graph=(VirtGraph)this.graph;
	        _graph.clear();
	} catch (ClassCastException e) {
		super.removeAll();
	}
	return this;
    }


    public void createRuleSet(String ruleSetName, String uriGraphRuleSet) 
    {
        ((VirtGraph)this.graph).createRuleSet(ruleSetName, uriGraphRuleSet);
    }


    public void removeRuleSet(String ruleSetName, String uriGraphRuleSet) 
    {
        ((VirtGraph)this.graph).removeRuleSet(ruleSetName, uriGraphRuleSet);
    }

    public void setRuleSet(String _ruleSet)
    {
        ((VirtGraph)this.graph).setRuleSet(_ruleSet);
    }

    public void setSameAs(boolean _sameAs)
    {
        ((VirtGraph)this.graph).setSameAs(_sameAs);
    }
	
}
