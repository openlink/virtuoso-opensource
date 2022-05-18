--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2022 OpenLink Software
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
--  Install rewrite rules
--
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_fctabout_http_proxy_rule_1', 1,
    '/describe/([^/\?\&]*)?/?([^/\?\&:]*)/(.*)', vector ('force', 'login', 'url'), 2,
    '/describe?url=%U&force=%U&login=%U', vector ('url', 'force', 'login'), null, null, 2);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_fctabout_http_proxy_rule_2', 1,
    '/describe/html/(.*)', vector ('g'), 1,
    '/fct/rdfdesc/description.vsp?g=%U', vector ('g'), null, null, 2);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_fctabout_http_proxy_rule_3', 1,
    '/describe/\\?url=(.*)', vector ('g'), 1,
    '/fct/rdfdesc/description.vsp?g=%s', vector ('g'), null, null, 2);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_fctabout_http_proxy_rule_4', 1,
    '/describe/\\?uri=(.*)', vector ('g'), 1,
    '/fct/rdfdesc/description.vsp?g=%s', vector ('g'), null, null, 2);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_fctabout_http_proxy_rule_5', 1,
    '/describe/\\?uri=([^\&]*)\&graph=([^\&]*)', vector ('g', 'graph'), 2,
    '/fct/rdfdesc/description.vsp?g=%s&graph=%s', vector ('g', 'graph'), null, null, 2);

DB.DBA.URLREWRITE_CREATE_RULELIST ('ext_fctabout_http_proxy_rule_list1', 1,
    vector (
         -- 'ext_fctabout_http_proxy_rule_1', deprecated
            'ext_fctabout_http_proxy_rule_2',
            'ext_fctabout_http_proxy_rule_3',
            'ext_fctabout_http_proxy_rule_4',
            'ext_fctabout_http_proxy_rule_5'
            ));


--
-- Create all the VHOST entries for an endpoint
--
create procedure FCT_ADD_DEFAULT_VDIRS()
{
    DB.DBA.ADD_DEFAULT_VHOST (
        lpath=>'/fct',
        ppath=>case when registry_get('_fct_path_') = 0 then '/fct/' else registry_get('_fct_path_') end,
        is_dav=>atoi (case when registry_get('_fct_dav_') = 0 then '0' else registry_get('_fct_dav_') end),
        vsp_user=>'dba',
        def_page=>'facet.vsp',
        opts=>vector ('401_page', 'login.vsp', '403_page', 'login.vsp'),
        overwrite=>1
        );

    DB.DBA.ADD_DEFAULT_VHOST (
        lpath=>'/describe',
        ppath=>case when registry_get('_fct_path_') = 0 then '/fct/rdfdesc/' else registry_get('_fct_path_') || 'rdfdesc/' end,
        is_dav=>atoi (case when registry_get('_fct_dav_') = 0 then '0' else registry_get('_fct_dav_') end),
        vsp_user=>'dba',
        def_page=>'description.vsp',
        opts=>vector('url_rewrite', 'ext_fctabout_http_proxy_rule_list1'),
        overwrite=>1
        );


    DB.DBA.ADD_DEFAULT_VHOST (
        lpath=>'/services/rdf/iriautocomplete.get',
        ppath=>'/SOAP/Http/IRI_AUTOCOMPLETE',
        soap_user=>'PROXY',
        overwrite=>1
        );

    DB.DBA.ADD_DEFAULT_VHOST (
        lpath=>'/fct/service',
        ppath=>'/SOAP/Http/fct_svc',
        soap_user=>'SPARQL',
        overwrite=>1
        );

    -- http://{cname}/fct/search(?q,view:type,c-term,s-term,invfp,same-as,inference,offet,limit,graph)
    DB.DBA.ADD_DEFAULT_VHOST (
        lpath=>'/fct/search',
        ppath=>'/SOAP/Http/fct_search',
        soap_user=>'SPARQL',
        overwrite=>1
        );

    DB.DBA.ADD_DEFAULT_VHOST (
        lpath=>'/fct/soap',
        ppath=>'/SOAP/',
        soap_user=>'SPARQL',
        overwrite=>1
        );

    --
    -- Deprecated, so remove this entry on standard installations
    --
    --DB.DBA.ADD_DEFAULT_VHOST (
    --    lpath=>'/b3s',
    --    ppath=>case when registry_get('_fct_path_') = 0 then '/fct/' else registry_get('_fct_path_') end || 'www/',
    --    is_dav=>atoi (case when registry_get('_fct_dav_') = 0 then '0' else registry_get('_fct_dav_') end),
    --    vsp_user=>'dba', def_page=>'listall.vsp'
    --    overwrite=>1
    --    );
}
;

FCT_ADD_DEFAULT_VDIRS()
;

create procedure FCT_CREATE_VHOST(
    in vhost varchar,
    in lhost varchar)
{
   declare endpoints any;

   --
   --  Endpoints we want to expose
   --
   endpoints := vector (
        '/describe',
        '/fct',
        '/fct/search',
        '/fct/service',
        '/fct/soap',
        '/services/rdf/iriautocomplete.get'
        );

    --
    --  Remove deprecated endpoints
    --
    DB.DBA.VHOST_REMOVE (
        vhost=>vhost,
        lhost=>lhost,
        lpath=>'/b3s');


    --
    --  Install VDIRs from defaults
    --
    for (select
            HPD_LPATH,
            HPD_PPATH,
            HPD_STORE_AS_DAV,
            HPD_DIR_BROWSEABLE,
            HPD_DEFAULT,
            HPD_REALM,
            HPD_AUTH_FUNC,
            HPD_POSTPROCESS_FUNC,
            HPD_RUN_VSP_AS,
            HPD_RUN_SOAP_AS,
            HPD_PERSIST_SES_VARS,
            HPD_SOAP_OPTIONS,
            HPD_AUTH_OPTIONS,
            HPD_OPTIONS,
            HPD_IS_DEFAULT_HOST
        from DB.DBA.HTTP_PATH_DEFAULT where HPD_LPATH in (endpoints)) do
        {
            DB.DBA.VHOST_REMOVE (
                vhost=>vhost,
                lhost=>lhost,
                lpath=>HPD_LPATH);

            DB.DBA.VHOST_DEFINE (
                vhost=>vhost,
                lhost=>lhost,
                lpath=>HPD_LPATH,
                ppath=>HPD_PPATH,
                is_dav=>HPD_STORE_AS_DAV,
                is_brws=>HPD_DIR_BROWSEABLE,
                def_page=>HPD_DEFAULT,
                auth_fn=>HPD_AUTH_FUNC,
                realm=>HPD_REALM,
                ppr_fn=>HPD_POSTPROCESS_FUNC,
                vsp_user=>HPD_RUN_VSP_AS,
                soap_user=>HPD_RUN_SOAP_AS,
                ses_vars=>HPD_PERSIST_SES_VARS,
                soap_opts=>deserialize (HPD_SOAP_OPTIONS),
                auth_opts=>deserialize (HPD_AUTH_OPTIONS),
                opts=>deserialize (HPD_OPTIONS),
                is_default_host=>HPD_IS_DEFAULT_HOST);
        }
}
;

DB.DBA.FCT_CREATE_VHOST('*ini*', '*ini*')
;

DB.DBA.FCT_CREATE_VHOST('*sslini*', '*sslini*')
;
