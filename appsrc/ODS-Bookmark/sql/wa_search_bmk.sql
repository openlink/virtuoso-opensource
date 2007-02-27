create function WA_SEARCH_BMK_GET_EXCERPT_HTML (
    			in _current_user_id integer,
    			in _BD_BOOKMARK_ID int,
			in _BD_DOMAIN_ID int,
			in _BD_NAME varchar,
			in _BD_DESCRIPTION varchar,
			in words any) returns varchar
{
  declare url varchar;
  declare res varchar;

  select B_URI into url from BMK.WA.BOOKMARK where B_ID = _BD_BOOKMARK_ID;

      res := sprintf ('<span><img src="%s" /> <a href="%s" target="_blank">%s</a> %s ',
      WA_SEARCH_ADD_APATH ('images/icons/web_16.png'), url, _BD_NAME, _BD_NAME);

      res := res || '<br />' ||
      left (
	  search_excerpt (
	    words,
	    subseq (coalesce (_BD_DESCRIPTION, ''), 0, 200000)
	    ),
	  900) || '</span>';

   return res;
}
;
