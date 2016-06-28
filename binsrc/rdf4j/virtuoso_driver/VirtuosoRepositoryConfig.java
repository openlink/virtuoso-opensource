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
package virtuoso.rdf4j.driver.config;

import org.eclipse.rdf4j.model.*;
import org.eclipse.rdf4j.model.impl.SimpleValueFactory;
import org.eclipse.rdf4j.model.util.ModelException;
import org.eclipse.rdf4j.model.util.Models;
import org.eclipse.rdf4j.repository.config.AbstractRepositoryImplConfig;
import org.eclipse.rdf4j.repository.config.RepositoryConfigException;

import static virtuoso.rdf4j.driver.config.VirtuosoRepositorySchema.PASSWORD;
import static virtuoso.rdf4j.driver.config.VirtuosoRepositorySchema.HOSTLIST;
import static virtuoso.rdf4j.driver.config.VirtuosoRepositorySchema.USERNAME;
import static virtuoso.rdf4j.driver.config.VirtuosoRepositorySchema.DEFGRAPH;
import static virtuoso.rdf4j.driver.config.VirtuosoRepositorySchema.USELAZYADD;
import static virtuoso.rdf4j.driver.config.VirtuosoRepositorySchema.FETCHSIZE;
import static virtuoso.rdf4j.driver.config.VirtuosoRepositorySchema.ROUNDROBIN;
import static virtuoso.rdf4j.driver.config.VirtuosoRepositorySchema.RULESET;
import static virtuoso.rdf4j.driver.config.VirtuosoRepositorySchema.BATCHSIZE;
import static virtuoso.rdf4j.driver.config.VirtuosoRepositorySchema.INSERTBNodeAsVirtuosoIRI;

public class VirtuosoRepositoryConfig extends AbstractRepositoryImplConfig {
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
    public Resource export(Model model) {
        Resource implNode = super.export(model);

        ValueFactory vf = SimpleValueFactory.getInstance();

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

        model.add(implNode, USELAZYADD, vf.createLiteral(useLazyAdd));

        model.add(implNode, ROUNDROBIN, vf.createLiteral(roundRobin));

        model.add(implNode, FETCHSIZE, vf.createLiteral(Integer.toString(fetchSize,10)));

        model.add(implNode, BATCHSIZE, vf.createLiteral(Integer.toString(batchSize,10)));

        model.add(implNode, INSERTBNodeAsVirtuosoIRI, vf.createLiteral(insertBNodeAsVirtuosoIRI));

        return implNode;
    }

    @Override
    public void parse(Model model, Resource implNode)
            throws RepositoryConfigException
    {
        super.parse(model, implNode);

        try {
            Models.objectLiteral(model.filter(implNode, HOSTLIST, null)).ifPresent(
                    lit -> setHostList(lit.getLabel()));

            Models.objectLiteral(model.filter(implNode, USERNAME, null)).ifPresent(
                    lit -> setUsername(lit.getLabel()));

            Models.objectLiteral(model.filter(implNode, PASSWORD, null)).ifPresent(
                    lit -> setPassword(lit.getLabel()));

            Models.objectLiteral(model.filter(implNode, DEFGRAPH, null)).ifPresent(
                    lit -> setDefGraph(lit.getLabel()));

            Models.objectLiteral(model.filter(implNode, USELAZYADD, null)).ifPresent(
                    lit -> setUseLazyAdd(lit.booleanValue()));

            Models.objectLiteral(model.filter(implNode, ROUNDROBIN, null)).ifPresent(
                    lit -> setRoundRobin(lit.booleanValue()));

            Models.objectLiteral(model.filter(implNode, FETCHSIZE, null)).ifPresent(
                    lit -> setFetchSize(lit.intValue()));

            Models.objectLiteral(model.filter(implNode, RULESET, null)).ifPresent(
                    lit -> setRuleSet(lit.getLabel()));

            Models.objectLiteral(model.filter(implNode, BATCHSIZE, null)).ifPresent(
                    lit -> setBatchSize(lit.intValue()));

            Models.objectLiteral(model.filter(implNode, INSERTBNodeAsVirtuosoIRI, null)).ifPresent(
                    lit -> setInsertBNodeAsVirtuosoIRI(lit.booleanValue()));
        }
        catch (ModelException e) {
            throw new RepositoryConfigException(e.getMessage(), e);
        }
    }

}
