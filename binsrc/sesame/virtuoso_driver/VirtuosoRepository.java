/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2007 OpenLink Software
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

import virtuoso.jdbc3.*;

import java.sql.*;
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
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import org.openrdf.model.impl.LiteralImpl;
import org.openrdf.model.BNode;
import org.openrdf.model.Graph;
import org.openrdf.model.Resource;
import org.openrdf.model.Statement;
import org.openrdf.model.URI;
import org.openrdf.model.Value;
import org.openrdf.model.ValueFactory;
import org.openrdf.model.impl.GraphImpl;
import org.openrdf.rio.RdfDocumentWriter;
import org.openrdf.rio.n3.N3Writer;
import org.openrdf.rio.ntriples.NTriplesWriter;
import org.openrdf.rio.rdfxml.RdfXmlWriter;
import org.openrdf.rio.turtle.TurtleWriter;
import org.openrdf.rio.StatementHandler;
import org.openrdf.rio.StatementHandlerException;
import org.openrdf.rio.ntriples.NTriplesParser;
import org.openrdf.rio.Parser;
import org.openrdf.sesame.admin.AdminListener;
import org.openrdf.sesame.admin.RdfAdmin;
import org.openrdf.sesame.admin.UpdateException;
import org.openrdf.sesame.config.AccessDeniedException;
import org.openrdf.sesame.config.UnknownRepositoryException;
import org.openrdf.sesame.constants.QueryLanguage;
import org.openrdf.sesame.constants.RDFFormat;
import org.openrdf.sesame.export.RdfExport;
import org.openrdf.sesame.query.GraphQuery;
import org.openrdf.sesame.query.GraphQueryResultListener;
import org.openrdf.sesame.query.MalformedQueryException;
import org.openrdf.sesame.query.QueryEvaluationException;
import org.openrdf.sesame.query.QueryResultsGraphBuilder;
import org.openrdf.sesame.query.QueryResultsTable;
import org.openrdf.sesame.query.QueryResultsTableBuilder;
import org.openrdf.sesame.query.TableQuery;
import org.openrdf.sesame.query.TableQueryResultListener;
import org.openrdf.sesame.query.rdql.RdqlEngine;
import org.openrdf.sesame.query.rql.RqlEngine;
import org.openrdf.sesame.query.serql.SerqlEngine;
import org.openrdf.sesame.repository.SesameRepository;
import org.openrdf.sesame.sail.RdfRepository;
import org.openrdf.sesame.sail.RdfSchemaSource;
import org.openrdf.sesame.sail.RdfSource;
import org.openrdf.sesame.sail.Sail;
import org.openrdf.sesame.sail.SailChangedEvent;
import org.openrdf.sesame.sail.SailChangedListener;
import org.openrdf.sesame.sail.SailInternalException;
import org.openrdf.sesame.sail.SailUpdateException;
import org.openrdf.sesame.sail.StatementIterator;
import org.openrdf.sesame.repository.local.*;
//import org.openrdf.sesame.sailimpl.memory.RdfRepository;


public class VirtuosoRepository implements SesameRepository
{
    private RdfSource _rdfSource;
    private String _id;
    private String url;
    private String user;
    private String password;
    private int connection_status = 0;
    private Connection connection = null;
    private List _listeners;

    private SerqlEngine _serqlQueryEngine;
    private RqlEngine _rqlQueryEngine;
    private RdqlEngine _rdqlQueryEngine;
    private RdfAdmin _rdfAdmin;
    private RdfExport _rdfExport;
    private LocalService _service;
    private String graphName;

    protected RdfRepository _expectedModel;

    protected VirtuosoRepository (String id, RdfSource rdfSource, LocalService service)
    {
	_id = id;
	_rdfSource = rdfSource;
	_service = service;

	_listeners = new ArrayList(0);

	if (_rdfSource instanceof VirtuosoRepository)
	{
	    //		        _listeners.add(VirtuosoAdminListener);
	}
    }

    public VirtuosoRepository (String graphName, String url, String user, String password)
    {
	this.graphName = graphName;
	this.url = url;
	this.user = user;
	this.password = password;

	if (connection == null)
	{
	    try
	    {
		Class.forName("virtuoso.jdbc3.Driver");
		connection = DriverManager.getConnection(url, user, password);
		connection_status = 1;
	    }
	    catch(Exception e)
	    {
		System.out.println("Connection to " + url + " is FAILED.");
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

    public QueryResultsTable performTableQuery (QueryLanguage language, String query)
	throws IOException, MalformedQueryException, QueryEvaluationException, AccessDeniedException
    {
	QueryResultsTableBuilder builder = new QueryResultsTableBuilder();
	performTableQuery(language, query, builder);
	return builder.getQueryResultsTable();
    }

    public void performTableQuery (QueryLanguage language, String query, TableQueryResultListener listener)
	throws IOException, MalformedQueryException, QueryEvaluationException, AccessDeniedException
    {
	query = "SPARQL " + query;

	try
	{
	    if (connection == null)
	    {
		Class.forName("virtuoso.jdbc3.Driver");
		Connection connection = DriverManager.getConnection(url, user, password);
	    }
	    java.sql.Statement stmt = connection.createStatement();
	    VirtuosoResultSet result_set = (VirtuosoResultSet) stmt.executeQuery(query);

	    ResultSetMetaData data = result_set.getMetaData();
	    String[] col_names = new String[data.getColumnCount()];

	    for(int meta_count = 0; meta_count < data.getColumnCount(); meta_count++)
	    {
		col_names[meta_count] = data.getColumnLabel(meta_count + 1);
	    }

	    listener.startTableQueryResult (col_names);

	    while(result_set.next())
	    {
		listener.startTuple();
		for(int meta_count = 1;meta_count <= data.getColumnCount();meta_count++)
		{
		    Value value = new LiteralImpl (result_set.getString(meta_count));
		    listener.tupleValue(value);
		}
		listener.endTuple ();
	    }

	    listener.endTableQueryResult ();

	}
	catch(Exception e)
	{
	    System.out.println("GET results are FAILED.");
	    e.printStackTrace();
	    System.exit(-1);
	}

	QueryResultsTableBuilder ret = new QueryResultsTableBuilder ();

    }

    public void addData (URL dataURL, String baseURI, RDFFormat format, boolean verifyData, AdminListener listener)
	throws IOException, AccessDeniedException
    {
	if (baseURI == null)
	{
	    baseURI = this.graphName;
	}

	String exec_text = "sparql load \"" + dataURL + "\" into graph <" + this.graphName + ">";

	try
	{
	    java.sql.Statement stmt = connection.createStatement();
	    stmt.executeQuery(exec_text);
	}
	catch(Exception e)
	{
	    e.printStackTrace();
	    System.exit(-1);
	}
    }

    public void clear (AdminListener listener)
	throws IOException, AccessDeniedException
    {
	try
	{
	    String exec_text ="delete from RDF_QUAD where G=DB.DBA.RDF_MAKE_IID_OF_QNAME ('" + this.graphName + "')";
	    java.sql.Statement stmt = connection.createStatement();
	    stmt.executeUpdate(exec_text);
	}
	catch(Exception e)
	{
	    e.printStackTrace();
	    System.exit(-1);
	}
    }

    public void addData (InputStream dataStream, String baseURI, RDFFormat format, boolean verifyData, AdminListener listener)
	throws IOException, AccessDeniedException
    {
	try
	{
	    NTriplesParser _nTriplesParser;
	    Map noParams = new HashMap();
	    _nTriplesParser = new NTriplesParser();
	    _nTriplesParser.setDatatypeHandling(Parser.DT_IGNORE);
	    _expectedModel = new org.openrdf.sesame.sailimpl.memory.RdfRepository();
	    _expectedModel.initialize(noParams);
	    _nTriplesParser.setStatementHandler(
		    new StatementHandler() {
			public void handleStatement(Resource subj, URI pred, Value obj) {
			    try {
				_expectedModel.addStatement(subj, pred, obj);
			    }
			    catch (SailUpdateException e) {
				e.getMessage();
			    }
			}
		    });
	    _expectedModel.startTransaction();
	    _nTriplesParser.parse(dataStream, "");
	    dataStream.close();
	    _expectedModel.commitTransaction();

	    StatementIterator statIter = _expectedModel.getStatements(null, null, null);
	    String S, P, O;
	    String exec_text;


	    while (statIter.hasNext())
	    {
		Statement st = statIter.next();
		S = st.getSubject().toString();
		P = st.getPredicate().toString();
		O = st.getObject().toString();
		S = S.replaceAll("'", "''");
		P = P.replaceAll("'", "''");
		O = O.replaceAll("'", "''");

		exec_text ="DB.DBA.RDF_QUAD_URI ('" + this.graphName +
		    "', '" + S +
		    "', '" + P +
		    "', '" + O +
		    "')";

		try
		{
		    java.sql.Statement stmt = connection.createStatement();
		    stmt.executeQuery(exec_text);
		}
		catch(Exception e)
		{
		    e.printStackTrace();
		    System.exit(-1);
		}
	    }

	}
	catch (Exception e) {
	    System.out.println(e.getMessage());
	}
	finally
	{
	    dataStream.close();
	}

    }

    public void addData (File dataFile, String baseURI, RDFFormat format, boolean verifyData, AdminListener listener)
	throws FileNotFoundException, IOException, AccessDeniedException
    {
	InputStream inputStream = new FileInputStream(dataFile);
	addData (inputStream, baseURI, format, verifyData, listener);
    }


    /* TODO */

    public void performGraphQuery (QueryLanguage language, String query, GraphQueryResultListener listener)
	throws IOException, MalformedQueryException, QueryEvaluationException, AccessDeniedException
    {
    }

    public Graph performGraphQuery (QueryLanguage language, String query)
	throws IOException, MalformedQueryException, QueryEvaluationException,
	       AccessDeniedException
    {
	QueryResultsGraphBuilder listener = new QueryResultsGraphBuilder();
	return new GraphImpl();
    }

    public void addData (String data, String baseURI, RDFFormat format, boolean verifyData, AdminListener listener)
	throws IOException, AccessDeniedException
    {
	addData(new StringReader(data), baseURI, format, verifyData, listener);
    }

    public void addData (SesameRepository repository, AdminListener listener)
	throws IOException, AccessDeniedException
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

    public void addData (Reader reader, String baseURI, RDFFormat format, boolean verifyData, AdminListener listener)
	throws IOException, AccessDeniedException
    {
	try
	{
	    _rdfAdmin.addRdfModel(reader, baseURI, listener, format, verifyData);
	}
	catch (UpdateException e)
	{
	    listener.error("error while adding new triples: " + e.getMessage(), -1, -1, null);
	}
    }

    public InputStream extractRDF (RDFFormat format, boolean ontology,
	    boolean instances, boolean explicitOnly, boolean niceOutput)
	throws IOException, AccessDeniedException
    {
	ByteArrayOutputStream baos = new ByteArrayOutputStream(8092);
	return new ByteArrayInputStream(baos.toByteArray());
    }

    public void extractRDF (RdfDocumentWriter rdfDocWriter, boolean ontology,
	    boolean instances, boolean explicitOnly, boolean niceOutput)
	throws IOException, AccessDeniedException
    {
	if (_rdfExport == null)
	{
	    _rdfExport = new RdfExport();
	}

	if (_rdfSource instanceof RdfSchemaSource)
	{
	    _rdfExport.exportRdf((RdfSchemaSource)_rdfSource, rdfDocWriter,
		    ontology, instances, explicitOnly, niceOutput);
	}
	else
	{
	    _rdfExport.exportRdf(_rdfSource, rdfDocWriter, niceOutput);
	}
    }

    public void removeStatements (Resource subject, URI predicate, Value object, AdminListener listener)
	throws IOException, AccessDeniedException
    {
	String S, P, O;
	String exec_text;

	S = subject.toString();
	P = predicate.toString();
	O = object.toString();

	exec_text ="jena_remove (" +
	    "'" + this.graphName + "', " +
	    "'" + S + "', " +
	    "'" + P + "', " +
	    "'" + O + "')";

	System.out.println (exec_text);

	try
	{
	    //			_rdfAdmin.removeStatements(subject, predicate, object, listener);
	}
	catch(Exception e)
	{
	    e.printStackTrace();
	    System.exit(-1);
	}
	;
    }

    public Sail getSail()
    {
	return _rdfSource;
    }

    public synchronized void shutDown()
    {
	if (_rdfSource != null)
	{
	    _rdfSource.shutDown();
	    _rdfSource = null;
	    _serqlQueryEngine = null;
	    _rqlQueryEngine = null;
	    _rdqlQueryEngine = null;
	    _rdfAdmin = null;
	    _rdfExport = null;
	}
    }

    public void mergeGraph (Graph graph)
	throws IOException, AccessDeniedException
    {
	RdfRepository thisRep = (RdfRepository)_rdfSource;
	StatementIterator iter = graph.getStatements();

	try
	{
	    thisRep.startTransaction();
	    while (iter.hasNext())
	    {
		Statement st = iter.next();

		Resource subject = st.getSubject();
		URI predicate = st.getPredicate();
		Value object = st.getObject();
		thisRep.addStatement(subject, predicate, object);
	    }
	}
	catch (SailUpdateException e)
	{
	    throw new IOException(e.getMessage());
	}
	finally
	{
	    thisRep.commitTransaction();
	    iter.close();
	}
    }


    public void addGraph(Graph graph)
	throws IOException, AccessDeniedException
    {
	addGraph(graph, true);
    }

    public void addGraph (Graph graph, boolean joinBlankNodes)
	throws IOException, AccessDeniedException
    {

	RdfRepository thisRep = (RdfRepository)_rdfSource;

	Map bNodesMap = null;
	ValueFactory factory = null;

	if (!joinBlankNodes)
	{
	    bNodesMap = new HashMap();
	    factory = thisRep.getValueFactory();
	}

	StatementIterator iter = graph.getStatements();

	try {
	    thisRep.startTransaction();
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
			    //							bNodesMap.put(bNodeId, object);
			}
		    }
		}

		thisRep.addStatement(subject, predicate, object);
	    }
	}
	catch (SailUpdateException e)
	{
	    throw new IOException(e.getMessage());
	}
	finally
	{
	    thisRep.commitTransaction();
	    iter.close();
	}
    }

    public void removeGraph (Graph graph)
	throws IOException, AccessDeniedException
    {
    }

    public void addGraph (QueryLanguage language, String query)
	throws IOException, AccessDeniedException
    {
    }

    public void addGraph (QueryLanguage language, String query, boolean joinBlankNodes)
	throws IOException, AccessDeniedException
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

    public void removeGraph (QueryLanguage language, String query)
	throws IOException, AccessDeniedException
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
	    //		    _listeners.add(listener);
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
}
