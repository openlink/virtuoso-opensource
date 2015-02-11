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


import java.sql.SQLException;
import java.sql.PreparedStatement;
import java.util.Iterator;
import java.util.List;
import javax.sql.*;

import com.hp.hpl.jena.graph.*;
import com.hp.hpl.jena.graph.impl.*;
import com.hp.hpl.jena.shared.*;
import com.hp.hpl.jena.util.iterator.*;
import com.hp.hpl.jena.datatypes.*;
import com.hp.hpl.jena.rdf.model.*;
import com.hp.hpl.jena.rdf.model.impl.*;


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
	

    public int getBatchSize()
    {
    	return ((VirtGraph)this.graph).getBatchSize();
    }


    public void setBatchSize(int sz)
    {
    	((VirtGraph)this.graph).setBatchSize(sz);
    }


    public String getSparqlPrefix()
    {
    	return ((VirtGraph)this.graph).getSparqlPrefix();
    }


    public void setSparqlPrefix(String val)
    {
    	((VirtGraph)this.graph).setSparqlPrefix(val);
    }




    public Model add( Statement [] statements )
    {
      VirtGraph _g=(VirtGraph)this.graph;
      String _gName = _g.getGraphName();
      PreparedStatement ps = null;
      try {
        ps = _g.prepareStatement(_g.S_BATCH_INSERT);

        int count = 0;
        for(int i=0; i < statements.length; i++)
        {
          Statement s = statements[i];

          _g.bindBatchParams(ps, s.getSubject().asNode(), 
          		s.getPredicate().asNode(),
          		s.getObject().asNode(), _gName);
          ps.addBatch();
          count++;

          if (count > _g.batchSize) {
	    ps.executeBatch();
	    ps.clearBatch();
            count = 0;
            if (_g.useReprepare) {
               try {
                 ps.close();
                 ps = null;
               } catch(Exception e){}
               ps = _g.prepareStatement(_g.S_BATCH_INSERT);
            }
          }
        }

        if (count > 0) 
        {
	  ps.executeBatch();
	  ps.clearBatch();
        }

      }	catch(Exception e) {
        throw new JenaException(e);
      } finally {
        if (ps!=null)
          try {
            ps.close();
          } catch (SQLException e){}
      }
      return this;
    }

    @Override
    public Model add( List<Statement> statements )
    {
      return add(statements.iterator());
    }

    @Override
    public Model add(StmtIterator iter)
    {  
      return add((Iterator<Statement>)iter);
    }

    protected Model add(Iterator<Statement> it)
    {  
      VirtGraph _g=(VirtGraph)this.graph;
      String _gName = _g.getGraphName();
      PreparedStatement ps = null;
      try {
        ps = _g.prepareStatement(_g.S_BATCH_INSERT);

        int count = 0;
        while (it.hasNext())
        {
          Statement s = (Statement) it.next();

          _g.bindBatchParams(ps, s.getSubject().asNode(), 
          		s.getPredicate().asNode(),
          		s.getObject().asNode(), _gName);
          ps.addBatch();
          count++;

          if (count > _g.BATCH_SIZE) {
	    ps.executeBatch();
	    ps.clearBatch();
            count = 0;
            if (_g.useReprepare) {
               try {
                 ps.close();
                 ps = null;
               } catch(Exception e){}
               ps = _g.prepareStatement(_g.S_BATCH_INSERT);
            }
          }
        }

        if (count > 0) 
        {
	  ps.executeBatch();
	  ps.clearBatch();
        }

      }	catch(Exception e) {
        throw new JenaException(e);
      } finally {
        if (ps!=null)
          try {
            ps.close();
          } catch (SQLException e){}
      }
      return this;
    }

    @Override
    public Model add(Model m)
    {
      return add(m.listStatements());
    }


    @Override
    public Model remove( Statement [] statements )
    {
      VirtGraph _g=(VirtGraph)this.graph;
      String _gname = _g.getGraphName();
      String del_start = "sparql define output:format '_JAVA_' DELETE FROM <";
      java.sql.Statement stmt = null;
      int count = 0;
      StringBuilder data = new StringBuilder(256);

      data.append(del_start);
      data.append(_g.getGraphName());
      data.append("> { ");

      try {
        stmt = _g.createStatement();

        for(int i=0; i < statements.length; i++)
        {
          Statement s = statements[i];

          StringBuilder row = new StringBuilder(256);
          row.append(VirtGraph.Node2Str(s.getSubject().asNode()));
          row.append(' ');
          row.append(VirtGraph.Node2Str(s.getPredicate().asNode()));
          row.append(' ');
          row.append(VirtGraph.Node2Str(s.getObject().asNode()));
          row.append(" .\n");

          if (count > 0 && data.length()+row.length() > _g.MAX_CMD_SIZE) {
            data.append(" }");
	    stmt.execute(data.toString());

	    data.setLength(0);
            data.append(del_start);
            data.append(_gname);
            data.append("> { ");
            count = 0;
          }

          data.append(row);
          count++;
        }

        if (count > 0) 
        {
          data.append(" }");
	  stmt.execute(data.toString());
        }

      }	catch(Exception e) {
        throw new JenaException(e);
      } finally {
        try {
          stmt.close();
        } catch (Exception e) {}
      }
      return this;
    }

    @Override
    public Model remove( List<Statement> statements )
    {
      return remove(statements.iterator());
    }

    protected Model remove(Iterator<Statement> it)
    {  
      VirtGraph _g=(VirtGraph)this.graph;
      String _gname = _g.getGraphName();
      String del_start = "sparql define output:format '_JAVA_' DELETE FROM <";
      java.sql.Statement stmt = null;
      int count = 0;
      StringBuilder data = new StringBuilder(256);

      data.append(del_start);
      data.append(_g.getGraphName());
      data.append("> { ");

      try {
        stmt = _g.createStatement();

        while (it.hasNext())
        {
          Statement s = it.next();

          StringBuilder row = new StringBuilder(256);
          row.append(VirtGraph.Node2Str(s.getSubject().asNode()));
          row.append(' ');
          row.append(VirtGraph.Node2Str(s.getPredicate().asNode()));
          row.append(' ');
          row.append(VirtGraph.Node2Str(s.getObject().asNode()));
          row.append(" .\n");

          if (count > 0 && data.length()+row.length() > _g.MAX_CMD_SIZE) {
            data.append(" }");
	    stmt.execute(data.toString());

	    data.setLength(0);
            data.append(del_start);
            data.append(_gname);
            data.append("> { ");
            count = 0;
          }

          data.append(row);
          count++;
        }

        if (count > 0) 
        {
          data.append(" }");
	  stmt.execute(data.toString());
        }

      }	catch(Exception e) {
        throw new JenaException(e);
      } finally {
        try {
          stmt.close();
        } catch (Exception e) {}
      }
      return this;
    }


}
