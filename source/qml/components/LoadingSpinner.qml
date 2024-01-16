import QtQuick 2.15
import QtQuick.Controls 2.15

import gui 1.0

import "../style"

SIcon {
    id: root
    iconColor: null
    opacity: 0.5
    icon: "qrc:/icons/loading-big.svg"

    RotationAnimator {
        loops: Animation.Infinite
        target: root
        from: 0
        to: 360
        duration: 1000
        running: root.visible && GUI.windowActive
    }
}