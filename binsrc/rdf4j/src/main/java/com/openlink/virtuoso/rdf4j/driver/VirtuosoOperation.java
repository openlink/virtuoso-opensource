/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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
package com.openlink.virtuoso.rdf4j.driver;

import org.eclipse.rdf4j.model.Value;
import org.eclipse.rdf4j.query.BindingSet;
import org.eclipse.rdf4j.query.Dataset;
import org.eclipse.rdf4j.query.Operation;
import org.eclipse.rdf4j.query.QueryInterruptedException;
import org.eclipse.rdf4j.query.impl.MapBindingSet;

public class VirtuosoOperation implements Operation {
    MapBindingSet bindingSet = new MapBindingSet();
    boolean includeInferred = false;
    Dataset dataset = null;
    int maxExecutionTime = 0;

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
        bindingSet.addBinding(name, value);
    }

    /**
     * Removes a previously set binding on the supplied variable. Calling this
     * method with an unbound variable name has no effect.
     *
     * @param name
     *        The name of the variable from which the binding is to be removed.
     */
    public void removeBinding(String name) {
        bindingSet.removeBinding(name);
    }

    /**
     * Removes all previously set bindings.
     */
    public void clearBindings() {
        bindingSet.clear();
    }

    /**
     * Retrieves the bindings that have been set on this query.
     *
     * @return A (possibly empty) set of query variable bindings.
     * @see #setBinding(String, Value)
     */
    public BindingSet getBindings() {
        return bindingSet;
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
     * Specifies the maximum time that an operation is allowed to run. The
     * operation will be interrupted when it exceeds the time limit. Any
     * consecutive requests to fetch query results will result in
     * {@link QueryInterruptedException}s or {@link UpdateInterruptedException}s
     * (depending on whether the operation is a query or an update).
     *
     * @param maxExecTime
     *        The maximum query time, measured in seconds. A negative or zero
     *        value indicates an unlimited execution time (which is the default).
     * @since 2.8.0
     */
    public void setMaxExecutionTime(int maxExecTime)
    {
        this.maxExecutionTime = maxExecTime;
    }

    /**
     * Returns the maximum operation execution time.
     *
     * @return The maximum operation execution time, measured in seconds.
     * @see #setMaxExecutionTime(int)
     * @since 2.8.0
     */
    public int getMaxExecutionTime()
    {
        return maxExecutionTime;
    }

}
