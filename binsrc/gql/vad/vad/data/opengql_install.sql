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
--  openGQL: GQL for Virtuoso - Reference Installer
--
--  This script is a manual-install reference. The sticker's post-install
--  DDL does the actual loading during VAD_INSTALL.
--

DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/opengql/gql_runtime.sql', 0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/opengql/gql_pl.sql', 0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/opengql/gql_lexer.sql', 0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/opengql/gql_parser.sql', 0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/opengql/gql_expr.sql', 0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/opengql/gql_plan.sql', 0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/opengql/gql_var_pass.sql', 0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/opengql/gql_translate.sql', 0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/opengql/gql_sparql_gen.sql', 0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/opengql/gql_main.sql', 0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/opengql/gql_stats.sql', 0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/opengql/gql_endpoint.sql', 0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/opengql/gql_bootstrap.sql', 0, 'report', 1);

SELECT DB.DBA.GQL_VERSION();
