/*
 *  $Id$
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

package virtuoso.sesame.driver;

import java.util.Map;

import org.openrdf.model.Resource;
import org.openrdf.model.URI;
import org.openrdf.model.Value;
import org.openrdf.model.*;
import org.openrdf.sesame.admin.AdminListener;
import org.openrdf.sesame.sail.SailUpdateException;
import org.openrdf.sesame.sail.SailChangedListener;
import org.openrdf.sesame.sail.LiteralIterator;
import org.openrdf.sesame.sail.RdfSchemaSource;
import org.openrdf.sesame.sail.StatementIterator;
import org.openrdf.sesame.sail.NamespaceIterator;
import org.openrdf.sesame.sail.query.Query;
import org.openrdf.sesame.sail.query.QueryOptimizer;
import org.openrdf.sesame.sail.SailInitializationException;
import org.openrdf.sesame.sail.Namespace;
import org.openrdf.sesame.sail.SailInternalException;
import org.openrdf.sesame.sail.util.SailChangedEventImpl;
import org.openrdf.sesame.sail.RdfSource;

public class VirtuosoSchemaRepository implements org.openrdf.sesame.sail.RdfSchemaRepository
{
    private boolean _transactionStarted = false;

    private VirtuosoRepository _vRepository = null;
    private AdminListener listener;
    private static final String JDBC_URL_KEY = "jdbcUrl";
    private static final String USER_KEY = "user";
    private static final String PASSWORD_KEY = "password";
    private static final String GRAPH = "graphName";

    public void VirtuosoSchemaRepository ()
    {
//	logger.info("VirtuosoSchemaRepository ()");
    }

    public void startTransaction()
    {
//	logger.info("startTransaction ()");
	_transactionStarted = true;
    }

    public void commitTransaction()
    {
//	logger.info("commitTransaction ()");
	_transactionStarted = true;
    }

    public boolean transactionStarted()
    {
//	logger.info("transactionStarted ()");
	return _transactionStarted;
    }

    public void removeListener (SailChangedListener listener)
    {
//	logger.info("removeListener ()");
    }

    public void addListener(SailChangedListener listener)
    {
    }

    public void addStatement (Resource subj, URI pred, Value obj) throws SailUpdateException
    {
//	logger.info("addStatement ()");
	if (!transactionStarted())
	{
	    throw new SailUpdateException ("no transaction started.");
	}

	_vRepository.addSingleStatement (subj, pred, obj);

//	logger.info("Adding statement (" + subj + ", " + pred + ", " + obj + ")");
    }

    public int removeStatements (Resource subj, URI pred, Value obj) throws SailUpdateException
    {
//	logger.info("VirtuosoSchemaRepository.java removeStatements");

	if (!transactionStarted())
	{
	    throw new SailUpdateException("no transaction started.");
	}

	int removed = 0;

//	logger.info ("Removing " + removed + " statements (" + subj + ", " + pred + ", " + obj + ")");

	return removed;
    }

    public void clearRepository() throws SailUpdateException
    {
//	logger.info("clearRepository ()");
	if (!transactionStarted())
	{
	    throw new SailUpdateException("no transaction started.");
	}

	try
	{
	    _vRepository.clear(listener);
	}
	catch(Exception e)
	{
	    e.printStackTrace();
	}
    }

    public void changeNamespacePrefix(String namespace, String prefix) throws SailUpdateException
    {
//	logger.info("changeNamespacePrefix ()");
	if (!transactionStarted())
	{
	    throw new SailUpdateException("no transaction started.");
	}
    }

    public LiteralIterator getLiterals (String label, String language, URI datatype)
    {
//	logger.info("getLiterals ()");
	LiteralIterator ret = null;
	return ret;
    }

    public boolean isDirectType(Resource anInstance, Resource aClass)
    {
//	logger.info("isDirectType ()");
	return false;
    }

    public boolean isType (Resource anInstance, Resource aClass)
    {
//	logger.info("isType ()");
	return false;
    }

    public StatementIterator getDirectType(Resource anInstance, Resource aClass)
    {
//	logger.info("getDirectType ()");
	StatementIterator ret = null;
	return ret;
    }

    public StatementIterator getType(Resource anInstance, Resource aClass)
    {
//	logger.info("getType ()");
	StatementIterator ret = null;
	return ret;
    }

    public StatementIterator getRange(Resource prop, Resource domain)
    {
//	logger.info("getRange ()");
	StatementIterator ret = null;
	return ret;
    }

    public StatementIterator getDomain(Resource prop, Resource domain)
    {
//	logger.info("getRange ()");
	StatementIterator ret = null;
	return ret;
    }

    public boolean isClass(Resource resource)
    {
//	logger.info("isClass ()");
	return false;
    }

    public StatementIterator getProperties()
    {
//	logger.info("getProperties ()");
	StatementIterator ret = null;;
	return ret;
    }

    public boolean isProperty(Resource resource)
    {
//	logger.info("isProperty ()");
	return false;
    }

    public StatementIterator getSubClassOf(Resource subClass, Resource superClass)
    {
//	logger.info("getSubClassOf ()");
	StatementIterator ret = null;
	return ret;
    }

    public StatementIterator getDirectSubClassOf(Resource subClass, Resource superClass)
    {
//	logger.info("getDirectSubClassOf ()");
	StatementIterator ret = null;;
	return ret;
    }

    public boolean isSubClassOf(Resource subClass, Resource superClass)
    {
//	logger.info("isSubClassOf ()");
	return false;
    }

    public boolean isDirectSubClassOf(Resource subClass, Resource superClass)
    {
//	logger.info("isDirectSubClassOf ()");
	return false;
    }

    public StatementIterator getSubPropertyOf(Resource subProperty, Resource superProperty)
    {
//	logger.info("getSubPropertyOf ()");
	StatementIterator ret = null;
	return ret;
    }

    public StatementIterator getDirectSubPropertyOf(Resource subProperty, Resource superProperty)
    {
//	logger.info("getDirectSubPropertyOf ()");
	StatementIterator ret = null;;
	return ret;
    }

    public boolean isSubPropertyOf(Resource subProperty, Resource superProperty)
    {
//	logger.info("isSubPropertyOf ()");
	return false;
    }

    public boolean isDirectSubPropertyOf(Resource subProperty, Resource superProperty)
    {
//	logger.info("isDirectSubPropertyOf ()");
	return false;
    }

    public StatementIterator getExplicitStatements(Resource subj, URI pred, Value obj) {
//	logger.info("getExplicitStatements ()");
	StatementIterator ret = null;;
	return ret;
    }

    public boolean hasExplicitStatement(Resource subj, URI pred, Value obj)
    {
//	logger.info("hasExplicitStatement ()");
	return false;
    }

    public StatementIterator getClasses()
    {
//	logger.info("getClasses ()");
	StatementIterator ret = null;;
	return ret;
    }

    public NamespaceIterator getNamespaces()
    {
//	logger.info("getNamespaces ()");
	NamespaceIterator result = null;;

	result = _vRepository.getNamespaces();

	return result;
    }

    public Query optimizeQuery(Query qc)
    {
//	logger.info("optimizeQuery () " + qc);
	return qc;
    }

    public boolean hasStatement(Resource subj, URI pred, Value obj)
    {
//	logger.info("hasStatement ()");
	return false;
    }

    public StatementIterator getStatements(Resource subj, URI pred, Value obj)
    {
//	logger.info("getStatements ()");
	StatementIterator ret = null;;
	return ret;
    }

    public void shutDown()
    {
//	logger.info("shutDown ()");
    }

    public ValueFactory getValueFactory()
    {
//	logger.info("getValueFactory ()");
	return _vRepository.getValueFactory();
    }

    public void initialize(Map configParams) throws SailInitializationException
    {
	String jUrl = (String)configParams.get(JDBC_URL_KEY);
	String user = (String)configParams.get(USER_KEY);
	String password = (String)configParams.get(PASSWORD_KEY);
	String graph = (String)configParams.get(GRAPH);

//	logger.info("initialize () " + jUrl + " " + user + " " + password + " " + graph);

	if (_vRepository == null)
	{
	    _vRepository = new VirtuosoRepository (graph, jUrl, user, password);
	}
    }
}
