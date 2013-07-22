LOG=DETVerTest.log
ifndef PORT
PORT=2121
endif

.SUFFIXES: .sql .m4

.PHONY: all
all: test

.m4.sql:
	m4 $< > $@

test: DETVerTest.sql DET_Versioning.sql dav_ver_new.sql test.m4
#	isql 2121 dba dba dav_ver_new.sql 2>&1
#	isql 2121 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT DET_Versioning.sql
	isql $(PORT) dba dba DETVerTest.sql > /dev/null 2> $(LOG)
	@cat $(LOG)
	@echo -e " **********************"
	@cat $(LOG) | awk ' BEGIN { e = 0; p = 0 } /^PASSED/ { p = p + 1 } /^\*\*\*FAILED:/ { e = e + 1 } END { print "* TOTAL:\t " e + p; print "* FAILED:\t " e }'
	@echo -e " **********************"


