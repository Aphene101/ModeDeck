#Requires AutoHotkey v2.0
#SingleInstance Force

W := 1000, H := 600
main := Gui()
main.Title := "ModeDeck"
TraySetIcon(A_ScriptDir "\..\assets\ModeDeck.ico")

main.BackColor := "0x262626"
main.SetFont("cc0c0c0 s40", "Segoe UI")
title := main.Add("Text", "x0 y16 w" W " Center", "Modes")

main.SetFont("s18 cc0c0c0", "Segoe UI")

title.GetPos(, &tY, , &tH)
y := tY + tH + 16

y := AddModeRow(main, "Thesis", y, W)
y := AddModeRow(main, "Anime", y, W)
y := AddModeRow(main, "Chill", y, W)
y := AddCreateRow(main, y, W)

main.Show("w" W " h" H)

AddModeRow(gui, name, y, W) {
    x := 20
    rowH := 60
    inner := 20
    rightPad := 20
    menuW := 28
    textH := 28
    menuH := 28
    top := y + (rowH - menuH) / 2

    gui.AddText(
        "x" (x + inner) " y" top " w" (W - (x + inner) - rightPad - menuW) " h" (menuH) " BackgroundTrans" " 0x200",
        name
    )

    gui.AddText(
        "x" (W - rightPad - menuW) " y" top " w" menuW " h" menuH " Center BackgroundTrans +0x100",
        "⋮"
    )

    gui.AddText("x" x " y" (y + rowH) " w" (W - x * 2) " h1 Background0x434343", "")

    return y + rowH + 1
}

AddCreateRow(gui, y, W) {
    x := 20
    rowH := 60
    inner := 20
    plusH := 50
    top := y + (rowH - plusH) / 2

    main.SetFont("s25 cc0c0c0", "Segoe UI")

    gui.AddText("x" (x + inner) " y" top " w28" " h" plusH " Center BackgroundTrans +0x100",
    "+")

    gui.AddText("x" x " y" (y + rowH) " w" (W - x * 2) " h1 Background0x434343", "")

    return y + rowH + 1
}
