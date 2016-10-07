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

import org.eclipse.rdf4j.query.Query;
import org.eclipse.rdf4j.query.QueryInterruptedException;

public class VirtuosoQuery extends VirtuosoOperation implements Query {
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
        setMaxExecutionTime(maxQueryTime);
    }

    /**
     * Returns the maximum query evaluation time.
     *
     * @return The maximum query evaluation time, measured in seconds.
     * @see #maxQueryTime
     */
    public int getMaxQueryTime()
    {
        return getMaxExecutionTime();
    }


}
