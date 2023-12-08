import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt.labs.platform 1.1

import gui 1.0

import "../style"

SMenuBar {
    id: root

    function showPreferences() {
        return
    }

    function showUpdate() {
        return
    }

    SMenu {
        id: menu
        title: "File"
        clipShadow: true
        width: 200

        SMenuItem {
            text: "New"
            shortcut: "Ctrl+N"
            global: true
            onPressed: {
                GUI.new()
            }            
        }

        SMenuSeparator { }

        SMenuItem {
            text: "Open..."
            shortcut: "Ctrl+O"
            global: true
            onPressed: {
                openDialog.open()
            }
            FileDialog {
                id: openDialog
                nameFilters: ["JSON files (*.json)"]
                fileMode: FileDialog.OpenFile

                onAccepted: {
                    GUI.open(file)
                }
            }
        }

        SMenu {
            id: recentMenu
            title: "Open Recent"
            width: 10

            Instantiator {
                model: GUI.recent
                SMenuItem {
                    property var ref
                    text: modelData
                    onPressed: {
                        GUI.openRecent(index)
                        ref.dismiss()
                    }

                    function sync() {
                        if(ref) {
                            var w = Math.min(350, contentWidth+25)
                            if(ref.width < w) {
                                ref.width = w
                            }
                        }
                    }

                    onContentWidthChanged: {
                        sync()
                    }

                    onRefChanged: {
                        sync()
                    }
                }
                onObjectAdded: {
                    object.ref = recentMenu
                    recentMenu.insertItem(index, object)
                }
                onObjectRemoved: recentMenu.removeItem(object)
            }
            
        }

        SMenuSeparator { }

        SMenuItem {
            text: "Save"
            shortcut: "Ctrl+S"
            global: true
            onPressed: {
                if(GUI.file != "") {
                    GUI.save()
                } else {
                    saveDialog.open()
                }
            }            
        }

        SMenuItem {
            text: "Save As…"
            shortcut: "Ctrl+Shift+S"
            global: true
            onPressed: {
                saveDialog.open()
            }

            FileDialog {
                id: saveDialog
                nameFilters: ["JSON files (*.json)"]
                fileMode: FileDialog.SaveFile

                onAccepted: {
                    GUI.saveAs(file)
                }
            }
            
        }

        SMenuSeparator { }

        SMenuItem {
            text: "Update"
            onPressed: {
                root.showUpdate()
            }
        }

        SMenuItem {
            text: "Preferences"
            shortcut: "Ctrl+,"
            global: true
            onPressed: {
                root.showPreferences()
            }
        }


        SMenuSeparator { }

        SMenuItem {
            text: "Quit"
            shortcut: "Ctrl+Shift+Q"
            global: true
            onPressed: {
                GUI.quit()
            }
        }
    }
    SMenu {
        title: "Edit"
        clipShadow: true
        width: 250
        SMenuItem {
            text: "Generate"
            shortcut: "Ctrl+Return, Ctrl+W"
            global: true
            disabled: !GUI.canGenerate
            onPressed: {
                if(!GUI.isGenerating) {
                    GUI.generate()
                }
            }
            onFailed: {
                GUI.fail()
            }
        }

        SMenuItem {
            text: "Regenerate"
            shortcut: "Ctrl+Tab"
            global: true
            disabled: !GUI.canGenerate
            onPressed: {
                if(!GUI.isGenerating) {
                    GUI.regenerate()
                }
            }
            onFailed: {
                GUI.fail()
            }
        }

        SMenuItem {
            text: "Revert"
            shortcut: "Ctrl+`"
            global: true
            disabled: GUI.isGenerating
            onPressed: {
                if(!GUI.isGenerating) {
                    GUI.revert()
                }
            }
            onFailed: {
                GUI.fail()
            }
        }

        
        SMenuItem {
            text: "Abort"
            shortcut: "Ctrl+Q"
            global: true
            disabled: !GUI.isGenerating
            onPressed: {
                if(GUI.isGenerating) {
                    GUI.abort()
                }
            }
            onFailed: {
                GUI.fail()
            }
        }

        SMenuSeparator {}

        SMenuItem {
            text: GUI.modelIsLoaded ? "Reload model" : "Load model"
            shortcut: "Ctrl+L"
            global: true
            disabled: GUI.modelIsWorking
            onPressed: {
                if(!GUI.isGenerating) {
                    GUI.load()
                }
            }
            onFailed: {
                GUI.fail()
            }
        }

        SMenuItem {
            text: "Unload model"
            shortcut: "Ctrl+U"
            global: true
            disabled: !GUI.modelIsLoaded
            onPressed: {
                if(!GUI.isGenerating) {
                    GUI.unload()
                }
            }
            onFailed: {
                GUI.fail()
            }
        }

        SMenuSeparator {}

        SMenuItem {
            text: "Set Marker"
            shortcut: "Ctrl+E, Ctrl+Click"
            global: true
            disabled: GUI.isGenerating
            onPressed: {
                GUI.setMarker()
            }
        }

        SMenuSeparator { }

        SMenu {
            title: "Switch to..."
            
            SMenuItem {
                text: "Sentance"
                shortcut: "Ctrl+1"
                global: true
                onPressed: {
                    GUI.setStopCondition("Sentance")
                }
            }

            SMenuItem {
                text: "Line"
                shortcut: "Ctrl+2"
                global: true
                onPressed: {
                    GUI.setStopCondition("Line")
                }
            }

            SMenuItem {
                text: "Paragraph"
                shortcut: "Ctrl+3"
                global: true
                onPressed: {
                    GUI.setStopCondition("Paragraph")
                }
            }

            SMenuItem {
                text: "None"
                shortcut: "Ctrl+4"
                global: true
                onPressed: {
                    GUI.setStopCondition("None")
                }
            }
        }

        Shortcut {
            sequences: ["Ctrl+W", "Ctrl+Return"]
            onActivated: {
                if(!GUI.isGenerating) {
                    GUI.generate()
                }
            }
        }

        Shortcut {
            sequences: ["Ctrl+E"]
            onActivated: GUI.setMarker()
        }

        Shortcut {
            sequences: ["Ctrl+1"]
            onActivated: GUI.setStopCondition("Sentance")
        }

        Shortcut {
            sequences: ["Ctrl+2"]
            onActivated: GUI.setStopCondition("Line")
        }

        Shortcut {
            sequences: ["Ctrl+3"]
            onActivated: GUI.setStopCondition("Paragraph")
        }

        Shortcut {
            sequences: ["Ctrl+4"]
            onActivated: GUI.setStopCondition("None")
        }
    }
    SMenu {
        title: "View"
        width: 200
        clipShadow: true

        SMenuItem {
            text: "Next Tab"
            shortcut: "Alt+Right"
            global: true
            onPressed: {
                GUI.tabs.current.nextTab()
            }
        }
        SMenuItem {
            text: "Previous Tab"
            shortcut: "Alt+Left"
            global: true
            onPressed: {
                GUI.tabs.current.prevTab()
            }
        }

        SMenuItem {
            text: "Set Tab"
            shortcut: "Alt+1..9"
            onPressed: {

            }
        }

        Shortcut {
            sequences: ["Alt+1"]
            onActivated: GUI.tabs.current.setTab(1)
        }
        Shortcut {
            sequences: ["Alt+2"]
            onActivated: GUI.tabs.current.setTab(2)
        }
        Shortcut {
            sequences: ["Alt+3"]
            onActivated: GUI.tabs.current.setTab(3)
        }
        Shortcut {
            sequences: ["Alt+4"]
            onActivated: GUI.tabs.current.setTab(4)
        }
        Shortcut {
            sequences: ["Alt+5"]
            onActivated: GUI.tabs.current.setTab(5)
        }
        Shortcut {
            sequences: ["Alt+6"]
            onActivated: GUI.tabs.current.setTab(6)
        }
        Shortcut {
            sequences: ["Alt+7"]
            onActivated: GUI.tabs.current.setTab(7)
        }
        Shortcut {
            sequences: ["Alt+8"]
            onActivated: GUI.tabs.current.setTab(8)
        }
        Shortcut {
            sequences: ["Alt+9"]
            onActivated: GUI.tabs.current.setTab(9)
        }

        SMenuSeparator { }

        SMenuItem {
            text: "Next Area"
            shortcut: "Alt+Up"
            global: true
            onPressed: {
                GUI.tabs.nextArea()
            }
        }

        SMenuItem {
            text: "Previous Area"
            shortcut: "Alt+Down"
            global: true
            onPressed: {
                GUI.tabs.prevArea()
            }
        }

        SMenuSeparator { }

        SMenu {
            title: "Overlays..."

            SMenuItem {
                text: "Spell checker"
                checkable: true
                checked: GUI.spellOverlay
                onCheckedChanged: {
                    GUI.spellOverlay = checked
                    checked = Qt.binding(function () { return GUI.spellOverlay; })
                }
            }

            SMenuItem {
                text: "Output stream"
                checkable: true
                checked: GUI.streamOverlay
                onCheckedChanged: {
                    GUI.streamOverlay = checked
                    checked = Qt.binding(function () { return GUI.streamOverlay; })
                }
            }

            SMenuItem {
                text: "Scroll positions"
                checkable: true
                checked: GUI.positionOverlay
                onCheckedChanged: {
                    GUI.positionOverlay = checked
                    checked = Qt.binding(function () { return GUI.positionOverlay; })
                }
            }
        }
    }
    SMenu {
        title: "Help"
        clipShadow: true
        SMenuItem {
            text: "About"
            onPressed: {
                GUI.openLink("https://github.com/arenasys/lineworks")
            }
        }
    }
}