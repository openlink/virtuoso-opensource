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

import static virtuoso.sesame3.driver.config.VirtuosoRepositorySchema.PASSWORD;
import static virtuoso.sesame3.driver.config.VirtuosoRepositorySchema.HOSTLIST;
import static virtuoso.sesame3.driver.config.VirtuosoRepositorySchema.USERNAME;
import static virtuoso.sesame3.driver.config.VirtuosoRepositorySchema.DEFGRAPH;
import static virtuoso.sesame3.driver.config.VirtuosoRepositorySchema.USELAZYADD;
import static virtuoso.sesame3.driver.config.VirtuosoRepositorySchema.FETCHSIZE;
import static virtuoso.sesame3.driver.config.VirtuosoRepositorySchema.ROUNDROBIN;
import static virtuoso.sesame3.driver.config.VirtuosoRepositorySchema.RULESET;

import java.util.HashSet;
import java.util.Set;

import org.openrdf.model.Literal;
import org.openrdf.model.Model;
import org.openrdf.model.Resource;
import org.openrdf.model.URI;
import org.openrdf.model.Value;
import org.openrdf.model.impl.ValueFactoryImpl;
import org.openrdf.model.util.ModelException;
import org.openrdf.repository.config.RepositoryImplConfigBase;
import org.openrdf.store.StoreConfigException;


public class VirtuosoRepositoryConfig extends RepositoryImplConfigBase {

	private String hostlist;

	private String username;

	private String password;

	private String defGraph;

	private boolean useLazyAdd;

	private int fetchSize = 200;

	private boolean roundRobin;

	private String ruleSet;

	public VirtuosoRepositoryConfig() {
		super(VirtuosoRepositoryFactory.REPOSITORY_TYPE);
	}

	public VirtuosoRepositoryConfig(String hostlist) {
		this();
		setHostList(hostlist);
	}

	public String getHostList() {
		return hostlist;
	}

	public void setHostList(String hostlist) {
		this.hostlist = hostlist;
	}

	public String getUsername() {
		return username;
	}

	public void setUsername(String username) {
		this.username = username;
	}

	public String getPassword() {
		return password;
	}

	public void setPassword(String password) {
		this.password = password;
	}


	public String getDefGraph() {
		return defGraph;
	}

	public void setDefGraph(String defGraph) {
		this.defGraph = defGraph;
	}


	public boolean getUseLazyAdd() {
		return useLazyAdd;
	}

	public void setUseLazyAdd(boolean useLazyAdd) {
		this.useLazyAdd = useLazyAdd;
	}

	public boolean getRoundRobin() {
		return roundRobin;
	}

	public void setRoundRobin(boolean roundRobin) {
		this.roundRobin = roundRobin;
	}


	public int getFetchSize() {
		return fetchSize;
	}

	public void setFetchSize(int fetchSize) {
		this.fetchSize = fetchSize;
	}


	public String getRuleSet() {
		return ruleSet;
	}

	public void setRuleSet(String ruleSet) {
		if (ruleSet!=null && ruleSet.equals("null"))
			this.ruleSet = null;
		else
			this.ruleSet = ruleSet;
	}

	
	@Override
	public void validate()
		throws StoreConfigException
	{
		super.validate();
		if (hostlist == null) {
			throw new StoreConfigException("No HostList specified for Virtuoso repository");
		}
	}

	@Override
	public Resource export(Model model) {
		Resource implNode = super.export(model);
		ValueFactoryImpl vf = ValueFactoryImpl.getInstance();

		if (hostlist != null) {
			model.add(implNode, HOSTLIST, vf.createLiteral(hostlist));
		}
		if (username != null) {
			model.add(implNode, USERNAME, vf.createLiteral(username));
		}
		if (password != null) {
			model.add(implNode, PASSWORD, vf.createLiteral(password));
		}

		if (defGraph != null) {
			model.add(implNode, DEFGRAPH, vf.createLiteral(defGraph));
		}

		if (ruleSet != null && ruleSet.length() > 0 && !ruleSet.equals("null")) {
			model.add(implNode, RULESET, vf.createLiteral(ruleSet));
		}

		model.add(implNode, USELAZYADD, vf.createLiteral(new Boolean(useLazyAdd).toString()));

		model.add(implNode, ROUNDROBIN, vf.createLiteral(new Boolean(roundRobin).toString()));

		model.add(implNode, FETCHSIZE, vf.createLiteral(Integer.toString(fetchSize,10)));

		return implNode;
	}

	@Override
	public void parse(Model model, Resource implNode)
		throws StoreConfigException
	{
		super.parse(model, implNode);

		try {
		        Literal hlist = model.filter(implNode, HOSTLIST, null).objectLiteral();
			if (hlist != null) {
				setHostList(hlist.getLabel());
			}
		        Literal username = model.filter(implNode, USERNAME, null).objectLiteral();
			if (username != null) {
				setUsername(username.getLabel());
			}
		        Literal password = model.filter(implNode, PASSWORD, null).objectLiteral();
			if (password != null) {
				setPassword(password.getLabel());
			}
		        Literal defgraph = model.filter(implNode, DEFGRAPH, null).objectLiteral();
			if (defgraph != null) {
				setDefGraph(defgraph.getLabel());
			}
		        Literal uselazyadd = model.filter(implNode, USELAZYADD, null).objectLiteral();
			if (uselazyadd != null) {
				setUseLazyAdd(Boolean.getBoolean(uselazyadd.getLabel()));
			}
		        Literal roundrobin = model.filter(implNode, ROUNDROBIN, null).objectLiteral();
			if (roundrobin != null) {
				setRoundRobin(Boolean.getBoolean(roundrobin.getLabel()));
			}
		        Literal fetchsize = model.filter(implNode, FETCHSIZE, null).objectLiteral();
			if (fetchsize != null) {
				setFetchSize(Integer.parseInt(fetchsize.getLabel()));
			}
		        Literal ruleset = model.filter(implNode, RULESET, null).objectLiteral();
			if (ruleset != null) {
				setRuleSet(ruleset.getLabel());
			}
		}
		catch (ModelException e) {
			throw new StoreConfigException(e.getMessage(), e);
		}
	}
}
