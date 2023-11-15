pragma Singleton
import QtQuick 2.15

QtObject {
    readonly property var pointValue: 9.3
    readonly property var pointLabel: 9.4

    property var bg00: "#1a1a1a"
    property var bg0: "#1d1d1d"
    property var bg0_5: "#202020"
    property var bg1: "#242424"
    property var bg1_5: "#272727"
    property var bg2: "#2a2a2a"
    property var bg2_5: "#2d2d2d"
    property var bg3: "#303030"
    property var bg3_5: "#393939"
    property var bg4: "#404040"
    property var bg5: "#505050"
    property var bg6: "#606060"
    property var bg7: "#707070"

    property var fg0: "#ffffff"
    property var fg1: "#eeeeee"
    property var fg1_3: "#dddddd"
    property var fg1_5: "#cccccc"
    property var fg2: "#aaaaaa"
    property var fg3: "#909090"

    property var selectionColor: "#666666"
    property var selectionTextColor: "#000000"

    function accent(hue, saturation=0.8, value=0.65, alpha=1.0) {
        return Qt.hsva(hue+0.45, saturation, value, alpha)
    }
}