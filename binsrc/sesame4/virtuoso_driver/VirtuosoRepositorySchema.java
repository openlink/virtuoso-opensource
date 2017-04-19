/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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
package virtuoso.sesame4.driver.config;

import org.openrdf.model.IRI;
import org.openrdf.model.ValueFactory;
import org.openrdf.model.impl.SimpleValueFactory;

/**
 * Defines constants for the VirtuosoRepository schema which is used by
 * {@link VirtuosoRepositoryFactory}s to initialize {@link virtuoso.sesame4.driver.VirtuosoRepository}s.
 *
 */
public class VirtuosoRepositorySchema {
    public static final String NAMESPACE = "http://www.openrdf.org/config/repository/virtuoso#";

    /** <tt>http://www.openrdf.org/config/repository/virtuoso#hostList</tt> */
    public final static IRI HOSTLIST;

    /** <tt>http://www.openrdf.org/config/repository/virtuoso#username</tt> */
    public final static IRI USERNAME;

    /** <tt>http://www.openrdf.org/config/repository/virtuoso#password</tt> */
    public final static IRI PASSWORD;

    /** <tt>http://www.openrdf.org/config/repository/virtuoso#defGraph</tt> */
    public final static IRI DEFGRAPH;

    /** <tt>http://www.openrdf.org/config/repository/virtuoso#useLazyAdd</tt> */
    public final static IRI USELAZYADD;

    /** <tt>http://www.openrdf.org/config/repository/virtuoso#fetchSize</tt> */
    public final static IRI FETCHSIZE;

    /** <tt>http://www.openrdf.org/config/repository/virtuoso#roundRobin</tt> */
    public final static IRI ROUNDROBIN;

    /** <tt>http://www.openrdf.org/config/repository/virtuoso#ruleSet</tt> */
    public final static IRI RULESET;

    /** <tt>http://www.openrdf.org/config/repository/virtuoso#batchSize</tt> */
    public final static IRI BATCHSIZE;

    /** <tt>http://www.openrdf.org/config/repository/virtuoso#insertBNodeAsVirtuosoIRI</tt> */
    public final static IRI INSERTBNodeAsVirtuosoIRI;

    /** <tt>http://www.openrdf.org/config/repository/virtuoso#macroLib</tt> */
    public final static IRI MACROLIB;

    /** <tt>http://www.openrdf.org/config/repository/virtuoso#concurrency</tt> */
    public final static IRI CONCURRENCY;

    static {
        ValueFactory factory = SimpleValueFactory.getInstance();
        HOSTLIST   = factory.createIRI(NAMESPACE, "hostList");
        USERNAME   = factory.createIRI(NAMESPACE, "username");
        PASSWORD   = factory.createIRI(NAMESPACE, "password");
        DEFGRAPH   = factory.createIRI(NAMESPACE, "defGraph");
        USELAZYADD = factory.createIRI(NAMESPACE, "useLazyAdd");
        FETCHSIZE  = factory.createIRI(NAMESPACE, "fetchSize");
        ROUNDROBIN = factory.createIRI(NAMESPACE, "roundRobin");
        RULESET    = factory.createIRI(NAMESPACE, "ruleSet");
        BATCHSIZE  = factory.createIRI(NAMESPACE, "batchSize");
        INSERTBNodeAsVirtuosoIRI  = factory.createIRI(NAMESPACE, "insertBNodeAsVirtuosoIRI");
        MACROLIB    = factory.createIRI(NAMESPACE, "macroLib");
        CONCURRENCY    = factory.createIRI(NAMESPACE, "concurrency");
    }
}
