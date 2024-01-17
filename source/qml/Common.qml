pragma Singleton
import QtQuick 2.15

QtObject {
    readonly property var pointValue: 9.3
    readonly property var pointLabel: 9.4

    property var light: scheme == 0
    property var classic: scheme == 2
    property var scheme: 1

    property var bg00:  ["#e5e5e5", "#1a1a1a", "#1a1a1a", "#001419"][scheme]
    property var bg0:   ["#e2e2e2", "#1d1d1d", "#1e1e1e", "#00181d"][scheme]
    property var bg0_5: ["#dfdfdf", "#202020", "#222222", "#001c22"][scheme]
    property var bg1:   ["#dbdbdb", "#242424", "#272727", "#002128"][scheme]
    property var bg1_5: ["#d8d8d8", "#272727", "#2b2b2b", "#00242c"][scheme]
    property var bg2:   ["#d5d5d5", "#2a2a2a", "#2f2f2f", "#002831"][scheme]
    property var bg2_5: ["#d2d2d2", "#2d2d2d", "#343434", "#002c35"][scheme]
    property var bg3:   ["#cfcfcf", "#303030", "#383838", "#002f3a"][scheme]
    property var bg3_5: ["#c6c6c6", "#393939", "#444444", "#003a47"][scheme]
    property var bg4:   ["#9f9f9f", "#404040", "#4e4e4e", "#004351"][scheme]
    property var bg5:   ["#8f8f8f", "#505050", "#646464", "#005669"][scheme]
    property var bg6:   ["#7f7f7f", "#606060", "#7a7a7a", "#006a81"][scheme]
    property var bg7:   ["#6f6f6f", "#707070", "#909090", "#007d99"][scheme]

    property var fg0:   ["#080808", "#ffffff", "#ffffff", "#ffffff"][scheme]
    property var fg1:   ["#121212", "#eeeeee", "#f0f0f0", "#f0f0f0"][scheme]
    property var fg1_3: ["#161616", "#dddddd", "#eeeeee", "#eeeeee"][scheme]
    property var fg1_5: ["#222222", "#cccccc", "#dddddd", "#dddddd"][scheme]
    property var fg2:   ["#444444", "#aaaaaa", "#cccccc", "#cccccc"][scheme]
    property var fg3:   ["#555555", "#909090", "#aaaaaa", "#aaaaaa"][scheme]

    property var selectionColor:     ["#999999", "#666666", "#666666", "#666666"][scheme]
    property var selectionTextColor: ["#ffffff", "#000000", "#000000", "#000000"][scheme]

    function accent(hue, saturation=0.8, value=null, alpha=1.0) {
        if(value == null) {
            value = light ? 0.8 : 0.65
        }
        if(light) {
            hue += 0.2
        }
        if(scheme == 3) {
            hue -= 0.3
            saturation -= 0.2
        }
        return Qt.hsva(hue+0.45, saturation, value, alpha)
    }
}