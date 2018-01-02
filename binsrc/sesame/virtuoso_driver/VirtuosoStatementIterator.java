/*
 *  $Id$
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

package virtuoso.sesame.driver;

import virtuoso.jdbc3.*;

import org.openrdf.model.Statement;
import org.openrdf.sesame.sail.StatementIterator;
import org.openrdf.sesame.query.QueryResultsTableBuilder;
import org.openrdf.sesame.sailimpl.memory.*;

class VirtuosoStatementIterator implements StatementIterator
{
    private StatementList _statements;
    private int _statementCount;
    private int _nextStatementIdx;
    private ResourceNode _subject;
    private URINode _predicate;
    private ValueNode _object;
    private boolean _explicitOnly;

    public VirtuosoStatementIterator(VirtuosoRepository _vRepository, StatementList statements)
    {
	this(statements, null, null, null, false);
	QueryResultsTableBuilder builder = new QueryResultsTableBuilder();
	try
	{
	    _vRepository.performTableQuery(null, "sss", builder);
	}
	catch(Exception e)
	{
	    e.printStackTrace();
	}
	builder.getQueryResultsTable();
    }

    public VirtuosoStatementIterator(StatementList statements,
	    ResourceNode subject, URINode predicate, ValueNode object)
    {
	this(statements, subject, predicate, object, false);
    }

    public VirtuosoStatementIterator(StatementList statements,
	    ResourceNode subject, URINode predicate, ValueNode object, boolean explicitOnly)
    {
	_statements = statements;
	_statementCount = _statements.size();

	_subject = subject;
	_predicate = predicate;
	_object = object;

	_explicitOnly = explicitOnly;

	_nextStatementIdx = -1;
	_findNextStatement();
    }


    private boolean _findNextStatement()
    {
	_nextStatementIdx++;
	for (; _nextStatementIdx < _statementCount; _nextStatementIdx++) {
	    MemStatement st = (MemStatement)_statements.get(_nextStatementIdx);

	    if (_explicitOnly && !st.isExplicit()) {
		continue;
	    }

	    if ( (_subject == null   || _subject == st.getSubject()) &&
		    (_predicate == null || _predicate == st.getPredicate()) &&
		    (_object == null    || _object == st.getObject()) )
	    {
		return true;
	    }
	}

	return false;
    }

    public boolean hasNext()
    {
	return _nextStatementIdx < _statementCount;
    }

    public Statement next()
    {
	Statement result = (Statement)_statements.get(_nextStatementIdx);
	_findNextStatement();
	return result;
    }

    public void close()
    {
	_statements = null;
	_nextStatementIdx = _statementCount;

	_subject = null;
	_predicate = null;
	_object = null;
    }
}
