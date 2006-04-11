
VirtuosoSinkps.dll: dlldata.obj VirtuosoSink_p.obj VirtuosoSink_i.obj
	link /dll /out:VirtuosoSinkps.dll /def:VirtuosoSinkps.def /entry:DllMain dlldata.obj VirtuosoSink_p.obj VirtuosoSink_i.obj \
		kernel32.lib rpcndr.lib rpcns4.lib rpcrt4.lib oleaut32.lib uuid.lib \

.c.obj:
	cl /c /Ox /DWIN32 /D_WIN32_WINNT=0x0400 /DREGISTER_PROXY_DLL \
		$<

clean:
	@del VirtuosoSinkps.dll
	@del VirtuosoSinkps.lib
	@del VirtuosoSinkps.exp
	@del dlldata.obj
	@del VirtuosoSink_p.obj
	@del VirtuosoSink_i.obj
