/*
 *  $Id$
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

package virtuoso.sesame3.driver;

import org.openrdf.query.TupleQueryResultHandler;
import org.openrdf.query.TupleQueryResultHandlerException;
import org.openrdf.query.algebra.evaluation.QueryBindingSet;
import org.openrdf.result.util.QueryResultUtil;
import org.openrdf.result.TupleResult;
import org.openrdf.store.StoreException;
import org.openrdf.query.TupleQuery;

public class VirtuosoTupleQuery extends VirtuosoQuery implements TupleQuery {

	protected int offset = 0;

	protected int limit = -1;

	public TupleResult evaluate() throws StoreException
	{
		return null;
	}

	public <H extends TupleQueryResultHandler> H evaluate(H handler)
		throws StoreException, TupleQueryResultHandlerException
	{
		TupleResult queryResult = evaluate();
		QueryResultUtil.report(queryResult, handler);
		return handler;
	}

	/**
	 * Specifies the numbers of results that should be omitted from the beginning
	 * of the query results.
	 * 
	 * @param offset
	 */
	public void setOffset(int offset)
	{
		this.offset = offset;
	}

	/**
	 * Returns the number of skipped results.
	 * 
	 * @return the numbers of results that should be omitted from the beginning
	 *         of the query results.
	 */
	public int getOffset()
	{
		return offset;
	}


	/**
	 * Specifies the maximum results that a query is allowed to return. The query
	 * stop before it exceeds the result limit. Any consecutive requests to fetch
	 * query results will result in a null value.
	 * 
	 * @param limit
	 *        The maximum number of query results. A -1 value indicates an
	 *        unlimited results (which is the default).
	 */
	public void setLimit(int limit)
	{
		this.limit = limit;
	}


	/**
	 * Returns the maximum number of query resultcs.
	 * 
	 * @return The maximum number of query results. A -1 value indicates an
	 *         unlimited results.
	 * @see #setLimit(int)
	 */
	public int getLimit()
	{
		return limit;
	}
}
