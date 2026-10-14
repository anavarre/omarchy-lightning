import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "anavarre.lightning"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󱐋"
    tooltipText: "Lightning launcher"
    onPressed: function(buttonCode) {
      if (root.bar && buttonCode === Qt.LeftButton)
        root.bar.run("omarchy-shell shell toggle anavarre.lightning")
    }
  }
}
