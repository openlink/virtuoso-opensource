# Microsoft Developer Studio Generated NMAKE File, Based on bif_sample.dsp
!IF "$(CFG)" == ""
CFG=bif_sample - Win32 Debug
!MESSAGE No configuration specified. Defaulting to bif_sample - Win32 Debug.
!ENDIF

!IF "$(CFG)" != "bif_sample - Win32 Release" && "$(CFG)" != "bif_sample - Win32 Debug"
!MESSAGE Invalid configuration "$(CFG)" specified.
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE
!MESSAGE NMAKE /f "bif_sample.mak" CFG="bif_sample - Win32 Debug"
!MESSAGE
!MESSAGE Possible choices for configuration are:
!MESSAGE
!MESSAGE "bif_sample - Win32 Release" (based on "Win32 (x86) Console Application")
!MESSAGE "bif_sample - Win32 Debug" (based on "Win32 (x86) Console Application")
!MESSAGE
!ERROR An invalid configuration is specified.
!ENDIF

!IF "$(OS)" == "Windows_NT"
NULL=
!ELSE
NULL=nul
!ENDIF

CPP=cl.exe
RSC=rc.exe

!IF  "$(CFG)" == "bif_sample - Win32 Release"

OUTDIR=.
INTDIR=.
# Begin Custom Macros
OutDir=.
# End Custom Macros

ALL : "$(OUTDIR)\bif_sample.exe"


CLEAN :
	-@erase "$(INTDIR)\bif_sample.obj"
	-@erase "$(INTDIR)\vc60.idb"
	-@erase "$(OUTDIR)\bif_sample.exe"

"$(OUTDIR)" :
    if not exist "$(OUTDIR)/$(NULL)" mkdir "$(OUTDIR)"

CPP_PROJ=/nologo /ML /W3 /GX /O2 /I "include" /D "WIN32" /D "NDEBUG" /D "_CONSOLE" /D "_MBCS" /Fp"$(INTDIR)\bif_sample.pch" /YX /Fo"$(INTDIR)\\" /Fd"$(INTDIR)\\" /FD /c
BSC32=bscmake.exe
BSC32_FLAGS=/nologo /o"$(OUTDIR)\bif_sample.bsc"
BSC32_SBRS= \

LINK32=link.exe
LINK32_FLAGS=kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib  kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:console /incremental:no /pdb:"$(OUTDIR)\bif_sample.pdb" /machine:I386 /out:"$(OUTDIR)\bif_sample.exe"
LINK32_OBJS= \
	"$(INTDIR)\bif_sample.obj" \
	".\lib\libvirtuoso-odbc-t.lib"

"$(OUTDIR)\bif_sample.exe" : "$(OUTDIR)" $(DEF_FILE) $(LINK32_OBJS)
    $(LINK32) @<<
  $(LINK32_FLAGS) $(LINK32_OBJS)
<<

!ELSEIF  "$(CFG)" == "bif_sample - Win32 Debug"

OUTDIR=.
INTDIR=.
# Begin Custom Macros
OutDir=.
# End Custom Macros

ALL : "$(OUTDIR)\bif_sample.exe"


CLEAN :
	-@erase "$(INTDIR)\bif_sample.obj"
	-@erase "$(INTDIR)\vc60.idb"
	-@erase "$(INTDIR)\vc60.pdb"
	-@erase "$(OUTDIR)\bif_sample.exe"
	-@erase "$(OUTDIR)\bif_sample.ilk"
	-@erase "$(OUTDIR)\bif_sample.pdb"

"$(OUTDIR)" :
    if not exist "$(OUTDIR)/$(NULL)" mkdir "$(OUTDIR)"

CPP_PROJ=/nologo /MLd /W3 /Gm /GX /ZI /Od /I "include" /D "WIN32" /D "_DEBUG" /D "_CONSOLE" /D "_MBCS" /Fp"$(INTDIR)\bif_sample.pch" /YX /Fo"$(INTDIR)\\" /Fd"$(INTDIR)\\" /FD /GZ  /c
BSC32=bscmake.exe
BSC32_FLAGS=/nologo /o"$(OUTDIR)\bif_sample.bsc"
BSC32_SBRS= \

LINK32=link.exe
LINK32_FLAGS=kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib  kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:console /incremental:yes /pdb:"$(OUTDIR)\bif_sample.pdb" /debug /machine:I386 /out:"$(OUTDIR)\bif_sample.exe" /pdbtype:sept
LINK32_OBJS= \
	"$(INTDIR)\bif_sample.obj" \
	".\lib\libvirtuoso-odbc-t.lib"

"$(OUTDIR)\bif_sample.exe" : "$(OUTDIR)" $(DEF_FILE) $(LINK32_OBJS)
    $(LINK32) @<<
  $(LINK32_FLAGS) $(LINK32_OBJS)
<<

!ENDIF

.c{$(INTDIR)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $<
<<

.cpp{$(INTDIR)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $<
<<

.cxx{$(INTDIR)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $<
<<

.c{$(INTDIR)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $<
<<

.cpp{$(INTDIR)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $<
<<

.cxx{$(INTDIR)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $<
<<


!IF "$(NO_EXTERNAL_DEPS)" != "1"
!IF EXISTS("bif_sample.dep")
!INCLUDE "bif_sample.dep"
!ELSE
!MESSAGE Warning: cannot find "bif_sample.dep"
!ENDIF
!ENDIF


!IF "$(CFG)" == "bif_sample - Win32 Release" || "$(CFG)" == "bif_sample - Win32 Debug"
SOURCE=.\bif_sample.c

"$(INTDIR)\bif_sample.obj" : $(SOURCE) "$(INTDIR)"



!ENDIF

