pragma Singleton
import QtQuick 2.15

QtObject {
    readonly property var pointValue: 9.3
    readonly property var pointLabel: 9.4

    property var light: false

    property var factor: light ? 0.35 : 1.0

    property var bg00:  light ? "#e5e5e5" : "#1a1a1a"
    property var bg0:   light ? "#e2e2e2" : "#1d1d1d"
    property var bg0_5: light ? "#dfdfdf" : "#202020"
    property var bg1:   light ? "#dbdbdb" : "#242424"
    property var bg1_5: light ? "#d8d8d8" : "#272727"
    property var bg2:   light ? "#d5d5d5" : "#2a2a2a"
    property var bg2_5: light ? "#d2d2d2" : "#2d2d2d"
    property var bg3:   light ? "#cfcfcf" : "#303030"
    property var bg3_5: light ? "#c6c6c6" : "#393939"
    property var bg4:   light ? "#afafaf" : "#404040"
    property var bg5:   light ? "#9f9f9f" : "#505050"
    property var bg6:   light ? "#8f8f8f" : "#606060"
    property var bg7:   light ? "#7f7f7f" : "#707070"

    property var fg0:   light ? "#020202" : "#ffffff"
    property var fg1:   light ? "#0f0f0f" : "#eeeeee"
    property var fg1_3: light ? "#111111" : "#dddddd"
    property var fg1_5: light ? "#222222" : "#cccccc"
    property var fg2:   light ? "#444444" : "#aaaaaa"
    property var fg3:   light ? "#555555" : "#909090"

    property var selectionColor: light ? "#999999" : "#666666"
    property var selectionTextColor: light ? "#ffffff" : "#000000"

    function accent(hue, saturation=0.8, value=0.65, alpha=1.0) {
        return Qt.hsva(hue+0.45, saturation, value, alpha)
    }
}