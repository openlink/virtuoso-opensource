CS=csc.exe

CS_WINFORMS_IMPORTS=/R:System.DLL /R:System.Windows.Forms.DLL  /R:System.Drawing.DLL

OUTDIR=.

#this should be set to the path to the Microsoft.Web.Services.dll
CSLIBFLAGS=/lib:.

CS_EXE_FLAGS=/nologo $(CSLIBFLAGS)

TARGETS = \
  $(OUTDIR)\UsernameClient.exe \
  $(OUTDIR)\UsernameClient2.exe
CLEANUP = \
  $(OUTDIR)\UsernameClient.exe \
  $(OUTDIR)\UsernameClient2.exe \
  $(OUTDIR)\UsernameClient.pdb

IMPORTS=$(CS_WINFORMS_IMPORTS) /r:System.dll /r:System.Web.Services.dll /r:System.Data.dll /r:System.Xml.dll /r:Microsoft.Web.Services.dll

IMPORTS2=$(CS_WINFORMS_IMPORTS) /r:System.dll /r:System.Web.Services.dll /r:System.Data.dll /r:System.Xml.dll /r:Microsoft.Web.Services2.dll

all : $(TARGETS)

$(OUTDIR)\UsernameClient.exe : UsernameClient.cs
  @if not exist $(OUTDIR) md $(OUTDIR)
  $(CS) $(CS_EXE_FLAGS) $(IMPORTS) /out:$@ $**

$(OUTDIR)\UsernameClient2.exe : UsernameClient2.cs
  @if not exist $(OUTDIR) md $(OUTDIR)
  $(CS) $(CS_EXE_FLAGS) $(IMPORTS2) /out:$@ $**

clean :
  @for %i in ( $(CLEANUP) ) do @if exist %i del %i
