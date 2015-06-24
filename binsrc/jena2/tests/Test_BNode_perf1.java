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

import java.io.*;
import java.net.URL;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.util.*;

import com.hp.hpl.jena.graph.NodeFactory;
import com.hp.hpl.jena.query.*;
import com.hp.hpl.jena.rdf.model.*;
import com.hp.hpl.jena.rdf.model.ResourceFactory;
import com.hp.hpl.jena.util.FileManager;
import com.hp.hpl.jena.util.iterator.*;
import com.hp.hpl.jena.graph.*;
import com.hp.hpl.jena.shared.*;

import virtuoso.jena.driver.VirtGraph;
import virtuoso.jena.driver.VirtModel;


public class Test_BNode_perf1 {

    public static final String VIRTUOSO_INSTANCE = "localhost";
    public static final int VIRTUOSO_PORT = 1111;
    public static final String VIRTUOSO_USERNAME = "dba";
    public static final String VIRTUOSO_PASSWORD = "dba";


    public static void log(String mess) {
        System.out.println("   " + mess);
    }


    public static void main(String[] args) {

        Perf_ImportFromFile(args, false);
        Perf_ImportFromFile(args, true);
    }



    public static void Perf_ImportFromFile(String[] args, boolean insertBNodeAsIRI) {

        String[] sa = new String[4];
        sa[0] = VIRTUOSO_INSTANCE;
        sa[1] = VIRTUOSO_PORT + "";
        sa[2] = VIRTUOSO_USERNAME;
        sa[3] = VIRTUOSO_PASSWORD;
        for (int i = 0; i < sa.length && i < args.length; i++) {
            sa[i] = args[i];
        }

        VirtModel vm = VirtModel.openDatabaseModel("test:jbnode", "jdbc:virtuoso://" + sa[0] + ":" + sa[1], sa[2], sa[3]);
        vm.setInsertBNodeAsVirtuosoIRI(insertBNodeAsIRI);

        try {

            // test add data to the repository
            boolean ok = true;

            System.out.println("\n\n++++++++++++++++++++++++++++++++++++++++++++++++++++++++");
            if (insertBNodeAsIRI)
              System.out.println("Test Import data from File (BNode as Virtuoso IRI)");
            else
              System.out.println("Test Import data from File (BNode as Virtuoso Native BNode)");
            System.out.println("++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
            log("Insert data with BNodes from file sp2b.n3");


            int REPEAT=3;
            long cum_time=0;

            for(int i=0; i<REPEAT; i++) {

              vm.removeAll();

              log("== Exec "+i);
              try
              {
                String nfile = "sp2b.n3";

                InputStream in = FileManager.get().open(nfile);
                if (in == null) {
                    throw new IllegalArgumentException( "File: " + nfile + " not found");
                }

                vm.begin();
	        long start_time = System.currentTimeMillis();
                vm.read(new BufferedReader(new InputStreamReader(in)), null, "N3");
	        long end_time = System.currentTimeMillis(); 
   	        vm.commit();
	        long tst_time = (end_time-start_time);
	        cum_time += tst_time;
 	        log("Time :"+(end_time-start_time)+" ms");

   	        long count = vm.size();
 	        log("Inserted :"+count+" triples");

              } catch (Exception e) {
                log("***FAILED Test "+e);
                ok = false;
              }
            }
            log("AVG TIME = "+cum_time/REPEAT+" ms");

        }
        catch (Exception e) {
            System.out.println("ERROR Test Failed.");
            e.printStackTrace();
        }
        finally {
            if (vm != null) try {
                vm.close();
            }
            catch (JenaException e) {
                e.printStackTrace();
            }
        }
    }

}
