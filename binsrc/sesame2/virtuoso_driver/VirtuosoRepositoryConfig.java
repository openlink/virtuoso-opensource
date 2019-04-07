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

package virtuoso.sesame2.driver.config;

import static virtuoso.sesame2.driver.config.VirtuosoRepositorySchema.PASSWORD;
import static virtuoso.sesame2.driver.config.VirtuosoRepositorySchema.HOSTLIST;
import static virtuoso.sesame2.driver.config.VirtuosoRepositorySchema.USERNAME;
import static virtuoso.sesame2.driver.config.VirtuosoRepositorySchema.DEFGRAPH;
import static virtuoso.sesame2.driver.config.VirtuosoRepositorySchema.USELAZYADD;
import static virtuoso.sesame2.driver.config.VirtuosoRepositorySchema.FETCHSIZE;
import static virtuoso.sesame2.driver.config.VirtuosoRepositorySchema.ROUNDROBIN;
import static virtuoso.sesame2.driver.config.VirtuosoRepositorySchema.RULESET;
import static virtuoso.sesame2.driver.config.VirtuosoRepositorySchema.BATCHSIZE;
import static virtuoso.sesame2.driver.config.VirtuosoRepositorySchema.INSERTBNodeAsVirtuosoIRI;
import static virtuoso.sesame2.driver.config.VirtuosoRepositorySchema.USE_DEF_GRAPH_FOR_QUERIES;

import org.openrdf.model.Graph;
import org.openrdf.model.Literal;
import org.openrdf.model.Resource;
import org.openrdf.model.URI;
import org.openrdf.model.util.GraphUtil;
import org.openrdf.model.util.GraphUtilException;
import org.openrdf.model.ValueFactory;
import org.openrdf.repository.config.RepositoryConfigException;
import org.openrdf.repository.config.RepositoryImplConfigBase;

/**
 */
public class VirtuosoRepositoryConfig extends RepositoryImplConfigBase {

	private String hostlist;

	private String username;

	private String password;

	private String defGraph;

	private boolean useLazyAdd;

	private int fetchSize = 100;

	private boolean roundRobin;

	private String ruleSet;

	private int batchSize = 5000;

	private boolean insertBNodeAsVirtuosoIRI = false;

	private boolean useDefGraphForQueries = false;

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

	public int getBatchSize() {
		return batchSize;
	}

	public void setBatchSize(int batchSize) {
		this.batchSize = batchSize;
	}


	public void setInsertBNodeAsVirtuosoIRI(boolean v) {
		this.insertBNodeAsVirtuosoIRI = v;
	}

	public boolean getInsertBNodeAsVirtuosoIRI() {
		return this.insertBNodeAsVirtuosoIRI;
	}

	
	public void setUseDefGraphForQueries(boolean v) {
		this.useDefGraphForQueries = v;
	}

	public boolean getUseDefGraphForQueries() {
		return this.useDefGraphForQueries;
	}
	

	@Override
	public void validate()
		throws RepositoryConfigException
	{
		super.validate();
		if (hostlist == null) {
			throw new RepositoryConfigException("No HostList specified for Virtuoso repository");
		}
	}

	@Override
	public Resource export(Graph graph) {
		Resource implNode = super.export(graph);

		ValueFactory vf = graph.getValueFactory();

		if (hostlist != null) {
//--			graph.add(implNode, HOSTLIST, graph.getValueFactory().createLiteral(hostlist), new Resource[0]);
			graph.add(implNode, HOSTLIST, vf.createLiteral(hostlist));
		}
		if (username != null) {
			graph.add(implNode, USERNAME, vf.createLiteral(username));
		}
		if (password != null) {
			graph.add(implNode, PASSWORD, vf.createLiteral(password));
		}

		if (defGraph != null) {
			graph.add(implNode, DEFGRAPH, vf.createLiteral(defGraph));
		}

		if (ruleSet != null && ruleSet.length() > 0 && !ruleSet.equals("null")) {
			graph.add(implNode, RULESET, vf.createLiteral(ruleSet));
		}

		graph.add(implNode, USELAZYADD, vf.createLiteral(new Boolean(useLazyAdd).toString()));

		graph.add(implNode, ROUNDROBIN, vf.createLiteral(new Boolean(roundRobin).toString()));

		graph.add(implNode, FETCHSIZE, vf.createLiteral(Integer.toString(fetchSize,10)));

		graph.add(implNode, BATCHSIZE, vf.createLiteral(Integer.toString(batchSize,10)));

		graph.add(implNode, INSERTBNodeAsVirtuosoIRI, vf.createLiteral(new Boolean(insertBNodeAsVirtuosoIRI).toString()));

		graph.add(implNode, USE_DEF_GRAPH_FOR_QUERIES, vf.createLiteral(new Boolean(useDefGraphForQueries).toString()));

		return implNode;
	}

	@Override
	public void parse(Graph graph, Resource implNode)
		throws RepositoryConfigException
	{
		super.parse(graph, implNode);

		try {
			Literal hlist = GraphUtil.getOptionalObjectLiteral(graph, implNode, HOSTLIST);
			if (hlist != null) {
				setHostList(hlist.getLabel());
			}
			Literal username = GraphUtil.getOptionalObjectLiteral(graph, implNode, USERNAME);
			if (username != null) {
				setUsername(username.getLabel());
			}
			Literal password = GraphUtil.getOptionalObjectLiteral(graph, implNode, PASSWORD);
			if (password != null) {
				setPassword(password.getLabel());
			}
			Literal defgraph = GraphUtil.getOptionalObjectLiteral(graph, implNode, DEFGRAPH);
			if (defgraph != null) {
				setDefGraph(defgraph.getLabel());
			}
			Literal uselazyadd = GraphUtil.getOptionalObjectLiteral(graph, implNode, USELAZYADD);
			if (uselazyadd != null) {
				setUseLazyAdd(Boolean.parseBoolean(uselazyadd.getLabel()));
			}
			Literal roundrobin = GraphUtil.getOptionalObjectLiteral(graph, implNode, ROUNDROBIN);
			if (roundrobin != null) {
				setRoundRobin(Boolean.parseBoolean(roundrobin.getLabel()));
			}
			Literal fetchsize = GraphUtil.getOptionalObjectLiteral(graph, implNode, FETCHSIZE);
			if (fetchsize != null) {
				setFetchSize(Integer.parseInt(fetchsize.getLabel()));
			}
			Literal ruleset = GraphUtil.getOptionalObjectLiteral(graph, implNode, RULESET);
			if (ruleset != null) {
				setRuleSet(ruleset.getLabel());
			}
			Literal batchsize = GraphUtil.getOptionalObjectLiteral(graph, implNode, BATCHSIZE);
			if (batchsize != null) {
				setBatchSize(Integer.parseInt(batchsize.getLabel()));
			}
			Literal bnodeAsUri = GraphUtil.getOptionalObjectLiteral(graph, implNode, INSERTBNodeAsVirtuosoIRI);
			if (bnodeAsUri != null) {
				setInsertBNodeAsVirtuosoIRI(Boolean.parseBoolean(bnodeAsUri.getLabel()));
			}
			Literal useDefGraphForQueries = GraphUtil.getOptionalObjectLiteral(graph, implNode, USE_DEF_GRAPH_FOR_QUERIES);
			if (useDefGraphForQueries != null) {
				setUseDefGraphForQueries(Boolean.parseBoolean(useDefGraphForQueries.getLabel()));
			}

		}
		catch (GraphUtilException e) {
			throw new RepositoryConfigException(e.getMessage(), e);
		}
	}
}
