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
--  openCypher (openCypher for Virtuoso) - VAD package installer.
--
--  The openCypher VAD ships only the PL translator: it can sit on top of a
--  stock Virtuoso server with no plugin and no core C changes.  Users
--  who cannot deploy `opencypher_plugin.so` (managed Virtuoso, restricted
--  hosts, evaluation environments) can install this VAD and translate
--  / execute openCypher queries through `DB.DBA.CYPHER_TO_SPARQL_PARAMS`
--  and the `/sparql` endpoint's `language=opencypher` mode.
--
--  This script is shipped inside the package for manual recovery and
--  reference.  The VAD sticker's post-install stanza performs the actual
--  package-relative loads using $BASE_PATH$ / $ISDAV$ substitution.
--

DB.DBA.VAD_LOAD_SQL_FILE ('/DAV/VAD/opencypher/cypher_runtime.sql',    0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE ('/DAV/VAD/opencypher/cypher_lexer.sql',      0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE ('/DAV/VAD/opencypher/cypher_parser.sql',     0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE ('/DAV/VAD/opencypher/cypher_expr.sql',       0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE ('/DAV/VAD/opencypher/cypher_plan.sql',       0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE ('/DAV/VAD/opencypher/cypher_translate.sql',  0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE ('/DAV/VAD/opencypher/cypher_sparql_gen.sql', 0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE ('/DAV/VAD/opencypher/cypher_main.sql',       0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE ('/DAV/VAD/opencypher/cypher_opencypher.sql',      0, 'report', 1);
DB.DBA.VAD_LOAD_SQL_FILE ('/DAV/VAD/opencypher/cypher_bootstrap.sql',  0, 'report', 1);

-- Sanity check: emit the version so the VAD installer log shows it.
declare ver varchar;
ver := DB.DBA.CYPHER_VERSION ();
result_names (opencypher_version);
result (ver);
