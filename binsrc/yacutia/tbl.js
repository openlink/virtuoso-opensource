/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

TBL.No = function (tbl, prefix, options)
  {
  var No = options.No;
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
  return parseInt(No)
}

TBL.parent = function (obj, tag) {
  var obj = obj.parentNode;
  if (obj.tagName.toLowerCase() == tag)
    return obj;
  return TBL.parent(obj, tag);
}

TBL.createRow = function (prefix, No, optionObject, viewMode) {
  if (No != null)
  {
    TBL.deleteRow(prefix, No);
  }
  else if (viewMode)
  {
    TBL.createViewRow(prefix, optionObject);
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

      No = TBL.No(tbl, prefix, options);
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
      td.style.cssText = 'white-space: nowrap; vertical-align: top;';
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
  var tbl = $(prefix+'_tbody');
  if (!tbl)
    tbl = $(prefix+'_tbl');
  if (tbl) {
    var No = TBL.No(tbl, prefix, options);
    OAT.Dom.hide (prefix+'_tr_no');

    var tr = OAT.Dom.create('tr');
    tr.id = prefix+'_tr_' + No;
    tbl.appendChild(tr);

    // fields
    for (var fld in options) {
      if (fld.indexOf('fld') == 0) {
        var fldOptions = options[fld];
        var td = OAT.Dom.create('td');
        if (fldOptions.tdCssText)
          td.style.cssText = fldOptions.tdCssText;
        tr.appendChild(td);

        if (fldOptions.mode) {
          fldName = prefix + '_' + fld + '_' + No;
          var fn = TBL["viewCell"+fldOptions.mode];
          if (fn)
        	  fn(td, prefix, fldName, 0, fldOptions);
      	} else {
          td.innerHTML = fldOptions.value;
        }
      }
      $(prefix+'_no').value = No + 1;
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
  for (var N = 0; N < No; N++) {
    if ($(prefix+'_tr_'+N))
      return;
  }
  OAT.Dom.show(prefix+'_tr_no');
  return true;
}

TBL.clean = function (prefix) {
  var No = parseInt($(prefix+'_no').value);
  for (var N = 0; N < No; N++)
    OAT.Dom.unlink(prefix+'_tr_'+N);

  OAT.Dom.show(prefix+'_tr_no');
  return true;
}

TBL.createCellOptions = function (fld, fldOptions) {
  if (fldOptions) {
    if (fldOptions.className)
      fld.className = fldOptions.className;
    if (fldOptions.onblur)
      fld.onblur = fldOptions.onblur;
    if (fldOptions.cssText)
      fld.style.cssText = fldOptions.cssText;
    if (fldOptions.readOnly)
      fld.readOnly = fldOptions.readOnly;
  }
}

TBL.createCellSelect = function (fldName, fldOptions) {
	var fld = OAT.Dom.create("select");
  fld.name = fldName;
  fld.id = fldName;
  TBL.createCellOptions(fld, fldOptions);

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

TBL.viewCell0 = function (td, prefix, fldName, No, fldOptions) {
  td.innerHTML = fldOptions.value;
}

TBL.changeCell50 = function (srcFld) {
  var srcValue = $v(srcFld.name);
  var dstName = srcFld.name.replace('fld_1', 'fld_2');
  var dstFld = $(dstName);
  var dstImg = $(dstName+'_img');
  if (srcValue == 'advanced') {
    OAT.Dom.hide(dstFld);
    OAT.Dom.hide(dstImg);
    OAT.Dom.removeClass(dstFld, '_validate_');
    var td = TBL.parent(dstFld, 'td');
    TBL.showCell51Tbl(td, dstName);
  } else {
    OAT.Dom.show(dstFld);
    OAT.Dom.addClass(dstFld, '_validate_');
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
    var dstTbl = $(dstName.replace('_fld', '_tbl'));
    OAT.Dom.hide(dstTbl);
  }
}

TBL.viewCell50 = function (td, prefix, fldName, No, fldOptions) {
  TBL.createCell50(td, prefix, fldName, No, fldOptions, true);
}

TBL.createCell50 = function (td, prefix, fldName, No, fldOptions, disabled) {
	var fld = OAT.Dom.create("select");
	fld.name = fldName;
	fld.id = fldName;
	TBL.selectOption(fld, fldOptions.value, "Personal", "person");
	TBL.selectOption(fld, fldOptions.value, "Group", "group");
	TBL.selectOption(fld, fldOptions.value, "Public", "public");
  if (!fldOptions.noAdvanced)
    TBL.selectOption(fld, fldOptions.value, "Advanced", "advanced");
  if (fldOptions.onchange)
    fld.onchange = fldOptions.onchange;

  if (disabled)
    fld.disabled = disabled;

  td.appendChild(fld);
  td.style.verticalAlign = 'top';
  return fld;
}

TBL.createCell51 = function (td, prefix, fldName, No, fldOptions) {
  var fld = TBL.createCell0 (td, prefix, fldName, No, fldOptions)
  var srcFld = $(fld.name.replace('fld_2', 'fld_1'));

    td.appendChild(OAT.Dom.text(' '));
  var img = OAT.Dom.image('images/icons/select.gif');
    img.id = fldName+'_img';
    img.className = "pointer";
  img.onclick = function (){TBL.webidShow(fld, fldOptions)};
    if (fldOptions.imgCssText)
      img.style.cssText = fldOptions.imgCssText;

    td.appendChild(img);
  td.style.verticalAlign = 'top';

  if (srcFld.value == 'advanced') {
    OAT.Dom.hide(fld);
    OAT.Dom.hide(img);
    OAT.Dom.removeClass(fld, '_validate_');
    TBL.showCell51Tbl(td, fldName, fldOptions);
  }
  if (srcFld.value == 'public')
    OAT.Dom.hide(img);

  return fld;
}

TBL.showCell51Tbl = function (td, fldName, fldOptions, disabled) {
  OAT.Loader.load(["ajax", "json"], function(){TBL.showCell51TblInternal (td, fldName, fldOptions, disabled);});
}

TBL.showCell51TblInternal = function (td, fldName, fldOptions, disabled) {
  var tblName = fldName.replace ('_fld', '_tbl');
  var tbl = $(tblName);
  if ($(tbl)) {
    OAT.Dom.show(tbl);
  } else {
    if (!disabled) {
      tbl = OAT.Dom.create('table', {width: '100%', id: tblName});
    } else {
      tbl = OAT.Dom.create('table', {width: '95%', id: tblName});
    }
    td.appendChild(tbl);
    var tr = OAT.Dom.create('tr');
    tbl.appendChild(tr);
    var td = OAT.Dom.create('td', {width: '95%', style: 'padding: 0'});
    tr.appendChild(td);
    var tbl2 = OAT.Dom.create('table', {width: '100%', className: 'ODS_formList'});
    td.appendChild(tbl2);
    var tbody2 = OAT.Dom.create('tbody', {id: fldName+'_tbody'});
    tbl2.appendChild(tbody2);
    var tr2 = OAT.Dom.create('tr', {id: fldName+'_tr_no'});
    tbody2.appendChild(tr2);
    var td2 = OAT.Dom.create('td', {colspan: '3'});
    tr2.appendChild(td2);
    var S = '<b>No Criteria</b>';
    td2.innerHTML = S.replace(/-TBL-/g, fldName);
    if (!disabled) {
      var td2 = OAT.Dom.create('td');
      td2.style.cssText = 'white-space: nowrap; vertical-align: top;';
      tr.appendChild(td2);
      S = '<img src="images/icons/add_16.png" border="0" class="button pointer" onclick="javascript: TBL.createRow(\'-TBL-\', null, {fld_1: {mode: 55, tdCssText: \'width: 33%; vertical-align: top;\', className: \'_validate_\'}, fld_2: {mode: 56, tdCssText: \'width: 33%; vertical-align: top;\', cssText: \'display: none;\', className: \'_validate_\'}, fld_3: {mode: 57, tdCssText: \'width: 33%; vertical-align: top;\', cssText: \'display: none;\', className: \'_validate_\'}, btn_1: {mode: 55}});" alt="Add Condition" title="Add Condition" />';
      td2.innerHTML = S.replace(/-TBL-/g, fldName);
    }
    if (fldOptions && fldOptions.value) {
      for (var i = 0; i < fldOptions.value.length; i = i + 1) {
        if (disabled) {
          TBL.createViewRow(fldName, {fld_1: {mode: 55, value: fldOptions.value[i][1], valueExt: fldOptions.value[i][4], tdCssText: 'width: 33%;'}, fld_2: {mode: 56, value: fldOptions.value[i][2], tdCssText: 'width: 33%; vertical-align: top;'}, fld_3: {mode: 57, value: fldOptions.value[i][3], tdCssText: 'width: 33%; vertical-align: top;'}});
        } else {
          TBL.createRow(fldName, null, {fld_1: {mode: 55, value: fldOptions.value[i][1], valueExt: fldOptions.value[i][4], tdCssText: 'width: 33%;', className: '_validate_'}, fld_2: {mode: 56, value: fldOptions.value[i][2], tdCssText: 'width: 33%; vertical-align: top;', className: '_validate_'}, fld_3: {mode: 57, value: fldOptions.value[i][3], tdCssText: 'width: 33%; vertical-align: top;', className: '_validate_'}, btn_1: {mode: 55}});
        }
      }
    }
  }
  return tbl;
}

TBL.viewCell51 = function (td, prefix, fldName, No, fldOptions) {
  var srcFld = $(fldName.replace('fld_2', 'fld_1'));
  if (srcFld && (srcFld.value == 'advanced')) {
    TBL.showCell51Tbl(td, fldName, fldOptions, true);
  } else {
    TBL.viewCell0(td, prefix, fldName, No, fldOptions);
  }
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
  if (fldOptions.execute)
  cb(td, prefix, fldName+'_x'+suffix, No, fldOptions, disabled, 2);

  td.style.verticalAlign = 'top';
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

TBL.changeCell55 = function (obj)
{
  var prefix = obj._prefix;
  var No = obj._No;

  TBL.createCell55Ext(obj);

  var td = $(prefix+'_td_'+No+'_2');
  td.innerHTML = '';
  TBL.createCell56(td, prefix, prefix+'_fld_2_'+No, No, {className: '_validate_'});

  var td = $(prefix+'_td_'+No+'_3');
  td.innerHTML = '';
  TBL.createCell57(td, prefix, prefix+'_fld_3_'+No, No, {className: '_validate_'});
}

TBL.createCell55 = function (td, prefix, fldName, No, fldOptions, disabled) {
  var fld = TBL.createCellSelect(fldName, fldOptions);
  fld._prefix = prefix;
  fld._No = No;
  fld.style.width = '95%';
  OAT.Dom.option('', '', fld);
  if (!TBL.predicates)
    TBL.initValues();
  if (TBL.predicates)
    for (var i = 0; i < TBL.predicates.length; i = i + 2) {
      OAT.Dom.option(TBL.predicates[i+1][0], TBL.predicates[i], fld);
    }

  if (fldOptions.value)
    fld.value = fldOptions.value;

  if (disabled)
    fld.disabled = disabled;

  if (!disabled)
    fld.onchange = function(){TBL.changeCell55(this)};

  td.appendChild(fld);
  TBL.createCell55Ext(fld, fldOptions, disabled)

  return fld;
}

TBL.createCell55Ext = function (obj, fldOptions, disabled) {
  var prefix = obj._prefix;
  var No = obj._No;

  var predicate = TBL.predicateGet(prefix+'_fld_1_'+No);
  if (!predicate)
    return;

  var fldName = prefix+'_fld_0_'+No;
  OAT.Dom.unlink('span_' + fldName);
  if ((predicate[1] != 'sparql') && (predicate[1] != 'triplet'))
    return;

  var td = TBL.parent(obj, 'td');
  var span = OAT.Dom.create('span');
  span.id = 'span_' + fldName;
  if (predicate[1] == 'sparql') {
  if (!fldOptions)
    fldOptions = {valueExt: 'prefix sioc: <http://rdfs.org/sioc/ns#>\nprefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>\nprefix foaf: <http://xmlns.com/foaf/0.1/>\nASK where {^{webid}^ rdf:type foaf:Person}'};

  var fld = OAT.Dom.create('textarea');
  fld.id = fldName;
  fld.name = fld.id;
  fld.style.cssFloat = 'left';
  fld.style.width = '94%';
  fld.style.height = '8em';
  if (fldOptions.valueExt)
    fld.value = fldOptions.valueExt;
  if (disabled)
    fld.disabled = disabled;

    span.appendChild(fld);
}
  else if (predicate[1] == 'triplet') {
    if (!fldOptions)
      fldOptions = {valueExt: ''};

    var fld = TBL.createCellCombolist(td, fldOptions.valueExt, {name: fldName});
    fld.input.style.width = "95%";

    if (!TBL.triplets)
      TBL.initValues();

    for (i = 0; i < TBL.triplets.length; i++)
      fld.addOption(TBL.triplets[i]);

    span.appendChild(fld.div);
  }
  td.appendChild(span);
}

TBL.changeCell56 = function (obj) {
  var prefix = obj._prefix;
  var No = obj._No;

  var td = $(prefix+'_td_'+No+'_3');
  td.innerHTML = '';
  TBL.createCell57(td, prefix, prefix+'_fld_3_'+No, No, {className: '_validate_'});
}

TBL.viewCell55 = function (td, prefix, fldName, No, fldOptions) {
  TBL.createCell55(td, prefix, fldName, No, fldOptions, true);
}

TBL.createCell56 = function (td, prefix, fldName, No, fldOptions, disabled)
{
  var predicate = TBL.predicateGet(prefix+'_fld_1_'+No);
  if (!predicate)
    return;

  var fld = TBL.createCellSelect(fldName, fldOptions);
  fld._prefix = prefix;
  fld._No = No;
  fld.style.width = '95%';
  OAT.Dom.option('', '', fld);
  var predicateType = predicate[1];
  if (TBL.compares)
    for (var i = 0; i < TBL.compares.length; i = i + 2) {
      var compareTypes = TBL.compares[i+1][1];
      for (var j = 0; j < compareTypes.length; j++) {
        if (compareTypes[j] == predicateType)
          OAT.Dom.option(TBL.compares[i+1][0], TBL.compares[i], fld);
      }
    }
  if (fldOptions.value)
    fld.value = fldOptions.value;

  if (disabled)
    fld.disabled = disabled;

  if (!disabled)
    fld.onchange = function(){TBL.changeCell56(this)};

  td.appendChild(fld);
  return fld;
}

TBL.viewCell56 = function (td, prefix, fldName, No, fldOptions) {
  TBL.createCell56(td, prefix, fldName, No, fldOptions, true);
}

TBL.createCell57 = function (td, prefix, fldName, No, fldOptions)
{
  var predicate = TBL.predicateGet(prefix+'_fld_1_'+No);
  if (!predicate)
    return;

  var fld_2 = $(fldName.replace('fld_3', 'fld_2'));
  if (!fld_2)
    return;

  var compare;
  for (var i = 0; i < TBL.compares.length; i = i + 2) {
    if (TBL.compares[i] == fld_2.value)
      compare = TBL.compares[i+1];
  }
  if (!compare || (compare[2] == 0))
    return;

  if ((predicate[1] == 'boolean') || (predicate[1] == 'sparql')) {
    var fld = OAT.Dom.create("select");
    OAT.Dom.option('Yes', '1', fld);
    OAT.Dom.option('No', '0', fld);
  }
  else
  {
    var fld = OAT.Dom.create("input");
    fld.type = 'text';
  }
  fld.id = fldName;
  fld.name = fld.id;
  fld.style.width = '93%';
  if (fldOptions.value)
    fld.value = fldOptions.value;
  if (fldOptions.className)
    fld.className = fldOptions.className;
  td.appendChild(fld);

  for (var i = 0; i < predicate[3].length; i += 2) {
    if (predicate[3][i] == 'size') {
      fld['size'] = predicate[3][i+1];
      fld.style.width = null;
    }

    if (predicate[3][i] == 'class')
      fld.className = predicate[3][i+1];

    if (predicate[3][i] == 'onclick')
      OAT.Event.attach(fld, "click", new Function((predicate[3][i+1]).replace(/-FIELD-/g, fld.id)));

    if (predicate[3][i] == 'button') {
      var span = OAT.Dom.create("span");
      span.innerHTML = ' ' + (predicate[3][i+1]).replace(/-FIELD-/g, fld.id);
      td.appendChild(span);
    }
  }
  return fld;
}

TBL.viewCell57 = function (td, prefix, fldName, No, fldOptions) {
  TBL.createCell0(td, prefix, fldName, No, fldOptions, true);
}

TBL.createButton0 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = OAT.Dom.create('span');
  fld.id = fldName;
  fld.title = 'Delete row';
  fld.onclick = function(){TBL.deleteRow(prefix, No);};
  OAT.Dom.addClass(fld, 'button pointer');

  var img = OAT.Dom.create('img');
  img.src = '/conductor/images/icons/trash_16.png';
  img.alt = 'Delete row';
  img.title = img.alt;
  OAT.Dom.addClass(img, 'button');

  fld.appendChild(img);
  fld.appendChild(OAT.Dom.text(' Delete'));

  td.appendChild(fld);
  return fld;
}

TBL.createButton1 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = OAT.Dom.create("input");
  fld.id = fldName;
  fld.type = 'button';
  fld.value = 'Remove';
  fld.onclick = function(){TBL.deleteRow(prefix, No);};

  td.appendChild(fld);
  return fld;
}

TBL.createButtonAdd = function (td, prefix, fldName, No, fldOptions)
{
  var fld = OAT.Dom.create('span');
  fld.id = fldName;
  fld.title = 'Add Element';
  OAT.Dom.addClass(fld, 'button pointer');

  var img = OAT.Dom.create('img');
  img.src = 'images/icons/add_16.png';
  img.alt = 'Add Element';
  img.title = img.alt;
  OAT.Dom.addClass(img, 'button');

  fld.appendChild(img);
  var titleText = fldOptions.title;
  if (!titleText)
    titleText = 'Add';
  fld.appendChild(OAT.Dom.text(' '+titleText));

  td.appendChild(fld);
  return fld;
}

TBL.createButton55 = function (td, prefix, fldName, No, fldOptions)
{
  var img = OAT.Dom.create('img');
  img.src = '/conductor/images/icons/trash_16.png';
  img.alt = 'Delete row';
  img.title = img.alt;
  img.onclick = function(){TBL.deleteRow(prefix, No);};
  OAT.Dom.addClass(img, 'button');

  td.appendChild(img);
  return img;
}

TBL.webidProperty = function(obj)
{
  var S = 'p';
  if (obj.id.replace('fld_2', 'fld_1') != obj.id)
    S = $v(obj.id.replace('fld_2', 'fld_1'))[0];

  return S;
}

TBL.typeheadProperty = function(obj)
{
  return '&depend=' + TBL.webidProperty(obj);
}

TBL.webidShow = function(obj, fldOptions)
{
  var S = TBL.webidProperty(obj);
  var frm = TBL.parent(obj, 'form');
  var F = '&form='+frm.name;
  var M = '&mode='+((fldOptions.formMode)? fldOptions.formMode: S);
  var N = (fldOptions.nrows)? '&nrows='+fldOptions.nrows: '';

  TBL.windowShow('/ods/webid_select.vspx?params='+obj.id+':s1;'+F+M+N, 'ods_select_webid');
}

TBL.windowShow = function(sPage, sPageName, width, height)
{
  if (!width)
    width = 700;
  if (!height)
    height = 500;
  if (document.forms[0].elements['sid'])
    sPage += '&sid=' + document.forms[0].elements['sid'].value;
  if (document.forms[0].elements['realm'])
    sPage += '&realm=' + document.forms[0].elements['realm'].value;
  win = window.open(sPage, sPageName, "width="+width+",height="+height+",top=100,left=100,status=yes,toolbar=no,menubar=no,scrollbars=yes,resizable=yes");
  win.window.focus();
}

TBL.initValues = function ()
{
  // load filters data
  var x = function(data) {
    var o = OAT.JSON.parse(data);
    TBL.predicates = o[0];
    TBL.compares = o[1];
    TBL.triplets = o[2];
  }
  OAT.AJAX.GET('/webid/api/acl_filters', false, x, {async: false});
}

TBL.predicateGet = function (fldName)
{
  var fld = $(fldName)
  if (fld) {
    if (!TBL.predicates)
      TBL.initValues();
    for (var i = 0; i < TBL.predicates.length; i += 2) {
      if (TBL.predicates[i] == fld.value)
        return TBL.predicates[i+1];
    }
  }
  return null;
}
