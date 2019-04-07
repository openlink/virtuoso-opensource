/*
 *  $Id$
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

TBL.changeCell40 = function (obj)
{
  var parts = obj.id.split('_');
  var prefix = parts[0];
  var No = parts[3];

  var td = $(prefix+'_td_'+No+'_2');
  td.innerHTML = '';
  TBL.createCell41(td, prefix, prefix+'_fld_2_'+No, No, {});

  var td = $(prefix+'_td_'+No+'_3');
  td.innerHTML = '';
  TBL.createCell42(td, prefix, prefix+'_fld_3_'+No, No, {});
}

TBL.createCell40 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = OAT.Dom.create('select');
  fld.id = fldName;
  fld.name = fld.id;
  fld.style.width = '95%';
  OAT.Dom.option('', '', fld);
  for (var i = 0; i < OMAIL.searchPredicates.length; i = i + 2) {
    if (OMAIL.searchPredicates[i+1][0] == 1)
      OAT.Dom.option(OMAIL.searchPredicates[i+1][1], OMAIL.searchPredicates[i], fld);
  }
  if (fldOptions.value)
    fld.value = fldOptions.value;
  fld.onchange = function(){TBL.changeCell40(this)};

  td.appendChild(fld);
  return fld;
}

TBL.changeCell41 = function (obj)
{
  var parts = obj.id.split('_');
  var prefix = parts[0];
  var No = parts[3];

  var td = $(prefix+'_td_'+No+'_3');
  td.innerHTML = '';
  TBL.createCell42(td, prefix, prefix+'_fld_3_'+No, No, {});
}

TBL.createCell41 = function (td, prefix, fldName, No, fldOptions)
{
  var predicate = OMAIL.searchGetPredicate(No);
  if (!predicate)
    return;

  var fld = OAT.Dom.create('select');
  fld.id = fldName;
  fld.name = fld.id;
  fld.style.width = '95%';
  OAT.Dom.option('', '', fld);
  var predicateType = predicate[2];
  for (var i = 0; i < OMAIL.searchCompares.length; i = i + 2) {
    var compareTypes = OMAIL.searchCompares[i+1][1];
    for (var j = 0; j < compareTypes.length; j++) {
      if (compareTypes[j] == predicateType)
        OAT.Dom.option(OMAIL.searchCompares[i+1][0], OMAIL.searchCompares[i], fld);
    }
  }
  if (fldOptions.value)
    fld.value = fldOptions.value;
  fld.onchange = function(){TBL.changeCell41(this)};

  td.appendChild(fld);
  return fld;
}

TBL.createCell42 = function (td, prefix, fldName, No, fldOptions)
{
  var predicate = OMAIL.searchGetPredicate(No);
  if (!predicate)
    return;

  var fld_2 = $(fldName.replace('fld_3', 'fld_2'));
  if (!fld_2)
    return;

  var compare;
  for (var i = 0; i < OMAIL.searchCompares.length; i = i + 2) {
    if (OMAIL.searchCompares[i] == fld_2.value)
      compare = OMAIL.searchCompares[i+1];
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
  else if (predicate[2] == 'boolean') {
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
    if (predicate[4][i] == 'onclick')
      OAT.Event.attach(fld, "click", new Function((predicate[4][i+1]).replace(/-fld-/g, fld.id)));

    if (predicate[4][i] == 'button') {
      var span = OAT.Dom.create("span");
      span.innerHTML = ' ' + (predicate[4][i+1]).replace(/-FIELD-/g, fld.id);
      td.appendChild(span);
    }
  }
  return fld;
}

TBL.changeCell45 = function (obj)
{
  var parts = obj.id.split('_');
  var prefix = parts[0];
  var No = parts[3];
  var td = $(prefix+'_td_'+No+'_2');

  td.innerHTML = '';
  TBL.createCell46(td, prefix, prefix+'_fld_2_'+No, No, {});
}

TBL.createCell45 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = OAT.Dom.create('select');
  fld.id = fldName;
  fld.name = fld.id;
  fld.style.width = '95%';
  OAT.Dom.option('', '', fld);
  for (var i = 0; i < OMAIL.searchActions.length; i = i + 2) {
    if (OMAIL.searchActions[i+1][0] == 1)
      OAT.Dom.option(OMAIL.searchActions[i+1][1], OMAIL.searchActions[i], fld);
  }
  if (fldOptions.value)
    fld.value = fldOptions.value;
  fld.onchange = function(){TBL.changeCell45(this)};

  td.appendChild(fld);
  return fld;
}

TBL.createCell46 = function (td, prefix, fldName, No, fldOptions) {
  var val = $v(fldName.replace('fld_2', 'fld_1'));
  if (val && (val != '')) {
    var fldParams;
    for (var i = 0; i < OMAIL.searchActions.length; i += 2) {
      if ((OMAIL.searchActions[i] == val) && (OMAIL.searchActions[i+1][0] == 1))
        fldParams = OMAIL.searchActions[i+1];
    }
    if (!fldParams || !fldParams[2])
      return;

    if (fldParams[2] == 'input') {
      var fld = OAT.Dom.create("input");
      fld.type = 'text';
    }
    else if (fldParams[2] == 'select')
    {
      var fld = OAT.Dom.create("select");
      if (fldParams[3] == 'folder') {
        for (var i = 0; i < OMAIL.searchFolders.length; i = i + 2)
          OAT.Dom.option(OMAIL.searchFolders[i+1], OMAIL.searchFolders[i], fld);
      }
      else if (fldParams[3] == 'priority')
      {
        OAT.Dom.option('Normal', '3', fld);
        OAT.Dom.option('Lowest', '5', fld);
        OAT.Dom.option('Low', '4', fld);
        OAT.Dom.option('High', '2', fld);
        OAT.Dom.option('Highest', '1', fld);
      }
    }
    fld.id = fldName;
    fld.name = fld.id;
    fld.style.width = '93%';
    if (fldOptions.value)
      fld.value = fldOptions.value;

    td.appendChild(fld);
    return fld;
  }
}
