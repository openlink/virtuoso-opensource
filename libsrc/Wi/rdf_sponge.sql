--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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

-- Function				is called from
-- RDF_LOG_DEBUG_INFO_RESET		RDF_GRAP
-- RDF_LOG_DEBUG_INFO			almost everywhere :)
-- RDF_FT_INDEX_GRABBED			RDF_GRAB_SEEALSO, RDF_GRAB
-- RDF_GRAB_PREPARE_PRIVATE		RDF_GRAB_SINGLE
-- RDF_GRAB_SINGLE			RDF_GRAB_SINGLE_ASYNC
-- RDF_GRAB_SINGLE_ASYNC			RDF_GRAB_SEEALSO, RDF_GRAB
-- RDF_GRAB_SEEALSO			RDF_GRAB
-- RDF_GRAB				code made from codegen for ssg_grabber_codegen() prepared by sparp_rewrite_grab()
-- RDF_GRAB_RESOLVER_DEFAULT		passed as 'resolver' to RDF_GRAB_SINGLE from SPARUL_LOAD
-- SYS_HTTP_SPONGE_GET_CACHE_PARAMS	SYS_HTTP_SPONGE_UP
-- SYS_HTTP_SPONGE_DEP_URL_NOT_CHANGED	unused in server
-- RDF_HTTP_MAKE_HTTP_REQ		SYS_HTTP_SPONGE_UP
-- RDF_HTTP_URL_GET			SYS_HTTP_SPONGE_UP
-- SYS_HTTP_SPONGE_UP			itself, RDF_SPONGE_UP_1
-- SYS_FILE_SPONGE_UP			RDF_SPONGE_UP_1
-- RDF_SPONGE_GUESS_CONTENT_TYPE		RDF_LOAD_HTTP_RESPONSE
-- RDF_SW_PING				RDF_LOAD_HTTP_RESPONSE
-- RDF_PROC_COLS				RDF_LOAD_HTTP_RESPONSE
-- RDF_LOAD_HTTP_RESPONSE		SYS_FILE_SPONGE_UP, passed to SYS_HTTP_SPONGE_UP from RDF_SPONGE_UP_1
-- RDF_FORGET_HTTP_RESPONSE		passed to SYS_FILE_SPONGE_UP and SYS_HTTP_SPONGE_UP from RDF_SPONGE_UP_1
-- RDF_SPONGE_UP				RDF_SPONGE_UP_LIST, code made by ssg_grabber_codegen passes it to RDF_GRAB proc view as _grabber_loader
-- RDF_SPONGE_UP_1			RDF_SPONGE_UP
-- RDF_SPONGE_UP_LIST			unused in server

-----
-- Procedures for graph grabber

--!AWK PUBLIC

create procedure DB.DBA.RDF_LOG_DEBUG_INFO_RESET (in flag varchar)
{
  declare ctx, flags_to_ignore any;
  flags_to_ignore := connection_get ('DB.DBA.RDF_LOG_DEBUG_INFO_RESET');
  if ((__tag(ctx) = __tag of vector) and (0 < position (flag, flags_to_ignore)))
    return;
  vectorbld_init(ctx);
  connection_swap ('DB.DBA.RDF_LOG_DEBUG_INFO acc', ctx, -1);
}
;

create procedure DB.DBA.RDF_LOG_DEBUG_INFO (in message varchar, in arg1 any, in arg2 any)
{
  --dbg_obj_princ ('DB.DBA.RDF_LOG_DEBUG_INFO (', message, arg1, arg2);
  declare ctx any;
  if (not connection_get ('DB.DBA.RDF_LOG_DEBUG_INFO', 0, -1))
    return;
  connection_swap ('DB.DBA.RDF_LOG_DEBUG_INFO acc', ctx, -1);
  if (__tag(ctx) <> __tag of vector)
    {
      dbg_obj_princ ('DB.DBA.RDF_LOG_DEBUG_INFO(): initialization');
      vectorbld_init(ctx);
    }
  vectorbld_acc (ctx, vector (message, arg1, arg2));
  connection_swap ('DB.DBA.RDF_LOG_DEBUG_INFO acc', ctx, -1);
}
;

--!AWK PUBLIC
create procedure DB.DBA.RDF_FT_INDEX_GRABBED (inout grabbed any, inout options any)
{
  declare grabbed_list any;
  declare grab_ctr, grab_count integer;
  declare g_iri varchar;
  if (not coalesce (get_keyword ('refresh_free_text', options), 0))
    return;
  g_iri := get_keyword ('get:group-destination', options);
  -- dbg_obj_princ ('DB.DBA.RDF_FT_INDEX_GRABBED () has g_iri = ', g_iri);
  if (isstring (g_iri) and __rdf_obj_ft_rule_count_in_graph (iri_to_id (g_iri)))
    {
      VT_INC_INDEX_DB_DBA_RDF_OBJ();
      commit work;
      -- dbg_obj_princ ('DB.DBA.RDF_FT_INDEX_GRABBED () has indexed RDF_OBJ');
      return;
    }
  grabbed_list := dict_to_vector (grabbed, 0);
  grab_count := length (grabbed_list);
  -- dbg_obj_princ ('DB.DBA.RDF_FT_INDEX_GRABBED () has grabbed_list = ', grabbed_list);
  for (grab_ctr := 1; grab_ctr < grab_count; grab_ctr := grab_ctr + 2)
    {
      g_iri := grabbed_list[grab_ctr];
      if (isstring (g_iri) and __rdf_obj_ft_rule_count_in_graph (iri_to_id (g_iri)))
        {
          VT_INC_INDEX_DB_DBA_RDF_OBJ();
          commit work;
          -- dbg_obj_princ ('DB.DBA.RDF_FT_INDEX_GRABBED () has indexed RDF_OBJ');
          return;
        }
    }
  -- dbg_obj_princ ('DB.DBA.RDF_FT_INDEX_GRABBED () has changed nothing');
}
;

create procedure DB.DBA.RDF_GRAB_PREPARE_PRIVATE (in graph_iri varchar, in group_iri varchar, in uname varchar, inout options any)
{
  declare uid, graph_public_perms integer;
  declare g_iid, group_iid IRI_ID;
  declare g_is_private integer;
#pragma prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
  g_iid := iri_to_id (graph_iri);
  uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  -- dbg_obj_princ    ('DB.DBA.RDF_GRAB_PREPARE_PRIVATE (', graph_iri, group_iri, uname, options, '): g_iid is ', g_iid, ', uid is ', uid);
  if (uid is null)
    signal ('RDFGS', sprintf ('A SPARQL query with get:private has failed to get data about user "%s"', uname));
  if (uid = http_nobody_uid())
    signal ('RDFGS', sprintf ('A SPARQL query with get:private is used by user "nobody", that is prohibited'));
-- If graph is virtrdf: then an error is signaled.
  if (graph_iri = 'http://www.openlinksw.com/schemas/virtrdf#')
    signal ('RDFGS', sprintf ('A SPARQL query with get:private tries to change access permissions of system metadata graph <%.500s>', graph_iri));
  if (group_iri in (UNAME'http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs', UNAME'http://www.openlinksw.com/schemas/virtrdf#rdf_repl_graph_group'))
    signal ('RDFGS', sprintf ('A SPARQL query with get:private tries to add graph <%.500s> to special graph group <%.500s>', graph_iri, group_iri));
-- If graph name is an IRI of handshaked web service endpoint then an error is signaled.
  if (exists (sparql define input:storage "" ask from virtrdf:
      where { `iri(?:graph_iri)` virtrdf:dialect|virtrdf:isEndpointOfService|^virtrdf:isEndpointOfService ?o } ) )
    signal ('RDFGS', sprintf ('A SPARQL query with get:private tries to change access permissions of graph <%.500s> but the graph is a known web service endpoint', graph_iri));
-- If access is public by default even for private graphs then an error is signaled and sponging is not tried.
  graph_public_perms := DB.DBA.RDF_GRAPH_USER_PERMS_GET (graph_iri, http_nobody_uid());
  if (bit_and (15, graph_public_perms)
    and (bit_and (15, dict_get (__rdf_graph_default_perms_of_user_dict(1), http_nobody_uid(), 15))
      or exists (select 1 from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = g_iid and RGU_USER_ID = http_nobody_uid()) ) )
    signal ('RDFGS', sprintf ('A SPARQL query with get:private tries to change access permissions of publicly accessible graph <%.500s>', graph_iri));
  if (group_iri <> '' and 11 <> bit_and (11, DB.DBA.RDF_GRAPH_USER_PERMS_GET (group_iri, uid)))
    signal ('RDFGS', sprintf ('A SPARQL query with get:private tries to change graph group <%.500s> and add <%.500s> there but user "%s" has not enough rights on that group', group_iri, graph_iri, uname));
-- If default is "no access" but someone (other than current user) has specifically granted read access to the graph in question AND current user is not dba then an error is signaled.
  if (uid <> 0)
    {
      declare other_reader varchar;
      other_reader := (select U_NAME from DB.DBA.RDF_GRAPH_USER join DB.DBA.SYS_USERS on (RGU_USER_ID=U_ID)
        where RGU_GRAPH_IID = g_iid and RGU_USER_ID <> uid and RGU_USER_ID <> 0 and RGU_PERMISSIONS <> 0 );
      if ((other_reader is not null) and not bit_and (32, DB.DBA.RDF_GRAPH_USER_PERMS_GET (graph_iri, uid)))
        signal ('RDFGS', sprintf ('A SPARQL query of user "%.500s" with get:private tries to change access permissions of graph <%.500s> privately used by user "%.500s"', uname, graph_iri, other_reader));
    }
  g_is_private := 0;
-- If read access is public by default for world and disabled for private graphs then the graph to be sponged is added to the group of private graphs.
  if (bit_and (15, dict_get (__rdf_graph_default_perms_of_user_dict(0), http_nobody_uid(), 15)))
    {
      -- dbg_obj_princ    ('DB.DBA.RDF_GRAB_PREPARE_PRIVATE (', graph_iri, group_iri, uname, ') will put graph to virtrdf:PrivateGraphs');
      DB.DBA.RDF_GRAPH_GROUP_INS (UNAME'http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs', graph_iri);
      g_is_private := 1;
    }
-- If current user is not DBA, current user gets granted read+write+sponge+admin access to the graph to be sponged.
  if (uid <> 0)
    {
      -- dbg_obj_princ    ('DB.DBA.RDF_GRAB_PREPARE_PRIVATE (', graph_iri, group_iri, uname, ') will set perms of non-dba user on the graph');
      DB.DBA.RDF_GRAPH_USER_PERMS_SET (graph_iri, uname, 15+32);
    }
-- If the value of get:private is an IRI then
  if (group_iri <> '')
    {
      group_iid := iri_to_id (group_iri);
      -- the IRI is supposed to be an IRI of "plain" graph group, error is signaled in case of nonexising graph group, group of private graphs or group of graphs to be replicated.
      -- - the graph is added to that group,
      -- dbg_obj_princ    ('DB.DBA.RDF_GRAB_PREPARE_PRIVATE (', graph_iri, group_iri, uname, ') will add the graph to graph group iid ', group_iid);
      DB.DBA.RDF_GRAPH_GROUP_INS (group_iri, graph_iri);
      for (
        select sub.U_NAME as fellow_name, bit_or (MAX (RGU_PERMISSIONS), graph_public_perms, 1) as max_perms from
          (
            select U_NAME, RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER join DB.DBA.SYS_USERS on (RGU_USER_ID=U_ID)
            where RGU_USER_ID <> uid and RGU_USER_ID <> http_nobody_uid() and RGU_USER_ID <> 0 and RGU_GRAPH_IID = group_iid and bit_and (RGU_PERMISSIONS, 8)
            union select U_NAME, RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER join DB.DBA.SYS_USERS on (RGU_USER_ID=U_ID)
            where RGU_USER_ID <> uid and RGU_USER_ID <> http_nobody_uid() and RGU_USER_ID <> 0 and RGU_GRAPH_IID = case when (g_is_private) then #i8192 else #i0 end and bit_and (RGU_PERMISSIONS, 8) ) sub
        group by sub.U_NAME ) do
        {
          -- - each non-dba user that can get list of files of the group will get permissions for the loaded graph equal to permissions they have on graph group minus "list" permission.
          -- dbg_obj_princ    ('DB.DBA.RDF_GRAB_PREPARE_PRIVATE (', graph_iri, group_iri, uname, ') will grant ', max_perms, ' to ', fellow_name);
          DB.DBA.RDF_GRAPH_USER_PERMS_SET (graph_iri, fellow_name, max_perms);
        }
    }
  -- dbg_obj_princ    ('DB.DBA.RDF_GRAB_PREPARE_PRIVATE (', graph_iri, group_iri, uname, ') done');
}
;

create function DB.DBA.RDF_GRAB_SINGLE (in val any, inout grabbed any, inout env any) returns integer
{
  declare resolver, url, get_method, recov varchar;
  declare dest varchar;
  declare opts, err any;
  -- dbg_obj_princ ('DB.DBA.RDF_GRAB_SINGLE (', coalesce (id_to_iri_nosignal (val), val), ',,... , ', env, ')');
  {
  whenever sqlstate '*' goto end_of_sponge;
  if (val is null)
    return 0;
  if (isiri_id (val))
    {
      if (is_bnode_iri_id (val))
        return 0;
      val := id_to_iri (val);
    }
  if (__tag of UNAME = __tag (val))
    val := cast (val as varchar);
  dest := null;
  resolver := get_keyword_ucase ('resolver', env, 'DB.DBA.RDF_GRAB_RESOLVER_DEFAULT');
  call (resolver) (get_keyword_ucase ('base_iri', env), val, url, dest, get_method);
  --if (dest is not null and dest = url)
  --  dest := null;
  if (url is null)
    {
      DB.DBA.RDF_LOG_DEBUG_INFO ('DB.DBA.RDF_GRAB_SINGLE() will not try to process <%s>, because the IRI resolver "%s" returned NULL', val, resolver);
      return 0;
    }
  else if (dict_get (grabbed, url, 0))
    {
      DB.DBA.RDF_LOG_DEBUG_INFO ('DB.DBA.RDF_GRAB_SINGLE() will not try to process <%s>, because it is resolved as <%s> and processed before', val, url);
      return 0;
    }
  else
    {
      declare final_dest, final_gdest, get_private varchar;
      final_dest := get_keyword ('get:destination', env, dest);
      final_gdest := get_keyword ('get:group-destination', env);
      opts := vector (
        'get:soft', get_keyword_ucase ('get:soft', env, 'soft'),
        'get:refresh', get_keyword_ucase ('get:refresh', env),
        'get:method', get_method,
        'get:destination', final_dest,
        'get:group-destination', final_gdest,
        'get:strategy', get_keyword_ucase ('get:strategy', env),
        'get:private', get_keyword_ucase ('get:private', env),
        'get:error-recovery', get_keyword_ucase ('get:error-recovery', env),
        'get:note', get_keyword_ucase ('get:note', env) );
      dict_put (grabbed, url, 1);
      DB.DBA.RDF_LOG_DEBUG_INFO ('DB.DBA.RDF_GRAB_SINGLE() has resolved <%s> as <%s> and will try to grab it', val, url);
      get_private := get_keyword_ucase ('get:private', env, null);
      if (get_private is not null)
        DB.DBA.RDF_GRAB_PREPARE_PRIVATE (final_dest, get_private, user, env);
      call (get_keyword ('loader', env, 'DB.DBA.RDF_SPONGE_UP'))(url, opts, user);
      commit work;
      dict_put (grabbed, url, coalesce (final_dest, dest));
      -- dbg_obj_princ ('DB.DBA.RDF_GRAB_SINGLE (', val, ',... , ', env, ') has loaded ', url);
      if (coalesce (get_keyword_ucase ('refresh_free_text', env), 0) and
        (__rdf_obj_ft_rule_count_in_graph (iri_to_id (final_dest)) or
          __rdf_obj_ft_rule_count_in_graph (iri_to_id (final_gdest)) ) )
        {
          VT_INC_INDEX_DB_DBA_RDF_OBJ();
          -- dbg_obj_princ ('DB.DBA.RDF_GRAB_SINGLE (', val, ',... , ', env, ') has loaded ', url);
          commit work;
        }
      return 1;
    }
  }
end_of_sponge:
  commit work;
  -- dbg_obj_princ ('DB.DBA.RDF_GRAB_SINGLE will try to recover after ', __SQL_STATE, __SQL_MESSAGE, ' with ', get_keyword_ucase ('get:error-recovery', env));
  recov := get_keyword_ucase ('get:error-recovery', env);
  if (recov is not null)
    {
      if (recov = 'signal')
        signal (__SQL_STATE, __SQL_MESSAGE);
      whenever sqlstate '*' goto end_of_recov;
      call (recov) (__SQL_STATE, __SQL_MESSAGE, val, grabbed, env);
      commit work;
      return 0;
end_of_recov:
      rollback work;
    }
  return 0;
}
;

create procedure DB.DBA.RDF_GRAB_SINGLE_ASYNC (in val any, in grabbed any, in env any, in counter_limit integer := 1)
{
  -- dbg_obj_princ ('DB.DBA.RDF_GRAB_SINGLE_ASYNC (', coalesce (id_to_iri_nosignal (val), val), ', { dict of size ', dict_size (grabbed), ' }, ', env, counter_limit);
  if (dict_size (grabbed) <= counter_limit)
    DB.DBA.RDF_GRAB_SINGLE (val, grabbed, vector_concat (vector ('refresh_free_text', 0), env));
}
;

create function DB.DBA.RDF_GRAB_SEEALSO (in subj varchar, in opt_g varchar, inout env any) returns integer
{
  declare grabbed, aq any;
  declare sa_graphs, sa_preds any;
  declare doc_limit, flags integer;
  if (not isiri_id (subj))
    return 1;
  aq := async_queue (8);
  grabbed := get_keyword ('grabbed', env);
  doc_limit := get_keyword ('doc_limit', env, 0hex1000000);
  if (dict_size (grabbed) > doc_limit)
    goto out_of_limit;
  sa_preds := get_keyword ('sa_preds', env);
  sa_graphs := get_keyword ('sa_graphs', env);
  -- dbg_obj_princ ('DB.DBA.RDF_GRAB_SEEALSO (', subj, opt_g, ') in graphs ', sa_graphs, ' with preds ', sa_preds);
  if (sa_graphs is null)
    {
      foreach (varchar pred in sa_preds) do
        {
          for (sparql define input:storage "" select ?val where { ?:subj ?:pred ?val . filter (isIRI(?val)) } ) do
            {
              -- dbg_obj_princ ('found { ?g, ', subj, pred, val, '}');
              if ("val" like 'http://%')
                {
                  -- dbg_obj_princ ('DB.DBA.RDF_GRAB_SEEALSO () aq_request ', vector ("val", '...', env, doc_limit));
                  DB.DBA.RDF_LOG_DEBUG_INFO ('DB.DBA.RDF_GRAB_SEEALSO suggests <%s> due to predicate <%s>', "val", __id2i (pred));
                  --DB.DBA.RDF_GRAB_SINGLE_ASYNC ("val", grabbed, env, doc_limit);
                  aq_request (aq, 'DB.DBA.RDF_GRAB_SINGLE_ASYNC', vector ("val", grabbed, env, doc_limit));
                  if (dict_size (grabbed) > doc_limit)
                    goto out_of_limit;
                }
              else
                DB.DBA.RDF_LOG_DEBUG_INFO ('DB.DBA.RDF_GRAB_SEEALSO rejects <%s> inferred via predicate <%s> because it is not of <http://...> format', "val", __id2i (pred));
            }
        }
    }
  else
    {
  foreach (varchar pred in sa_preds) do
    {
      foreach (varchar graph in sa_graphs) do
        {
          for (sparql define input:storage "" select ?val where { graph ?:graph { ?:subj ?:pred ?val . filter (isIRI(?val)) } } ) do
            {
              -- dbg_obj_princ ('found {', graph, subj, pred, val, '}');
              if ("val" like 'http://%')
                {
                  -- dbg_obj_princ ('DB.DBA.RDF_GRAB_SEEALSO () aq_request ', vector ("val", '...', env, doc_limit));
                      DB.DBA.RDF_LOG_DEBUG_INFO ('DB.DBA.RDF_GRAB_SEEALSO suggests <%s> due to predicate <%s> in "see-also" graphs', "val", __id2i (pred));
                  --DB.DBA.RDF_GRAB_SINGLE_ASYNC ("val", grabbed, env, doc_limit);
                  aq_request (aq, 'DB.DBA.RDF_GRAB_SINGLE_ASYNC', vector ("val", grabbed, env, doc_limit));
                  if (dict_size (grabbed) > doc_limit)
                    goto out_of_limit;
                }
                  else
                    DB.DBA.RDF_LOG_DEBUG_INFO ('DB.DBA.RDF_GRAB_SEEALSO rejects <%s> inferred via predicate <%s> in "see-also" graphs because it is not of <http://...> format', "val", __id2i (pred));
            }
        }
    }
    }
  if (opt_g is not null)
    {
      foreach (varchar pred in sa_preds) do
        {
          for (sparql define input:storage "" select ?val where { graph ?:opt_g { ?:subj ?:pred ?val . filter (isIRI(?val)) } } ) do
            {
              -- dbg_obj_princ ('found {', opt_g, subj, pred, val, '}');
              if ("val" like 'http://%')
                {
                  -- dbg_obj_princ ('DB.DBA.RDF_GRAB_SEEALSO () aq_request ', vector ("val", '...', env, doc_limit));
                  DB.DBA.RDF_LOG_DEBUG_INFO ('DB.DBA.RDF_GRAB_SEEALSO suggests <%s> due to predicate <%s> in "additional" graph', "val", __id2i (pred));
                  --DB.DBA.RDF_GRAB_SINGLE_ASYNC ("val", grabbed, env, doc_limit);
                  aq_request (aq, 'DB.DBA.RDF_GRAB_SINGLE_ASYNC', vector ("val", grabbed, env, doc_limit));
                  if (dict_size (grabbed) > doc_limit)
                    goto out_of_limit;
                }
              else
                DB.DBA.RDF_LOG_DEBUG_INFO ('DB.DBA.RDF_GRAB_SEEALSO rejects <%s> inferred via predicate <%s> in "additional" graph because it is not of <http://...> format', "val", __id2i (pred));
            }
        }
    }
  flags := get_keyword ('flags', env, 0);
  if (bit_and (1, flags))
    {
      declare subj_iri varchar;
      subj_iri := id_to_iri (subj);
      if (subj_iri like 'http://%')
        {
          -- dbg_obj_princ ('DB.DBA.RDF_GRAB_SEEALSO () aq_request ', vector (subj, '...', env, doc_limit));
          DB.DBA.RDF_LOG_DEBUG_INFO ('DB.DBA.RDF_GRAB_SEEALSO suggests subject <%s> as required by bit 1 of flags %d', subj_iri, flags);
          --DB.DBA.RDF_GRAB_SINGLE_ASYNC (subj, grabbed, env, doc_limit);
          aq_request (aq, 'DB.DBA.RDF_GRAB_SINGLE_ASYNC', vector (subj_iri, grabbed, env, doc_limit));
        }
    }
out_of_limit:
  commit work;
  aq_wait_all (aq);
  DB.DBA.RDF_FT_INDEX_GRABBED (grabbed, env);
  if (dict_size (grabbed) > doc_limit)
    return 4;
  return 2;
}
;

create procedure DB.DBA.RDF_GRAB (
  in app_params any, in grab_params any, in seed varchar, in iter varchar, in final varchar, in ret_limit integer,
  in const_iris any, in depth integer, in plain_ret integer, in uid any )
{
  declare rctr, rcount, colcount, iter_ctr, doc_limit integer;
  declare stat, msg varchar;
  declare sa_graphs, sa_preds, all_params any;
  declare grabbed, metas, rset, aq any;
  RDF_LOG_DEBUG_INFO_RESET ('DB.DBA.RDF_GRAB');
  sa_preds := get_keyword ('sa_preds', grab_params);
  doc_limit := get_keyword ('doc_limit', grab_params, 0hex1000000);
  grab_params := vector_concat (grab_params, vector ('grabbed', dict_new()));
  all_params := vector_concat (vector (grab_params), app_params);
  -- dbg_obj_princ ('DB.DBA.RDF_GRAB (', app_params, grab_params, ',..., ', ret_limit, const_iris, depth, doc_limit, plain_ret, uid, ')');
  DB.DBA.RDF_LOG_DEBUG_INFO ('DB.DBA.RDF_GRAB() begins its work with limit on number of documents set to %d, depth limit is %d', doc_limit, depth);
  aq := async_queue (sys_stat ('enable_qp'));
  grabbed := dict_new ();
  foreach (any val in const_iris) do
    {
      -- dbg_obj_princ ('DB.DBA.RDF_GRAB: const IRI', val);
      if (val is not null and __rgs_ack_cbk (val, uid, 4))
        {
          -- dbg_obj_princ ('DB.DBA.RDF_GRAB () aq_request ', vector (val, '...', grab_params, doc_limit));
          --DB.DBA.RDF_GRAB_SINGLE_ASYNC (val, grabbed, grab_params, doc_limit);
          aq_request (aq, 'DB.DBA.RDF_GRAB_SINGLE_ASYNC', vector (val, grabbed, grab_params, doc_limit));
          if (sa_preds is not null)
            {
              -- dbg_obj_princ ('DB.DBA.RDF_GRAB () grabs seealso for ', val);
              DB.DBA.RDF_GRAB_SEEALSO (val, null, grab_params);
            }
        }
    }
  commit work;
  aq_wait_all (aq);
  commit work;
  DB.DBA.RDF_FT_INDEX_GRABBED (grabbed, grab_params);
  commit work;
  if (dict_size (grabbed) >= doc_limit)
    goto final_exec;
  for (iter_ctr := 0; iter_ctr <= depth; iter_ctr := iter_ctr + 1)
    {
      declare old_doc_count integer;
      declare colctr integer;
      declare col_null_stat, col_nonref_stat any;
      old_doc_count := dict_size (grabbed);
      stat := '00000';
      -- dbg_obj_princ ('DB.DBA.RDF_GRAB ():, will exec with params ', all_params);
      exec (case (iter_ctr) when 0 then seed else iter end, stat, msg, all_params,
        case (isnull (ret_limit)) when 0 then __max (ret_limit, doc_limit, 1000) else null end,
        metas, rset);
      if (stat <> '00000')
        signal (stat, msg);
      rcount := length (rset);
      colcount := length (metas[0]);
      col_null_stat := make_array (colcount, 'any');
      col_nonref_stat := make_array (colcount, 'any');
      -- dbg_obj_princ ('DB.DBA.RDF_GRAB ():, iter ', iter_ctr, '/', depth, ' rset is ', rcount, ' rows * ', colcount, ' cols');
      DB.DBA.RDF_LOG_DEBUG_INFO ('DB.DBA.RDF_GRAB() has executed query on iteration %d, result set is %d rows long', iter_ctr, rcount);
      for (rctr := 0; rctr < rcount; rctr := rctr + 1)
        {
          for (colctr := 0; colctr < colcount; colctr := colctr + 1)
            {
              declare val any;
              declare dest varchar;
              if (dict_size (grabbed) >= doc_limit)
                goto final_exec;
              val := rset[rctr][colctr];
              if (is_named_iri_id (val))
                {
                  if (__rgs_ack_cbk (val, uid, 4))
                {
                  -- dbg_obj_princ ('DB.DBA.RDF_GRAB ():, iter ', iter_ctr, ', row ', rctr, ', col ', colctr, ', vector (', val, '=<', id_to_iri(val), ',..., ', grab_params, doc_limit, ')');
                  --DB.DBA.RDF_GRAB_SINGLE_ASYNC (val, grabbed, grab_params, doc_limit);
                  aq_request (aq, 'DB.DBA.RDF_GRAB_SINGLE_ASYNC', vector (val, grabbed, grab_params, doc_limit));
                  if (dict_size (grabbed) >= doc_limit)
                    goto final_exec;
                  if (sa_preds is not null)
                    {
                      -- dbg_obj_princ ('DB.DBA.RDF_GRAB () grabs seealso for ', val);
                      DB.DBA.RDF_GRAB_SEEALSO (val, null, grab_params);
                    }
                  if (dict_size (grabbed) >= doc_limit)
                        {
                          DB.DBA.RDF_LOG_DEBUG_INFO ('DB.DBA.RDF_GRAB() has reached the limit of number of document IRIs to grab: %d grabbed, limit is %d', dict_size (grabbed), doc_limit);
                    goto final_exec;
                }
            }
                  else
                    DB.DBA.RDF_LOG_DEBUG_INFO ('No sponge permission on value "%s" of variable "%s"', __id2i (val), metas[0][colctr][0]);
                }
              else if (val is null)
                col_null_stat[colctr] := col_null_stat[colctr] + 1;
              else
                col_nonref_stat[colctr] := col_nonref_stat[colctr] + 1;
            }
        }
      commit work;
      aq_wait_all (aq);
      commit work;
      for (colctr := 0; colctr < colcount; colctr := colctr + 1)
        {
          if (col_null_stat[colctr])
             DB.DBA.RDF_LOG_DEBUG_INFO ('Note %d NULL values of variable "%s"', col_null_stat[colctr], metas[0][colctr][0]);
          if (col_nonref_stat[colctr])
             DB.DBA.RDF_LOG_DEBUG_INFO ('Note %d non-IRI values of variable "%s"', col_nonref_stat[colctr], metas[0][colctr][0]);
        }
      DB.DBA.RDF_FT_INDEX_GRABBED (grabbed, grab_params);
      commit work;
      if (old_doc_count = dict_size (grabbed))
        {
          -- dbg_obj_princ ('DB.DBA.RDF_GRAB () has reached a stable point with ', old_doc_count, ' grabbed docs');
          DB.DBA.RDF_LOG_DEBUG_INFO ('DB.DBA.RDF_GRAB() has reached a stable point with %d distinct document IRIs at iteration step %d. No need in further iterations.', dict_size (grabbed), iter_ctr);
        goto final_exec;
    }
      DB.DBA.RDF_LOG_DEBUG_INFO ('DB.DBA.RDF_GRAB() iteration is done with %d document IRIs (was %d)', dict_size (grabbed), old_doc_count);
    }

final_exec:
  stat := '00000';
  exec (final, stat, msg, app_params, ret_limit, metas, rset);
  if (stat <> '00000')
    signal (stat, msg);
  if (plain_ret)
    return rset[0][0];
  rcount := length (rset);
  result_names (rset);
  for (rctr := 0; rctr < rcount; rctr := rctr + 1)
    result (rset[rctr]);
}
;

create function DB.DBA.RDF_GRAB_RESOLVER_DEFAULT (in base varchar, in rel_uri varchar, out abs_uri varchar, out dest_uri varchar, out get_method varchar)
{
  declare rel_lattice_pos, base_lattice_pos integer;
  declare lattice_tail varchar;
  if (__tag of UNAME = __tag (rel_uri))
    rel_uri := cast (rel_uri as varchar);
  if (__tag of UNAME = __tag (base))
    base := cast (base as varchar);
  rel_lattice_pos := strrchr (rel_uri, '#');
  lattice_tail := '';
  if (rel_lattice_pos is not null)
    {
      lattice_tail := subseq (rel_uri, rel_lattice_pos);
      rel_uri := subseq (rel_uri, 0, rel_lattice_pos);
    }
  if ((base is not null) and (base <> ''))
    {
      base_lattice_pos := strrchr (cast (base as varchar), '#');
      if (base_lattice_pos is not null)
        {
          if ('' = lattice_tail)
            lattice_tail := subseq (base, base_lattice_pos);
          base := subseq (base, 0, base_lattice_pos);
        }
    }
  else
    base := '';
  if (base = '')
    abs_uri := rel_uri;
  else
    abs_uri := XML_URI_RESOLVE_LIKE_GET (base, rel_uri);
  dest_uri := abs_uri;
  if (abs_uri like '%/')
    get_method := 'GET+MGET';
  else
    get_method := 'GET';
  -- dbg_obj_princ ('DB.DBA.RDF_GRAB_RESOLVER_DEFAULT (', base, rel_uri, ', ...) sets ', abs_uri, dest_uri, get_method);
}
;



-----
-- Procedures to execute local SPARQL statements (obsolete, now SPARQL can be simply inlined in SQL)

create procedure DB.DBA.SPARQL_EVAL_TO_ARRAY (in query varchar, in dflt_graph varchar, in maxrows integer)
{
  declare state, msg varchar;
  declare metas, rset any;
  if (dflt_graph is not null)
    query := concat ('sparql { define input:default-graph-uri <', dflt_graph, '> ', query, '\n}');
  else
    query := concat ('sparql { ', query, '\n}');
  state := '00000';
  metas := null;
  rset := null;
  exec (query, state, msg, vector(), maxrows, metas, rset);
  -- dbg_obj_princ ('exec metas=', metas);
  if (state <> '00000')
    signal (state, msg);
  return rset;
}
;

create procedure DB.DBA.SPARQL_EVAL (in query varchar, in dflt_graph varchar, in maxrows integer)
{
  declare sqltext, state, msg varchar;
  declare metas, rset any;
  if (dflt_graph is not null)
    query := concat ('sparql { define input:default-graph-uri <', dflt_graph, '> ', query, '\n}');
  else
    query := concat ('sparql { ', query, '\n}');
  state := '00000';
  metas := null;
  rset := null;
  exec (query, state, msg, vector(), maxrows, metas, rset);
  if (state <> '00000')
    signal (state, msg);
  -- dbg_obj_princ ('exec metas=', metas);
  if (metas is not null)
    {
      exec_result_names (metas[0]);
      foreach (any row in rset) do
	{
	  exec_result (row);
	}
    }
}
;


-----
-- Resource sponge

create table DB.DBA.SYS_HTTP_SPONGE (
  HS_LOCAL_IRI varchar not null,
  HS_PARSER varchar not null,
  HS_ORIGIN_URI varchar not null,
  HS_ORIGIN_LOGIN varchar,
  HS_LAST_LOAD datetime,
  HS_LAST_ETAG varchar,
  HS_LAST_READ datetime,
  HS_EXP_IS_TRUE integer,
  HS_EXPIRATION datetime,
  HS_LAST_MODIFIED datetime,
  HS_DOWNLOAD_SIZE integer,
  HS_DOWNLOAD_MSEC_TIME integer,
  HS_READ_COUNT integer,
  HS_SQL_STATE varchar,
  HS_SQL_MESSAGE varchar,
  HS_FROM_IRI varchar,
  HS_QUALITY double precision,
  HS_NOTE varchar,
  primary key (HS_LOCAL_IRI, HS_PARSER)
)
alter index SYS_HTTP_SPONGE on DB.DBA.SYS_HTTP_SPONGE partition (HS_LOCAL_IRI varchar)
create not null index SYS_HTTP_SPONGE_EXPIRATION on DB.DBA.SYS_HTTP_SPONGE (HS_EXPIRATION desc) partition (HS_LOCAL_IRI varchar)
create index SYS_HTTP_SPONGE_FROM_IRI on DB.DBA.SYS_HTTP_SPONGE (HS_FROM_IRI, HS_PARSER) partition (HS_FROM_IRI varchar)
create index SYS_HTTP_SPONGE_ORIGIN_URI on DB.DBA.SYS_HTTP_SPONGE (HS_ORIGIN_URI) partition (HS_ORIGIN_URI varchar)
;

alter table DB.DBA.SYS_HTTP_SPONGE add HS_NOTE varchar
;

create table DB.DBA.SYS_HTTP_SPONGE_REFRESH_DEFAULTS (
  HSRD_DATA_SOURCE_URI_PATTERN varchar not null,
  HSRD_DEFAULT_REFRESH_INTERVAL_SECS integer,
  primary key (HSRD_DATA_SOURCE_URI_PATTERN)
)
;

alter table DB.DBA.SYS_HTTP_SPONGE add HS_NOTE varchar
;

create table DB.DBA.SYS_HTTP_SPONGE_REFRESH_DEFAULTS (
  HSRD_DATA_SOURCE_URI_PATTERN varchar not null,
  HSRD_DEFAULT_REFRESH_INTERVAL_SECS integer,
  primary key (HSRD_DATA_SOURCE_URI_PATTERN)
)
;


create table DB.DBA.RDF_WEBID_ACL_GROUPS (
	AG_WEBID varchar,
	AG_GROUP varchar,
primary key (AG_WEBID, AG_GROUP)
)
;

create procedure DB.DBA.SYS_HTTP_SPONGE_GET_CACHE_PARAMS
   (
    in explicit_refresh any,
    in old_last_modified any,
    inout ret_hdr any,
    inout new_expiration any,
    out ret_content_type any,
    out ret_etag any,
    out ret_date any,
    out ret_expires any,
    out ret_last_modif any,
    out ret_dt_date any,
    out ret_dt_expires any,
    out ret_dt_last_modified any
   )
{
  declare ret_304_not_modified int;

  ret_304_not_modified := 0;
  if (ret_hdr[0] like 'HTTP%304%')
    {
      ret_304_not_modified := 1;
    }

  ret_content_type := http_request_header (ret_hdr, 'Content-Type', null, null);
  ret_etag := http_request_header (ret_hdr, 'ETag', null, null);
  ret_date := http_request_header (ret_hdr, 'Date', null, null);
  ret_expires := http_request_header (ret_hdr, 'Expires', null, null);
  ret_last_modif := http_request_header (ret_hdr, 'Last-Modified', null, null);
  ret_dt_date := http_string_date (ret_date, NULL, NULL);
  ret_dt_expires := http_string_date (ret_expires, NULL, now());
  ret_dt_last_modified := http_string_date (ret_last_modif, NULL, now());
  -- if no cache directive we say it is now
  if (http_request_header (ret_hdr, 'Pragma', null, null) = 'no-cache' or http_request_header (ret_hdr, 'Cache-Control', null, null) like 'no-cache%' )
    {
    ret_dt_expires := now ();
      ret_etag := null;
    }
  -- if not modified and no last given we take old last modified
  if (ret_304_not_modified and ret_dt_last_modified is null)
    ret_dt_last_modified := old_last_modified;
  -- if we have date given
  if (ret_dt_date is not null)
    {
      -- we calculate on which date it expiry
      if (ret_dt_expires is not null)
        ret_dt_expires := dateadd ('second', datediff ('second', ret_dt_date, now()), ret_dt_expires);
      -- if we have last modified we calculate based on date given
      if (ret_dt_last_modified is not null)
        ret_dt_last_modified := dateadd ('second', datediff ('second', ret_dt_date, now()), ret_dt_last_modified);
    }
  -- if we have expires and it is less tand date we reset to null
  if (ret_dt_expires is not null and
    (ret_dt_expires < coalesce (ret_dt_date, ret_dt_last_modified, now ())) )
    ret_dt_expires := NULL;
  -- new expiration is expires date if not null
  if (ret_dt_expires is not null)
    new_expiration := ret_dt_expires;
  else
    {
      -- we have date and last modified but not expires, so we calculate based on date and modified date
      if (ret_dt_date is not null and ret_dt_last_modified is not null and (ret_dt_date >= ret_dt_last_modified))
        new_expiration := dateadd ('second',
		__min (
		   3600 * 24 * 7,
		   0.7 * datediff ('second', ret_dt_last_modified, ret_dt_date)
		 ),
		now());
    }
  if (ret_304_not_modified)
    {
      -- if not modified and we have explicit refresh, we use explicit
      if (new_expiration is null and explicit_refresh is not null)
        new_expiration := dateadd ('second', 0.7 * explicit_refresh, now());

      -- we take less from new expiration and expilicit refresh
      if (ret_dt_expires is null and new_expiration is not null and explicit_refresh is not null)
        new_expiration := __min (new_expiration, dateadd ('second', explicit_refresh, now()));
    }
}
;

create procedure DB.DBA.SYS_HTTP_SPONGE_DEP_URL_NOT_CHANGED (in local_iri varchar, in parser varchar, in explicit_refresh int)
{

 for select
       HS_LOCAL_IRI as old_local_iri,
       HS_LAST_LOAD as old_last_load,
       HS_READ_COUNT as old_read_count,
       HS_EXP_IS_TRUE as old_exp_is_true,
       HS_EXPIRATION as old_expiration,
       HS_LAST_MODIFIED as old_last_modified
  from DB.DBA.SYS_HTTP_SPONGE where HS_FROM_IRI = local_iri and HS_PARSER = parser
  do
    {
      -- dbg_obj_princ (' old_expiration=', old_expiration, ' old_exp_is_true=', old_exp_is_true, ' old_last_load=', old_last_load);
      -- dbg_obj_princ ('now()=', now(), ' explicit_refresh=', explicit_refresh);
      if (old_expiration is not null)
	{
	  if ((old_expiration >= now()) and (
		explicit_refresh is null or
		old_exp_is_true or
		(dateadd ('second', explicit_refresh, old_last_load) >= now()) ) )
	    {
	      -- dbg_obj_princ ('not expired, return');
	      update DB.DBA.SYS_HTTP_SPONGE
		  set HS_LAST_READ = now(), HS_READ_COUNT = old_read_count + 1
		  where HS_LOCAL_IRI = old_local_iri and HS_LAST_READ < now();
              commit work;
	    }
	  else
	    {
	      return 0;
	    }
	}
      else -- either other loading is in progress or an recorded error
	{
	  if (old_last_load >= now() and old_expiration is null)
	    {
	      -- dbg_obj_princ ('collision in the air, return');
	      return 0; -- Nobody promised to resolve collisions in the air.
	    }
	}
    }
  return 1;
}
;

create procedure DB.DBA.RDF_HTTP_MAKE_HTTP_REQ (in url varchar, in meth varchar, in req varchar)
{
  declare hf any;
  declare str any;

  hf := rfc1808_parse_uri (url);
  str := meth || ' ' || hf[2] || case when hf[4] <> '' then '?' else '' end || hf[4] || ' HTTP/1.1\r\n' ||
  	 'Host: ' || hf[1] || '\r\n' || req;
  str := replace (str, '\r', '\n');
  str := replace (str, '\n\n', '\n');
  return split_and_decode (str, 0, '\0\0\n');
}
;

create function DB.DBA.SYS_HTTP_SPONGE_UP (in local_iri varchar, in get_uri varchar, in parser varchar, in eraser varchar, in options any)
{
  declare new_origin_uri, new_origin_login, new_last_etag varchar;
  declare old_origin_uri, old_origin_login, old_last_etag varchar;
  declare new_last_load, new_expiration datetime;
  declare old_last_load, old_expiration, old_last_modified datetime;
  declare load_begin_msec, load_end_msec, old_exp_is_true,
    old_download_size, old_download_msec_time, old_read_count,
    new_download_size, explicit_refresh, max_sz integer;
  declare get_method varchar;
  declare get_soft varchar;
  declare get_note varchar;
  declare ret_hdr, immg, req_hdr_arr any;
  declare req_hdr varchar;
  declare ret_body, ret_content_type, ret_etag, ret_last_modified, ret_date, ret_last_modif, ret_expires varchar;
  declare get_proxy varchar;
  declare ret_dt_date, ret_dt_last_modified, ret_dt_expires, expiration, min_expiration datetime;
  declare ret_304_not_modified integer;
  declare parser_rc, max_refresh, default_refresh int;
  declare stat, msg varchar;

  -- dbg_obj_princ ('DB.DBA.SYS_HTTP_SPONGE_UP (', local_iri, get_uri, parser, eraser, options, ')');
  new_origin_uri := cast (get_keyword_ucase ('get:uri', options, get_uri) as varchar);
  new_origin_login := cast (get_keyword_ucase ('get:login', options) as varchar);
  explicit_refresh := get_keyword_ucase ('get:refresh', options);
  get_soft := get_keyword_ucase ('get:soft', options, '');
  get_note := get_keyword_ucase ('get:note', options);
  if (explicit_refresh is null)
    {
      max_refresh := atoi (coalesce (virtuoso_ini_item_value ('SPARQL', 'MaxCacheExpiration'), '-1'));
      default_refresh := (select HSRD_DEFAULT_REFRESH_INTERVAL_SECS from DB.DBA.SYS_HTTP_SPONGE_REFRESH_DEFAULTS where regexp_match (HSRD_DATA_SOURCE_URI_PATTERN, local_iri) is not null);
      if (default_refresh is not null)
	{
	  if (default_refresh >= 0)
        {
	  if (max_refresh >= 0)
	      explicit_refresh := __min (default_refresh, max_refresh);
	    else
	      explicit_refresh := default_refresh;
	  }
	  else if (max_refresh >= 0)
	    explicit_refresh := max_refresh;
	}
      else if (max_refresh >= 0)
	explicit_refresh := max_refresh;
    }
  else if (isstring (explicit_refresh))
    explicit_refresh := atoi (explicit_refresh);
  min_expiration := atoi (coalesce (virtuoso_ini_item_value ('SPARQL', 'MinExpiration'), '-1'));
  if (min_expiration < 0)
    min_expiration := null;
  set isolation='serializable';
  whenever not found goto add_new_origin;
  select HS_ORIGIN_URI, HS_ORIGIN_LOGIN, HS_LAST_LOAD, HS_LAST_ETAG,
    HS_EXP_IS_TRUE, HS_EXPIRATION, HS_LAST_MODIFIED,
    HS_DOWNLOAD_SIZE, HS_DOWNLOAD_MSEC_TIME, HS_READ_COUNT
  into old_origin_uri, old_origin_login, old_last_load, old_last_etag,
    old_exp_is_true, old_expiration, old_last_modified,
    old_download_size, old_download_msec_time, old_read_count
  from DB.DBA.SYS_HTTP_SPONGE where HS_LOCAL_IRI = local_iri and HS_PARSER = parser for update;

  if ((new_origin_uri <> old_origin_uri) and (eraser is not null))
    signal ('RDFXX',
      sprintf ('Can not get-and-cache RDF graph <%.500s> from <%.500s> because is has been loaded from <%.500s>',
        local_iri, new_origin_uri, old_origin_uri) );

  if (coalesce (new_origin_login, '') <> coalesce (old_origin_login, '') and
    old_expiration is not null )
    signal ('RDFXX',
      sprintf ('Can not get-and-cache RDF graph <%.500s> from <%.500s> using %s because is has been loaded using %s',
        local_iri, new_origin_uri,
        case (isnull (new_origin_login)) when 0 then sprintf ('login "%.100s"', new_origin_login) else 'anonymous access' end,
        case (isnull (old_origin_login)) when 0 then sprintf ('login "%.100s"', old_origin_login) else 'anonymous access' end ) );

  -- dbg_obj_princ (' old_expiration=', old_expiration, ' old_exp_is_true=', old_exp_is_true, ' old_last_load=', old_last_load);
  -- dbg_obj_princ ('now()=', now(), ' explicit_refresh=', explicit_refresh, ' max_refresh=', max_refresh, ' default_refresh=', default_refresh,  ' min_expiration=', min_expiration);
  if (eraser is null)
    {
      -- dbg_obj_princ ('will start load w/o expiration check due to NULL eraser (dependant loading)');
      goto perform_actual_load;
    }
  if (old_expiration is not null)
    {
      if ((old_expiration >= now() and (old_exp_is_true or old_last_etag is null) and explicit_refresh is null) or
	 (explicit_refresh is not null and dateadd ('second', explicit_refresh, old_last_load) >= now()))
        {
          -- dbg_obj_princ ('not expired, return');
          update DB.DBA.SYS_HTTP_SPONGE
          set HS_LAST_READ = now(), HS_READ_COUNT = old_read_count + 1, HS_NOTE = get_note
          where HS_LOCAL_IRI = local_iri and HS_LAST_READ < now();
          commit work;
	  return local_iri;
        }
    }
  else -- either other loading is in progress or an recorded error
    {
      if (datediff ('hour', old_last_load, now()) >= 1)
        {
          -- dbg_obj_princ ('assuming previous sponge of this resource over 1 hour ago failed part way through');
	  ;
	}
      else
        {
      -- dbg_obj_princ ('collision in the air, return');
      return local_iri; -- Nobody promised to resolve collisions in the air.
    }
    }

update_old_origin:
  -- dbg_obj_princ ('starting update old origin...');
  update DB.DBA.SYS_HTTP_SPONGE
  set HS_LAST_LOAD = now(), HS_LAST_ETAG = NULL, HS_LAST_READ = NULL,
    HS_EXP_IS_TRUE = 0, HS_EXPIRATION = NULL, HS_LAST_MODIFIED = NULL,
    HS_DOWNLOAD_SIZE = NULL, HS_DOWNLOAD_MSEC_TIME = NULL,
    HS_READ_COUNT = 0,
    HS_SQL_STATE = NULL, HS_SQL_MESSAGE = NULL, HS_NOTE = get_note
  where
    HS_LOCAL_IRI = local_iri and HS_PARSER = parser;
  commit work;
  goto perform_actual_load;

add_new_origin:
  -- dbg_obj_princ ('adding new origin...');
  old_origin_uri := NULL; old_origin_login := NULL; old_last_load := NULL; old_last_etag := NULL;
  old_expiration := NULL; old_download_size := NULL; old_download_msec_time := NULL;
  old_exp_is_true := 0; old_read_count := 0; old_last_modified := null;
  insert into DB.DBA.SYS_HTTP_SPONGE (HS_LOCAL_IRI, HS_PARSER, HS_ORIGIN_URI, HS_ORIGIN_LOGIN, HS_LAST_LOAD, HS_NOTE)
  values (local_iri, parser, new_origin_uri, new_origin_login, now(), get_note);
  commit work;
  goto perform_actual_load;

perform_actual_load:
  -- dbg_obj_princ ('performing actual load...');
  new_expiration := NULL;
  new_last_etag := NULL;
  ret_304_not_modified := 0;
  load_begin_msec := msec_time();
  set isolation='committed';
  commit work;
  get_method := cast (get_keyword_ucase ('get:method', options, 'GET') as varchar);
  --!!!TBD: if (get_method in ('MGET', 'GET+MGET')) { ... }
  if (get_method in ('POST', 'GET', 'GET+MGET'))
    {
      declare acc_hdr varchar;
      req_hdr := NULL;
      get_proxy := get_keyword_ucase ('get:proxy', options);
      acc_hdr := trim (get_keyword_ucase ('get:accept', options));
      if (not length (acc_hdr))
	acc_hdr := 'application/rdf+xml; q=1.0, text/rdf+n3; q=0.9, application/rdf+turtle; q=0.5, application/x-turtle; q=0.6, application/turtle; q=0.5, text/turtle; q=1.0, application/xml; q=0.2, */*; q=0.1';
      connection_set ('sparql-get:proxy', get_proxy);
      --!!!TBD: proper support for POST
      --!!!TBD: proper authentication if get:login / get:password is provided.
      --!!! XXX: if authentication is needed then better to use http_client() instead of http_get
      if (old_last_etag is not null and explicit_refresh is null)
        req_hdr := 'If-None-Match: ' || old_last_etag;
      else if (old_last_load is not null and explicit_refresh is null)
        req_hdr := 'If-Modified-Since: ' || DB.DBA.date_rfc1123 (old_last_load);
      -- content negotiation
      -- Here we tell to the remote party we want rdf in some form, if it supports content negotiation
      -- then it may return rdf instead of html
      req_hdr := req_hdr || case when length (req_hdr) > 0 then '\r\n' else '' end
        || 'User-Agent: OpenLink Virtuoso RDF crawler\r\n'
	|| 'Accept: ' || acc_hdr;
	--|| 'Accept: application/rdf+xml, text/rdf+n3, application/rdf+turtle, application/x-turtle, application/turtle, application/xml, */*';
      -- dbg_obj_princ (get_method, ' method with ', req_hdr);
      {
        declare mtd, new_origin_uri_save varchar;
        declare exit handler for sqlstate '*' {
          -- dbg_obj_princ ('Error receiving response for <', new_origin_uri, '>: ', __SQL_STATE, ': ', __SQL_MESSAGE);
	  delete from DB.DBA.SYS_HTTP_SPONGE where HS_LOCAL_IRI = local_iri and HS_PARSER = parser;
	  commit work;
	  resignal;
	};
	new_origin_uri_save := new_origin_uri;
        if (get_method = 'GET+MGET')
          mtd := 'GET';
        else
          mtd := get_method;
        ret_body := DB.DBA.RDF_HTTP_URL_GET (new_origin_uri, '', ret_hdr, mtd, req_hdr, NULL, get_proxy, 0);
        -- dbg_obj_princ ('http_get for <', new_origin_uri, '> returned header: ', ret_hdr);
	if (new_origin_uri <> new_origin_uri_save)
	  {
	    declare pos int;
	    pos := position ('http-redirect-to', options);
	    if (pos > 0)
	      options[pos-1] := new_origin_uri;
	    else
	      options := vector_concat (options, vector ('http-redirect-to', new_origin_uri));
	  }
	new_origin_uri := new_origin_uri_save;
      }
      if (ret_hdr[0] like 'HTTP%404%')
        {
	  delete from DB.DBA.SYS_HTTP_SPONGE where HS_LOCAL_IRI = local_iri and HS_PARSER = parser;
	  commit work;
          signal ('HT404', sprintf ('Resource "%.1000s" not found', new_origin_uri));
	}
      if (ret_hdr[0] like 'HTTP%304%')
        {
          ret_304_not_modified := 1;
          goto resp_received;
        }
      if (ret_hdr[0] like 'HTTP/1._ 5__ %' or ret_hdr[0] like 'HTTP/1._ 4__ %')
	{
	  rollback work;
	  update DB.DBA.SYS_HTTP_SPONGE
	      set HS_SQL_STATE = 'RDFXX',
	      HS_SQL_MESSAGE = sprintf ('Unable to retrieve data from "%.500s": %.500s', new_origin_uri, ret_hdr[0]),
	      HS_EXPIRATION = now (),
	      HS_EXP_IS_TRUE = 0,
	      HS_NOTE = get_note
		  where
		  HS_LOCAL_IRI = local_iri and HS_PARSER = parser;
	  commit work;
	  signal ('RDFXX', sprintf ('Unable to retrieve data from "%.500s": %.500s', new_origin_uri, ret_hdr[0]));
	}
      goto resp_received;
    }
  if (eraser is not null and (get_soft <> 'add'))
    {
      -- dbg_obj_princ ('Unsupported method so call (eraser=', eraser, ') (', local_iri, new_origin_uri, options, ')');
      call (eraser) (local_iri, new_origin_uri, options);
    }
  signal ('RDFZZ', sprintf (
      'Unable to get data from "%.1000s": This version of Virtuoso does not support OPTION (get:method "%.100s")',
         new_origin_uri, get_method ) );

resp_received:
--- resolve the caching params
   DB.DBA.SYS_HTTP_SPONGE_GET_CACHE_PARAMS (explicit_refresh, old_last_modified, ret_hdr, new_expiration,
       ret_content_type, ret_etag, ret_date, ret_expires, ret_last_modif,
       ret_dt_date, ret_dt_expires, ret_dt_last_modified);

  if (ret_304_not_modified)
    {
      update DB.DBA.SYS_HTTP_SPONGE
      set HS_LAST_LOAD = now(), HS_LAST_ETAG = old_last_etag, HS_LAST_READ = now(),
        HS_EXP_IS_TRUE = case (isnull (ret_dt_expires)) when 1 then 0 else 1 end,
        HS_EXPIRATION = coalesce (ret_dt_expires, new_expiration, now()),
        HS_LAST_MODIFIED = coalesce (old_last_modified, ret_dt_last_modified),
        HS_DOWNLOAD_SIZE = old_download_size,
        HS_DOWNLOAD_MSEC_TIME = old_download_msec_time,
        HS_READ_COUNT = old_read_count + 1,
        HS_SQL_STATE = NULL, HS_SQL_MESSAGE = NULL, HS_NOTE = get_note
      where
        HS_LOCAL_IRI = local_iri;
      commit work;
      return local_iri;
    }
  if (ret_body is null)
    {
      rollback work;
      update DB.DBA.SYS_HTTP_SPONGE
	  set HS_SQL_STATE = 'RDFXX',
	  HS_SQL_MESSAGE = sprintf ('Unable to retrieve data from "%.500s": %.500s', new_origin_uri, ret_hdr[0]),
	  HS_EXPIRATION = now (),
	  HS_EXP_IS_TRUE = 0, HS_NOTE = get_note
	      where
	      HS_LOCAL_IRI = local_iri and HS_PARSER = parser;
      commit work;
      signal ('RDFXX', sprintf ('Unable to retrieve data from "%.500s": %.500s', new_origin_uri, ret_hdr[0]));
    }
  --!!!TBD: proper character set handling in response
  new_download_size := length (ret_body);

  max_sz := atoi (coalesce (virtuoso_ini_item_value ('SPARQL', 'MaxDataSourceSize'), '20971520'));

  if (max_sz < new_download_size)
    {
      rollback work;
      update DB.DBA.SYS_HTTP_SPONGE
	  set HS_SQL_STATE = 'RDFXX',
	  HS_SQL_MESSAGE = sprintf ('Content length %d is over the limit %d', new_download_size, max_sz),
	  HS_EXPIRATION = now (),
	  HS_EXP_IS_TRUE = 0, HS_NOTE = get_note
	      where
	      HS_LOCAL_IRI = local_iri and HS_PARSER = parser;
      commit work;
      signal ('RDFXX', sprintf ('Content length %d is over the limit %d', new_download_size, max_sz));
    }

  --if (__tag (ret_body) = 185)
  --  ret_body := string_output_string (subseq (ret_body, 0, 10000000));

  {
  whenever sqlstate '*' goto error_during_load;
  parser_rc := 0;
  req_hdr_arr := DB.DBA.RDF_HTTP_MAKE_HTTP_REQ (new_origin_uri, get_method, req_hdr);
  if (eraser is not null and (get_soft <> 'add'))
    {
      -- dbg_obj_princ ('Before actual parser so call (eraser=', eraser, ') (', local_iri, new_origin_uri, options, ')');
      call (eraser) (local_iri, new_origin_uri, options);
    }
  parser_rc := call (parser) (local_iri, new_origin_uri, ret_content_type, ret_hdr, ret_body, options, req_hdr_arr);
  -- dbg_obj_princ (parser, ' returned ', parser_rc, ' to SYS_HTTP_SPONGE_UP()');
  if (parser_rc is not null)
    {
      new_last_etag := ret_etag;
      if (__tag (parser_rc) = 193 and eraser is not null and ret_content_type like '%html')
        {
          declare sa any;
          sa := get_keyword ('seeAlso', parser_rc);
          foreach (varchar dep in sa) do
            {
              DB.DBA.SYS_HTTP_SPONGE_UP (local_iri, dep, parser, NULL, options);
            }
        }
    }
  else
    new_last_etag := null;

  load_end_msec := msec_time();
  if (new_expiration is null)
    new_expiration := dateadd ('second', load_end_msec - load_begin_msec, now()); -- assuming that expiration is at least 1000 times larger than load time.
  if (ret_dt_expires is null and explicit_refresh is not null)
    new_expiration := __min (new_expiration, dateadd ('second', 0.7 * explicit_refresh, now()));
  expiration := coalesce (ret_dt_expires, new_expiration, now());
  if (explicit_refresh is null and min_expiration is not null)
    expiration := __max (dateadd ('second', min_expiration, now()), expiration);
  commit work;
  update DB.DBA.SYS_HTTP_SPONGE
  set HS_LAST_LOAD = now(), HS_LAST_ETAG = new_last_etag, HS_LAST_READ = now(),
    HS_EXP_IS_TRUE = case (isnull (ret_dt_expires)) when 1 then 0 else 1 end,
    HS_EXPIRATION = expiration,
    HS_LAST_MODIFIED = ret_dt_last_modified,
    HS_DOWNLOAD_SIZE = new_download_size,
    HS_DOWNLOAD_MSEC_TIME = load_end_msec - load_begin_msec,
    HS_READ_COUNT = 1,
    HS_SQL_STATE = NULL, HS_SQL_MESSAGE = NULL, HS_NOTE = get_note
  where
    HS_LOCAL_IRI = local_iri and HS_PARSER = parser;
  commit work;
  return local_iri;
  }

error_during_load:
  rollback work;
  -- dbg_obj_princ ('error during load: ', __SQL_STATE, __SQL_MESSAGE);
  stat := __SQL_STATE;
  msg := __SQL_MESSAGE;
  load_end_msec := msec_time();
  if (new_expiration is null)
    new_expiration := dateadd ('second', load_end_msec - load_begin_msec, now());
  if (ret_dt_expires is null and explicit_refresh is not null)
    new_expiration := __min (new_expiration, dateadd ('second', 0.7 * explicit_refresh, now()));

  update DB.DBA.SYS_HTTP_SPONGE
  set HS_SQL_STATE = stat,
    HS_SQL_MESSAGE = msg,
    HS_EXPIRATION = coalesce (ret_dt_expires, new_expiration, now()),
    HS_EXP_IS_TRUE = case (isnull (ret_dt_expires)) when 1 then 0 else 1 end,
    HS_NOTE = get_note
  where
    HS_LOCAL_IRI = local_iri and HS_PARSER = parser;
  commit work;
  -- dbg_obj_princ ('DB.DBA.SYS_HTTP_SPONGE_UP logged ', stat, msg, local_iri, parser, ', get:error-recovery is ', get_keyword_ucase ('get:error-recovery', options));
  if (get_keyword_ucase ('get:error-recovery', options) is not null)
    signal (stat, msg);
  return local_iri;
}
;

-- /* handle local files */

create function DB.DBA.SYS_FILE_SPONGE_UP (in local_iri varchar, in get_uri varchar, in parser varchar, in eraser varchar, in options any)
{
  declare new_origin_uri, str, base_uri, mime_type, dummy, tmp any;
  declare inx int;
  declare get_soft varchar;
  new_origin_uri := cast (get_keyword_ucase ('get:uri', options, get_uri) as varchar);
  get_soft := get_keyword_ucase ('get:soft', options, '');
  inx := 5;
  base_uri := new_origin_uri;
  base_uri := charset_recode (base_uri, 'UTF-8', NULL);
  while (length (base_uri) > inx + 1 and aref (base_uri, inx) = ascii ('/'))
    inx := inx + 1;
  if (inx = 8) -- i.e., it is 'file:///'
    str := file_to_string (subseq (base_uri, inx-1));
  else
  str := file_to_string (concat (http_root(), '/' , subseq (base_uri, inx)));
  dummy := vector ();
  tmp := vector ('OK');
  mime_type := null;
  if (eraser is not null and (get_soft <> 'add'))
    call (eraser) (local_iri, new_origin_uri, options);
  DB.DBA.RDF_LOAD_HTTP_RESPONSE (local_iri, new_origin_uri, mime_type, tmp, str, options, dummy);
  return local_iri;
}
;

create function DB.DBA.RDF_SPONGE_TRY_TTL (in mode integer, inout txt varchar) returns varchar
{
  declare msg varchar;
  declare app_env any;
  declare cr_pos integer;
  -- dbg_obj_princ ('DB.DBA.RDF_SPONGE_TRY_TTL (', mode, txt, ')');
  whenever sqlstate '*' goto err;
  DB.DBA.TTLP_VALIDATE (txt, '', 'dummy', mode);
  -- dbg_obj_princ ('-- no error');
  return '';
err:
  msg := __SQL_STATE || __SQL_MESSAGE;
  -- dbg_obj_princ ('--', msg);
  cr_pos := strchr (msg, '\n');
  if (cr_pos is null)
    return msg;
  return subseq (msg, 0, cr_pos);
}
;

create function DB.DBA.RDF_SPONGE_GUESS_TTL_CONTENT_TYPE (in origin_uri varchar, in ret_content_type varchar, inout ret_body any, inout ret_begin any) returns varchar
{
  declare shorter_ret_begin varchar;
  declare last_cr_pos integer;
  declare ctr integer;
  declare msg, s_msg varchar;
  shorter_ret_begin := ret_begin;
  for (ctr := 0; ctr < 3; ctr := ctr+1)
    {
      last_cr_pos := strrchr (shorter_ret_begin, 0hexA);
      if (last_cr_pos is null)
        goto no_cr;
      shorter_ret_begin := subseq (shorter_ret_begin, 0, last_cr_pos);
    }
no_cr:
  -- dbg_obj_princ ('DB.DBA.RDF_SPONGE_GUESS_TTL_CONTENT_TYPE: shorter_ret_begin=', shorter_ret_begin);
  msg := DB.DBA.RDF_SPONGE_TRY_TTL (0, ret_begin);
  if ('' = msg)
    return 'text/turtle';
  if (last_cr_pos is not null and DB.DBA.RDF_SPONGE_TRY_TTL (0, shorter_ret_begin) <> msg)
    return 'text/turtle';
  msg := DB.DBA.RDF_SPONGE_TRY_TTL (512, ret_begin);
  if ('' = msg)
    return 'text/x-nquads';
  if (last_cr_pos is not null and DB.DBA.RDF_SPONGE_TRY_TTL (512, shorter_ret_begin) <> msg)
    return 'text/x-nquads';
  msg := DB.DBA.RDF_SPONGE_TRY_TTL (256, ret_begin);
  if ('' = msg)
    return 'application/x-trig';
  if (last_cr_pos is not null and DB.DBA.RDF_SPONGE_TRY_TTL (256, shorter_ret_begin) <> msg)
    return 'application/x-trig';
  if (ret_content_type is null or
    strstr (ret_content_type, 'text/plain') is not null or
    strstr (ret_content_type, 'application/octet-stream') is not null )
    {
      declare ret_lines any;
      declare ret_lcount, ret_lctr integer;
      ret_lines := split_and_decode (ret_begin, 0, '\0\t\n');
      ret_lcount := length (ret_lines);
      for (ret_lctr := 0; ret_lctr < ret_lcount; ret_lctr := ret_lctr + 1)
        {
          declare l varchar;
          l := rtrim (replace (ret_lines [ret_lctr], '\r', ''));
          -- dbg_obj_princ ('l = ', l);
          if (("LEFT" (l, 7) = '@prefix') or ("LEFT" (l, 5) = '@base') or ("LEFT" (l, 8) = '@keyword'))
            return 'text/turtle';
          if ((("LEFT" (l, 1) = '<') or ("LEFT" (l, 1) = '[')) and 
            (
             "RIGHT" (origin_uri, 4) in ('.ttl', '.TTL')
            ))
            return 'text/turtle';
          if ((("LEFT" (l, 1) = '<') or ("LEFT" (l, 1) = '[')) and 
            (
             "RIGHT" (origin_uri, 3) in ('.n3', '.N3', '.nt', '.NT')
            ))
            return 'text/rdf+n3';
          if (not ((l like '#%') or (l='')))
            return 'text/plain';
        }
    }
  return null;
}
;


-- /* guess the content type */
create function DB.DBA.RDF_SPONGE_GUESS_CONTENT_TYPE (in origin_uri varchar, in ret_content_type varchar, inout ret_body any) returns varchar
{
  declare guessed_ret_type varchar;
  -- dbg_obj_princ ('DB.DBA.RDF_SPONGE_GUESS_CONTENT_TYPE (', origin_uri, ret_content_type, '...)');
  if (ret_content_type is not null)
    {
      if (strstr (ret_content_type, 'application/sparql-results+xml') is not null)
        return 'application/sparql-results+xml';
      if (strstr (ret_content_type, 'application/rdf+xml') is not null)
        return 'application/rdf+xml';
      if (strstr (ret_content_type, 'text/rdf+ttl') is not null or
        strstr (ret_content_type, 'text/rdf+turtle') is not null or
        strstr (ret_content_type, 'text/turtle') is not null or
        strstr (ret_content_type, 'application/x-turtle') is not null or
        strstr (ret_content_type, 'application/turtle') is not null )
        return 'text/turtle';
      if (strstr (ret_content_type, 'text/n3') is not null or
        strstr (ret_content_type, 'text/rdf+n3') is not null )
        return 'text/rdf+n3';
      if (strstr (ret_content_type, 'application/x-trig') is not null)
        return 'application/x-trig';
      if (strstr (ret_content_type, 'text/x-nquads') is not null)
        return 'text/x-nquads';
    }
  declare ret_begin, ret_html any;
  ret_begin := subseq (ret_body, 0, 65535);
  if (isstring_session (ret_begin))
    ret_begin := string_output_string (ret_begin);
  -- dbg_obj_princ ('DB.DBA.RDF_SPONGE_GUESS_CONTENT_TYPE: ret_begin = ', ret_begin);
  ret_html := xtree_doc (ret_begin, 2);
  -- dbg_obj_princ ('DB.DBA.RDF_SPONGE_GUESS_CONTENT_TYPE: ret_html = ', ret_html);
  if (xpath_eval ('[xmlns:xh="http://www.w3.org/1999/xhtml"] /html|/xhtml|/xh:html|/xh:xhtml', ret_html) is not null)
    {
      if (xpath_eval ('[xmlns:grddl="http://www.w3.org/2003/g/data-view#"] /*/@grddl:transformation', ret_html) is not null)
        return 'text/html'; -- GRDDL stylesheet is most authoritative
      if (xpath_eval ('/*/head/@profile', ret_html) is not null)
        return 'text/html'; -- GRDDL inline profile is authoritative, too
      if (xpath_eval ('//*[exists(@itemscope) or exists(@itemprop) or exists(@itemid) or exists(@itemtype)]', ret_html) is not null)
        return 'text/microdata+html'; -- Microdata are tested before RDFa because metadata with @rel may be wrongly recognised as RDFa
      -- if (xpath_eval ('//*[exists(@rel) or exists(@rev) or exists(@typeof) or exists(@property) or exists(@about)]', ret_html) is not null)
      if (xpath_eval ('//*[exists(@typeof) or exists(@about)]', ret_html) is not null)
        return 'application/xhtml+xml';
    return 'text/html';
    }
  if (xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] /rset:sparql', ret_html) is not null
    or xpath_eval ('[xmlns:rset2="http://www.w3.org/2001/sw/DataAccess/rf1/result2"] /rset2:sparql', ret_html) is not null)
    return 'application/sparql-results+xml';
  if (xpath_eval ('[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"] /rdf:rdf', ret_html) is not null)
    return 'application/rdf+xml';
  if (strstr (ret_begin, '<html>') is not null or
    strstr (ret_begin, '<xhtml>') is not null )
    return 'text/html';
  guessed_ret_type := DB.DBA.RDF_SPONGE_GUESS_TTL_CONTENT_TYPE (origin_uri, ret_content_type, ret_body, ret_begin);
  if (guessed_ret_type is not null)
    return guessed_ret_type;
  return ret_content_type;
}
;

-- Additional RDF mappers defined elsewhere
create table DB.DBA.SYS_RDF_MAPPERS (
    RM_ID integer identity,		-- an ordered id for execution order
    RM_PATTERN varchar,			-- a LIKE pattern, URL or MIME
    RM_TYPE varchar default 'MIME', 	-- pattern type, MIME or URL
    RM_HOOK varchar,			-- PL hook
    RM_KEY  long varchar,		-- API specific key to use
    RM_DESCRIPTION long varchar,
    RM_ENABLED integer default 1,
    RM_OPTIONS any,
    RM_PID integer identity,		-- permanent id for fk in application tables
    primary key (RM_HOOK))
alter index SYS_RDF_MAPPERS on DB.DBA.SYS_RDF_MAPPERS partition cluster replicated
create index SYS_RDF_MAPPERS_I1 on DB.DBA.SYS_RDF_MAPPERS (RM_ID) partition cluster replicated
create index SYS_RDF_MAPPERS_I2 on DB.DBA.SYS_RDF_MAPPERS (RM_PID) partition cluster replicated
;


create procedure DB.DBA.RDF_HTTP_URL_GET (inout url any, in base any, inout hdr any,
	in meth any := 'GET', in req_hdr varchar := null, in cnt any := null, in proxy any := null, in sig int := 1)
{
  declare content varchar;
  declare olduri, req_hdr_orig varchar;
  --declare hdr any;
  declare redirects, is_https int;
  -- dbg_obj_princ ('DB.DBA.RDF_HTTP_URL_GET (', url, base, ')');

  req_hdr_orig := req_hdr;
  hdr := null;
  redirects := 15;
  url := WS.WS.EXPAND_URL (base, url);
  again:
  olduri := url;
  if (redirects <= 0)
    signal ('22023', 'Too many HTTP redirects', 'RDFXX');

  if (lower (url) like 'https://%' and proxy is not null)
    signal ('22023', 'The HTTPS retrieval is not supported via proxy', 'RDFXX');
  is_https := 0;
  if (lower (url) like 'https://%')
    is_https := 1;

  if (proxy is null)
    content := http_client_ext (url=>url, headers=>hdr, http_method=>meth, http_headers=>req_hdr, body=>cnt);
  else
    content := http_get (url, hdr, meth, req_hdr, cnt, proxy);
  redirects := redirects - 1;

  if (hdr[0] not like 'HTTP/1._ 200 %' and hdr[0] not like 'HTTP/1._ 203 %')
    {
      if (hdr[0] like 'HTTP/1._ 30_ %' and hdr[0] not like 'HTTP/1._ 304 %')
	{
	  url := http_request_header (hdr, 'Location');
	  if (isstring (url))
	    {
	      declare cookie_hdr varchar;
	      url := WS.WS.EXPAND_URL (olduri, url);
	      req_hdr := req_hdr_orig;
	      cookie_hdr := DB.DBA.COOKIE_HDR (olduri, hdr, url);
	      if (length (cookie_hdr))
	        req_hdr := req_hdr || '\r\n' || cookie_hdr;
	      goto again;
	    }
	}
      if (sig)
        signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
      -- dbg_obj_princ ('DB.DBA.RDF_HTTP_URL_GET (', url, base, ') failed to download ', url);
      return NULL;
    }
  -- dbg_obj_princ ('DB.DBA.RDF_HTTP_URL_GET (', url, base, ') downloaded ', url);
  return content;
}
;

-- Extracts Set-Cookie: headers from a source URL's response and builds a corresponding
-- Cookie: request header for the URL being redirected to
create procedure DB.DBA.COOKIE_HDR (in src_url any, in resp_hdrs any, in dest_url any)
{
  declare ua_src, ua_dest, cookies, resp_cookie, cookie_attrs any;
  declare ua_src_domain, ua_src_path, ua_dest_domain, ua_dest_path, req_cookie_hdr, cookie_domain, cookie_path varchar;
  declare valid integer;

  declare exit handler for sqlstate '*'
  {
    return null;
  };

  ua_src := rfc1808_parse_uri (src_url);
  ua_src_domain := ua_src[1];
  if (strcontains (ua_src_domain, ':'))
    ua_src_domain := subseq (ua_src_domain, 0, strchr (ua_src_domain, ':'));
  ua_src_path := ua_src[2];

  ua_dest := rfc1808_parse_uri (dest_url);
  ua_dest_domain := ua_dest[1];
  if (strcontains (ua_dest_domain, ':'))
    ua_dest_domain := subseq (ua_dest_domain, 0, strchr (ua_dest_domain, ':'));
  ua_dest_path := ua_dest[2];

  req_cookie_hdr := null;
  if (length (resp_hdrs) = 0)
    goto done;

  cookies := vector();
  foreach (varchar hdr in resp_hdrs) do
  {
    if (starts_with (hdr, 'Set-Cookie: '))
    {
      resp_cookie := regexp_replace (hdr, 'Set-Cookie: (.+)\r\n', '\\1');
      resp_cookie := regexp_replace (resp_cookie, '; ', ';');
      cookie_attrs := split_and_decode (resp_cookie, 0, '\0\0;=');
      cookies := vector_concat (cookies, vector(cookie_attrs));
    }
  }

  if (length (cookies) = 0)
    goto done;

  req_cookie_hdr := '';
  foreach (any cookie in cookies) do
  {
    -- Assume any expiring cookies are still valid, they've only just been set.
    -- Check the cookies apply to the domain + path being redirected to
    valid := 1;
    cookie_domain := get_keyword ('domain', cookie, ua_src_domain);
    cookie_path :=  get_keyword ('path', cookie, ua_src_path);
    if (length (cookie_domain) and not ends_with (ua_dest_domain, cookie_domain))
      valid := 0;
    if (length (cookie_path) and not starts_with (ua_dest_path, cookie_path))
      valid := 0;
    if (valid)
      req_cookie_hdr := sprintf ('%s %s=%s;', req_cookie_hdr, cookie[0], cookie[1]);
  }

  if (length (req_cookie_hdr))
  {
    req_cookie_hdr := 'Cookie:' || req_cookie_hdr;
    req_cookie_hdr := rtrim (req_cookie_hdr, ';');
  }

done:
  return req_cookie_hdr;
}
;

-- /* async ping of a web service e.g. PTSW */
create procedure DB.DBA.RDF_SW_PING (in endp varchar, in url varchar)
{
  declare rc any;
  declare err, msg any;
  declare xt any;
  commit work;
  declare exit handler for sqlstate '*'
  {
    insert into DB.DBA.SYS_SPARQL_SW_LOG (PL_SERVER, PL_URI, PL_RC, PL_MSG)
	values (endp, url, __SQL_STATE, __SQL_MESSAGE);
    commit work;
    return;
  };

  err := '';
  msg := 'n/a';
  xt := null;
  if (virtuoso_ini_item_value ('SPARQL', 'RestPingService') = '1')
    {
      rc := http_client (url=>endp||sprintf ('?url=%U', url), timeout=>10);
      xt := xtree_doc (rc);
    }
  else
    {
      rc := DB.DBA.XMLRPC_CALL (endp, 'weblogUpdates.ping', vector ('', url));
      if (isarray (rc))
	xt := xml_tree_doc (rc);
    }
  if (xt is not null)
    {
      err := cast (xpath_eval ('//flerror/text()', xml_cut(xt), 1) as varchar);
      msg := cast (xpath_eval ('//message/text()', xml_cut(xt), 1) as varchar);
    }
  insert into DB.DBA.SYS_SPARQL_SW_LOG (PL_SERVER, PL_URI, PL_RC, PL_MSG)
    values (endp, url, err, msg);
--  dbg_obj_print ('DB.DBA.RDF_SW_PING end', endp, ' ', url);
  commit work;
  return;
}
;

create procedure DB.DBA.RDF_PROC_COLS (in pname varchar)
{
  set_user_id ('dba', 1);
  return procedure_cols (pname);
}
;

create function DB.DBA.RDF_PROXY_GET_HTTP_HOST ()
{
    declare default_host, cname, xhost varchar;
    xhost := connection_get ('http_host');
    if (isstring (xhost))
      return xhost;
    if (is_http_ctx ())
        default_host := http_request_header(http_request_header (), 'Host', null, null);
    else if (connection_get ('__http_host') is not null)
        default_host := connection_get ('__http_host');
    else
        default_host := virtuoso_ini_item_value ('URIQA', 'DefaultHost');
    if (default_host is not null)
        cname := default_host;
    else
    {
        cname := sys_stat ('st_host_name');
        if (server_http_port () <> '80')
            cname := cname ||':'|| server_http_port ();
    }
    return cname;
}
;

create procedure DB.DBA.RDF_SPONGE_IRI_SCH ()
{
  declare xproto any;
  xproto := connection_get ('http_proto');
  if (isstring (xproto))
    return xproto;
  if (is_https_ctx ())
    return 'https';
  return 'http';
}
;

--
-- # this one is used to make proxy IRI for primary topic (entity)
--
--!AWK PUBLIC
create procedure DB.DBA.RDF_PROXY_ENTITY_IRI (in uri varchar := '', in login varchar := '', in frag varchar := 'this')
{
    declare cname any;
    declare ret any;
    declare url_sch, local_prx varchar;
    declare ua any;
    cname := DB.DBA.RDF_PROXY_GET_HTTP_HOST ();
    if (frag = 'this' or frag = '#this') -- comment out to do old behaviour
        frag := '';
    if (length (frag) and frag[0] <> '#'[0])
    {
        frag := '#' || sprintf ('%U', frag);
    }
    if (strchr (uri, '#') is not null)
        frag := '';
    --if (http_mime_type (uri) like 'image/%')
    --  return uri;
    local_prx := sprintf ('%s://%s/about/id/entity/', RDF_SPONGE_IRI_SCH (), cname);
    if (starts_with (uri, local_prx))
        return uri;
    ua := rfc1808_parse_uri (uri);
    url_sch := ua[0];
    ua [0] := '';
    uri := vspx_uri_compose (ua);
    uri := ltrim (uri, '/');
    ret := sprintf ('%s://%s/about/id/entity/%s/%s%s', RDF_SPONGE_IRI_SCH (), cname, url_sch, uri, frag);
    return ret;
}
;

--
-- # this is used to make proxy IRI of the document
--

--!AWK PUBLIC
create procedure DB.DBA.RDF_SPONGE_PROXY_IRI(in uri varchar := '', in login varchar := '', in frag varchar := 'this')
{
    declare cname any;
    declare ret any;
    declare url_sch varchar;
    declare ua any;
    cname := DB.DBA.RDF_PROXY_GET_HTTP_HOST ();
    if (frag = 'this' or frag = '#this') -- comment out to do old behaviour
        frag := '';
    if (length (frag) and frag[0] <> '#'[0])
        frag := '#' || sprintf ('%U', frag);
    if (strchr (uri, '#') is not null)
        frag := '';
    --if (http_mime_type (uri) like 'image/%')
    --return uri;
    ua := rfc1808_parse_uri (uri);
    url_sch := ua[0];
    ua [0] := '';
    uri := vspx_uri_compose (ua);
    uri := ltrim (uri, '/');
    if (length (login))
        ret := sprintf ('%s://%s/about/rdf/%s/%U/%s%s', RDF_SPONGE_IRI_SCH (), cname, url_sch, login, uri, frag);
    else
        ret := sprintf ('%s://%s/about/id/%s/%s%s', RDF_SPONGE_IRI_SCH (), cname, url_sch, uri, frag);
    return ret;
}
;

-- Postprocessing for sponging pure RDF sources
create procedure DB.DBA.RDF_LOAD_RDFXML_PP_GENERIC (in contents varchar, in base varchar, in graph varchar, in mimetype varchar :='text/html')
{
  declare proxyiri, docproxyiri, dociri varchar;

  if (__proc_exists ('DB.DBA.RM_SPONGE_DOC_IRI') is null)
    return;

  proxyiri := DB.DBA.RDF_PROXY_ENTITY_IRI (graph);
  docproxyiri := DB.DBA.RDF_SPONGE_PROXY_IRI (graph);
  dociri:=DB.DBA.RM_SPONGE_DOC_IRI(graph);
  
  sparql define input:storage "" 
    define sql:table-option "index G"
    insert in iri(?:graph) { 
      `iri(?:graph)` <http://xmlns.com/foaf/0.1/topic> `iri(sql:XML_URI_RESOLVE_LIKE_GET(?:base, ?s))` .
      `iri(sql:XML_URI_RESOLVE_LIKE_GET(?:base, ?s))` <http://www.w3.org/2007/05/powder-s#describedby> `iri(?:proxyiri)` 
    }
    where { { select distinct ?s 
      where { graph `iri(?:graph)` { ?s ?p ?o .
	filter (iri(sql:XML_URI_RESOLVE_LIKE_GET(?:base, ?s)) != iri(?:graph) && !(regex (?s, '/about/id/http') || regex (?s, '/about/id/entity/http')))
	}
      }
    }
  };
  sparql define input:storage "" 
    define sql:table-option "index G"
    insert in graph iri(?:graph) { 
      `iri(?:docproxyiri)` a <http://purl.org/ontology/bibo/Document> ;
      <http://www.w3.org/ns/formats/media_type> `?:mimetype` ;
      <http://vocab.deri.ie/void#inDataset> `iri(?:graph)` ; 
      <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://rdfs.org/sioc/ns#Container> , <http://purl.org/ontology/bibo/Document> ;
      <http://rdfs.org/sioc/ns#container_of> `iri(?:proxyiri)` .
      `iri(?:dociri)` <http://www.w3.org/2002/07/owl#sameAs> `iri(?:proxyiri)` . 
    };
  if (registry_get ('__rdf_cartridges_add_spongetime__') = '1') {
    sparql define input:storage "" 
      insert in graph iri(?:graph) { 
	`iri(?:graph)` <http://www.openlinksw.com/schema/attribution#sponge_time> `bif:now()` . 
      };
  }
}
;


--! Load the document in triple store. returns 1 if the document is an RDF, otherwise if it has links etc. it returns 0
create procedure DB.DBA.RDF_LOAD_HTTP_RESPONSE (in graph_iri varchar, in new_origin_uri varchar, inout ret_content_type varchar, inout ret_hdr any, inout ret_body any, inout options any, inout req_hdr_arr any)
{
  declare dest, extra, groupdest, get_soft, cset, base, first_stat, first_msg varchar;
  declare rc any;
  declare aq, ps any;
  declare xd, xt any;
  declare saved_log_mode, ttl_mode, only_rdfa, retr_count, rdf_fmt integer;
  aq := null;
  rdf_fmt := 0;
  ps := virtuoso_ini_item_value ('SPARQL', 'PingService');
  if (length (ps))
    {
      aq := async_queue (1);
    }
  -- dbg_obj_princ ('DB.DBA.RDF_LOAD_HTTP_RESPONSE (', graph_iri, new_origin_uri, ret_content_type, ret_hdr, ret_body, options, req_hdr_arr, ')');
  --!!!TBD: proper calculation of new_expiration, using data from HTTP header of the response
  declare l any;
  l := ret_body;
  if (length (l) > 3 and l[0] = 0hexEF and l[1] = 0hexBB and l[2] = 0hexBF) -- remove BOM
    ret_body := subseq (ret_body, 3);
  ret_content_type := DB.DBA.RDF_SPONGE_GUESS_CONTENT_TYPE (new_origin_uri, ret_content_type, ret_body);
  -- dbg_obj_princ ('ret_content_type is ', ret_content_type);
  dest := get_keyword_ucase ('get:destination', options);
  groupdest := get_keyword_ucase ('get:group-destination', options);
  extra := get_keyword_ucase ('get:extra', options, '0');
  base := get_keyword ('http-redirect-to', options, new_origin_uri);
  get_soft := get_keyword_ucase ('get:soft', options);
  if (get_keyword_ucase ('get:strategy', options, 'default') = 'rdfa-only' or get_soft = 'no-sponge')
    only_rdfa := 1;
  else
    only_rdfa := 0;
  if (strstr (ret_content_type, 'application/sparql-results+xml') is not null)
    signal ('RDFXX', sprintf ('Unable to load RDF graph <%.500s> from <%.500s>: the sparql-results XML answer does not contain triples', graph_iri, new_origin_uri));
  if (get_keyword ('http-headers', options) is null)
    options := vector_concat (options, vector ('http-headers', vector (req_hdr_arr, ret_hdr)));
retry_after_deadlock:
  if (strstr (ret_content_type, 'application/rdf+xml') is not null)
    {
      --if (dest is null)
      --  DB.DBA.SPARUL_CLEAR (coalesce (dest, graph_iri), 1);
      declare exit handler for sqlstate '*'
      {
        if (registry_get ('__sparql_mappers_debug') = '1')
          dbg_printf ('%s: SQL_MESSAGE: %s', current_proc_name(), __SQL_MESSAGE);
        goto load_grddl_after_error;
      };
      --log_enable (2, 1);
      xt := xtree_doc (ret_body);
      -- we test for GRDDL inside RDF/XML, if so do it inside mappers, else it will fail because of dv:transformation attr
      if (xpath_eval ('[ xmlns:dv="http://www.w3.org/2003/g/data-view#" ] /*[1]/@dv:transformation', xt) is not null)
        goto load_grddl;
      DB.DBA.RDF_LOAD_RDFXML (ret_body, base, coalesce (dest, graph_iri));
      if (get_soft <> 'no-sponge')
        DB.DBA.RDF_LOAD_RDFXML_PP_GENERIC(ret_body, base, coalesce (dest, graph_iri), ret_content_type);
      rdf_fmt := 1;
      if (groupdest is not null)
        {
          DB.DBA.RDF_LOAD_RDFXML (ret_body, base, groupdest);
	  if (get_soft <> 'no-sponge')
            DB.DBA.RDF_LOAD_RDFXML_PP_GENERIC(ret_body, base, groupdest, ret_content_type);
        }
        goto load_grddl;
      if (__proc_exists ('DB.DBA.RDF_LOAD_POST_PROCESS') and only_rdfa = 0) -- optional step, by default skip
        call ('DB.DBA.RDF_LOAD_POST_PROCESS') (graph_iri, new_origin_uri, dest, ret_body, ret_content_type, options);
      --log_enable (saved_log_mode, 1);
      if (aq is not null)
        aq_request (aq, 'DB.DBA.RDF_SW_PING', vector (ps, new_origin_uri));
      return 1;
    }
  ttl_mode := null;
  if (
    strstr (ret_content_type, 'text/rdf+n3') is not null or
    strstr (ret_content_type, 'text/n3') is not null or
    strstr (ret_content_type, 'text/rdf+ttl') is not null or
    strstr (ret_content_type, 'text/rdf+turtle') is not null or
    strstr (ret_content_type, 'text/turtle') is not null or
    strstr (ret_content_type, 'application/rdf+n3') is not null or
    strstr (ret_content_type, 'application/rdf+turtle') is not null or
    strstr (ret_content_type, 'application/turtle') is not null or
    strstr (ret_content_type, 'application/n-triples') is not null or
    strstr (ret_content_type, 'application/x-turtle') is not null )
    ttl_mode := 255;
  else if (
    strstr (ret_content_type, 'application/x-trig') is not null)
    ttl_mode := 256+255;
  else if (
    strstr (ret_content_type, 'text/x-nquads') is not null)
    ttl_mode := 512+255;
  if (ttl_mode is not null)
    {
      declare exit handler for sqlstate '*'
      {
        if (registry_get ('__sparql_mappers_debug') = '1')
          dbg_printf ('%s: SQL_MESSAGE: %s', current_proc_name(), __SQL_MESSAGE);
        goto load_grddl_after_error;
      };
      --log_enable (2, 1);
      --if (dest is null)
      --  DB.DBA.SPARUL_CLEAR (coalesce (dest, graph_iri), 1);

      DB.DBA.TTLP (ret_body, base, coalesce (dest, graph_iri), ttl_mode);
      if (get_soft <> 'no-sponge')
        DB.DBA.RDF_LOAD_RDFXML_PP_GENERIC(ret_body, base, coalesce (dest, graph_iri), ret_content_type);
      rdf_fmt := 1;

      if (groupdest is not null)
        {
          DB.DBA.TTLP (ret_body, base, groupdest);
          if(get_soft <> 'no-sponge')
            DB.DBA.RDF_LOAD_RDFXML_PP_GENERIC(ret_body, base, groupdest, ret_content_type);
        }
      if (exists (select 1 from DB.DBA.SYS_RDF_MAPPERS where RM_TYPE = 'URL' and regexp_match (RM_PATTERN, new_origin_uri) and RM_ENABLED = 1))
        goto load_grddl;
      if (__proc_exists ('DB.DBA.RDF_LOAD_POST_PROCESS') and only_rdfa = 0) -- optional step, by default skip
        call ('DB.DBA.RDF_LOAD_POST_PROCESS') (graph_iri, new_origin_uri, dest, ret_body, ret_content_type, options);
      --log_enable (saved_log_mode, 1);
      if (aq is not null)
        aq_request (aq, 'DB.DBA.RDF_SW_PING', vector (ps, new_origin_uri));
      return 1;
    }
  else if (strstr (ret_content_type, 'text/microdata+html') is not null)
    {
      declare exit handler for sqlstate '*'
      {
        if (registry_get ('__sparql_mappers_debug') = '1')
          dbg_printf ('%s: SQL_MESSAGE: %s', current_proc_name(), __SQL_MESSAGE);
        goto load_grddl_after_error;
      };
      --log_enable (2, 1);
      --DB.DBA.RDF_LOAD_XHTML_MICRODATA (ret_body, base, coalesce (dest, graph_iri));
      rdf_fmt := 1;
      if (groupdest is not null and groupdest <> coalesce (dest, graph_iri))
        DB.DBA.RDF_LOAD_XHTML_MICRODATA (ret_body, base, groupdest);
      if (exists (select 1 from DB.DBA.SYS_RDF_MAPPERS where (RM_TYPE = 'URL' and regexp_match (RM_PATTERN, new_origin_uri) or
                 RM_TYPE='MIME' and regexp_match(RM_PATTERN, ret_content_type)) and RM_ENABLED = 1))
        goto load_grddl;
      if (__proc_exists ('DB.DBA.RDF_LOAD_POST_PROCESS') and only_rdfa = 0) -- optional step, by default skip
        call ('DB.DBA.RDF_LOAD_POST_PROCESS') (graph_iri, new_origin_uri, dest, ret_body, ret_content_type, options);
      --log_enable (saved_log_mode, 1);
      if (aq is not null)
        aq_request (aq, 'DB.DBA.RDF_SW_PING', vector (ps, new_origin_uri));
      return 1;
    }
  else if (only_rdfa = 1 and (strstr (ret_content_type, 'text/html') is not null or strstr (ret_content_type, 'application/xhtml+xml') is not null))
    {
      declare exit handler for sqlstate '*'
      {
        if (registry_get ('__sparql_mappers_debug') = '1')
          dbg_printf ('%s: SQL_MESSAGE: %s', current_proc_name(), __SQL_MESSAGE);
        goto load_grddl_after_error;
      };
      --log_enable (2, 1);
      DB.DBA.RDF_LOAD_RDFA (ret_body, base, coalesce (dest, graph_iri));
      rdf_fmt := 1;
      if (groupdest is not null and groupdest <> coalesce (dest, graph_iri))
        DB.DBA.RDF_LOAD_RDFA (ret_body, base, groupdest);
      --log_enable (saved_log_mode, 1);
      if (aq is not null)
        aq_request (aq, 'DB.DBA.RDF_SW_PING', vector (ps, new_origin_uri));
      return 1;
    }

  --if (dest is null)
  --  {
  --    DB.DBA.SPARUL_CLEAR (graph_iri, 1);
  --    commit work;
  --  }

load_grddl:;

  if (get_soft = 'no-sponge')
    goto no_cart;

  if (('40001' = __SQL_STATE) and (retr_count < 10))
    {
      rollback work;
      retr_count := retr_count + 1;
      goto retry_after_deadlock;
    }
  if (__proc_exists ('DB.DBA.RDF_RUN_CARTRIDGES') is not null)
    {
      rc := DB.DBA.RDF_RUN_CARTRIDGES (graph_iri, new_origin_uri, dest, ret_body, ret_content_type, options, ret_hdr, ps, aq, req_hdr_arr);
      if (rc)
    return rc;
    }
  else
    {
  cset := http_request_header (ret_hdr, 'Content-Type', 'charset', null);
  for select RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_OPTIONS, RM_DESCRIPTION from DB.DBA.SYS_RDF_MAPPERS where RM_ENABLED = 1 order by RM_ID do
    {
      declare val_match, pcols, new_opts any;
      declare npars int;

      if (RM_TYPE = 'MIME')
	{
	  val_match := ret_content_type;
	}
      else if (RM_TYPE = 'URL' or RM_TYPE = 'HTTP')
	{
	  val_match := new_origin_uri;
	}
      else
	val_match := null;

      if (registry_get ('__sparql_mappers_debug') = '1')
        dbg_obj_prin1 ('Trying ', RM_HOOK);
      if (isstring (val_match) and regexp_match (RM_PATTERN, val_match) is not null)
	{
	  if (__proc_exists (RM_HOOK) is null)
	    goto try_next_mapper;

	  declare exit handler for sqlstate '*'
	    {
	      goto try_next_mapper;
	    };
          pcols := DB.DBA.RDF_PROC_COLS (RM_HOOK);
          npars := 8;
          if (isarray (pcols))
	    npars := length (pcols);
	  --!!!TBD: Carefully check what happens when dest is NULL vs dest is not NULL, then add support for groupdest.
          if (registry_get ('__sparql_mappers_debug') = '1')
            dbg_obj_prin1 ('Match ', RM_HOOK);
	  new_opts := vector_concat (options, RM_OPTIONS, vector ('content-type', ret_content_type, 'charset', cset));
	  if (__proc_exists ('DB.DBA.RDF_SPONGER_STATUS'))
	    call ('DB.DBA.RDF_SPONGER_STATUS') (graph_iri, new_origin_uri, dest, RM_DESCRIPTION, options);
	  if (RM_TYPE <> 'HTTP')
	    {
	      if (npars = 7)
	        rc := call (RM_HOOK) (graph_iri, new_origin_uri, dest, ret_body, aq, ps, RM_KEY);
	      else
	        rc := call (RM_HOOK) (graph_iri, new_origin_uri, dest, ret_body, aq, ps, RM_KEY, new_opts);
	    }
          else
	    {
	      if (npars = 7)
	        rc := call (RM_HOOK) (graph_iri, new_origin_uri, dest, ret_body, aq, ps, vector (req_hdr_arr, ret_hdr));
	      else
	        rc := call (RM_HOOK) (graph_iri, new_origin_uri, dest, ret_body, aq, ps, vector (req_hdr_arr, ret_hdr), new_opts);
	    }
          if (registry_get ('__sparql_mappers_debug') = '1')
	    {
	      dbg_obj_prin1 ('Return ', rc, RM_HOOK);
	      if (__tag(rc) = 193 or rc < 0 or rc > 0)
                dbg_obj_prin1 ('END of mappings');
	    }
	  if (__tag(rc) = 193 or rc < 0 or rc > 0)
	    {
		  if (rc > 0 and __proc_exists ('DB.DBA.RDF_LOAD_POST_PROCESS')) -- optional step, by default skip
		call ('DB.DBA.RDF_LOAD_POST_PROCESS') (graph_iri, new_origin_uri, dest, ret_body, ret_content_type, options);
              if (__tag(rc) = 193)
                return rc;
	      return (case when rc < 0 then 0 else 1 end);
	    }
	}
      try_next_mapper:;
    }
    }

  -- else if not handled with the above cases
  --xd := DAV_EXTRACT_META_AS_RDF_XML (new_origin_uri, ret_body);
  --if (xd is not null)
  --  {
      -- DB.DBA.SPARUL_CLEAR (dest, 1);
  --    DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  --    if (groupdest is not null)
  --      DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, groupdest);
  --    return 1;
  --  }

no_cart:

  if (rdf_fmt) -- even cartridges didn't extracted anything more, the rdf is already loaded
    return 1;

  if ((dest is null) and (get_soft is null or (get_soft <> 'add')))
    {
      DB.DBA.SPARUL_CLEAR (graph_iri, 1, 0);
      commit work;
    }
  if (strstr (ret_content_type, 'text/plain') is not null)
    {
      -- dbg_obj_princ ('DB.DBA.RDF_LOAD_HTTP_RESPONSE will signal text/plain error re. ', graph_iri, new_origin_uri, ret_content_type);
      signal ('RDFXX', sprintf (
          'Unable to load RDF graph <%.500s> from <%.500s>: returned Content-Type ''%.300s'' status ''%.300s'' body %.300s',
          graph_iri, new_origin_uri, ret_content_type, ret_hdr[0], subseq (ret_body, 0, 300) ) );
    }
  if (strstr (ret_content_type, 'text/html') is not null)
    {
      -- dbg_obj_princ ('DB.DBA.RDF_LOAD_HTTP_RESPONSE will signal text/html error re. ', graph_iri, new_origin_uri, ret_content_type);
      signal ('RDFZZ', sprintf (
          'Unable to load RDF graph <%.500s> from <%.500s>: returned Content-Type ''%.300s'' status ''%.300s''\n%.300s',
          graph_iri, new_origin_uri, ret_content_type, ret_hdr[0],
--          "LEFT" (cast (xtree_doc (ret_body, 2) as varchar), 300)
          subseq (ret_body, 0, 300) ) );
    }
  if (isstring (first_stat))
    {
      -- dbg_obj_princ ('DB.DBA.RDF_LOAD_HTTP_RESPONSE will signal first error re. ', graph_iri, new_origin_uri, ret_content_type, first_stat, first_msg);
      signal ('RDFZZ', sprintf (
          'Unable to load RDF graph <%.200s> from <%.200s> with Content-Type ''%.50s'': %.6s: %.1000s',
          graph_iri, new_origin_uri, ret_content_type, first_stat, first_msg ) );
    }
  -- dbg_obj_princ ('DB.DBA.RDF_LOAD_HTTP_RESPONSE will signal generic error re. ', graph_iri, new_origin_uri, ret_content_type);
  signal ('RDFZZ', sprintf (
      'Unable to load RDF graph <%.500s> from <%.500s>: returned unsupported Content-Type ''%.300s''',
      graph_iri, new_origin_uri, ret_content_type ) );
resignal_parse_error:
--  log_enable (saved_log_mode, 1);
  -- dbg_obj_princ ('DB.DBA.RDF_LOAD_HTTP_RESPONSE will resignal ', __SQL_STATE, __SQL_MESSAGE);
  resignal;

load_grddl_after_error:
  first_stat := __SQL_STATE;
  first_msg := __SQL_MESSAGE;
  if (('40001' = first_stat) and (retr_count < 10))
    {
      rollback work;
      retr_count := retr_count + 1;
      goto retry_after_deadlock;
    }
  goto load_grddl;
}
;

create procedure DB.DBA.RDF_FORGET_HTTP_RESPONSE (in graph_iri varchar, in new_origin_uri varchar, inout options any)
{
  declare dest varchar;
  declare deadl int;
  deadl := atoi (coalesce (virtuoso_ini_item_value ('SPARQL', 'MaxDeadlockRetries'), '5'));
  declare exit handler for sqlstate '40001'
    {
      deadl := deadl - 1;
      rollback work;
      if (deadl > 0)
	{
	  delay (0.2);
	  goto again;
	}
      resignal;
    };
again:
  dest := get_keyword_ucase ('get:destination', options);
  if (dest is null)
    DB.DBA.SPARUL_CLEAR (graph_iri, 1, 0);
  commit work;
}
;

create function DB.DBA.RDF_SPONGE_UP (in graph_iri varchar, in options any, in uid integer := -1)
{
  declare aq, cookie varchar;
  declare dest, local_iri varchar;

  if (coalesce (virtuoso_ini_item_value ('SPARQL', 'AsyncQueue'), '0') = '0' or get_keyword ('__rdf_sponge_queue', options) = 1)
    {
      return DB.DBA.RDF_SPONGE_UP_1 (graph_iri, options, uid);
    }
  commit work;
  --set_user_id ('dba', 1);
  cookie := connection_get ('__rdf_sponge_sid');
  if (cookie is not null)
    options := vector_concat (options, vector ('rdf_sponge_sid', cookie));
  if (connection_get ('__rdf_sponge_debug') is not null)
    options := vector_concat (options, vector ('rdf_sponge_debug', connection_get ('__rdf_sponge_debug')));
  if (is_http_ctx ())
    options := vector_concat (options, vector ('http_host', http_request_header(http_request_header (), 'Host', null, null)));
  options := vector_concat (options, vector ('__rdf_sponge_log_mode', log_enable (null, 1)));
  aq := async_queue (1);
  aq_request (aq, 'DB.DBA.RDF_SPONGE_UP_1', vector (graph_iri, options, uid));
  commit work;
  aq_wait_all (aq);
  graph_iri := cast (graph_iri as varchar);
  dest := get_keyword_ucase ('get:destination', options);
  if (dest is not null)
    {
      DB.DBA.RDF_LOG_DEBUG_INFO ('DB.DBA.RDF_SPONGE_UP() uses destination <%s> for document <%s>', dest, graph_iri);
      local_iri := 'destMD5=' || md5(dest) || '&graphMD5=' || md5(graph_iri);
      DB.DBA.RDF_LOG_DEBUG_INFO ('DB.DBA.RDF_SPONGE_UP() will return hash %s for document <%s>', local_iri, graph_iri);
    }
  else
    {
      local_iri := graph_iri;
    }
  return local_iri;
}
;

create function DB.DBA.RDF_SPONGE_UP_1 (in graph_iri varchar, in options any, in uid integer := -1)
{
  declare dest, get_soft, local_iri, immg, res_graph_iri, cookie, get_private varchar;
  declare perms, log_mode integer;
  -- dbg_obj_princ ('DB.DBA.RDF_SPONGE_UP_1 (', graph_iri, options, ')');
  graph_iri := cast (graph_iri as varchar);
  --set_user_id ('dba', 1);
  dest := get_keyword_ucase ('get:destination', options);
  if (dest is not null)
    local_iri := 'destMD5=' || md5(dest) || '&graphMD5=' || md5(graph_iri);
  else
    dest := local_iri := graph_iri;
  cookie := get_keyword ('rdf_sponge_sid', options);
  if (cookie is not null)
    connection_set ('__rdf_sponge_sid', cookie);
  if (get_keyword ('rdf_sponge_debug', options) is not null)
    connection_set ('__rdf_sponge_debug', get_keyword ('rdf_sponge_debug', options));
  if (get_keyword ('http_host', options) is not null)
    connection_set ('__http_host', get_keyword ('http_host', options));
  log_mode := get_keyword ('__rdf_sponge_log_mode', options);
  if (log_mode is not null) -- when in aq mode
    log_enable (log_mode, 1);
  -- dbg_obj_princ ('DB.DBA.RDF_SPONGE_UP_1 (', graph_iri, options, ') set local_iri=', local_iri);
  get_soft := get_keyword_ucase ('get:soft', options);
  if (isstring  (uid))
    uid := get_user_id_by_name (uid);
  if ('soft' = get_soft)
    {
      if ((dest = graph_iri) and exists (select 1 from DB.DBA.RDF_QUAD table option (index G) where G = iri_to_id (graph_iri, 0) ) and
        not exists (select 1 from DB.DBA.SYS_HTTP_SPONGE
          where HS_LOCAL_IRI = local_iri and HS_PARSER = 'DB.DBA.RDF_LOAD_HTTP_RESPONSE' and
          HS_EXPIRATION is not null))
        {
          -- dbg_obj_princ ('Exists and get:soft=soft, leaving');
          perms := DB.DBA.RDF_GRAPH_USER_PERMS_GET (dest, case (uid) when -1 then http_nobody_uid() else uid end);
          if (not bit_and (perms, 1))
            {
               -- dbg_obj_princ (dest, ' graph is OK as it is but not returned from RDF_SPONGE_UP_1 due to lack of read permission for user ', uid);
               return null;
            }
          res_graph_iri := local_iri;
          goto graph_is_ready;
        }
      -- dbg_obj_princ ('Does not exist, continue despite get:soft=soft');
    }
  else
    if (('replacing' = get_soft) or ('replace' = get_soft) or ('add' = get_soft) or ('no-sponge' = get_soft))
      {
        -- dbg_obj_princ ('get:soft=', get_soft);
        ;
      }
  else
    signal ('RDFZZ', sprintf (
      'This version of Virtuoso supports only "soft", "replacing", "add" and "no-sponge" values of "define get:soft ...", not "%.500s"',
      get_soft ) );
  get_private := get_keyword_ucase ('get:private', options, null);
  if (get_private is not null)
    DB.DBA.RDF_GRAB_PREPARE_PRIVATE (graph_iri, get_private, user, options);
  else
    {
      perms := DB.DBA.RDF_GRAPH_USER_PERMS_GET (dest, case (uid) when -1 then http_nobody_uid() else uid end);
      if (not bit_and (perms, 4))
        {
           if (get_keyword_ucase ('get:error-recovery', options, 'signal') = 'signal')
             signal ('RDFZZ', sprintf (
               'The graph <%.500s> is not sponged by RDF_SPONGE_UP_1 due to lack of sponge permission for user %d', dest, case (uid) when -1 then http_nobody_uid() else uid end ) );
           -- dbg_obj_princ (res_graph_iri, ' graph is not sponged by RDF_SPONGE_UP_1 due to lack of sponge permission for user ', uid);
           return null;
        }
    }
  -- if requested iri is immutable, do not try to get it at all
  -- this is to preserve rdf storage in certain cases
  immg := virtuoso_ini_item_value ('SPARQL', 'ImmutableGraphs');
  if (immg is not null and user <> 'dba')
    {
      immg := split_and_decode (immg, 0, '\0\0,');
      foreach (any imm in immg) do
        {
          imm := trim (imm);
          if (imm = dest)
            {
              res_graph_iri := dest;
              -- dbg_obj_princ ('immutable');
              goto graph_is_ready;
            }
          if (imm = 'inference-graphs' and exists (select 1 from DB.DBA.SYS_RDF_SCHEMA where RS_URI = dest))
            {
              res_graph_iri := dest;
              -- dbg_obj_princ ('immutable');
              goto graph_is_ready;
            }
          -- Like pattern allowed
          if (dest like imm)
            {
              res_graph_iri := local_iri;
              goto graph_is_ready;
            }
        }
    }
  -- dbg_obj_princ ('will sponge...');
  set_user_id ('dba', 1);
  if (lower (graph_iri) like 'file:%')
    {
      res_graph_iri := DB.DBA.SYS_FILE_SPONGE_UP (local_iri, graph_iri, null, 'DB.DBA.RDF_FORGET_HTTP_RESPONSE', options);
      goto graph_is_ready;
    }
  else if (lower (graph_iri) like 'http:%' or lower (graph_iri) like 'https:%')
    {
      res_graph_iri := DB.DBA.SYS_HTTP_SPONGE_UP (local_iri, graph_iri, 'DB.DBA.RDF_LOAD_HTTP_RESPONSE', 'DB.DBA.RDF_FORGET_HTTP_RESPONSE', options);
      goto graph_is_ready;
    }
  else
    {
      declare sch any;
      sch := rfc1808_parse_uri (graph_iri);
      sch := upper (sch[0]);
      -- dbg_obj_princ ('Needs DB.DBA.SYS_'||sch||'_SPONGE_UP ...');
      if (__proc_exists ('DB.DBA.SYS_'||sch||'_SPONGE_UP') is not null)
        {
	  res_graph_iri := call ('DB.DBA.SYS_'||sch||'_SPONGE_UP') (local_iri, graph_iri, options);
          goto graph_is_ready;
        }
      else
	{
	  -- signal ('RDFZZ', sprintf ('This version of Virtuoso Sponger does not support "%s" IRI scheme (IRI "%.1000s")', lower(sch), graph_iri));
          return null;
	}
    }
graph_is_ready:
  -- dbg_obj_princ (res_graph_iri, ' graph is ready, about to return from RDF_SPONGE_UP_1');
  if (__rdf_obj_ft_rule_check (iri_to_id (res_graph_iri), null) and
    coalesce (get_keyword ('refresh_free_text', options), 0) )
    VT_INC_INDEX_DB_DBA_RDF_OBJ();
  return res_graph_iri;
}
;

create function DB.DBA.RDF_SPONGE_UP_LIST (in sources any)
{
  declare need_reindex integer;
  declare aq any;
  need_reindex := 0;
  aq := async_queue (8);
  foreach (any src in sources) do
    {
      declare res_graph_iri any;
      res_graph_iri := DB.DBA.RDF_SPONGE_UP (src[0], vector_concat (vector ('refresh_free_text', 0), src[1]));
      if (__rdf_obj_ft_rule_check (iri_to_id (res_graph_iri), null) and
        coalesce (get_keyword ('refresh_free_text', src[1]), 0) )
      need_reindex := 1;
    }
  if (need_reindex)
    VT_INC_INDEX_DB_DBA_RDF_OBJ();
  return 1;
}
;

-- API

create function DB.DBA.SPONGER_DOCUMENT_IS_SPONGED (in doc varchar)
{
  if (exists (select 1 from DB.DBA.SYS_HTTP_SPONGE where HS_ORIGIN_URI = doc))
    return 1;
  return 0;
}
;

create procedure DB.DBA.SPONGER_DOCUMENT_EXPIRATION (in graph varchar)
{
  declare ret datetime;
  ret := null;
  for select HS_EXPIRATION from DB.DBA.SYS_HTTP_SPONGE where HS_ORIGIN_URI = graph do
    {
      ret := HS_EXPIRATION;
    }
  return ret;
}
;

create procedure DB.DBA.SPONGER_CACHE_CHECK (in url varchar, in top_url varchar, out old_etag varchar, out old_last_modified any)
{
  declare old_exp_is_true, old_expiration, old_read_count any;
  whenever not found goto no_record;
  select HS_EXP_IS_TRUE, HS_EXPIRATION, HS_LAST_MODIFIED, HS_LAST_ETAG, HS_READ_COUNT
      into old_exp_is_true, old_expiration, old_last_modified, old_etag, old_read_count
      from DB.DBA.SYS_HTTP_SPONGE where HS_FROM_IRI = url and HS_PARSER = 'DB.DBA.RDF_LOAD_HTTP_RESPONSE';
  -- as we are at point we load everything we always do re-load
no_record:
  return 0;
}
;

create procedure DB.DBA.SPONGER_CACHE_REGISTER (in url varchar, in top_url varchar, inout hdr any,
                   in old_last_modified any, in download_size int, in load_msec int)
{
  declare explicit_refresh, new_expiration, ret_content_type, ret_etag, ret_date, ret_expires, ret_last_modif,
      ret_dt_date, ret_dt_expires, ret_dt_last_modified any;

  if (not isarray (hdr))
    return;

  url := WS.WS.EXPAND_URL (top_url, url);
  explicit_refresh := null;
  new_expiration := now ();
  DB.DBA.SYS_HTTP_SPONGE_GET_CACHE_PARAMS (explicit_refresh, old_last_modified,
      hdr, new_expiration, ret_content_type, ret_etag, ret_date, ret_expires, ret_last_modif,
       ret_dt_date, ret_dt_expires, ret_dt_last_modified);
  insert replacing DB.DBA.SYS_HTTP_SPONGE (
      HS_LAST_LOAD,
      HS_LAST_ETAG,
      HS_LAST_READ,
      HS_EXP_IS_TRUE,
      HS_EXPIRATION,
      HS_LAST_MODIFIED,
      HS_DOWNLOAD_SIZE,
      HS_DOWNLOAD_MSEC_TIME,
      HS_READ_COUNT,
      HS_SQL_STATE,
      HS_SQL_MESSAGE,
      HS_LOCAL_IRI,
      HS_PARSER,
      HS_ORIGIN_URI,
      HS_ORIGIN_LOGIN,
      HS_FROM_IRI)
      values
      (
       now (),
       ret_etag,
       now(),
       case (isnull (ret_dt_expires)) when 1 then 0 else 1 end,
       coalesce (ret_dt_expires, new_expiration, now()),
       ret_dt_last_modified,
       download_size,
       load_msec,
       1,
       NULL,
       NULL,
       url,
       'DB.DBA.RDF_LOAD_HTTP_RESPONSE',
       url,
       NULL,
       top_url
       );

  return;
}
;

-- scheduler task if needed to keep volume under certain limit
create procedure DB.DBA.SPONGE_CLEAN_SPONGE (in d int := 30, in n int := 2000)
{
  declare res, stat, msg varchar;
  declare inx int;

  declare exit handler for sqlstate '*'
    {
      log_enable (1);
      resignal;
    }
  ;
  log_enable (2);
  inx := 0;
  for select HS_LOCAL_IRI as graph from DB.DBA.SYS_HTTP_SPONGE where HS_EXPIRATION < dateadd ('day', -1*d, now ()) do
    {
       inx := inx + 1;
       stat := '00000';
       exec ('sparql clear graph <'||graph||'>', stat, msg);
       if (inx > n)
         goto endp;
    }
 endp:
  log_enable (1);
}
;

create procedure DB.DBA.SPONGER_GET_GRAPHS_LIKE (in graph_pattern varchar)
{
  declare ret any;
  ret := (select VECTOR_AGG (HS_ORIGIN_URI) from DB.DBA.SYS_HTTP_SPONGE where regexp_match (graph_pattern, HS_ORIGIN_URI) is not null);
  return ret;
}
;

create procedure DB.DBA.SPONGER_GET_EXPIRY_INFO (in graph varchar)
{
  declare ret any;
  ret := (select VECTOR_AGG (vector (HS_EXPIRATION, HS_LAST_MODIFIED, HS_LAST_ETAG))
      from DB.DBA.SYS_HTTP_SPONGE where HS_LOCAL_IRI =  graph and HS_PARSER = 'DB.DBA.RDF_LOAD_HTTP_RESPONSE');
  return ret;
}
;

-- end API

create procedure DB.DBA.RDF_GRANT_SPONGE ()
{
  declare state, msg varchar;
  declare cmds any;
  cmds := vector (
    'create role SPARQL_SPONGE',
    'grant SPARQL_SELECT to SPARQL_SPONGE',
    'grant SPARQL_SPONGE to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_GRAB_SINGLE to SPARQL_SPONGE',
    'grant execute on DB.DBA.RDF_GRAB_SINGLE_ASYNC to SPARQL_SPONGE',
    'grant execute on DB.DBA.RDF_GRAB_SEEALSO to SPARQL_SPONGE',
    'grant execute on DB.DBA.RDF_GRAB to SPARQL_SPONGE',
    'grant execute on DB.DBA.SPARQL_EVAL_TO_ARRAY to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_EVAL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_SPONGE_UP to SPARQL_SPONGE',
    'grant execute on DB.DBA.RDF_SPONGE_UP_1 to SPARQL_SPONGE',
    'grant execute on DB.DBA.RDF_SPONGE_UP_LIST to SPARQL_SPONGE',
    'grant execute on DB.DBA.SPONGER_DOCUMENT_IS_SPONGED to SPARQL_SPONGE',
    'grant execute on DB.DBA.SPONGER_DOCUMENT_EXPIRATION to SPARQL_SPONGE',
    'grant execute on DB.DBA.SPONGER_CACHE_CHECK to SPARQL_SPONGE',
    'grant execute on DB.DBA.SPONGER_CLEAN_SPONGE to SPARQL_SPONGE',
    'grant execute on DB.DBA.SPONGER_GET_GRAPHS_LIKE to SPARQL_SPONGE',
    'grant execute on DB.DBA.SPONGER_GET_EXPIRY_INFO to SPARQL_SPONGE');
  foreach (varchar cmd in cmds) do
    {
      exec (cmd, state, msg);
    }
}
;

--!AFTER __PROCEDURE__ DB.DBA.USER_CREATE !
DB.DBA.RDF_GRANT_SPONGE ()
;

insert soft DB.DBA.SYS_XPF_EXTENSIONS (XPE_NAME, XPE_PNAME) values ('http://www.openlinksw.com/virtuoso/xslt/:docproxyIRI','DB.DBA.RDF_SPONGE_PROXY_IRI')
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:docproxyIRI', 'DB.DBA.RDF_SPONGE_PROXY_IRI', 0)
;

