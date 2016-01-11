--  
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2016 OpenLink Software
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

use PUMP
;


--drop procedure html_a_out;

create procedure "PUMP"."DBA"."HTML_A_OUT" ( 	in arr any,
				in href varchar,
				in text varchar,
				in class varchar,
				in dop varchar,
				in onclick varchar )
{
  http('<a ');
  if (length(arr)>1)
    href := sprintf('%s?all_together_now=%s',href,
	"PUMP"."DBA"."URLIFY_STRING" (
		"PUMP"."DBA"."__GET_KEYWORD" ('all_together_now',arr,'')));
--dbg_obj_print(href);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('href',href);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('class',class);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('onclick',onclick);
  "PUMP"."DBA"."HTML_STR_OUT" (dop);
  http('>');
  "PUMP"."DBA"."HTML_STR_OUT" (text);
  http('</a>\n');
}
;


--drop procedure html_button_out;

create procedure "PUMP"."DBA"."HTML_BUTTON_OUT" ( in arr any,
				  in name varchar,
				  in val varchar,
				  in onclick varchar,
				  in class varchar,
				  in dop varchar  )
{
  http('<input type=button ');
  "PUMP"."DBA"."HTML_SMTH_OUT" ('value',val); --"PUMP"."DBA"."__GET_KEYWORD" (name,arr,val));
  "PUMP"."DBA"."HTML_SMTH_OUT" ('onclick',onclick);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('name',name);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('class',class);
  "PUMP"."DBA"."HTML_STR_OUT" (dop);
  "PUMP"."DBA"."__CHECK_TITLE" (name);
  http('>\n');
--  __CHECK_HELP (name);
}
;


--drop procedure html_style_out;
--create procedure "PUMP"."DBA"."HTML_STYLE_OUT" ( in host varchar )
--{
--  declare page, s varchar;
--  s := sprintf('http://%s/admin/dbpump/dbpump_style.html',host);
--  page:=http_get (s);
--  http (page);
--}
--;


--drop procedure html_script_out;
--create procedure "PUMP"."DBA"."HTML_SCRIPT_OUT" ( in host varchar )
--{
--  declare page varchar;
--  page := sprintf('http://%s/admin/dbpump/dbpump_scripts.html',host);
--  page:=http_get (page);
--  http (page);
--}
--;


--drop procedure HTML_LINK_OUT;
create procedure "PUMP"."DBA"."HTML_LINK_OUT" (	in arr any,
					in href varchar,
					in text varchar,
					in class varchar,
					in dop varchar ,
					in code integer)
{
  if (code=49) --'1'
    {
	declare s varchar;
	s := sprintf ('document.forms[0].action=\'%s\';',href);
        "PUMP"."DBA"."HTML_BUTTON_OUT" ( arr, 'button', text,
		concat (s,'document.forms[0].submit();'), class, 'STYLE="background-color:#cccccc"');
    }
  else
    {
	declare s varchar;
	s := 'disabled="true" STYLE="background-color:';
	if (code=50)
	  s := concat(s,'#cccccc;"');
	else
	  s := concat(s,'#666666;"');
        "PUMP"."DBA"."HTML_BUTTON_OUT" ( arr, NULL, text, 'document.forms[0].submit();', class, s);
    }
}
;


create procedure "PUMP"."DBA"."TEST_CONNECTED" ( in flag integer , in val integer )
{
  if (flag)
    return val;
  return 50;
}
;

--drop procedure html_header_out;
create procedure "PUMP"."DBA"."HTML_HEADER_OUT" ( in arr any,  in text varchar, in mask varchar)
{
  http('<BODY>\n');
  http('<TABLE WIDTH="100%" BORDER="0" CELLPADDING="0" CELLSPACING="0">\n');

  if (text is not null)
    text := sprintf ('<a href="dbdoc.vsp">%s</a>', text);

  http(sprintf('<TR><TD CLASS="AdmPagesTitle"><H2>%s</H2></TD></TR>', coalesce(text,'NO HEADING')));
  http('<TR><TD CLASS="AdmBorders" COLSPAN="2" ALIGN="middle">\n');
--  http('<TR><TD CLASS="CtrlMain" COLSPAN="2" ALIGN="middle"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="15" ALT=""></TD></TR>\n');
--  http('<TR><TD CLASS="CtrlMain" COLSPAN="2" ALIGN="middle">');

  if (mask is null)
    mask := '        ';
  if (length(mask)<8)
    mask := sprintf('%-.8s',mask);

  http('<form method=get>');
--  http('<table border="0" cellpadding="0"><tr>');
--  http('</td><td width=1*>');
--  "PUMP"."DBA"."HTML_LINK_OUT" (arr, 'dump_page.vsp', '    Dump  ', '', ' width="100pt" title="Dump Page"', 49);
--  http('</td><td width=1*>');
--  "PUMP"."DBA"."HTML_LINK_OUT" (arr, 'restore_page.vsp', '  Restore ', '', ' width="100pt" title="Restore Page"', 49);
--  http('</td><td width=1*>');
--  "PUMP"."DBA"."HTML_LINK_OUT" (arr, 'browse_page.vsp', '  Browse  ', '', ' width="100pt" title="Repository browser"', 49);
--  http('</td><td width=1*>');
--  "PUMP"."DBA"."HTML_LINK_OUT" (arr, 'dbdoc.vsp', '   Help    ', '', ' width="100pt" title="Help"', 49);

--  http('</td>');
--  http('</tr></table>');

  http('</TD></TR><TR><TD CLASS="AdmBorders" COLSPAN="1"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></td></tr>\n');
  http('<TR><TD CLASS="CtrlMain" COLSPAN="2" ALIGN="middle">');

--  "PUMP"."DBA"."HTML_HIDDEN_OUT" (arr, 'all_together_now', NULL, NULL);
}
;

--drop procedure dump_debug_info;
create procedure "PUMP"."DBA"."DUMP_DEBUG_INFO" ( in arr any )
{
  declare i,n integer;
  declare s varchar;

  i:=0;
  http('<table class="genlist" border="0" cellpadding="0">');
  n:=length(arr);
  while(i<n)
    {
      http('<tr><td CLASS="statlisthead">');
      http(aref(arr,i));
      http('</td><td CLASS="statdata">');
      s:=aref(arr,i+1);
      if (s is not null and length(s)>100)
        s := subseq(s,0,100);
      http(s);
      http('</td></tr>');
      i:=i+2;
    }
  http('</table>');
}
;

--drop procedure html_footer_out;
create procedure "PUMP"."DBA"."HTML_FOOTER_OUT" ( inout arr any )
{
  http('</form></td></tr>');
  declare s varchar;
  s := "PUMP"."DBA"."__GET_KEYWORD" ('last_error',arr,'');
  if (s is not null and length(s))
    {
      http ('<TR><TD CLASS="CtrlMain" COLSPAN="2" ALIGN="middle">');
      "PUMP"."DBA"."HTML_LARGETEXT_OUT" (arr, 'last_error', 'Internal error:\n', NULL, NULL, '  width=50% ');
      http ('</TD></TR>');
      "PUMP"."DBA"."CHANGE_VAL" (arr, 'last_error', '');
      "PUMP"."DBA"."HIDDEN_VAL_OUT" (arr, 'last_error');
    }

  s := "PUMP"."DBA"."__GET_KEYWORD" ('debug_in_footer',arr,'');
  if (s is not null and equ(s,'on'))
    {
      http ('<TR><TD CLASS="AdmBorders" COLSPAN="2"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></TD></TR>\n');
      http ('<TR><TD CLASS="CtrlMain" COLSPAN="2" ALIGN="middle">');
      "PUMP"."DBA"."DUMP_DEBUG_INFO" (arr);
      http ('</TD></TR>');
    }
  http ('<TR><TD CLASS="CopyrightBorder" COLSPAN="2"><IMG SRC="/admin/images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></TD></TR>');
  http ('<TR><TD ALIGN="right" COLSPAN="2"><P CLASS="Copyright">Virtuoso Server ');
  http (sys_stat('st_dbms_ver'));
  http (' DBPUMP Interface - Copyright&copy; 1998-2016 OpenLink Software.</P></TD></TR>');
  http ('</TABLE>\n</BODY>');
}
;

--drop procedure html_reset_out;
create procedure "PUMP"."DBA"."HTML_RESET_OUT" ( in arr any,
					in name varchar,
					in val varchar,
					in onclick varchar,
					in class varchar,
					in dop varchar  )
{
  http('<input type=reset ');
  "PUMP"."DBA"."HTML_SMTH_OUT" ('value',val); --"PUMP"."DBA"."__GET_KEYWORD" (name,arr,val));
  "PUMP"."DBA"."HTML_SMTH_OUT" ('onclick',onclick);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('name',name);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('class',class);
  "PUMP"."DBA"."HTML_STR_OUT" (dop);
  "PUMP"."DBA"."__CHECK_TITLE" (name);
  http('>\n');
--  __CHECK_HELP (name);
}
;

--drop procedure html_submit_out;
create procedure "PUMP"."DBA"."HTML_SUBMIT_OUT" ( 	in arr any,
					in name varchar,
					in val varchar,
					in onclick varchar,
					in class varchar,
					in dop varchar  )
{
  http('<input type=reset ');
  "PUMP"."DBA"."HTML_SMTH_OUT" ('value',"PUMP"."DBA"."__GET_KEYWORD" (name,arr,val));
  "PUMP"."DBA"."HTML_SMTH_OUT" ('onclick',onclick);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('name',name);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('class',class);
  "PUMP"."DBA"."HTML_STR_OUT" (dop);
  "PUMP"."DBA"."__CHECK_TITLE" (name);
  http('>\n');
--  __CHECK_HELP (name);
}
;

--drop procedure html_edit_out;
create procedure "PUMP"."DBA"."HTML_EDIT_OUT" ( in arr any,
					in name varchar,
					in text varchar,
					in val varchar,
					in class varchar,
					in dop varchar  )
{
--  HTML_STR_OUT (text);
  if (text is not null)
    "PUMP"."DBA"."__CHECK_HELP" (name, text);
  http('<input type=text ');
  "PUMP"."DBA"."HTML_SMTH_OUT" ('value',"PUMP"."DBA"."__GET_KEYWORD" (name,arr,val));
  "PUMP"."DBA"."HTML_SMTH_OUT" ('name',name);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('class',class);
  "PUMP"."DBA"."HTML_STR_OUT" (dop);
  "PUMP"."DBA"."__CHECK_TITLE" (name);
  http('>\n');
}
;

--drop procedure html_edit_row_out;
create procedure "PUMP"."DBA"."HTML_EDIT_ROW_OUT" ( 	in arr any,
					in name varchar,
					in text varchar,
					in val varchar,
					in class varchar,
					in dop varchar  )
{
--  HTML_STR_OUT (text);
  http ('<tr><td CLASS="statlisthead">');
  "PUMP"."DBA"."__CHECK_HELP" (name, text);
  http ('</td>');
  http ('<td CLASS="statdata">');
  http('<input type=text ');
  "PUMP"."DBA"."HTML_SMTH_OUT" ('value',"PUMP"."DBA"."__GET_KEYWORD" (name,arr,val));
  "PUMP"."DBA"."HTML_SMTH_OUT" ('name',name);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('class',class);
  "PUMP"."DBA"."HTML_STR_OUT" (dop);
  "PUMP"."DBA"."__CHECK_TITLE" (name);
  http('>');
  http ('</td><tr>\n');
}
;

--drop procedure HTML_HIDDEN_OUT;
create procedure "PUMP"."DBA"."HTML_HIDDEN_OUT" (  	in arr any,
					in name varchar,
					in val varchar,
					in dop varchar )
{
  http('<input type=hidden ');
  "PUMP"."DBA"."HTML_SMTH_OUT" ('value',"PUMP"."DBA"."__GET_KEYWORD" (name,arr,val));
  "PUMP"."DBA"."HTML_SMTH_OUT" ('name',name);
  "PUMP"."DBA"."HTML_STR_OUT" (dop);
  http('>\n');
}
;

--drop procedure html_password_out;
create procedure "PUMP"."DBA"."HTML_PASSWORD_OUT" ( 	in arr any,
					in name varchar,
					in text varchar,
					in val varchar,
					in class varchar,
					in dop varchar  )
{
--  HTML_STR_OUT (text);
  "PUMP"."DBA"."__CHECK_HELP" (name, text);
  http('<input type=password ');
  "PUMP"."DBA"."HTML_SMTH_OUT" ('value',"PUMP"."DBA"."__GET_KEYWORD" (name,arr,val));
  "PUMP"."DBA"."HTML_SMTH_OUT" ('name',name);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('class',class);
  "PUMP"."DBA"."HTML_STR_OUT" (dop);
  "PUMP"."DBA"."__CHECK_TITLE" (name);
  http('>\n');
}
;

--drop procedure html_password_row_out;
create procedure "PUMP"."DBA"."HTML_PASSWORD_ROW_OUT" (	in arr any,
					in name varchar,
					in text varchar,
					in val varchar,
					in class varchar,
					in dop varchar  )
{
--  HTML_STR_OUT (text);
  http ('<tr><td CLASS="statlisthead">');
  "PUMP"."DBA"."__CHECK_HELP" (name, text);
  http ('</td>');
  http ('<td CLASS="statdata">');
  http('<input type=password ');
  "PUMP"."DBA"."HTML_SMTH_OUT" ('value',"PUMP"."DBA"."__GET_KEYWORD" (name,arr,val));
  "PUMP"."DBA"."HTML_SMTH_OUT" ('name',name);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('class',class);
  "PUMP"."DBA"."HTML_STR_OUT" (dop);
  "PUMP"."DBA"."__CHECK_TITLE" (name);
  http('>');
  http ('</td><tr>\n');
}
;

--drop procedure html_textarea_out;
create procedure "PUMP"."DBA"."HTML_TEXTAREA_OUT" ( 	in arr any,
					in name varchar,
					in text varchar,
					in val varchar,
					in class varchar,
					in dop varchar  )
{
--  HTML_STR_OUT (text);
  if (text is not null)
    {
      http ('<table class="genlist" border="0" cellpadding="0">');
      http ('<tr><td class="genhead">');
      "PUMP"."DBA"."__CHECK_HELP" (name, sprintf('&nbsp;%s&nbsp;', text));
      http ('</td></tr>');
      http ('<tr><td class="statdata">');
    }
  http('<textarea ');
  "PUMP"."DBA"."HTML_SMTH_OUT" ('name',name);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('class',class);
  "PUMP"."DBA"."HTML_STR_OUT" (dop);
  "PUMP"."DBA"."__CHECK_TITLE" (name);
  http('>\n');
  "PUMP"."DBA"."HTML_STR_OUT" ("PUMP"."DBA"."__GET_KEYWORD" (name,arr,val));
  http('</textarea>');
  if (text is not null)
    http ('</td></tr></table>');
}
;


--drop procedure html_largetext_out;
create procedure "PUMP"."DBA"."HTML_LARGETEXT_OUT" ( 	in arr any,
					in name varchar,
					in text varchar,
					in val varchar,
					in class varchar,
					in dop varchar  )
{
--  HTML_STR_OUT (text);
  if (dop is null)
    dop := '';
  http (sprintf ('<table class="genlist" border="0" cellpadding="0" %s>', dop));
  http ('<tr><td class="genhead">');
  "PUMP"."DBA"."__CHECK_HELP" (name, sprintf('&nbsp;%s&nbsp;', text));
  http ('</td></tr>');
  http ('<tr><td CLASS="statdata">');
  http('<pre>\n');
  declare s varchar;
  s := "PUMP"."DBA"."__GET_KEYWORD" (name,arr,val);
  if (s is null or length(s)=0)
    s := '<empty>';
  "PUMP"."DBA"."HTML_STR_OUT" (s);
  http('</pre></td></tr></table>');
}
;


--drop procedure html_checkbox_out;
create procedure "PUMP"."DBA"."HTML_CHECKBOX_OUT" (  	in arr any,
					in name varchar,
					in text varchar,
					in val varchar,
					in onclick varchar,
					in class varchar,
					in dop varchar )
{
  http('<input type=checkbox ');
  declare v varchar;
  v := "PUMP"."DBA"."__GET_KEYWORD" (name,arr,val);
--dbg_obj_print(v,name);
  if (equ(v,'on'))
    http(' checked ');
--  dbg_obj_print (v);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('value', v);
--  if (onclick is not null)
    onclick:=concat(onclick, sprintf('if (this.checked)this.form.%s.value=\'on\';else this.form.%s.value=\'\';',name,name));
  "PUMP"."DBA"."HTML_SMTH_OUT" ('onclick',onclick);
--  HTML_SMTH_OUT ('name',concat(name,'_value'));
  "PUMP"."DBA"."HTML_SMTH_OUT" ('class',class);
  "PUMP"."DBA"."HTML_STR_OUT" (dop);
  "PUMP"."DBA"."__CHECK_TITLE" (name);
  http('>');
--  HTML_STR_OUT (text);
  if (text is not null)
    "PUMP"."DBA"."__CHECK_HELP" (name, text);
  http('</input>\n');
  "PUMP"."DBA"."HTML_HIDDEN_OUT" (arr, name, v, NULL);
}
;

--drop procedure html_radio_out;
create procedure "PUMP"."DBA"."HTML_RADIO_OUT" ( 	in arr any,
					in name varchar,
					in val varchar,
					in onclick varchar,
					in class varchar,
					in dop varchar )
{
  declare v any;
  declare i,n integer;
--dbg_obj_print('split1');
  v := split_and_decode(val,0);
  n := length(v);
  if (n<2)
    return;
  i := 0;

  declare cmp varchar;
  cmp := "PUMP"."DBA"."__GET_KEYWORD" (name,arr,'');
  while  (i<n)
    {
      http('<input type=radio ');
      "PUMP"."DBA"."HTML_SMTH_OUT" ('value',aref(v,i));
      onclick:=concat(onclick, sprintf('if (this.checked)this.form.%s.value=\'%s\';else this.form.%s.value=\'off\';',name,aref(v,i),name));
      "PUMP"."DBA"."HTML_SMTH_OUT" ('onclick',onclick);
      if (equ(cmp,aref(v,i)))
	http(' checked ');
      "PUMP"."DBA"."HTML_SMTH_OUT" ('name',concat(name,'_value'));
      "PUMP"."DBA"."HTML_SMTH_OUT" ('class',class);
      "PUMP"."DBA"."HTML_STR_OUT" (dop);
      "PUMP"."DBA"."__CHECK_TITLE" (name);
      http('>');
      if (i+1<n)
        "PUMP"."DBA"."__CHECK_HELP" (name, aref(v,i+1));
      i := i+2;
      http('</input>\n');
    }
  "PUMP"."DBA"."HTML_HIDDEN_OUT" (arr, name, v, NULL);
--   __CHECK_HELP (name);
}
;

--drop procedure html_image_out;
create procedure "PUMP"."DBA"."HTML_IMAGE_OUT" ( in arr any,
					in name varchar,
					in val varchar,
					in onclick varchar,
					in src varchar,
					in class varchar,
					in dop varchar )
{
  http('<input type=image ');
  "PUMP"."DBA"."HTML_SMTH_OUT" ('value',"PUMP"."DBA"."__GET_KEYWORD" (name,arr,val));
  "PUMP"."DBA"."HTML_SMTH_OUT" ('onclick',onclick);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('name',name);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('src',src);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('class',class);
  "PUMP"."DBA"."HTML_STR_OUT" (dop);
  "PUMP"."DBA"."__CHECK_TITLE" (name);
  http('>\n');
--  __CHECK_HELP (name);
}
;

--drop procedure html_file_out;
create procedure "PUMP"."DBA"."HTML_FILE_OUT" (	in arr any,
					in name varchar,
					in text varchar,
					in val varchar,
					in class varchar,
					in dop varchar  )
{
--  HTML_STR_OUT (text);
  "PUMP"."DBA"."__CHECK_HELP" (name, text);
  http('<input type=file ');
  "PUMP"."DBA"."HTML_SMTH_OUT" ('value',"PUMP"."DBA"."__GET_KEYWORD" (name,arr,val));
  "PUMP"."DBA"."HTML_SMTH_OUT" ('name',name);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('class',class);
  "PUMP"."DBA"."HTML_STR_OUT" (dop);
  "PUMP"."DBA"."__CHECK_TITLE" (name);
  http('>\n');
}
;

--drop procedure html_select_out;
create procedure "PUMP"."DBA"."HTML_SELECT_OUT" ( 	in arr any,
					in name varchar,
					in text varchar,
					in val varchar,
					in class varchar,
					in dop varchar,
					in exclude varchar,
					in wid integer := 40,
					in onchange varchar := ''
						)
{
  declare realname, testval varchar;
  realname := concat(name, '_value');
  testval := '';
  if (text is not null)
    {
      http ('<table class="genlist" border="0" cellpadding="0" width=100%>');
      http ('<tr><td class="genhead">');
      "PUMP"."DBA"."__CHECK_HELP" (name, sprintf('&nbsp;%s&nbsp;', text));
      http ('</td></tr>');
      http ('<tr><td CLASS="statdata">');
    }
  http (sprintf ('<select style=\"width=%gin\"',wid/10));
  "PUMP"."DBA"."__CHECK_TITLE" (name);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('name',realname);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('class',class);

  onchange := concat (sprintf ('this.form.%s.value=this.value;', name), onchange);
  "PUMP"."DBA"."HTML_SMTH_OUT" ('onchange', onchange);

  "PUMP"."DBA"."HTML_STR_OUT" (dop);
  http('>');
  declare v,vcmp any;
  declare vexcl any;
  declare i,n,ncmp,j integer;
  if (exclude is not null)
    vexcl := split_and_decode (exclude,0);
  else
    vexcl := NULL;
  v := split_and_decode(val,0);
  n := length(v);
  http (sprintf ('<option>%s</option>\n', repeat('+',wid)));
  if (n<2)
    {
      goto fin;
    }
  i := 0;

  declare cmp varchar;
  cmp := "PUMP"."DBA"."__GET_KEYWORD" (name,arr,'');
  vcmp := split_and_decode (cmp,0,'\0\0@');
  ncmp := length (vcmp);
  while  (i<n)
    {
      declare exstr,valem varchar;
      valem := trim (aref (v,i),' \t\r\n');
      if (vexcl is not null and length(vexcl)>=2)
	{
          exstr := get_keyword(valem,vexcl,'');
	}
      else
	exstr := NULL;
      if ((exstr is null or length(exstr)=0 or neq(valem,exstr)) and valem is not null and length(valem)>0)
	{
	  http('<option ');
	  "PUMP"."DBA"."HTML_SMTH_OUT" ('value',valem);
	  j := 0;
	  while (j<ncmp)
	    {
	      if (equ(aref(vcmp,j),valem))
		{
	          http(' selected ');
		  testval := valem;
		}
	      j := j + 1;
	    }
	  http('>');
	  if (i+1<n)
	     "PUMP"."DBA"."HTML_STR_ENCODE_OUT" (aref(v,i+1));
	  http('\n');
	}
      i := i+2;
    }
fin:
  http ('</select>\n');
  if (text is not null)
    {
      http ('</td></tr>');
      http ('</table>');
    }
  http ('<script>');
  http (sprintf ('document.forms[0].%s.options[0]=null;',realname));
--  http (sprintf ('document.forms[0].%s.onchange=\'alert(12345);this.form.%s.value=this.value;\'',realname, name));
  http ('</script>');
  "PUMP"."DBA"."HTML_HIDDEN_OUT" (arr, name, testval, NULL);
}
;


create procedure "PUMP"."DBA"."OUT_DUMP_TYPE" ( 	in arr any )
{
--create procedure "PUMP"."DBA"."HTML_SELECT_OUT" ( 	in arr any,
--					in name varchar,
--					in text varchar,
--					in val varchar,
--					in class varchar,
--					in dop varchar,
--					in exclude varchar,
--					in wid integer := 40,
--					in onchange varchar := ''
  "PUMP"."DBA"."HTML_SELECT_OUT" (arr,
				'dump_type',
				NULL,
				'1=Everything&2=Schema Only&3=Data Only&0=Custom',
				NULL,
				NULL,
				NULL,
				20,
				'
		if (this.selectedIndex==0)
		{
		  this.form.table_defs.value=\'on\';
		  this.form.triggers.value=\'on\';
		  this.form.stored_procs.value=\'on\';
		  this.form.constraints.value=\'on\';
		  this.form.fkconstraints.value=\'on\';
		  this.form.views.value=\'on\';
		  this.form.users.value=\'on\';
		  this.form.grants.value=\'on\';
		  this.form.table_data.value=\'on\';
		  this.form.submit();
		}
		else if (this.selectedIndex==1)
		{
		  this.form.table_defs.value=\'on\';
		  this.form.triggers.value=\'on\';
		  this.form.stored_procs.value=\'on\';
		  this.form.constraints.value=\'on\';
		  this.form.fkconstraints.value=\'on\';
		  this.form.views.value=\'on\';
		  this.form.users.value=\'on\';
		  this.form.grants.value=\'on\';
		  this.form.table_data.value=\'\';
		  this.form.submit();
		}
		else if (this.selectedIndex==2)
		{
		  this.form.table_defs.value=\'\';
		  this.form.triggers.value=\'\';
		  this.form.stored_procs.value=\'\';
		  this.form.constraints.value=\'\';
		  this.form.fkconstraints.value=\'\';
		  this.form.views.value=\'\';
		  this.form.users.value=\'\';
		  this.form.grants.value=\'\';
		  this.form.table_data.value=\'on\';
		  this.form.submit();
		}
		');
}
;
