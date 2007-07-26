--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2006 OpenLink Software
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
USE DB;

--delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (JSO_SYS_GRAPH());
--DB.DBA.SPARQL_RELOAD_QM_GRAPH ();

sparql drop quad map virtrdf:ODS_DS . ;

sparql prefix ods: <http://www.openlinksw.com/virtuoso/ods/>
       create iri class ods:graph "http://^{URIQADefaultHost}^/dataspace/%U" (in uname varchar not null)
			    option (returns "http://^{URIQADefaultHost}^/dataspace/%U") .
       create iri class ods:user "http://^{URIQADefaultHost}^/dataspace/%U#user" (in uname varchar not null)
			    option (returns "http://^{URIQADefaultHost}^/dataspace/%U#user") .
       create iri class ods:user_group "http://^{URIQADefaultHost}^/dataspace/%U#group" (in uname varchar not null)
			    option (returns "http://^{URIQADefaultHost}^/dataspace/%U#group") .
       create iri class ods:person "http://^{URIQADefaultHost}^/dataspace/%U#this" (in uname varchar not null)
			    option (returns "http://^{URIQADefaultHost}^/dataspace/%U#this") .
       create iri class ods:mbox "mailto:%s" (in email varchar not null)
			    option (returns "mailto:%s") .
       create iri class ods:phone "tel:%s" (in tel varchar not null)
       			    option (returns "tel:%s") .
       create iri class ods:geo_point "http://^{URIQADefaultHost}^/dataspace/%U#geo" (in uname varchar not null)
       			    option (returns "http://^{URIQADefaultHost}^/dataspace/%U#geo") .
       create iri class ods:forum "http://^{URIQADefaultHost}^/dataspace/%U/%U/%U"
	     ( in uname varchar not null, in forum_type varchar not null, in forum_name varchar not null)
	    		    option (returns "http://^{URIQADefaultHost}^/dataspace/%U/%U/%U") .
       create iri class ods:proxy "http://^{URIQADefaultHost}^/proxy/%U" (in url varchar not null)
       			    option (returns  "http://^{URIQADefaultHost}^/proxy/%U") .
       create iri class ods:site "http://^{URIQADefaultHost}^/dataspace/%U#site" (in uname varchar not null)
       			    option (returns "http://^{URIQADefaultHost}^/dataspace/%U#site") .
       create iri class ods:role "http://^{URIQADefaultHost}^/dataspace/%U/%U/%U#%U"
	     ( in uname varchar not null, in tp varchar not null, in inst varchar not null, in role_name varchar not null)
			    option (returns  "http://^{URIQADefaultHost}^/dataspace/%U/%U/%U#%U" ) .
     	 create iri class ods:tag "http://^{URIQADefaultHost}^/dataspace/%U/concept#%U"
		   ( in uname varchar not null, in tag varchar not null)
          option (returns  "http://^{URIQADefaultHost}^/dataspace/%U/concept#%U") .
	# Blog
	create iri class ods:blog_forum "http://^{URIQADefaultHost}^/dataspace/%U/weblog/%U"
		(in uname varchar not null, in forum_name varchar not null)
		option (returns "http://^{URIQADefaultHost}^/dataspace/%U/weblog/%U") .
	create iri class ods:blog_post "http://^{URIQADefaultHost}^/dataspace/%U/weblog/%U/%U"
		(in uname varchar not null, in forum_name varchar not null, in postid varchar not null)
		option (returns "http://^{URIQADefaultHost}^/dataspace/%U/weblog/%U/%U" ) .
	create iri class ods:blog_comment "http://^{URIQADefaultHost}^/dataspace/%U/weblog/%U/%U/%d"
		(in uname varchar not null, in forum_name varchar not null, in postid varchar not null, in comment_id int not null)
 	  option (returns  "http://^{URIQADefaultHost}^/dataspace/%U/weblog/%U/%U/%d" ) .
	create iri class ods:blog_post_text "http://^{URIQADefaultHost}^/dataspace/%U/weblog-text/%U/%U"
		(in uname varchar not null, in forum_name varchar not null, in postid varchar not null)
		option (returns "http://^{URIQADefaultHost}^/dataspace/%U/weblog-text/%U/%U" ) .
	# Feeds
	create iri class ods:feed "http://^{URIQADefaultHost}^/dataspace/feed/%d" (in feed_id integer not null)
          	option (returns "http://^{URIQADefaultHost}^/dataspace/feed/%d" ) .
	create iri class ods:feed_item "http://^{URIQADefaultHost}^/dataspace/feed/%d/%d" (in feed_id integer not null, in item_id integer not null)
	 	option (returns  "http://^{URIQADefaultHost}^/dataspace/feed/%d/%d" ) .
	create iri class ods:feed_item_text "http://^{URIQADefaultHost}^/dataspace/feed/%d/%d/text" (in feed_id integer not null, in item_id integer not null)
		option (returns  "http://^{URIQADefaultHost}^/dataspace/feed/%d/%d/text" ) .
	create iri class ods:feed_mgr "http://^{URIQADefaultHost}^/dataspace/%U/feeds/%U" (in uname varchar not null, in inst_name varchar not null)
		option (returns "http://^{URIQADefaultHost}^/dataspace/%U/feeds/%U" ) .
	create iri class ods:feed_comment "http://^{URIQADefaultHost}^/dataspace/%U/feeds/%U/%d/%d"
		(in uname varchar not null, in inst_name varchar not null, in item_id integer not null, in comment_id integer not null)
		option (returns "http://^{URIQADefaultHost}^/dataspace/%U/feeds/%U/%d/%d" ) .
	# Bookmark
	create iri class ods:bmk_post "http://^{URIQADefaultHost}^/dataspace/%U/bookmark/%U/%d"
		(in uname varchar not null, in inst_name varchar not null, in bmk_id integer not null)
		option (returns "http://^{URIQADefaultHost}^/dataspace/%U/bookmark/%U/%d") .
	create iri class ods:bmk_post_text "http://^{URIQADefaultHost}^/dataspace/%U/bookmark/%U/%d/text"
		(in uname varchar not null, in inst_name varchar not null, in bmk_id integer not null)
		option (returns "http://^{URIQADefaultHost}^/dataspace/%U/bookmark/%U/%d/text" ) .
	create iri class ods:bmk_forum "http://^{URIQADefaultHost}^/dataspace/%U/bookmark/%U"
		( in uname varchar not null, in forum_name varchar not null)
		option (returns "http://^{URIQADefaultHost}^/dataspace/%U/bookmark/%U") .
	# Photo
	create iri class ods:photo_forum "http://^{URIQADefaultHost}^/dataspace/%U/photos/%U"
		(in uname varchar not null, in inst_name varchar not null)
		option (returns  "http://^{URIQADefaultHost}^/dataspace/%U/photos/%U") .
	create iri class ods:photo_post "http://^{URIQADefaultHost}^%s"
		(in path varchar not null) option (returns "http://^{URIQADefaultHost}^/DAV/%s") .
	create iri class ods:photo_post_text "http://^{URIQADefaultHost}^%s/text"
		(in path varchar not null) option (returns "http://^{URIQADefaultHost}^/DAV/%s/text") .
	create iri class ods:photo_comment "http://^{URIQADefaultHost}^%s:comment_%d"
		(in path varchar not null, in comment_id int not null)
		option (returns "http://^{URIQADefaultHost}^/DAV/%s:comment_%d") .
  # Polls
  create iri class ods:polls_forum "http://^{URIQADefaultHost}^/dataspace/%U/polls/%U"
    ( in uname varchar not null, in forum_name varchar not null) .
  create iri class ods:polls_post "http://^{URIQADefaultHost}^/dataspace/%U/polls/%U/%d"
    (in uname varchar not null, in inst_name varchar not null, in poll_id integer not null) .
  create iri class ods:polls_post_text "http://^{URIQADefaultHost}^/dataspace/%U/polls/%U/%d/text"
    (in uname varchar not null, in inst_name varchar not null, in poll_id integer not null) .
  # AddressBook
  create iri class ods:addressbook_contact "http://^{URIQADefaultHost}^/dataspace/%U/addressbook/%U/%d"
    (in uname varchar not null, in inst_name varchar not null, in contact_id integer not null) .
  create iri class ods:addressbook_contact_text "http://^{URIQADefaultHost}^/dataspace/%U/addressbook/%U/%d/text"
    (in uname varchar not null, in inst_name varchar not null, in contact_id integer not null) .
  create iri class ods:addressbook_forum "http://^{URIQADefaultHost}^/dataspace/%U/addressbook/%U"
    ( in uname varchar not null, in forum_name varchar not null) .
	# Community
	create iri class ods:community_forum "http://^{URIQADefaultHost}^/dataspace/%U/community/%U"
		(in uname varchar not null, in forum_name varchar not null)
		option (returns  "http://^{URIQADefaultHost}^/dataspace/%U/community/%U") .
	# Briefcase
	create iri class ods:odrive_forum "http://^{URIQADefaultHost}^/dataspace/%U/briefcase/%U"
		(in uname varchar not null, in inst_name varchar not null)
		option (returns "http://^{URIQADefaultHost}^/dataspace/%U/briefcase/%U" ) .
	create iri class ods:odrive_post "http://^{URIQADefaultHost}^%s"
		(in path varchar not null) option (returns "http://^{URIQADefaultHost}^/DAV/%s") .
	create iri class ods:odrive_post_text "http://^{URIQADefaultHost}^%s/text"
		(in path varchar not null) option (returns "http://^{URIQADefaultHost}^/DAV/%s/text") .
	# Wiki
	create iri class ods:wiki_post "http://^{URIQADefaultHost}^/dataspace/%U/wiki/%U/%U"
		(in uname varchar not null, in inst_name varchar not null, in topic_id varchar not null)
		option (returns "http://^{URIQADefaultHost}^/dataspace/%U/wiki/%U/%U") .
	create iri class ods:wiki_post_text "http://^{URIQADefaultHost}^/dataspace/%U/wiki/%U/%U/text"
		(in uname varchar not null, in inst_name varchar not null, in topic_id varchar not null)
		option (returns "http://^{URIQADefaultHost}^/dataspace/%U/wiki/%U/%U/text" ) .
	create iri class ods:wiki_forum "http://^{URIQADefaultHost}^/dataspace/%U/wiki/%U"
		( in uname varchar not null, in forum_name varchar not null)
		option (returns  "http://^{URIQADefaultHost}^/dataspace/%U/wiki/%U" ) .
	# Calendar
	create iri class ods:calendar_event "http://^{URIQADefaultHost}^/dataspace/%U/calendar/%U/%d"
		(in uname varchar not null, in inst_name varchar not null, in calendar_id integer not null)
		option (returns "http://^{URIQADefaultHost}^/dataspace/%U/calendar/%U/%d" ) .
	create iri class ods:calendar_event_text "http://^{URIQADefaultHost}^/dataspace/%U/calendar/%U/%d/text"
		(in uname varchar not null, in inst_name varchar not null, in calendar_id integer not null)
		option (returns "http://^{URIQADefaultHost}^/dataspace/%U/calendar/%U/%d/text" ) .
	create iri class ods:calendar_forum "http://^{URIQADefaultHost}^/dataspace/%U/calendar/%U"
		( in uname varchar not null, in forum_name varchar not null)
		option (returns  "http://^{URIQADefaultHost}^/dataspace/%U/calendar/%U") .
	# NNTPF
	create iri class ods:nntp_forum "http://^{URIQADefaultHost}^/dataspace/discussion/%U"
		( in forum_name varchar not null)
		option (returns "http://^{URIQADefaultHost}^/dataspace/discussion/%U").
	create iri class ods:nntp_post "http://^{URIQADefaultHost}^/dataspace/discussion/%U/%U"
		( in group_name varchar not null, in message_id varchar not null)
		option (returns  "http://^{URIQADefaultHost}^/dataspace/discussion/%U/%U" ) .
	create iri class ods:nntp_post_text "http://^{URIQADefaultHost}^/dataspace/discussion/%U/%U/text"
		( in group_name varchar not null, in message_id varchar not null)
		option (returns  "http://^{URIQADefaultHost}^/dataspace/discussion/%U/%U/text") .
	create iri class ods:nntp_role "http://^{URIQADefaultHost}^/dataspace/discussion/%U#reader"
		(in forum_name varchar not null)
		option (returns "http://^{URIQADefaultHost}^/dataspace/discussion/%U#reader") .
       ;


sparql
    prefix sioc: <http://rdfs.org/sioc/ns#>
    prefix sioct: <http://rdfs.org/sioc/types#>
    prefix atom: <http://atomowl.org/ontologies/atomrdf#>
    prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    prefix foaf: <http://xmlns.com/foaf/0.1/>
    prefix dc: <http://purl.org/dc/elements/1.1/>
    prefix dct: <http://purl.org/dc/terms/>
    prefix skos: <http://www.w3.org/2004/02/skos/core#>
    prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
    prefix bm: <http://www.w3.org/2002/01/bookmark#>
    prefix exif: <http://www.w3.org/2003/12/exif/ns/>
    prefix ann: <http://www.w3.org/2000/10/annotation-ns#>
    prefix wikiont: <http://sw.deri.org/2005/04/wikipedia/wikiont.owl#>
    prefix calendar: <http://www.w3.org/2002/12/cal#>
    prefix ods: <http://www.openlinksw.com/virtuoso/ods/>

    alter quad storage virtrdf:DefaultQuadStorage
      from DB.DBA.SIOC_USERS as users
      from DB.DBA.SIOC_ODS_FORUMS as forums
      from DB.DBA.SIOC_ROLES as roles
      from DB.DBA.SIOC_ROLE_GRANTS as grants
      from DB.DBA.SIOC_KNOWS as knows
      from DB.DBA.ODS_FOAF_PERSON as person
      where (^{person.}^.U_NAME = ^{users.}^.U_NAME)
      where (^{forums.}^.U_NAME = ^{users.}^.U_NAME)
      where (^{knows.}^.TO_NAME = ^{users.}^.U_NAME)
      where (^{knows.}^.FROM_NAME = ^{users.}^.U_NAME)
      where (^{grants.}^.U_NAME = ^{users.}^.U_NAME)
      where (^{roles.}^.U_NAME = ^{users.}^.U_NAME)

      from DB.DBA.ODS_BLOG_POSTS as blog_posts
      where (^{blog_posts.}^.B_OWNER = ^{users.}^.U_NAME)
      from DB.DBA.ODS_BLOG_POST_LINKS as blog_links
      where (^{blog_links.}^.B_OWNER = ^{users.}^.U_NAME)
      from DB.DBA.ODS_BLOG_POST_ATTS as blog_atts
      where (^{blog_atts.}^.B_OWNER = ^{users.}^.U_NAME)
      from DB.DBA.ODS_BLOG_POST_TAGS as blog_tags
      where (^{blog_tags.}^.U_NAME = ^{users.}^.U_NAME)
      from DB.DBA.ODS_BLOG_COMMENTS as blog_comms
      where (^{blog_comms.}^.U_NAME = ^{users.}^.U_NAME)

      from DB.DBA.ODS_BMK_POSTS as bmk_posts
      where (^{bmk_posts.}^.U_NAME = ^{users.}^.U_NAME)
      from DB.DBA.ODS_BMK_TAGS as bmk_tags
      where (^{bmk_tags.}^.U_NAME = ^{users.}^.U_NAME)

      from DB.DBA.ODS_ODRIVE_POSTS as odrv_posts
      where (^{odrv_posts.}^.U_MEMBER = ^{users.}^.U_NAME)
      from DB.DBA.ODS_ODRIVE_TAGS as odrv_tags
      where (^{odrv_tags.}^.U_OWNER = ^{users.}^.U_NAME)

      from DB.DBA.ODS_FEED_FEED_DOMAIN as feed_domain
      where (^{feed_domain.}^.U_NAME = ^{users.}^.U_NAME)
      from DB.DBA.ODS_FEED_POSTS as feed_posts
      where (^{feed_posts.}^.EFI_FEED_ID = ^{feed_domain.}^.EF_ID)
      from DB.DBA.ODS_FEED_COMMENTS as feed_comments
      where (^{feed_comments.}^.U_NAME = ^{users.}^.U_NAME)
      from DB.DBA.ODS_FEED_TAGS as feed_tags
      where (^{feed_tags.}^.U_NAME = ^{users.}^.U_NAME)
      from DB.DBA.ODS_FEED_LINKS as feed_links
      where (^{feed_links.}^.EFI_FEED_ID = ^{feed_domain.}^.EF_ID)
      from DB.DBA.ODS_FEED_ATTS as feed_atts
      where (^{feed_atts.}^.EFI_FEED_ID = ^{feed_domain.}^.EF_ID)

      from DB.DBA.ODS_PHOTO_POSTS as photo_posts
      where (^{photo_posts.}^.U_MEMBER = ^{users.}^.U_NAME)
      from DB.DBA.ODS_PHOTO_COMMENTS as photo_comments
      where (^{photo_comments.}^.U_MEMBER = ^{users.}^.U_NAME)
      from DB.DBA.ODS_PHOTO_TAGS as photo_tags
      where (^{photo_tags.}^.U_MEMBER = ^{users.}^.U_NAME)

      from DB.DBA.ODS_POLLS_POSTS as polls_posts
      where (^{polls_posts.}^.U_NAME = ^{users.}^.U_NAME)
      from DB.DBA.ODS_POLLS_TAGS as polls_tags
      where (^{polls_tags.}^.U_NAME = ^{users.}^.U_NAME)

      from DB.DBA.ODS_ADDRESSBOOK_CONTACTS as addressbook_contacts
      where (^{addressbook_contacts.}^.U_NAME = ^{users.}^.U_NAME)
      from DB.DBA.ODS_ADDRESSBOOK_TAGS as addressbook_tags
      where (^{addressbook_tags.}^.U_NAME = ^{users.}^.U_NAME)

      from DB.DBA.ODS_WIKI_POSTS as wiki_posts
      where (^{wiki_posts.}^.U_NAME = ^{users.}^.U_NAME)

      from DB.DBA.ODS_COMMUNITIES as community
      where (^{community.}^.C_OWNER = ^{users.}^.U_NAME)

      from DB.DBA.ODS_NNTP_GROUPS as nntp_groups
      from DB.DBA.ODS_NNTP_POSTS as nntp_posts
      from DB.DBA.ODS_NNTP_USERS as nntp_users
      where (^{nntp_users.}^.U_NAME = ^{users.}^.U_NAME)
      from DB.DBA.ODS_NNTP_LINKS as nntp_links

      from DB.DBA.ODS_CALENDAR_EVENTS as cal_events
      where (^{cal_events.}^.U_NAME = ^{users.}^.U_NAME)
      from DB.DBA.ODS_CALENDAR_TAGS as cal_tags
      where (^{cal_tags.}^.U_NAME = ^{users.}^.U_NAME)

    {
	create virtrdf:ODS_DS as graph ods:graph (users.U_NAME) option (exclusive)
	  {
	    ods:user (users.U_NAME) a sioc:User ;
        sioc:id users.U_NAME ;
        sioc:name users.U_FULL_NAME ;
        sioc:email ods:mbox (users.E_MAIL) ;
        sioc:email_sha1 users.E_MAIL_SHA1 ;
        sioc:account_of ods:person (users.U_NAME) .

	    ods:person (person.U_NAME) a foaf:Person ;
        foaf:nick person.U_NAME ;
	      foaf:name person.U_FULL_NAME ;
	      foaf:mbox ods:mbox (person.E_MAIL) ;
        foaf:mbox_sha1sum person.E_MAIL_SHA1 ;
        foaf:holdsAccount ods:user (person.U_NAME) ;
        foaf:firstName person.FIRST_NAME ;
        foaf:family_name person.LAST_NAME ;
        foaf:gender person.GENDER ;
        foaf:icqChatID person.ICQ ;
        foaf:msnChatID person.MSN ;
        foaf:aimChatID person.AIM ;
        foaf:yahooChatID person.YAHOO ;
        foaf:birthday person.BIRTHDAY ;
        foaf:organization person.ORG ;
        foaf:phone ods:phone (person.PHONE) ;
	      foaf:based_near ods:geo_point (person.U_NAME)
	    .

	    ods:geo_point (person.U_NAME) a geo:Point ;
		    geo:lat person.LAT ;
		    geo:lng person.LNG .

	    ods:person (knows.FROM_NAME) foaf:knows ods:person (knows.TO_NAME) .
	    ods:person (knows.TO_NAME) foaf:knows ods:person (knows.FROM_NAME) .

	    ods:user_group (grants.G_NAME) a sioc:Usergroup ;
	    	sioc:id grants.G_NAME ;
		    sioc:has_member ods:user (grants.U_NAME) .
	      ods:user (grants.U_NAME)  sioc:member_of ods:user_group (grants.G_NAME) .

	    ods:role (roles.U_NAME, roles.APP_TYPE, roles.WAM_INST, roles.WMT_NAME)
	      sioc:has_scope ods:forum (roles.U_NAME, roles.APP_TYPE, roles.WAM_INST) ;
	      sioc:function_of ods:user (roles.U_NAME) .

      ods:forum (roles.U_NAME, roles.APP_TYPE, roles.WAM_INST)
	    	sioc:scope_of ods:role (roles.U_NAME, roles.APP_TYPE, roles.WAM_INST, roles.WMT_NAME) .
      ods:user (roles.U_NAME)
	    	sioc:has_function ods:role (roles.U_NAME, roles.APP_TYPE, roles.WAM_INST, roles.WMT_NAME) .

	    ods:forum (forums.U_NAME, forums.APP_TYPE, forums.WAM_INST) a sioc:Container ;
        sioc:id forums.WAM_INST ;
	      sioc:type forums.APP_TYPE ;
        sioc:description forums.WAI_DESCRIPTION ;
        sioc:link ods:proxy (forums.LINK) ;
        sioc:has_space ods:site (forums.U_NAME) .

      # Weblog
	    ods:blog_post (blog_posts.B_OWNER, blog_posts.B_INST, blog_posts.B_POST_ID) a sioct:BlogPost ;
	    sioc:link ods:proxy (blog_posts.B_LINK) ;
	    sioc:has_creator ods:user (blog_posts.B_CREATOR) ;
	    foaf:maker ods:person (blog_posts.B_CREATOR) ;
	    sioc:has_container ods:blog_forum (blog_posts.B_OWNER, blog_posts.B_INST) ;
	    dc:title blog_posts.B_TITLE ;
	    dct:created blog_posts.B_CREATED ;
	    dct:modified blog_posts.B_MODIFIED ;
	    sioc:content blog_posts.B_CONTENT .

	    ods:blog_forum (blog_posts.B_OWNER, blog_posts.B_INST)
	    sioc:container_of
	    ods:blog_post (blog_posts.B_OWNER, blog_posts.B_INST, blog_posts.B_POST_ID) .

	    ods:user (blog_posts.B_CREATOR)
	    sioc:creator_of
	    ods:blog_post (blog_posts.B_OWNER, blog_posts.B_INST, blog_posts.B_POST_ID) .

	    ods:blog_post (blog_links.B_OWNER, blog_links.B_INST, blog_links.B_POST_ID)
	    sioc:links_to
	    ods:proxy (blog_links.PL_LINK) .
	    # end Weblog

      # Bookmark
	    ods:bmk_post (bmk_posts.U_NAME, bmk_posts.WAI_NAME, bmk_posts.BD_BOOKMARK_ID)
        a bm:Bookmark ;
	      dc:title bmk_posts.BD_NAME;
	      dct:created bmk_posts.BD_CREATED ;
	      dct:modified bmk_posts.BD_LAST_UPDATE ;
	      dc:date bmk_posts.BD_LAST_UPDATE ;
	      ann:created bmk_posts.BD_CREATED ;
	      dc:creator bmk_posts.U_NAME ;
	      bm:recalls ods:proxy (bmk_posts.B_URI) ;
	      sioc:link ods:proxy (bmk_posts.B_URI) ;
	      sioc:content bmk_posts.BD_DESCRIPTION ;
	      sioc:has_creator ods:user (bmk_posts.U_NAME) ;
	      foaf:maker ods:person (bmk_posts.U_NAME) ;
	      sioc:has_container ods:bmk_forum (bmk_posts.U_NAME, bmk_posts.WAI_NAME) .

      ods:bmk_forum (bmk_posts.U_NAME, bmk_posts.WAI_NAME)
	      sioc:container_of ods:bmk_post (bmk_posts.U_NAME, bmk_posts.WAI_NAME, bmk_posts.BD_BOOKMARK_ID) .

	    ods:user (bmk_posts.U_NAME)
	      sioc:creator_of ods:bmk_post (bmk_posts.U_NAME, bmk_posts.WAI_NAME, bmk_posts.BD_BOOKMARK_ID) .

	    ods:bmk_post (bmk_tags.U_NAME, bmk_tags.WAM_INST, bmk_tags.ITEM_ID)
	      sioc:topic ods:tag (bmk_tags.U_NAME, bmk_tags.BD_TAG) .

	    ods:tag (bmk_tags.U_NAME, bmk_tags.BD_TAG) a skos:Concept ;
	      skos:prefLabel bmk_tags.BD_TAG ;
	      skos:isSubjectOf ods:bmk_post (bmk_tags.U_NAME, bmk_tags.WAM_INST, bmk_tags.ITEM_ID) .
	    # end Bookmark

      # Briefcase
	    ods:odrive_post (odrv_posts.RES_FULL_PATH) a foaf:Document ;
	    dc:title odrv_posts.RES_NAME ;
	    dct:created odrv_posts.RES_CREATED ;
	    dct:modified odrv_posts.RES_MODIFIED ;
	    sioc:content odrv_posts.RES_DESCRIPTION ;
	    sioc:has_creator ods:user (odrv_posts.U_OWNER) ;
	    foaf:maker ods:person (odrv_posts.U_OWNER) ;
	    sioc:has_container ods:odrive_forum (odrv_posts.U_MEMBER, odrv_posts.WAI_NAME) .

	    ods:odrive_forum (odrv_posts.U_MEMBER, odrv_posts.WAI_NAME)
	    sioc:container_of
	    ods:odrive_post (odrv_posts.RES_FULL_PATH) .

	    ods:user (odrv_posts.U_OWNER)
	    sioc:creator_of
	    ods:odrive_post (odrv_posts.RES_FULL_PATH) .

	    ods:odrive_post (odrv_tags.RES_FULL_PATH)
	    sioc:topic
	    ods:tag (odrv_tags.U_OWNER, odrv_tags.TAG) .

	    ods:tag (odrv_tags.U_OWNER, odrv_tags.TAG) a skos:Concept ;
	    skos:prefLabel odrv_tags.TAG ;
	    skos:isSubjectOf ods:odrive_post (odrv_tags.RES_FULL_PATH) .
      # end Briefcase

      # Feeds
	    ods:feed (feed_domain.EF_ID)
	      a atom:Feed ;
  	    sioc:link ods:proxy (feed_domain.EF_URI) ;
  	    atom:link ods:proxy (feed_domain.EF_URI) ;
  	    atom:title feed_domain.EF_TITLE ;
  	    sioc:has_parent ods:feed_mgr (feed_domain.U_NAME, feed_domain.WAI_NAME) .

	    ods:feed_mgr (feed_domain.U_NAME, feed_domain.WAI_NAME)
	      sioc:parent_of ods:feed (feed_domain.EF_ID) .

	    ods:feed_item (feed_tags.EFI_FEED_ID, feed_tags.EFID_ITEM_ID)
	      sioc:topic ods:tag (feed_tags.U_NAME, feed_tags.EFID_TAG) .

	    ods:tag (feed_tags.U_NAME, feed_tags.EFID_TAG)
	      a skos:Concept ;
  	    skos:prefLabel feed_tags.EFID_TAG ;
  	    skos:isSubjectOf ods:feed_item (feed_tags.EFI_FEED_ID, feed_tags.EFID_ITEM_ID) .

	    ods:feed_comment (feed_comments.U_NAME, feed_comments.WAI_NAME, feed_comments.EFIC_ITEM_ID, feed_comments.EFIC_ID)
  	    a sioct:Comment ;
  	    dc:title feed_comments.EFIC_TITLE ;
  	    sioc:content feed_comments.EFIC_COMMENT ;
  	    dct:modified feed_comments.LAST_UPDATE ;
  	    dct:created feed_comments.LAST_UPDATE ;
  	    sioc:link ods:proxy (feed_comments.LINK) ;
  	    sioc:has_container ods:feed (feed_comments.EFI_FEED_ID) ;
  	    sioc:reply_of ods:feed_item (feed_comments.EFI_FEED_ID, feed_comments.EFIC_ITEM_ID) ;
  	    foaf:maker ods:proxy (feed_comments.EFIC_U_URL) .

	    ods:proxy (feed_comments.EFIC_U_URL)
	      a foaf:Person ;
	      foaf:name feed_comments.EFIC_U_NAME;
	      foaf:mbox ods:mbox (feed_comments.EFIC_U_MAIL) .

      ods:feed (feed_comments.EFI_FEED_ID)
	      sioc:container_of ods:feed_comment (feed_comments.U_NAME, feed_comments.WAI_NAME, feed_comments.EFIC_ITEM_ID, feed_comments.EFIC_ID) .

      ods:feed_item (feed_comments.EFI_FEED_ID, feed_comments.EFIC_ITEM_ID)
	      sioc:has_reply ods:feed_comment (feed_comments.U_NAME, feed_comments.WAI_NAME, feed_comments.EFIC_ITEM_ID, feed_comments.EFIC_ID) .

      ods:feed_item (feed_links.EFI_FEED_ID, feed_links.EFI_ID)
	      sioc:links_to ods:proxy (feed_links.EFIL_LINK) .

	    ods:feed_item (feed_atts.EFI_FEED_ID, feed_atts.EFI_ID)
	      sioc:attachment ods:proxy (feed_atts.EFIE_URL) .

	    ods:feed_item (feed_posts.EFI_FEED_ID, feed_posts.EFI_ID) a atom:Entry ;
  	    sioc:has_container ods:feed (feed_posts.EFI_FEED_ID) ;
  	    dc:title feed_posts.EFI_TITLE ;
  	    dct:created feed_posts.PUBLISH_DATE ;
  	    dct:modified feed_posts.PUBLISH_DATE ;
  	    sioc:link ods:proxy (feed_posts.EFI_LINK) ;
  	    sioc:content feed_posts.EFI_DESCRIPTION ;
  	    atom:title feed_posts.EFI_TITLE ;
  	    atom:source ods:feed (feed_posts.EFI_FEED_ID) ;
  	    atom:published feed_posts.PUBLISH_DATE ;
  	    atom:updated feed_posts.PUBLISH_DATE ;
  	    atom:content ods:feed_item_text (feed_posts.EFI_FEED_ID, feed_posts.EFI_ID) .

	    ods:feed (feed_posts.EFI_FEED_ID) sioc:container_of ods:feed_item (feed_posts.EFI_FEED_ID, feed_posts.EFI_ID) .

	    ods:feed_item_text (feed_posts.EFI_FEED_ID, feed_posts.EFI_ID) a atom:Content ;
	      atom:type "text/xhtml" ;
	      atom:lang "en-US" ;
	      atom:body feed_posts.EFI_DESCRIPTION .

	    ods:feed (feed_posts.EFI_FEED_ID)
	      atom:contains ods:feed_item (feed_posts.EFI_FEED_ID, feed_posts.EFI_ID) .
      # end Feeds

	    # Photo
	    ods:photo_post (photo_posts.RES_FULL_PATH) a exif:IFD ;
	    dc:title photo_posts.RES_NAME ;
	    dct:created photo_posts.RES_CREATED ;
	    dct:modified photo_posts.RES_MODIFIED ;
	    sioc:content photo_posts.RES_DESCRIPTION ;
	    sioc:has_creator ods:user (photo_posts.U_OWNER) ;
	    foaf:maker ods:person (photo_posts.U_OWNER) ;
	    sioc:link ods:proxy (photo_posts.RES_LINK) ;
	    sioc:has_container ods:photo_forum (photo_posts.U_MEMBER, photo_posts.WAI_NAME) .

	    ods:photo_forum (photo_posts.U_MEMBER, photo_posts.WAI_NAME)
	    sioc:container_of
	    ods:photo_post (photo_posts.RES_FULL_PATH) .

	    ods:user (photo_posts.U_OWNER)
	    sioc:creator_of
	    ods:photo_post (photo_posts.RES_FULL_PATH) .

	    ods:photo_post (photo_tags.RES_FULL_PATH)
	    sioc:topic
	    ods:tag (photo_tags.U_MEMBER, photo_tags.RES_TAG) .

	    ods:tag (photo_tags.U_MEMBER, photo_tags.RES_TAG) a skos:Concept ;
	    skos:prefLabel photo_tags.RES_TAG ;
	    skos:isSubjectOf ods:photo_post (photo_tags.RES_FULL_PATH) .

	    ods:photo_comment (photo_comments.RES_FULL_PATH, photo_comments.COMMENT_ID) a sioct:Comment ;
	    sioc:reply_of ods:photo_post (photo_comments.RES_FULL_PATH) ;
	    sioc:has_container ods:photo_forum (photo_comments.U_MEMBER, photo_comments.WAI_NAME) ;
	    dc:title photo_comments.RES_NAME ;
	    dct:created photo_comments.CREATE_DATE ;
	    dct:modified photo_comments.MODIFY_DATE ;
	    sioc:content photo_comments.TEXT ;
	    foaf:maker ods:person (photo_comments.U_MAKER) .

	    ods:photo_post (photo_comments.RES_FULL_PATH)
	    sioc:has_reply
	    ods:photo_comment (photo_comments.RES_FULL_PATH, photo_comments.COMMENT_ID) .
	    # end Photo

	    # Polls
	    ods:polls_post (polls_posts.U_NAME, polls_posts.WAI_NAME, polls_posts.P_ID)
        dc:title polls_posts.P_NAME;
        dct:created polls_posts.P_CREATED ;
    	  dct:modified polls_posts.P_UPDATED ;
    	  dc:date polls_posts.P_UPDATED ;
    	  dc:creator polls_posts.U_NAME ;
    	  sioc:content polls_posts.P_DESCRIPTION ;
    	  sioc:has_creator ods:user (polls_posts.U_NAME) ;
    	  sioc:has_container ods:polls_forum (polls_posts.U_NAME, polls_posts.WAI_NAME) ;
    	  foaf:maker ods:person (polls_posts.U_NAME)
    	.
      ods:polls_forum (polls_posts.U_NAME, polls_posts.WAI_NAME)
        sioc:container_of	ods:polls_post (polls_posts.U_NAME, polls_posts.WAI_NAME, polls_posts.P_ID)
      .
     	ods:user (polls_posts.U_NAME)
     	  sioc:creator_of	ods:polls_post (polls_posts.U_NAME, polls_posts.WAI_NAME, polls_posts.P_ID)
     	.
      ods:polls_post (polls_posts.U_NAME, polls_posts.WAI_NAME, polls_posts.P_ID)
	      a atom:Entry ;
      	atom:title polls_posts.P_NAME ;
      	atom:source ods:polls_forum (polls_posts.U_NAME, polls_posts.WAI_NAME) ;
      	atom:author ods:person (polls_posts.U_NAME) ;
        atom:published polls_posts.P_CREATED ;
	      atom:updated polls_posts.P_UPDATED ;
	      atom:content ods:polls_post_text (polls_posts.U_NAME, polls_posts.WAI_NAME, polls_posts.P_ID)
	    .
      ods:polls_post (polls_posts.U_NAME, polls_posts.WAI_NAME, polls_posts.P_ID)
        a atom:Content ;
        atom:type "text/plain" ;
	      atom:lang "en-US" ;
	      atom:body polls_posts.P_DESCRIPTION
	    .
      ods:polls_forum (polls_posts.U_NAME, polls_posts.WAI_NAME)
	      atom:contains ods:polls_post (polls_posts.U_NAME, polls_posts.WAI_NAME, polls_posts.P_ID)
	    .
    	ods:polls_post (polls_tags.U_NAME, polls_tags.WAM_INST, polls_tags.P_ID)
    	  sioc:topic ods:tag (polls_tags.U_NAME, polls_tags.P_TAG)
    	.
    	ods:tag (polls_tags.U_NAME, polls_tags.P_TAG)
    	  a skos:Concept ;
    	  skos:prefLabel polls_tags.P_TAG ;
    	  skos:isSubjectOf ods:polls_post (polls_tags.U_NAME, polls_tags.WAM_INST, polls_tags.P_ID)
    	.
      # end Polls

      # AddressBook
      ods:addressbook_contact (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME, addressbook_contacts.P_ID)
        a foaf:Person option (EXCLUSIVE) ;
        dc:title addressbook_contacts.P_NAME ;
        dct:created addressbook_contacts.P_CREATED ;
       	dct:modified addressbook_contacts.P_UPDATED ;
  	    dc:date addressbook_contacts.P_UPDATED ;
  	    dc:creator addressbook_contacts.U_NAME ;
  	    sioc:link ods:proxy (addressbook_contacts.P_URI) ;
  	    sioc:content addressbook_contacts.P_FULL_NAME ;
  	    sioc:has_creator ods:user (addressbook_contacts.U_NAME) ;
  	    sioc:has_container ods:addressbook_forum (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME) ;
  	    rdfs:seeAlso ods:proxy (addressbook_contacts.SEE_ALSO) ;
  	    foaf:maker ods:person (addressbook_contacts.U_NAME) ;
  	    foaf:nick addressbook_contacts.P_NAME ;
  	    foaf:name addressbook_contacts.P_FULL_NAME ;
  	    foaf:firstName addressbook_contacts.P_FIRST_NAME ;
  	    foaf:family_name addressbook_contacts.P_LAST_NAME ;
  	    foaf:gender addressbook_contacts.P_GENDER ;
  	    foaf:mbox ods:proxy(addressbook_contacts.P_MAIL) ;
  	    foaf:icqChatID addressbook_contacts.P_ICQ ;
  	    foaf:msnChatID addressbook_contacts.P_MSN ;
  	    foaf:aimChatID addressbook_contacts.P_AIM ;
  	    foaf:yahooChatID addressbook_contacts.P_YAHOO ;
  	    foaf:birthday addressbook_contacts.P_BIRTHDAY
  	  .
      ods:addressbook_forum (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME)
        sioc:container_of ods:addressbook_contact (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME, addressbook_contacts.P_ID)
      .
	    ods:user (addressbook_contacts.U_NAME)
	      sioc:creator_of ods:addressbook_contact (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME, addressbook_contacts.P_ID)
	    .
      ods:addressbook_contact (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME, addressbook_contacts.P_ID)
        a atom:Entry ;
      	atom:title addressbook_contacts.P_NAME ;
      	atom:source ods:addressbook_forum (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME) ;
      	atom:author ods:person (addressbook_contacts.U_NAME) ;
        atom:published addressbook_contacts.P_CREATED ;
      	atom:updated addressbook_contacts.P_UPDATED ;
      	atom:content ods:addressbook_contact_text (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME, addressbook_contacts.P_ID)
     	.
      ods:addressbook_contact (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME, addressbook_contacts.P_ID)
        a atom:Content ;
        atom:type "text/plain" ;
    	  atom:lang "en-US" ;
	      atom:body addressbook_contacts.P_FULL_NAME
	    .
      ods:addressbook_forum (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME)
        atom:contains ods:addressbook_contact (addressbook_contacts.U_NAME, addressbook_contacts.WAI_NAME, addressbook_contacts.P_ID)
      .
    	ods:addressbook_contact (addressbook_tags.U_NAME, addressbook_tags.WAM_INST, addressbook_tags.P_ID)
    	  sioc:topic ods:tag (addressbook_tags.U_NAME, addressbook_tags.P_TAG)
    	.
    	ods:tag (addressbook_tags.U_NAME, addressbook_tags.P_TAG)
    	  a skos:Concept ;
    	  skos:prefLabel addressbook_tags.P_TAG ;
    	  skos:isSubjectOf ods:addressbook_contact (addressbook_tags.U_NAME, addressbook_tags.WAM_INST, addressbook_tags.P_ID)
    	.
      # end AddressBook

	    # Mail
	    # end Mail

	    # Wiki
      ods:wiki_post (wiki_posts.U_NAME, wiki_posts.CLUSTERNAME, wiki_posts.LOCALNAME) a wikiont:Article ;
	    dc:title wiki_posts.LOCALNAME ;
	    dct:created wiki_posts.RES_CREATED ;
	    dct:modified wiki_posts.RES_MODIFIED ;
	    sioc:content wiki_posts.RES_CONTENT ;
	    sioc:has_creator ods:user (wiki_posts.U_NAME) ;
	    foaf:maker ods:person (wiki_posts.U_NAME) ;
	    sioc:has_container ods:wiki_forum (wiki_posts.U_NAME, wiki_posts.CLUSTERNAME) .

	    ods:wiki_forum (wiki_posts.U_NAME, wiki_posts.CLUSTERNAME)
	    sioc:container_of
	    ods:wiki_post (wiki_posts.U_NAME, wiki_posts.CLUSTERNAME, wiki_posts.LOCALNAME) .

	    ods:user (wiki_posts.U_NAME)
	    sioc:creator_of
	    ods:wiki_post (wiki_posts.U_NAME, wiki_posts.CLUSTERNAME, wiki_posts.LOCALNAME) .

	    # end Wiki

      # Community
	    ods:community_forum (community.C_OWNER, community.CM_COMMUNITY_ID) a sioc:Community ;
	    sioc:has_part ods:forum (community.A_OWNER, community.A_TYPE, community.CM_MEMBER_APP) .

	    ods:forum (community.A_OWNER, community.A_TYPE, community.CM_MEMBER_APP)
	    sioc:part_of
	    ods:community_forum (community.C_OWNER, community.CM_COMMUNITY_ID) .
      # end Community

	    # NNTP
	    ods:nntp_forum (nntp_groups.NG_NAME) a sioct:MessageBoard ;
	    sioc:id nntp_groups.NG_NAME ;
	    sioc:description nntp_groups.NG_DESC .

	    ods:nntp_post (nntp_posts.NG_NAME, nntp_posts.NM_ID) a sioct:BoardPost ;
	    sioc:content nntp_posts.NM_BODY ;
	    dc:title nntp_posts.FTHR_SUBJ ;
	    dct:created  nntp_posts.REC_DATE ;
	    dct:modified nntp_posts.REC_DATE ;
	    foaf:maker ods:proxy (nntp_posts.MAKER) ;
	    sioc:reply_of ods:nntp_post (nntp_posts.NG_NAME, nntp_posts.FTHR_REFER) ;
	    sioc:has_container ods:nntp_forum (nntp_posts.NG_NAME) .

	    ods:nntp_post (nntp_posts.NG_NAME, nntp_posts.FTHR_REFER)
	    sioc:has_reply
	    ods:nntp_post (nntp_posts.NG_NAME, nntp_posts.NM_ID) .

	    ods:nntp_forum (nntp_posts.NG_NAME)
	    sioc:container_of
	    ods:nntp_post (nntp_posts.NG_NAME, nntp_posts.NM_ID) .


	    ods:nntp_role (nntp_groups.NG_NAME)
	    sioc:has_scope
	    ods:nntp_forum (nntp_groups.NG_NAME) .

	    ods:nntp_forum (nntp_groups.NG_NAME)
	    sioc:scope_of
	    ods:nntp_role (nntp_groups.NG_NAME) .

	    ods:user (nntp_users.U_NAME)
	    sioc:has_function
	    ods:nntp_role (nntp_users.NG_NAME) .

	    ods:nntp_role (nntp_users.NG_NAME)
	    sioc:function_of
	    ods:user (nntp_users.U_NAME) .

	    ods:nntp_post (nntp_links.NG_NAME, nntp_links.NML_MSG_ID)
	    sioc:links_to
	    ods:proxy (nntp_links.NML_URL) .
	    # end NNTP

	    # Calendar
	    ods:calendar_event (cal_events.U_NAME, cal_events.WAI_NAME, cal_events.E_ID)
	      a calendar:vevent option (EXCLUSIVE) ;
  	    dc:title cal_events.E_SUBJECT ;
  	    dct:created cal_events.E_CREATED ;
  	    dct:modified cal_events.E_UPDATED ;
  	    dc:date cal_events.E_UPDATED ;
  	    ann:created cal_events.E_CREATED ;
  	    dc:creator cal_events.U_NAME ;
  	    sioc:link ods:proxy (cal_events.E_URI) ;
  	    sioc:content cal_events.E_DESCRIPTION ;
  	    sioc:has_creator ods:user (cal_events.U_NAME) ;
  	    foaf:maker ods:person (cal_events.U_NAME) ;
  	    sioc:has_container ods:calendar_forum (cal_events.U_NAME, cal_events.WAI_NAME)
  	  .
	    ods:calendar_forum (cal_events.U_NAME, cal_events.WAI_NAME)
	      sioc:container_of ods:calendar_event (cal_events.U_NAME, cal_events.WAI_NAME, cal_events.E_ID)
	    .
	    ods:user (cal_events.U_NAME)
	      sioc:creator_of ods:calendar_event (cal_events.U_NAME, cal_events.WAI_NAME, cal_events.E_ID)
	    .
	    ods:calendar_event (cal_tags.U_NAME, cal_tags.WAM_INST, cal_tags.ITEM_ID)
	      sioc:topic ods:tag (cal_tags.U_NAME, cal_tags.E_TAG)
	    .
	    ods:tag (cal_tags.U_NAME, cal_tags.E_TAG)
	      a skos:Concept ;
	      skos:prefLabel cal_tags.E_TAG ;
	      skos:isSubjectOf ods:calendar_event (cal_tags.U_NAME, cal_tags.WAM_INST, cal_tags.ITEM_ID)
	    .
	    # end Calendar

	  } .
  } .
;

--sparql select * from <http://intel.gmz:6666/dataspace/dav> where { [] ?p ?o };
--sparql select * from <http://intel.gmz:6666/dataspace/dba> where { [] ?p ?o };
