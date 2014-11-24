/*
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2008 OpenLink Software
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

import java.util.*;
import com.hp.hpl.jena.graph.Graph;
import com.hp.hpl.jena.rdf.model.*;

import virtuoso.jena.driver.*;


public class VirtuosoSPARQLBatchExample1 {

    public static void main(String[] args) 
    {
	String url;
	if(args.length == 0)
	    url = "jdbc:virtuoso://localhost:1111";
	else
	    url = args[0];

	VirtGraph set = new VirtGraph ("http://test", url, "dba", "dba");

        // open model
        VirtModel vm = VirtModel.openDatabaseModel("http://test", url, "dba", "dba");

	vm.removeAll();

	Resource subj = ResourceFactory.createResource("http://m_subj");
	Property pred = ResourceFactory.createProperty("http://m_pred");

        ArrayList<Statement> lst = new ArrayList<>(5000);

        System.out.println("Start insert...");
        //Insert 12000 triples
        int cnt_insert = 12000;
	for(int i =0; i<cnt_insert; i++){
	  RDFNode obj = ResourceFactory.createPlainLiteral(""+i);
          Statement s = ResourceFactory.createStatement(subj, pred, obj);
          lst.add(s);
          if (lst.size()>=5000) {
            vm.add(lst); // Batch Insert data to DBMS
            lst.clear();
          }
	}

        if (lst.size()>0) {
          vm.add(lst); // Batch Insert data to DBMS
          lst.clear();
        }
        System.out.println(""+cnt_insert+" triples were inserted");

        System.out.println("Start remove...");
        //Remove first 5000 triples
        int cnt_remove = 5000;
	for(int i =0; i<cnt_remove; i++){
	  RDFNode obj = ResourceFactory.createPlainLiteral(""+i);
          Statement s = ResourceFactory.createStatement(subj, pred, obj);
          lst.add(s);
	}
        vm.remove(lst); // Batch Remove data from DBMS
        System.out.println(""+cnt_remove+" triples were removed");
    
    }
}
