/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

import java.io.*;
import java.util.HashMap;
import java.net.URL;

import org.openrdf.sesame.query.QueryEvaluationException;
import org.openrdf.sesame.Sesame;
import org.openrdf.sesame.config.AccessDeniedException;
import org.openrdf.sesame.config.ConfigurationException;
import org.openrdf.sesame.config.RepositoryConfig;
import org.openrdf.sesame.config.SailConfig;
import org.openrdf.sesame.config.UnknownRepositoryException;
import org.openrdf.sesame.constants.QueryLanguage;
import org.openrdf.sesame.query.MalformedQueryException;
import org.openrdf.sesame.repository.local.LocalService;
import org.openrdf.sesame.server.SesameServer;
import org.openrdf.sesame.sail.Sail;
import org.openrdf.sesame.admin.AdminListener;
import org.openrdf.sesame.constants.RDFFormat;
import org.openrdf.sesame.Sesame;
import org.openrdf.sesame.repository.SesameService;
import org.openrdf.sesame.repository.SesameRepository;
import org.openrdf.sesame.query.QueryResultsTable;
import org.openrdf.sesame.constants.QueryLanguage;

import org.openrdf.model.Value;
import org.openrdf.util.Enumeration;

import virtuoso.sesame.driver.*;


public class VirtuosoExample1
{

    public static void main(String[] args)
    {

	// example query
	String query = "SELECT ?s ?p ?o from <sesame> WHERE { ?s ?p ?o }";

	try
	{

	    VirtuosoAdminListener _report = null;

	    VirtuosoRepository rep = new VirtuosoRepository ("sesame",
		    "jdbc:virtuoso://localhost:1111", "dba", "dba");

	    rep.clear (_report);

	    URL url = new URL("http://demo.openlinksw.com/dataspace/person/demo#this");

	    rep.addData (url, null, RDFFormat.RDFXML, false, _report);

	    // execute query

	    QueryResultsTable result = rep.performTableQuery(null, query);

	    System.out.println("result.getRowCount = " + result.getRowCount());

	}
	catch (AccessDeniedException ade)
	{
	    System.out.println("Access denied.");
	    System.out.println(ade.getMessage());
	}
	catch (FileNotFoundException fnfe)
	{
	    System.out.println("File not found.");
	    System.out.println(fnfe.getMessage());
	}
	catch (IOException ioe)
	{
	    System.out.println("I/O error.");
	    System.out.println(ioe.getMessage());
	}
	catch (QueryEvaluationException qee)
	{
	    System.out.println("QueryEvaluationException.");
	    System.out.println(qee.getMessage());
	}
	catch (MalformedQueryException mqe)
	{
	    System.out.println("Malformed query - SimpleExample.");
	    System.out.println(mqe.getMessage());
	    mqe.printStackTrace();
	}
	catch (ClassCastException cce)
	{
	    System.out.println("ClassCastException repository.");
	    System.out.println(cce.getMessage());
	    cce.printStackTrace();
	}
    }
}
