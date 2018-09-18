--drop table DB.DBA.SYS_PROJ4_SRIDS;

create table DB.DBA.SYS_PROJ4_SRIDS (
  SR_ID integer,
  SR_FAMILY varchar not null,
  SR_TAG varchar,
  SR_ORIGIN varchar not null,
  SR_IRI IRI_ID_8,
  SR_PROJ4_STRING varchar not null,
  SR_WKT varchar,
  SR_COMMENT varchar,
  SR_PROJ4_XML any,
  primary key (SR_ID, SR_FAMILY) )
alter index SYS_PROJ4_SRIDS on DB.DBA.SYS_PROJ4_SRIDS partition cluster REPLICATED
create unique index SYS_PROJ4_SRIDS_TAG_FAMILY on DB.DBA.SYS_PROJ4_SRIDS (SR_TAG, SR_FAMILY)
alter index SYS_PROJ4_SRIDS_TAG_FAMILY on DB.DBA.SYS_PROJ4_SRIDS partition cluster REPLICATED
;

grant select on DB.DBA.SYS_PROJ4_SRIDS to public
;

create table DB.DBA.SYS_PROJ4_SR_IRIS (
  SRI_IRI varchar not null primary key,
  SRI_SR_ID integer,
  SRI_FAMILY_OF_IRI varchar,
  SRI_CONFLICTING_SR_ID integer,
  SRI_CONFLICTING_FAMILY varchar )
alter index SYS_PROJ4_SR_IRIS on DB.DBA.SYS_PROJ4_SR_IRIS partition cluster REPLICATED
;

create function DB.DBA.PROJ4_SPLIT_INIT_FILE (in content varchar, in path varchar)
{
  declare lines, records any;
  declare linectr, linecount integer;
  declare comment, init, tag varchar;
  vectorbld_init (records);
  lines := split_and_decode (content, 0, '\0\0\n');
  linecount := length (lines);
  linectr := 0;
  comment := '';
  init := '';
  tag := '';
  while (linectr < linecount)
    {
      declare line varchar;
      declare pos integer;
      declare init_items, norm_init_ses any;
      declare ictr, icount integer;
      line := trim (lines [linectr], ' \t\r'); linectr := linectr + 1;
      if (line = '')
        {
          comment := '';
          goto next_line;
        }
      pos := strchr (line, '#');
      if (pos is not null)
        {
          if (comment <> '')
            comment := comment || '\n' || trim (subseq (line, pos+1), ' \t');
          else
            comment := trim (subseq (line, pos+1), ' \t');
          line := subseq (line, 0, pos);
        }
      if (line = '')
        goto next_line;
      if (line[0] = '<'[0])
        {
          pos := strchr (line, '>');
          if (pos is null)
            signal ('22023', '"<" without ">" at line ' || linectr+1 || ' of file ' || path);
          if (pos = 1)
            {
              if (tag = '')
                signal ('22023', '"<>" without opening <nick> at line ' || linectr+1 || ' of file ' || path);
              if (init = '')
                signal ('22023', 'Empty init string between "<' || tag || '>" and "<>" at line ' || linectr+1 || ' of file ' || path);
              if (length (line) > 2)
                signal ('22023', 'Unexpected characters after "<>" at line ' || linectr+1 || ' of file ' || path);
              goto process_record;
            }
          tag := subseq (line, 1, pos);
          line := trim (subseq (line, pos + 1), ' \t');
        }
      if (line = '')
        goto next_line;
      pos := strstr (line, '<>');
      if (pos is null)
        {
          if (tag = '')
            signal ('22023', 'Some text found that is neither "#comment" nor part of init string between "<tag>" and "<>", at line ' || linectr+1 || ' of file ' || path);
          if (init = '')
            init := line;
          else
            init := init || ' ' || line;      
          goto next_line;
        }
      if (tag = '')
        signal ('22023', '"<>" without opening <nick> at line ' || linectr+1 || ' of file ' || path);
      if (init = '')
        init := trim (subseq (line, 0, pos), ' \t');
      else
        init := init || ' ' || trim (subseq (line, 0, pos), ' \t');
      if (init = '')
        signal ('22023', 'Empty init string between "<' || tag || '>" and "<>" at line ' || linectr+1 || ' of file ' || path);
      if (length (line) > pos + 2)
        signal ('22023', 'Unexpected characters after "<>" at line ' || linectr+1 || ' of file ' || path);
process_record: ;
      init := replace (init, '\t', ' ');
      while (strstr (init, '  ') is not null) init := replace (init, '  ', ' ');
      init_items := split_and_decode (init, 0, '\0\0 ');
      icount := length (init_items);
      for (ictr := 0; ictr < icount; ictr := ictr + 1)
        {
          declare itm varchar;
          itm := init_items[ictr];
          if (strchr (itm, '=') is not null and itm[0] <> '+'[0])
            itm := '+' || itm;
          init_items[ictr] := itm;
        }
      gvector_sort (init_items, 1, 0, 1);
      norm_init_ses := string_output();
      for (ictr := 0; ictr < icount; ictr := ictr + 1)
        {
          if (ictr) http (' ', norm_init_ses);
          http (init_items[ictr], norm_init_ses);
        }
      init := string_output_string (norm_init_ses);
      vectorbld_acc (records, vector ('tag', tag, 'init', init, 'comment', comment, 'linectr', linectr));
      comment := '';
      init := '';
      tag := '';
next_line: ;
    }
  vectorbld_final (records);
  return records;
}
;

create procedure DB.DBA.PROJ4_LOAD_INIT_FILE (in path varchar, in _sr_family varchar)
{
  declare content varchar;
  declare records any;
  content := file_to_string (path);
  records := DB.DBA.PROJ4_SPLIT_INIT_FILE (content, path);
  foreach (any rec in records) do
    {
      declare init, tag varchar;
      tag := get_keyword ('tag', rec);
      init := get_keyword ('init', rec);
      insert soft DB.DBA.SYS_PROJ4_SRIDS (SR_ID, SR_FAMILY, SR_TAG, SR_ORIGIN, SR_IRI, SR_PROJ4_STRING, SR_WKT, SR_COMMENT, SR_PROJ4_XML)
      values (case when (regexp_like (tag, '^([0-9])*\044')) then cast (tag as integer) else null end,
        _sr_family, tag, path, null, init, null, get_keyword ('comment', rec), null);
    }
  -- dbg_obj_princ (records);
}
;

create procedure DB.DBA.PROJ4_LOAD_SYS_SRIDS (in projdir varchar := '/usr/share/proj', in only_if_empty_table integer := 0)
{
  if (only_if_empty_table)
    {
      if (exists (select 1 from DB.DBA.SYS_PROJ4_SRIDS))
        return;
      {
        whenever sqlstate '*' goto err;
        log_message ('Initial setup of DB.DBA.SYS_PROJ4_SRIDS data from files in "' || projdir || '"');
        DB.DBA.PROJ4_LOAD_SYS_SRIDS (projdir, 0);
        if (exists (select 1 from DB.DBA.SYS_PROJ4_SRIDS))
          log_message ('DB.DBA.SYS_PROJ4_SRIDS now contains ' || (select count(1) from DB.DBA.SYS_PROJ4_SRIDS) || ' spatial reference systems');
        return;
      }
err:
      log_message ('Error during initial setup of DB.DBA.SYS_PROJ4_SRIDS data: ' || __SQL_STATE || ': ' || __SQL_MESSAGE);
      rollback work;
      delete from DB.DBA.SYS_PROJ4_SRIDS;
      commit work;
      return;
    }
  DB.DBA.PROJ4_LOAD_INIT_FILE (projdir || '/epsg', 'EPSG');
  DB.DBA.PROJ4_LOAD_INIT_FILE (projdir || '/esri', 'ESRI');
  DB.DBA.PROJ4_LOAD_INIT_FILE (projdir || '/esri.extra', 'ESRI');
  DB.DBA.PROJ4_LOAD_INIT_FILE (projdir || '/nad83', 'NAD83');
  DB.DBA.PROJ4_LOAD_INIT_FILE (projdir || '/nad27', 'NAD27');
  commit work;
}
;

create procedure DB.DBA.PROJ4_BEST_SR_PROJ4_STRING_BY_SR_ID (in srid integer, out proj4_string varchar, out family varchar)
{
  declare family_priority_list any;
  family_priority_list := vector ('PG', 'EPSG', 'ESRI', 'NAD83', 'NAD27');
  foreach (varchar fam in family_priority_list) do
    {
      declare strg varchar;
      strg := (select SR_PROJ4_STRING from DB.DBA.SYS_PROJ4_SRIDS where SR_ID = srid and SR_FAMILY=fam);
      if (strg is not null)
        {
          proj4_string := strg;
          family := fam;
          return;
        }
    }
  proj4_string := NULL;
  family := NULL;
}
;

create procedure DB.DBA.PROJ4_LOAD_SYS_SR_IRIS_ENUM_GROUP (in family varchar, in iri_format_string varchar)
{
  for (select SR_ID as srid, SR_PROJ4_STRING as fam_proj4_string from DB.DBA.SYS_PROJ4_SRIDS where SR_FAMILY=family for update) do
    {
      declare best_proj4_string, best_family varchar;
      DB.DBA.PROJ4_BEST_SR_PROJ4_STRING_BY_SR_ID (srid, best_proj4_string, best_family);
      if (best_proj4_string = fam_proj4_string)
        insert replacing DB.DBA.SYS_PROJ4_SR_IRIS (SRI_IRI, SRI_SR_ID, SRI_FAMILY_OF_IRI, SRI_CONFLICTING_SR_ID, SRI_CONFLICTING_FAMILY)
        values (sprintf (iri_format_string, srid), srid, family, NULL, NULL);
      else
        insert replacing DB.DBA.SYS_PROJ4_SR_IRIS (SRI_IRI, SRI_SR_ID, SRI_FAMILY_OF_IRI, SRI_CONFLICTING_SR_ID, SRI_CONFLICTING_FAMILY)
        values (sprintf (iri_format_string, srid), NULL, family, srid, best_family);
      commit work;
    }
}
;

create procedure DB.DBA.PROJ4_LOAD_SYS_SR_IRIS ()
{
  insert replacing DB.DBA.SYS_PROJ4_SR_IRIS (SRI_IRI, SRI_SR_ID, SRI_FAMILY_OF_IRI, SRI_CONFLICTING_SR_ID, SRI_CONFLICTING_FAMILY)
  values ('http://www.opengis.net/def/crs/OGC/1.3/CRS84', 4326, 'OGC/1.3', NULL, NULL);
  commit work;
  DB.DBA.PROJ4_LOAD_SYS_SR_IRIS_ENUM_GROUP ('EPSG', 'http://www.opengis.net/def/crs/EPSG/0/%d');
}
;

create procedure DB.DBA.PROJ4_FILL_SR_IRI_TO_SRID_DICT ()
{
  for (select SRI_IRI, SRI_SR_ID from DB.DBA.SYS_PROJ4_SR_IRIS) do
    {
      dict_put ("Proj4 get_sr_iri_to_srid_dict"(), SRI_IRI, SRI_SR_ID);
      dict_put ("Proj4 get_sr_srid_to_iri_dict"(), SRI_SR_ID, SRI_IRI);
      log_text ('dict_put ("Proj4 get_sr_iri_to_srid_dict"(), ?, ?)', SRI_IRI, SRI_SR_ID);
      log_text ('dict_put ("Proj4 get_sr_srid_to_iri_dict"(), ?, ?)', SRI_SR_ID, SRI_IRI);
    }
}
;

--delete from DB.DBA.SYS_PROJ4_SRIDS;
DB.DBA.PROJ4_LOAD_SYS_SRIDS ('/usr/share/proj', 1)
;

DB.DBA.PROJ4_LOAD_SYS_SR_IRIS ()
;

DB.DBA.PROJ4_FILL_SR_IRI_TO_SRID_DICT ()
;
