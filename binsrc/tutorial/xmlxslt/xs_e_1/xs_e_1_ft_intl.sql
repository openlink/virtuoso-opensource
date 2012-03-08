--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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

drop table XS_E_1;

create table XS_E_1 (NAME varchar primary key, TEXT long varchar);

create text xml index on XS_E_1 (TEXT);

create procedure 
load_xml_text (in n varchar, in t varchar)
{
  insert into XS_E_1 (NAME, TEXT) values (n, t);
}
;

set charset='KOI8-R';
load_xml_text('English.UTF8-x-any'	, '<?xml version="1.0"?><q><w>One two three four five 3.14 A.B.B.R.E.V.I.A.T.I.O.N.</w><p>2.17</p></q>');

load_xml_text('English.ASCII-x-any'	, '<?xml version="1.0" encoding="ASCII" ?><q><w>One two three four five 3.14 A.B.B.R.E.V.I.A.T.I.O.N.</w><p>2.17</p></q>');

load_xml_text('English.WIN-x-any'	, '<?xml version="1.0" encoding="WINDOWS-1251" ?><q><w>One two three four five 3.14 A.B.B.R.E.V.I.A.T.I.O.N.</w><p>2.17</p></q>');

load_xml_text('English.UTF8-en'	, '<?xml version="1.0"?><q><w xml:lang="en">One two three four five 3.14 A.B.B.R.E.V.I.A.T.I.O.N.</w><p>2.17</p></q>');

load_xml_text('English.ASCII-en'	, '<?xml version="1.0" encoding="ASCII" ?><q><w xml:lang="en">One two three four five 3.14 A.B.B.R.E.V.I.A.T.I.O.N.</w><p>2.17</p></q>');

load_xml_text('English.WIN-en'		, '<?xml version="1.0" encoding="WINDOWS-1251" ?><q><w xml:lang="en">One two three four five 3.14 A.B.B.R.E.V.I.A.T.I.O.N.</w><p>2.17</p></q>');

load_xml_text('Russian.UTF8-x-any'	, '<?xml version="1.0"?><q><w>п·п╫ п╢п╬п╠п╟п╡п╦п╩ п╨п╟я─я┌п╬я┬п╨п╦, п©п╬я│п╬п╩п╦п╩ п╦ п©п╬я│я┌п╟п╡п╦п╩ п╟п╨п╡п╟я─п╦я┐п╪ п╫п╟ п╬пЁп╬п╫я▄</w><p>2.17</p></q>');

load_xml_text('Russian.OEM-x-any'	, '<?xml version="1.0" encoding="IBM866" ?><q><w>▌╜ ╓╝║═╒╗╚ ╙═ЮБ╝Х╙╗, ╞╝А╝╚╗╚ ╗ ╞╝АБ═╒╗╚ ═╙╒═Ю╗Ц╛ ╜═ ╝ё╝╜Л</w><p>2.17</p></q>');

load_xml_text('Russian.KOI-x-any'	, '<?xml version="1.0" encoding="KOI8-R" ?><q><w>Он добавил картошки, посолил и поставил аквариум на огонь</w><p>2.17</p></q>');

load_xml_text('Russian.WIN-x-any'	, '<?xml version="1.0" encoding="WINDOWS-1251" ?><q><w>нМ ДНАЮБХК ЙЮПРНЬЙХ, ОНЯНКХК Х ОНЯРЮБХК ЮЙБЮПХСЛ МЮ НЦНМЭ</w><p>2.17</p></q>');

load_xml_text('Russian.UTF8-en'	, '<?xml version="1.0"?><q><w xml:lang="en">п·п╫ п╢п╬п╠п╟п╡п╦п╩ п╨п╟я─я┌п╬я┬п╨п╦, п©п╬я│п╬п╩п╦п╩ п╦ п©п╬я│я┌п╟п╡п╦п╩ п╟п╨п╡п╟я─п╦я┐п╪ п╫п╟ п╬пЁп╬п╫я▄</w><p>2.17</p></q>');

load_xml_text('Russian.OEM-en'		, '<?xml version="1.0" encoding="IBM866" ?><q><w xml:lang="en">▌╜ ╓╝║═╒╗╚ ╙═ЮБ╝Х╙╗, ╞╝А╝╚╗╚ ╗ ╞╝АБ═╒╗╚ ═╙╒═Ю╗Ц╛ ╜═ ╝ё╝╜Л</w><p>2.17</p></q>');

load_xml_text('Russian.KOI-en'		, '<?xml version="1.0" encoding="KOI8-R" ?><q><w xml:lang="en">Он добавил картошки, посолил и поставил аквариум на огонь</w><p>2.17</p></q>');

load_xml_text('Russian.WIN-en'		, '<?xml version="1.0" encoding="WINDOWS-1251" ?><q><w xml:lang="en">нМ ДНАЮБХК ЙЮПРНЬЙХ, ОНЯНКХК Х ОНЯРЮБХК ЮЙБЮПХСЛ МЮ НЦНМЭ</w><p>2.17</p></q>');

load_xml_text('English.UTF8-x-any'	, '<?xml version="1.0"?><q><w>One two three four five 3.14 A.B.B.R.E.V.I.A.T.I.O.N.</w><p>2.17</p></q>');

load_xml_text('English.ASCII-x-any'	, '<?xml version="1.0" encoding="ASCII" ?><q><w>One two three four five 3.14 A.B.B.R.E.V.I.A.T.I.O.N.</w><p>2.17</p></q>');

load_xml_text('English.WIN-x-any'	, '<?xml version="1.0" encoding="WINDOWS-1251" ?><q><w>One two three four five 3.14 A.B.B.R.E.V.I.A.T.I.O.N.</w><p>2.17</p></q>');

load_xml_text('English.UTF8-en'	, '<?xml version="1.0"?><q><w xml:lang="en">One two three four five 3.14 A.B.B.R.E.V.I.A.T.I.O.N.</w><p>2.17</p></q>');

load_xml_text('English.ASCII-en'	, '<?xml version="1.0" encoding="ASCII" ?><q><w xml:lang="en">One two three four five 3.14 A.B.B.R.E.V.I.A.T.I.O.N.</w><p>2.17</p></q>');

load_xml_text('English.WIN-en'		, '<?xml version="1.0" encoding="WINDOWS-1251" ?><q><w xml:lang="en">One two three four five 3.14 A.B.B.R.E.V.I.A.T.I.O.N.</w><p>2.17</p></q>');

load_xml_text('Russian.UTF8-x-any'	, '<?xml version="1.0"?><q><w>п·п╫ п╢п╬п╠п╟п╡п╦п╩ п╨п╟я─я┌п╬я┬п╨п╦, п©п╬я│п╬п╩п╦п╩ п╦ п©п╬я│я┌п╟п╡п╦п╩ п╟п╨п╡п╟я─п╦я┐п╪ п╫п╟ п╬пЁп╬п╫я▄</w><p>2.17</p></q>');

load_xml_text('Russian.OEM-x-any'	, '<?xml version="1.0" encoding="IBM866" ?><q><w>▌╜ ╓╝║═╒╗╚ ╙═ЮБ╝Х╙╗, ╞╝А╝╚╗╚ ╗ ╞╝АБ═╒╗╚ ═╙╒═Ю╗Ц╛ ╜═ ╝ё╝╜Л</w><p>2.17</p></q>');

load_xml_text('Russian.KOI-x-any'	, '<?xml version="1.0" encoding="KOI8-R" ?><q><w>Он добавил картошки, посолил и поставил аквариум на огонь</w><p>2.17</p></q>');

load_xml_text('Russian.WIN-x-any'	, '<?xml version="1.0" encoding="WINDOWS-1251" ?><q><w>нМ ДНАЮБХК ЙЮПРНЬЙХ, ОНЯНКХК Х ОНЯРЮБХК ЮЙБЮПХСЛ МЮ НЦНМЭ</w><p>2.17</p></q>');

load_xml_text('Russian.UTF8-en'	, '<?xml version="1.0"?><q><w xml:lang="en">п·п╫ п╢п╬п╠п╟п╡п╦п╩ п╨п╟я─я┌п╬я┬п╨п╦, п©п╬я│п╬п╩п╦п╩ п╦ п©п╬я│я┌п╟п╡п╦п╩ п╟п╨п╡п╟я─п╦я┐п╪ п╫п╟ п╬пЁп╬п╫я▄</w><p>2.17</p></q>');

load_xml_text('Russian.OEM-en'		, '<?xml version="1.0" encoding="IBM866" ?><q><w xml:lang="en">▌╜ ╓╝║═╒╗╚ ╙═ЮБ╝Х╙╗, ╞╝А╝╚╗╚ ╗ ╞╝АБ═╒╗╚ ═╙╒═Ю╗Ц╛ ╜═ ╝ё╝╜Л</w><p>2.17</p></q>');

load_xml_text('Russian.KOI-en'		, '<?xml version="1.0" encoding="KOI8-R" ?><q><w xml:lang="en">Он добавил картошки, посолил и поставил аквариум на огонь</w><p>2.17</p></q>');

load_xml_text('Russian.WIN-en'		, '<?xml version="1.0" encoding="WINDOWS-1251" ?><q><w xml:lang="en">нМ ДНАЮБХК ЙЮПРНЬЙХ, ОНЯНКХК Х ОНЯРЮБХК ЮЙБЮПХСЛ МЮ НЦНМЭ</w><p>2.17</p></q>');


select NAME from XS_E_1 where xcontains (TEXT, '//w[text-contains(., "''3.14 A.B.B.R.E.V.I.A.T.I.O.N.''")]');
select NAME from XS_E_1 where xcontains (TEXT, '[__enc ''ASCII''] //w[text-contains(., "''3.14 A.B.B.R.E.V.I.A.T.I.O.N.''")]');
select NAME from XS_E_1 where xcontains (TEXT, '[__enc ''WINDOWS-1251''] //w[text-contains(., "''3.14 A.B.B.R.E.V.I.A.T.I.O.N.''")]');
select NAME from XS_E_1 where xcontains (TEXT, '[__lang ''en''] //w[text-contains(., "''3.14 A.B.B.R.E.V.I.A.T.I.O.N.''")]');
select NAME from XS_E_1 where xcontains (TEXT, '[__lang ''en'' __enc ''ASCII''] //w[text-contains(., "''3.14 A.B.B.R.E.V.I.A.T.I.O.N.''")]');
select NAME from XS_E_1 where xcontains (TEXT, '[__lang ''en'' __enc ''WINDOWS-1251''] //w[text-contains(., "''3.14 A.B.B.R.E.V.I.A.T.I.O.N.''")]');
select NAME from XS_E_1 where xcontains (TEXT, '[__enc ''ASCII''] //w[text-contains(., "[__lang ''en''] ''3.14 A.B.B.R.E.V.I.A.T.I.O.N.''")]');
select NAME from XS_E_1 where xcontains (TEXT, '[__enc ''WINDOWS-1251''] //w[text-contains(., "[__lang ''en''] ''3.14 A.B.B.R.E.V.I.A.T.I.O.N.''")]');
select NAME from XS_E_1 where xcontains (TEXT, '//w[text-contains(., "''поставил аквариум на огонь''")]');
select NAME from XS_E_1 where xcontains (TEXT, '[__enc ''UTF-8''] //w[text-contains(., "''п©п╬я│я┌п╟п╡п╦п╩ п╟п╨п╡п╟я─п╦я┐п╪ п╫п╟ п╬пЁп╬п╫я▄''")]');
select NAME from XS_E_1 where xcontains (TEXT, '[__enc ''IBM866''] //w[text-contains(., "''╞╝АБ═╒╗╚ ═╙╒═Ю╗Ц╛ ╜═ ╝ё╝╜Л''")]');
select NAME from XS_E_1 where xcontains (TEXT, '[__enc ''KOI8-R''] //w[text-contains(., "''поставил аквариум на огонь''")]');
select NAME from XS_E_1 where xcontains (TEXT, '[__enc ''WINDOWS-1251''] //w[text-contains(., "''ОНЯРЮБХК ЮЙБЮПХСЛ МЮ НЦНМЭ''")]');

select NAME from XS_E_1 where contains (TEXT, '"3.14 A.B.B.R.E.V.I.A.T.I.O.N."');
select NAME from XS_E_1 where contains (TEXT, '[__enc ''ASCII''] "3.14 A.B.B.R.E.V.I.A.T.I.O.N."');
select NAME from XS_E_1 where contains (TEXT, '[__enc ''WINDOWS-1251''] "3.14 A.B.B.R.E.V.I.A.T.I.O.N."');
select NAME from XS_E_1 where contains (TEXT, '[__lang ''en''] "3.14 A.B.B.R.E.V.I.A.T.I.O.N."');
select NAME from XS_E_1 where contains (TEXT, '[__lang ''en'' __enc ''ASCII''] "3.14 A.B.B.R.E.V.I.A.T.I.O.N."');
select NAME from XS_E_1 where contains (TEXT, '[__lang ''en'' __enc ''WINDOWS-1251''] "3.14 A.B.B.R.E.V.I.A.T.I.O.N."');
select NAME from XS_E_1 where contains (TEXT, '"поставил аквариум на огонь"');
select NAME from XS_E_1 where contains (TEXT, '[__enc ''UTF-8''] "п©п╬я│я┌п╟п╡п╦п╩ п╟п╨п╡п╟я─п╦я┐п╪ п╫п╟ п╬пЁп╬п╫я▄"');
select NAME from XS_E_1 where contains (TEXT, '[__enc ''IBM866''] "╞╝АБ═╒╗╚ ═╙╒═Ю╗Ц╛ ╜═ ╝ё╝╜Л"');
select NAME from XS_E_1 where contains (TEXT, '[__enc ''KOI8-R''] "поставил аквариум на огонь"');
select NAME from XS_E_1 where contains (TEXT, '[__enc ''WINDOWS-1251''] "ОНЯРЮБХК ЮЙБЮПХСЛ МЮ НЦНМЭ"');
