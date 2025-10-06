#Requires AutoHotkey v2.0
#Include "lib\JSON.ahk"
#SingleInstance Force

global W := 1000
global H := 600
global configPath := A_ScriptDir "\..\states.json"
global gModes := []
global maingui
global gCreateDlg := ""
global gEditDlgs := Map()
global gModePIDs := Map()
global gLastMode := 0
global profileStateFile := A_ScriptDir "\profiles.json"
global gProfileInitialized := Map()

if FileExist(profileStateFile) {
    try {
        gProfileInitialized := JSON.Load(FileRead(profileStateFile))
    } catch {
        gProfileInitialized := Map()
    }
} else {
    gProfileInitialized := Map()
}

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
    nameCtl.OnEvent("Click", (*) => LaunchMode(idx))

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
    if (gCreateDlg != "" && WinExist("ahk_id " gCreateDlg.Hwnd)) {
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
    if (Trim(name) = "") {
        MsgBox("Mode name cannot be empty")
        return
    }
    if (items.Length = 0) {
        MsgBox("Add at least one item")
        return
    }

    items := NormalizeItems(items)
    mode := { name: name, items: items }
    result := ValidateMode(mode)

    if !result["ok"] {
        msg := "Some items couldn’t be opened. Please fix them:`n`n"
        for err in result["errors"] {
            idx := (err["index"] > 0) ? "#" err["index"] " " : ""
            msg .= "• " idx "[" err["item"] "] — " err["message"] "`n"
        }
        MsgBox(msg, "Validation failed", 0x10)
        return
    }

    gModes.Push({ name: name, items: items })
    SaveModes()
    newmode.Destroy()
    RefreshModes()
}

SaveModes() {
    global configPath
    try FileDelete(configPath)
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
    if (gEditDlgs.HasProp(idx)) {
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
    cancelBtn.OnEvent("Click", (*) => (dlg.Destroy()))
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

    items := NormalizeItems(items)
    mode := { name: name, items: items }
    result := ValidateMode(mode)
    if !result["ok"] {
        msg := "Some items couldn’t be opened. Please fix them:`n`n"
        for err in result["errors"] {
            idx := (err["index"] > 0) ? "#" err["index"] " " : ""
            msg .= "• " idx "[" err["item"] "] — " err["message"] "`n"
        }
        MsgBox(msg, "Validation failed", 0x10)
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

IsProbablyUrl(url) {
    return RegExMatch(url, "i)^(https?://)[^\s/$.?#].[^\s]*$")
}

HttpReachable(url, timeoutMs := 2500) {
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Option[4] := 0x00002000   ; <<< NEW: suppress cert / error dialogs
        req.SetTimeouts(timeoutMs, timeoutMs, timeoutMs, timeoutMs)
        req.Open("HEAD", url, false)
        req.SetRequestHeader("User-Agent", "ModeDeck/1.0 (AHK v2)")
        try {
            req.Send()
        } catch {
            req := ComObject("WinHttp.WinHttpRequest.5.1")
            req.Option[4] := 0x00002000   ; <<< same flag for fallback request
            req.SetTimeouts(timeoutMs, timeoutMs, timeoutMs, timeoutMs)
            req.Open("GET", url, false)
            req.SetRequestHeader("Range", "bytes=0-0")
            req.SetRequestHeader("User-Agent", "ModeDeck/1.0 (AHK v2)")
            req.Send()
        }
        status := req.Status
        return Map("ok", (status >= 200 && status < 400), "status", status, "reason", req.StatusText)
    } catch as e {
        return Map("ok", false, "status", 0, "reason", e.Message)
    }
}

FileOrDirExists(p) {
    s := p . ""
    s := Trim(s)
    if (s = "")
        return false

    if RegExMatch(s, "i)^https?://")
        return false

    try_fe := FileExist(s)
    if (try_fe != "")
        return true

    try {
        f := FileOpen(s, "r")
        if IsObject(f) {
            f.Close()
            return true
        }
    } catch {

    }

    alt := RegExReplace(s, "^file:///*", "")
    alt := StrReplace(alt, "/", "\")
    if (alt != s) {
        if (FileExist(alt) != "")
            return true
        try {
            f2 := FileOpen(alt, "r")
            if IsObject(f2) {
                f2.Close()
                return true
            }
        } catch {
        }
    }

    long := "\\?\" s
    try_long := FileExist(long)
    if (try_long != "")
        return true
    try {
        f3 := FileOpen(long, "r")
        if IsObject(f3) {
            f3.Close()
            return true
        }
    } catch {

    }

    return false
}

FindOnPath(name) {
    if InStr(name, "\") || InStr(name, "/") || RegExMatch(name, "i)^\w:\\") {
        return FileOrDirExists(name) ? name : ""
    }

    pathext := EnvGet("PATHEXT")
    if !pathext
        pathext := ".COM;.EXE;.BAT;.CMD"
    exts := StrSplit(pathext, ";")

    pathvar := EnvGet("PATH")
    if !pathvar
        pathvar := ""
    paths := StrSplit(pathvar, ";")

    for p in paths {
        if !p
            continue
        for ext in exts {
            test := RTrim(p, "\/") "\" name (ext ? ext : "")
            if FileOrDirExists(test)
                return test
        }

        test := RTrim(p, "\/") "\" name
        if FileOrDirExists(test)
            return test
    }
    return ""
}

CleanPath(s) {
    if s = ""
        return ""
    str := s . ""

    str := StrReplace(str, "%20", " ")
    str := StrReplace(str, "%22", "" "")
    str := StrReplace(str, "%28", "(")
    str := StrReplace(str, "%29", ")")
    str := Trim(str)

    if (SubStr(str, 1, 1) = '"' && SubStr(str, 0) = '"')
        str := SubStr(str, 2, StrLen(str) - 2)

    str := RegExReplace(str, "i)^\s*file:///*", "")

    if !RegExMatch(str, "i)^https?://")
        str := StrReplace(str, "/", "\")

    str := Trim(str)
    return str
}

NormalizeItems(items) {
    out := []
    for _, it in items {
        if IsObject(it) && Type(it) = "Map" {
            m := Map()
            if it.Has("type")
                m["type"] := StrLower(it["type"])
            if it.Has("target")
                m["target"] := CleanPath(it["target"])

            for k, v in it {
                lk := StrLower(k)
                if !m.Has("target") && (lk = "target" || lk = "path" || lk = "value" || lk = "url")
                    m["target"] := CleanPath(v)
            }

            if !m.Has("type") && m.Has("target")
                m["type"] := RegExMatch(m["target"], "i)^https?://") ? "url" : "file"

            out.Push(m)
            continue
        }

        if IsObject(it) {
            m := Map()
            try {
                if it.HasProp("type")
                    m["type"] := StrLower(it.type)
                if it.HasProp("target")
                    m["target"] := CleanPath(it.target)
            } catch {
            }
            try {
                for k, v in it {
                    lk := StrLower(k)
                    if !m.Has("target") && (lk = "target" || lk = "path" || lk = "value" || lk = "url")
                        m["target"] := CleanPath(v)
                    if !m.Has("type") && lk = "type"
                        m["type"] := StrLower(v)
                }
            } catch {

            }

            if !m.Has("target")
                m["target"] := CleanPath(ItemToString(it))
            if !m.Has("type")
                m["type"] := RegExMatch(m["target"], "i)^https?://") ? "url" : "file"
            out.Push(m)
            continue
        }

        s := ItemToString(it)
        t := RegExMatch(s, "i)^https?://") ? "url" : "file"
        out.Push({ type: t, target: CleanPath(s) })
    }
    return out
}

ItemToString(x) {
    if x = ""
        return ""
    if IsObject(x) {
        try {
            return JSON.Dump(x)
        } catch as e {
            return ""
        }
    }
    return x . ""
}

CanOpenItem(item) {
    t := ""
    val := ""

    if IsObject(item) {
        typeName := Type(item)

        if (typeName = "Map") {
            if item.Has("type")
                t := StrLower(item["type"])
            if item.Has("target")
                val := item["target"]

            for k, v in item {
                lk := StrLower(k)
                if (lk = "path" || lk = "value" || lk = "url")
                    val := v
            }

        } else {
            if item.HasProp("type")
                t := StrLower(item.type)
            if item.HasProp("target")
                val := item.target

            try {
                for k, v in item {
                    lk := StrLower(k)
                    if (lk = "path" || lk = "value" || lk = "url")
                        val := v
                }
            } catch {
                s := ItemToString(item)
                if (s != "") {
                    t := RegExMatch(s, "i)^https?://") ? "url" : "file"
                    val := s
                }
            }
        }
    } else {
        val := item . ""
        t := RegExMatch(val, "i)^https?://") ? "url" : "file"
    }

    if (t = "")
        return Map("ok", false, "err", "Missing 'type' (url/file/app).")
    if (val = "")
        return Map("ok", false, "err", "Missing value/path/URL (target).")

    switch t {
        case "website", "url":
            if !IsProbablyUrl(val)
                return Map("ok", false, "err", "Invalid URL format.")
            return Map("ok", true)

        case "file":
            if !FileOrDirExists(val)
                return Map("ok", false, "err", "File or folder not found.")
            return Map("ok", true)

        case "app":
            full := FindOnPath(val)
            if !full
                return Map("ok", false, "err", "App not found on PATH or invalid path.")
            if !RegExMatch(StrLower(full), "\.(exe|com|bat|cmd)$")
                return Map("ok", false, "err", "Resolved app is not an executable: " full)
            return Map("ok", true)

        default:
            return Map("ok", false, "err", "Unknown type: " t)
    }
}

ArrayContains(arr, value) {
    if !IsObject(arr)
        return false
    for _, v in arr
        if (v = value)
            return true
    return false
}

ValidateMode(mode) {
    errs := []
    if !mode || !mode.HasProp("items") || Type(mode.items) != "Array" || mode.items.Length = 0
        errs.Push(Map("index", -1, "item", "", "message", "No items in this mode."))

    if mode && mode.HasProp("items") {
        for i, it in mode.items {
            res := CanOpenItem(it)
            if !res["ok"] {
                label := ""
                if IsObject(it) {
                    try {
                        for k, v in it {
                            if (StrLower(k) ~= "^(target|value|path|url|name)$") {
                                label := v
                                break
                            }
                        }
                    }
                } else {
                    label := it . ""
                }

                if !label
                    label := "(item #" i ")"
                errs.Push(Map("index", i, "item", label, "message", res["err"]))
            }
        }
    }
    return errs.Length ? Map("ok", false, "errors", errs) : Map("ok", true, "errors", [])
}

LaunchMode(idx) {
    global gModes, gModePIDs, gLastMode

    mode := gModes[idx]
    if !mode || !mode.HasProp("items") {
        MsgBox("Invalid mode.", "Error", 0x10)
        return
    }

    result := ValidateMode(mode)
    if !result["ok"] {
        MsgBox("Mode contains invalid items. Please fix them first.", "Cannot Launch", 0x10)
        return
    }

    ; --- Kill previous mode safely ---
    if (gModePIDs.Has(idx) OR gLastMode && gLastMode != idx && gModePIDs.Has(gLastMode)) {

        for proc in gModePIDs[gLastMode].pids {
            pid := proc.pid
            try RunWait('taskkill /PID ' pid ' /T /F', , 'Hide')
        }

        for hwnd in gModePIDs[gLastMode].windows {
            try {
                if WinExist("ahk_id " hwnd)
                    WinClose("ahk_id " hwnd)
            }
        }

        gModePIDs.Delete(gLastMode)
    }

    newPids := []
    newWindows := []
    urlsAndPdfs := []
    otherItems := []

    for _, item in mode.items {
        t := StrLower(item["type"])
        target := item["target"]
        if (t = "url" || (t = "file" && RegExMatch(target, "\.pdf$"))) {
            urlsAndPdfs.Push({ target: target, type: t })
        } else {
            otherItems.Push({ target: target, type: t })
        }
    }

    tmpProf := ""
    if (urlsAndPdfs.Length > 0) {
        exe := GetDefaultBrowserExe()
        profName := RegExReplace(mode.name, "[^\w\s-]", "_")
        tmpProf := A_ScriptDir "\profiles\" profName
        DirCreate(tmpProf)

        if !gProfileInitialized.Has(profName) || !IsObject(gProfileInitialized[profName]) {
            gProfileInitialized[profName] := []
        }

        urlsToLaunch := []
        for _, u in urlsAndPdfs {
            if !ArrayContains(gProfileInitialized[profName], u.target)
                urlsToLaunch.Push(u.target)
        }

        if (urlsToLaunch.Length = 0)
            urlsToLaunch := []

        cmd := '"' exe '" --user-data-dir="' tmpProf '" --no-first-run --no-default-browser-check --disable-session-crashed-bubble --restore-last-session=false --allow-pre-commit-input --enable-features=PasswordImport'

        for _, u in urlsToLaunch
            cmd .= ' "' u '"'

        Run cmd, , , &pid

        ; --- mark URLs as launched in profile ---
        for _, u in urlsToLaunch
            gProfileInitialized[profName].Push(u)

        try FileDelete(profileStateFile)
        FileAppend(JSON.Dump(gProfileInitialized), profileStateFile, "UTF-8")

        newPids.Push({ pid: pid, exe: exe })

        if WinWaitActive("ahk_pid " pid, , 10) {
            h := WinExist("ahk_pid " pid)
            if (h) {
                WinMaximize("ahk_id " h)
                newWindows.Push(h)
            }
        }
    }

    for _, it in otherItems {
        target := it.target
        t := it.type
        try {
            if (t = "file" || t = "app") {
                before := WinGetList()
                Run '"' target '"', , , &pid
                newPids.Push({ pid: pid, exe: target })

                foundH := 0
                baseExe := RegExReplace(target, "^.*[\\/]", "")
                loop 20 {
                    Sleep 150
                    for h in WinGetList() {
                        if before.Has(h)
                            continue
                        try procName := WinGetProcessName("ahk_id " h)
                        if (procName && InStr(StrLower(procName), StrLower(baseExe))) {
                            foundH := h
                            break
                        }
                    }
                    if foundH
                        break
                }

                if foundH {
                    WinActivate("ahk_id " foundH)
                    Sleep 100
                    WinMaximize("ahk_id " foundH)
                    newWindows.Push(foundH)
                }
            }
        } catch as e {
            MsgBox("Failed to launch: " target "`n`n" e.Message, "Launch Error", 0x10)
        }
    }

    gModePIDs[idx] := { pids: newPids, windows: newWindows, profile: tmpProf }
    gLastMode := idx
}

GetDefaultBrowserExe() {
    static path := ""
    if (path != "")
        return path

    try {
        progId := RegRead(
            "HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice", "ProgId"
        )
        cmd := RegRead("HKEY_CLASSES_ROOT\" progId "\shell\open\command")
        RegExMatch(cmd, "" "([^" "]+)" "", &m)
        if (m.Length && FileExist(m[1]) && !InStr(StrLower(m[1]), "msedge")) {
            path := m[1]
            return path
        }
    }

    browsers := []
    loop reg, "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths", "K" {
        try {
            exe := RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\" A_LoopRegName)
            if (exe && FileExist(exe)) {
                name := StrLower(A_LoopRegName)
                if (InStr(name, "chrome") || InStr(name, "brave") || InStr(name, "firefox")
                || InStr(name, "opera") || InStr(name, "vivaldi") || InStr(name, "chromium")
                || InStr(name, "browser")) {
                    browsers.Push(exe)
                }
            }
        }
    }

    static fallbacks := ["brave.exe", "chrome.exe", "firefox.exe",
        "opera.exe", "vivaldi.exe", "chromium.exe"]
    for , name in fallbacks
        if ((p := FindOnPath(name)) && FileExist(p))
            browsers.Push(p)

    for , p in browsers
        if (FileExist(p)) {
            path := p
            return path
        }

    path := FileSelect(3, , "Select your browser executable (avoid Edge)", "Programs (*.exe)")
    if (!path)
        path := "chrome.exe"
    return path
}

CloseAllWindows() {
    excludeList := ["ModeDeck", "Task Manager", "Program Manager", "Windows Explorer"]

    windows := WinGetList()
    for hwnd in windows {
        try {
            title := WinGetTitle("ahk_id " hwnd)
            exe := WinGetProcessName("ahk_id " hwnd)
            if (!title || !exe)
                continue

            skip := false
            for _, excl in excludeList {
                if InStr(title, excl) || InStr(exe, excl) {
                    skip := true
                    break
                }
            }

            if (!skip) {
                WinClose("ahk_id " hwnd)
            }
        } catch {

        }
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