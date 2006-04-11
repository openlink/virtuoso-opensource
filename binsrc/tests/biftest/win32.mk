phplib=php4ts.lib
jdk=c:/j2sdk1.4.1_01

mono=../mono

virt_lib=libvirtuoso-odbc-t.lib
virt_lib_gc=libvirtuoso-odbc-t-gc.lib
virt_inc=include
virt_cflags=-DWIN32 -DBIF_SAMPLES -I $(virt_inc)

cl_cflags=/Zi /MT
gcc_cflags=-mno-cygwin -g

EXES=virtuoso-odbc-php-t.exe virtuoso-odbc-javavm-t.exe virtuoso-odbc-clr-t.exe \
	virtuoso-odbc-clr-javavm-php-t.exe virtuoso-odbc-mono-t.exe


all: $(EXES)

clean:
	del h_bif_server*.obj
	del *.ilk *.pdb
	del $(EXES)

php_objs=bif_server_php.obj $(phplib)
javavm_objs=javavm.obj sql_code_javavm.obj $(jdk)\lib\jvm.lib
clr_objs=basec_clr.obj dotnet.obj sql_code_clr.obj
mono_objs=basec_mono.obj mono.obj sql_code_clr.obj
mono_libs=$(mono)/lib/libmono.a $(mono)/lib/gc.dll $(mono)/lib/libglib-2.0-0.dll $(mono)/lib/libgmodule-2.0-0.dll $(mono)/lib/libintl-1.dll -lws2_32 -lpsapi

virtuoso-odbc-php-t.exe: $(virt_lib) $(php_objs) bif_server.c
	cl $(cl_cflags) $(virt_cflags) -Foh_bif_server_php.obj -Fevirtuoso-odbc-php-t.exe \
	-DPHP \
	 $(php_objs) \
	 bif_server.c $(virt_lib)


virtuoso-odbc-javavm-t.exe: $(javavm_objs) sql_code_xslt.obj bif_server.c
	cl $(cl_cflags) $(virt_cflags) -Foh_bif_server_javavm.obj -Fevirtuoso-odbc-javavm-t.exe \
	-DJAVAVM \
	 sql_code_xslt.obj $(javavm_objs) \
	 bif_server.c $(virt_lib)

virtuoso-odbc-clr-t.exe: $(clr_objs) sql_code_xslt.obj bif_server.c
	cl $(cl_cflags) $(virt_cflags) -Foh_bif_server_clr.obj -Fevirtuoso-odbc-clr-t.exe \
	-DCLR \
         $(clr_objs) sql_code_xslt.obj \
	 bif_server.c $(virt_lib)

virtuoso-odbc-mono-t.exe: $(mono_objs) sql_code_xslt.obj bif_server.c
	gcc $(gcc_cflags) $(virt_cflags) -ovirtuoso-odbc-mono-t.exe \
	-DMONO \
         $(mono_objs) sql_code_xslt.obj  $(mono_libs) \
	 bif_server.c $(virt_lib_gc)

virtuoso-odbc-clr-javavm-php-t.exe:  $(php_objs) $(javavm_objs) $(clr_objs) sql_code_xslt.obj bif_server.c
	cl $(cl_cflags) $(virt_cflags) -Foh_bif_server_clr_javavm_php.obj -Fevirtuoso-odbc-clr-javavm-php-t.exe \
	-DCLR \
	-DJAVAVM \
	-DPHP \
         sql_code_xslt.obj \
	 $(clr_objs) $(javavm_objs) $(php_objs) \
	 bif_server.c $(virt_lib)
