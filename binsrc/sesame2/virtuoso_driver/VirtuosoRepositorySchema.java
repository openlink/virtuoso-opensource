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

package virtuoso.sesame2.driver.config;


import org.openrdf.model.URI;
import org.openrdf.model.ValueFactory;
import org.openrdf.model.impl.ValueFactoryImpl;
import virtuoso.sesame2.driver.VirtuosoRepository;

/**
 * Defines constants for the VirtuosoRepository schema which is used by
 * {@link VirtuosoRepositoryFactory}s to initialize {@link VirtuosoRepository}s.
 * 
 */
public class VirtuosoRepositorySchema {

	public static final String NAMESPACE = "http://www.openrdf.org/config/repository/virtuoso#";

	/** <tt>http://www.openrdf.org/config/repository/virtuoso#hostList</tt> */
	public final static URI HOSTLIST;

	/** <tt>http://www.openrdf.org/config/repository/virtuoso#username</tt> */
	public final static URI USERNAME;

	/** <tt>http://www.openrdf.org/config/repository/virtuoso#password</tt> */
	public final static URI PASSWORD;

	/** <tt>http://www.openrdf.org/config/repository/virtuoso#defGraph</tt> */
	public final static URI DEFGRAPH;

	/** <tt>http://www.openrdf.org/config/repository/virtuoso#useLazyAdd</tt> */
	public final static URI USELAZYADD;

	/** <tt>http://www.openrdf.org/config/repository/virtuoso#fetchSize</tt> */
	public final static URI FETCHSIZE;

	/** <tt>http://www.openrdf.org/config/repository/virtuoso#roundRobin</tt> */
	public final static URI ROUNDROBIN;

	/** <tt>http://www.openrdf.org/config/repository/virtuoso#ruleSet</tt> */
	public final static URI RULESET;

	/** <tt>http://www.openrdf.org/config/repository/virtuoso#batchSize</tt> */
	public final static URI BATCHSIZE;

	/** <tt>http://www.openrdf.org/config/repository/virtuoso#insertBNodeAsVirtuosoIRI</tt> */
	public final static URI INSERTBNodeAsVirtuosoIRI;

	/** <tt>http://www.openrdf.org/config/repository/virtuoso#useDefGraphForQueries</tt> */
	public final static URI USE_DEF_GRAPH_FOR_QUERIES;

	static {
		ValueFactory factory = ValueFactoryImpl.getInstance();
		HOSTLIST   = factory.createURI(NAMESPACE, "hostList");
		USERNAME   = factory.createURI(NAMESPACE, "username");
		PASSWORD   = factory.createURI(NAMESPACE, "password");
		DEFGRAPH   = factory.createURI(NAMESPACE, "defGraph");
		USELAZYADD = factory.createURI(NAMESPACE, "useLazyAdd");
		FETCHSIZE  = factory.createURI(NAMESPACE, "fetchSize");
		ROUNDROBIN = factory.createURI(NAMESPACE, "roundRobin");
		RULESET    = factory.createURI(NAMESPACE, "ruleSet");
		BATCHSIZE  = factory.createURI(NAMESPACE, "batchSize");
		INSERTBNodeAsVirtuosoIRI  = factory.createURI(NAMESPACE, "insertBNodeAsVirtuosoIRI");
		USE_DEF_GRAPH_FOR_QUERIES = factory.createURI(NAMESPACE, "useDefGraphForQueries");
	}
}

