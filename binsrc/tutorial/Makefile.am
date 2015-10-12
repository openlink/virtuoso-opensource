#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2015 OpenLink Software
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
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HOST=localhost $(SHELL) ./make_vad.sh

clean-local:
	-rm -rf vad vad_files

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST= \
	$(srcdir)/*.css \
	$(srcdir)/*.html \
	$(srcdir)/*.js \
	$(srcdir)/*.owl \
	$(srcdir)/*.sql \
	$(srcdir)/*.vsp \
	$(srcdir)/*.xml \
	$(srcdir)/*.xsl \
	bin/tabcontrol.dll \
	bin/tabcontrol2.dll \
	$(srcdir)/images/*.gif \
	$(srcdir)/images/*.jpg \
	$(srcdir)/images/*.png \
	$(srcdir)/images/tree/*.gif \
	$(srcdir)/images/tree/*.png \
	$(srcdir)/intprot/*.css \
	$(srcdir)/intprot/*.xml \
	$(srcdir)/intprot/nn_s_1/*.vsp \
	$(srcdir)/intprot/nn_s_1/*.xml \
	$(srcdir)/intprot/nn_s_2/*.vsp \
	$(srcdir)/intprot/nn_s_2/*.xml \
	$(srcdir)/intprot/sm_s_1/*.vsp \
	$(srcdir)/intprot/sm_s_1/*.xml \
	$(srcdir)/intprot/sm_s_2/*.xml \
	$(srcdir)/intprot/sm_s_3/*.sql \
	$(srcdir)/intprot/sm_s_3/*.xml \
	$(srcdir)/intprot/sm_s_4/*.sql \
	$(srcdir)/intprot/sm_s_4/*.vsp \
	$(srcdir)/intprot/sm_s_4/*.xml \
	$(srcdir)/intprot/sm_s_5/*.sql \
	$(srcdir)/intprot/sm_s_5/*.vsp \
	$(srcdir)/intprot/sm_s_5/*.xml \
	$(srcdir)/intprot/sm_s_6/*.vsp \
	$(srcdir)/intprot/sm_s_6/*.xml \
	$(srcdir)/intprot/sm_s_7/*.vsp \
	$(srcdir)/intprot/sm_s_7/*.xml \
	$(srcdir)/linkeddata/*.xml \
	$(srcdir)/linkeddata/sem_s_1/*.xml \
	make_vad.sh \
	$(srcdir)/linkeddata/*.xml \
	$(srcdir)/linkeddata/*.xml \
	$(srcdir)/linkeddata/sem_s_1/*.xml \
	$(srcdir)/linkeddata/sem_s_1/*.xml \
	$(srcdir)/rdf/*.xml \
	$(srcdir)/rdf/fs_s_1/*.vsp \
	$(srcdir)/rdf/fs_s_1/*.xml \
	$(srcdir)/rdf/rd_s_1/*.sql \
	$(srcdir)/rdf/rd_s_1/*.xml \
	$(srcdir)/rdf/rd_s_2/*.sql \
	$(srcdir)/rdf/rd_s_2/*.xml \
	$(srcdir)/rdf/rd_s_2/*.py \
	$(srcdir)/rdf/ri_s_1/*.gif \
	$(srcdir)/rdf/ri_s_1/*.js \
	$(srcdir)/rdf/ri_s_1/*.sql \
	$(srcdir)/rdf/ri_s_1/*.vsp \
	$(srcdir)/rdf/ri_s_1/*.vspx \
	$(srcdir)/rdf/ri_s_1/*.xml \
	$(srcdir)/rdf/rq_s_2/*.php \
	$(srcdir)/rdf/rq_s_2/*.sql \
	$(srcdir)/rdf/rq_s_2/*.xml \
	$(srcdir)/rdf/rq_s_3/*.gif \
	$(srcdir)/rdf/rq_s_3/*.js \
	$(srcdir)/rdf/rq_s_3/*.php \
	$(srcdir)/rdf/rq_s_3/*.sql \
	$(srcdir)/rdf/rq_s_3/*.xml \
	$(srcdir)/rdfview/*.xml \
	$(srcdir)/rdfview/rd_v_1/*.sql \
	$(srcdir)/rdfview/rd_v_1/*.xml \
	$(srcdir)/rdfview/rd_v_1/*.owl \
	$(srcdir)/rdfview/rd_v_1/*.isparql \
	$(srcdir)/repl/*.css \
	$(srcdir)/repl/*.xml \
	$(srcdir)/repl/re_ds_1/*.sql \
	$(srcdir)/repl/re_ds_1/*.vsp \
	$(srcdir)/repl/re_ds_1/*.xml \
	$(srcdir)/repl/re_sb_1/*.sql \
	$(srcdir)/repl/re_sb_1/*.xml \
	$(srcdir)/repl/re_sb_2/*.sql \
	$(srcdir)/repl/re_sb_2/*.xml \
	$(srcdir)/repl/re_sb_3/*.sql \
	$(srcdir)/repl/re_sb_3/*.xml \
	$(srcdir)/repl/re_sb_4/*.sql \
	$(srcdir)/repl/re_sb_4/*.vsp \
	$(srcdir)/repl/re_sb_4/*.xml \
	$(srcdir)/repl/re_sd_1/*.sql \
	$(srcdir)/repl/re_sd_1/*.xml \
	$(srcdir)/repl/re_sd_2/*.sql \
	$(srcdir)/repl/re_sd_2/*.xml \
	$(srcdir)/repl/re_sd_3/*.sql \
	$(srcdir)/repl/re_sd_3/*.xml \
	$(srcdir)/repl/re_sm_1/*.xml \
	$(srcdir)/repl/re_xb_1/*.sql \
	$(srcdir)/repl/re_xb_1/*.xml \
	$(srcdir)/repl/re_xb_2/*.sql \
	$(srcdir)/repl/re_xb_2/*.xml \
	$(srcdir)/repl/re_xb_3/*.sql \
	$(srcdir)/repl/re_xb_3/*.xml \
	$(srcdir)/repl/re_xb_4/*.sql \
	$(srcdir)/repl/re_xb_4/*.xml \
	root_filelist \
	$(srcdir)/semweb/*.xml \
	$(srcdir)/semweb/sem_s_1/*.xml \
	$(srcdir)/syntax/*.css \
	$(srcdir)/syntax/*.js \
	vad_version \
	$(srcdir)/wap/*.css \
	$(srcdir)/wap/*.xml \
	$(srcdir)/wap/wa_b_1/*.vsp \
	$(srcdir)/wap/wa_b_1/*.xml \
	$(srcdir)/wap/wa_b_1/*.xsl \
	$(srcdir)/wap/wa_b_2/*.vsp \
	$(srcdir)/wap/wa_b_2/*.xml \
	$(srcdir)/wap/wa_b_2/*.xsl \
	$(srcdir)/wap/wa_b_3/*.sql \
	$(srcdir)/wap/wa_b_3/*.vsp \
	$(srcdir)/wap/wa_b_3/*.xml \
	$(srcdir)/web2/*.xml \
	$(srcdir)/webid/*.html \
	$(srcdir)/webid/*.php \
	$(srcdir)/webid/*.vsp \
	$(srcdir)/xmlapps/*.xml \
	$(srcdir)/xmlsql/*.css \
	$(srcdir)/xmlsql/*.xml \
	$(srcdir)/xmlsql/*.xsl \
	$(srcdir)/xmlsql/ms_a_1/*.sql \
	$(srcdir)/xmlsql/ms_a_1/*.xml \
	xmlsql/ms_a_1/Cat_Product.xsd \
	xmlsql/ms_a_1/Customer_Order.xsd \
	xmlsql/ms_a_1/CustOr_constant.xsd \
	xmlsql/ms_a_1/Cust_Order_attr.xsd \
	xmlsql/ms_a_1/Cust_Order_OD.xsd \
	xmlsql/ms_a_1/EmpSchema.xsd \
	$(srcdir)/xmlsql/ms_a_2/*.vsp \
	$(srcdir)/xmlsql/ms_a_2/*.xml \
	$(srcdir)/xmlsql/ms_a_3/*.vsp \
	$(srcdir)/xmlsql/ms_a_3/*.xml \
	$(srcdir)/xmlsql/ms_a_3a/*.vsp \
	$(srcdir)/xmlsql/ms_a_3a/*.xml \
	$(srcdir)/xmlsql/ms_a_3b/*.vsp \
	$(srcdir)/xmlsql/ms_a_3b/*.xml \
	$(srcdir)/xmlsql/ms_a_4/*.vsp \
	$(srcdir)/xmlsql/ms_a_4/*.xml \
	$(srcdir)/xmlsql/ms_a_5/*.vsp \
	$(srcdir)/xmlsql/ms_a_5/*.xml \
	$(srcdir)/xmlsql/xp_v_1/*.sql \
	$(srcdir)/xmlsql/xp_v_1/*.xml \
	$(srcdir)/xmlsql/xp_v_2/*.vsp \
	$(srcdir)/xmlsql/xp_v_2/*.xml \
	$(srcdir)/xmlsql/xp_v_3/*.xml \
	$(srcdir)/xmlsql/xs_s_1/*.sql \
	$(srcdir)/xmlsql/xs_s_1/*.vsp \
	$(srcdir)/xmlsql/xs_s_1/*.xml \
	$(srcdir)/xmlsql/xs_s_2/*.sql \
	$(srcdir)/xmlsql/xs_s_2/*.vsp \
	$(srcdir)/xmlsql/xs_s_2/*.xml \
	$(srcdir)/xmlsql/xs_s_3/*.vsp \
	$(srcdir)/xmlsql/xs_s_3/*.xml \
	$(srcdir)/xmlsql/xs_s_4/*.vsp \
	$(srcdir)/xmlsql/xs_s_4/*.xml \
	$(srcdir)/xmlsql/xs_s_5/*.sql \
	$(srcdir)/xmlsql/xs_s_5/*.vsp \
	$(srcdir)/xmlsql/xs_s_5/*.xml \
	$(srcdir)/xmlsql/xs_s_5/*.xsl \
	$(srcdir)/xmlsql/xs_s_6/*.vsp \
	$(srcdir)/xmlsql/xs_s_6/*.xml \
	$(srcdir)/xmlsql/xs_s_7/*.html \
	$(srcdir)/xmlsql/xs_s_7/*.vsp \
	$(srcdir)/xmlsql/xs_s_7/*.xml \
	$(srcdir)/xmlsql/xs_s_7/*.xsl \
	$(srcdir)/xmlsql/xs_s_8/*.sql \
	$(srcdir)/xmlsql/xs_s_8/*.vsp \
	$(srcdir)/xmlsql/xs_s_8/*.xml \
	$(srcdir)/xmlsql/xs_s_9/*.sql \
	$(srcdir)/xmlsql/xs_s_9/*.vsp \
	$(srcdir)/xmlsql/xs_s_9/*.xml \
	$(srcdir)/xmlsql/xs_u_1/*.sql \
	$(srcdir)/xmlsql/xs_u_1/*.vsp \
	$(srcdir)/xmlsql/xs_u_1/*.xml \
	$(srcdir)/xmlsql/xs_u_1/*.xsl \
	$(srcdir)/xmlsql/xs_u_2/*.sql \
	$(srcdir)/xmlsql/xs_u_2/*.vsp \
	$(srcdir)/xmlsql/xs_u_2/*.xml \
	$(srcdir)/xmlsql/xs_u_3/*.html \
	$(srcdir)/xmlsql/xs_u_3/*.sql \
	$(srcdir)/xmlsql/xs_u_3/*.xml \
	$(srcdir)/xmlsql/xs_u_3/*.xsl \
	$(srcdir)/xmlxslt/*.xml \
	$(srcdir)/xmlxslt/xs_d_1/*.vsp \
	$(srcdir)/xmlxslt/xs_d_1/*.xml \
	$(srcdir)/xmlxslt/xs_e_1/*.sql \
	$(srcdir)/xmlxslt/xs_e_1/*.vsp \
	$(srcdir)/xmlxslt/xs_e_1/*.xml \
	$(srcdir)/xmlxslt/xs_e_1/*.xsl \
	$(srcdir)/xmlxslt/xs_f_1/*.vsp \
	$(srcdir)/xmlxslt/xs_f_1/*.xml \
	$(srcdir)/xmlxslt/xs_f_1/*.xsl \
	$(srcdir)/xmlxslt/xs_f_2/*.vsp \
	$(srcdir)/xmlxslt/xs_f_2/*.xml \
	$(srcdir)/xmlxslt/xs_l_1/*.vsp \
	$(srcdir)/xmlxslt/xs_l_1/*.xml \
	$(srcdir)/xmlxslt/xs_t_1/*.sql \
	$(srcdir)/xmlxslt/xs_t_1/*.vsp \
	$(srcdir)/xmlxslt/xs_t_1/*.xml
