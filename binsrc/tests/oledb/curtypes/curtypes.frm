VERSION 5.00
Begin VB.Form CurTypes 
   BackColor       =   &H80000016&
   Caption         =   "CurTypes"
   ClientHeight    =   3945
   ClientLeft      =   60
   ClientTop       =   345
   ClientWidth     =   3750
   LinkTopic       =   "Form1"
   ScaleHeight     =   3945
   ScaleWidth      =   3750
   StartUpPosition =   3  'Windows Default
   Begin VB.TextBox txtPassword 
      Height          =   285
      IMEMode         =   3  'DISABLE
      Left            =   1680
      PasswordChar    =   "*"
      ScrollBars      =   1  'Horizontal
      TabIndex        =   5
      Top             =   1320
      Width           =   1695
   End
   Begin VB.TextBox txtUserID 
      Height          =   285
      Left            =   1680
      TabIndex        =   4
      Top             =   960
      Width           =   1695
   End
   Begin VB.CommandButton cmdStop 
      Caption         =   "Stop"
      Height          =   375
      Left            =   2040
      TabIndex        =   1
      Top             =   2520
      Width           =   1335
   End
   Begin VB.ComboBox cmbProvider 
      Height          =   315
      ItemData        =   "curtypes.frx":0000
      Left            =   1680
      List            =   "curtypes.frx":000A
      Style           =   2  'Dropdown List
      TabIndex        =   2
      Top             =   240
      Width           =   1695
   End
   Begin VB.ComboBox cmbLockType 
      Height          =   315
      ItemData        =   "curtypes.frx":0022
      Left            =   1680
      List            =   "curtypes.frx":0032
      Style           =   2  'Dropdown List
      TabIndex        =   7
      Top             =   2040
      Width           =   1695
   End
   Begin VB.ComboBox cmbCursorType 
      Height          =   315
      ItemData        =   "curtypes.frx":006C
      Left            =   1680
      List            =   "curtypes.frx":007C
      Style           =   2  'Dropdown List
      TabIndex        =   6
      Top             =   1680
      Width           =   1695
   End
   Begin VB.TextBox txtDataSource 
      Height          =   285
      Left            =   1680
      TabIndex        =   3
      Top             =   600
      Width           =   1695
   End
   Begin VB.CommandButton cmdRun 
      Caption         =   "Run"
      Height          =   375
      Left            =   360
      TabIndex        =   0
      Top             =   2520
      Width           =   1335
   End
   Begin VB.Label lblPassword 
      Caption         =   "Password"
      Height          =   255
      Left            =   360
      TabIndex        =   17
      Top             =   1320
      Width           =   975
   End
   Begin VB.Label lblUser 
      Caption         =   "User ID"
      Height          =   255
      Left            =   360
      TabIndex        =   16
      Top             =   960
      Width           =   975
   End
   Begin VB.Label lblProvider 
      Caption         =   "Provider"
      Height          =   255
      Left            =   360
      TabIndex        =   15
      Top             =   240
      Width           =   975
   End
   Begin VB.Label lblLockType 
      Caption         =   "Lock Type"
      Height          =   255
      Left            =   360
      TabIndex        =   14
      Top             =   2040
      Width           =   975
   End
   Begin VB.Label lblCursorType 
      Caption         =   "Cursor Type"
      Height          =   255
      Left            =   360
      TabIndex        =   13
      Top             =   1680
      Width           =   975
   End
   Begin VB.Label lblDataSource 
      Caption         =   "Data Source"
      Height          =   255
      Left            =   360
      TabIndex        =   12
      Top             =   600
      Width           =   975
   End
   Begin VB.Label lblRowsFetched 
      Alignment       =   1  'Right Justify
      BorderStyle     =   1  'Fixed Single
      Height          =   255
      Left            =   1680
      TabIndex        =   11
      Top             =   3120
      Width           =   1695
   End
   Begin VB.Label lblRowsFetchedLabel 
      Caption         =   "Rows Fetched"
      Height          =   255
      Left            =   360
      TabIndex        =   10
      Top             =   3120
      Width           =   1095
   End
   Begin VB.Label lblElapsedTime 
      Alignment       =   1  'Right Justify
      BackColor       =   &H8000000A&
      BorderStyle     =   1  'Fixed Single
      Height          =   255
      Left            =   1680
      TabIndex        =   9
      Top             =   3480
      Width           =   1695
   End
   Begin VB.Label lblElapsedTimeLabel 
      Caption         =   "Elapsed Time"
      Height          =   255
      Left            =   360
      TabIndex        =   8
      Top             =   3480
      Width           =   1095
   End
End
Attribute VB_Name = "CurTypes"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit

Dim oConn As ADODB.Connection
Dim oRSet As ADODB.Recordset
Dim fStop As Boolean

Private Sub cmdRun_Click()
    Run
End Sub

Private Sub cmdStop_Click()
    fStop = True
End Sub

Private Sub Run()
    Dim strConn As String
    Dim dblStart As Double
    Dim dblEnd As Double
    Dim dblCur As Double
    Dim iCount As Long

    lblRowsFetched.Caption = 0
    lblElapsedTime.Caption = 0
    DoEvents

    Select Case cmbProvider.ListIndex
    Case 0
        strConn = "Provider=VIRTOLEDB;Data Source=" & txtDataSource.Text & _
        ";User Id=" & txtUserID.Text & ";Password=" & txtPassword.Text & _
        ";Initial Catalog=Demo;Prompt=Complete;"
    Case 1
        strConn = "Provider=MSDASQL" & _
        ";Extended Properties=""DRIVER={OpenLink Virtuoso Driver};HOST=" & txtDataSource.Text & _
        ";UID=" & txtUserID.Text & ";PWD=" & txtPassword.Text & _
        ";DATABASE=Demo"";Prompt=Complete;"
    End Select

    Set oConn = New ADODB.Connection
    oConn.CursorLocation = adUseServer
    oConn.Open strConn

    Set oRSet = New ADODB.Recordset
    oRSet.Open "select * from orders", oConn, cmbCursorType.ListIndex, cmbLockType.ListIndex + 1, adCmdText

    iCount = 0
    fStop = False
    dblStart = Timer

    oRSet.MoveFirst
    Do Until oRSet.EOF
        iCount = iCount + 1
        
        If (iCount Mod 10) = 0 Then
            dblCur = Timer
    
            lblRowsFetched.Caption = iCount
            lblElapsedTime.Caption = FormatNumber(dblCur - dblStart, 4)
            DoEvents
    
            If fStop Then
                Exit Do
            End If
        End If
    
        oRSet.MoveNext
    Loop
    
    dblEnd = Timer
    lblRowsFetched.Caption = iCount
    lblElapsedTime.Caption = FormatNumber(dblCur - dblStart, 4)

    oRSet.Close
    Set oRSet = Nothing
    
    oConn.Close
    Set oConn = Nothing
End Sub

Private Sub Form_Load()
    cmbProvider.ListIndex = 0
    txtDataSource.Text = "localhost:1111"
    cmbCursorType.ListIndex = 0
    cmbLockType.ListIndex = 0
End Sub

Private Sub CurTypes_Unload(Cancel As Integer)
    If oRSet.State = adStateOpen Then
        oRSet.Close
        Set oRSet = Nothing
    End If
    If oConn.State = adStateOpen Then
        oConn.Close
        Set oConn = Nothing
    End If
End Sub

