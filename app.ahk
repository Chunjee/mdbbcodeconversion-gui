#NoEnv
SetBatchLines, -1
#SingleInstance force

#Include %A_ScriptDir%\node_modules
#Include neutron.ahk\export.ahk

; Create a new NeutronWindow and navigate to our HTML page
neutron := new NeutronWindow()
neutron.Load("gui\Bootstrap.html")

; Use the Gui method to set a custom label prefix for GUI events. This code is
; equivalent to the line `Gui, name:+LabelNeutron` for a normal GUI.
neutron.Gui("+LabelNeutron")

; Show the Neutron window
neutron.Show()
; Set up a timer to make dynamic page updates.
return


fn_fieldChanged(neutron, event)
{
	; formData := neutron.qs("#input").value
	formData := event.target.value
	neutron.doc.getElementById("ahk_output").innerText := Convert(formData)
}

; FileInstall all your dependencies, but put the FileInstall lines somewhere
; they won't ever be reached. Right below your AutoExecute section is a great
; location!
FileInstall, gui\Bootstrap.html, gui\Bootstrap.html
FileInstall, gui\bootstrap.min.css, gui\bootstrap.min.css
FileInstall, gui\bootstrap.min.js, gui\bootstrap.min.js
FileInstall, gui\jquery.min.js, gui\jquery.min.js

; The built in GuiClose, GuiEscape, and GuiDropFiles event handlers will work
; with Neutron GUIs. Using them is the current best practice for handling these
; types of events. Here, we're using the name NeutronClose because the GUI was
; given a custom label prefix up in the auto-execute section.
NeutronClose:
ExitApp
return


Button(neutron, event)
{
	MsgBox, % "You clicked " event.target.innerText
}

submit(neutron, event)
{
	; form will redirect the page by default, but we want to handle the form data ourself.
	event.preventDefault()

	; Use Neutron's GetFormData method to process the form data into a form that
	; is easily accessed. Fields that have a 'name' attribute will be keyed by
	; that, or if they don't they'll be keyed by their 'id' attribute.
	formData := neutron.GetFormData(event.target)

	; You can access all of the form fields by iterating over the FormData
	; object. It will go through them in the order they appear in the HTML.
	; out := ""
	; for name, value in formData
	; 	out .= name ": " value "`n"
	; out .= "`n"

	out := ""
	for name, value in formData
		out .= value "`n"
	out .= "`n"

	; You can also get field values by name directly. Use object dot notation
	; with the field name/id.
	; out .= "Email: " formData.inputEmail "`n"

	; Show the output
	neutron.doc.getElementById("ahk_output").innerText := Convert(out)
}



; ------------------
; functions
; ------------------

Convert(Post)
{
	Post := RegExReplace(Post, "`a)\R", "`r`n")

	; Pull out alternate sections
	Alternatives := []
	for Match, Ctx in new RegExMatchAll(Post, "sO)<!-- alternate[\s\R]+(.+?)[\s\R]+-->.+?<!-- /alternate -->")
	{
		Alternatives.Push(Match[1])
		Ctx.Replacement := "@@Alternate" A_Index "@@"
	}
	Post := Ctx.Haystack

	; Pull out code blocks
	CodeBlocks := []
	for Match, Ctx in new RegExMatchAll(Post, "sO)``````.*?\R(.+?)\R``````")
	{
		CodeBlocks.Push(Match[1])
		Ctx.Replacement := "@@CodeBlock" A_Index "@@"
	}
	Post := Ctx.Haystack

	; Pull out spoilers
	Spoilers := []
	for Match, Ctx in new RegExMatchAll(Post, "sO)<!-- spoiler -->(.+?)<!-- /spoiler -->")
	{
		Spoilers.Push(Match[1])
		Ctx.Replacement := "@@Spoiler" A_Index "@@"
	}
	Post := Ctx.Haystack

	; Parse each paragraph
	Post := ParseBlocks(Post)

	; Restore spoilers
	for Match, Ctx in new RegExMatchAll(Post, "O)@@Spoiler(\d+)@@")
		Ctx.Replacement := "[spoiler]" ParseBlocks(Spoilers[Match[1]]) "[/spoiler]"
	Post := Ctx.Haystack

	; Restore code block
	for Match, Ctx in new RegExMatchAll(Post, "O)@@CodeBlock(\d+)@@")
		Ctx.Replacement := "[code]" CodeBlocks[Match[1]] "[/code]"
	Post := Ctx.Haystack

	; Restore alternatives
	for Match, Ctx in new RegExMatchAll(Post, "O)@@Alternate(\d+)@@")
		Ctx.Replacement := Alternatives[Match[1]]
	Post := Ctx.Haystack

	return Trim(Post, "`r`n `t")
}

; https://gist.github.com/G33kDude/1601bd24996cf380e03bcf2c2d9c2372#regular-expressions
class RegExMatchAll
{
	__New(ByRef Haystack, ByRef Needle)
	{
		this.Haystack := Haystack
		this.Needle := Needle
	}

	_NewEnum()
	{
		this.Pos := 0
		return this
	}

	Next(ByRef Match, ByRef Context)
	{
		if this.HasKey("Replacement")
		{
			Len := StrLen(IsObject(this.Match) ? this.Match.Value : this.Match)
			this.Haystack := SubStr(this.Haystack, 1, this.Pos-1)
			. this.Replacement
			. SubStr(this.Haystack, this.Pos + Len)
			this.Delete("Replacement")
		}
		Context := this
		this.Pos := RegExMatch(this.Haystack, this.Needle, Match, this.Pos+1)
		this.Match := Match
		return !!this.Pos
	}
}

ParseBlocks(Post)
{
	Post := RegExReplace(Trim(Post, "`r`n `t"), "`\R{2,}", "`r`n`r`n")
	Paras := []
	for i, Para in Strsplit(Post, "`r`n`r`n")
		Paras.Push(ParseBlock(Para))
	Post := ""
	for i, Para in Paras
		Post .= Para "`r`n`r`n"
	return Post
}

ParseBlock(Post)
{
	; Parse lists
	Lists := "m`n)(^(\*|\d\.)\s+.+(?:\R[ \t]+.+)*\R?)+"
	for Match, Ctx in new RegExMatchAll(Post, Lists)
	{
		Match := RTrim(Match, "`r`n")
		Ctx.Replacement := "[list"	 (Match ~= "^\d" ? "=1" : "") "]"
		Lines := StrSplit(Match, "`n", "`r")
		while Lines.length()
		{
			; Trim off list item marker
			Line := RegExReplace(Lines.RemoveAt(1), "^(\*|\d\.)\s+")

			; Get whole list item
			if RegExMatch(Lines[1], "^\s+", Whitespace)
			{
				while (Lines[1] ~= "^" Whitespace)
					Line .= "`r`n" SubStr(Lines.RemoveAt(1), 1+StrLen(Whitespace))
			}

			; Parse the list item
			Ctx.Replacement .= "[*]" ParseBlocks(Line)
		}
		Ctx.Replacement .= "[/list]"
	}
	Post := Ctx.Haystack

	Replacements :=
	( LTrim Join Comments
	[
		["s)!\[.+?\]\(\s*(.+?)\s*\)", "[img]$1[/img]"],
		["s)\[([^\[\]]+?)\]\(\s*(.+?)\s*\)", "[url=$2]$1[/url]"],
		["\*\*(.+?)\*\*", "[b]$1[/b]"],
		["&sup1;", Chr(0xB9)],
		["&sup2;", Chr(0xB2)],
		["&sup3;", Chr(0xB3)],
		["m)(?<!^|\[)\*(.+?)\*", "[i]$1[/i]"],
		["m)^###\s*(.+)", "[size=125]$1[/size]"],
		["m)^##\s*(.+)", "<br>[size=150]$1[/size]"],
		["m)^#\s*(.+)", "<br><br>[size=200]$1[/size]"],
		["<!-- spoiler -->", "[spoiler]"],
		["<!-- /spoiler -->", "[/spoiler]"],
		["&#9888;", " :!: "],
		["<sub>", "[size=85]"],
		["</sub>", "[/size]"],
		["s)``(.+?)``", "[c]$1[/c]"],
		["m)^[-=]{3,}$", "[hr][/hr]"]
	]
	)
	for k, v in Replacements
		Post := RegExReplace(Post, v[1], v[2])
		Post := RegExReplace(Post, "^\R", "")
		Post := RegExReplace(Post, "\R", " ")
		Post := RegExReplace(Post, "<br>", "`r`n")
	return Post
}

print(obj)
{
	output := ""
	if (IsObject(obj)) {
		for k, v in obj {
			if (IsObject(v)) {
				v := print(v)
			}
			output .= k ": " v ",  "
		}
	} else {
		output := obj
	}
	return output
}
