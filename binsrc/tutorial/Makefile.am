#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2012 OpenLink Software
#  
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#  
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#  
#  

TOP=@TOP@

SUBDIRS = . apps hosting services web xml

if WITH_TUTORIAL_VAD
nodist_vad_DATA = tutorial_dav.vad
endif

CLEANFILES = tutorial_filesystem.vad tutorial_dav.vad

tutorial_filesystem.vad tutorial_dav.vad: $(EXTRA_DIST)
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HOST=localhost sh ./make_vad.sh

clean-local:
	-rm -rf vad vad_files

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST= \
	*.css \
	*.html \
	*.js \
	*.owl \
	*.sql \
	*.vsp \
	*.xml \
	*.xsl \
	bin/tabcontrol.dll \
	bin/tabcontrol2.dll \
	images/*.gif \
	images/*.jpg \
	images/*.png \
	images/tree/*.gif \
	images/tree/*.png \
	intprot/*.css \
	intprot/*.xml \
	intprot/nn_s_1/*.vsp \
	intprot/nn_s_1/*.xml \
	intprot/nn_s_2/*.vsp \
	intprot/nn_s_2/*.xml \
	intprot/sm_s_1/*.vsp \
	intprot/sm_s_1/*.xml \
	intprot/sm_s_2/*.xml \
	intprot/sm_s_3/*.sql \
	intprot/sm_s_3/*.xml \
	intprot/sm_s_4/*.sql \
	intprot/sm_s_4/*.vsp \
	intprot/sm_s_4/*.xml \
	intprot/sm_s_5/*.sql \
	intprot/sm_s_5/*.vsp \
	intprot/sm_s_5/*.xml \
	intprot/sm_s_6/*.vsp \
	intprot/sm_s_6/*.xml \
	intprot/sm_s_7/*.vsp \
	intprot/sm_s_7/*.xml \
	linkeddata/*.xml \
	linkeddata/sem_s_1/*.xml \
	make_vad.sh \
	linkeddata/*.xml \
	linkeddata/*.xml \
	linkeddata/sem_s_1/*.xml \
	linkeddata/sem_s_1/*.xml \
	rdf/*.xml \
	rdf/fs_s_1/*.vsp \
	rdf/fs_s_1/*.xml \
	rdf/rd_s_1/*.sql \
	rdf/rd_s_1/*.xml \
	rdf/rd_s_2/*.sql \
	rdf/rd_s_2/*.xml \
	rdf/rd_s_2/*.py \
	rdf/ri_s_1/*.gif \
	rdf/ri_s_1/*.js \
	rdf/ri_s_1/*.sql \
	rdf/ri_s_1/*.vsp \
	rdf/ri_s_1/*.vspx \
	rdf/ri_s_1/*.xml \
	rdf/rq_s_2/*.php \
	rdf/rq_s_2/*.sql \
	rdf/rq_s_2/*.xml \
	rdf/rq_s_3/*.gif \
	rdf/rq_s_3/*.js \
	rdf/rq_s_3/*.php \
	rdf/rq_s_3/*.sql \
	rdf/rq_s_3/*.xml \
	rdfview/*.xml \
	rdfview/rd_v_1/*.sql \
	rdfview/rd_v_1/*.xml \
	rdfview/rd_v_1/*.owl \
	rdfview/rd_v_1/*.isparql \
	repl/*.css \
	repl/*.xml \
	repl/re_ds_1/*.sql \
	repl/re_ds_1/*.vsp \
	repl/re_ds_1/*.xml \
	repl/re_sb_1/*.sql \
	repl/re_sb_1/*.xml \
	repl/re_sb_2/*.sql \
	repl/re_sb_2/*.xml \
	repl/re_sb_3/*.sql \
	repl/re_sb_3/*.xml \
	repl/re_sb_4/*.sql \
	repl/re_sb_4/*.vsp \
	repl/re_sb_4/*.xml \
	repl/re_sd_1/*.sql \
	repl/re_sd_1/*.xml \
	repl/re_sd_2/*.sql \
	repl/re_sd_2/*.xml \
	repl/re_sd_3/*.sql \
	repl/re_sd_3/*.xml \
	repl/re_sm_1/*.xml \
	repl/re_xb_1/*.sql \
	repl/re_xb_1/*.xml \
	repl/re_xb_2/*.sql \
	repl/re_xb_2/*.xml \
	repl/re_xb_3/*.sql \
	repl/re_xb_3/*.xml \
	repl/re_xb_4/*.sql \
	repl/re_xb_4/*.xml \
	root_filelist \
	semweb/*.xml \
	semweb/sem_s_1/*.xml \
	syntax/*.css \
	syntax/*.js \
	vad_version \
	wap/*.css \
	wap/*.xml \
	wap/wa_b_1/*.vsp \
	wap/wa_b_1/*.xml \
	wap/wa_b_1/*.xsl \
	wap/wa_b_2/*.vsp \
	wap/wa_b_2/*.xml \
	wap/wa_b_2/*.xsl \
	wap/wa_b_3/*.sql \
	wap/wa_b_3/*.vsp \
	wap/wa_b_3/*.xml \
	web2/*.xml \
	webid/*.html \
	webid/*.php \
	webid/*.vsp \
	xmlapps/*.xml \
	xmlsql/*.css \
	xmlsql/*.xml \
	xmlsql/*.xsl \
	xmlsql/ms_a_1/*.sql \
	xmlsql/ms_a_1/*.xml \
	xmlsql/ms_a_1/Cat_Product.xsd \
	xmlsql/ms_a_1/Customer_Order.xsd \
	xmlsql/ms_a_1/CustOr_constant.xsd \
	xmlsql/ms_a_1/Cust_Order_attr.xsd \
	xmlsql/ms_a_1/Cust_Order_OD.xsd \
	xmlsql/ms_a_1/EmpSchema.xsd \
	xmlsql/ms_a_2/*.vsp \
	xmlsql/ms_a_2/*.xml \
	xmlsql/ms_a_3/*.vsp \
	xmlsql/ms_a_3/*.xml \
	xmlsql/ms_a_3a/*.vsp \
	xmlsql/ms_a_3a/*.xml \
	xmlsql/ms_a_3b/*.vsp \
	xmlsql/ms_a_3b/*.xml \
	xmlsql/ms_a_4/*.vsp \
	xmlsql/ms_a_4/*.xml \
	xmlsql/ms_a_5/*.vsp \
	xmlsql/ms_a_5/*.xml \
	xmlsql/xp_v_1/*.sql \
	xmlsql/xp_v_1/*.xml \
	xmlsql/xp_v_2/*.vsp \
	xmlsql/xp_v_2/*.xml \
	xmlsql/xp_v_3/*.xml \
	xmlsql/xs_s_1/*.sql \
	xmlsql/xs_s_1/*.vsp \
	xmlsql/xs_s_1/*.xml \
	xmlsql/xs_s_2/*.sql \
	xmlsql/xs_s_2/*.vsp \
	xmlsql/xs_s_2/*.xml \
	xmlsql/xs_s_3/*.vsp \
	xmlsql/xs_s_3/*.xml \
	xmlsql/xs_s_4/*.vsp \
	xmlsql/xs_s_4/*.xml \
	xmlsql/xs_s_5/*.sql \
	xmlsql/xs_s_5/*.vsp \
	xmlsql/xs_s_5/*.xml \
	xmlsql/xs_s_5/*.xsl \
	xmlsql/xs_s_6/*.vsp \
	xmlsql/xs_s_6/*.xml \
	xmlsql/xs_s_7/*.html \
	xmlsql/xs_s_7/*.vsp \
	xmlsql/xs_s_7/*.xml \
	xmlsql/xs_s_7/*.xsl \
	xmlsql/xs_s_8/*.sql \
	xmlsql/xs_s_8/*.vsp \
	xmlsql/xs_s_8/*.xml \
	xmlsql/xs_s_9/*.sql \
	xmlsql/xs_s_9/*.vsp \
	xmlsql/xs_s_9/*.xml \
	xmlsql/xs_u_1/*.sql \
	xmlsql/xs_u_1/*.vsp \
	xmlsql/xs_u_1/*.xml \
	xmlsql/xs_u_1/*.xsl \
	xmlsql/xs_u_2/*.sql \
	xmlsql/xs_u_2/*.vsp \
	xmlsql/xs_u_2/*.xml \
	xmlsql/xs_u_3/*.html \
	xmlsql/xs_u_3/*.sql \
	xmlsql/xs_u_3/*.xml \
	xmlsql/xs_u_3/*.xsl \
	xmlxslt/*.xml \
	xmlxslt/xs_d_1/*.vsp \
	xmlxslt/xs_d_1/*.xml \
	xmlxslt/xs_e_1/*.sql \
	xmlxslt/xs_e_1/*.vsp \
	xmlxslt/xs_e_1/*.xml \
	xmlxslt/xs_e_1/*.xsl \
	xmlxslt/xs_f_1/*.vsp \
	xmlxslt/xs_f_1/*.xml \
	xmlxslt/xs_f_1/*.xsl \
	xmlxslt/xs_f_2/*.vsp \
	xmlxslt/xs_f_2/*.xml \
	xmlxslt/xs_l_1/*.vsp \
	xmlxslt/xs_l_1/*.xml \
	xmlxslt/xs_t_1/*.sql \
	xmlxslt/xs_t_1/*.vsp \
	xmlxslt/xs_t_1/*.xml
