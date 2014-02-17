--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
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

drop table XSLTS;
create table XSLTS (
    KIND varchar not null primary key,
    DATA long varchar);


create procedure
XSLT_CHDIR (in dir varchar, in dummy any, out response varchar)
{
  --dbg_obj_print ('XSLT_CHDIR', dir);
  response := 'OK';

  insert replacing XSLTS (KIND, DATA) values ('DIR', dir);
}
;

create procedure
XSLT_STYLESHEET (in stylesheet varchar, in dummy any, out response varchar)
{
  --dbg_obj_print ('XSLT_STYLESHEET', stylesheet);
  response := 'OK';

  declare dir varchar;
  dir := '';
  select DATA into dir from XSLTS where KIND = 'DIR';
  stylesheet := file_to_string_output (concat (dir, '/', stylesheet));
  insert replacing XSLTS (KIND, DATA) values ('STYLE', stylesheet);
}
;

create procedure
XSLT_INPUT (in inp varchar, in dummy any, out response varchar)
{
  --dbg_obj_print ('XSLT_INPUT', inp);
  response := 'OK';

  declare dir varchar;
  dir := '';
  select DATA into dir from XSLTS where KIND = 'DIR';

  inp := file_to_string_output (concat (dir, '/', inp));
  insert replacing XSLTS (KIND, DATA) values ('FILE', inp);
}
;

create procedure
XSLT_TRANSFORM (in outfile varchar, in iters integer, out response varchar)
{
  --dbg_obj_print ('XSLT_TRANSFORM', outfile, 'iters=', iters);

  declare res, tree any;
  declare st, en any;

  st := get_timestamp();
  --dbg_obj_print ('XSLT_TRANSFORM', 'st=', get_timestamp());
  select xml_tree_doc (xml_tree (DATA)) into tree from XSLTS where KIND = 'FILE';

  declare inx integer;
  inx := 0;
  while (inx < iters)
    {
      res := xslt ('virt://DB.DBA.XSLTS.KIND.DATA:STYLE', tree);
      inx := inx + 1;
    }
  --dbg_obj_print ('XSLT_TRANSFORM', 'end=', now());
  en := datediff ('second', st, get_timestamp()) * 1000;
  --dbg_obj_print ('XSLT_TRANSFORM', 'end=', en);

  declare ses any;
  ses := string_output ();
  http_value (res, NULL, ses);

  declare dir varchar;
  dir := '';
  select DATA into dir from XSLTS where KIND = 'DIR';
  string_to_file (concat (dir, '/', outfile), string_output_string (ses), -2);
  response := sprintf ('OK wallclock: %09.2lf ms; cpuclock: %06d', 0.0, en);
}
;

