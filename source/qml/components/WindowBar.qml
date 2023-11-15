import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt.labs.platform 1.1

import gui 1.0

import "../style"

SMenuBar {
    id: root

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
        width: 200
        SMenuItem {
            text: "Generate"
            shortcut: "Ctrl+Return"
            global: true
            onPressed: {
                if(!GUI.isGenerating) {
                    GUI.generate()
                }
            }            
        }

        SMenuItem {
            text: "Regenerate"
            shortcut: "Ctrl+Tab"
            global: true
            onPressed: {
                if(!GUI.isGenerating) {
                    GUI.regenerate()
                }
            }            
        }
    }
    SMenu {
        title: "View"
        clipShadow: true
        SMenuItem {
            text: "None"
        }
    }
    SMenu {
        title: "Help"
        clipShadow: true
        SMenuItem {
            text: "About"
            onPressed: {
                GUI.openLink("https://github.com/arenasys")
            }
        }
    }
}