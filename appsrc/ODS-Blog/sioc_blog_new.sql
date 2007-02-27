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

use DB;

-- BLOG posts & related

wa_exec_no_error ('drop view ODS_BLOG_POSTS');
wa_exec_no_error ('drop view ODS_BLOG_POST_LINKS');
wa_exec_no_error ('drop view ODS_BLOG_POST_ATTS');
wa_exec_no_error ('drop view ODS_BLOG_POST_TAGS');
wa_exec_no_error ('drop view ODS_BLOG_COMMENTS');

create view ODS_BLOG_POSTS as select
	uo.U_NAME 	as B_OWNER,
	i.BI_WAI_NAME	as B_INST,
	p.B_POST_ID	as B_POST_ID,
	p.B_TITLE	as B_TITLE,
	p.B_CONTENT	as B_CONTENT,
	sioc..sioc_date (p.B_TS) as B_CREATED,
	sioc..sioc_date (p.B_MODIFIED) as B_MODIFIED,
	uc.U_NAME	as B_CREATOR,
        sioc..post_iri (uo.U_NAME, 'WEBLOG2', i.BI_WAI_NAME, p.B_POST_ID) || '/sioc.rdf' as B_SEE_ALSO,
        md5 (sioc..post_iri (uo.U_NAME, 'WEBLOG2', i.BI_WAI_NAME, p.B_POST_ID)) as IRI_MD5
	from BLOG.DBA.SYS_BLOG_INFO i, BLOG.DBA.SYS_BLOGS p, DB.DBA.SYS_USERS uo, DB.DBA.SYS_USERS uc
	where p.B_BLOG_ID = i.BI_BLOG_ID and i.BI_OWNER = uo.U_ID and p.B_USER_ID = uc.U_ID;

create view ODS_BLOG_POST_LINKS as select
	U_NAME      	as B_OWNER,
	BI_WAI_NAME 	as B_INST,
	PL_POST_ID 	as B_POST_ID,
	PL_LINK		as PL_LINK
	from BLOG.DBA.SYS_BLOG_INFO, DB.DBA.SYS_USERS, BLOG.DBA.BLOG_POST_LINKS
	where PL_BLOG_ID = BI_BLOG_ID and BI_OWNER = U_ID;

create view ODS_BLOG_POST_ATTS as select
	U_NAME      	as B_OWNER,
	BI_WAI_NAME 	as B_INST,
	PE_POST_ID 	as B_POST_ID,
	PE_URL		as PE_LINK
	from BLOG.DBA.SYS_BLOG_INFO, DB.DBA.SYS_USERS, BLOG.DBA.BLOG_POST_ENCLOSURES
	where PE_BLOG_ID = BI_BLOG_ID and BI_OWNER = U_ID;

create view ODS_BLOG_POST_TAGS as select
	BT_TAG,
	BT_POST_ID,
	BI_WAI_NAME,
	U_NAME
	from
	BLOG..BLOG_TAGS_STAT,
	BLOG..SYS_BLOG_INFO,
	DB.DBA.SYS_USERS
	where blogid = BI_BLOG_ID and BI_OWNER = U_ID;

create view ODS_BLOG_COMMENTS as select
	U_NAME,
	BI_WAI_NAME,
	BM_POST_ID,
	BM_ID,
	BM_COMMENT,
	BM_NAME,
	case when length (BM_E_MAIL) then 'mailto:'||BM_E_MAIL else null end as E_MAIL,
	case when length (BM_E_MAIL) then sha1_digest (BM_E_MAIL) else null end as E_MAIL_SHA1,
	case when length (BM_HOME_PAGE) then BM_HOME_PAGE else NULL end as BM_HOME_PAGE,
	sioc..sioc_date (BM_TS) as BM_CREATED,
	BM_TITLE,
        sioc..post_iri (U_NAME, 'WEBLOG2', BI_WAI_NAME, sprintf ('%s/%d', BM_POST_ID, BM_ID)) || '/sioc.rdf' as SEE_ALSO,
        md5 (sioc..post_iri (U_NAME, 'WEBLOG2', BI_WAI_NAME, sprintf ('%s/%d', BM_POST_ID, BM_ID))) as IRI_MD5
	from BLOG..BLOG_COMMENTS, BLOG..SYS_BLOG_INFO, DB.DBA.SYS_USERS
	where BI_BLOG_ID = BM_BLOG_ID and BM_IS_PUB = 1 and BI_OWNER = U_ID;




create procedure sioc.DBA.rdf_weblog_view_str ()
{
  return
      '
	# Blog Posts
	sioc:blog_post_iri (DB.DBA.ODS_BLOG_POSTS.B_OWNER,
			    DB.DBA.ODS_BLOG_POSTS.B_INST,
			    DB.DBA.ODS_BLOG_POSTS.B_POST_ID) a sioc:Post ;
        rdfs:seeAlso  sioc:iri (B_SEE_ALSO) ;
	sioc:id IRI_MD5 ;
	sioc:has_creator sioc:user_iri (B_CREATOR) ;
	foaf:maker foaf:person_iri (B_CREATOR) ;
        sioc:has_container sioc:blog_forum_iri (B_OWNER, B_INST) ;
        dc:title B_TITLE ;
        dct:created B_CREATED ;
 	dct:modified B_MODIFIED ;
	sioc:content B_CONTENT
	.

	sioc:user_iri (DB.DBA.ODS_BLOG_POSTS.B_CREATOR)
	sioc:creator_of
	sioc:blog_post_iri (B_OWNER, B_INST, B_POST_ID) .

	sioc:blog_forum_iri (DB.DBA.ODS_BLOG_POSTS.B_OWNER, DB.DBA.ODS_BLOG_POSTS.B_INST)
	sioc:container_of
	sioc:blog_post_iri (B_OWNER, B_INST, B_POST_ID) .

	# Blog Post links_to
	sioc:blog_post_iri (DB.DBA.ODS_BLOG_POST_LINKS.B_OWNER,
	    		    DB.DBA.ODS_BLOG_POST_LINKS.B_INST,
			    DB.DBA.ODS_BLOG_POST_LINKS.B_POST_ID)
	sioc:links_to
	sioc:iri (PL_LINK) .

	# Blog Post enclosures
	sioc:blog_post_iri (DB.DBA.ODS_BLOG_POST_ATTS.B_OWNER,
	    		    DB.DBA.ODS_BLOG_POST_ATTS.B_INST,
			    DB.DBA.ODS_BLOG_POST_ATTS.B_POST_ID)
	sioc:attachment
	sioc:iri (PE_LINK) .

        # Blog Post tags
	sioc:blog_post_iri (DB.DBA.ODS_BLOG_POST_TAGS.U_NAME,
	    		    DB.DBA.ODS_BLOG_POST_TAGS.BI_WAI_NAME,
			    DB.DBA.ODS_BLOG_POST_TAGS.BT_POST_ID)
	sioc:topic
	sioc:blog_tag_iri (U_NAME, BT_TAG) .

        sioc:blog_tag_iri (DB.DBA.ODS_BLOG_POST_TAGS.U_NAME, DB.DBA.ODS_BLOG_POST_TAGS.BT_TAG) a skos:Concept ;
	skos:prefLabel BT_TAG ;
	skos:isSubjectOf sioc:blog_post_iri (U_NAME,BI_WAI_NAME,BT_POST_ID) .

	# Blog Comments
        sioc:blog_comment_iri (DB.DBA.ODS_BLOG_COMMENTS.U_NAME,
			       DB.DBA.ODS_BLOG_COMMENTS.BI_WAI_NAME,
		   	       DB.DBA.ODS_BLOG_COMMENTS.BM_POST_ID,
			       DB.DBA.ODS_BLOG_COMMENTS.BM_ID) a sioc:Post ;
        sioc:id IRI_MD5 ;
        rdfs:seeAlso sioc:iri (SEE_ALSO) ;
	foaf:maker sioc:iri (BM_HOME_PAGE) ;
	sioc:has_container sioc:blog_forum_iri (U_NAME, BI_WAI_NAME) ;
	dc:title BM_TITLE ;
	dct:created BM_CREATED ;
 	dct:modified BM_CREATED ;
	sioc:content BM_COMMENT ;
        sioc:reply_of sioc:blog_post_iri (U_NAME, BI_WAI_NAME, BM_POST_ID)
        .

        sioc:blog_post_iri (DB.DBA.ODS_BLOG_COMMENTS.U_NAME,
			    DB.DBA.ODS_BLOG_COMMENTS.BI_WAI_NAME,
		   	       DB.DBA.ODS_BLOG_COMMENTS.BM_POST_ID)
	sioc:has_reply
	sioc:blog_comment_iri (U_NAME, BI_WAI_NAME, BM_POST_ID, BM_ID)
	.

	sioc:blog_forum_iri (DB.DBA.ODS_BLOG_COMMENTS.U_NAME, DB.DBA.ODS_BLOG_COMMENTS.BI_WAI_NAME)
	sioc:container_of
	sioc:blog_comment_iri (U_NAME, BI_WAI_NAME, BM_POST_ID, BM_ID)
	.

	sioc:iri (DB.DBA.ODS_BLOG_COMMENTS.BM_HOME_PAGE) a foaf:Person ;
        foaf:name BM_NAME ;
	foaf:mbox E_MAIL ;
	foaf:mbox_sha1sum E_MAIL_SHA1
        .

      ';
};

ODS_RDF_VIEW_DEF ();
