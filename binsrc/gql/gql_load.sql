--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2026 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--
--
--
--  openGQL: GQL for Virtuoso - Loader Script
--
--  Load all openGQL components in dependency order.
--  Usage from isql: LOAD binsrc/gql/gql_load.sql;
--

LOAD binsrc/gql/gql_runtime.sql;
LOAD binsrc/gql/gql_pl.sql;
LOAD binsrc/gql/gql_lexer.sql;
LOAD binsrc/gql/gql_expr.sql;
LOAD binsrc/gql/gql_parser.sql;
LOAD binsrc/gql/gql_plan.sql;
LOAD binsrc/gql/gql_var_pass.sql;
LOAD binsrc/gql/gql_translate.sql;
LOAD binsrc/gql/gql_sparql_gen.sql;
LOAD binsrc/gql/gql_main.sql;
LOAD binsrc/gql/gql_endpoint.sql;
LOAD binsrc/gql/gql_bootstrap.sql;

-- Verify installation
SELECT DB.DBA.GQL_VERSION();
