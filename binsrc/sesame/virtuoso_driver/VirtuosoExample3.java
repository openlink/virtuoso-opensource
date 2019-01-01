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

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.net.URL;

import org.openrdf.sesame.config.AccessDeniedException;
import org.openrdf.sesame.constants.RDFFormat;
import org.openrdf.sesame.query.MalformedQueryException;
import org.openrdf.sesame.query.QueryEvaluationException;
import org.openrdf.sesame.query.QueryResultsTable;
import org.openrdf.sesame.sail.NamespaceIterator;

import virtuoso.sesame.driver.*;

public class VirtuosoExample3
{
    public static void main(String[] args)
    {

	// example query

	try
	{
	    VirtuosoAdminListener _report = new VirtuosoAdminListener();
	    VirtuosoRepository rep = new VirtuosoRepository("sesame", "jdbc:virtuoso://localhost:1111", "dba", "dba");

	    rep.clear(_report);

	    // TEST 1
	    File dataFile = new File("virtuoso_driver/data.nt");
	    System.out.println("TEST 1: Loading file " + dataFile.getAbsolutePath() + " ...");
	    rep.addData(dataFile, "http://localhost/", RDFFormat.NTRIPLES, false, _report);
	    String query = "SELECT ?s ?p ?o from <sesame> WHERE { ?s ?p ?o }";
	    QueryResultsTable result = rep.performTableQuery(null, query);
	    System.out.println("TEST 1: Passed = " + (result.getRowCount() > 0));

	    // TEST 2
	    System.out.println("TEST 2: Clearing repository ...");
	    rep.clear(_report);
	    query = "SELECT ?s ?p ?o from <sesame> WHERE { ?s ?p ?o }";
	    result = rep.performTableQuery(null, query);
	    System.out.println("TEST 2: Passed = " + (result.getRowCount() == 0));

	    // TEST 3
	    URL url = new URL("http://overdogg.com/rdf/requests/1"); //("http://demo.openlinksw.com/dataspace/person/demo#this");
	    System.out.println("TEST 3: Loading remote file: " + url.toString() + " ...");
	    rep.addData(url, "http://localhost/", RDFFormat.RDFXML, false, _report);
	    // execute query
	    query = "SELECT ?s ?p ?o from <sesame> WHERE { ?s ?p ?o }";
	    result = rep.performTableQuery(null, query);
	    System.out.println("TEST 3: Passed = " + (result.getRowCount() > 0));

	    // TEST 4
	    NamespaceIterator nss = rep.getNamespaces();
	    System.out.println("TEST 4: Passed = " + nss.hasNext());
	}
	catch (AccessDeniedException ade)
	{
	    System.out.println("VirtuosoTest.main() Access denied.");
	    System.out.println(ade.getMessage());
	}
	catch (FileNotFoundException fnfe)
	{
	    System.out.println("VirtuosoTest.main() File not found.");
	    System.out.println(fnfe.getMessage());
	}
	catch (IOException ioe)
	{
	    System.out.println("VirtuosoTest.main() I/O error.");
	    System.out.println(ioe.getMessage());
	}
	catch (QueryEvaluationException qee)
	{
	    System.out.println("VirtuosoTest.main() QueryEvaluationException.");
	    System.out.println(qee.getMessage());
	}
	catch (MalformedQueryException mqe)
	{
	    System.out.println("VirtuosoTest.main() Malformed query - SimpleExample.");
	    System.out.println(mqe.getMessage());
	    mqe.printStackTrace();
	}
	catch (ClassCastException cce)
	{
	    System.out.println("VirtuosoTest.main() ClassCastException.");
	    System.out.println(cce.getMessage());
	    cce.printStackTrace();
	}
    }
}
