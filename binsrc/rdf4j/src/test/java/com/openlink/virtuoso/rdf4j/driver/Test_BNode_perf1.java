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

package com.openlink.virtuoso.rdf4j.driver;

import org.eclipse.rdf4j.model.IRI;
import org.eclipse.rdf4j.model.ValueFactory;
import org.eclipse.rdf4j.repository.RepositoryConnection;
import org.eclipse.rdf4j.rio.RDFFormat;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;

import java.net.URL;


public class Test_BNode_perf1 extends TestBase {

    @Test
    @Disabled
    public void test1() throws Exception {
        Perf_ImportFromFile(false);
    }

    @Test
    @Disabled
    public void test2() throws Exception {
        Perf_ImportFromFile(true);
    }


    public static void Perf_ImportFromFile(boolean insertBNodeAsIRI) throws Exception {

        repository.setInsertBNodeAsVirtuosoIRI(insertBNodeAsIRI);

        try (RepositoryConnection con = repository.getConnection()) {

            // test add data to the repository
            ValueFactory vfac = repository.getValueFactory();
            IRI context = vfac.createIRI("test:blank");

            if (insertBNodeAsIRI)
                System.out.println("\nTest Import data from File (BNode as Virtuoso IRI)");
            else
                System.out.println("\nTest Import data from File (BNode as Virtuoso Native BNode)");

            log("Insert data with BNodes from file sp2b.n3");


            int REPEAT = 3;
            long cum_time = 0;

            for (int i = 0; i < REPEAT; i++) {

                con.clear(context);

                IRI ns = repository.getValueFactory().createIRI("http://localhost/publications/journals/Journal3/1967");
                IRI np = repository.getValueFactory().createIRI("http://swrc.ontoware.org/ontology#editor");
                IRI np1 = repository.getValueFactory().createIRI("http://xmlns.com/foaf/0.1/name");

                log("== Exec " + i);

                ClassLoader classLoader = Thread.currentThread().getContextClassLoader();
                URL dataFile = classLoader.getResource("sp2b.n3");

                if (!con.isActive())
                    con.begin();

                long start_time = System.currentTimeMillis();
                con.add(dataFile, "", RDFFormat.N3, context);
                long end_time = System.currentTimeMillis();
                con.commit();
                long tst_time = (end_time - start_time);
                cum_time += tst_time;
                log("Time :" + (end_time - start_time) + " ms");

                long count = con.size(context);
                log("Inserted :" + count + " triples");
            }
            log("AVG TIME = " + cum_time / REPEAT + " ms");

        }
    }

}
