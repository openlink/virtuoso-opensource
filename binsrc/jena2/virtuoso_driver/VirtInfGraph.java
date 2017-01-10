/*
 *  $Id: VirtInfGraph.java,v 1.1.4.4 2012/03/08 12:55:00 source Exp $
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

package virtuoso.jena.driver;


import java.util.*;


import com.hp.hpl.jena.graph.*;
import com.hp.hpl.jena.graph.compose.MultiUnion;
import com.hp.hpl.jena.graph.impl.*;
import com.hp.hpl.jena.shared.*;
import com.hp.hpl.jena.util.iterator.*;
import com.hp.hpl.jena.datatypes.*;
import com.hp.hpl.jena.rdf.model.*;
import com.hp.hpl.jena.reasoner.*;


public class VirtInfGraph extends VirtGraph implements InfGraph {
    protected boolean recordDerivations;


    public VirtInfGraph(String _ruleSet, boolean useSameAs, String graphName) {
        super(graphName);
        setRuleSet(_ruleSet);
        setSameAs(useSameAs);
    }

    public VirtInfGraph(String _ruleSet, boolean useSameAs, String graphName,
                        String url_hostlist, String user, String password) {
        super(graphName, url_hostlist, user, password);
        setRuleSet(_ruleSet);
        setSameAs(useSameAs);
    }

    public VirtInfGraph(String _ruleSet, boolean useSameAs, String graphName,
                        String url_hostlist, String user, String password,
                        boolean roundrobin) {
        super(graphName, url_hostlist, user, password, roundrobin);
        setRuleSet(_ruleSet);
        setSameAs(useSameAs);
    }


    /**
     * Return the raw RDF data Graph being processed (i.e. the argument
     * to the Reasonder.bind call that created this InfGraph).
     */
    public Graph getRawGraph() {
        VirtGraph g = new VirtGraph(getGraphName(), getGraphUrl(), getGraphUser(),
                getGraphPassword(), roundrobin);
        return g;
    }

    /**
     * Return the Reasoner which is being used to answer queries to this graph.
     */
    public Reasoner getReasoner() {
        return null; //??TODO
    }

    /**
     * Replace the underlying data graph for this inference graph and start any
     * inferences over again. This is primarily using in setting up ontology imports
     * processing to allow an imports multiunion graph to be inserted between the
     * inference graph and the raw data, before processing.
     *
     * @param data the new raw data graph
     */
    public void rebind(Graph data) {
    }

    /**
     * Cause the inference graph to reconsult the underlying graph to take
     * into account changes. Normally changes are made through the InfGraph's add and
     * remove calls are will be handled appropriately. However, in some cases changes
     * are made "behind the InfGraph's back" and this forces a full reconsult of
     * the changed data.
     */
    public void rebind() {
    }

    /**
     * Perform any initial processing and caching. This call is optional. Most
     * engines either have negligable set up work or will perform an implicit
     * "prepare" if necessary. The call is provided for those occasions where
     * substantial preparation work is possible (e.g. running a forward chaining
     * rule system) and where an application might wish greater control over when
     * this prepration is done.
     */
    public void prepare() {
    }

    /**
     * Reset any internal caches. Some systems, such as the tabled backchainer,
     * retain information after each query. A reset will wipe this information preventing
     * unbounded memory use at the expense of more expensive future queries. A reset
     * does not cause the raw data to be reconsulted and so is less expensive than a rebind.
     */
    public void reset() {
    }

    /**
     * Test a global boolean property of the graph. This might included
     * properties like consistency, OWLSyntacticValidity etc.
     * It remains to be seen what level of generality is needed here. We could
     * replace this by a small number of specific tests for common concepts.
     *
     * @param property the URI of the property to be tested
     * @return a Node giving the value of the global property, this may
     * be a boolean literal, some other literal value (e.g. a size).
     */
    public Node getGlobalProperty(Node property) {
        throw new ReasonerException("Global property not implemented: " + property);
    }


    /**
     * A convenience version of getGlobalProperty which can only return
     * a boolean result.
     */
    public boolean testGlobalProperty(Node property) {
        Node resultNode = getGlobalProperty(property);
        if (resultNode.isLiteral()) {
            Object result = resultNode.getLiteralValue();
            if (result instanceof Boolean) {
                return ((Boolean) result).booleanValue();
            }
        }
        throw new ReasonerException("Global property test returned non-boolean value" +
                "\nTest was: " + property +
                "\nResult was: " + resultNode);
    }

    /**
     * Test the consistency of the bound data. This normally tests
     * the validity of the bound instance data against the bound
     * schema data.
     *
     * @return a ValidityReport structure
     */
    public ValidityReport validate() {
        checkOpen();
        return new StandardValidityReport();
    }

    /**
     * An extension of the Graph.find interface which allows the caller to
     * encode complex expressions in RDF and then refer to those expressions
     * within the query triple. For example, one might encode a class expression
     * and then ask if there are any instances of this class expression in the
     * InfGraph.
     *
     * @param subject  the subject Node of the query triple, may be a Node in
     *                 the graph or a node in the parameter micro-graph or null
     * @param property the property to be retrieved or null
     * @param object   the object Node of the query triple, may be a Node in
     *                 the graph or a node in the parameter micro-graph.
     * @param param    a small graph encoding an expression which the subject and/or
     *                 object nodes refer.
     */
    public ExtendedIterator<Triple> find(Node subject, Node property, Node object, Graph param) {
        return cloneWithPremises(param).find(subject, property, object);
    }


    /**
     * Return a new inference graph which is a clone of the current graph
     * together with an additional set of data premises. The default
     * implementation loses ALL partial deductions so far. Some subclasses
     * may be able to a more efficient job.
     */
    public Graph cloneWithPremises(Graph premises) {
        MultiUnion union = new MultiUnion();
        union.addGraph(this);
        union.setBaseGraph(this);
        union.addGraph(premises);
        return union;
    }


    /**
     * Switch on/off drivation logging
     */
    public void setDerivationLogging(boolean logOn) {
        recordDerivations = logOn;
    }

    /**
     * Return the derivation of the given triple (which is the result of
     * some previous find operation).
     * Not all reasoneers will support derivations.
     *
     * @return an iterator over Derivation records or null if there is no derivation information
     * available for this triple.
     */
    public Iterator<Derivation> getDerivation(Triple triple) {
        return null;
    }

    /**
     * Returns a derivations graph. The rule reasoners typically create a
     * graph containing those triples added to the base graph due to rule firings.
     * In some applications it can useful to be able to access those deductions
     * directly, without seeing the raw data which triggered them. In particular,
     * this allows the forward rules to be used as if they were rewrite transformation
     * rules.
     *
     * @return the deductions graph, if relevant for this class of inference
     * engine or null if not.
     */
    public Graph getDeductionsGraph() {
        return null;
    }


}

