/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

var TBL = new Object();
TBL.selectOption = function(fld, fldValue, optionName, optionValue) {
	var o = OAT.Dom.option(optionName, optionValue, fld);
	if (fldValue == optionValue)
		o.selected = true;
}

TBL.createRow = function (prefix, No, optionObject)
{
  if (No != null)
  {
    TBL.deleteRow(prefix, No);
  }
  else
  {
    var tbl = $(prefix+'_tbody');
    if (!tbl)
      tbl = $(prefix+'_tbl');
    if (tbl)
    {
      var options = {btn_1: {mode: 0}};
      for (var p in optionObject) {options[p] = optionObject[p]; }

      No = options.No;
      if (!$(prefix+'_no')) {
      	var fld = OAT.Dom.create("input");
        fld.type = 'hidden';
        fld.name = prefix+'_no';
        fld.id = fld.name;
        fld.value = '0';
        tbl.appendChild(fld);
      }
      if (No) {
        $(prefix+'_no').value = No;
      } else {
        No = $v(prefix+'_no');
      }
      No = parseInt(No)

      OAT.Dom.hide (prefix+'_tr_no');

      var tr = OAT.Dom.create('tr');
      tr.id = prefix+'_tr_' + No;
      tbl.appendChild(tr);

      // fields
      for (var fld in options)
      {
        if (fld.indexOf('fld') == 0)
        {
          var fldOptions = options[fld];
          var td = OAT.Dom.create('td');
          td.id = prefix+'_td_'+ No+'_'+fld.replace(/fld_/, '');
          if (fldOptions.tdCssText)
            td.style.cssText = fldOptions.tdCssText;
          tr.appendChild(td);
          var fldName = prefix + '_' + fld + '_' + No;
          var fn = TBL["createCell"+((fldOptions.mode)? fldOptions.mode: "0")];
          if (fn)
        	  fn(td, prefix, fldName, No, fldOptions);
        }
      }

      // actions
      var td = OAT.Dom.create('td');
      td.id = prefix+'_td_'+ No+'_btn';
      td.style.whiteSpace = 'nowrap';
      tr.appendChild(td);
      if (options.id) {
      	var fld = OAT.Dom.create("input");
        fld.type = 'hidden';
        fld.name = prefix + '_fld_0_' + No;
        fld.id = fld.name;
        fld.value = options.id;
        td.appendChild(fld);
      }
      for (var btn in options)
      {
        if (btn.indexOf('btn') == 0)
        {
          var fldOptions = options[btn];
          if (fldOptions.tdCssText)
            td.style.cssText = fldOptions.tdCssText;
          var fldName = prefix + '_' + btn + '_' + No;
          var fn = TBL["createButton"+fldOptions.mode];
          if (fn)
          {
        	  var btn = fn(td, prefix, fldName, No, fldOptions);
            if (btn) {
              if (fldOptions.cssText)
                btn.style.cssText = fldOptions.cssText;
              if (fldOptions.className)
                btn.className = fldOptions.className;
            }
          }
        }
      }
      $(prefix+'_no').value = No + 1;
    }
  }
}

TBL.createViewRow = function (prefix, options)
{
  var tbl = $(prefix+'_tbl');
  if (tbl)
  {
    OAT.Dom.hide (prefix+'_tr_no');

    var tr = OAT.Dom.create('tr');
    tbl.appendChild(tr);

    // fields
    for (var fld in options)
    {
      if (fld.indexOf('fld') == 0)
      {
        var fldOptions = options[fld];
        var td = OAT.Dom.create('td');
        if (fldOptions.tdCssText)
          td.style.cssText = fldOptions.tdCssText;
        tr.appendChild(td);

        if (fldOptions.mode) {
          fldName = prefix + '_' + fld + '_0';
          var fn = TBL["viewCell"+fldOptions.mode];
          if (fn)
        	  fn(td, prefix, fldName, 0, fldOptions);
      	} else {
          td.innerHTML = fldOptions.value;
        }
      }
    }
  }
}

TBL.deleteRow = function (prefix, No, ask) {
  if (ask && !confirm('Are you sure that you want to delete this row?'))
    return false;

  OAT.Dom.unlink(prefix+'_tr_'+No);
  OAT.Dom.unlink(prefix+'_tr_'+No+'_items');
  OAT.Dom.unlink(prefix+'_tr_'+No+'_properties');
  var No = parseInt($(prefix+'_no').value);
  for (var N = 0; N < No; N++)
  {
    if ($(prefix+'_tr_'+N))
      return;
  }
  OAT.Dom.show(prefix+'_tr_no');
  return true;
}

TBL.createCellSelect = function (fldName) {
	var fld = OAT.Dom.create("select");
  fld.name = fldName;
  fld.id = fldName;
  return fld;
}

TBL.createCellCombolist = function (td, fldValue, fldOptions) {
  var fld = new OAT.Combolist([], fldValue, fldOptions);
  fld.input.id = fld.input.name;
  fld.input.style.width = "85%";
  td.appendChild(fld.div);

  var dims = OAT.Dom.getWH(td);
  fld.list.style.width = (((dims[0]>250)?dims[0]:250)*0.75)+"px";

  return fld;
}

TBL.createCell0 = function (td, prefix, fldName, No, fldOptions) {
  var fld = OAT.Dom.create('input');
  fld.type = (fldOptions.type)? (fldOptions.type): 'text';
  fld.id = fldName;
  fld.name = fld.id;
  if (fldOptions.value) {
    fld.value = fldOptions.value;
    fld.defaultValue = fld.value;
  }
  if (fldOptions.className)
    fld.className = fldOptions.className;
  if (fldOptions.onblur)
    fld.onblur = fldOptions.onblur;
  fld.style.width = '95%';
  if (fldOptions.cssText)
    fld.style.cssText = fldOptions.cssText;
  if (fldOptions.readOnly)
    fld.readOnly = fldOptions.readOnly;

  td.appendChild(fld);
  return fld;
}

TBL.createCell40 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = new OAT.Combolist([], fldOptions.value, {name: fldName});
  fld.input.name = fldName;
  fld.input.id = fldName;
  fld.input.style.width = "85%";
  fld.addOption('xml-sql');
  fld.addOption('xml-sql-root');
  fld.addOption('xml-sql-dtd');
  fld.addOption('xml-sql-schema');
  fld.addOption('xml-sql-description');
  fld.addOption('xml-sql-encoding');
  fld.addOption('xml-stylesheet');
  fld.addOption('xml-template');
  fld.addOption('xper');

  td.appendChild(fld.div);
  return fld;
}

TBL.createCell41 = function (td, prefix, fldName, No, fldOptions) {
	var fld = OAT.Dom.create("select");
	fld.name = fldName;
	fld.id = fldName;
	TBL.selectOption(fld, fldOptions.value, "Set", "U");
	TBL.selectOption(fld, fldOptions.value, "Remove", "R");

  td.appendChild(fld);
  return fld;
}

TBL.changeCell50 = function (srcFld) {
  var srcValue = $v(srcFld.name);
  var dstName = srcFld.name.replace('fld_1', 'fld_2');
  var dstFld = $(dstName);
  var dstImg = $(dstName+'_img');
  if (srcValue == 'public') {
    dstFld.value = 'foaf:Agent';
    dstFld.readOnly = true;
  } else {
    if (dstFld.value == 'foaf:Agent')
      dstFld.value = '';
    dstFld.readOnly = false;
  }
  if (srcValue == 'public') {
    OAT.Dom.hide(dstImg);
  } else {
    OAT.Dom.show(dstImg);
  }
}

TBL.viewCell50 = function (td, prefix, fldName, No, fldOptions) {
	if (fldOptions.value == "public") {
	  td.innerHTML = "Public";
	} else if (fldOptions.value == "group") {
	  td.innerHTML = "Group";
	} else {
	  td.innerHTML = "Personal";
	}
}

TBL.createCell50 = function (td, prefix, fldName, No, fldOptions) {
	var fld = OAT.Dom.create("select");
	fld.name = fldName;
	fld.id = fldName;
	TBL.selectOption(fld, fldOptions.value, "Personal", "person");
	TBL.selectOption(fld, fldOptions.value, "Group", "group");
	TBL.selectOption(fld, fldOptions.value, "Public", "public");
  if (fldOptions.onchange)
    fld.onclick = fldOptions.onchange;

  td.appendChild(fld);
  return fld;
}

TBL.createCell51 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = TBL.createCell0 (td, prefix, fldName, No, fldOptions)
  if (document.forms[0].elements['sid']) {
    td.appendChild(OAT.Dom.text(' '));
    var img = OAT.Dom.image('/ods/images/select.gif');
    img.id = fldName+'_img';
    img.className = "pointer";
    img.onclick = function (){TBL.webidShow(fld, fldOptions.form)};
    if (fldOptions.imgCssText)
      img.style.cssText = fldOptions.imgCssText;

    td.appendChild(img);
  }
  return fld;
}

TBL.createCell52 = function (td, prefix, fldName, No, fldOptions, disabled) {
  function cb(td, prefix, fldName, No, fldOptions, disabled, ndx) {
  	var fld = OAT.Dom.create("input");
    fld.type = 'checkbox';
    fld.id = fldName;
    fld.name = fld.id;
    fld.value = 1;
    if (fldOptions.value && fldOptions.value[ndx])
      fld.checked = true;
    if (fldOptions.onclick)
      fld.onclick = fldOptions.onclick;
    if (disabled)
      fld.disabled = disabled;
    td.appendChild(fld);
  }
  var suffix = '';
  if (fldOptions.suffix)
    suffix = fldOptions.suffix;
  cb(td, prefix, fldName+'_r'+suffix, No, fldOptions, disabled, 0);
  cb(td, prefix, fldName+'_w'+suffix, No, fldOptions, disabled, 1);
  cb(td, prefix, fldName+'_x'+suffix, No, fldOptions, disabled, 2);
}

TBL.viewCell52 = function (td, prefix, fldName, No, fldOptions) {
  TBL.createCell52(td, prefix, fldName, No, fldOptions, true);
}

TBL.clickCell52 = function (fld)
{
  var fldName = fld.name;
  if (fldName.indexOf('_deny') != -1) {
    fldName = fldName.replace('_deny', '_grant');
    fldName = fldName.replace('fld_4', 'fld_3');
  }
  else if (fldName.indexOf('_grant') != -1) {
    fldName = fldName.replace('_grant', '_deny');
    fldName = fldName.replace('fld_3', 'fld_4');
  }
  $(fldName).checked = false;
}

TBL.createCell53 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = TBL.createCell0 (td, prefix, fldName, No, fldOptions)
  td.appendChild(OAT.Dom.text(' '));
  var img = OAT.Dom.image('/ods/images/select.gif');
  img.id = fldName+'_img';
  img.className = "pointer";
  img.onclick = function (){TBL.webidShow(fld)};
  if (fldOptions.imgCssText)
    img.style.cssText = fldOptions.imgCssText;

  td.appendChild(img);
  return fld;
}

TBL.createButton0 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = OAT.Dom.create('span');
  fld.id = fldName;
  fld.onclick = function(){TBL.deleteRow(prefix, No);};
  OAT.Dom.addClass(fld, 'button pointer');

  var img = OAT.Dom.create('img');
  img.src = 'images/icons/trash_16.png';
  img.alt = 'Delete row';
  img.title = fld.alt;
  OAT.Dom.addClass(img, 'button');

  fld.appendChild(img);
  fld.appendChild(OAT.Dom.text(' Delete'));

  td.appendChild(fld);
  return fld;
}
