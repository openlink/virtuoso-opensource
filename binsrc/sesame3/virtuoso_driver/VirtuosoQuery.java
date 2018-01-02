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

package virtuoso.sesame3.driver;

import org.openrdf.model.Value;
import org.openrdf.query.BindingSet;
import org.openrdf.query.Dataset;
import org.openrdf.query.TupleQueryResultHandler;
import org.openrdf.query.algebra.evaluation.QueryBindingSet;
import org.openrdf.query.resultio.TupleQueryResultWriter;
import org.openrdf.query.Query;
import org.openrdf.store.StoreException;
import org.openrdf.result.Result;

public class VirtuosoQuery implements Query {

	QueryBindingSet bindingSet = new QueryBindingSet();
	boolean includeInferred = false;
	Dataset dataset = null;
	int maxQueryTime = 0;
	
	/**
	 * Binds the specified variable to the supplied value. Any value that was
	 * previously bound to the specified value will be overwritten.
	 * 
	 * @param name
	 *        The name of the variable that should be bound.
	 * @param value
	 *        The (new) value for the specified variable.
	 */
	public void setBinding(String name, Value value) {
		this.bindingSet.setBinding(name, value);
	}

	/**
	 * Removes a previously set binding on the supplied variable. Calling this
	 * method with an unbound variable name has no effect.
	 * 
	 * @param name
	 *        The name of the variable from which the binding is to be removed.
	 */
	public void removeBinding(String name) {
		this.bindingSet.removeBinding(name);
	}

	/**
	 * Retrieves the bindings that have been set on this query.
	 * 
	 * @return A (possibly empty) set of query variable bindings.
	 * @see #setBinding(String, Value)
	 */
	public BindingSet getBindings() {
		return this.bindingSet;
	}

	/**
	 * Specifies the dataset against which to evaluate a query, overriding any
	 * dataset that is specified in the query itself.
	 */
	public void setDataset(Dataset dataset) {
		this.dataset = dataset;
	}

	/**
	 * Gets the dataset that has been set using {@link #setDataset(Dataset)}, if
	 * any.
	 */
	public Dataset getDataset() {
		return dataset;
	}

	/**
	 * Determine whether evaluation results of this query should include inferred
	 * statements (if any inferred statements are present in the repository). The
	 * default setting is 'true'.
	 * 
	 * @param includeInferred
	 *        indicates whether inferred statements should included in the
	 *        result.
	 */
	public void setIncludeInferred(boolean includeInferred) {
		this.includeInferred = includeInferred;
	}

	/**
	 * Returns whether or not this query will return inferred statements (if any
	 * are present in the repository).
	 * 
	 * @return <tt>true</tt> if inferred statements will be returned,
	 *         <tt>false</tt> otherwise.
	 */
	public boolean getIncludeInferred() {
		return this.includeInferred;
	}

	/**
	 * Specifies the maximum time that a query is allowed to run. The query will
	 * be interrupted when it exceeds the time limit. Any consecutive requests to
	 * fetch query results will result in {@link QueryInterruptedException}s.
	 * 
	 * @param maxQueryTime
	 *        The maximum query time, measured in seconds. A negative or zero
	 *        value indicates an unlimited query time (which is the default).
	 */
	public void setMaxQueryTime(int maxQueryTime)
	{
		this.maxQueryTime = maxQueryTime;
	}

	/**
	 * Returns the maximum query evaluation time.
	 * 
	 * @return The maximum query evaluation time, measured in seconds.
	 * @see #maxQueryTime
	 */
	public int getMaxQueryTime()
	{
		return -1;
	}

	public Result<?> evaluate()
		throws StoreException
	{
		return null;
	}
}
