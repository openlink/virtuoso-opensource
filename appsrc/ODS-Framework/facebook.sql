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

use DB;

wa_exec_no_error('drop type DB.DBA.FacebookRestClient');
wa_exec_no_error('drop type Facebook');

create type DB.DBA.FacebookRestClient as (
  api_key      varchar,
  secret       varchar,
  session_key  varchar,
  friends_list any,
  added        integer,
  last_call_id any,
  server_addr  varchar,
  debug_mode   integer
)
  constructor method FacebookRestClient(api_key varchar,secret varchar, session_key varchar),
  -- methods of this UDT correspond to API functions of Facebook - http://wiki.developers.facebook.com/index.php/API
  method auth_getSession(auth_token any) returns any,
  method call_method(method varchar,params any) returns any,
  method post_request(method varchar, params any) returns any,
  method generate_sig(params_array any, secret varchar) returns varchar,
  method users_getInfo( uids any,fields any) returns any,
  method users_isAppAdded() returns any,
  method friends_areFriends(uids1 any, uids2 any) returns any,
  method friends_get() returns any,
  method events_get(uid integer, eids any,start_time integer,end_time integer,rsvp_status varchar) returns any,
  method events_get(uid integer) returns any,
  method events_getMembers(eid integer) returns any,
  method fql_query(_query varchar) returns any,
  method feed_publishStoryToUser(title varchar,body varchar,image_1 varchar, image_1_link varchar,image_2 varchar,image_2_link varchar,
                                 image_3 varchar,image_3_link varchar,image_4 varchar,image_4_link varchar,priority     integer) returns any,
  method feed_publishStoryToUser(title varchar,body varchar) returns any,
  method feed_publishActionOfUser(title varchar,body varchar,image_1 varchar, image_1_link varchar,image_2 varchar,image_2_link varchar,
                                 image_3 varchar,image_3_link varchar,image_4 varchar,image_4_link varchar,priority     integer) returns any,
  method feed_publishActionOfUser(title varchar,body varchar) returns any,
  method friends_getAppUsers() returns any,
  method groups_get(uid integer,gids any) returns any,
  method groups_getMembers(gid integer) returns any,
  method notifications_get() returns any,
  method notifications_send(to_ids any,notification varchar, email varchar) returns any,
  method notifications_sendRequest(to_ids any,type varchar,content varchar, image varchar, invite integer) returns any,
  method photos_get(subj_id integer,aid integer, pids any) returns any,
  method photos_getAlbums(uid integer,aids integer) returns any,
  method photos_getTags(pids any) returns any,
  method profile_setFBML(markup varchar,uid integer) returns any,
  method profile_getFBML(uid integer) returns any,
  method fbml_refreshImgSrc(_url varchar) returns any,
  method fbml_refreshRefUrl(_url varchar) returns any,
  method fbml_setRefHandle(_handle varchar,fbml varchar) returns any
;

create constructor method FacebookRestClient(
       in api_key varchar,
       in secret varchar,
       in session_key varchar
)
  for DB.DBA.FacebookRestClient
{
  self.secret       := secret;
  self.session_key  := session_key;
  self.api_key      := api_key;
  self.last_call_id := 0;
  self.server_addr  := get_facebook_url('api')||'/restserver.php';
  self.debug_mode   := 0; --set this to 1 if you want to see error xml on server console
}
;

create method auth_getSession(
       in auth_token any
)
  for DB.DBA.FacebookRestClient
{
    declare _result any;
    declare _user integer;
    _result := self.call_method('facebook.auth.getSession', vector('auth_token',auth_token));
    if(_result is not null)
    {
       self.session_key := cast(xpath_eval('/auth_getSession_response/session_key',_result) as varchar);
       _user:=cast(xpath_eval('/auth_getSession_response/uid',_result) as integer);

    if (cast(xpath_eval('/auth_getSession_response/secret',_result) as varchar) is not null)
         -- desktop apps have a special secret
         self.secret := cast(xpath_eval('/auth_getSession_response/secret',_result) as varchar);

       return vector(self.session_key,_user);
  }
       return null;
}
;

--  /* UTILITY FUNCTIONS */
create method call_method(
       in method varchar,
       in params any
)
  for DB.DBA.FacebookRestClient
{
  declare _result any;
  declare res_xml varchar;

    res_xml := self.post_request(method, params);
    _result:=xtree_doc(res_xml);
    if(xpath_eval('/error_response',_result) is not null )
    {
       if(self.debug_mode=1)
       {
          dbg_obj_print('Facebook REST API returns ERROR XML');
          dbg_obj_print(res_xml);
       }

       return null;
    }

    return _result;
}
;

create method post_request(
       in method varchar,
       in params any
)
  for DB.DBA.FacebookRestClient
{

    if(params is null)
       params := vector();

    params := vector_concat(params,vector('method',method));
    params := vector_concat(params,vector('api_key',self.api_key)); --'ad77de6d743402ddb9f9a52ca9321bd0'

    if(method<>'facebook.auth.getSession')
    {
      if(get_keyword('call_id',params,null) is not null)
         params := vector_concat(params,vector('call_id',cast(msec_time()+1 as varchar)));
      else
         params := vector_concat(params,vector('call_id',cast(msec_time() as varchar)));
      params := vector_concat(params,vector('session_key',self.session_key)); --'a8c8361138addd75ca7dc340-663197781'
    }

  if (get_keyword('v',params,null) is null)
        params := vector_concat(params,vector('v','1.0'));

    params := vector_concat(params,vector('sig',self.generate_sig(params, self.secret))); --'e54f374e470893968b6c9457e69c6f7a'
    declare _result,aResult any;
    declare i,l integer;

    aResult:=string_output();
    i := 0;
    l := length(params);
  while(i < l)
  {
--     if (i + 1 < l and isarray (params[i + 1])) goto _skip;
    if (i > 0)
      http('&',aResult);
      http(params[i],aResult);
    if (i + 1 < l)
    {
        http('=',aResult);
        http_url(params[i + 1],null,aResult);
    }
      _skip:;
      i := i + 2;
  }

    declare post_string varchar;
    post_string:=string_output_string(aResult);

     declare ret_header, rq_header any;

  commit work;
  rq_header := 'Content-type: application/x-www-form-urlencoded \r\nUser-Agent: Facebook API VSP Client 1.1';
    _result:=http_get ('http://api.facebook.com/restserver.php', ret_header, 'POST', rq_header, post_string); --'127.0.0.1:8888'
     return _result;
}
;


create method generate_sig(
       in params_array any,
       in secret varchar
)
for DB.DBA.FacebookRestClient
{
    declare str varchar;
    declare params_key any;
    declare i,l integer;
  declare _key, _val varchar;

    l := length (params_array);
  params_key := vector();
  for (i := 0; i < l; i := i + 2)
    {
      _key := trim(cast(params_array[i] as varchar));
      _val := params_array[i+1];
      params_key:=vector_concat(params_key,vector(_key));
    }

   params_key:=__vector_sort(params_key);
  str := '';
   l := length (params_key);
  for (i := 0; i < l; i := i + 1)
   {
     _key := params_key[i];
     _val := get_keyword(_key,params_array);
     if (_val is not null)
         _val := trim (cast(_val as varchar));

     str := str || _key || '=' || _val;
   }
   str := str||secret;
   return md5(str);
}
;

--  /**
--   * Returns events according to the filters specified.
--   * @param int uid Optional: User associated with events.
--   *   A null parameter will default to the session user.
--   * @param array eids Optional: Filter by these event ids.
--   *   A null parameter will get all events for the user.
--   * @param int start_time Optional: Filter with this UTC as lower bound.
--   *   A null or zero parameter indicates no lower bound.
--   * @param int end_time Optional: Filter with this UTC as upper bound.
--   *   A null or zero parameter indicates no upper bound.
--   * @param string rsvp_status Optional: Only show events where the given uid
--   *   has this rsvp status.  This only works if you have specified a value for
--   *   uid.  Values are as in events.getMembers.  Null indicates to ignore
--   *   rsvp status when filtering.
--   * @return array of events
--   */
create method events_get(
      in uid integer,
      in eids any := '',
      in start_time integer :=0,
      in end_time integer :=0,
      in rsvp_status varchar :=''
)
  for DB.DBA.FacebookRestClient
{
    return self.call_method('facebook.events.get',
        vector('uid' , uid,
               'eids', eids,
               'start_time', start_time,
               'end_time', end_time,
                                 'rsvp_status', rsvp_status)
                         );
 }
;

create method events_get(
      in uid integer
)
  for DB.DBA.FacebookRestClient
{
    return self.events_get( uid,'',0,0,'');
}
;

--  /**
--   * Returns membership list data associated with an event
--   * @param int eid : event id
--   * @return assoc array of four membership lists, with keys 'attending',
--   *  'unsure', 'declined', and 'not_replied'
--   */
create method events_getMembers(
       in eid integer
)
for DB.DBA.FacebookRestClient
{
    return self.call_method('facebook.events.getMembers',vector('eid' , eid));
}
;

--  /**
--   * Makes an FQL query.  This is a generalized way of accessing all the data
--   * in the API, as an alternative to most of the other method calls.  More
--   * info at http://developers.facebook.com/documentation.php?v=1.0&doc=fql
--   * @param string query the query to evaluate
--   * @return generalized array representing the results
--   */
create method fql_query(
       in _query varchar
)
for DB.DBA.FacebookRestClient
{
    return self.call_method('facebook.fql.query',vector('query' , _query));
}
;

create method feed_publishStoryToUser(
              in title        varchar,
              in body         varchar,
              in image_1      varchar :=null,
              in image_1_link varchar :=null,
              in image_2      varchar :=null,
              in image_2_link varchar :=null,
              in image_3      varchar :=null,
              in image_3_link varchar :=null,
              in image_4      varchar :=null,
              in image_4_link varchar :=null,
              in priority     integer :=1
)
for DB.DBA.FacebookRestClient
{
    return self.call_method('facebook.feed.publishStoryToUser',
                            vector('title'       ,title,
                                   'body'        ,body,
                                   'image_1'     ,image_1,
                                   'image_1_link',image_1_link,
                                   'image_2'     ,image_2,
                                   'image_2_link',image_2_link,
                                   'image_3'     ,image_3,
                                   'image_3_link',image_3_link,
                                   'image_4'     ,image_4,
                                   'image_4_link',image_4_link,
                                   'priority'    ,priority));
}
;

create method feed_publishStoryToUser(
              in title        varchar,
              in body         varchar
)
for DB.DBA.FacebookRestClient
{
    return self.feed_publishStoryToUser(title,body, null,null,null,null,null,null,null,null,1);
}
;

create method feed_publishActionOfUser(
              in title        varchar,
              in body         varchar,
              in image_1      varchar :=null,
              in image_1_link varchar :=null,
              in image_2      varchar :=null,
              in image_2_link varchar :=null,
              in image_3      varchar :=null,
              in image_3_link varchar :=null,
              in image_4      varchar :=null,
              in image_4_link varchar :=null,
              in priority     integer :=1
)
for DB.DBA.FacebookRestClient
{
    return self.call_method('facebook.feed.publishActionOfUser',
                            vector('title'       ,title,
                                   'body'        ,body,
                                   'image_1'     ,image_1,
                                   'image_1_link',image_1_link,
                                   'image_2'     ,image_2,
                                   'image_2_link',image_2_link,
                                   'image_3'     ,image_3,
                                   'image_3_link',image_3_link,
                                   'image_4'     ,image_4,
                                   'image_4_link',image_4_link,
                                   'priority'    ,priority));
}
;

create method feed_publishActionOfUser(
              in title        varchar,
              in body         varchar
)
for DB.DBA.FacebookRestClient
{
    return self.feed_publishActionOfUser(title,body, null,null,null,null,null,null,null,null,1);
}
;

--  /**
--   * Returns the friends of the session user, who are also users
--   * of the calling application.
--   * @return array of friends
--   */
create method friends_getAppUsers()
for DB.DBA.FacebookRestClient
{
    return self.call_method('facebook.friends.getAppUsers', vector());
}
;
--  /**
--   * Returns groups according to the filters specified.
--   * @param int uid Optional: User associated with groups.
--   *  A null parameter will default to the session user.
--   * @param array gids Optional: group ids to query.
--   *   A null parameter will get all groups for the user.
--   * @return array of groups
--   */
create method groups_get(
       in uid integer,
       in gids any
)
for DB.DBA.FacebookRestClient
{
    return self.call_method('facebook.groups.get',vector('uid', uid,'gids',gids));
}
;

--  /**
--   * Returns the membership list of a group
--   * @param int gid : Group id
--   * @return assoc array of four membership lists, with keys
--   *  'members', 'admins', 'officers', and 'not_replied'
--   */
create method groups_getMembers(
         in gid integer
)
for DB.DBA.FacebookRestClient
{
    return self.call_method('facebook.groups.getMembers',vector('gid', gid));
}
;
--  /**
--   * Returns the outstanding notifications for the session user.
--   * @return assoc array of
--   *  notification count objects for 'messages', 'pokes' and 'shares',
--   *  a uid list of 'friend_requests', a gid list of 'group_invites',
--   *  and an eid list of 'event_invites'
--   */
create method notifications_get()
for DB.DBA.FacebookRestClient
{
   return self.call_method('facebook.notifications.get', vector());
 }
;
--  /**
--   * Sends an email notification to the specified user.
--   * @return string url which you should send the logged in user to to finalize the message.
--   */
create method notifications_send(
       in to_ids any,
       in notification varchar,
       in email varchar :=null
)
for DB.DBA.FacebookRestClient
{
  return self.call_method('facebook.notifications.send',
                          vector('to_ids', to_ids,
                                 'notification', notification,
                                 'email', email));
}
;

--  /**
--   * Sends a request to the specified user (e.g. "you have 1 event invitation")
--   * @param array to_ids   user ids to receive the request (must be friends with sender, capped at 10)
--   * @param string type    type of request, e.g. "event" (as in "You have an event invitation.")
--   * @param string content fbml content of the request.  really stripped down fbml - just
--   *                        text/names/links.  also, use the special tag <fb:req-choice url="" label="" />
--   *                        to specify the buttons to be included.
--   * @param string image   url of an image to show beside the request
--   * @param bool   invite  whether to call it an "invitation" or a "request"
--   * @return string url which you should send the logged in user to to finalize the message.
--   */
create method notifications_sendRequest(
       in to_ids any,
       in type varchar,
       in content varchar,
       in image varchar,
       in invite integer)
for DB.DBA.FacebookRestClient
{
    return self.call_method('facebook.notifications.sendRequest',
                           vector('to_ids', to_ids,
                                  'type', type,
                                  'content', content,
                                  'image', image,
                                  'invite', invite));
}
;
--  /**
--   * Returns photos according to the filters specified.
--   * @param int subj_id Optional: Filter by uid of user tagged in the photos.
--   * @param int aid Optional: Filter by an album, as returned by
--   *  photos_getAlbums.
--   * @param array pids Optional: Restrict to a list of pids
--   * Note that at least one of these parameters needs to be specified, or an
--   * error is returned.
--   * @return array of photo objects.
--   */
create method photos_get(
         in subj_id integer,
         in aid integer,
         in pids any
)
for DB.DBA.FacebookRestClient
{
    return self.call_method('facebook.photos.get',vector('subj_id', subj_id, 'aid', aid, 'pids', pids));
}
;
--  /**
--   * Returns the albums created by the given user.
--   * @param int uid Optional: the uid of the user whose albums you want.
--   *   A null value will return the albums of the session user.
--   * @param array aids Optional: a list of aids to restrict the query.
--   * Note that at least one of the (uid, aids) parameters must be specified.
--   * @returns an array of album objects.
--   */

create method photos_getAlbums(
              in uid integer,
              in aids integer
)
for DB.DBA.FacebookRestClient
{
    return self.call_method('facebook.photos.getAlbums', vector('uid' , uid, 'aids' , aids));
}
;

--  /**
--   * Returns the tags on all photos specified.
--   * @param string pids : a list of pids to query
--   * @return array of photo tag objects, with include pid, subject uid,
--   *  and two floating-point numbers (xcoord, ycoord) for tag pixel location
--   */
create method photos_getTags(
       in pids any
)
for DB.DBA.FacebookRestClient
{
    return self.call_method('facebook.photos.getTags', vector('pids' , pids));
}
;

--  /**
--   * Returns the requested info fields for the requested set of users
--   * @param array uids an array of user ids
--   * @param array fields an array of strings describing the info fields desired
--   * @return array of users
--   */
create method users_getInfo(
              in uids any,
  in fields any)
for DB.DBA.FacebookRestClient
{
    return self.call_method('facebook.users.getInfo', vector('uids' , uids, 'fields' , fields));
}
;

--  /**
--   * Returns whether or not the user corresponding to the current session object has the app installed
--   * @return boolean
--   */
create method users_isAppAdded()
for DB.DBA.FacebookRestClient
{
  if (self.added is not null)
      return self.added;

      declare _xmle any;

  _xmle := self.call_method('facebook.users.isAppAdded', vector());
      if(_xmle is not null)
         _xmle:=xpath_eval('/users_isAppAdded_response',_xmle);

      if(_xmle is not null)
      {
         self.added:=cast(_xmle as integer);
         return self.added;
      }
    return 0;
}
;

--  /**
--   * Returns whether or not pairs of users are friends.
--   * Note that the Facebook friend relationship is symmetric.
--   * @param array uids1: array of ids (id_1, id_2,...) of some length X
--   * @param array uids2: array of ids (id_A, id_B,...) of SAME length X
--   * @return array of uid pairs with bool, true if pair are friends, e.g.
--   *   array( 0 => array('uid1' => id_1, 'uid2' => id_A, 'are_friends' => 1),
--   *          1 => array('uid1' => id_2, 'uid2' => id_B, 'are_friends' => 0)
--   *         ...)
--   */
create method friends_areFriends(
      in uids1 any,
      in uids2 any)
for DB.DBA.FacebookRestClient
{
    return self.call_method('facebook.friends.areFriends',
                          vector('uids1', uids1,
                                 'uids2', uids2));
}
;

--  /**
--   * Returns the friends of the current session user.
--   * @return array of friends
--   */
create method friends_get()
for DB.DBA.FacebookRestClient
{
  if (self.friends_list is not null and length(self.friends_list)>0)
      return self.friends_list;

      declare _xmle,friends_arr any;
      declare i,friends_num integer;

      _xmle:=self.call_method('facebook.friends.get', vector());
      if(_xmle is not null)
      {
         _xmle:=xpath_eval('/friends_get_response/uid',_xmle,0);

         if(length(_xmle)>0)
            friends_num:=length(_xmle);

         friends_arr:=vector();
    for (i := 0; i < friends_num; i := i + 1)
         {
           friends_arr:=vector_concat(friends_arr,vector(cast(_xmle[i] as varchar)));
         }
         if(length(friends_arr)>0)
            return friends_arr;
      }
     return self.call_method('facebook.friends.get', vector());
}
;

--  /**
--   * Sets the FBML for the profile of the user attached to this session
--   * @param   string   markup     The FBML that describes the profile presence of this app for the user
--   * @return  array    A list of strings describing any compile errors for the submitted FBML
--   */
create method profile_setFBML(
       in markup varchar,
  in uid integer := null)
for DB.DBA.FacebookRestClient
{
    return self.call_method('facebook.profile.setFBML', vector('markup' , markup, 'uid' , uid));
  }
;

create method profile_getFBML(
       in uid integer
)
for DB.DBA.FacebookRestClient
{
    return self.call_method('facebook.profile.getFBML', vector('uid' , uid));
}
;

create method fbml_refreshImgSrc(
       in _url varchar
)
for DB.DBA.FacebookRestClient
{
    return self.call_method('facebook.fbml.refreshImgSrc', vector('url' , _url));
}
;

create method fbml_refreshRefUrl(
       in _url varchar
)
for DB.DBA.FacebookRestClient
{
    return self.call_method('facebook.fbml.refreshRefUrl', vector('url', _url));
}
;

create method fbml_setRefHandle(
       in _handle varchar,
       in fbml varchar
)
for DB.DBA.FacebookRestClient
{
    return self.call_method('facebook.fbml.setRefHandle', vector('handle' , _handle, 'fbml' , fbml));
}
;


-- #Facebook Type#

create type DB.DBA.Facebook as (
  api_client   DB.DBA.FacebookRestClient,
  api_key      varchar,
  secret       varchar,
  fb_params    any,
  _user        integer,
  _params      any,
  _lines       any

)
self as ref
  constructor method Facebook(api_key varchar,secret varchar,_params any, _lines any),
  method validate_fb_params () returns any,
  method get_valid_fb_params(params any, timeout any, namespace any) returns any,
  method in_fb_canvas() returns integer,
  method in_frame() returns integer,
  method verify_signature(fb_params any,expected_sig varchar) returns integer,
  method set_user( _user integer, session_key varchar, expires any) returns any,
  method do_get_session(auth_token any) returns any,
  method redirect(url varchar) returns any,
  method get_add_url(_next varchar) returns varchar,
  method get_login_url(_next varchar,canvas integer, skipcookie integer) returns varchar,
  method require_login(relog integer) returns integer,
  method get_loggedin_user() returns varchar,
  method current_url() returns varchar
;

create constructor method Facebook(
       in api_key varchar,
       in secret varchar,
       in _params any,
       in _lines any
)
for DB.DBA.Facebook
{
    self.api_key := api_key;
    self.secret  := secret;

    self._params := _params;
    self._lines  := _lines;

    self.api_client := new DB.DBA.FacebookRestClient(api_key, secret, null);

    self.validate_fb_params();
  if (get_keyword('friends',self.fb_params,null) is not null)
  {
        self.api_client.friends_list := split_and_decode (get_keyword('friends',self.fb_params), 0, '\0\0,');
    }
  if (get_keyword('added',self.fb_params,null) is not null)
  {
      self.api_client.added := get_keyword('added',self.fb_params);
    }
}
;

create method set_user(
       in _user integer,
       in session_key varchar,
       in expires any
)
for DB.DBA.Facebook
{
    declare expires_str varchar;
    if(expires is null)
       expires:=now();

    if(expires='0')
       expires:=dateadd ('hour', 168, now());

    if(isstring(expires) and expires='0')
         expires:=dateadd ('day', 15, now());
  else
    expires := now();

    expires_str := sprintf (' expires=%s;', date_rfc1123 (dateadd ('hour', 1, expires)));

    declare _COOKIE any;
    _COOKIE:=_get_cookie_vec (self._lines);

    if (self.in_fb_canvas()=0 AND
        (get_keyword(self.api_key || '_user',_COOKIE, null) is null OR get_keyword(self.api_key || '_user',_COOKIE, null) <> cast(_user as varchar))
       )
    {
      declare cookies any;

      cookies := vector();
      cookies := vector_concat(cookies,vector('user',_user));
      cookies := vector_concat(cookies,vector('session_key',session_key));

      declare sig any;
      sig := self.api_client.generate_sig(cookies, self.secret);

      declare  cookie_str varchar;
      declare i,l integer;
      i := 0;
      l := length (cookies);
      while (i < l)
      {
        declare _key, _val varchar;
        _key := trim (cast(cookies[i] as varchar));
        _val := cookies[i+1];
        if (_val is not null)
            _val := trim (cast(_val as varchar));

        cookie_str := sprintf ('Set-Cookie: %s=%s;%s path=/\r\n', _key,_val, expires_str);
        http_header (cookie_str);

        i := i + 2;
      }


      cookie_str := sprintf ('Set-Cookie: %s=%s;%s path=/\r\n', self.api_key,sig, expires_str);
      http_header (cookie_str);
    }

    self._user := _user;
    self.api_client:=udt_set(self.api_client,'session_key',session_key);

    return;
}
;

create method validate_fb_params()
for DB.DBA.Facebook
{
  self.fb_params := self.get_valid_fb_params(self._params, 48*3600, 'fb_sig');
  if (self.fb_params is null)
  {
       self.fb_params := self.get_valid_fb_params(self._params, 48*3600, 'fb_sig');
    }

    declare _cookies,_session any;
    _cookies := self.get_valid_fb_params(_get_cookie_vec(self._lines), null, self.api_key);

  if ((self.fb_params is  null or length(self.fb_params)=0) and _cookies is not null)
    {
     self.fb_params:= _cookies;
    }
    if(get_keyword('auth_token',self._params,null) is not null)
       _session := self.do_get_session(get_keyword('auth_token',self._params)); --do_get_session sets self._user along the session
    else
       _session:=null;

  if (self.fb_params is not null)
  {
      -- If we got any fb_params passed in at all, then either:
      --  - they included an fb_user / fb_session_key, which we should assume to be correct
      --  - they didn't include an fb_user / fb_session_key, which means the user doesn't have a
      --    valid session and if we want to get one we'll need to use require_login().  (Calling
      --    set_user with null values for user/session_key will work properly.)
      -- Note that we should *not* use our cookies in this scenario, since they may be referring to
      -- the wrong user.
      declare session_key varchar;
      declare _user integer;
      declare expires datetime;


--      dbg_obj_print('self.fb_params',self.fb_params);

      _user       := coalesce( self._user,get_keyword('user',self.fb_params,null)); --if do_get_session have already succeeded to set _user no need to look for it in fb_params
      session_key := coalesce(_session,get_keyword('session_key',self.fb_params, ''));
      expires     := get_keyword('expires',self.fb_params, now());
      self.set_user(_user, session_key, expires);
  }
  else if (length(_cookies)>0)
    {
      -- use api_key . '_' as a prefix for the cookies in case there are
      -- multiple facebook clients on the same domain.
      self.set_user(get_keyword('user',_cookies ),get_keyword('session_key',_cookies ),now());
  }
  else if (length(get_keyword('auth_token',self._params,'')) and _session is not null)
  {
      self.set_user(self._user,_session, now());
    }
    if( self.fb_params is not null)
       return 1;

  return 0;
}
;

create method get_valid_fb_params(
       in params any,
       in timeout any := null,
       in namespace any := 'fb_sig'
)
for DB.DBA.Facebook
{
    declare prefix varchar;
    declare prefix_len integer;
    declare fb_params any;

    prefix := namespace || '_';
    prefix_len := length(prefix);
    fb_params := vector();

  declare i integer;
  for (i := 0; i < length (params); i := i + 2)
    {
      declare _key, _val varchar;

    if (isstring (params[i]))
    {
      _key := trim (cast(params[i] as varchar));
      if (position( prefix,_key) = 1 and prefix_len < length(_key))
      {
      _val := params[i+1];
      if (_val is not null)
          _val := trim (cast(_val as varchar));
         fb_params:=vector_concat(fb_params,vector(subseq(_key,prefix_len),_val));
      }
    }
    }

--    if (timeout is not null and
--        (get_keyword('time',fb_params) is null or now() - get_keyword('time',fb_params) > timeout)
--       ) {
--      return vector();
--    }

  if (get_keyword(namespace,params) is null OR self.verify_signature(fb_params, get_keyword(namespace,params))=0)
      return vector();

    if(length(fb_params)=0)
       return null;

       return fb_params;
}
;

create method verify_signature(
       in fb_params any,
       in expected_sig varchar
)
for DB.DBA.Facebook
{
    if (self.api_client.generate_sig(fb_params, self.secret) = expected_sig)
        return 1;

        return 0;
}
;

create method in_fb_canvas()
for DB.DBA.Facebook
{
  if(get_keyword('in_canvas',self.fb_params,'')<>'')
     return 1;

     return 0;
}
;

create method do_get_session(
       in auth_token any
)
for DB.DBA.Facebook
{
    declare auth_res any;

  declare exit handler for sqlstate '*'
  {
    if(self.api_client.debug_mode=1)
                                            {
                                               dbg_obj_print('--REST CLIENT ERR--');
                                               dbg_obj_print(__SQL_STATE);
                                               dbg_obj_print(__SQL_MESSAGE);
                                               dbg_obj_print('-------------------');
    }
                                            return null;
                                          };
    auth_res:=self.api_client.auth_getSession(auth_token);
    if(auth_res is not null)
    {
--      if( auth_res[1] is not null and auth_res[0] is not null and locate(cast(auth_res[1] as varchar),cast(auth_res[0] as varchar))>0)
      if( auth_res[1] is not null and auth_res[0] is not null)
      {

          self._user:=auth_res[1];
--          if(not locate(cast(auth_res[1] as varchar),cast(auth_res[0] as varchar))>0)
--          {
--            dbg_obj_print('2',self.api_client.auth_getSession(auth_token));
--            dbg_obj_print(auth_res[0]);
--            dbg_obj_print(split_and_decode(auth_res[0],0,'\0\0-')[0]||'-'||cast(auth_res[1] as varchar));
--            return split_and_decode(auth_res[0],0,'\0\0-')[0]||'-'||cast(auth_res[1] as varchar);
--            return split_and_decode(auth_res[0],0,'\0\0-')[0]||'-'||split_and_decode(auth_res[0],0,'\0\0-')[1];
--          }
          return auth_res[0];

      }
--      else self.redirect(self.get_login_url(self.current_url(), self.in_frame(),0)); --this action is due to facebook issue(facebook site generates invalid auth token in some cases)
    }
    return '';


}
;

create method redirect(
   in url varchar
)
for DB.DBA.Facebook
{
--    dbg_obj_print('redirect_url',url);
  if (self.in_fb_canvas())
  {
      http ('<fb:redirect url="' || url || '"/>');
  }
  else if (length(regexp_match('/^https?:\/\/([^\/]*\.)?facebook\.com(:\d+)?/i', url))>0)
  {
      -- make sure facebook.com url's load in the full frame so that we don't
      -- get a frame within a frame.
      http ('<script type=\"text/javascript\">\ntop.location.href = \"'||url||'\";\n</script>');
  }
  else
  {
      http_rewrite();
      http_request_status('HTTP/1.1 302');
      http_header (concat ('Location: ', url, '\r\n'));
    }

    return;
}
;

create method get_add_url(
  in _next varchar := null)
for DB.DBA.Facebook
{
    declare add_url varchar;

    add_url:=get_facebook_url()||'/add.php?api_key='||self.api_key;
    if(_next is not null)
       add_url:=add_url||'&next=' || sprintf('%U',_next);

    return add_url;
 }
;

create method get_login_url(
      in _next varchar :=null,
      in canvas integer :=0,
      in skipcookie integer :=0
)
for DB.DBA.Facebook
{
    declare login_url varchar;
    login_url:=get_facebook_url()||'/login.php?v=1.0&api_key=' || self.api_key ;
    if(_next is not null)
       login_url:=login_url||'&next=' || sprintf('%U',_next);
    if(canvas=1)
       login_url:=login_url||'&canvas';
    if(skipcookie=1)
       login_url:=login_url||'&skipcookie';

    return login_url;
}
;

create method require_login ( in relog integer :=0)
for DB.DBA.Facebook
{
    declare _user any;

    if(relog=1)
    {
      if(self._user > 0)
      {
         self._user:=0;
         self.api_client:=udt_set(self.api_client,'session_key','');
      }
      self.redirect(self.get_login_url(self.current_url(), self.in_frame(),1));
    }
    _user:=self.get_loggedin_user();
    if(_user is not null)
       return _user;

    self.redirect(self.get_login_url(self.current_url(), self.in_frame(),0));
    return;
  }
;

create method in_frame()
for DB.DBA.Facebook
{
  if (get_keyword('in_canvas',self.fb_params,null) is not null and
       get_keyword('in_iframe',self.fb_params,null) is not null)
    return 1;
    return 0;
}
;

create method get_loggedin_user()
for DB.DBA.Facebook
{
    return self._user;
}
;

create method current_url()
for DB.DBA.Facebook
{
    declare _sid,_realm,_http_query_str varchar;
    _sid   :=get_keyword('sid',self._params,null);
    _realm := get_keyword('realm',self._params,null);
    _http_query_str := get_keyword('_http_query_str',self._params,null);


    if(_http_query_str is not null and length(_http_query_str)>0)
    {
--      return 'http://' || http_request_header(self._lines,'Host') || http_path()||'?'||_http_query_str;
      return '?'||_http_query_str;
  }
  else if(_sid is not null and length(_sid)>0)
    {
--      return 'http://' || http_request_header(self._lines,'Host') || http_path()||'?sid='||_sid||'&realm='||coalesce(_realm,'wa');
      return '?sid='||_sid||'&realm='||coalesce(_realm,'wa');
    }

--    return 'http://' || http_request_header(self._lines,'Host') || http_path();

    return '';

}
;
-- END Facebook type


create procedure get_facebook_url(in subdomain varchar := 'www')
{
    return 'http://' ||subdomain ||'.facebook.com';

}
;

create procedure _get_cookie_vec (in lines any)
{
  declare cookie_vec any;
  declare i,l int;
  declare cookie_str varchar;
  cookie_str := http_request_header (lines, 'Cookie');
  if (not isstring (cookie_str))
    return vector ();
  cookie_vec := split_and_decode (cookie_str, 0, '\0\0;=');
  i := 0;
  l := length (cookie_vec);
  while (i < l)
    {
      declare _key, _val varchar;
      _key := trim (cast(cookie_vec[i] as varchar));
      _val := cookie_vec[i+1];
      if (_val is not null)
          _val := trim (cast(_val as varchar));
      aset (cookie_vec, i, _key);
      aset (cookie_vec, i + 1, _val);
      i := i + 2;
    }
  return cookie_vec;
}
;

create procedure _get_ods_fb_settings (
  out fb_settings any)
{
   fb_settings := null;
  for (select a_key, a_secret from OAUTH.DBA.APP_REG where a_owner = 0 and a_name = 'Facebook API') do
   {
    fb_settings := vector (a_key, a_secret);
      return 1;
   }
   return 0;
}
;

create procedure valid_abid_by_fbid (
                 in logged_odsuser_id integer,
                 inout fbf_data any,
                 in ab_domain_id integer,
  in validation_arr any := null)
{
    declare valid_id_arr any;
    valid_id_arr:=null;

    declare exit handler for not found{valid_id_arr:=null;};
    declare qry,state, msg, maxrows, metas, rset any;

    rset := null;
    maxrows := 0;
    state := '00000';
    msg := '';

    declare validate_by_fields any;

    if(validation_arr is null)
       validate_by_fields := coalesce ((select deserialize (LV_FIELDS) from LDAP..LDAP_VALIDATION where LV_USER_ID = logged_odsuser_id), vector());
    else
      validate_by_fields:=validation_arr;

    declare full_name,first_name,last_name varchar;
    full_name  := trim(xpath_eval('string(name)',fbf_data));
    first_name := trim(xpath_eval('string(first_name)',fbf_data));
    last_name  := trim(xpath_eval('string(last_name)',fbf_data));

    declare validation_sql varchar;
    declare k integer;


    validation_sql:='';
    if (validate_by_fields is not null and length (validate_by_fields))
    {
      for (k := 0; k < length (validate_by_fields); k := k + 2)
      {
        declare _key varchar;
        declare _val,_tmpval any;

        _key:=validate_by_fields[k];
        _val:=validate_by_fields[k+1];
        if(_val is not null and (_val=1 or _val='1'))
        {
          if(_key='P_FULL_NAME' and length(full_name)>0 )
             validation_sql:=validation_sql||sprintf(' AND P_FULL_NAME=''%s'' ',full_name);
          if(_key='P_FIRST_NAME' and length(first_name)>0 )
             validation_sql:=validation_sql||sprintf(' AND P_FIRST_NAME=''%s'' ',first_name);
          if(_key='P_MIDDLE_NAME' and length(last_name)>0 )
             validation_sql:=validation_sql||sprintf(' AND (P_LAST_NAME=''%s'' OR P_MIDDLE_NAME=''%s'') ',last_name,last_name);
          if(_key='P_LAST_NAME'  and length(last_name)>0 )
             validation_sql:=validation_sql||sprintf(' AND P_LAST_NAME=''%s'' ',last_name);

          _tmpval:=trim(xpath_eval('string(sex)',fbf_data));
          if(_key='P_GENDER' and _tmpval<>'')
             validation_sql:=validation_sql||sprintf(' AND P_GENDER=''%s'' ',_tmpval);

          _tmpval:=trim(xpath_eval('string(hometown_location/city)',fbf_data));
          if(_key='P_H_CITY'  and _tmpval<>'')
             validation_sql:=validation_sql||sprintf(' AND P_H_CITY=''%s'' ',_tmpval);

          _tmpval:=trim(xpath_eval('string(hometown_location/state)',fbf_data));
          if(_key='P_H_STATE'  and _tmpval<>'')
             validation_sql:=validation_sql||sprintf(' AND P_H_STATE=''%s'' ',_tmpval);

          _tmpval:=trim(xpath_eval('string(hometown_location/country)',fbf_data));
          if(_key='P_H_COUNTRY'  and _tmpval<>'')
             validation_sql:=validation_sql||sprintf(' AND P_H_COUNTRY=''%s'' ',_tmpval);
          _tmpval:=trim(xpath_eval('string(hometown_location/zip)',fbf_data));
          if(_key='P_H_CODE'  and _tmpval<>'')
             validation_sql:=validation_sql||sprintf(' AND P_H_CODE=''%s'' ',_tmpval);

          _tmpval:=trim(xpath_eval('string(work_history/work_info[1]/location/city)',fbf_data));
          if(_key='P_B_CITY'  and _tmpval<>'')
             validation_sql:=validation_sql||sprintf(' AND P_B_CITY=''%s'' ',_tmpval);

          _tmpval:=trim(xpath_eval('string(work_history/work_info[1]/location/state)',fbf_data));
          if(_key='P_B_STATE'  and _tmpval<>'')
             validation_sql:=validation_sql||sprintf(' AND P_B_STATE=''%s'' ',_tmpval);

          _tmpval:=trim(xpath_eval('string(work_history/work_info[1]/location/country)',fbf_data));
          if(_key='P_B_COUNTRY'  and _tmpval<>'')
             validation_sql:=validation_sql||sprintf(' AND P_B_COUNTRY=''%s'' ',_tmpval);

          _tmpval:=trim(xpath_eval('string(work_history/work_info[1]/company_name)',fbf_data));
          if(_key='P_B_ORGANIZATION'  and _tmpval<>'')
             validation_sql:=validation_sql||sprintf(' AND P_B_ORGANIZATION=''%s'' ',_tmpval);

          _tmpval:=trim(xpath_eval('string(work_history/work_info[1]/position)',fbf_data));
          if(_key='P_B_JOB'  and _tmpval<>'')
             validation_sql:=validation_sql||sprintf(' AND P_B_JOB=''%s'' ',_tmpval);

          _tmpval:=cast(trim(xpath_eval('string(birthday)',fbf_data)) as varchar);
          if(_key='P_BIRTHDAY' and _tmpval<>'')
          {
             declare _date_str varchar;
             declare _arr any;

             _arr:=split_and_decode(_tmpval,0,'\0\0,');
             if(_arr is not null and length(_arr)>0)
             {
                _arr[0]:=split_and_decode(_arr[0],0,'\0\0 ');

             if(length(_arr)=1)
                _date_str:=sprintf('stringdate(''1970-%d-%s'')',_get_monhtbyname(trim(_arr[0][0])),trim(_arr[0][1]));
             else
                _date_str:=sprintf('stringdate(''%s-%d-%s'')',trim(_arr[1]),_get_monhtbyname(trim(_arr[0][0])),trim(_arr[0][1]));


             if(_date_str is not null and length(_date_str)>0)
               validation_sql:=validation_sql||sprintf(' AND P_BIRTHDAY=%s ',_date_str);
             }
          }

        }

      }

   }

    if(validation_sql is null or validation_sql='')
    {
       qry:=sprintf('select P_ID from AB.WA.PERSONS '||
                    'where P_DOMAIN_ID=%d '||
                    '   and (   (P_LAST_NAME=''%s'' and (P_MIDDLE_NAME=''%s'' or P_FIRST_NAME=''%s'')) '||
                    '       or (P_FULL_NAME=''%s'') '||
                    '       or (concat(trim(P_FIRST_NAME),'' '',trim(P_LAST_NAME))=''%s'') '||
                    '       or (concat(trim(P_MIDDLE_NAME),'' '',trim(P_LAST_NAME))=''%s'') )',
                    ab_domain_id,last_name,first_name,first_name,full_name,full_name,full_name);
  } else {
    qry:=sprintf('select P_ID from AB.WA.PERSONS where P_DOMAIN_ID=%d %s', ab_domain_id, validation_sql);
    }
    exec (qry, state, msg, vector(), maxrows, metas, rset);
    if (state = '00000' and length(rset)>0)
    {
       declare idx integer;
       for(idx:=0;idx<length(rset);idx:=idx+1)
          valid_id_arr:=vector_concat(valid_id_arr,vector(rset[idx][0]));
    }
    return valid_id_arr;
}
;

create procedure sync_fbf_value (
  in colPath varchar,
  in colName varchar,
  inout _xml any,
  inout _col any,
  inout _val any)
{
  declare tmp any;

  tmp := serialize_to_UTF8_xml (xpath_eval (sprintf ('string(%s)', colPath), _xml));
  if (tmp <> '')
  {
    _col := vector_concat(_col, vector (colName));
    _val := vector_concat(_val, vector (tmp));
  }
  return tmp;
}
;

create procedure sync_fbf_odsab (
                 in fb_obj DB.DBA.Facebook,
                 in ods_uid integer,
                 in fb_user integer,
                 in _update_odsab integer :=0,
                 in _ischeck integer :=0 )
{
--_res_stat[0]
-- 1 all fbu in odsab
-- 0 fbu diff to odsab
-- -1 no ods addressbook instance
-- -2 fb_client error
--_res_stat[1] - new contacts count
--_res_stat[2] - updated contacts count
--_res_stat[3] - total fb friends count
--_res_stat[4] - addressbook id if exists

  declare i integer;
  declare _res any;
declare _res_stat any;
declare ab_domain_id integer;

  _res_stat := vector(0,0,0,0,0);
  declare exit handler for not found
{
    ab_domain_id := 0;
    goto _no_address_book;
  };
   select top 1 B.WAI_ID into ab_domain_id from WA_MEMBER A, WA_INSTANCE B where A.WAM_MEMBER_TYPE = 1 and A.WAM_INST = B.WAI_NAME and A.WAM_APP_TYPE='AddressBook' and A.WAM_USER=ods_uid ;

_no_address_book:;

  if(ab_domain_id=0)
  {
    _res_stat[0] := -1;
    return _res_stat;
  }
  _res_stat[4]:=ab_domain_id;
  _res:=fb_obj.api_client.friends_get();

  if(isarray(_res) and length(_res)>0)
  {
    declare ff_ids varchar;

    ff_ids:='';
    for (i := 0; i < length(_res); i := i + 1)
    {
     if(i<(length(_res)-1))
        ff_ids:=ff_ids||_res[i]||',';
     else
        ff_ids:=ff_ids||_res[i];
    }
    _res:=fb_obj.api_client.users_getInfo(ff_ids,'name,first_name,last_name,sex,birthday,current_location,work_history,hometown_location,timezone');
  } else {
    _res_stat[0]:=-2;
  }

  if(_res is not null)
  {
    _res:=xpath_eval('/users_getInfo_response/user',_res,0);
    if(_res is not null and length(_res)>0)
    {
      for (i := 0; i < length(_res); i := i + 1)
      {
        declare _p_id integer;
          declare valid_abid_arr any;

          _p_id:=-1;
        valid_abid_arr := valid_abid_by_fbid(ods_uid, _res[i], ab_domain_id);
          if(valid_abid_arr is not null)
          _p_id:=valid_abid_arr[0];

          if (_ischeck=1)
          {
            if(_p_id=-1)
               _res_stat[1]:=_res_stat[1]+1;
            else
               _res_stat[2]:=_res_stat[2]+1;

            goto _skip_parseandupdate;
          }

          declare _col, _val any;
          declare _tmpval varchar;
        declare full_name, first_name, last_name varchar;

          _col    :=vector();
          _val    :=vector();

          _tmpval:=trim(xpath_eval('string(birthday)',_res[i]));
          if(_tmpval<>'')
          {
             declare _date date;
             declare _arr any;

             _arr:=split_and_decode(cast(_tmpval as varchar),0,'\0\0,');
             if(_arr is not null and length(_arr)>0)
                _arr[0]:=split_and_decode(_arr[0],0,'\0\0 ');
             if(length(_arr)=1)
                _date:=stringdate('1970-'||cast(_get_monhtbyname(trim(_arr[0][0])) as varchar)||'-'||trim(_arr[0][1]));
             else
                _date:=stringdate(trim(_arr[1])||'-'||cast(_get_monhtbyname(trim(_arr[0][0])) as varchar)||'-'||trim(_arr[0][1]));

          _col := vector_concat(_col, vector('P_BIRTHDAY'));
             _val:=vector_concat(_val,vector(_date));
          }
        full_name  := sync_fbf_value ('name', 'P_FULL_NAME', _res[i], _col, _val);
        first_name := sync_fbf_value ('first_name', 'P_FIRST_NAME', _res[i], _col, _val);
        last_name  := sync_fbf_value ('last_name', 'P_LAST_NAME', _res[i], _col, _val);
        sync_fbf_value ('sex', 'P_GENDER', _res[i], _col, _val);
        sync_fbf_value ('hometown_location/city', 'P_H_CITY', _res[i], _col, _val);
        sync_fbf_value ('hometown_location/state', 'P_H_STATE', _res[i], _col, _val);
        sync_fbf_value ('hometown_location/country', 'P_H_COUNTRY', _res[i], _col, _val);
        sync_fbf_value ('hometown_location/zip', 'P_H_CODE', _res[i], _col, _val);
        sync_fbf_value ('work_history/work_info[1]/location/city', 'P_B_CITY', _res[i], _col, _val);
        sync_fbf_value ('work_history/work_info[1]/location/state', 'P_B_STATE', _res[i], _col, _val);
        sync_fbf_value ('work_history/work_info[1]/location/country', 'P_B_COUNTRY', _res[i], _col, _val);
        sync_fbf_value ('work_history/work_info[1]/company_name', 'P_B_ORGANIZATION', _res[i], _col, _val);
        sync_fbf_value ('work_history/work_info[1]/position', 'P_B_JOB', _res[i], _col, _val);
          if(trim(coalesce(full_name,first_name||' '||last_name))<>'')
          {
            if(_p_id=-1)
            {
               declare _np_id integer;

            _np_id := AB.WA.contact_update2 (_p_id, ab_domain_id, 'P_NAME', full_name);
               if(_np_id>-1)
               {
                  AB.WA.contact_update3 (_np_id,ab_domain_id,_col,_val,'');
                 _res_stat[1]:=_res_stat[1]+1;
               }
            }

            if(_p_id<>-1 and _update_odsab=1)
            {
               AB.WA.contact_update3 (_p_id,ab_domain_id,_col,_val,'');
               _res_stat[2]:=_res_stat[2]+1;
            }
        }
_skip_parseandupdate:;
      }
    }
  }


_res_stat[3]:=i;

if(_res_stat[1]=0)
   _res_stat[0]:=1;

return _res_stat;
}
;

create procedure _get_monhtbyname(in monthname varchar)
{
  declare months_arr any;
  months_arr:=vector('January','February','March','April','May','June','July','August','September','October','November','December');

  return position(monthname, months_arr);

}
;


create procedure get_syncdata_arr (
                 in fb_obj DB.DBA.Facebook,
                 in ods_uid integer,
                 in simple integer :=0
)
{
  declare i, k integer;
declare ab_domain_id integer;
  declare _res any;
  declare _res_str varchar;

  ab_domain_id := (select top 1 B.WAI_ID from WA_MEMBER A, WA_INSTANCE B where A.WAM_MEMBER_TYPE = 1 and A.WAM_INST = B.WAI_NAME and A.WAM_APP_TYPE='AddressBook' and A.WAM_USER=ods_uid);
  if (isnull (ab_domain_id))
    return 'No addressbook instance';

  _res_str := string_output();
  _res:=fb_obj.api_client.friends_get();
  if (not (isarray(_res) and length(_res) > 0))
    return 'REST API error';

    declare ff_ids varchar;

    ff_ids:='';
  for (i := 0; i<length(_res); i:=i+1)
    {
     if(i<(length(_res)-1))
        ff_ids:=ff_ids||_res[i]||',';
     else
        ff_ids:=ff_ids||_res[i];
    }
    _res:=fb_obj.api_client.users_getInfo(ff_ids,'name,first_name,last_name,sex,birthday,current_location,work_history,hometown_location,timezone');

  if(_res is not null)
  {
     http ('new Array(', _res_str);
    _res:=xpath_eval('/users_getInfo_response/user',_res,0);
    if(_res is not null and length(_res)>0)
    {
      for (i := 0; i < length(_res); i := i + 1)
      {
        declare uid,full_name,first_name,last_name varchar;
        uid        := serialize_to_UTF8_xml (xpath_eval('string(uid)',_res[i]));
        full_name  := serialize_to_UTF8_xml (xpath_eval('string(name)',_res[i]));
        first_name := serialize_to_UTF8_xml (xpath_eval('string(first_name)',_res[i]));
        last_name  := serialize_to_UTF8_xml (xpath_eval('string(last_name)',_res[i]));

          declare addressbook_cid_arr any;
          declare addressbook_cid_sqlstr varchar;
          addressbook_cid_sqlstr:='';

          addressbook_cid_arr:=valid_abid_by_fbid(ods_uid,_res[i],ab_domain_id);

--          dbg_obj_print(addressbook_cid_arr);
          if(addressbook_cid_arr is not null and length(addressbook_cid_arr)>0)
            {
          if (length(addressbook_cid_arr) = 1)
          {
            addressbook_cid_sqlstr := sprintf(' = %d',addressbook_cid_arr[0]);
          } else {
              declare m integer;
              declare _tmp_str varchar;

            _tmp_str := '';
              for(m:=0; m<length(addressbook_cid_arr); m:=m+1)
              {
                  if(m=0)
                     _tmp_str:=sprintf('%d',addressbook_cid_arr[m]);
                  else
                     _tmp_str:=sprintf('%s,%d',_tmp_str,addressbook_cid_arr[m]);
              }
                addressbook_cid_sqlstr:=sprintf(' in  (%s)',_tmp_str);
            }
          }

        declare qry, state, msg, metas, rset any;

          state := '00000';
          if(addressbook_cid_sqlstr='')
          {
          qry := sprintf('select top 1 -1, ''New contact'', P_DOMAIN_ID, -1 from AB.WA.PERSONS where P_DOMAIN_ID=%d ',
                       ab_domain_id);
        } else {
          qry := sprintf('select P_ID, P_NAME, P_DOMAIN_ID, P_ID from AB.WA.PERSONS where P_DOMAIN_ID=%d and P_ID%s',
                       ab_domain_id,addressbook_cid_sqlstr);
        }
        exec (qry, state, msg, vector(), 0, metas, rset);
          if (state = '00000' and length(rset)>0)
          {
          if (i > 0)
            http ('\r\n,', _res_str);
            if(simple=1)
            http ('{fb_id:'||cast(uid as varchar)||',', _res_str);
            else
            http ('{_name:"'||full_name||'",fb_id:'||cast(uid as varchar)||',fb_href:"http://www.facebook.com/profile.php?id='||cast(uid as varchar)||'",odsab_instid:'||cast(ab_domain_id as varchar)||',ods_contacts:new Array(', _res_str);

            k:=0;
            if(simple)
            {
             http ('ods_cid:'||cast(rset[k][0] as varchar)||'}', _res_str);
          } else {
            for (k := 0; k < length(rset); k := k + 1)
             {
	             http ('{ods_cid:'||cast(rset[k][0] as varchar)||',ods_name:"'||cast(rset[k][1] as varchar)||'",ods_href:"'||sprintf('/dataspace/%U/addressbook/%U/%d',WA_APP_GET_OWNER(rset[k][2]),replace (AB.WA.domain_name (rset[k][2]), '+', '%2B'),rset[k][3])||'"}', _res_str);
	             if(k < length(rset)-1)
	                http (',', _res_str);
	           }
             http (')}', _res_str);
            }
	        }
        }
    }
   http (')', _res_str);
  }
return string_output_string(_res_str);
}
;

create procedure DB.DBA.fbf_rdf_load_fql (
                 in graph_iri varchar,
                 in new_origin_uri varchar,
                 in dest varchar,
                 in fb_obj DB.DBA.Facebook,
                 in fb_uid varchar,
                 in isLogged integer)
{
  declare ret, xt, xd any;
  declare url,  q, own  varchar;

  SPARQL CLEAR GRAPH <graph_iri>;

  own := fb_uid;
  q :=  sprintf ('SELECT uid, first_name, last_name, name, pic_small, pic_big, pic_square, pic, affiliations, profile_update_time, timezone, religion, birthday, sex, hometown_location, meeting_sex, meeting_for, relationship_status, significant_other_id, political, current_location, activities, interests, is_app_user, music, tv, movies, books, quotes, about_me, hs_info, education_history, work_history, notes_count, wall_count, status, has_added_app FROM user WHERE uid = %s', own);
    ret := fb_obj.api_client.fql_query(q);
  if(ret is not null)
  {
   xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/fql2rdf.xsl', ret, vector ('baseUri', coalesce (dest, graph_iri)));
   xd := serialize_to_UTF8_xml (xt);
   DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  }
  q := sprintf ('SELECT aid, cover_pid, owner, name, created, modified, description, location, size, link FROM album WHERE owner = %s', own);
  ret := fb_obj.api_client.fql_query(q);
  if(ret is not null)
  {
    xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/fql2rdf.xsl', ret, vector ('baseUri', coalesce (dest, graph_iri)));
    xd := serialize_to_UTF8_xml (xt);
    DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  }
  q := sprintf ('select eid, name, tagline, nid, pic_small, pic_big, pic, host, description, event_type, event_subtype, '||
                ' start_time, end_time, creator, update_time, location, venue from event where eid in '||
                '(SELECT eid FROM event_member where uid = %s)', own);
  ret := fb_obj.api_client.fql_query(q);
  if(ret is not null)
  {
    xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/fql2rdf.xsl', ret, vector ('baseUri', coalesce (dest, graph_iri)));
    xd := serialize_to_UTF8_xml (xt);
    DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  }

  if(isLogged)
  {
     q := sprintf ('select uid2 from friend where uid1 = %s', own);
     ret := fb_obj.api_client.fql_query(q);
     if(ret is not null)
     {
        xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/fql2rdf.xsl', ret, vector ('baseUri', coalesce (dest, graph_iri)));
        xd := serialize_to_UTF8_xml (xt);
        DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
    }
     q := sprintf ('SELECT uid, first_name, last_name, name, pic_small, pic_big, pic_square, pic, profile_update_time, timezone, religion, birthday, sex, current_location FROM user WHERE uid IN (select uid2 from friend where uid1 = %s)', own);
     ret := fb_obj.api_client.fql_query(q);
     if(ret is not null)
     {
        xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/fql2rdf.xsl', ret, vector ('baseUri', coalesce (dest, graph_iri)));
        xd := serialize_to_UTF8_xml (xt);
        DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
    }
  }
  return 1;
}
;
