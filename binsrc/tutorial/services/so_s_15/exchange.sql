--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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
create user exch;

user_set_qualifier('exch', 'exch');

vhost_remove (lpath=>'/exchange');

vhost_define (lpath=>'/exchange',ppath=>'/SOAP/', soap_user=>'exch');

drop table exch.exch.currency_table;

create table exch.exch.currency_table(currency_short varchar(4) not null, currency_full varchar(50) not null);

drop table exch.exch.all_currencies;

create table exch.exch.all_currencies(all_currencies long varchar, timestmp varchar(100));

create procedure exch.dba.makeRates()
{
  declare exc, _full, _currency, _rate varchar;
  declare xe, _fullv, _currencyv, _ratev, _script, _scriptl any;
  declare i, j, l integer;
  declare _fullname, _shortname, _rates, _time any;
  declare x decimal;
  exc := http_get('http://www.oanda.com/convert/classic');
  xe := xml_tree_doc(xml_tree(exc, 2));
  _fullv := xpath_eval('/descendant::form[2]//select[@name=\'exch\']/option/text()', xe, 0);
  l := length(_fullv);
  _fullname := make_array(l, 'any');
  _shortname := make_array(l, 'any');
  _rates := make_array(l, 'any');
  while (i < l)
  {
    aset(_fullv, i, trim(cast (_fullv[i] as varchar), '\r\n'));
    j := strstr(_fullv[i], ' . ');
    aset(_fullname, i, left(_fullv[i], j));
    aset(_shortname, i, substring(_fullv[i], j + 4, 3));
    if (not exists(select 1 from exch.exch.currency_table where currency_short = _shortname[i]))
      insert into exch.exch.currency_table(currency_short, currency_full) values(_shortname[i], _fullname[i]);
    i := i + 1;
  }
  declare _retxml any;
  _retxml := string_output();
  xml_auto('select 1 as tag, null as parent, currency_short as [currency!1!shortname!element], currency_full as [currency!1!fullname!element] from exch.exch.currency_table for xml explicit', vector(), _retxml);
  delete from exch.exch.all_currencies;
  _time := dt_set_tz(now(), 0);
  insert into exch.exch.all_currencies(all_currencies, timestmp) values(string_output_string(_retxml),
         sprintf('%2d %.3s %d %02d:%02d GMT', dayofmonth(_time), monthname(_time), year(_time), hour(_time), minute(_time)));
}
;

create procedure exch.dba.newRate(in _from varchar, in _to varchar, in _amount decimal, in _flag varchar, in x integer)
{
  declare exc any;
  declare rates, pattern  varchar;
  declare _longfrom, _longto, temp varchar;
  declare euro, _to_amount, eflag decimal;
  declare eurov any;
  euro := 1;
  _longfrom := (select currency_full from exch.exch.currency_table where currency_short = _from);
  _longto := (select currency_full from exch.exch.currency_table where currency_short = _to);
  exc := http_get(sprintf('http://www.oanda.com/convert/classic?user=printable&exch=%s&expr=%s&value=%s', _from, _to, cast(_amount as varchar)));
  temp := exc;
  pattern := sprintf(concat('[0-9\\.,]* %s = [0-9\\.,]* ', replace(_longto, '(oz.)', '\\(oz\\.\\)')), _longfrom);
  rates := regexp_match(pattern, temp);
  if (rates is null)
  {
    temp := exc;
    pattern := sprintf(concat('[0-9\\.,]* Euro = [0-9\\.,]* ', replace(_longto, '(oz.)', '\\(oz\\.\\)')), _longto);
    rates := regexp_match(pattern, temp);
    if (rates is null and x = 0)
    {
      temp := exc;
      pattern := sprintf('[0-9\\.,]* %s = [0-9\\.,]* Euro', _longfrom);
      rates := regexp_match(pattern, temp);
      eurov := exch.dba.newRate('EUR', _to, '1', '', x+1);
      euro := eurov[0];
      eflag := -1;
    }
    else
    {
      temp := rates;
      temp := regexp_match('[0-9\\.,]*', temp, 1);
      eflag := cast(temp as decimal);
    }
  }
  else
  {
    eflag := 0;
  }
  regexp_match('[0-9\\.,]* ', rates, 1);
  rates :=  replace(rates, ',', '');
  rates := regexp_match('[0-9\\.,]+', rates, 1);
  rates := cast(rates as decimal);
  _to_amount := rates * euro;
  if (eflag = -1)
    eurov := vector(rates, exch.exch.amountStyle(rates, _flag));
  else if (eflag <> 0)
    eurov := vector(eflag, exch.exch.amountStyle(eflag, _flag));
  else eurov := null;
  return vector(_to_amount, exch.exch.amountStyle(_to_amount, _flag), eurov);
}
;

create procedure exch.exch.convertRate(in ConvertFrom varchar, in ConvertTo varchar, in Amount varchar)
{
  declare _newamount, _oldamount, _euro any;
  declare _from_full, _to_full  varchar;
  declare _error varchar;
  declare _retxml any;
  ConvertFrom := coalesce(ConvertFrom, '');
  ConvertTo := coalesce(ConvertTo, '');
  _error := '<?xml version="1.0" encoding="ISO-8859-1" ?><document><error>%s</error></document>';
  _from_full := (select currency_full from exch.exch.currency_table where currency_short = ConvertFrom);
  _to_full := (select currency_full from exch.exch.currency_table where currency_short = ConvertTo);
  _oldamount := exch.dba.changeAmount(Amount);
  if (_oldamount is null)
    return sprintf(_error, sprintf('Invalid amount supplied: %s', coalesce(Amount,0)));
  if (_from_full is null)
    return sprintf(_error, sprintf('Invalid currency supplied: %s', ConvertFrom));
  else if (_to_full is null)
    return sprintf(_error, sprintf('Invalid currency supplied: %s', ConvertTo));
  _newamount := exch.dba.newRate(ConvertFrom, ConvertTo, _oldamount[0], _oldamount[1],0);
  _euro := _newamount[2];
  _retxml := string_output();
  http('<?xml version="1.0" encoding="ISO-8859-1" ?>\r\n', _retxml);
  http('<document>\r\n', _retxml);
  http(sprintf('<Conversion timestamp="%s">', (select timestmp from exch.exch.all_currencies)), _retxml);
  http('<From>\r\n', _retxml);
  http(sprintf('<shortname>%s</shortname>', ConvertFrom), _retxml);
  http(sprintf('<fullname>%s</fullname>', _from_full), _retxml);
  http(sprintf('<amount_number>%f</amount_number>', _oldamount[0]), _retxml);
  http(sprintf('<amount_text>%s</amount_text>', coalesce(Amount,0)), _retxml);
  http('</From>', _retxml);
  if (_euro is not null)
  {
    http('<Euro>\r\n', _retxml);
    http('<shortname>EUR</shortname>', _retxml);
    http('<fullname>Euro</fullname>', _retxml);
    http(sprintf('<amount_number>%f</amount_number>', _euro[0]), _retxml);
    http(sprintf('<amount_text>%s</amount_text>', _euro[1]), _retxml);
    http('</Euro>', _retxml);
  }
  http('<To>\r\n', _retxml);
  http(sprintf('<shortname>%s</shortname>', ConvertTo), _retxml);
  http(sprintf('<fullname>%s</fullname>', _to_full), _retxml);
  http(sprintf('<amount_number>%f</amount_number>', _newamount[0]), _retxml);
  http(sprintf('<amount_text>%s</amount_text>', _newamount[1]), _retxml);
  http('</To>', _retxml);
  http('</Conversion></document>', _retxml);
  return string_output_string(_retxml);
}
;

create procedure exch.exch.convertRateSimple(in ConvertFrom varchar, in ConvertTo varchar, in Amount varchar)
{
  declare _newamount, _oldamount, _euro any;
  declare _from_full, _to_full  varchar;
  declare _error varchar;
  declare _retxml any;
  ConvertFrom := coalesce(ConvertFrom, '');
  ConvertTo := coalesce(ConvertTo, '');
  _error := '<?xml version="1.0" encoding="ISO-8859-1" ?><document><error>%s</error></document>';
  _from_full := (select currency_full from exch.exch.currency_table where currency_short = ConvertFrom);
  _to_full := (select currency_full from exch.exch.currency_table where currency_short = ConvertTo);
  _oldamount := exch.dba.changeAmount(Amount);
  if (_oldamount is null)
    return sprintf(_error, sprintf('Invalid amount supplied: %s', coalesce(Amount,0)));
  if (_from_full is null)
    return sprintf(_error, sprintf('Invalid currency supplied: %s', ConvertFrom));
  else if (_to_full is null)
    return sprintf(_error, sprintf('Invalid currency supplied: %s', ConvertTo));
  _newamount := exch.dba.newRate(ConvertFrom, ConvertTo, _oldamount[0], _oldamount[1],0);
  return _newamount[0];
}
;


create procedure exch.dba.changeAmount(in amount varchar)
{
  declare temp1, temp2 varchar;
  declare _amount decimal;
  declare _flag varchar;
  if ((amount := trim(coalesce(amount, ''))) = '') return null;
  temp1 := temp2 := amount;
  if (regexp_substr('^[+-]?([0-9]*)(\\.[0-9]*)?\$', amount, 0) is not null)
  {
    _amount := cast(amount as decimal);
    _flag := '';
  }
  else if (regexp_substr('^(([+-]?(([1-9][0-9]{0,2})(,[0-9]{3})*)?)|[0-9])(\\.[0-9]*)?\$', amount, 0) is not null)
  {
    _amount := cast(replace(amount, ',', '') as decimal);
    _flag := ',';
  }
  else if (regexp_substr('^(([+-]?(([1-9][0-9]{0,2})(\\.[0-9]{3})*)?)|[0-9])(,[0-9]*)?\$', amount, 0) is not null)
  {
    temp1 := amount;
    temp2 := regexp_match('^(([+-]?(([1-9][0-9]{0,2})(\\.[0-9]{3})*)?)|[0-9])', temp1);
    temp2 := replace(temp2, '.', '');
    temp1 := replace(temp1, ',', '.');
    _amount := cast(concat(temp2, temp1) as decimal);
    _flag := '.';
  }
  else return null;
  return vector(_amount, _flag);
}
;

create procedure exch.exch.amountStyle(in amount decimal, in delimiter varchar)
{
  declare _retval, _sign varchar;
  declare i integer;
  _retval := sprintf('%f', coalesce(amount,0));
  _sign := coalesce(regexp_match('^-', _retval), '');
  if (delimiter = ',')
  {
    i := strchr(_retval, '.');
    while ((i := i - 3) > 0)
    {
      _retval := concat(left(_retval, i), ',', subseq(_retval, i));
    }
  }
  else if (delimiter = '.')
  {
    _retval := replace(_retval, '.', ',');
    i := strchr(_retval, ',');
    while ((i := i - 3) > 0)
    {
      _retval := concat(left(_retval, i), '.', subseq(_retval, i));
    }
  }
  return concat(_sign,_retval);
}
;


create procedure exch.exch.currencyList(in names varchar)
{
  declare _retxml any;
  declare _names any;
  declare i, l, c integer;
  _retxml := string_output();
  _names := coalesce(_names, '');
  if (exists(select 1 from exch.exch.all_currencies))
  {
    _names := split_and_decode(names, 0, '\0\0;');
    l := length(_names);
    while (i < l)
    {
      aset(_names, i, trim(_names[i]));
      if (_names[i] <> '')
      {
        if (c = 0)
          http('<?xml version="1.0" encoding="ISO-8859-1" ?><document>\r\n', _retxml);
        http(sprintf('<currencies name="%s">\r\n', _names[i]), _retxml);
        http((select all_currencies from exch.exch.all_currencies), _retxml);
        http('</currencies>\r\n', _retxml);
        c := c + 1;
      }
      i := i + 1;
    }
    if (c = 0)
    {
      http('<?xml version="1.0" encoding="ISO-8859-1" ?><document>\r\n', _retxml);
      http('<currencies>\r\n', _retxml);
      http((select all_currencies from exch.exch.all_currencies), _retxml);
      http('</currencies>\r\n', _retxml);
    }
    http('</document>\r\n', _retxml);
  }
  else
    http('<?xml version="1.0" encoding="ISO-8859-1" ?> <document><error>No currencies available.</error></document>', _retxml);
  return string_output_string(_retxml);
}
;

grant execute on exch.dba.makeRates to exch;

grant execute on exch.exch.convertRate to exch;

grant execute on exch.exch.convertRateSimple to exch;

grant execute on exch.dba.changeAmount to exch;

grant execute on exch.dba.newRate to exch;

grant execute on exch.exch.amountStyle to exch;

grant execute on exch.exch.currencyList to exch;

exch.dba.makeRates();

insert soft DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_INTERVAL, SE_SQL)
    values ('EXCHANGE_RATES_CONVERSION', now(), 1440, 'exch.dba.makeRates()');
