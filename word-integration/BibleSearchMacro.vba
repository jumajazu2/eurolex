' ============================================================
' Bible Search Macro for Word (VBA)
' ============================================================
' Installation:
' 1. Open Word → Alt+F11 (VBA Editor)
' 2. Insert → Module
' 3. Paste this code
' 4. Add Microsoft WinHTTP Services reference:
'    Tools → References → Check "Microsoft WinHTTP Services, version 5.1"
' 5. Insert → UserForm and name it "frmBibleResults"
' 6. Add controls to the form (see below)
' ============================================================

Option Explicit

' API Configuration
Const API_URL = "https://search.pts-translation.sk/eu_7239_bibles/_search"
Const API_KEY = "7239"
Const API_EMAIL = "juraj.kuban.sk@gmail.com"

' Main search function - triggered by keyboard shortcut or button
Sub SearchBibleFromSelection()
    Dim selectedText As String
    selectedText = Trim(Selection.Text)
    
    If Len(selectedText) = 0 Then
        MsgBox "Please select some text first!", vbExclamation
        Exit Sub
    End If
    
    ' Limit search text length
    If Len(selectedText) > 200 Then
        selectedText = Left(selectedText, 200)
    End If
    
    ' Show loading message
    Application.StatusBar = "Searching Bible for: " & selectedText
    
    ' Perform search
    Dim results As String
    results = SearchBible(selectedText)
    
    ' Display results in UserForm
    If Len(results) > 0 Then
        ShowResults results, selectedText
    Else
        MsgBox "No results found.", vbInformation
    End If
    
    Application.StatusBar = False
End Sub

' HTTP Search Function
Function SearchBible(searchText As String) As String
    On Error GoTo ErrorHandler
    
    Dim http As Object
    Set http = CreateObject("WinHttp.WinHttpRequest.5.1")
    
    ' Build query JSON
    Dim queryJson As String
    queryJson = "{" & _
        """query"":{" & _
            """bool"":{" & _
                """must"":[" & _
                    "{""exists"":{""field"":""en_text""}}," & _
                    "{""multi_match"":{" & _
                        """query"":""" & EscapeJson(searchText) & """," & _
                        """fields"":[""en_text"",""sk_text"",""de_text"",""fr_text"",""de2_text""]," & _
                        """fuzziness"":""AUTO""," & _
                        """minimum_should_match"":""60%""" & _
                    "}}" & _
                "]" & _
            "}" & _
        "}," & _
        """size"":20," & _
        """highlight"":{" & _
            """fields"":{""en_text"":{},""sk_text"":{},""de_text"":{},""fr_text"":{},""de2_text"":{}}" & _
        "}" & _
    "}"
    
    ' Send request
    http.Open "POST", API_URL, False
    http.SetRequestHeader "Content-Type", "application/json"
    http.SetRequestHeader "x-api-key", API_KEY
    http.SetRequestHeader "x-email", API_EMAIL
    http.Send queryJson
    
    ' Return response
    SearchBible = http.ResponseText
    Set http = Nothing
    Exit Function
    
ErrorHandler:
    MsgBox "Error searching Bible: " & Err.Description, vbCritical
    SearchBible = ""
End Function

' Escape JSON special characters
Function EscapeJson(txt As String) As String
    Dim result As String
    result = Replace(txt, "\", "\\")
    result = Replace(result, """", "\""")
    result = Replace(result, vbCr, "\r")
    result = Replace(result, vbLf, "\n")
    result = Replace(result, vbTab, "\t")
    EscapeJson = result
End Function

' Show results in UserForm
Sub ShowResults(jsonResponse As String, searchText As String)
    On Error GoTo ErrorHandler
    ' Parse JSON and show in form
    ' For simplicity, we'll extract key fields with string parsing
    ' (VBA doesn't have native JSON support - you can add JsonConverter if needed)
    
    frmBibleResults.txtSearchTerm.Text = searchText
    frmBibleResults.txtResults.Text = ParseResults(jsonResponse)
    frmBibleResults.txtResults.SelStart = 0  ' Scroll to top
    frmBibleResults.Show vbModeless  ' Non-modal allows interaction with Word
    Exit Sub
    
ErrorHandler:
    MsgBox "Error displaying results: " & Err.Description & vbCrLf & vbCrLf & _
           "Make sure the UserForm has txtSearchTerm and txtResults textboxes!", vbCritical
End Sub

' Open search form (call this to show the form)
Sub OpenBibleSearchForm()
    On Error GoTo ErrorHandler
    
    ' Initialize with empty results
    frmBibleResults.txtSearchTerm.Text = ""
    frmBibleResults.txtResults.Text = "Enter search text and click 'Search Typed Text' or select text in Word and click 'Search Selected Text'"
    frmBibleResults.Show vbModeless
    Exit Sub
    
ErrorHandler:
    MsgBox "Error opening form: " & Err.Description & vbCrLf & vbCrLf & _
           "Make sure frmBibleResults exists with txtSearchTerm and txtResults textboxes!", vbCritical
End Sub

' Simple JSON parser for results (basic implementation)
Function ParseResults(jsonText As String) As String
    Dim results As String
    Dim hits As String
    Dim pos As Long, endPos As Long
    Dim count As Integer
    
    ' Extract total hits
    pos = InStr(jsonText, """total"":{""value"":")
    If pos > 0 Then
        pos = pos + 17
        endPos = InStr(pos, jsonText, ",")
        count = CInt(Mid(jsonText, pos, endPos - pos))
        results = "Found " & count & " verses:" & vbCrLf & vbCrLf
    Else
        results = "Found results:" & vbCrLf & vbCrLf
    End If
    
    ' Extract hits (simplified parsing)
    pos = InStr(jsonText, """hits"":[")
    If pos = 0 Then
        ParseResults = "No results found."
        Exit Function
    End If
    
    ' Store results grouped by book
    Dim bookGroups() As String
    Dim bookIds() As String
    Dim groupCount As Integer
    groupCount = 0
    
    Dim hitCount As Integer
    hitCount = 0
    pos = InStr(pos, jsonText, """_source""")
    
    Do While pos > 0 And hitCount < 20
        hitCount = hitCount + 1
        
        ' Extract book info
        Dim bookId As String, bookName As String
        bookId = ExtractField(jsonText, pos, "book_id")
        bookName = ExtractField(jsonText, pos, "book_name")
        
        ' Extract chapter and verse
        Dim chapter As String, verse As String
        chapter = ExtractField(jsonText, pos, "bible_chapter")
        verse = ExtractField(jsonText, pos, "verse")
        
        ' Extract content (try different language fields)
        Dim content As String
        content = ExtractField(jsonText, pos, "en_text")
        If content = "" Then content = ExtractField(jsonText, pos, "sk_text")
        If content = "" Then content = ExtractField(jsonText, pos, "de_text")
        If content = "" Then content = ExtractField(jsonText, pos, "fr_text")
        If content = "" Then content = ExtractField(jsonText, pos, "de2_text")
        
        ' Find or create book group
        Dim groupIndex As Integer
        groupIndex = -1
        Dim i As Integer
        For i = 0 To groupCount - 1
            If bookIds(i) = bookId Then
                groupIndex = i
                Exit For
            End If
        Next i
        
        If groupIndex = -1 Then
            ' New book group
            groupIndex = groupCount
            groupCount = groupCount + 1
            ReDim Preserve bookIds(0 To groupCount - 1)
            ReDim Preserve bookGroups(0 To groupCount - 1)
            bookIds(groupIndex) = bookId
            bookGroups(groupIndex) = "=== " & bookName & " ===" & vbCrLf
        End If
        
        ' Add verse to group
        If content <> "" Then
            bookGroups(groupIndex) = bookGroups(groupIndex) & _
                "  " & content & " [" & bookName & " " & chapter & ":" & verse & "]" & vbCrLf
        End If
        
        ' Find next hit
        pos = InStr(pos + 100, jsonText, """_source""")
    Loop
    
    ' Combine all groups
    For i = 0 To groupCount - 1
        results = results & bookGroups(i) & vbCrLf
    Next i
    
    ParseResults = results
End Function

' Extract field value from JSON (simple string parsing)
Function ExtractField(jsonText As String, startPos As Long, fieldName As String) As String
    Dim pos As Long, endPos As Long
    Dim searchStr As String
    
    searchStr = """" & fieldName & """:"
    pos = InStr(startPos, jsonText, searchStr)
    
    If pos = 0 Or pos > startPos + 2000 Then
        ExtractField = ""
        Exit Function
    End If
    
    pos = pos + Len(searchStr)
    
    ' Skip whitespace and check if it's a string (starts with ")
    Do While Mid(jsonText, pos, 1) = " "
        pos = pos + 1
    Loop
    
    If Mid(jsonText, pos, 1) = """" Then
        ' String value
        pos = pos + 1
        endPos = InStr(pos, jsonText, """")
        ExtractField = Mid(jsonText, pos, endPos - pos)
    Else
        ' Number value
        endPos = pos
        Do While endPos <= Len(jsonText)
            Dim ch As String
            ch = Mid(jsonText, endPos, 1)
            If ch >= "0" And ch <= "9" Then
                endPos = endPos + 1
            Else
                Exit Do
            End If
        Loop
        ExtractField = Mid(jsonText, pos, endPos - pos)
    End If
    
    ' Unescape JSON
    ExtractField = Replace(ExtractField, "\""", """")
    ExtractField = Replace(ExtractField, "\\", "\")
End Function

' ============================================================
' USER FORM INSTRUCTIONS (frmBibleResults)
' ============================================================
' IMPORTANT: Set UserForm ShowModal property to False!
' 1. Select the UserForm in the designer
' 2. Press F4 (Properties Window)
' 3. Find "ShowModal" property
' 4. Set it to False
'
' Create a UserForm named "frmBibleResults" with these controls:
'
' 1. Label (lblTitle)
'    - Caption: "Bible Search Results"
'    - Font: Bold, 14pt
'
' 2. Label (lblSearchTerm)
'    - Caption: "Search term:"
'
' 3. TextBox (txtSearchTerm)
'    - Width: 300
'
' 4. CommandButton (btnSearchSelection)
'    - Caption: "Search Selected Text"
'    - Width: 150
'
' 5. CommandButton (btnSearch)
'    - Caption: "Search Typed Text"
'    - Width: 150
'
' 6. TextBox (txtResults)
'    - MultiLine: True
'    - ScrollBars: 2 (Vertical)
'    - Width: 400
'    - Height: 300
'    - Locked: True
'
' 7. CommandButton (btnInsert)
'    - Caption: "Insert Selected"
'
' 8. CommandButton (btnClose)
'    - Caption: "Close"
' ============================================================

' UserForm Code (paste in frmBibleResults code window)
' Private Sub btnClose_Click()
'     Unload Me
' End Sub
'
' Private Sub btnSearchSelection_Click()
'     If Selection.Type = wdSelectionNormal And Len(Trim(Selection.Text)) > 0 Then
'         txtSearchTerm.Text = Trim(Selection.Text)
'         SearchBibleFromForm
'     Else
'         MsgBox "Please select text in the Word document first.", vbExclamation
'     End If
' End Sub
'
' Private Sub btnSearch_Click()
'     If Len(Trim(txtSearchTerm.Text)) > 0 Then
'         SearchBibleFromForm
'     Else
'         MsgBox "Please enter search text.", vbExclamation
'     End If
' End Sub
'
' Private Sub SearchBibleFromForm()
'     Dim searchText As String
'     searchText = Trim(txtSearchTerm.Text)
'     
'     If Len(searchText) > 200 Then
'         searchText = Left(searchText, 200)
'     End If
'     
'     Me.txtResults.Text = "Searching..."
'     DoEvents
'     
'     Dim results As String
'     results = SearchBible(searchText)
'     
'     If Len(results) > 0 Then
'         Me.txtResults.Text = ParseResults(results)
'         Me.txtResults.SelStart = 0  ' Scroll to top
'     Else
'         Me.txtResults.Text = "No results found."
'     End If
' End Sub
'
' Private Sub btnInsert_Click()
'     If txtResults.SelLength > 0 Then
'         Selection.TypeText txtResults.SelText
'         MsgBox "Text inserted!", vbInformation
'     Else
'         MsgBox "Please select text to insert first.", vbExclamation
'     End If
' End Sub
'
' Private Sub UserForm_Initialize()
'     Me.Width = 450
'     Me.Height = 500
' End Sub
