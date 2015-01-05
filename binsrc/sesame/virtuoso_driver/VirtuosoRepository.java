/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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

package virtuoso.sesame.driver;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.io.Reader;
import java.io.StringReader;
import java.net.URL;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSetMetaData;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.openrdf.model.BNode;
import org.openrdf.model.Graph;
import org.openrdf.model.Resource;
import org.openrdf.model.Statement;
import org.openrdf.model.URI;
import org.openrdf.model.Value;
import org.openrdf.model.ValueFactory;
import org.openrdf.model.impl.BNodeImpl;
import org.openrdf.model.impl.LiteralImpl;
import org.openrdf.model.impl.StatementImpl;
import org.openrdf.model.impl.URIImpl;
import org.openrdf.model.impl.ValueFactoryImpl;
import org.openrdf.rio.Parser;
import org.openrdf.rio.RdfDocumentWriter;
import org.openrdf.rio.StatementHandler;
import org.openrdf.rio.ntriples.NTriplesParser;
import org.openrdf.rio.rdfxml.RdfXmlParser;
import org.openrdf.rio.turtle.TurtleParser;
import org.openrdf.sesame.admin.AdminListener;
import org.openrdf.sesame.config.AccessDeniedException;
import org.openrdf.sesame.constants.QueryLanguage;
import org.openrdf.sesame.constants.RDFFormat;
import org.openrdf.sesame.query.GraphQueryResultListener;
import org.openrdf.sesame.query.MalformedQueryException;
import org.openrdf.sesame.query.QueryEvaluationException;
import org.openrdf.sesame.query.QueryResultsGraphBuilder;
import org.openrdf.sesame.query.QueryResultsTable;
import org.openrdf.sesame.query.QueryResultsTableBuilder;
import org.openrdf.sesame.query.TableQueryResultListener;
import org.openrdf.sesame.repository.SesameRepository;
import org.openrdf.sesame.repository.local.LocalRepositoryChangedListener;
import org.openrdf.sesame.sail.Namespace;
import org.openrdf.sesame.sail.NamespaceIterator;
import org.openrdf.sesame.sail.SailChangedEvent;
import org.openrdf.sesame.sail.StatementIterator;
import org.openrdf.sesame.sailimpl.memory.MemNamespaceIterator;

import virtuoso.jdbc3.VirtuosoResultSet;

public class VirtuosoRepository implements SesameRepository
{
    private String _id;
    private String url;
    private String user;
    private String password;
    private Connection connection = null;
    private List _listeners;
    private String graphName;
    protected ValueFactory _valueFactory;

    static
    {
	try
	{
	    Class.forName("virtuoso.jdbc3.Driver");
	}
	catch (ClassNotFoundException e)
	{
	    e.printStackTrace();
	}
    }

    public VirtuosoRepository (String graphName, String url, String user, String password)
    {
	this._id = url + ":" + graphName;
	this._valueFactory = new ValueFactoryImpl();
	this.graphName = graphName;
	this.url = url;
	this.user = user;
	this.password = password;

	if (connection == null)
	{
	    try
	    {
		connection = DriverManager.getConnection(this.url, this.user, this.password);
	    }
	    catch(Exception e)
	    {
		System.out.println("VirtuosoRepository.init() Connection to " + url + " is FAILED.");
		e.printStackTrace();
		System.exit(-1);
	    }
	}
    }

    public boolean hasReadAccess()
    {
	return true;
    }

    public boolean hasWriteAccess()
    {
	return true;
    }

    public QueryResultsTable performTableQuery(QueryLanguage language, String query) throws IOException, MalformedQueryException, QueryEvaluationException, AccessDeniedException
    {
	QueryResultsTableBuilder builder = new QueryResultsTableBuilder();
	performTableQuery(language, query, builder);
	return builder.getQueryResultsTable();
    }

    public void performTableQuery(QueryLanguage language, String query, TableQueryResultListener listener) throws IOException, MalformedQueryException, QueryEvaluationException, AccessDeniedException
    {
	// the query language is ignored, only SPARQL syntax is accepted
	query = "SPARQL " + query;

	try
	{
	    java.sql.Statement stmt = connection.createStatement();
	    VirtuosoResultSet results = (VirtuosoResultSet) stmt.executeQuery(query);

	    ResultSetMetaData data = results.getMetaData();
	    String[] col_names = new String[data.getColumnCount()];

	    for(int meta_count = 0; meta_count < data.getColumnCount(); meta_count++)
	    {
		col_names[meta_count] = data.getColumnLabel(meta_count + 1);
	    }

	    listener.startTableQueryResult (col_names);

	    while (results.next())
	    {
		listener.startTuple();
		for(int meta_count = 1;meta_count <= data.getColumnCount();meta_count++)
		{
		    String col = data.getColumnName(meta_count);
		    String value = results.getString(col);
		    Value v = parseValue(value);
		    listener.tupleValue(v);
		}
		listener.endTuple ();
	    }

	    listener.endTableQueryResult ();

	}
	catch(Exception e)
	{
	    System.out.println("VirtuosoRepository.performTableQuery() GET results are FAILED.");
	    e.printStackTrace();
	    System.exit(-1);
	}
    }

    public void addData(URL dataURL, String baseURI, RDFFormat format, boolean verifyData, AdminListener listener) throws IOException, AccessDeniedException
    {
	if (baseURI == null)
	{
	    baseURI = this.graphName;
	}

	String query = "sparql load \"" + dataURL + "\" into graph <" + this.graphName + ">";

	try
	{
	    java.sql.Statement stmt = connection.createStatement();
	    stmt.executeQuery(query);
	}
	catch(Exception e)
	{
	    e.printStackTrace();
	    System.exit(-1);
	}
    }

    public void clear(AdminListener listener) throws IOException, AccessDeniedException
    {
	try
	{
	    String query = "delete from RDF_QUAD where G=DB.DBA.RDF_MAKE_IID_OF_QNAME ('" + this.graphName + "')";
	    java.sql.Statement stmt = connection.createStatement();
	    stmt.executeUpdate(query);
	}
	catch(Exception e)
	{
	    e.printStackTrace();
	    System.exit(-1);
	}
    }

    public void addData(InputStream dataStream, String baseURI, RDFFormat format, boolean verifyData, AdminListener listener) throws IOException, AccessDeniedException
    {
	try
	{
	    Parser parser = null;
	    Map noParams = new HashMap();
	    if(format.equals(RDFFormat.TURTLE))
	    {
		parser = new TurtleParser();
		}
	    else if(format.equals(RDFFormat.RDFXML))
		{
		parser = new RdfXmlParser();
		}
	    else if(format.equals(RDFFormat.NTRIPLES))
	    {
		parser = new NTriplesParser();
	    }
	    else return;

	    parser.setDatatypeHandling(Parser.DT_IGNORE); // TODO find out what this is doing
	    StatementHandler sh = new StatementHandler()
	    {
		public void handleStatement(Resource subj, URI pred, Value obj)
		{
		    addSingleStatement(subj, pred, obj);
	}
	    };
	    parser.setStatementHandler(sh);
	    parser.parse(dataStream, baseURI);
	    dataStream.close();
	}
	catch (Exception e)
	{
	    System.out.println(e.getMessage());
	}
	finally
	{
	    dataStream.close();
	}
    }

    public void addData(File dataFile, String baseURI, RDFFormat format, boolean verifyData, AdminListener listener) throws FileNotFoundException, IOException, AccessDeniedException
    {
	InputStream inputStream = new FileInputStream(dataFile);
	addData (inputStream, baseURI, format, verifyData, listener);
    }

    public NamespaceIterator getNamespaces()
    {
	List<org.openrdf.sesame.sailimpl.memory.Namespace> namespaceList = new ArrayList<org.openrdf.sesame.sailimpl.memory.Namespace>();
	// TODO verify that this query is correct
	StringBuffer query = new StringBuffer();
	query.append("SELECT distinct RP_NAME, RP_ID from DB.DBA.RDF_PREFIX");
	try
	{
	    java.sql.Statement stmt = this.connection.createStatement();
	    VirtuosoResultSet results = (VirtuosoResultSet) stmt.executeQuery(query.toString());
	    ResultSetMetaData data = results.getMetaData();

	    // begin at onset one
	    while (results.next())
	    {
		String name = null;
		String prefix = null;
		for (int meta_count = 1; meta_count <= data.getColumnCount(); meta_count++)
		{
		    // TODO need to parse these into appropriate resource values
		    String col = data.getColumnName(meta_count);
		    if(col.equals("RP_ID"))
		    {
			name = results.getString(col);
		    }
		    else if(col.equals("RP_NAME"))
		    {
			prefix = results.getString(col);
		    }
		}
		if(name != null && prefix != null)
		{
		    org.openrdf.sesame.sailimpl.memory.Namespace ns =  new org.openrdf.sesame.sailimpl.memory.Namespace(prefix, name, false);
		    namespaceList.add(ns);
		}
	    }
	}
	catch (Exception e)
	{
	    e.printStackTrace();
	    System.exit(-1);
	}
	return new MemNamespaceIterator(namespaceList);
    }

    public void addSingleStatement (Resource subj, URI pred, Value obj)
    {
	String s, p, o;
	String query;

	s = subj.toString();
	p = pred.toString();
	o = obj.toString();
	
	s = s.replaceAll("'", "''");
	p = p.replaceAll("'", "''");
	o = o.replaceAll("'", "''");

	query = "DB.DBA.RDF_QUAD_URI ('" + this.graphName + "', '" + s + "', '" + p + "', '" + o + "')";

		try
		{
		    java.sql.Statement stmt = connection.createStatement();
	    stmt.executeUpdate(query);
		}
		catch(Exception e)
		{
		    e.printStackTrace();
		    System.exit(-1);
		}
    }

    /* TODO */

    public void performGraphQuery(QueryLanguage language, String query, GraphQueryResultListener listener) throws IOException, MalformedQueryException, QueryEvaluationException, AccessDeniedException
    {
	query = "SPARQL " + query;

	try
	{
	    java.sql.Statement stmt = connection.createStatement();
	    VirtuosoResultSet results = (VirtuosoResultSet) stmt.executeQuery(query);

	    ResultSetMetaData data = results.getMetaData();
	    String[] col_names = new String[data.getColumnCount()];

	    while (results.next())
	    {
		listener.startGraphQueryResult();
		for (int meta_count = 1; meta_count <= data.getColumnCount(); meta_count++)
		{
		    String col = data.getColumnName(meta_count);
		    String value = results.getString(col);
		    Value v = parseValue(value);
		    listener.triple(null, null, null); // TODO find out how to interpret Virtuoso CONSTRUCT query
		}
		listener.endGraphQueryResult();
	    }

	    listener.endGraphQueryResult();
	}
	catch (Exception e)
    {
	    System.out.println("GET results are FAILED.");
	    e.printStackTrace();
	    System.exit(-1);
	}
    }

    public Graph performGraphQuery(QueryLanguage language, String query) throws IOException, MalformedQueryException, QueryEvaluationException, AccessDeniedException
    {
	QueryResultsGraphBuilder qrgb = new QueryResultsGraphBuilder();
	performGraphQuery(language, query, qrgb);
	return qrgb.getGraph();
    }

    public void addData(String data, String baseURI, RDFFormat format, boolean verifyData, AdminListener listener) throws IOException, AccessDeniedException
    {
	addData(new StringReader(data), baseURI, format, verifyData, listener);
    }

    public void addData(SesameRepository repository, AdminListener listener) throws IOException, AccessDeniedException
    {
	if (this == repository)
	{
	    return;
	}

	InputStream dataStream = repository.extractRDF(RDFFormat.RDFXML, true, true, true, false);

	try
	{
	    addData(dataStream, "foo:bar", RDFFormat.RDFXML, false, listener);
	}
	finally
	{
	    dataStream.close();
	}
    }

    public void addData(Reader reader, String baseURI, RDFFormat format, boolean verifyData, AdminListener listener) throws IOException, AccessDeniedException
    {
    }

    public InputStream extractRDF(RDFFormat format, boolean ontology, boolean instances, boolean explicitOnly, boolean niceOutput) throws IOException, AccessDeniedException
    {
	ByteArrayOutputStream baos = new ByteArrayOutputStream(8092);
	return new ByteArrayInputStream(baos.toByteArray());
    }

    public void extractRDF(RdfDocumentWriter rdfDocWriter, boolean ontology, boolean instances, boolean explicitOnly, boolean niceOutput) throws IOException, AccessDeniedException
	{
    }

    public void removeStatements(Resource subject, URI predicate, Value object, AdminListener listener) throws IOException, AccessDeniedException
    {
	String S, P, O;
	String exec_text;

	S = subject.toString();
	P = predicate.toString();
	O = object.toString();

	exec_text = "jena_remove (" + "'" + this.graphName + "', " + "'" + S + "', " + "'" + P + "', " + "'" + O + "')";

	try
	{
	    java.sql.Statement stmt = this.connection.createStatement();
	    stmt.executeUpdate(exec_text);
	}
	catch(Exception e)
	{
	    listener.error("Problem removing data", 0, 0, new StatementImpl(subject, predicate, object));
	    e.printStackTrace();
	    System.exit(-1);
	};
    }

    public synchronized void shutDown()
    {
    }

    public void mergeGraph(Graph graph) throws IOException, AccessDeniedException
    {
	StatementIterator iter = graph.getStatements();
	    while (iter.hasNext())
	    {
		Statement st = iter.next();

		Resource subject = st.getSubject();
		URI predicate = st.getPredicate();
		Value object = st.getObject();

	    addSingleStatement(subject, predicate, object);
	}
	    iter.close();
	}

    public void addGraph(Graph graph) throws IOException, AccessDeniedException
    {
	addGraph(graph, true);
    }

    public void addGraph(Graph graph, boolean joinBlankNodes) throws IOException, AccessDeniedException
    {
	Map bNodesMap = null;
	ValueFactory factory = null;

	if (!joinBlankNodes)
	{
	    bNodesMap = new HashMap();
	    factory = getValueFactory();
	}

	StatementIterator iter = graph.getStatements();

	    while (iter.hasNext())
	    {
		Statement st = iter.next();

		Resource subject = st.getSubject();
		URI predicate = st.getPredicate();
		Value object = st.getObject();

		if (!joinBlankNodes)
		{
		    if (subject instanceof BNode)
		    {
			String bNodeId = ((BNode)subject).getID();
			if (bNodesMap.containsKey(bNodeId))
			{
			    subject = (Resource)bNodesMap.get(bNodeId);
			}
			else
			{
			    subject = factory.createBNode();
			    //							bNodesMap.put(bNodeId, subject);
			}
		    }

		    if (object instanceof BNode)
		    {
			String bNodeId = ((BNode)object).getID();
			if (bNodesMap.containsKey(bNodeId))
			{
			    object = (Resource)bNodesMap.get(bNodeId);
			}
			else
			{
			    object = factory.createBNode();
			}
		    }
		}

	    addSingleStatement(subject, predicate, object);
	    }
	iter.close();
	}

    public void removeGraph(Graph graph) throws IOException, AccessDeniedException
	{
	StatementIterator sit = graph.getStatements();
	while(sit.hasNext())
	{
	    Statement st = sit.next();
	    for(int i = 0; i < this._listeners.size(); i++)
	    {
		if(this._listeners.get(i) instanceof AdminListener)
		{
		    removeStatements(st.getSubject(), st.getPredicate(), st.getObject(), (AdminListener) this._listeners.get(i));
		}
	}
    }
    }

    public void addGraph(QueryLanguage language, String query) throws IOException, AccessDeniedException 
    {
    }

    public void addGraph(QueryLanguage language, String query, boolean joinBlankNodes) throws IOException, AccessDeniedException
    {
	try
	{
	    Graph graph = performGraphQuery(language, query);
	    addGraph(graph, joinBlankNodes);
	}
	catch (QueryEvaluationException e)
	{
	    throw new IOException(e.getMessage());
	}
	catch (MalformedQueryException e)
	{
	    throw new IOException(e.getMessage());
	}
    }

    public void removeGraph(QueryLanguage language, String query) throws IOException, AccessDeniedException
    {
	try
	{
	    Graph graph = performGraphQuery(language, query);
	    removeGraph(graph);
	}
	catch (QueryEvaluationException e)
	{
	    throw new IOException(e.getMessage());
	}
	catch (MalformedQueryException e)
	{
	    throw new IOException(e.getMessage());
	}
    }

    public String getRepositoryId()
    {
	return _id;
    }

    public String getRepository (String _id)
    {
	return _id;
    }

    public void addListener(LocalRepositoryChangedListener listener)
    {
	synchronized(_listeners)
	{
			_listeners.add(listener);
	}
    }

    public void removeListener(LocalRepositoryChangedListener listener)
    {
	synchronized(_listeners)
	{
	    _listeners.remove(listener);
	}
    }

    public void sailChanged(SailChangedEvent event)
    {
    }

    public ValueFactory getValueFactory()
    {
	return this._valueFactory;
    }


    // native methods
	
    private Value parseValue(String val)
    {
	if(val == null || val.length() == 0) return null;
	try
	{
	    return new URIImpl(val);					
	}
	catch(IllegalArgumentException iaex)
	{
	    //System.out.println("Resource is not a URI: " + val);
	    try
	    {
		return new LiteralImpl(val);
	    }
	    catch(IllegalArgumentException iaex2)
	    {
		// System.out.println("Resource is not a Literal: " + val);
		try
		{
		    return new BNodeImpl(val);					
		}
		catch(IllegalArgumentException iaex3)
		{
		    System.out.println("VirtuosoRepository.parseValue() Could not parse resource: " + val);
		}
	    }
	}
	return null;
    }
}
