import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property var entries: []
  property var results: []
  property int selectedIndex: 0

  readonly property string pluginId: (root.manifest && root.manifest.id) || "anavarre.lightning"
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property string configPath: root.configHome + "/lightning/lightning.conf"
  readonly property string ensureScript: decodeURIComponent(Qt.resolvedUrl("ensure-config.sh").toString().replace(/^file:\/\//, ""))
  readonly property int maxResults: 8

  // Shares the [menu] surface tokens so themes style it like the menu.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int contentSpacing: Style.spacing.md
  property int headerHeight: Math.max(Style.space(38), Style.font.heading + Style.spacing.controlPaddingY * 2)
  property int rowHeight: Math.max(Style.space(36), Style.font.body + Style.spacing.rowPaddingX * 2)
  property int cardWidth: Math.min(Style.space(560), panel.width - Style.gapsOut * 2)
  readonly property int resultsHeight: root.results.length > 0 ? root.contentSpacing + root.rowHeight * root.results.length : 0

  // payloadJson is part of the overlay contract; Lightning takes no caller input.
  function open(payloadJson) {
    root.opened = true
    field.text = ""
    root.refresh()
    ensureConfig.running = true
    Qt.callLater(function() { field.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  // Text after the trigger fills the URL's placeholder: "jira ABC-123".
  function refresh() {
    var query = Model.splitQuery(field.text)
    root.results = Model.lookup(root.entries, query.keyword, root.maxResults).map(function(entry) {
      var takesArgument = Model.hasPlaceholder(entry.url)
      return {
        trigger: entry.trigger,
        takesArgument: takesArgument,
        url: takesArgument && query.argument !== "" ? Model.expandUrl(entry.url, query.argument) : entry.url,
        ready: !takesArgument || query.argument !== ""
      }
    })
    root.selectedIndex = 0
  }

  // Puts the trigger in the field, followed by a space and any argument
  // already typed when its URL has a placeholder.
  function complete(entry) {
    var argument = Model.splitQuery(field.text).argument
    field.text = entry.takesArgument ? entry.trigger + " " + argument : entry.trigger
    field.cursorPosition = field.text.length
  }

  function select(delta) {
    if (root.results.length === 0) return
    root.selectedIndex = (root.selectedIndex + delta + root.results.length) % root.results.length
  }

  function activate(index) {
    var entry = root.results[index]
    if (!entry) return
    if (!entry.ready) {
      root.complete(entry)
      return
    }
    root.dismiss()
    Quickshell.execDetached(["omarchy-launch-browser", entry.url])
  }

  function editConfig() {
    root.dismiss()
    Quickshell.execDetached(["omarchy-launch-editor", root.configPath])
  }

  // Creates ~/.config/lightning/lightning.conf the first time the plugin runs.
  Process {
    id: ensureConfig
    running: false
    command: [root.ensureScript]
    onExited: configFile.reload()
  }

  Component.onCompleted: ensureConfig.running = true

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      root.entries = Model.parseConfig(text())
      root.refresh()
    }
    onLoadFailed: {
      root.entries = []
      root.refresh()
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-lightning"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: card.contentTopInset + card.contentBottomInset + root.headerHeight + root.resultsHeight
      radius: root.cornerRadius
      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.round(parent.height * 0.22)
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: field.forceActiveFocus() }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Item {
          width: parent.width
          height: root.headerHeight

          Text {
            id: glyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "󱐋"
            color: root.selectedText
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
          }

          TextInput {
            id: field
            anchors.left: glyph.right
            anchors.leftMargin: Style.spacing.lg
            anchors.right: addButton.left
            anchors.rightMargin: Style.spacing.lg
            anchors.verticalCenter: parent.verticalCenter
            color: root.foreground
            selectionColor: Style.selectionFillFor(root.foreground, Color.accent, Color.urgent)
            selectedTextColor: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            clip: true
            selectByMouse: true
            focus: true
            onTextChanged: root.refresh()

            Text {
              anchors.fill: parent
              verticalAlignment: Text.AlignVCenter
              visible: field.text === ""
              text: "Type a trigger…"
              color: root.foreground
              opacity: 0.5
              font: field.font
              elide: Text.ElideRight
            }

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                if (field.text !== "") field.text = ""
                else root.dismiss()
                event.accepted = true
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.activate(root.selectedIndex)
                event.accepted = true
              } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier))) {
                root.select(1)
                event.accepted = true
              } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier))) {
                root.select(-1)
                event.accepted = true
              } else if (event.key === Qt.Key_Tab) {
                var entry = root.results[root.selectedIndex]
                if (entry) root.complete(entry)
                event.accepted = true
              }
            }
          }

          Button {
            id: addButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "+"
            fontFamily: root.fontFamily
            fontSize: Style.font.heading
            foreground: root.foreground
            tooltipText: "Edit " + root.configPath
            onClicked: root.editConfig()
          }
        }

        Column {
          width: parent.width
          visible: root.results.length > 0

          Repeater {
            model: root.results

            delegate: Rectangle {
              id: row
              required property var modelData
              required property int index
              readonly property bool hasCursor: index === root.selectedIndex

              width: parent.width
              height: root.rowHeight
              radius: root.cornerRadius
              color: hasCursor ? root.selectedBackground : "transparent"

              Text {
                id: linkIcon
                anchors.left: parent.left
                anchors.leftMargin: Style.spacing.lg
                anchors.verticalCenter: parent.verticalCenter
                width: Style.font.title * 1.5
                text: "󰌷"
                color: row.hasCursor ? root.selectedText : root.foreground
                opacity: row.hasCursor ? 1 : 0.7
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
              }

              Text {
                id: triggerLabel
                anchors.left: linkIcon.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width * 0.35)
                textFormat: Text.PlainText
                text: row.modelData.trigger
                color: row.hasCursor ? root.selectedText : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                anchors.left: triggerLabel.right
                anchors.leftMargin: Style.spacing.xl
                anchors.right: parent.right
                anchors.rightMargin: Style.spacing.lg
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: row.modelData.url
                color: root.foreground
                opacity: 0.6
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (containsMouse) root.selectedIndex = row.index
                onClicked: root.activate(row.index)
              }
            }
          }
        }
      }
    }
  }
}
