
create procedure OMAIL.WA.utl_arr_dump(in arr any)
{
  return sprintf('<pre>%s</pre>',OMAIL.WA.utl_arr_dump_recu(arr,0,0));
}
;

--
create procedure OMAIL.WA.utl_arr_dump_recu(
  in arr    any,
  in alevel integer,
  in elem    integer)
{
  declare len,ind,lyear integer;
  declare res,buff varchar;
  declare _color any;

  _color := vector('000000','FD9B00','9D995F','FD0065','2A00FD','706A11','03C8CF','CF6803','0316CF');
  res := sprintf('<font color="#%s">',aref(_color,alevel));
  len := length(arr);

  ind := 0;
  while(ind < len and ind < 100){
    if (isnull(aref(arr,ind)))
      aset(arr,ind,'NULL');

    if (isarray(aref(arr,ind)) and not isstring(aref(arr,ind))){
      res := sprintf('%s <br>%s ',res,OMAIL.WA.utl_arr_dump_recu(aref(arr,ind),alevel+1,ind));
	  } else {
      if (isstring(aref(arr,ind))) {
        -- string
        res := sprintf('%s,\n %s"%s"',res,space(alevel*3+6),replace(aref(arr,ind),'\r\n',''));

      }else if(internal_type(aref(arr,ind)) = 230) {
        -- XML entity
        buff := OMAIL.WA.utl_xml2str(aref(arr,ind));
        buff := replace(buff,'<','&lt;');
        buff := replace(buff,'>',concat('&gt;<br>',space(alevel*3+10)));
        res := sprintf('%s,\n %s"%s"',res,space(alevel*3+6),buff);
      }
      else
        res := sprintf('%s,\n %s%s',res,space(alevel*3+4),cast(aref(arr,ind) as varchar));
    };
    ind := ind + 1;
  };
  res := sprintf('%s</font>',res);
  return sprintf(' %s <font color="#%s"><b>array[%d:%d]</b>{%s\n%s}</font>',space(alevel*3),aref(_color,alevel),alevel,elem,ltrim(res,', '),space(alevel*2+4));
}
;

--==================================================
create procedure OMAIL.WA.utl_array2xml(
  in _arr any)
{
  declare _ind integer;
  declare _rs,_node,_value varchar;

  _rs  := '';
  for (_ind := 0;_ind < length(_arr); _ind := _ind + 2) {
  	if (isstring(_arr[_ind])) {
  	  _node := lower(cast(_arr[_ind] as varchar));
  	  if (isarray(_arr[_ind+1]) and not isstring(_arr[_ind+1])) {
  	    _value := OMAIL.WA.utl_array2xml(aref(_arr,_ind+1)) ;

  	  } else if (isnull(_arr[_ind+1])) {
  	    _value := '';

  	  } else {
  	    _value := cast(_arr[_ind+1] as varchar);
  	  }
  	  _rs := sprintf('%s<%s>%s</%s>\n',_rs,_node,_value,_node);
    }
  }
  return _rs;
}
;

--==================================================
create procedure OMAIL.WA.utl_combos2arr(
  inout _params any,
  in    _kword   varchar,
  in    _cast varchar := 'integer')
{
  declare _ind,_name,_value,_arr any;

  _arr := vector();
  while (_ind < length(_params)) {
    _name  := aref(_params,_ind);
    if (_name = _kword) {
      _value := aref(_params,_ind + 1);
      if (_cast = 'integer') {
        _value := cast(_value as integer);
      } else if(_cast = 'varchar'){
        _value := cast(_value as varchar);
      };
    	_arr := vector_concat(_arr,vector(_value));
    };
  	_ind := _ind + 2;
  };
  return _arr;
}
;

--==================================================
create procedure OMAIL.WA.utl_date2xml (in m_time  time ){
  declare _rs,d,e,h,m,y,s,w varchar;
  declare exit handler FOR SQLSTATE '22007' { return '';};

  if(isnull(m_time)) return '';

  h := either(lt(cast(hour(m_time) as integer),10),sprintf('%d%d',0,hour(m_time)),cast(hour(m_time)as varchar));
  e := either(lt(cast(minute(m_time) as integer),10),sprintf('%d%d',0,minute(m_time)),cast(minute(m_time)as varchar));
  s := either(lt(cast(second(m_time) as integer),10),sprintf('%d%d',0,second (m_time)),cast(second(m_time)as varchar));
  d := either(lt(cast(dayofmonth(m_time) as integer),10),sprintf('%d%d',0,dayofmonth(m_time)),cast(dayofmonth(m_time)as varchar));
  m := either(lt(cast(month(m_time) as integer),10),sprintf('%d%d',0,month(m_time)),cast(month(m_time)as varchar));
  w := cast(dayofweek(m_time) as varchar);
  y := cast(year(m_time)as varchar);

	_rs := '';

  --_rs := sprintf('<ddate>');
  _rs := sprintf('%s<hour>%s</hour>',_rs,h);
  _rs := sprintf('%s<minute>%s</minute>',_rs,e);
  _rs := sprintf('%s<second>%s</second>',_rs,s);
  _rs := sprintf('%s<day>%s</day>',_rs,d);
  _rs := sprintf('%s<wday>%s</wday>',_rs,w);
  _rs := sprintf('%s<month>%s</month>',_rs,m);
  _rs := sprintf('%s<year>%s</year>',_rs,y);
  --_rs := sprintf('%s</ddate>',_rs);

  return _rs;
}
;

--==================================================
create procedure OMAIL.WA.utl_dbg_benchmark(
  in description varchar := '',
  in act         varchar := 'bench')
{
  declare filename varchar;
  declare filecontent,start_str,offset_str,start_offset_str varchar;
  declare ctime,ltime,start integer;

  filename := 'dbg_benchmark.txt';
  start_str := 'START | ';

  if(lower(act)=lower('reset')){
         ctime := msec_time();
         string_to_file(filename,concat(start_str,cast(ctime as varchar),'\n'),-2);
         registry_set('openx_dbg_benchmark_start_time',cast(ctime as varchar));
         registry_set('openx_dbg_benchmark_last_time',cast(ctime as varchar));
         return ctime;
  }else if(lower(act)=lower('bench')){
         ctime := msec_time();
         ltime := cast(registry_get('openx_dbg_benchmark_last_time')as integer);
         start := cast(registry_get('openx_dbg_benchmark_start_time')as integer);
         start_offset_str := cast(ctime-start as varchar);
         offset_str       := cast(ctime-ltime as varchar);
         string_to_file(filename,concat('BENCH | ',start_offset_str,space(10-length(start_offset_str)),' msec | ',offset_str,space(5-length(offset_str)),' msec | ',description,'\n'),-1);
         registry_set('openx_dbg_benchmark_last_time',cast(ctime as varchar));
         return ctime;
  }else{return 0;};
}
;

--==================================================
create procedure OMAIL.WA.utl_decode_qp(
  inout _body      varchar,
  in    _encoding  varchar)
{
  _encoding := either(isnull(_encoding),'',_encoding);
  if (isblob(_body))
    _body := blob_to_string(_body);

  if ((_encoding = 'quoted-printable') or strstr(_body,'=3D')) {
    _body := replace(_body,'\r\n','\n');
		_body := replace(_body,'=\n','');
		_body := split_and_decode(_body,0,'=');
	};
}
;

--==================================================
create procedure OMAIL.WA.utl_find_keyword(
  in _arr any,
  in _word varchar)
{
  declare _ind,_name any;
  _ind :=0;
  while(_ind < length(_arr)){
    _name := aref(_arr,_ind);
    if(_name like _word){
      return _name;
      return aref(_arr,_ind + 1);
    };
    _ind := _ind + 2;
  };
  return null;
}
;

--==================================================
create procedure OMAIL.WA.utl_find_keyword_simple(
  in _arr any,
  in _word varchar)
{
  declare _ind,_name any;

  _ind :=0;
  while (_ind < length(_arr)) {
    if(aref(_arr,_ind) like _word){
      return 1;
    };
    _ind := _ind + 1;
  };
  return null;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utl_form_option(
  in _array any,
  in _selection varchar)
{
  declare N integer;
  declare S varchar;

  S := '';
  for (N := 0; N < length(_array); N := N + 2) {
    if (cast(_selection as varchar) = _array[N])
      S := sprintf('%s\n<option value="%s" selected="1">%s</option>', S, _array[N], _array[N+1]);
    else
      S := sprintf('%s\n<option value="%s">%s</option>', S, _array[N], _array[N+1]);
  }
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utl_form_select_day(
  in _name varchar,
  in _day varchar,
  in _date date)
{
  declare days varchar;
  declare arr any;

  if (is_empty_or_null(_day))
    _day := dayofmonth(_date);
  days := '1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13,14,14,15,15,16,16,17,17,18,18,19,19,20,20,21,21,22,22,23,23,24,24,25,25,26,26,27,27,28,28,29,29,30,30,31,31';
  arr  := split_and_decode(days,0,concat('\0\0,'));
  return sprintf('<select name="%s">%s\n</select>\n', _name, OMAIL.WA.utl_form_option(arr, _day));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utl_form_select_month (
  in _name varchar,
  in _month varchar,
  in _date date)
{
  declare months varchar;
  declare arr any;

  if (is_empty_or_null(_month))
    _month := month(_date);

  months := '1,January,2,February,3,March,4,April,5,May,6,June,7,July,8,August,9,September,10,October,11,November,12,December';
  arr := split_and_decode(months, 0, concat('\0\0,'));
  return sprintf('<select name="%s">%s\n</select>\n', _name, OMAIL.WA.utl_form_option(arr, _month));
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.utl_form_select_year(
  in _name varchar,
  in _year varchar,
  in _date date,             -- date from which to generate the 'select'
  in _before integer := 20,  -- years before adate
  in _after integer := 2)    -- years after adate
{
  declare N integer;
  declare arr any;

  if (is_empty_or_null(_year))
    _year := year(_date);
  _year := cast(_year as integer);

  arr := vector();
  for (N := year(_date)-_before; N < year(_date)+_after; N := N+1)
    arr := vector_concat(arr, vector(cast(N as varchar), cast(N as varchar)));
  return sprintf('<select name="%s">%s\n</select>\n', _name, OMAIL.WA.utl_form_option(arr, _year));
}
;

--==================================================
create procedure OMAIL.WA.utl_get2post(
  in _get_vars varchar,
  in _pattern  varchar)
{
 ---------------------------------------------------------
  -- Descr: transform http GET vars from URL to POST vars
  -- Supported by: Veselin Malezanov <vmalezanov@openlinksw.bg>
  --
  -- IN:
  --  _get_vars  -> URL (ex. default.vsp?sid=abc&pid=123)
  --  _pattern -> pattern (ex. <input name="%s" value="%s">)
  -- OUT:
  --  string
  ---------------------------------------------------------

  declare _buff,_pos,_res,_tmp any;
  _res := '';
  _pos := locate('?',_get_vars);

  if (_pos) {
   _buff := substring(_get_vars,_pos+1,length(_get_vars));
   _buff := split_and_decode(_buff,0,'\0\0&');
   declare _ind any;
    _ind :=0;
    while(_ind < length(_buff)){
      if(length(_buff[_ind]) > 0){
        _tmp := split_and_decode(_buff[_ind],0,'\0\0=');
        if(isarray(_tmp) and length(_tmp) > 1) {
          if(length(_tmp[0]) > 0)
            _res := sprintf(concat('%s',_pattern),_res,_tmp[0],_tmp[1]);
        } else {
          _res := sprintf(concat('%s',_pattern),_res,_buff[_ind],'');
        }
      }
      _ind := _ind + 1;
    }
  }
  return _res;
}
;

--==================================================
create procedure OMAIL.WA.utl_get_header_info(
	in _lines any,
	in _elem  varchar)
{
	declare _pos,_header,_ind,_name,_value,_sep,_res any;
	_header := vector();
	_res := '';

	while(_ind < length(_lines)) {
    if(aref(_lines,_ind) like 'GET %') {
      _sep := ' ';
    } else {
      _sep := ':';
    };

		_pos 	 := strstr(aref(_lines,_ind),_sep);
		_name  := lower(subseq(aref(_lines,_ind),0,_pos));
  	_value := trim(subseq(aref(_lines,_ind),_pos+1));
  	_value := replace(_value,'\r\n','');
  	_value := replace(_value,'\n','');
		_header := vector_concat(_header,vector(_name,_value));

		_ind := _ind + 1;
	};

  if ((_elem <> '') and (not isnull(_elem))) {
    _ind :=0;
    while(_ind < length(_header)) {
      if (lower(_elem) = aref(_header,_ind))
        _res := sprintf('%s, %s',_res,aref(_header,_ind+1));
      _ind := _ind + 1;
    };
    if (length(_res) = 0)
      return null;
    return subseq(_res,2);
  }
  return _header;
}
;

--==================================================
create procedure OMAIL.WA.utl_locate_last(
  in _str1 varchar,
  in _str2 varchar)
{
  declare _start,_rez integer;
  _start := 1;

  while(1){
    _rez := locate(_str1,_str2,_start);
    if(isnull(_rez)) return null;
    if(not(_rez)) return _start-length(_str1);
    else         _start := _rez+length(_str1);
  };
  return _rez;
}
;

--==================================================
create procedure OMAIL.WA.utl_mdate_to_tstamp(in _mdate varchar)
{
	----------------------------------------------------------
	-- Get mail format "DAY, DD MON YYYY HH:MI:SS {+,-}HHMM"
	--		  and return "DD.MM.YYYY HH:MI:SS" GMT
	------------------------------------------------------------
	declare _arr,_months,_rs,_tzone_z,_tzone_h,_tzone_m any;
	declare _date,_month,_year,_hms,_tzone varchar;

	_months := vector('JAN','01','FEB','02','MAR','03','APR','04','MAY','05','JUN','06','JUL','07','AUG','08','SEP','09','OCT','10','NOV','11','DEC','12');
	_arr := split_and_decode(ltrim(_mdate),0,'\0\0 ');

	if(length(_arr) = 6){
		_date   := aref(_arr,1);
		_month  := aref(_arr,2);
		_year   := aref(_arr,3);
		_hms    := aref(_arr,4);
		_tzone  := aref(_arr,5);

		_month  := get_keyword(upper(_month),_months,'');

		_tzone_z := substring(_tzone,1,1);
		_tzone_h := atoi(substring(_tzone,2,2));
		_tzone_m := atoi(substring(_tzone,4,2));

	  if(_tzone_z = '+'){
	     _tzone_h := _tzone_h - 2*_tzone_h;
	     _tzone_m := _tzone_m - 2*_tzone_m;
		}
	  _rs := sprintf('%s.%s.%s %s',_month,_date,_year,_hms);
	  _rs := stringdate(_rs);
	  _rs := dateadd ('hour',   _tzone_h, _rs);
	  _rs := dateadd ('minute', _tzone_m, _rs);

	}else{
	  _rs := '01.01.1900 00:00:00'; -- set system date
	};
	return _rs;
}
;

--==================================================
create procedure OMAIL.WA.utl_myhttp(
	in _xml 	  any,
	in _xsl     any,
	in _mime    any,
	in _accept  any,
	in _path    any,
	in _entry   varchar := '')
{

  declare _ind integer;
  declare _xsl_path,_mime_type varchar;
  declare _xsl_prefix any;

  _accept := OMAIL.WA.utl_get_header_info(_accept,'accept');

  -- print xml tree ------------------------------------------------------------
  if (_mime = 'x'){
		_mime_type := 'text/xml';

  -- print xml tree ------------------------------------------------------------
  } else if (_mime = 'xt'){
		_mime_type := 'text/plain';

  -- print html-----------------------------------------------------------------
  } else if (_mime = 'image/gif'){
		_mime_type := 'image/gif';

  -- print html-----------------------------------------------------------------
  } else {
    -- get xsl template by default path
    if (isnull(_xsl))
      _xsl := concat(subseq(aref(_path,length(_path)-1),0,strstr(aref(_path,length(_path)-1),'.')+1),'xsl');

    _xsl_path := OMAIL.WA.omail_xslt_full(_xsl);
    _mime_type := 'text/html';
    xslt_stale(_xsl_path);

    _xml := xml_tree(_xml,0);
    _xml := xml_tree_doc(_xml);
    _xml := xslt(_xsl_path,_xml);
    _xml := OMAIL.WA.utl_xml2str(_xml);
  };

	-- Print to output
  http_rewrite();
  http_header (sprintf ('Content-type: %s\r\n', _mime_type));
  http(_xml);
}
;

--==================================================
create procedure OMAIL.WA.utl_paramclear(
  in    _name	 varchar,
  inout _params any)
  ---------------------------------------------------------
  -- Descr: pop out 1 parameter from _params
  -- Support : Veselin Malezanov
  -- IN:
  --  _name   -> name of element (ex. user_id)
  --  _params -> associative array of params
  -- OUT: <none>
  ---------------------------------------------------------
{
  declare _len,_ind integer;
  declare _params_new any;

  _params_new := vector();

  if(not isarray(_params))
    return;

  _ind := 0;
  _len := length(_params);
  while(_ind < _len){
   	if(aref(_params,_ind) <> _name)
   		_params_new := vector_concat(_params_new,vector(aref(_params,_ind)),vector(aref(_params,_ind+1)));
 		_ind := _ind + 2;
  };

  _params := _params_new;
  return ;
}
;

--==================================================
create procedure OMAIL.WA.utl_paramget(
  in _name varchar,
  in _params any){
  ---------------------------------------------------------
  -- Descr: get one element of associative vector _params (like get_keyword())
  -- Supported by: Veselin Malezanov <vmalezanov@openlinksw.bg>
  --
  -- IN:
  --  _names  -> name of element
  --  _params -> associative array of params
  -- OUT:
  --  value of _names in _params
  -- Exception:
  -- 1. If name not exist in _params, then return NULL
  ---------------------------------------------------------
  return get_keyword(_name,_params,null);
}
;

--==================================================
create procedure OMAIL.WA.utl_params2str(
  in _names			varchar,
  in _params 		any)
{
  -----------------------------------------------------------------------------
  -- Descr: get list of names and associative vector of params and return string of values
  -- of vector in order from names list with delimiter ','
  -- Supported by: Veselin Malezanov <vmalezanov@openlinksw.bg>
  --
  -- IN:
  --  _names  -> list of names delimited with ',' (ex. "user_id,msg_id,obj_id,...")
  --  _params -> associative array of params (ex. vector('user_id',101,'msg_id',0,...))
  -- OUT: <none>
  --  string of values, delimited with ',' (ex. "101,0,3434,...")
  -----------------------------------------------------------------------------
  declare _string,_names_arr,_values_arr,_separator,_val,_value any;
  declare _len,_ind,_int integer;
  _separator := ',';
	_string    := '';
  _val       := '';

  if(not isarray(_params))
    _params := vector();

	_names_arr  := split_and_decode(_names,0,concat('\0\0',_separator));

  _ind := 0;
  _len := length(_names_arr);
  while(_ind < _len){
   	_value := get_keyword(aref(_names_arr,_ind),_params,'');

   	if(isarray(_value)){
   	   _int := 0;
   	   _val := '';

   	   while(_int < length(_value)){
   	      _val := sprintf('%s:%s',_val,cast(aref(_value,_int) as varchar));
   	      _int := _int + 1;
   	   };

   	   if(length(_val) > 0){
   	      _val := substring(_val,2,length(_val));
   	   };

   	} else {
      _val := cast(_value as varchar);
    };
    _string := sprintf('%s,',_string,_val);
    if(length(_val) > 0)
   	  _string := sprintf('%s%s',_string,_val);
 		_ind := _ind + 1;
  };

  if (length(_string) > 0)
   	_string := substring(_string,2,length(_string));

  return _string;
}
;

--==================================================
create procedure OMAIL.WA.utl_paramset(
  in    _name	 varchar,
  inout _params any,
  in    _value  any)
{
  -----------------------------------------------------------------------------
  -- Descr: set value to one element of associative vector _params
  -- Supported by: Veselin Malezanov <vmalezanov@openlinksw.bg>
  --
  -- IN:
  --  _name   -> name of element
  --  _params -> associative array of params
  --  _value  -> (new) value
  -- OUT: <none>
  --
  -- Exception:
  -- 1. If name not exist in _params, then create it with new value
  -----------------------------------------------------------------------------
  declare _len,_ind integer;

  if (not isarray(_params))
    _params := vector();

  if (isstring(_params))
    _params := vector();

  if (not isarray(_value))
    _value := cast(_value as integer);

  _ind := 0;
  _len := length(_params);
  while(_ind < _len){
   	if (aref(_params,_ind) = _name) {
   		aset(_params,_ind+1,_value);
   		return;
   	};
 		_ind := _ind + 1;
  };
  _params := vector_concat(_params,vector(_name,_value));
}
;

--==================================================
create procedure OMAIL.WA.utl_redirect(in afull_location varchar)
{
  signal('90001',afull_location);
  return;
}
;

--==================================================
create procedure OMAIL.WA.utl_doredirect(in afull_location varchar)
{
  http_rewrite();
  http_request_status('HTTP/1.1 302');
  http_header(sprintf('Location: %s \r\n',afull_location));

  return;
}
;

--==================================================
create procedure OMAIL.WA.utl_redirect_adv(
  in    _url_default varchar,
  inout _params      any)
{
  declare _sid,_url varchar;
  _sid := get_keyword('sid',_params,'');
  _url := get_keyword('ru',_params,'');

  if (_url <> '') {
    if (_sid <> '') {
      _url := sprintf('%s&sid=%s',_url,_sid);
    };
  } else {
    _url := sprintf('%s&sid=%s',_url_default,_sid);
  };

  signal('90001',_url);
  return;
}
;

--==================================================
create procedure OMAIL.WA.utl_replace_arr(
	inout  _vector any,
	in     _what   varchar,
	in     _with   varchar)
{
  declare _ind integer;

  _ind := 0;
  while(_ind < length(_vector)){
    if(isstring(aref(_vector,_ind))){
      aset(_vector,_ind,replace(aref(_vector,_ind),_what,_with));
    };
    _ind := _ind + 1;
  };

	return;
}
;

--==================================================
create procedure OMAIL.WA.utl_strencode(
  in _address any)
{

  _address := xml_tree(concat('<a><![CDATA[',_address,']]></a>'),0);

  if(isarray(_address)){
    _address := xml_tree_doc(_address);
    _address := OMAIL.WA.utl_xml2str(_address);
		_address := replace(_address,'&lt;','<');
		_address := replace(_address,'&gt;','>');
		_address := replace(_address,'&apos;','\'');
		_address := replace(_address,'&quot;','"');
    _address := substring(_address,4,length(_address)-7);

  }else{
    _address := '<addres_list/>';
  };

	return _address;
}
;

--==================================================
create procedure OMAIL.WA.utl_tstamp_to_mdate(in atime time)
{
	----------------------------------------------------------
	-- Get mail format time GMT
	--		  and return "DAY, DD MON YYYY HH:MI:SS {+,-}HHMM"
	------------------------------------------------------------

  declare result,d,e,h,m,y,s,k,z,zh,zm,zz varchar;
  declare m_time TIME;
  declare daysofweek,months any;
	daysofweek := vector('01','Sun','02','Mon','03','Tue','04','Wed','05','Thu','06','Fri','07','Sat');
	months := vector('01','Jan','02','Feb','03','Mar','04','Apr','05','May','06','Jun','07','Jul','08','Aug','09','Sep','10','Oct','11','Nov','12','Dec');
  m_time := atime;

  d  := either(lt(cast(dayofmonth(m_time) as integer),10),sprintf('%d%d',0,dayofmonth(m_time)),cast(dayofmonth(m_time)as varchar));
  m  := either(lt(cast(month(m_time)      as integer),10),sprintf('%d%d',0,month(m_time))     ,cast(month(m_time)     as varchar));
  h  := either(lt(cast(hour(m_time)       as integer),10),sprintf('%d%d',0,hour(m_time))      ,cast(hour(m_time)      as varchar));
  e  := either(lt(cast(minute(m_time)     as integer),10),sprintf('%d%d',0,minute(m_time))    ,cast(minute(m_time)    as varchar));
  s  := either(lt(cast(second(m_time)     as integer),10),sprintf('%d%d',0,second (m_time))   ,cast(second(m_time)    as varchar));
	k  := either(lt(cast(dayofweek(m_time)  as integer),10),sprintf('%d%d',0,dayofweek(m_time)) ,cast(dayofweek(m_time) as varchar));
  y  := cast(year(m_time)as varchar);
	z  := timezone(m_time);
	if(z < 0) {zz := '-'; z := z-(2*z);} else{ zz := '+';};
	zh := either(lt(cast((z/60)    as integer),10),sprintf('%d%d',0,(z/60))   ,cast((z/60)   as varchar));
	zm := either(lt(cast(mod(z,60) as integer),10),sprintf('%d%d',0,mod(z,60)),cast(mod(z,60)as varchar));
	z  := sprintf('%s%s%s',zz,zh,zm);
	z  := cast(z as varchar);
  result := sprintf('%s, %s %s %s %s:%s:%s %s',get_keyword(k,daysofweek,''),d,get_keyword(m,months,''),y, h,e,s,z);

  RETURN result;
}
;

--==================================================
create procedure OMAIL.WA.utl_url_encode(in _url any)
{
  declare stream any;

  stream := string_output();
  http_url(_url,null,stream);
  return string_output_string(stream);
}
;

--==================================================
create procedure OMAIL.WA.utl_xhtml_parse(inout _body any)
{
  _body := xml_tree(_body,2);
  if(not isarray(_body)){
    signal('9001','Not valid XML content');
  };
  _body := xml_tree_doc(_body);
  xml_tree_doc_set_output (_body,'xhtml');
  _body := OMAIL.WA.utl_xml2str(_body);

  return;
}
;

--==================================================
create procedure OMAIL.WA.utl_xml2str(in axml_entry any){
  declare stream any;

  stream := string_output();
  http_value(axml_entry,null,stream);
  return string_output_string(stream);
}
;

--==================================================
create procedure OMAIL.WA.utl_parse_url(in url varchar){
  declare i,tmp any;

  i := strstr(url,' ');
  tmp := subseq(url,i+1);
  i := strstr(tmp,' ');
  tmp := subseq(tmp,1,i);
  i := strstr(tmp,'?');
  tmp := subseq(tmp,0,i);
  tmp := split_and_decode(tmp,0,'\0\0/');
  return tmp;
}
;
