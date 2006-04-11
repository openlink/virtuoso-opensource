Attribute VB_Name = "MoveNext"
Option Explicit

Private Sub TestCursor(objConn As ADODB.Connection, _
                       cursorType As ADODB.CursorTypeEnum, _
                       lockType As ADODB.LockTypeEnum, _
                       strDesc As String)
    Dim objRSet As ADODB.Recordset
    'Dim dblStart As Double
    'Dim dblEnd As Double
    'Dim dblCur As Double
    'Dim lngCount As Long

    On Error GoTo OnError

    Set objRSet = New ADODB.Recordset
    objRSet.Open "select * from ""Orders""", objConn, cursorType, lockType, adCmdText

    'lngCount = 0
    'dblStart = Timer

    objRSet.MoveFirst
    Do Until objRSet.EOF
        'lngCount = lngCount + 1
        'If (lngCount Mod 10) = 0 Then
        '    dblCur = Timer
        '    Debug.Print "Rows Feched: ", lngCount, "Elapsed Time: ", FormatNumber(dblCur - dblStart, 4)
        'End If
        objRSet.MoveNext
    Loop

    'dblEnd = Timer
    'Debug.Print "Rows Feched: ", lngCount, "Elapsed Time: ", FormatNumber(dblCur - dblStart, 4)

    objRSet.Close
    Set objRSet = Nothing

    Print #1, "PASSED: ", strDesc

    Exit Sub
OnError:
    Print #1, "Error " & Hex(Err.Number) & ": " & Err.Description
    Print #1, "***FAILED: ", strDesc
End Sub

Sub TestAllCursors(strDataSource As String)
    Dim strConn As String
    Dim objConn As ADODB.Connection

    On Error GoTo OnError

    strConn = "Provider=VIRTOLEDB;Data Source=" & strDataSource & _
              ";User Id=dba;Password=dba;Initial Catalog=Demo;Prompt=NoPrompt;"

    Set objConn = New ADODB.Connection
    objConn.CursorLocation = adUseServer
    objConn.Open strConn

    TestCursor objConn, _
               adOpenForwardOnly, adLockReadOnly, _
               "ForwardOnly cursor with ReadOnly concurrency"
    TestCursor objConn, _
               adOpenStatic, adLockReadOnly, _
               "Static cursor with ReadOnly concurrency"
    TestCursor objConn, _
               adOpenDynamic, adLockReadOnly, _
               "Dynamic cursor with ReadOnly concurrency"
    Rem TestCursor objConn, _
               adOpenDynamic, adLockPessimistic, _
               "Dynamic cursor with Pessimistic concurrency"
    Rem TestCursor objConn, _
               adOpenDynamic, adLockOptimistic, _
               "Dynamic cursor with Optimistic concurrency"
    TestCursor objConn, _
               adOpenKeyset, adLockReadOnly, _
               "Keyset cursor with ReadOnly concurrency"
    Rem TestCursor objConn, _
               adOpenKeyset, adLockPessimistic, _
               "Keyset cursor with Pessimistic concurrency"
    Rem TestCursor objConn, _
               adOpenKeyset, adLockOptimistic, _
               "Keyset cursor with Optimistic concurrency"

    objConn.Close
    Set objConn = Nothing

    Exit Sub
OnError:
    Print #1, "Error " & Hex(Err.Number) & ": " & Err.Description
    Print #1, "***FAILED: Cannot connect to the datasource: " & strDataSource
End Sub

Sub Main()
    Dim strDataSource As String

    Open "vbtest.output" For Output As #1

    strDataSource = Environ("DSN")
    If strDataSource = "" Then
        Print #1, "***FAILED: The DSN environment variable is not set"
    Else
        TestAllCursors strDataSource
    End If

    Exit Sub
OnError:
    Print #1, "Error " & Hex(Err.Number) & ": " & Err.Description
End Sub
