TOP=@TOP@

nodist_vad_DATA = ods_dav.vad

CLEANFILES =  \
	make_ods_vad.log \
	make_ods_vad.xml \
	ods_dav.vad \
	virtuoso.db \
	virtuoso.ini \
	virtuoso.lck \
	virtuoso.log \
	virtuoso.pxa \
	virtuoso.tdb \
	virtuoso.trx

ods_dav.vad: make_vad.sh *.sql *.vspx *.xsl comp/*.xsl
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HOST=localhost sh ./make_vad.sh

clean-local:
	-rm -rf vad

EXTRA_DIST = \
	*.css \
	*.html \
	*.js \
	*.sql \
	*.vsp \
	*.vspx \
	*.xml \
	*.xsl \
	comp/*.js \
	comp/*.xml \
	comp/*.xsl \
	doc/*.png \
	doc/*.vsd \
	icons/*.gif \
	icons/*.png \
	images/*.gif \
	images/*.htm \
	images/*.jpg \
	images/*.png \
	images/dav_browser/*.png \
	images/yac_banner.jfif \
	make_vad.sh \
	readme.txt \
	tmpl/SN_INV_TEMPLATE \
	tmpl/WS_APPROVE_BY_USER_TEMPLATE \
	tmpl/WS_CHANGE_BY_OWNER_TEMPLATE \
	tmpl/WS_INV_TEMPLATE \
	tmpl/WS_JOIN_APPROVE_TEMPLATE \
	tmpl/WS_JOIN_REJECT_TEMPLATE \
	tmpl/WS_MEM_TEMPLATE \
	tmpl/WS_NOT_TEMPLATE \
	tmpl/WS_REG_TEMPLATE \
	tmpl/WS_REJECT_BY_USER_TEMPLATE \
	tmpl/WS_TERM_BY_OWNER_TEMPLATE \
	tmpl/WS_TERM_BY_USER_TEMPLATE \
	vad_version
