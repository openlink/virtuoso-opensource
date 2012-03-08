/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

package virtuoso.sesame3.driver.config;


import org.openrdf.repository.Repository;
import org.openrdf.repository.config.RepositoryFactory;
import org.openrdf.repository.config.RepositoryImplConfig;
import org.openrdf.store.StoreConfigException;
import virtuoso.sesame3.driver.VirtuosoRepository;

/**
 * A {@link RepositoryFactory} that creates {@link VirtuosoRepository}s based on
 * RDF configuration data.
 */
public class VirtuosoRepositoryFactory implements RepositoryFactory {

	/**
	 * The type of repositories that are created by this factory.
	 * 
	 * @see RepositoryFactory#getRepositoryType()
	 */
	public static final String REPOSITORY_TYPE = "openrdf:VirtuosoRepository";

	/**
	 * Returns the repository's type: <tt>openrdf:VirtuosoRepository</tt>.
	 */
	public String getRepositoryType() {
		return REPOSITORY_TYPE;
	}

	public RepositoryImplConfig getConfig() {
		return new VirtuosoRepositoryConfig();
	}

	public Repository getRepository(RepositoryImplConfig config)
		throws StoreConfigException
	{
		VirtuosoRepository result = null;
		
		if (config instanceof VirtuosoRepositoryConfig) {
			VirtuosoRepositoryConfig vConfig = (VirtuosoRepositoryConfig)config;
			result = new VirtuosoRepository(vConfig.getHostList(), 
					vConfig.getUsername(), 
					vConfig.getPassword(),
					vConfig.getDefGraph(),
					vConfig.getUseLazyAdd());
			result.setFetchSize(vConfig.getFetchSize());
			result.setRoundrobin(vConfig.getRoundRobin());
			result.setFetchSize(vConfig.getFetchSize());
		  	result.setRuleSet(vConfig.getRuleSet());
		}
		else {
			throw new StoreConfigException("Invalid configuration class: " + config.getClass());
		}
		return result;
	}
}
