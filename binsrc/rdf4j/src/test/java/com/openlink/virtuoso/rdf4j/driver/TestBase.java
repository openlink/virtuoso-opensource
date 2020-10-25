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

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;

public class TestBase {

    static VirtuosoRepository repository;

    @BeforeEach
    public void setUp() throws Exception {
        String host = System.getProperty("test_hostname", "localhost");
        String port = System.getProperty("test_port", "1111");
        String uid = System.getProperty("test_UID", "dba");
        String pwd = System.getProperty("test_PWD", "dba");

        String connurl = "jdbc:virtuoso://" + host + ":" + port + "/log_enable=0";

        repository = new VirtuosoRepository(connurl, uid, pwd);
    }

    @AfterEach
    public void tearDown() throws Exception {
    }

    public static void log(String mess) {
        System.out.println("   " + mess);
    }

}
