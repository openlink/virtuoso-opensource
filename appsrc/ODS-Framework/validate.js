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
*/

function validateError(fld, msg)
{
  alert(msg);
  setTimeout(function(){fld.focus();}, 1);
  return false;
}

function validateInt(fld)
{
  var v = fld.value.trim();
  var regex = /^[0-9]+$/;
  if (!regex.test(v))
    return validateError(fld, 'Invalid integer value: ' + v);

  return true;
}

function validateFloat(fld)
{
  var v = fld.value.trim();
  var regex = /^[-+]?([0-9]*\.)?[0-9]+([eE][-+]?[0-9]+)?$/;
  if (!regex.test(v))
    return validateError(fld, 'Invalid float value: ' + v);

  return true;
}

function validateDate(fld)
{
  var v = fld.value.trim();
  var regex = /^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])$/;
  if (!regex.test(v))
    return validateError(fld, 'Invalid date value: ' + v);

  return true;
}

function validateDateTime(fld)
{
  var v = fld.value.trim();
  var regex = /^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])( ([01]?[0-9]|[2][0-3])(:[0-5][0-9])?)?$/;
  if (!regex.test(v))
    return validateError(fld, 'Invalid date value: ' + v);

  return true;
}

function validateMail(fld)
{
  var v = fld.value.trim();
  if ((v.length == 0) || (v.length > 40))
    return validateError(fld, 'E-mail address cannot be empty or longer then 40 chars');

  var regex = /^([a-zA-Z0-9_\.\-])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$/;
  if (!regex.test(v))
    return validateError(fld, 'Invalid E-mail address: ' + v);

  return true;
}

function validateURL(fld)
{
  var v = fld.value.trim();
  var regex = /^(ftp|http|https):(\/\/)?(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?/;
  if (!regex.test(v))
    return validateError(fld, 'Invalid URL address: ' + v);

  return true;
}

function validateURI(fld)
{
  var v = fld.value.trim();
  var regex = /^([a-z0-9+.-]+):(\/\/)?(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?/;
  var mail = /^acct:([a-zA-Z0-9_\.\-])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$/;
  if (!regex.test(v) && !mail.test(v))
    return validateError(fld, 'Invalid URI address: ' + v);

  return true;
}

function validateWebID(fld)
{
  var v = fld.value.trim();
  if (v == 'foaf:Agent')
    return true;

  var regex = /(http|https):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?/;
  if (regex.test(v))
    return true;

  var regex  = /^acct:([a-zA-Z0-9_\.\-\+])+\@(([a-zA-Z0-9\-:])+)+\.?([a-zA-Z0-9]{0,4})+$/;
  if (regex.test(v))
    return true;

  var regex = /^acct:([a-zA-Z0-9_\.\-])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$/;
  if (regex.test(v))
    return true;

  return validateError(fld, 'Invalid URI address: ' + v);
}

function validateDigest(fld)
{
  var v = fld.value.trim();
  var regex = /^di:[^ <>]+$/;
  if (regex.test(v))
    return true;

  return validateError(fld, 'Invalid di: scheme value: ' + v);
}

function validateField(fld)
{
  if ((fld.value.length == 0) && OAT.Dom.isClass(fld, '_canEmpty_'))
    return true;
  if (OAT.Dom.isClass(fld, '_int_'))
    return validateInt(fld);
  if (OAT.Dom.isClass(fld, '_float_'))
    return validateFloat(fld);
  if (OAT.Dom.isClass(fld, '_date_'))
    return validateDate(fld);
  if (OAT.Dom.isClass(fld, '_dateTime_'))
    return validateDateTime(fld);
  if (OAT.Dom.isClass(fld, '_mail_'))
    return validateMail(fld);
  if (OAT.Dom.isClass(fld, '_url_'))
    return validateURL(fld);
  if (OAT.Dom.isClass(fld, '_uri_'))
    return validateURI(fld);
  if (OAT.Dom.isClass(fld, '_webid_'))
    return validateWebID(fld);
  if (OAT.Dom.isClass(fld, '_digest_'))
    return validateDigest(fld);
  if (fld.value.length == 0)
    return validateError(fld, 'Field cannot be empty');
  return true;
}

function validateInputs(fld, prefix)
{
  var retValue = true;
  var form = fld.form;
  for (i = 0; i < form.elements.length; i++)
  {
    var fld = form.elements[i];
    if (prefix && (fld.name.indexOf(prefix) != 0))
      continue;
    if (OAT.Dom.isClass(fld, '_validate_'))
    {
      retValue = validateField(fld);
      if (!retValue)
        return retValue;
    }
  }
  return retValue;
}
