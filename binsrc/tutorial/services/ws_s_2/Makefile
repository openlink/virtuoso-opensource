CS=csc.exe

CS_WINFORMS_IMPORTS=/R:System.DLL /R:System.Windows.Forms.DLL  /R:System.Drawing.DLL

OUTDIR=.

#set path to the Microsoft.WSDK.dll
CSLIBFLAGS=/lib:.

CS_EXE_FLAGS=/nologo $(CSLIBFLAGS)

TARGETS = \
  $(OUTDIR)\SymClient.exe
CLEANUP = \
  $(OUTDIR)\SymClient.exe \
  $(OUTDIR)\SymClient.pdb \
  $(OUTDIR)\*.webinfo \
  $(OUTDIR)\referralCache.config \

IMPORTS=$(CS_WINFORMS_IMPORTS) /r:System.dll /r:System.Web.Services.dll /r:System.Data.dll /r:System.Xml.dll /r:Microsoft.WSDK.dll

all : $(TARGETS)

$(OUTDIR)\SymClient.exe : SymClient.cs
  @if not exist $(OUTDIR) md $(OUTDIR)
  $(CS) $(CS_EXE_FLAGS) $(IMPORTS) /out:$@ $**


clean :
  @for %i in ( $(CLEANUP) ) do @if exist %i del %i
