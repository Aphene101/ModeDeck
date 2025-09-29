#Requires AutoHotkey v2.0
#Include "lib\JSON.ahk"
#SingleInstance Force

global W := 1000
global H := 600
global configPath := A_ScriptDir "\..\states.json"
global gModes := []
global maingui
global gCreateDlg := 0
global gEditDlgs := Map()

LoadModes()

Main() {
    global W, H, configPath, gModes, maingui
    LoadModes()

    maingui := Gui()
    maingui.Title := "ModeDeck"
    TraySetIcon(A_ScriptDir "\..\assets\ModeDeck.ico")

    maingui.BackColor := "0x262626"
    maingui.SetFont("cc0c0c0 s40", "Segoe UI")
    title := maingui.Add("Text", "x0 y16 w" W " Center", "Modes")

    maingui.SetFont("s18 cc0c0c0", "Segoe UI")

    title.GetPos(, &tY, , &tH)
    y := tY + tH + 16

    ; ToolTip("Loaded modes: " gModes.Length)
    SetTimer(() => ToolTip(), -1500)

    for idx, mode in gModes
        y := AddModeRow(maingui, mode, y, W, idx)

    y := AddCreateRow(maingui, y, W)

    maingui.Show("w" W " h" H)
}

AddModeRow(gui, mode, y, W, idx) {
    x := 20
    rowH := 60
    inner := 20
    rightPad := 20
    menuW := 28
    textH := 28
    menuH := 28
    top := y + (rowH - menuH) / 2

    nameCtl := gui.AddText(
        "x" (x + inner) " y" top " w" (W - (x + inner) - rightPad - menuW) " h" (menuH) " BackgroundTrans 0x200 +0x100",
        mode.name
    )

    menuCtl := gui.AddText(
        "x" (W - rightPad - menuW) " y" top " w" menuW " h" menuH " Center BackgroundTrans +0x100",
        "⋮"
    )
    menuCtl.OnEvent("Click", (*) => ShowModeMenu(idx))

    gui.AddText("x" x " y" (y + rowH) " w" (W - x * 2) " h1 Background0x434343", "")

    return y + rowH + 1
}

AddCreateRow(gui, y, W) {
    x := 20
    rowH := 60
    inner := 20
    plusH := 50
    top := y + (rowH - plusH) / 2

    gui.SetFont("s25 cc0c0c0", "Segoe UI")

    plus := gui.AddText("x" (x + inner) " y" top " w28" " h" plusH " Center BackgroundTrans +0x100",
    "+")

    plus.OnEvent("Click", ShowCreateModePrompt)

    gui.AddText("x" x " y" (y + rowH) " w" (W - x * 2) " h1 Background0x434343", "")

    return y + rowH + 1
}

ShowCreateModePrompt(*) {
    global gCreateDlg
    if (gCreateDlg && WinExist("ahk_id " gCreateDlg.Hwnd)) {
        gCreateDlg.Show("Center")
        WinActivate("ahk_id " gCreateDlg.Hwnd)
        return
    }
    gCreateDlg := CreateModePrompt()
}

CreateModePrompt(*) {
    newmodeW := 480, newmodeH := 550
    rowY := 128 + 180 + 55
    btnW := 110
    gap := 20
    totalW := btnW * 2 + gap
    startX := (newmodeW - totalW) / 2
    tmpItems := []

    newmode := Gui(, "Create New Mode")
    newmode.BackColor := "0x262626"
    newmode.SetFont("s25 cc0c0c0", "Segoe UI")

    newmode.AddText("x20 y16 w" (newmodeW - 40) " h50 BackgroundTrans Center", "Create a New Mode")

    newmode.SetFont("s14 cc0c0c0", "Segoe UI")
    newmode.AddText("x20 y80 w120 h24 BackgroundTrans", " Mode Name: ")
    newmode.SetFont("s14 c0x262626", "Segoe UI")
    nameInput := newmode.AddEdit("x20 y110 w" (newmodeW - 40) " h28")

    newmode.SetFont("s14 cc0c0c0", "Segoe UI")
    newmode.AddText("x20 y150 w200 h24", "Items:")
    itemsList := newmode.AddListBox("x20 y178 w" (newmodeW - 40) " h180 Background0x333333 c0xDDDDDD")

    btnWeb := newmode.AddButton("x" (startX - 95) " y" (178 + 180 + 12) " w" btnW " h30", "Website")
    btnFile := newmode.AddButton("x" (startX + btnW + 50 - 100) " y" (178 + 180 + 12) " w" btnW " h30", "File")
    btnApp := newmode.AddButton("x" (startX + (btnW + 50) * 2 - 100) " y" (178 + 180 + 12) " w" btnW " h30", "App")
    btnWeb.OnEvent("Click", (*) => PromptAddItem(itemsList, tmpItems, "url"))
    btnFile.OnEvent("Click", (*) => PromptAddItem(itemsList, tmpItems, "file"))
    btnApp.OnEvent("Click", (*) => PromptAddItem(itemsList, tmpItems, "app"))

    removeBtn := newmode.AddButton("x" (20 + 120 + 10) " y" rowY + 55 " w170 h30", "Remove Selected")
    removeBtn.OnEvent("Click", (*) => RemoveSelectedHandler(itemsList, tmpItems))

    saveBtn := newmode.AddButton("x" startX " y" (newmodeH - 56) " w" btnW " h30", "Save")
    cancelBtn := newmode.AddButton("x" (startX + btnW + gap) " y" (newmodeH - 56) " w" btnW " h30", "Cancel")
    cancelBtn.OnEvent("Click", (*) => newmode.Destroy())
    saveBtn.OnEvent("Click", (*) => (
        SaveNewMode(nameInput.Text, tmpItems, newmode)
    ))
    newmode.Show("w" (newmodeW) "h" (newmodeH) "Center")
    return newmode
}

PromptAddItem(itemsList, tmpItems, kind) {
    if (kind = "url") {
        hint := "Example:`nhttps://example.com`nhttps://youtube.com/watch?v=..."
        res := InputBox("Paste a website URL`n`n" hint, "Add Website")
        if (res.Result = "OK" && res.Value != "") {
            v := Trim(res.Value)
            itemsList.Add([" • Website: " v])
            tmpItems.Push({ type: "url", target: v })
        }
    } else if (kind = "file") {
        hint := "Example:`nC:\Users\You\Documents\Report.docx`nD:\Media\song.mp3"
        res := InputBox("Paste a full file path`n`n" hint, "Add File")
        if (res.Result = "OK" && res.Value != "") {
            v := Trim(res.Value)
            itemsList.Add([" • File: " v])
            tmpItems.Push({ type: "file", target: v })
        }
    } else if (kind = "app") {
        hint := "Example:`nC:\Program Files\Google\Chrome\Application\chrome.exe`nC:\Windows\System32\notepad.exe"
        res := InputBox("Paste a full application path (EXE)`n`n" hint, "Add Application")
        if (res.Result = "OK" && res.Value != "") {
            v := Trim(res.Value)
            itemsList.Add([" • App: " v])
            tmpItems.Push({ type: "app", target: v })
        }
    }
}

RemoveSelectedHandler(itemsList, tmpItems) {
    index := itemsList.Value
    if (index <= 0)
        return
    itemsList.Delete(index)
    tmpItems.RemoveAt(index)
}

SaveNewMode(name, items, newmode) {
    if (name = "") {
        MsgBox("Mode name cannot be empty")
        return
    }
    if (items.Length = 0) {
        MsgBox("Add at least one item")
        return
    }

    gModes.Push({ name: name, items: items })
    SaveModes()
    newmode.Destroy()
    RefreshModes()
}

SaveModes() {
    global configPath
    FileDelete(configPath)
    FileAppend(JSON.Dump(gModes), configPath, "UTF-8")
}

GetKeyCI(obj, keys) {
    for k, v in obj {
        for _, want in keys
            if (StrLower(k) = StrLower(want))
                return v
    }
    return ""
}

ShowModeMenu(idx) {
    global gModes
    m := Menu()
    m.Add("Rename", (*) => RenameMode(idx))
    m.Add("Edit", (*) => EditMode(idx))
    m.Add()
    m.Add("Duplicate", (*) => DuplicateMode(idx))
    m.Add("Move Up", (*) => MoveMode(idx, -1))
    m.Add("Move Down", (*) => MoveMode(idx, +1))
    m.Add()
    m.Add("Delete", (*) => DeleteMode(idx))
    m.Show()
}

RenameMode(idx) {
    global gModes
    cur := gModes[idx].name
    res := InputBox("Enter a new name for this mode:", "Rename Mode", "", cur)
    if (res.Result = "OK") {
        newName := Trim(res.Value)
        if (newName != "") {
            gModes[idx].name := newName
            SaveModes()
            RefreshModes()
        }
    }
}

EditMode(idx) {
    global gModes, gEditDlgs
    if (gEditDlgs.Has(idx)) {
        dlg := gEditDlgs[idx]
        if (dlg && WinExist("ahk_id " dlg.Hwnd)) {
            dlg.Show("Center"), WinActivate("ahk_id " dlg.Hwnd)
            return
        } else {
            gEditDlgs.Delete(idx)
        }
    }
    mode := gModes[idx]
    gEditDlgs[idx] := EditModeDialog(idx, mode.name, mode.items)
}

EditModeDialog(idx, nameInit, itemsInit) {
    global gEditDlgs
    newmodeW := 480, newmodeH := 550
    rowY := 128 + 180 + 55
    btnW := 110, gap := 20
    totalW := btnW * 2 + gap
    startX := (newmodeW - totalW) / 2

    tmpItems := DeepClone(itemsInit)

    dlg := Gui(, "Edit Mode")
    dlg.OnEvent("Close", (*) => gEditDlgs.Delete(idx))

    dlg.BackColor := "0x262626"
    dlg.SetFont("s25 cc0c0c0", "Segoe UI")
    dlg.AddText("x20 y16 w" (newmodeW - 40) " h50 BackgroundTrans Center", "Edit Mode")

    dlg.SetFont("s14 cc0c0c0", "Segoe UI")
    dlg.AddText("x20 y80 w120 h24 BackgroundTrans", " Mode Name: ")
    dlg.SetFont("s14 c0x262626", "Segoe UI")
    nameInput := dlg.AddEdit("x20 y110 w" (newmodeW - 40) " h28", nameInit)

    dlg.SetFont("s14 cc0c0c0", "Segoe UI")
    dlg.AddText("x20 y150 w200 h24", "Items:")
    itemsList := dlg.AddListBox("x20 y178 w" (newmodeW - 40) " h180 Background0x333333 c0xDDDDDD")

    ; preload items
    for _, it in tmpItems {
        if !IsObject(it) {
            s := it
            t := RegExMatch(s, "i)^(https?://)") ? "url" : "file"
            lab := (t = "url") ? " • Website: " : (t = "file") ? " • File: " : " • Item: "
            itemsList.Add([lab s])
            continue
        }
        t := StrLower(GetKeyCI(it, ["type"]))
        target := GetKeyCI(it, ["target", "path", "value"])
        lab := (t = "url") ? " • Website: " : (t = "file") ? " • File: " : (t = "app") ? " • App: " : " • Item: "
        itemsList.Add([lab target])
    }

    btnWeb := dlg.AddButton("x" (startX - 95) " y" (178 + 180 + 12) " w" btnW " h30", "Website")
    btnFile := dlg.AddButton("x" (startX + btnW + 50 - 100) " y" (178 + 180 + 12) " w" btnW " h30", "File")
    btnApp := dlg.AddButton("x" (startX + (btnW + 50) * 2 - 100) " y" (178 + 180 + 12) " w" btnW " h30", "App")
    btnWeb.OnEvent("Click", (*) => PromptAddItem(itemsList, tmpItems, "url"))
    btnFile.OnEvent("Click", (*) => PromptAddItem(itemsList, tmpItems, "file"))
    btnApp.OnEvent("Click", (*) => PromptAddItem(itemsList, tmpItems, "app"))

    removeBtn := dlg.AddButton("x150 y" rowY + 55 " w170 h30", "Remove Selected")
    removeBtn.OnEvent("Click", (*) => RemoveSelectedHandler(itemsList, tmpItems))

    saveBtn := dlg.AddButton("x" startX " y" (newmodeH - 56) " w" btnW " h30", "Save")
    cancelBtn := dlg.AddButton("x" (startX + btnW + gap) " y" (newmodeH - 56) " w" btnW " h30", "Cancel")
    cancelBtn.OnEvent("Click", (*) => (dlg.Destroy(), gEditDlgs.Delete(idx)))
    saveBtn.OnEvent("Click", (*) => EditModeSave(idx, nameInput.Text, tmpItems, dlg))

    dlg.Show("w" (newmodeW) "h" (newmodeH) "Center")
    return dlg
}

EditModeSave(idx, name, items, dlg) {
    global gModes, gEditDlgs
    if (Trim(name) = "") {
        MsgBox("Mode name cannot be empty")
        return
    }
    if (items.Length = 0) {
        MsgBox("Add at least one item")
        return
    }
    gModes[idx].name := name
    gModes[idx].items := items
    SaveModes()
    dlg.Destroy()
    gEditDlgs.Delete(idx)
    RefreshModes()
}

DuplicateMode(idx) {
    global gModes
    clone := DeepClone(gModes[idx])
    clone.name := (clone.HasProp("name") ? clone["name"] : "Untitled") " (Copy)"
    gModes.Push(clone)
    SaveModes()
    RefreshModes()
}

MoveMode(idx, delta) {
    global gModes
    to := idx + delta
    if (to < 1 || to > gModes.Length)
        return
    tmp := gModes[idx]
    gModes[idx] := gModes[to]
    gModes[to] := tmp
    SaveModes()
    RefreshModes()
}

DeleteMode(idx) {
    global gModes
    if (MsgBox("Delete this mode?", "Confirm Delete", "YesNo Icon!") = "Yes") {
        gModes.RemoveAt(idx)
        SaveModes()
        RefreshModes()
    }
}

LoadModes() {
    global gModes, configPath

    if !FileExist(configPath) {
        gModes := []
        return
    }

    try {
        txt := FileRead(configPath, "UTF-8")
        if (SubStr(txt, 1, 1) = Chr(0xFEFF)) {
            txt := SubStr(txt, 2)
        }
        data := JSON.Load(txt)

        modes := []
        ok := false

        try {
            if (IsObject(data) && data.Length >= 0) {
                modes := data
                ok := true
            }
        } catch {

        }

        if (!ok && IsObject(data)) {
            if (data.HasProp("modes") && IsObject(data.modes)) {
                modes := data.modes
                ok := true
            } else if (data.HasProp("states") && IsObject(data.states)) {
                modes := data.states
                ok := true
            }
        }

        gModes := []
        if (ok && IsObject(modes)) {
            for k, v in modes {
                m := v
                if !IsObject(m)
                    continue

                n := GetKeyCI(m, ["name", "title", "label"])
                name := (n != "") ? n : "Untitled"

                it := GetKeyCI(m, ["items", "states", "entries"])
                items := (IsObject(it)) ? it : []

                gModes.Push({ name: name, items: items })
            }
        }
    } catch {
        gModes := []
    }
    ToolTip("afterLoad gModes=" gModes.Length), SetTimer(() => ToolTip(), -1500)
}

DeepClone(v) {
    try
        return JSON.Load(JSON.Dump(v))
    catch
        return v
}

RefreshModes() {
    global maingui, gModes, y, W

    maingui.Destroy()
    maingui := Gui()
    maingui.Title := "ModeDeck"
    maingui.BackColor := "0x262626"
    maingui.SetFont("c0xC0C0C0 s40", "Segoe UI")
    title := maingui.Add("Text", "x0 y16 w" W " Center", "Modes")
    maingui.SetFont("s18 c0xC0C0C0", "Segoe UI")

    title.GetPos(, &tY, , &tH)
    y := tY + tH + 16

    for idx, mode in gModes
        y := AddModeRow(maingui, mode, y, W, idx)

    y := AddCreateRow(maingui, y, W)

    maingui.Show("w" W " h" H)
}

Main()