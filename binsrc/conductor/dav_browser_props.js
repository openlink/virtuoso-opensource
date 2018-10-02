/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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
 */

/*
 *  Cookies:
 *  dav_show_scr_adv (exp 7 days) controls initial display of blocks vp_1/vp_2 and status of
 *  checkbox wg_vs_adv
 */

var pr_name_cl = {};
var pr_inx = 1;

function init_properties_mod()
{
  var tab = new OAT.Tab ("tab_viewport");
  tab.add ("tab_props","props");
  tab.add ("tab_owner_perms","owner_perms");
  //tab.go (0); /* is 0-based index... */

  var mt_cl = new OAT.Combolist([],"",{name:"mime_type",imagePath:"images/"});
  $("mime_cl").appendChild(mt_cl.div);
  for (var i = 0; i < mime_types.length; i++)
  {
    mt_cl.addOption(mime_types[i]);
  }

  pr_name_cl = new OAT.Combolist(['xml-sql','xml-sql-root','xml-sql-dtd','xml-sql-schema','xml-stylesheet','xper'],"",{imagePath:"images/"});
  //pr_name_cl.input.name = "pr_name";
  $("pr_name_div").appendChild(pr_name_cl.div);

  /* Set initial state of checkbox */

//  alert (read_cookie ('dav_show_scr_adv'));

  //if (read_cookie ('dav_show_scr_adv') == 'true')
  //  {
  //    block_show ('vp_1');
  //    block_hide ('vp_2');
  //    check_box ('wg_vs_adv');
  //  }
  //else
  //  {
  //    block_show ('vp_2');
  //    block_hide ('vp_1');
  //    uncheck_box ('wg_vs_adv');
  //  }

}

function init_prop_edit()
{
  var mt_cl = new OAT.Combolist([],cur_mime_type,{name:"mime_type1",imagePath:"images/"});
  $("mime_cl").appendChild(mt_cl.div);
  for (var i = 0; i < mime_types.length; i++)
  {
    mt_cl.addOption(mime_types[i]);
  }
}

function init_upload()
{
  var mt_cl = new OAT.Combolist([],cur_mime_type,{name:"mime_type",imagePath:"images/"});
  $("mime_cl").appendChild(mt_cl.div);
  for (var i = 0; i < mime_types.length; i++)
  {
    mt_cl.addOption(mime_types[i]);
  }
}

function directive_add(){
  var pr_instr = $("pr_instr")[$("pr_instr").selectedIndex];
  var pr_name = pr_name_cl.value; //$("pr_name").value;
  var pr_value = $("pr_value").value;

  var tbody = $("pr_dirs");

  if (!pr_name && pr_instr.value != 'ra') {
    alert('Property name can not be empty!');
    return false;
  }
  if (pr_instr.value == 'r')
    pr_value = '';
  if (pr_instr.value == 'ra') {
    pr_name = '';
    pr_value = '';
  }

  if (tbody && tbody.insertRow) {
    var row = tbody.insertRow(tbody.rows.length);
    row.onclick = select_row_click;
    var cell_0 = row.insertCell(0);
    cell_0.innerHTML = '<input type="hidden" name="pr_set" value="'+pr_inx+'"/><input type="hidden" name="pr_instr_'+pr_inx+'" value="'+pr_instr.value+'"/>' + pr_instr.text;
    var cell_1 = row.insertCell(1);
    cell_1.innerHTML = '<input type="hidden" name="pr_name_'+pr_inx+'" value="'+pr_name+'"/>' + pr_name;
    var cell_2 = row.insertCell(2);
    cell_2.innerHTML = '<input type="hidden" name="pr_value_'+pr_inx+'" value="'+pr_value+'"/>' + pr_value;
    pr_inx++;
  }

  table_rows_decor(tbody);
  return true;
}


function directive_rm_all(){
  var tbody = $("pr_dirs");
  if (tbody && tbody.deleteRow) {
    for (var i = tbody.rows.length; i >= 0; i--)
    {
      tbody.deleteRow(i - 1);
    }
  }
}

function directive_rm_sel(){
  var tbody = $("pr_dirs");
  if (tbody && tbody.deleteRow) {
    for (var i = tbody.rows.length; i > 0; i--)
    {
      if (tbody.rows[i - 1].className == 'selected_row')
        tbody.deleteRow(i - 1);
    }
  }

  table_rows_decor($("pr_dirs"));
}

function check_box (_id)
{
  $(_id).checked=true;
}

function uncheck_box (_id)
{
  $(_id).checked=false;
}

function cb_toggle (_id, _elm1, _elm2) {
  if (_id.checked == false) {
    block_hide (_elm1);
    block_show (_elm2);
    create_cookie ('dav_show_scr_adv', 'false', 7);
  }
  else
  {
    block_hide (_elm2);
    block_show (_elm1);
    create_cookie ('dav_show_scr_adv', 'true', 7);
  }
}

function block_hide (_elm)
{
  $(_elm).style['display']='none';
}

function block_show (_elm)
{
  $(_elm).style['display']='block';
}

function create_cookie (name, value, days)
{
  if (days)
    {
      var date = new Date ();
      date.setTime (date.getTime () + (days*24*60*60*1000));
      var expires = "; expires=" + date.toGMTString ();
    }
  else var expires = "";

  document.cookie = name + "=" + value + expires + "; path=/";
}

function read_cookie (name)
{
  var name_eq = name + "=";
  var ca = document.cookie.split (';');
  for (var i=0; i < ca.length; i++)
    {
      var c = ca[i];
      while (c.charAt (0)==' ') c = c.substring (1, c.length);
      if (c.indexOf (name_eq) == 0) return c.substring (name_eq.length, c.length);
    }
  return null;
}

function erase_cookie (name)
{
  create_cookie (name,"",-1);
}

function select_row_click(e){
  var targ;
	if (!e) e = window.event;
	if (e.target) targ = e.target;
	else if (e.srcElement) targ = e.srcElement;
	if (targ.nodeType == 3) // defeat Safari bug
		targ = targ.parentNode;

  var tr = targ;
  while (tr.tagName.toLowerCase() != "tr")
  tr = tr.parentNode;

  select_row(tr);
}

function select_row(tr){

  if (tr.className == 'selected_row')
    tr.className = '';
  else
    tr.className = 'selected_row';

  table_rows_decor(tr.parentNode);
}

function table_rows_decor(t){
  for (var i = 0; i < t.rows.length; i++)
  {
    if (t.rows[i].className != 'selected_row')
    {
      if ((i+1)%2 == 0)
        t.rows[i].className = 'even';
      else
        t.rows[i].className = '';
    }
  }
}
