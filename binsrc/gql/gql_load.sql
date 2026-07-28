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

LOAD libsrc/Wi/gql_runtime.sql;
LOAD libsrc/Wi/gql_pl.sql;
LOAD libsrc/Wi/gql_lexer.sql;
LOAD libsrc/Wi/gql_expr.sql;
LOAD libsrc/Wi/gql_parser.sql;
LOAD libsrc/Wi/gql_plan.sql;
LOAD libsrc/Wi/gql_var_pass.sql;
LOAD libsrc/Wi/gql_translate.sql;
LOAD libsrc/Wi/gql_sparql_gen.sql;
LOAD libsrc/Wi/gql_main.sql;
LOAD libsrc/Wi/gql_stats.sql;
LOAD libsrc/Wi/gql_endpoint.sql;
LOAD libsrc/Wi/gql_bootstrap.sql;

-- Verify installation
SELECT DB.DBA.GQL_VERSION();
