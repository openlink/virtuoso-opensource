/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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

TBL.createCell41 = function (td, prefix, fldName, No, fldOptions)
{
	var fld = OAT.Dom.create("select");
	fld.name = fldName;
	fld.id = fldName;
	TBL.selectOption(fld, fldOptions.value, "Set", "U");
	TBL.selectOption(fld, fldOptions.value, "Remove", "R");

  td.appendChild(fld);
  return fld;
}

TBL.createCell42 = function (td, prefix, fldName, No, fldOptions, disabled)
{
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

TBL.createCell43 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = TBL.createCellSelect(fldName, fldOptions);
  TBL.selectOption(fld, fldOptions.value, 'This object only', 0);
	if (fldOptions.objectType == 'C') {
	  TBL.selectOption(fld, fldOptions.value, 'This object, subfolders and files', 1);
  	TBL.selectOption(fld, fldOptions.value, 'Subfolders and files', 2);
  }

  td.appendChild(fld);
  return fld;
}

TBL.viewCell42 = function (td, prefix, fldName, No, fldOptions)
{
  TBL.createCell42(td, prefix, fldName, No, fldOptions, true);
}

TBL.clickCell42 = function (fld)
{
  var fldName = fld.name;
  var i = fldName.indexOf('_fld_');
  var n = parseInt(fldName.substring(i+5,i+6));
  if (fldName.indexOf('_deny') != -1) {
    fldName = fldName.replace('_deny', '_grant');
    fldName = fldName.replace('fld_'+n, 'fld_'+(n-1));
  }
  else if (fldName.indexOf('_grant') != -1) {
    fldName = fldName.replace('_grant', '_deny');
    fldName = fldName.replace('fld_'+n, 'fld_'+(n+1));
  }
  $(fldName).checked = false;
}

var Cartridges;
TBL.createCell45 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = TBL.createCellSelect(fldName, fldOptions);
  if (Cartridges) {
    TBL.createCell45Options(fld, fldOptions.value);
  } else {
    var x = function (data) {
      try {
        Cartridges = OAT.JSON.parse(data);
        TBL.createCell45Options(fld, fldOptions.value);
      } catch (e) {Cartridges = null;}
    }
    OAT.AJAX.GET(WEBDAV.Preferences.restPath+'dav_browser_rest.vsp?a=cartridges', '', x);
  }
  td.appendChild(fld);
  return fld;
}

TBL.createCell45Options = function (fld, fldValue)
{
  for (var i = 0; i < Cartridges.length; i++)
    TBL.selectOption(fld, fldValue, Cartridges[i][1], Cartridges[i][0]);
}

var MetaCartridges;
TBL.createCell46 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = TBL.createCellSelect(fldName, fldOptions);
  if (MetaCartridges) {
    TBL.createCell46Options(fld, fldOptions.value);
  } else {
    var x = function (data) {
      try {
        MetaCartridges = OAT.JSON.parse(data);
        TBL.createCell46Options(fld, fldOptions.value);
      } catch (e) {MetaCartridges = null;}
    }
    OAT.AJAX.GET(WEBDAV.Preferences.restPath+'dav_browser_rest.vsp?a=metaCartridges', '', x);
  }
  td.appendChild(fld);
  return fld;
}

TBL.createCell46Options = function (fld, fldValue)
{
  for (var i = 0; i < MetaCartridges.length; i++)
    TBL.selectOption(fld, fldValue, MetaCartridges[i][1], MetaCartridges[i][0]);
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
  var img = OAT.Dom.image(WEBDAV.Preferences.imagePath + 'select.gif');
  img.id = fldName+'_img';
  img.className = "pointer";
  img.onclick = function (){TBL.webidShow(fld, fldOptions)};
  if (fldOptions.imgCssText)
    img.style.cssText = fldOptions.imgCssText;

  td.appendChild(img);
  td.style.verticalAlign = 'top';

  if (typeof(TypeAhead) === 'function') {
    var ta = new TypeAhead(fld.id, 'webIDs', {checkMode: 1, userParams: TBL.typeheadProperty});
    fld.setAttribute('autocomplete', 'off');
    fld.form.onsubmit = CheckSubmit;
    taVars[taVars.length] = ta;
  }

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
      S = '<img src="'+WEBDAV.Preferences.imagePath+'add_16.png" border="0" class="button pointer" onclick="javascript: TBL.createRow(\'-TBL-\', null, {fld_1: {mode: 55, tdCssText: \'width: 33%; vertical-align: top;\', className: \'_validate_\'}, fld_2: {mode: 56, tdCssText: \'width: 33%; vertical-align: top;\', cssText: \'display: none;\', className: \'_validate_\'}, fld_3: {mode: 57, tdCssText: \'width: 33%; vertical-align: top;\', cssText: \'display: none;\', className: \'_validate_\'}, btn_1: {mode: 55}});" alt="Add Condition" title="Add Condition" />';
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

TBL.createCell61 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = TBL.createCellSelect(fldName, fldOptions);
  OAT.Dom.option('', '', fld);
  td.appendChild(fld);

  for (var i = 0; i < TBL.searchPredicates.length; i = i + 2)
  {
    if (TBL.searchPredicates[i+1][0] == 1)
      OAT.Dom.option(TBL.searchPredicates[i+1][1], TBL.searchPredicates[i], fld);
  }
  if (fldOptions.value)
    fld.value = fldOptions.value;

  fld.onchange = function(){TBL.searchColumnChange(this)};
}

TBL.createCell62 = function (td, prefix, fldName, No, fldOptions)
{
  if (fldOptions.value == null) {
    TBL.searchColumnHide(prefix, 2);
    return;
  }

  var predicate = TBL.searchPredicate(fldName.replace('fld_2', 'fld_1'));
  if (predicate) {
    if (predicate[2] == 'rdfSchema') {
      var fld = TBL.createCellSelect(fldName, fldOptions);
      td.appendChild(fld);
      OAT.Dom.option('', '', fld);
      TBL.searchColumnShow(prefix, 2);

      var x = function(data) {
        var o = OAT.JSON.parse(data);
        for (var i = 0; i < o.length; i = i + 2)
          OAT.Dom.option(o[i+1], o[i], fld);

        if (fldOptions.value)
          fld.value = fldOptions.value;

        fld.onchange = function(){TBL.searchColumnChange(this)};
      }
      OAT.AJAX.GET(WEBDAV.Preferences.restPath+'dav_browser_rest.vsp?a=search&sa=schemas', null, x, {async: false});

      WEBDAV.Preferences.restPath
    }
  }
}

TBL.createCell63 = function (td, prefix, fldName, No, fldOptions)
{
  if (fldOptions.value == null) {
    TBL.searchColumnHide(prefix, 3);
    return;
  }

  var predicate = TBL.searchPredicate(fldName.replace('fld_3', 'fld_1'));
  if (predicate) {
    if (predicate[3] == 'davProperties') {
      TBL.createCell40(td, prefix, fldName, No, fldOptions)
      TBL.searchColumnShow(prefix, 3);
    }
    else if (predicate[3] == 'rdfProperties')
    {
      var fldSchema = $v(prefix+'_fld_2_' + No)
      if (fldSchema) {
        var fld = TBL.createCellSelect(fldName, fldOptions);
        td.appendChild(fld);
        OAT.Dom.option('', '', fld);
        TBL.searchColumnShow(prefix, 3);

        var x = function(data) {
          var o = OAT.JSON.parse(data);
          for (var i = 0; i < o.length; i = i + 2)
            OAT.Dom.option(o[i+1], o[i], fld);

          if (fldOptions.value)
            fld.value = fldOptions.value;
        }
        OAT.AJAX.GET(WEBDAV.Preferences.restPath+'dav_browser_rest.vsp?a=search&sa=schemaProperties&schema='+fldSchema, null, x, {async: false});
      }
    }
  }
}

TBL.createCell64 = function (td, prefix, fldName, No, fldOptions)
{
  if (fldOptions.value == null)
    return;

  var fld = TBL.createCellSelect(fldName, fldOptions);
  OAT.Dom.option('', '', fld);
  td.appendChild(fld);

  var predicate = TBL.searchPredicate(fldName.replace('fld_4', 'fld_1'));
  if (predicate) {
    var predicateType = predicate[4];
    for (var i = 0; i < TBL.searchCompares.length; i = i + 2) {
      var compareTypes = TBL.searchCompares[i+1][1];
      for (var j = 0; j < compareTypes.length; j++)
      {
        if (compareTypes[j] == predicateType)
          OAT.Dom.option(TBL.searchCompares[i+1][0], TBL.searchCompares[i], fld);
      }
    }
  }
  if (fldOptions.value)
    fld.value = fldOptions.value;
}

TBL.createCell65 = function (td, prefix, fldName, No, fldOptions)
{
  if (fldOptions.value == null)
    return;

  var fld = TBL.createCell0 (td, prefix, fldName, No, fldOptions)
  var predicate = TBL.searchPredicate(fldName.replace('fld_5', 'fld_1'));
  if (predicate) {
    for (var i = 0; i < predicate[5].length; i = i + 2) {
      if (predicate[5][i] == 'size') {
        fld['size'] = predicate[5][i+1];
        fld.style.width = null;
      }
      else if (predicate[5][i] == 'onclick')
      {
        OAT.Event.attach(fld, "click", new Function((predicate[5][i+1]).replace(/-FIELD-/g, fld.id)));
      }
      else if (predicate[5][i] == 'button')
      {
        var span = OAT.Dom.create("span");
        span.innerHTML = ' ' + (predicate[5][i+1]).replace(/-FIELD-/g, fld.id);
        td.appendChild(span);
      }
    }
  }
}

TBL.createButton61 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = TBL.createButton0(td, prefix, fldName, No, fldOptions);
  fld.onclick = function(){
    TBL.deleteRow(prefix, No);
    TBL.searchColumnHide(prefix, 2);
    TBL.searchColumnHide(prefix, 3);
  };
  return fld;
}

TBL.changeCell70 = function (obj)
{
  var parts = obj.id.split('_');
  var prefix = parts[0];
  var No = parts[3];

  TBL.createCell70Ext(obj, null, true);

  var td = $(prefix+'_td_'+No+'_2');
  td.innerHTML = '';
  TBL.createCell71(td, prefix, prefix+'_fld_2_'+No, No, {});

  var td = $(prefix+'_td_'+No+'_3');
  td.innerHTML = '';
  TBL.createCell72(td, prefix, prefix+'_fld_3_'+No, No, {});
}

TBL.createCell70 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = OAT.Dom.create('select');
  fld.id = fldName;
  fld.name = fld.id;
  fld.style.width = '95%';
  OAT.Dom.option('', '', fld);
  if (!TBL.imapPredicates) {
    TBL.imapFilter();
  }
  for (var i = 0; i < TBL.imapPredicates.length; i = i + 2) {
    if ((TBL.imapPredicates[i+1][0]).indexOf(TBL.imapFilterMode) != -1) {
      OAT.Dom.option(TBL.imapPredicates[i+1][1], TBL.imapPredicates[i], fld);
    }
  }
  if (fldOptions.value) {
    fld.value = fldOptions.value;
  }
  fld.onchange = function(){TBL.changeCell70(this)};
  td.appendChild(fld);

  TBL.createCell70Ext(fld, fldOptions)

  return fld;
}

TBL.createCell70Ext = function (obj, fldOptions, fldUnlink)
{
  var parts = obj.id.split('_');
  var prefix = parts[0];
  var No = parts[3];
  var fldName = prefix+'_fld_0_'+No;

  var predicate = TBL.imapGetPredicate(No);
  if (!predicate)
    return;

  if (((predicate[2] != 'sparql') && (predicate[2] != 'header') && (predicate[2] != 'triplet')) || fldUnlink)
    OAT.Dom.unlink('span_' + fldName);

  if ((predicate[2] != 'sparql') && (predicate[2] != 'header') && (predicate[2] != 'triplet'))
    return;

  if ($(fldName))
    return;

  var td = $(prefix+'_td_'+No+'_1');
  var span = OAT.Dom.create('span');
  span.id = 'span_' + fldName;
  if (predicate[2] == 'sparql') {
    if (!fldOptions)
      fldOptions = {valueExt: 'prefix sioc: <http://rdfs.org/sioc/ns#>\nprefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>\nprefix nmo: <http://www.semanticdesktop.org/ontologies/2007/03/22/nmo#>\nprefix nie: <http://www.semanticdesktop.org/ontologies/2007/01/19/nie#>\nASK\nWHERE\n  {\n    <%item_iri%> nmo:messageFrom <mailto:someone@example.com>\n  }'};

    var fld = OAT.Dom.create('textarea');
    fld.id = fldName;
    fld.name = fld.id;
    fld.style.width = '94%';
    fld.style.height = '8em';
    if (fldOptions.valueExt)
      fld.value = fldOptions.valueExt;

    span.appendChild(fld);
  }
  else if (predicate[2] == 'header') {
    if (!fldOptions)
      fldOptions = {valueExt: ''};

    var fld = TBL.createCellCombolist(td, fldOptions.valueExt, {name: fldName});
    fld.input.style.width = "95%";

    if (!TBL.imapHeaders)
      TBL.imapFilter();

    for (i = 0; i < TBL.imapHeaders.length; i++)
      fld.addOption(TBL.imapHeaders[i]);

    span.appendChild(fld.div);
  }
  else if (predicate[2] == 'triplet') {
    if (!fldOptions)
      fldOptions = {valueExt: ''};

    var fld = TBL.createCellCombolist(td, fldOptions.valueExt, {name: fldName});
    fld.input.style.width = "95%";

    if (!TBL.imapTriplets)
      TBL.imapFilter();

    for (i = 0; i < TBL.imapTriplets.length; i++)
      fld.addOption(TBL.imapTriplets[i]);

    span.appendChild(fld.div);
  }
  td.appendChild(span);
}

TBL.changeCell71 = function (obj)
{
  var parts = obj.id.split('_');
  var prefix = parts[0];
  var No = parts[3];

  var td = $(prefix+'_td_'+No+'_3');
  td.innerHTML = '';
  TBL.createCell72(td, prefix, prefix+'_fld_3_'+No, No, {});
}

TBL.createCell71 = function (td, prefix, fldName, No, fldOptions)
{
  var predicate = TBL.imapGetPredicate(No);
  if (!predicate)
    return;

  var fld = OAT.Dom.create('select');
  fld.id = fldName;
  fld.name = fld.id;
  fld.style.width = '95%';
  OAT.Dom.option('', '', fld);
  var predicateType = predicate[2];
  for (var i = 0; i < TBL.imapCompares.length; i = i + 2) {
    var compareTypes = TBL.imapCompares[i+1][1];
    for (var j = 0; j < compareTypes.length; j++) {
      if (compareTypes[j] == predicateType)
        OAT.Dom.option(TBL.imapCompares[i+1][0], TBL.imapCompares[i], fld);
    }
  }
  if (fldOptions.value)
    fld.value = fldOptions.value;
  fld.onchange = function(){TBL.changeCell71(this)};

  td.appendChild(fld);
  return fld;
}

TBL.createCell72 = function (td, prefix, fldName, No, fldOptions)
{
  var predicate = TBL.imapGetPredicate(No);
  if (!predicate)
    return;

  var fld_2 = $(fldName.replace('fld_3', 'fld_2'));
  if (!fld_2)
    return;

  var compare;
  for (var i = 0; i < TBL.imapCompares.length; i = i + 2) {
    if (TBL.imapCompares[i] == fld_2.value)
      compare = TBL.imapCompares[i+1];
  }
  if (!compare || (compare[2] == 0))
    return;

  if (predicate[2] == 'priority') {
    var fld = OAT.Dom.create("select");
    OAT.Dom.option('Normal', '3', fld);
    OAT.Dom.option('Lowest', '5', fld);
    OAT.Dom.option('Low', '4', fld);
    OAT.Dom.option('High', '2', fld);
    OAT.Dom.option('Highest', '1', fld);
  }
  else if (predicate[2] == 'folder') {
    var fld = OAT.Dom.create("select");
    for (var i = 0; i < TBL.imapFolders.length; i++) {
      OAT.Dom.option(TBL.imapFolders[i][1], TBL.imapFolders[i][0], fld);
    }
  }
  else if ((predicate[2] == 'boolean') || (predicate[2] == 'sparql')) {
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
  td.appendChild(fld);

  for (var i = 0; i < predicate[4].length; i += 2) {
    if (predicate[4][i] == 'size') {
      fld['size'] = predicate[4][i+1];
      fld.style.width = null;
    }

    if (predicate[4][i] == 'class')
      fld.className = predicate[4][i+1];

    if (predicate[4][i] == 'onclick')
      OAT.Event.attach(fld, "click", new Function((predicate[4][i+1]).replace(/-FIELD-/g, fld.id)));

    if (predicate[4][i] == 'button') {
      var span = OAT.Dom.create("span");
      span.innerHTML = ' ' + (predicate[4][i+1]).replace(/-FIELD-/g, fld.id);
      td.appendChild(span);
    }
  }
  return fld;
}

TBL.changeCell75 = function (obj)
{
  var parts = obj.id.split('_');
  var prefix = parts[0];
  var No = parts[3];
  var td = $(prefix+'_td_'+No+'_2');

  td.innerHTML = '';
  TBL.createCell76(td, prefix, prefix+'_fld_2_'+No, No, {});
}

TBL.createCell75 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = OAT.Dom.create('select');
  fld.id = fldName;
  fld.name = fld.id;
  fld.style.width = '95%';
  OAT.Dom.option('', '', fld);
  if (!TBL.imapActions)
    TBL.imapFilter();
  for (var i = 0; i < TBL.imapActions.length; i = i + 2) {
    if (TBL.imapActions[i+1][0] == 1)
      OAT.Dom.option(TBL.imapActions[i+1][1], TBL.imapActions[i], fld);
  }
  if (fldOptions.value)
    fld.value = fldOptions.value;
  fld.onchange = function(){TBL.changeCell75(this)};

  td.appendChild(fld);
  return fld;
}

TBL.createCell76 = function (td, prefix, fldName, No, fldOptions) {
  var val = $v(fldName.replace('fld_2', 'fld_1'));
  if (val && (val != '')) {
    var fldParams;
    for (var i = 0; i < TBL.imapActions.length; i += 2) {
      if ((TBL.imapActions[i] == val) && (TBL.imapActions[i+1][0] == 1)) {
        fldParams = TBL.imapActions[i+1];
      }
    }
    if (!fldParams || !fldParams[2])
      return;

    var fld;
    var fldButton;
    if (fldParams[2] == 'input') {
      fld = OAT.Dom.create("input");
      fld.type = fldParams[3];
    }
    else if ((fldParams[2] == 'select') && (fldParams[3] == 'folder')) {
      fld = OAT.Dom.create("input");
      fld.type = 'text';
      if ($v('dirPath'))
        fld.value = $v('dirPath');
      fldButton = OAT.Dom.create('img');
      fldButton.src = '/ods/images/select.gif';
      fldButton.className = "pointer";
      fldButton.onclick = function(name){return function(){ WEBDAV.davSelect (name, true);};}(fldName);
    }
    else if ((fldParams[2] == 'select') && (fldParams[3] == 'priority')) {
      fld = OAT.Dom.create("select");
      OAT.Dom.option('Normal', '3', fld);
      OAT.Dom.option('Lowest', '5', fld);
      OAT.Dom.option('Low', '4', fld);
      OAT.Dom.option('High', '2', fld);
      OAT.Dom.option('Highest', '1', fld);
    }
    fld.id = fldName;
    fld.name = fld.id;
    fld.style.width = '93%';
    if (fldOptions.value) {
      fld.value = fldOptions.value;
    }
    td.appendChild(fld);
    if (fldButton) {
      td.appendChild(fldButton);
    }
    return fld;
  }
}

TBL.searchFilter = function ()
{
  if (TBL.searchPredicates)
    return;

  if (!OAT.AJAX)
    return;

  var x = function(data) {
    var o = OAT.JSON.parse(data);
    TBL.searchPredicates = o[0];
    TBL.searchCompares = o[1];
  }
  OAT.AJAX.GET(WEBDAV.Preferences.restPath+'dav_browser_rest.vsp?a=search&sa=metas', '', x, {async:false});
}

TBL.searchColumnShow = function (prefix, column)
{
  var No = parseInt($v(prefix+'_no'));
  for (var N = 0; N <= No; N++)
    OAT.Dom.show(prefix+'_td_'+N+'_'+column);

  OAT.Dom.show(prefix+'_th_'+column);
}

TBL.searchColumnHide = function (prefix, column)
{
  var No = parseInt($v(prefix+'_no'));
  for (var N = 0; N <= No; N++) {
    var td = $(prefix+'_td_'+N+'_'+column);
    if (td && (td.innerHTML != ''))
      return;
  }
  for (var N = 0; N <= No; N++)
    OAT.Dom.hide(prefix+'_td_'+N+'_'+column);

  OAT.Dom.hide(prefix+'_th_'+column);
}

TBL.searchColumnChange = function (obj)
{
  function searchColumnsInit(prefix, No, column)
  {
    for (var N = column; N <= 5; N++)
      $(prefix+'_td_'+No+'_'+N).innerHTML = '';

    if (column <= 2)
      TBL.searchColumnHide(prefix, 2)

    if (column <= 3)
      TBL.searchColumnHide(prefix, 3)
  }

  var parts = obj.id.split('_');
  var prefix = parts[0];
  var column = parseInt(parts[2]);
  var No = parseInt(parts[3]);
  var td = $(prefix+'_td_'+No+'_'+column);
  var predicate = TBL.searchPredicate(prefix+'_fld_1_'+No);
  if (column == 1) {
    searchColumnsInit(prefix, No, 2);
    if (obj.value == '')
      return;

    if (predicate && predicate[2]) {
      TBL.createCell62($(prefix+'_td_'+No+'_'+2), prefix, prefix+'_fld_2_'+No, No, {value: '', cssText: 'width: 95%;'});
      return;
    }
  } else if (column == 2) {
    searchColumnsInit(prefix, No, 3);
    if (obj.value == '')
      return;
  }
  if (predicate) {
    if (predicate[3])
      TBL.createCell63($(prefix+'_td_'+No+'_'+3), prefix, prefix+'_fld_3_'+No, No, {value: '', cssText: 'width: 95%;'});

    TBL.createCell64($(prefix+'_td_'+No+'_'+4), prefix, prefix+'_fld_4_'+No, No, {value: '', cssText: 'width: 95%;'});
    TBL.createCell65($(prefix+'_td_'+No+'_'+5), prefix, prefix+'_fld_5_'+No, No, {value: '', cssText: 'width: 95%;'});
  }
}

TBL.searchPredicate = function (fldName)
{
  var fld = $(fldName)
  if (fld) {
    for (var i = 0; i < TBL.searchPredicates.length; i = i + 2) {
      if (TBL.searchPredicates[i] == fld.value)
        return TBL.searchPredicates[i+1];
    }
  }
  return null;
}

TBL.imapFilter = function ()
{
  // load filters data
  var x = function(data) {
    var o = OAT.JSON.parse(data);
    TBL.imapPredicates = o[0];
    TBL.imapCompares = o[1];
    TBL.imapActions = o[2];
    TBL.imapFolders = o[3];
    TBL.imapHeaders = o[4];
    TBL.imapTriplets = o[5];
    TBL.imapFilterMode = 'filter';
  }
  OAT.AJAX.GET(WEBDAV.Preferences.restPath+'dav_browser_rest.vsp?a=imapFilter&owner='+$v('imapOwner'), '', x, {async:false});
}

TBL.imapGetPredicate = function (No)
{
  var fld = $('search_fld_1_' + No)
  if (fld) {
    for (var i = 0; i < TBL.imapPredicates.length; i += 2) {
      if (TBL.imapPredicates[i] == fld.value)
        return TBL.imapPredicates[i+1];
    }
  }
  return null;
}
