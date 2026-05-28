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
--  openCypher: SQL/VAD endpoint compatibility helpers.
--

create procedure DB.DBA.OPENCYPHER (in _query varchar, in _default_graph varchar := null)
{
  return DB.DBA.OPENCYPHER_EXEC (_query, _default_graph);
}
;

create procedure DB.DBA.OPENCYPHER_PARAMS (in _query varchar, in _default_graph varchar := null, in _params any := null)
{
  return DB.DBA.CYPHER_PARAMS (_query, _default_graph, _params);
}
;

create procedure WS.WS.SPARQL_ENDPOINT_OPENCYPHER_BODY (in query varchar)
{
  declare q, ql, next_ch varchar;

  if (query is null)
    return null;

  q := trim (query);
  ql := lower (q);

  if (ql = 'opencypher')
    return '';
  if (length (q) > 10 and subseq (ql, 0, 10) = 'opencypher')
    {
      next_ch := subseq (q, 10, 11);
      if (next_ch in (' ', '\t', '\n', '\r'))
        return trim (subseq (q, 10));
    }

  return null;
}
;
