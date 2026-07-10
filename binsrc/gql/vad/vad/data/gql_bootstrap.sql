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
--  openGQL: GQL for Virtuoso - Bootstrap / Post-Install Hooks
--
--  Copyright (C) 1998-2026 OpenLink Software
--

create procedure DB.DBA.GQL_BOOTSTRAP_ENDPOINT_GRANTS ()
{
  -- Intentionally left blank.
  -- Endpoint grants are managed manually by the DBA.
  return;
}
;

----------------------------------------------------------------------
-- Node IRI minting
-- Generates a unique IRI for a new node, preferring a deterministic
-- scheme (label+property driven) when labels are present, falling back
-- to a random IRI for unlabeled nodes.
-- IRI scheme: <urn:opengql:node:<label>/<random>
----------------------------------------------------------------------

create procedure DB.DBA.GQL_MINT_NODE_IRI (in _graph varchar, in _labels any, in _props any)
{
  declare label_slug, random_part varchar;
  declare i integer;

  label_slug := '';
  if (_labels is not null and length (_labels) > 0)
    {
      for (i := 0; i < length (_labels); i := i + 1)
        label_slug := concat (label_slug, aref (_labels, i), '/');
    }
  else
    label_slug := '_/';

  -- Use a random IRI suffix for uniqueness; the label prefix makes
  -- IRIs human-readable while the random part prevents collisions.
  return DB.DBA.GQL_NEW_NODE_URI ();
}
;

DB.DBA.GQL_REGISTER_NS ()
;
DB.DBA.GQL_BOOTSTRAP_ENDPOINT_GRANTS ()
;

----------------------------------------------------------------------
-- Schema resolution helper for §17 schema references
----------------------------------------------------------------------

create procedure DB.DBA.GQL_SCHEMA_RESOLVE (in _name varchar)
{
  -- Currently resolves schema names to their IRI form.
  -- In a future phase, this will query the GQL_SCHEMA catalog table
  -- to resolve absolute and relative path references.
  if (_name is null)
    return DB.DBA.GQL_DEFAULT_GRAPH ();
  if (strstr (_name, '://') is not null)
    return _name;
  return concat (DB.DBA.GQL_NS (), 'schema/', _name);
}
;

----------------------------------------------------------------------
-- Graph type enforcement feature flag
-- Set to 0 (disabled) by default. Type checking on INSERT/SET is
-- out of scope for the current phase — graph type specs are recorded
-- in the catalog but not enforced at runtime.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_ENFORCE_TYPES ()
{
  return 0;
}
;
