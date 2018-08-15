<?xml version='1.0'?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2018 OpenLink Software
 -  
 -  This project is free software; you can redistribute it and/or modify it
 -  under the terms of the GNU General Public License as published by the
 -  Free Software Foundation; only version 2 of the License, dated June 1991.
 -  
 -  This program is distributed in the hope that it will be useful, but
 -  WITHOUT ANY WARRANTY; without even the implied warranty of
 -  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 -  General Public License for more details.
 -  
 -  You should have received a copy of the GNU General Public License along
 -  with this program; if not, write to the Free Software Foundation, Inc.,
 -  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 -  
 -  
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  version="1.0"
  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
  xmlns:bpel="http://schemas.xmlsoap.org/ws/2003/03/business-process/"
  xmlns:virt="http://www.openlinksw.com/virtuoso/xslt"
  xmlns:bpelv="http://www.openlinksw.com/virtuoso/bpel"
  xmlns:bpelx="http://schemas.oracle.com/bpel/extension"
  >

<xsl:output method="text" omit-xml-declaration="yes" indent="yes" />

<xsl:param name="tns" select="/bpel:process/@targetNamespace" />
<xsl:param name="bpelURI" select="/bpel:process/@targetNamespace" />
<!--xsl:param name="wsdl" /-->
<xsl:variable name="script_id" select="$id" />

<!-- all elements making a node -->
<xsl:variable name="nodes"
    select="
    //bpel:receive|
    //bpel:reply|
    //bpel:invoke|
    //bpel:assign/copy|
    //bpel:throw|
    //bpel:terminate|
    //bpel:wait|
    //bpel:empty|
    //bpel:sequence|
    //bpel:switch|
    //bpel:case|
    //bpel:otherwise|
    //bpel:while|
    //bpel:pick|
    //bpel:scope|
    //bpel:flow|
    //bpel:link|
    //bpel:compensate|
    //bpel:compensationHandler|
    //bpel:compensationHandlerEnd|
    //bpel:faultHandlers|
    //bpel:catch|
    //bpel:catchAll|
    //bpel:onMessage|
    //bpel:onAlarm|
    //bpelv:exec[((not @import) and (not @using) and (not @ref))]|
    //bpelx:exec[not @import]|
    //bpelv:serverFailure"/>

 <!-- all elements making scope inside their body -->
 <xsl:variable name="snodes" select="//bpel:while[bpel:scope] | //bpel:compensationHandler | //bpel:scope | //bpel:eventHandlers/bpel:*"/>
 <!-- these are not needed as are expanded already
 all elements making two new nodes; this could be taken out as preprocessing puts default catchAll
 <xsl:variable name="dnodes" select="//bpel:faultHandlers[not (bpel:catchAll)]|//bpel:while[not (bpel:scope)]"/-->

<xsl:template match="/">
  <!-- some basic checks -->
  <xsl:variable name="iop"
      select="bpel:process/bpel:sequence/bpel:receive[1]|
      bpel:process/bpel:sequence/bpel:scope/bpel:receive[1]|
      bpel:process/bpel:sequence/bpel:sequence/bpel:receive[1]|
      bpel:process/bpel:sequence/bpel:pick[1][bpel:onMessage]|
      bpel:process/bpel:sequence/bpel:scope/bpel:pick[1][bpel:onMessage]|
      bpel:process/bpel:sequence/bpel:sequence/bpel:pick[1][bpel:onMessage]"
      />

 <xsl:if test="//bpel:faultHandlers[not (bpel:catchAll)] or //bpel:while[not (bpel:scope)]">
     <xsl:message terminate="yes">The source is not expanded</xsl:message>
 </xsl:if>

  <xsl:if test="empty ($iop)">
      <xsl:message terminate="yes">The first operation in the process must be sequence/receive</xsl:message>
  </xsl:if>
  <xsl:if test="not $iop/@operation and not $iop/bpel:onMessage/@operation">
      <xsl:message terminate="yes">Operation has no name</xsl:message>
  </xsl:if>
  <xsl:if test="string($iop/@createInstance) != 'yes'">
      <xsl:message terminate="yes">The first receive operation must contains createInstance="yes"</xsl:message>
  </xsl:if>
  <xsl:if test="//bpel:*/bpel:correlations[count(bpel:correlation[@initiate='no'])&gt;1]">
      <xsl:message terminate="yes">Correlation with more than one set is not allowed</xsl:message>
  </xsl:if>
  -- Automatically generated code from BPEL script
  create procedure BPEL.BPEL.update_nodes_<xsl:value-of select="$script_id"/> ()
    {
      declare curr_parent_node BPEL.BPEL.node;
      declare top_scope BPEL.BPEL.scope;
      declare script_inst integer;
      declare nodes_cnt int;
      declare pmask varbinary;
      declare current_scope, current_fault, current_fault_bit int;
      declare ctx BPEL..comp_ctx;
      declare enclosing_scp, events, scopes any;
      declare java_imports, clr_imports varchar;
      declare clr_refs any;
      java_imports := clr_imports := '';
      clr_refs := make_array (0, 'any');

      <!-- XXX: total nodes count must keep in sync with actual nodes count
      nodes := all_activities + ones_that_adding_jumps_and_ends + 2;
      the last 2 is because process makes a scope
      -->
      nodes_cnt := <xsl:value-of select="count($nodes)"/> + <xsl:text/>
      		<xsl:value-of select="count($snodes)"/> + <xsl:text/>
		<!--xsl:text/>(2 * <xsl:value-of select="count($dnodes)"/>) + <xsl:text/-->
		<xsl:text/>2;
      <!-- pickup mask, length of all plus one as at zero position is reserved -->
      pmask := BPEL..zero_mask (nodes_cnt+1);
      -- pmask := cast (repeat ('\x0', nodes_cnt+1) as varbinary);

      script_inst := <xsl:value-of select="$script_id"/>;

      curr_parent_node := null;

      declare curr_node BPEL.BPEL.node;
      declare current_scope, current_fault, current_fault_bit int;
      curr_node := BPEL.BPEL.node::new_scope (curr_parent_node, script_inst, null);

      top_scope := curr_node.bn_activity;
      top_scope.ba_vars := BPEL.BPEL.vector_push (top_scope.ba_vars,
      			 vector ('@request@', '@request@', 'any'), 'any');
      top_scope.ba_vars := BPEL.BPEL.vector_push (top_scope.ba_vars,
                         vector ('@result@', '@result@', 'any'), 'any');
      top_scope.ba_vars := BPEL.BPEL.vector_push (top_scope.ba_vars,
                         vector ('@fault-0', '@fault-0', 'any'), 'any');
      curr_node.bn_activity := top_scope;

      curr_parent_node := curr_node;
      current_scope := curr_node.bn_id;
      enclosing_scp := vector ();
      events := vector ();
      scopes := vector (curr_node.bn_id, 0);

      <xsl:apply-templates select="*" />

      <!-- scope end node -->
      {
	declare curr_node BPEL.BPEL.node;

	<xsl:variable name="no_comps" select="bpel:compensationHandler/*[local-name()!='compensate']"/>

        curr_node := BPEL.BPEL.node::new_node  (curr_parent_node,
	new BPEL.BPEL.scope_end (events, null, <xsl:value-of select="boolean($no_comps)"/>), script_inst);
        <xsl:call-template name="get-links-clear"/>
        BPEL.BPEL.store_new_node (curr_node, pmask, nodes_cnt, current_scope, ctx);
      }
      <xsl:call-template name="get-links"/>

      BPEL.BPEL.store_new_node (curr_parent_node, pmask, nodes_cnt, current_scope, ctx);

      update BPEL..script set bs_pickup_bf = pmask, bs_first_node_id = curr_node.bn_id, bs_act_num = nodes_cnt,
      	bs_scopes = scopes
        where bs_id = script_inst;

      return curr_parent_node.bn_id;
    }<xsl:text/>
</xsl:template>

<xsl:template name="get-links-clear">
    ctx := new BPEL..comp_ctx ();
    ctx.c_current_fault := current_fault;
    ctx.c_current_fault_bit := current_fault_bit;
    ctx.c_enc_scps := enclosing_scp;
    ctx.c_event := 0;
    ctx.c_scopes := scopes;
    ctx.c_in_comp := <xsl:value-of select="boolean (ancestor::bpel:compensationHandler)"/>;
</xsl:template>

<xsl:template name="get-links">
    ctx := new BPEL..comp_ctx ();
    ctx.c_internal_id  := '<xsl:value-of select="@internal_id"/>';
    <xsl:if test="@src-line">
	ctx.c_src_line := <xsl:value-of select="@src-line"/>;
    </xsl:if>
    ctx.c_current_fault := current_fault;
    ctx.c_current_fault_bit := current_fault_bit;
    ctx.c_enc_scps := enclosing_scp;
    ctx.c_join_cond := '<xsl:value-of select="virt:encode_base64 (@joinCondition)"/>';
    ctx.c_supp_join := '<xsl:value-of select="ancestor-or-self::*/@suppressJoinFailure"/>';
    ctx.c_srclinks := vector (
    <xsl:for-each select="bpel:source">
	'<xsl:value-of select="@linkName"/>',
	'<xsl:value-of select="virt:encode_base64 (@transitionCondition)"/>'
	<xsl:if test="position() != last ()">,</xsl:if>
    </xsl:for-each>
    			);
    ctx.c_tgtlinks := vector (
    <xsl:for-each select="bpel:target">
	'<xsl:value-of select="@linkName"/>'
	<xsl:if test="position() != last ()">,</xsl:if>
    </xsl:for-each>
    			);
    ctx.c_event := <xsl:value-of select="boolean (parent::bpel:eventHandlers)"/>;
    ctx.c_scopes := scopes;
    ctx.c_in_comp := <xsl:value-of select="boolean (ancestor::bpel:compensationHandler)"/>;
</xsl:template>

<xsl:template match="bpel:partnerLinks">
  {
    <xsl:apply-templates select="bpel:partnerLink"/>
  }
</xsl:template>

<xsl:template match="bpel:partnerLink">
  {
        BPEL.BPEL.create_new_partner_link (script_inst,
		'<xsl:value-of select="@name"/>',
		'<xsl:value-of select="@partnerLinkType"/>',
		'<xsl:value-of select="@myRole"/>',
		'<xsl:value-of select="@partnerRole"/>');
  }
</xsl:template>

<xsl:template match="bpel:sequence">
  {
    declare curr_node BPEL.BPEL.node;

    curr_node := BPEL.BPEL.node::new_sequence (curr_parent_node, script_inst);
    declare curr_parent_node BPEL.BPEL.node;
    curr_parent_node := curr_node;

    	<xsl:apply-templates/>

	<xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_parent_node, pmask, nodes_cnt, current_scope, ctx);
  }
</xsl:template>

<xsl:template match="bpel:variables">
  {
	declare scp BPEL.BPEL.scope;
	scp := curr_node.bn_activity;

		<xsl:apply-templates select="bpel:variable"/>

	curr_node.bn_activity := scp;
  }
</xsl:template>

<xsl:template match="bpel:variable">
   scp.ba_vars := BPEL.BPEL.vector_push (scp.ba_vars, vector (
			'<xsl:value-of select="@name"/>',
			<!-- unique name for per script -->
			'var-<xsl:value-of select="generate-id()"/>',
			<xsl:choose>
			    <xsl:when test="@messageType">
				'<xsl:value-of select="@messageType"/>',
				0
			    </xsl:when>
			    <xsl:when test="@element">
				'<xsl:value-of select="@element"/>',
				1
			    </xsl:when>
			    <xsl:when test="@type">
				'<xsl:value-of select="@type"/>',
				2
			    </xsl:when>
			    <xsl:otherwise>
				'',
				3
			    </xsl:otherwise>
			</xsl:choose>
			),
		'any');
</xsl:template>

<xsl:template match="bpel:invoke">
      {
      declare curr_node BPEL.BPEL.node;
      declare corrs any;
      corrs := null;
	<xsl:for-each select="bpel:correlations/bpel:correlation">
		corrs := BPEL.BPEL.vector_push ( corrs,
		vector ('<xsl:value-of select="@set"/>',
			'<xsl:value-of select="@initiate"/>',
			'<xsl:value-of select="@pattern"/>'
			),
			'any');
	</xsl:for-each>
  <xsl:choose>
    <xsl:when test="self::node()/@outputVariable">
      curr_node := BPEL.BPEL.node::new_invoke(curr_parent_node, script_inst,
                '<xsl:value-of select="@partnerLink"/>',
                '<xsl:value-of select="@portType"/>',
                '<xsl:value-of select="@operation"/>',
		'<xsl:value-of select="@inputVariable"/>',
		'<xsl:value-of select="@outputVariable"/>',
		corrs);
    </xsl:when>
    <xsl:otherwise>
      curr_node := BPEL.BPEL.node::new_invoke(curr_parent_node, script_inst,
                '<xsl:value-of select="@partnerLink"/>',
                '<xsl:value-of select="@portType"/>',
                '<xsl:value-of select="@operation"/>',
		'<xsl:value-of select="@inputVariable"/>',
		NULL,
		corrs);
    </xsl:otherwise>
  </xsl:choose>
      <xsl:call-template name="get-links"/>
      BPEL.BPEL.store_new_node (curr_node, pmask, nodes_cnt, current_scope, ctx);
      }
</xsl:template>


<xsl:template match="bpel:receive">
  <xsl:variable name="portType" select="@portType"/>
  {
    declare curr_node BPEL.BPEL.node;
    declare corrs any;
    corrs := null;
    <!-- we need to make assigment or to register correlation vars  -->
	<xsl:for-each select="bpel:correlations/bpel:correlation">
		corrs := BPEL.BPEL.vector_push ( corrs,
		vector ('<xsl:value-of select="@set"/>',
			'<xsl:value-of select="@initiate"/>', 'in'), 'any');
	</xsl:for-each>
	<xsl:choose>
		<xsl:when test="//descendant::reply [ @portType = $portType ]">
		    curr_node := BPEL.BPEL.node::new_node (curr_parent_node, new BPEL.BPEL.receive(
			          '<xsl:value-of select="@name"/>',
			          '<xsl:value-of select="@partnerLink"/>',
			          '<xsl:value-of select="@portType"/>',
			          '<xsl:value-of select="@operation"/>',
			          '<xsl:value-of select="@variable"/>',
			          '<xsl:value-of select="@createInstance"/>',
			          corrs, 0),
		          script_inst);
		</xsl:when>
		<xsl:otherwise>
		    curr_node := BPEL.BPEL.node::new_node (curr_parent_node, new BPEL.BPEL.receive(
			          '<xsl:value-of select="@name"/>',
			          '<xsl:value-of select="@partnerLink"/>',
			          '<xsl:value-of select="@portType"/>',
			          '<xsl:value-of select="@operation"/>',
			          '<xsl:value-of select="@variable"/>',
			          '<xsl:value-of select="@createInstance"/>',
			          corrs, 1),
		          script_inst);
		</xsl:otherwise>
	</xsl:choose>
    insert soft BPEL..operation (bo_script, bo_name, bo_partner_link, bo_port_type, bo_init)
    values (script_inst, '<xsl:value-of select="@operation"/>', '<xsl:value-of select="@partnerLink"/>', '<xsl:value-of select="@portType"/>', <xsl:value-of select="boolean(@createInstance)"/>);
      <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_node, pmask, nodes_cnt, current_scope, ctx);
  }
</xsl:template>

<xsl:template match="bpel:reply">
  {
    declare curr_node BPEL.BPEL.node;
    declare corrs any;
    corrs := null;

	<xsl:for-each select="bpel:correlations/bpel:correlation">
		corrs := BPEL.BPEL.vector_push ( corrs,
		vector ('<xsl:value-of select="@set"/>',
			'<xsl:value-of select="@initiate"/>', 'out'),
			'any');
	</xsl:for-each>

    curr_node := BPEL.BPEL.node::new_node (curr_parent_node, BPEL.BPEL.reply (
    	'<xsl:value-of select="@partnerLink"/>',
	'<xsl:value-of select="@portType"/>',
	'<xsl:value-of select="@operation"/>',
	'<xsl:value-of select="@variable"/>',
	'<xsl:value-of select="@name"/>',
	corrs,
	'<xsl:value-of select="@faultName"/>'
	), script_inst);

      <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_node, pmask, nodes_cnt, current_scope, ctx);
 }
</xsl:template>

<xsl:template match="bpel:link">
  {
    declare curr_node BPEL.BPEL.node;

    curr_node := BPEL.BPEL.node::new_node (curr_parent_node,
    		BPEL..link ('<xsl:value-of select="@name"/>'), script_inst);

      <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_node, pmask, nodes_cnt, current_scope, ctx);
 }
</xsl:template>

<xsl:template match="bpel:empty">
  {
    declare curr_node BPEL.BPEL.node;

    curr_node := BPEL.BPEL.node::new_node (curr_parent_node,
    		BPEL..empty (), script_inst);

      <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_node, pmask, nodes_cnt, current_scope, ctx);
 }
</xsl:template>

<xsl:template match="bpel:throw">
  {
    declare curr_node BPEL.BPEL.node;

    curr_node := BPEL.BPEL.node::new_node (curr_parent_node,
    BPEL..throw ('<xsl:value-of select="@faultName"/>'), script_inst);

      <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_node, pmask, nodes_cnt, current_scope, ctx);
 }
</xsl:template>

<xsl:template match="bpelv:serverFailure">
  {
    declare curr_node BPEL.BPEL.node;

    curr_node := BPEL.BPEL.node::new_node (curr_parent_node,
    BPEL..server_failure (), script_inst);

      <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_node, pmask, nodes_cnt, current_scope, ctx);
 }
</xsl:template>

<xsl:template match="@*" mode="escape"><xsl:value-of select="translate (., &quot;&apos;&quot;, '&quot;')"/></xsl:template>

<xsl:template match="bpel:assign" >
--  assigment
  <xsl:for-each select="bpel:copy">
    {
    declare curr_node BPEL.BPEL.node;
    declare assign BPEL.BPEL.assign;
    <xsl:choose>
      <xsl:when test="from/@variable and from/@part">
        assign  := BPEL.BPEL.assign ( BPEL.BPEL.place_vpa (
        '<xsl:value-of select="from/@variable"/>',
        '<xsl:value-of select="from/@part"/>',
	'<xsl:apply-templates select="from/@query" mode="escape"/>') );
      </xsl:when>
      <xsl:when test="from/@variable and from/@property">
        assign := BPEL.BPEL.assign ( BPEL.BPEL.place_vpr (
        '<xsl:value-of select="from/@variable"/>',
        '<xsl:value-of select="from/@property"/>') );
      </xsl:when>
      <xsl:when test="from/@variable">
        assign := BPEL.BPEL.assign ( BPEL.BPEL.place_vq (
        '<xsl:value-of select="from/@variable"/>',
        '<xsl:value-of select="from/@query"/>') );
      </xsl:when>
      <xsl:when test="from/@partnerLink and from/@endpointReference">
        assign := BPEL.BPEL.assign ( BPEL.BPEL.place_plep (
        '<xsl:value-of select="from/@partnerLink"/>',
        '<xsl:value-of select="from/@endpoinReference"/>') );
      </xsl:when>
      <xsl:when test="from/@expression">
        assign := BPEL.BPEL.assign ( BPEL.BPEL.place_expr (
        '<xsl:value-of select="virt:encode_base64(from/@expression)"/>') );
      </xsl:when>
      <xsl:when test="from">
		<xsl:variable name="tempTree" select="from/*"/>
      	assign := BPEL.BPEL.assign ( BPEL.BPEL.place_text ('
		<xsl:value-of select="virt:transform_xml_to_text  ($tempTree)"/>
		'));
      </xsl:when>
      <xsl:otherwise>
      	signal ('BP501', 'Incomplete assignment is not allowed');
      </xsl:otherwise>
    </xsl:choose>

    if (assign is null)
      signal ('BP500', 'Unexpected copy statement');

    <xsl:choose>
      <xsl:when test="to/@variable and to/@property">
        assign.add_to ( BPEL.BPEL.place_vpr (
        '<xsl:value-of select="to/@variable"/>',
        '<xsl:value-of select="to/@property"/>') );
      </xsl:when>
      <xsl:when test="to/@partnerLink">
        assign.add_to ( BPEL.BPEL.place_plep ('<xsl:value-of select="to/@partnerLink"/>', null) );
      </xsl:when>
      <xsl:when test="to/@variable and to/@part">
        assign.add_to ( BPEL.BPEL.place_vpa (
        '<xsl:value-of select="to/@variable"/>',
        '<xsl:value-of select="to/@part"/>',
	'<xsl:apply-templates select="to/@query" mode="escape"/>') );
      </xsl:when>
      <xsl:when test="to/@variable">
        assign.add_to ( BPEL.BPEL.place_vq (
        '<xsl:value-of select="to/@variable"/>',
        '<xsl:apply-templates select="to/@query" mode="escape"/>') );
      </xsl:when>
      <xsl:otherwise>
      	signal ('BP500', 'Incomplete assignment is not allowed');
      </xsl:otherwise>
    </xsl:choose>
    curr_node := BPEL.BPEL.node::new_node (curr_parent_node, assign, script_inst);

      <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_node, pmask, nodes_cnt, current_scope, ctx);
    }
  </xsl:for-each>
</xsl:template>


<xsl:template match="bpel:compensationHandler">
  {
    declare curr_node BPEL.BPEL.node;

    curr_node := BPEL.BPEL.node::new_compensation_handler (curr_parent_node, script_inst);
    declare curr_parent_node BPEL.BPEL.node;
    curr_parent_node := curr_node;

    	<xsl:apply-templates/>

    <!-- compensation handler end node -->
    {
      declare curr_node BPEL.BPEL.node;

      curr_node := BPEL.BPEL.node::new_node  (curr_parent_node,
         new BPEL.BPEL.compensation_handler_end (), script_inst);
      <xsl:call-template name="get-links-clear"/>
      BPEL.BPEL.store_new_node (curr_node, pmask, nodes_cnt, current_scope, ctx);
    }
      <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_parent_node, pmask, nodes_cnt, current_scope, ctx);
  }
</xsl:template>
<xsl:template match="bpel:faultHandlers">
  {
    declare curr_node BPEL.BPEL.node;

    curr_node := BPEL.BPEL.node::new_fault_handlers (curr_parent_node, script_inst);

    declare curr_parent_node BPEL.BPEL.node;
    curr_parent_node := curr_node;

    	<xsl:apply-templates select="bpel:catch"/>
	<xsl:apply-templates select="bpel:catchAll"/>
	<!-- if no catch all then make one with throw inside -->
	<xsl:if test="not (bpel:catchAll)">
	  <xsl:call-template name="catchAllImplicit"/>
	</xsl:if>

      <xsl:call-template name="get-links"/>
    current_fault := curr_node.bn_id;
    current_fault_bit := curr_node.bn_activity.ba_id;
    BPEL.BPEL.store_new_node (curr_parent_node, pmask, nodes_cnt, current_scope, ctx);
  }
 </xsl:template>
 <xsl:template match="bpel:catch">
   {
     declare curr_node BPEL.BPEL.node;

     curr_node := BPEL.BPEL.node::new_node (curr_parent_node, BPEL.BPEL.catch (
                             '<xsl:value-of select="@faultName"/>',
			     '<xsl:value-of select="@faultVariable"/>'
     			),
			script_inst);

     declare curr_parent_node BPEL.BPEL.node;
     curr_parent_node := curr_node;

     <xsl:apply-templates/>

      <xsl:call-template name="get-links"/>
     BPEL.BPEL.store_new_node (curr_parent_node, pmask, nodes_cnt, current_scope, ctx);
   }
</xsl:template>

<xsl:template match="bpel:catchAll">
   {
     declare curr_node BPEL.BPEL.node;

     curr_node := BPEL.BPEL.node::new_node (curr_parent_node, BPEL.BPEL.catch ( '*', ''),
			script_inst);

     declare curr_parent_node BPEL.BPEL.node;
     curr_parent_node := curr_node;

     <xsl:apply-templates/>

      <xsl:call-template name="get-links"/>
     BPEL.BPEL.store_new_node (curr_parent_node, pmask, nodes_cnt, current_scope, ctx);
   }
</xsl:template>

<xsl:template name="catchAllImplicit">
   {
     declare curr_node BPEL.BPEL.node;

     curr_node := BPEL.BPEL.node::new_node (curr_parent_node, BPEL.BPEL.catch ( '*', ''),
			script_inst);

     declare curr_parent_node BPEL.BPEL.node;
     curr_parent_node := curr_node;

      {
	declare curr_node BPEL.BPEL.node;

	curr_node := BPEL.BPEL.node::new_node (curr_parent_node, BPEL..throw ('*'), script_inst);

	<xsl:call-template name="get-links-clear"/>
	BPEL.BPEL.store_new_node (curr_node, pmask, nodes_cnt, current_scope, ctx);
      }

     <xsl:call-template name="get-links-clear"/>
     BPEL.BPEL.store_new_node (curr_parent_node, pmask, nodes_cnt, current_scope, ctx);
   }
</xsl:template>


<xsl:template match="bpel:scope">
  {
    declare save_fault, save_fault_bit int;

    save_fault := current_fault;
    save_fault_bit := current_fault_bit;

    declare curr_node BPEL.BPEL.node;
    declare active_scope BPEL.BPEL.scope;
    declare current_fault, current_fault_bit int;
    declare s_enclosing_scp any;

    current_fault := save_fault;
    current_fault_bit := save_fault_bit;

    <!--
    all scopes have name after pre-processing
    xsl:choose>
    	<xsl:when test="@name">
	   curr_node := BPEL.BPEL.node::new_scope (curr_parent_node, script_inst,
	   '<xsl:value-of select="@name"/>');
	</xsl:when>
	<xsl:otherwise>
	   curr_node := BPEL.BPEL.node::new_scope (curr_parent_node, script_inst, null);
	</xsl:otherwise>
    </xsl:choose-->
    curr_node := BPEL.BPEL.node::new_scope (curr_parent_node, script_inst, '<xsl:value-of select="@name"/>');

    s_enclosing_scp := vector_concat (enclosing_scp, vector (current_scope));

    declare curr_parent_node BPEL.BPEL.node;
    declare enclosing_scp, events any;
    declare current_scope int;
    enclosing_scp := s_enclosing_scp;

    curr_parent_node := curr_node;
    current_scope := curr_node.bn_id;
    events := vector ();
    scopes := vector_concat (scopes, vector (curr_node.bn_id, 0));

    	<xsl:apply-templates select="bpel:faultHandlers"/>
	<xsl:apply-templates select="* [ name() != 'http://schemas.xmlsoap.org/ws/2003/03/business-process/:faultHandlers' and name() != 'http://schemas.xmlsoap.org/ws/2003/03/business-process/:compensationHandler' ] "/>
    <!-- scope end node -->
    {
      declare curr_node BPEL.BPEL.node;

      <xsl:variable name="no_comps" select="bpel:compensationHandler/*[local-name()!='compensate']"/>
      curr_node := BPEL.BPEL.node::new_node  (curr_parent_node,
      new BPEL.BPEL.scope_end (events, '<xsl:value-of select="@name"/>', <xsl:value-of select="boolean($no_comps)"/>), script_inst);
      <xsl:call-template name="get-links-clear"/>
      BPEL.BPEL.store_new_node (curr_node, pmask, nodes_cnt, current_scope, ctx);
    }
    <xsl:if test="parent::bpel:while">
    <!-- special jump instruction at the end of the while -->
    {
      declare curr_node BPEL.BPEL.node;
      curr_node :=
      BPEL.BPEL.node::new_node  (curr_parent_node,
      	new BPEL.BPEL.jump (curr_parent_node.bn_activity.ba_parent_id, curr_parent_node.bn_parent), script_inst);
	<xsl:call-template name="get-links-clear"/>
      BPEL.BPEL.store_new_node (curr_node, pmask, nodes_cnt, current_scope, ctx);
    }
    </xsl:if>
    	<xsl:apply-templates select="bpel:compensationHandler"/>

      <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_parent_node, pmask, nodes_cnt, current_scope, ctx);
  }
</xsl:template>


<xsl:template match="bpel:correlationSets">
      {
	declare curr_scope BPEL.BPEL.scope;
	curr_scope := curr_node.bn_activity;

	<xsl:apply-templates select="bpel:correlationSet"/>

	curr_node.bn_activity := curr_scope;
      }
</xsl:template>

<xsl:template match="bpel:correlationSet">
	BPEL.BPEL.add_correlation_set (<xsl:value-of select="$script_id"/>,
		'<xsl:value-of select="@name"/>',
		'<xsl:value-of select="@properties"/>');
	curr_scope.ba_corrs := BPEL.BPEL.vector_push (curr_scope.ba_corrs,
	vector ('<xsl:value-of select="@name"/>',
		'corr-<xsl:value-of select="generate-id()"/>',
		'<xsl:value-of select="@properties"/>'), 'any');
</xsl:template>

<xsl:template match="bpel:correlations">
</xsl:template>

<xsl:template match="bpel:correlation">
</xsl:template>

<xsl:template match="bpel:flow">
  {
    declare curr_node BPEL.BPEL.node;

    curr_node := BPEL.BPEL.node::new_flow (curr_parent_node, script_inst);
    declare curr_parent_node BPEL.BPEL.node;
    curr_parent_node := curr_node;

    	<xsl:apply-templates/>

      <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_parent_node, pmask, nodes_cnt, current_scope, ctx);
  }
</xsl:template>

<xsl:template match="bpel:pick">
  {
    declare curr_node BPEL.BPEL.node;

    curr_node := BPEL.BPEL.node::new_node (
    	curr_parent_node,
	new BPEL.BPEL.pick ('<xsl:value-of select="@createInstance"/>'),
	script_inst);

    declare curr_parent_node BPEL.BPEL.node;
    curr_parent_node := curr_node;

    <xsl:apply-templates/>

    <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_parent_node, pmask, nodes_cnt, current_scope, ctx);
  }
</xsl:template>

<xsl:template match="bpel:onMessage">
  <xsl:variable name="pt" select="@portType"/>
  <xsl:variable name="op" select="@operation"/>
  <xsl:variable name="pl" select="@partnerLink"/>
  {
    declare curr_node BPEL.BPEL.node;
    declare corrs any;
    corrs := null;
    <xsl:for-each select="bpel:correlations/bpel:correlation">
		corrs := BPEL.BPEL.vector_push ( corrs,
		vector ('<xsl:value-of select="@set"/>',
			'<xsl:value-of select="@initiate"/>', 'in'),
			'any');
    </xsl:for-each>

    curr_node := BPEL.BPEL.node::new_node (
    	curr_parent_node,
	new BPEL.BPEL.onmessage
	(
	 '<xsl:value-of select="$pl"/>',
	 '<xsl:value-of select="$pt"/>',
	 '<xsl:value-of select="$op"/>',
	 '<xsl:value-of select="@variable"/>',
	 '<xsl:value-of select="parent::bpel:pick/@createInstance"/>',
	 corrs,
	 <xsl:value-of select="not boolean (//descendant::reply [ @portType = $pt and @operation = $op and @partnerLink = $pl])"/>
	),
	script_inst);
    <xsl:if test="parent::bpel:eventHandlers">
     events := vector_concat (events, vector (curr_node.bn_id));
    </xsl:if>

    declare curr_parent_node BPEL.BPEL.node;
    curr_parent_node := curr_node;

    <xsl:apply-templates/>

    <xsl:if test="parent::bpel:eventHandlers">
    <!-- special jump instruction to the start of event -->
    {
      declare curr_node BPEL.BPEL.node;
      curr_node :=
      BPEL.BPEL.node::new_node  (curr_parent_node,
      	new BPEL.BPEL.jump (curr_parent_node.bn_activity.ba_id, curr_parent_node.bn_id), script_inst);
	<xsl:call-template name="get-links-clear"/>
      BPEL.BPEL.store_new_node (curr_node, pmask, nodes_cnt, current_scope, ctx);
    }
    </xsl:if>

    insert soft BPEL..operation (bo_script, bo_name, bo_partner_link, bo_port_type, bo_init)
    values (script_inst, '<xsl:value-of select="$op"/>', '<xsl:value-of select="$pl"/>', '<xsl:value-of select="$pt"/>', <xsl:value-of select="boolean(parent::bpel:pick/@createInstance)"/>);

    <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_parent_node, pmask, nodes_cnt, current_scope, ctx);
  }
</xsl:template>

<xsl:template match="bpel:onAlarm">
  {
    declare curr_node BPEL.BPEL.node;

    curr_node := BPEL.BPEL.node::new_node (
    	curr_parent_node,
	new BPEL.BPEL.onalarm
	(
	 '<xsl:value-of select="virt:encode_base64(@for)"/>',
	 '<xsl:value-of select="virt:encode_base64(@until)"/>'
	),
	script_inst);
    <xsl:if test="parent::bpel:eventHandlers">
     events := vector_concat (events, vector (curr_node.bn_id));
    </xsl:if>

    declare curr_parent_node BPEL.BPEL.node;
    curr_parent_node := curr_node;

    <xsl:apply-templates/>

    <xsl:if test="parent::bpel:eventHandlers">
    <!-- special jump instruction to the start of event -->
    {
      declare curr_node BPEL.BPEL.node;
      curr_node :=
      BPEL.BPEL.node::new_node  (curr_parent_node,
      	new BPEL.BPEL.jump (curr_parent_node.bn_activity.ba_id, curr_parent_node.bn_id), script_inst);
	<xsl:call-template name="get-links-clear"/>
      BPEL.BPEL.store_new_node (curr_node, pmask, nodes_cnt, current_scope, ctx);
    }
    </xsl:if>

    <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_parent_node, pmask, nodes_cnt, current_scope, ctx);
  }
</xsl:template>

<xsl:template match="bpel:terminate">
  {
    declare curr_node BPEL.BPEL.node;

    curr_node := BPEL.BPEL.node::new_node ( curr_parent_node, new BPEL.BPEL.terminate (), script_inst);

    <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_node, pmask, nodes_cnt, current_scope, ctx);
  }
</xsl:template>

<xsl:template match="bpel:compensate">
  {
    declare curr_node BPEL.BPEL.node;
    curr_node := BPEL.BPEL.node::new_compensate (
		curr_parent_node, script_inst,
		'<xsl:value-of select="@scope"/>');
      <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_node, pmask, nodes_cnt, current_scope, ctx);
  }
</xsl:template>
<xsl:template match="bpel:switch">
  {
    declare curr_node BPEL.BPEL.node;
    curr_node := BPEL.BPEL.node::new_node (curr_parent_node, new BPEL.BPEL.switch(), script_inst);
    declare curr_parent_node BPEL.BPEL.node;
    curr_parent_node := curr_node;
    	<xsl:apply-templates/>
      <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_parent_node, pmask, nodes_cnt, current_scope, ctx);
  }
</xsl:template>
<xsl:template match="bpel:case">
  {
    declare curr_node BPEL.BPEL.node;
    curr_node := BPEL.BPEL.node::new_node (curr_parent_node,
    	new BPEL.BPEL.case1('<xsl:value-of select="virt:encode_base64(@condition)"/>'),
	script_inst);
    declare curr_parent_node BPEL.BPEL.node;
    curr_parent_node := curr_node;
    	<xsl:apply-templates/>
      <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_parent_node, pmask, nodes_cnt, current_scope, ctx);
  }
</xsl:template>
<xsl:template match="bpel:otherwise">
  {
    declare curr_node BPEL.BPEL.node;
    curr_node := BPEL.BPEL.node::new_node (curr_parent_node, new BPEL.BPEL.otherwise(), script_inst);
    declare curr_parent_node BPEL.BPEL.node;
    curr_parent_node := curr_node;
    	<xsl:apply-templates/>
      <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_parent_node, pmask, nodes_cnt, current_scope, ctx);
  }
</xsl:template>
<xsl:template match="bpel:wait">
  {
    declare curr_node BPEL.BPEL.node;
    curr_node := BPEL.BPEL.node::new_node (curr_parent_node, new BPEL.BPEL.wait('<xsl:value-of select="@for"/>'), script_inst);
    declare curr_parent_node BPEL.BPEL.node;
    curr_parent_node := curr_node;
      <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_parent_node, pmask, nodes_cnt, current_scope, ctx);
  }
</xsl:template>

<xsl:template match="bpelx:exec">
  <xsl:choose>
    <xsl:when test="not (@import)">
      curr_node := BPEL.BPEL.node::new_node (curr_parent_node, new BPEL.BPEL.java_exec('<xsl:value-of select="@name"/>', '<xsl:value-of select="virt:encode_base64 (node())"/>', java_imports), script_inst);
    </xsl:when>
    <xsl:when test="@import">
      java_imports := java_imports || 'import <xsl:value-of select="@import"/>;\n';
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="bpelv:exec">
  <xsl:choose>
    <xsl:when test="@import and @binding='JAVA'">
      java_imports := java_imports || 'import <xsl:value-of select="@import"/>;\n';
    </xsl:when>
    <xsl:when test="@using and @binding='CLR'">
      clr_imports := clr_imports || 'using <xsl:value-of select="@using"/>;\n';
    </xsl:when>
    <xsl:when test="@ref and @binding='CLR'">
      clr_refs := BPEL.BPEL.vector_push (clr_refs, '<xsl:value-of select="@ref"/>', 'any');
    </xsl:when>
    <xsl:otherwise>
  {
    declare curr_node BPEL.BPEL.node;
    <xsl:choose>
      <xsl:when test="@binding='SQL'">
	    curr_node := BPEL.BPEL.node::new_node (curr_parent_node, new BPEL.BPEL.sql_exec('<xsl:value-of select="virt:encode_base64(node())"/>'), script_inst);
      </xsl:when>
      <xsl:when test="@binding='JAVA' and not @import">
        curr_node := BPEL.BPEL.node::new_node (curr_parent_node, new BPEL.BPEL.java_exec('<xsl:value-of select="@name"/>', '<xsl:value-of select="virt:encode_base64 (node())"/>', java_imports), script_inst);
      </xsl:when>
      <xsl:when test="@binding='CLR' and (not @using) and (not @ref)">
        curr_node := BPEL.BPEL.node::new_node (curr_parent_node, new BPEL.BPEL.clr_exec('<xsl:value-of select="@name"/>', '<xsl:value-of select="virt:encode_base64 (node())"/>', clr_imports, clr_refs), script_inst);
      </xsl:when>
      <xsl:when test="@binding='PYTHON'">
	    curr_node := BPEL.BPEL.node::new_node (curr_parent_node, new BPEL.BPEL.sql_exec('<xsl:value-of select="node()"/>'), script_inst);
      </xsl:when>
      <xsl:when test="@binding='PERL'">
	    curr_node := BPEL.BPEL.node::new_node (curr_parent_node, new BPEL.BPEL.sql_exec('<xsl:value-of select="node()"/>'), script_inst);
      </xsl:when>
      <xsl:when test="@binding='MONO'">
	    curr_node := BPEL.BPEL.node::new_node (curr_parent_node, new BPEL.BPEL.sql_exec('<xsl:value-of select="node()"/>'), script_inst);
      </xsl:when>
    </xsl:choose>
    declare curr_parent_node BPEL.BPEL.node;
    curr_parent_node := curr_node;
      <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_parent_node, pmask, nodes_cnt, current_scope, ctx);
  }
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
<xsl:template match="bpel:while">
  {
    declare curr_node BPEL.BPEL.node;
    curr_node := BPEL.BPEL.node::new_node (curr_parent_node, new BPEL.BPEL.while_st('<xsl:value-of select="virt:encode_base64(@condition)"/>'), script_inst);
    declare curr_parent_node BPEL.BPEL.node;
    curr_parent_node := curr_node;
    <xsl:choose>
	<xsl:when test="not (bpel:scope)">
	    <xsl:message terminate="yes">The source is not expanded</xsl:message>
	    <!--
    {
      declare curr_node BPEL.BPEL.node;
      declare current_scope, current_fault, current_fault_bit int;
      declare s_enclosing_scp any;

      curr_node := BPEL.BPEL.node::new_scope  (curr_parent_node, script_inst, null);
      s_enclosing_scp := vector_concat (enclosing_scp, vector (curr_node.bn_id));

      declare curr_parent_node BPEL.BPEL.node;
      declare enclosing_scp any;

      enclosing_scp := s_enclosing_scp;
      curr_parent_node := curr_node;
      current_scope := curr_node.bn_id;
       <xsl:apply-templates/>
      <xsl:call-template name="get-links-clear"/>
      BPEL.BPEL.store_new_node (curr_parent_node, pmask, nodes_cnt, current_scope, ctx);
    }
      -->
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates/>
      </xsl:otherwise>
    </xsl:choose>
    <!-- jump is inside scope before compensation in order to get it known false -->

      <xsl:call-template name="get-links"/>
    BPEL.BPEL.store_new_node (curr_parent_node, pmask, nodes_cnt, current_scope, ctx);
  }
</xsl:template>


</xsl:stylesheet>

