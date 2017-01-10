/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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
 *
*/



// Get object form

function
dav_object_form ()
{
  return window.top.frames[1].document.obj_form;
}


// get top form

function
dav_top_form ()
{
  return window.top.frames[0].document.top_form;
}

// get bot form

function
dav_bot_form ()
{
  return window.top.frames[2].document.bot_form;
}

// get target form

function
dav_target_form ()
{
  //return window.top.opener.document.browser_launch;
  return window.top.opener;
}



function
dav_cd (col_id)
{

  var of = document.obj_form;

  //  alert ('Got col_id: '+col_id);
  of.cur_col.value = of.new_col.value;
  of.new_col.value = col_id;
  of.submit();
}

function
os_cd (os_name)
{

  var of = document.obj_form;

  //  alert ('Got col_id: '+col_id);
  of.os_path.value = os_name;
  of.submit();
}

function
dav_up ()
{
  var of;

  of = window.top.frames[1].document.obj_form;
  if (of.os.value == 'dav')
    of.new_col.value = of.cur_col.value;
  else if (of.os.value == 'os' && of.os_path.value != '' && of.os_path.value != '/')
    of.new_path.value = of.cur_path.value + '/..';
//  util_dbg_show_elems (of);
  of.submit ();
}


//
// Top form Go button onclick
//

function
dav_go_path (path)
{
  var of = dav_object_form ();

  of.new_path.value = path;
  of.submit ();
}

//
// Top form view type onchange evt
//

//function
//dav_view_type_chg (type)
//{
//  var of = dav_object_form ();
//
// of =
//
//}

//
// update path text field on top form (file list onload evt)
//

function
dav_update_path (path)
{
  var tf = dav_top_form ();

//  util_dbg_show_elems (tf);
  if (tf)
    tf.PATH.value = path;
}

//
//  Send result to target form
//

function
dav_send_result (form_name, field_name)
{
  var of = dav_object_form ();
  var tgf = dav_target_form ();
  var bf = dav_bot_form ();
  var tx;
  var i, sform;
  var tf = dav_top_form ();
  var slash;

  browse_mode = of.browse_mode.value;

//  tx = 'of.new_col.value: ' + of.new_col.value;
//  tx += '\n  bf.RES.value: ' + bf.RES.value;
//  tx += '\n bf.PATH.value: ' + bf.PATH.value;
//  tx += '\n         browse_mode: ' + browse_mode;

//  alert (tx);

  // this will work only with fixed name !!
  if (tgf.COL != null)
    tgf.COL.value = of.new_col.value;

  // in both modes we'll return path to destination
  if ('RES' == browse_mode || 'COL' == browse_mode)
    {
      if (tgf.RES != null)
        tgf.RES.value = bf.RES.value;
      if (tgf.PATH != null)
        tgf.PATH.value = bf.PATH.value;
      // the above works only with fixed names !!!

      sform = tgf.document.forms[form_name];
      if (sform != null)
  {
    for (i = 0; i < sform.elements.length; i++)
      {
        if (sform.elements[i].name == field_name)
    {
      if (tf.PATH.value.charAt(tf.PATH.value.length - 1) != '/')
       sform.elements[i].value = tf.PATH.value + '/' + bf.sel_name.value;
      else
       sform.elements[i].value = tf.PATH.value + bf.sel_name.value;
    }
      }
  }
    }
  tgf.focus ();
  window.top.close ();
}

function
dav_newflt (flt_string)
{
  var of = dav_object_form();

  of.flt_pat.value = flt_string;
  of.submit ();
}

function
dav_res_view (url)
{
  window.open (url, 'Viewer', 'menubar=no, scrollbars=yes');
}

function
dav_res_select (_name, _res, _path)
{
//  var str;
//
//  str = 'dav_res_select\n\nname: '+ _name;
//  str += '\n res: ' + _res;
//  str += '\npath: ' + _path;
//  str += '\n\nWindow name: ' + window.top.name;
//
//  alert (str);

  var bf = dav_bot_form ();

  bf.sel_name.value = _name;
  bf.RES.value = _res;
  bf.PATH.value = _path;

//  alert (window.top.frames[2].document.bot_form.res_name);
}

function
dav_launch_browser (browse_mode, lst_mode, xfer_mode,
                    cur_col, new_col, flt_pat)
{
  var launch_url;

  launch_url = 'dav_browser.vsp?';

  if (browse_mode) launch_url += 'browse_mode=' + escape (browse_mode) + '&';
  if (lst_mode) launch_url += 'lst_mode=' + escape (lst_mode) + '&';
  if (xfer_mode) launch_url += 'xfer_mode=' + escape (xfer_mode) + '&';
  if (cur_col) launch_url += 'cur_col=' + escape (cur_col) + '&';
  if (new_col) launch_url += 'new_col=' + escape (new_col) + '&';

  launch_url += 'flt_pat=', + escape (flt_pat);

//  alert (launch_url);

  window.open (launch_url,
         'dav_browser',
         'resizable=yes, status=no, menubar=no, scrollbars=no, width=640, height=400');
}
