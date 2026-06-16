import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "components" as Components
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: rootItem

    property var weatherData

    property string temperatureUnit: root.temperatureUnit

    readonly property string unitStr: (temperatureUnit === "0" || temperatureUnit == 0) ? "°C" : "°F"
    readonly property string currentTempText: (weatherData && weatherData.temperaturaActualPopup) ? weatherData.temperaturaActualPopup : "--"
    readonly property bool anyDetailEnabled: !!(root.showApparentTemp || root.showHumidity || root.showUVIndex || root.showWind)
    readonly property bool showBottomDetails: !!(anyDetailEnabled && root.showConditionFull)

    // --- VUE DÉTAIL JOURNALIÈRE (courbes) ---
    // -1 = vue classique. >= 0 = index du jour sélectionné.
    property int selectedDayIndex: -1

    // Courbe active dans la vue détail : 0=temp, 1=humidity, 2=wind, 3=uv
    property int activeChart: 0

    readonly property var hourlyData: (weatherData && weatherData.weatherData && weatherData.weatherData.hourly) ? weatherData.weatherData.hourly : null
    readonly property bool hasHourlyData: !!hourlyData

    // Accès sécurisé et centralisé aux données journalières. Évite de répéter
    // "weatherData && weatherData.weatherData && weatherData.weatherData.daily"
    // à chaque utilisation — l'original accédait parfois directement à
    // ".weatherData.daily" sans vérifier l'étage intermédiaire, ce qui pouvait
    // planter le popup si "weatherData" existait sans "weatherData.weatherData".
    readonly property var dailyData: (weatherData && weatherData.weatherData && weatherData.weatherData.daily) ? weatherData.weatherData.daily : null

    // Index du jour courant dans le tableau daily
    readonly property int currentDayIndex: {
        if (!dailyData) return 0;
        let today = new Date();
        let todayStr = today.getFullYear() + "-" +
        String(today.getMonth() + 1).padStart(2, "0") + "-" +
        String(today.getDate()).padStart(2, "0");
        let times = dailyData.time;
        for (let i = 0; i < times.length; i++) {
            if (times[i] === todayStr) return i;
        }
        return 0;
    }

    // Source unique de vérité pour les 4 courbes (température, humidité, vent,
    // UV) : libellé complet, libellé court d'onglet, unité et couleur. Avant,
    // ces informations étaient dupliquées dans deux switch/case distincts et
    // dans 4 littéraux de couleur répétés pour les onglets — toute couleur
    // changée à un endroit risquait d'être oubliée à l'autre.
    readonly property var chartDefs: [
        {
            field: "temperature_2m",
            label: i18n("Temp."),
            tabLabel: i18n("Temp."),
            unit: unitStr,
            color: Qt.rgba(0.92, 0.62, 0.15, 1.0) // ambre
        },
        {
            field: "relative_humidity_2m",
            label: i18n("Hum."),
            tabLabel: i18n("Hum."),
            unit: "%",
            color: Qt.rgba(0.29, 0.56, 0.88, 1.0) // bleu doux
        },
        {
            field: "wind_speed_10m",
            label: i18n("Wind"),
            tabLabel: i18n("Wind"),
            unit: (unitStr === "°C" ? " km/h" : " mph"),
            color: Qt.rgba(0.29, 0.50, 0.66, 1.0)
        },
        {
            field: "uv_index",
            label: i18n("UV Index"),
            tabLabel: i18n("UV"),
            unit: "",
            color: Qt.rgba(0.55, 0.25, 0.90, 1.0) // violet
        }
    ]

    function hourlySlice(fieldName) {
        if (!hourlyData || !hourlyData[fieldName] || selectedDayIndex < 0) return [];
        let start = selectedDayIndex * 24;
        return hourlyData[fieldName].slice(start, start + 24);
    }

    function openDayDetail(dayIndex) {
        if (hasHourlyData) {
            activeChart = 0; // reset à température à chaque ouverture
            selectedDayIndex = dayIndex;
        }
    }

    function closeDayDetail() {
        selectedDayIndex = -1;
    }

    function resetScroll() {
        forecastSection.positionViewAtBeginning();
        closeDayDetail();
    }

    readonly property int fixedWidth: Kirigami.Units.gridUnit * 15
    readonly property int calculatedHeight: {
        let base = Kirigami.Units.gridUnit * 12.5;
        return (showBottomDetails) ? base : (base - Kirigami.Units.gridUnit * 2.5);
    }

    width: fixedWidth
    height: calculatedHeight
    Layout.minimumWidth: fixedWidth
    Layout.maximumWidth: fixedWidth
    Layout.preferredWidth: fixedWidth
    Layout.minimumHeight: calculatedHeight
    Layout.maximumHeight: calculatedHeight
    Layout.preferredHeight: calculatedHeight

    // --- 1. LE FOND ANIMÉ ---
    Rectangle {
        id: backgroundContainer
        anchors { fill: parent; margins: -8 }
        color: Kirigami.Theme.backgroundColor
        radius: root.borderRadius
        clip: true

        layer.enabled: !!plasmoid.configuration.showAnimations
        layer.smooth: true
        z: -1

        Item {
            id: animationsLayers
            anchors.fill: parent

            visible: !!(plasmoid.configuration.showAnimations &&
            weatherData &&
            weatherData.weatherData &&
            weatherData.temperaturaActual !== "--")

            readonly property int weatherCode: weatherData && weatherData.codeweather ? parseInt(weatherData.codeweather) : 0
            readonly property real windValue: weatherData && weatherData.windSpeed && weatherData.windSpeed !== "--" ? parseFloat(weatherData.windSpeed) : 0

            readonly property bool isDay: {
                if (weatherData && weatherData.weatherData && weatherData.weatherData.current) {
                    return weatherData.weatherData.current.is_day === 1;
                }
                let currentHour = new Date().getHours();
                return (currentHour >= 7 && currentHour <= 20);
            }

            Loader {
                anchors.fill: parent
                active: !!(plasmoid.configuration.showAnimations && animationsLayers.visible)
                source: animationsLayers.isDay ? "animations/soleil.qml" : "animations/nuit.qml"
            }
            Loader {
                anchors.fill: parent
                active: {
                    if (!plasmoid.configuration.showAnimations || !animationsLayers.visible) return false;
                    let code = animationsLayers.weatherCode;
                    return code >= 3 && code !== 45 && code !== 48;
                }
                source: "animations/nuage.qml"
            }
            Loader {
                anchors.fill: parent
                active: !!(plasmoid.configuration.showAnimations && animationsLayers.visible && source !== "")
                source: {
                    let code = animationsLayers.weatherCode;
                    if (code >= 95) return "animations/orage.qml";
                    if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "animations/neige.qml";
                    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return "animations/pluie.qml";
                    if (code >= 51 && code <= 57) return "animations/bruine.qml";
                    if (code === 45 || code === 48) return "animations/brume.qml";
                    return "";
                }
            }
            Loader {
                anchors.fill: parent
                active: !!(plasmoid.configuration.showAnimations && animationsLayers.visible && animationsLayers.windValue >= 20)
                source: "animations/vent.qml"
            }
        }
    }

    // --- 2. LAYOUT PRINCIPAL ---
    Item {
        id: infoLayout
        anchors.fill: parent

        // ============================================================
        // === VUE CLASSIQUE ===
        // ============================================================
        ColumnLayout {
            id: classicContent
            anchors.fill: parent
            spacing: 0

            // Fondu croisé entre vue classique et vue détail, plutôt qu'une
            // bascule de "visible" sèche : rendu plus doux, toujours minimal.
            opacity: rootItem.selectedDayIndex === -1 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            RowLayout {
                id: headerSection
                Layout.fillWidth: true
                Layout.topMargin: -Kirigami.Units.smallSpacing
                Layout.leftMargin: Kirigami.Units.gridUnit
                Layout.rightMargin: Kirigami.Units.gridUnit
                spacing: 0

                Item { Layout.fillWidth: true; visible: !rightSideContainer.visible }

                Row {
                    id: tempContainer
                    spacing: 0
                    Layout.alignment: Qt.AlignVCenter

                    PlasmaComponents3.Label {
                        text: currentTempText
                        font.pixelSize: Kirigami.Units.gridUnit * 2.5
                        font.bold: true
                        leftPadding: currentTempText.length === 1 ? Kirigami.Units.gridUnit * 0.4 : 0
                    }
                    PlasmaComponents3.Label {
                        text: unitStr
                        font.pixelSize: Kirigami.Units.gridUnit * 1.5
                        font.bold: true
                        topPadding: Kirigami.Units.gridUnit * 0.2
                    }
                }

                Item { Layout.fillWidth: true }

                ColumnLayout {
                    id: rightSideContainer
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0
                    visible: !!(root.showConditionFull || anyDetailEnabled)

                    PlasmaComponents3.Label {
                        visible: !!root.showConditionFull
                        Layout.fillWidth: true
                        text: weatherData ? weatherData.weatherLongtext : ""
                        font.pixelSize: text.length <= 10 ? Kirigami.Units.gridUnit * 1.3 : Kirigami.Units.gridUnit * 1.0
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: Kirigami.Units.gridUnit * 0.55
                    }

                    GridLayout {
                        id: detailsGrid
                        visible: !!(!root.showConditionFull && anyDetailEnabled)
                        columns: 2
                        rowSpacing: Kirigami.Units.gridUnit * 0.3
                        columnSpacing: Kirigami.Units.smallSpacing
                        layoutDirection: Qt.RightToLeft
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                        // Micro-ajustement visuel : compense le padding interne
                        // des Label pour un alignement optique parfait avec le
                        // bord droit du widget.
                        readonly property real rightNudge: -7.5
                        Layout.rightMargin: rightNudge
                        Layout.topMargin: root.showConditionFull ? 0 : Kirigami.Units.gridUnit * 0.4

                        // On ne génère que les éléments réellement visibles :
                        // plus besoin de "visible: !!root.showX" sur chaque
                        // CompactGridItem, et GridLayout n'a rien à exclure.
                        readonly property var quickStats: [
                            { label: i18n("Wind"),  value: (weatherData && weatherData.windSpeed !== "--") ? (weatherData.windSpeed + (unitStr === "°C" ? " km/h" : " mph")) : "--", show: !!root.showWind },
                            { label: i18n("UV"),    value: (weatherData && weatherData.uvIndex !== "--") ? weatherData.uvIndex : "--", show: !!root.showUVIndex },
                            { label: i18n("Hum."),  value: (weatherData && weatherData.humidity !== "--") ? (weatherData.humidity + "%") : "--", show: !!root.showHumidity },
                            { label: i18n("Feels"), value: (weatherData && weatherData.apparentTemp !== "--") ? (weatherData.apparentTemp + unitStr) : "--", show: !!root.showApparentTemp }
                        ].filter(function (d) { return d.show; })

                        Repeater {
                            model: detailsGrid.quickStats
                            delegate: CompactGridItem {
                                label: modelData.label
                                value: modelData.value
                            }
                        }
                    }
                }
            }

            // --- SECTION PRÉVISIONS ---
            ListView {
                id: forecastSection
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 5
                Layout.topMargin: -Kirigami.Units.gridUnit * 0.5
                spacing: 0
                orientation: ListView.Horizontal

                snapMode: ListView.SnapToItem
                boundsBehavior: Flickable.OvershootBounds
                maximumFlickVelocity: 500
                flickDeceleration: 1000
                interactive: true
                clip: true

                model: (rootItem.dailyData && rootItem.dailyData.time) ? (rootItem.dailyData.time.length - root.forecastStartDay) : 0

                delegate: ColumnLayout {
                    width: forecastSection.width / 3
                    spacing: 0
                    readonly property int dayIndex: index + root.forecastStartDay

                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: {
                            if (rootItem.dailyData && rootItem.dailyData.time) {
                                let d = new Date(rootItem.dailyData.time[dayIndex]);
                                return root.days ? root.days[d.getDay()] : "";
                            }
                            return "";
                        }
                        horizontalAlignment: Text.AlignHCenter
                        font.capitalization: Font.Capitalize
                        font.pixelSize: Kirigami.Units.gridUnit * 0.65
                        opacity: 0.8
                    }

                    Item {
                        id: iconWrapper
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2.7
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 2.7
                        Layout.alignment: Qt.AlignHCenter

                        Kirigami.Icon {
                            anchors.fill: parent
                            source: rootItem.dailyData ? weatherData.asingicon(rootItem.dailyData.weather_code[dayIndex]) : ""
                        }

                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent
                            hoverEnabled: rootItem.hasHourlyData
                            enabled: rootItem.hasHourlyData
                            cursorShape: rootItem.hasHourlyData ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: rootItem.openDayDetail(dayIndex)
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4
                        PlasmaComponents3.Label {
                            text: rootItem.dailyData ? Math.round(rootItem.dailyData.temperature_2m_max[dayIndex]) + "°" : ""
                            font.bold: true
                            font.pixelSize: Kirigami.Units.gridUnit * 0.75
                        }
                        PlasmaComponents3.Label {
                            text: rootItem.dailyData ? Math.round(rootItem.dailyData.temperature_2m_min[dayIndex]) + "°" : ""
                            opacity: 0.6
                            font.pixelSize: Kirigami.Units.gridUnit * 0.75
                        }
                    }
                }
            }

            RowLayout {
                id: detailsRow
                visible: !!showBottomDetails
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2.2
                Layout.leftMargin: Kirigami.Units.gridUnit * 0.5
                Layout.rightMargin: Kirigami.Units.gridUnit * 0.5
                spacing: 0

                // Même principe que pour "quickStats" : on filtre les éléments
                // visibles puis on les enchaîne avec un séparateur entre
                // chaque paire. Avant, chaque séparateur portait une condition
                // manuelle du type "showA && (showB || showC || showD)",
                // fragile dès qu'une option de configuration changeait.
                readonly property var visibleDetails: [
                    { label: i18n("Apparent Temp"), value: (weatherData && weatherData.apparentTemp !== "--") ? (weatherData.apparentTemp + unitStr) : "--", show: !!root.showApparentTemp },
                    { label: i18n("Humidity"),      value: (weatherData && weatherData.humidity !== "--") ? (weatherData.humidity + "%") : "--", show: !!root.showHumidity },
                    { label: i18n("UV Index"),      value: (weatherData && weatherData.uvIndex !== "--") ? weatherData.uvIndex : "--", show: !!root.showUVIndex },
                    { label: i18n("Wind"),          value: (weatherData && weatherData.windSpeed !== "--") ? (weatherData.windSpeed + (unitStr === "°C" ? " km/h" : " mph")) : "--", show: !!root.showWind }
                ].filter(function (d) { return d.show; })

                Repeater {
                    model: detailsRow.visibleDetails
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Rectangle {
                            visible: index > 0
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 1.2
                            color: Kirigami.Theme.textColor
                            opacity: 0.15
                            Layout.alignment: Qt.AlignVCenter
                        }
                        DetailColumn {
                            label: modelData.label
                            value: modelData.value
                        }
                    }
                }
            }
        }

        // ============================================================
        // === VUE DÉTAIL ===
        // ============================================================
        ColumnLayout {
            id: dayDetailView
            anchors.fill: parent
            spacing: 0

            opacity: rootItem.selectedDayIndex !== -1 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            readonly property string dayLabelFull: {
                if (!rootItem.dailyData || rootItem.selectedDayIndex < 0) return "";
                let d = new Date(rootItem.dailyData.time[rootItem.selectedDayIndex]);
                let locale = Qt.locale();
                return d.toLocaleString(locale, "dddd");
            }

            // Toutes les infos de la courbe active proviennent désormais de
            // "rootItem.chartDefs" — une seule source, plus de switch/case.
            readonly property var activeDef: rootItem.chartDefs[rootItem.activeChart]
            readonly property var activeValues: rootItem.hourlySlice(activeDef.field)
            readonly property string activeUnit: activeDef.unit
            readonly property string activeLabel: activeDef.label
            readonly property color activeColor: activeDef.color

            RowLayout {
                id: navigationHeader
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing
                spacing: 0

                Item {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.6
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.6

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        radius: width / 2
                        color: Kirigami.Theme.textColor
                        opacity: backMouse.pressed ? 0.15 : (backMouse.containsMouse ? 0.08 : 0.0)
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Kirigami.Units.gridUnit * 1.0
                        height: Kirigami.Units.gridUnit * 1.0
                        source: "go-previous"
                        opacity: backMouse.pressed ? 0.6 : (backMouse.containsMouse ? 1.0 : 0.75)
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rootItem.closeDayDetail()
                    }
                }

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    font.bold: true
                    font.capitalization: Font.Capitalize
                    text: dayDetailView.dayLabelFull
                }

                Item {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.6
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.6
                }
            }

            Components.LineChart {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing

                label:       dayDetailView.activeLabel
                unit:        dayDetailView.activeUnit
                values:      dayDetailView.activeValues
                lineColor:   dayDetailView.activeColor
                // currentHour est géré en interne par LineChart.qml via un
                // Timer qui se rafraîchit chaque minute. Ne pas surcharger ici.

                preciseTemp: root.preciseTempChart
                chartType:   rootItem.activeChart
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                component ChartTab : Rectangle {
                    property string tabLabel: ""
                    property int tabIndex: 0
                    property color tabColor: Kirigami.Theme.highlightColor

                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.4
                    radius: Kirigami.Units.smallSpacing

                    readonly property bool isActive: rootItem.activeChart === tabIndex
                    color: isActive
                    ? Qt.rgba(tabColor.r, tabColor.g, tabColor.b, 0.20)
                    : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        visible: parent.isActive
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 3
                        height: 2
                        radius: 1
                        color: parent.tabColor
                    }

                    PlasmaComponents3.Label {
                        anchors.centerIn: parent
                        text: parent.tabLabel
                        font.pixelSize: Kirigami.Units.gridUnit * 0.52
                        font.bold: parent.isActive
                        color: parent.isActive ? parent.tabColor : Kirigami.Theme.textColor
                        opacity: parent.isActive ? 1.0 : 0.55
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    TapHandler {
                        onTapped: rootItem.activeChart = parent.tabIndex
                    }
                }

                Repeater {
                    model: rootItem.chartDefs
                    delegate: ChartTab {
                        tabLabel: modelData.tabLabel
                        tabIndex: index
                        tabColor: modelData.color
                    }
                }
            }
        }
    }

    component CompactGridItem : ColumnLayout {
        property string label: ""
        property string value: ""
        spacing: 1
        Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2

        PlasmaComponents3.Label {
            text: parent.label
            font.pixelSize: Kirigami.Units.gridUnit * 0.50
            opacity: 0.55
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 0
            readonly property var _split: {
                let v = parent.value;
                let m = v.match(/^(-?\d+(?:\.\d+)?)\s*(.+)$/);
                return m ? { num: m[1], unit: m[2] } : { num: v, unit: "" };
            }
            // unit type: "degree" for °C/°F, "percent" for %, "speed" for km/h mph
            readonly property string _unitType: {
                let u = _split.unit;
                if (u === "°C" || u === "°F") return "degree";
                if (u === "%") return "percent";
                return "speed";
            }
            PlasmaComponents3.Label {
                id: compactNumLabel
                text: parent._split.num
                font.pixelSize: Kirigami.Units.gridUnit * 0.68
                font.bold: true
            }
            // Degree → haut, taille lisible, vraiment au-dessus du centre
            PlasmaComponents3.Label {
                visible: parent._unitType === "degree"
                text: parent._split.unit
                font.pixelSize: Kirigami.Units.gridUnit * 0.52
                font.bold: true
                leftPadding: 2
                anchors.bottom: compactNumLabel.top
                anchors.bottomMargin: -Kirigami.Units.gridUnit * 0.75
            }
            // Percent → légèrement sous le centre, gap à gauche
            PlasmaComponents3.Label {
                visible: parent._unitType === "percent"
                text: parent._split.unit
                font.pixelSize: Kirigami.Units.gridUnit * 0.48
                font.bold: true
                leftPadding: 3
                anchors.verticalCenter: compactNumLabel.verticalCenter
                anchors.verticalCenterOffset: -Kirigami.Units.gridUnit * 0.01
            }
            // Speed (km/h, mph) → baseline-aligned, small gap
            PlasmaComponents3.Label {
                visible: parent._unitType === "speed"
                text: parent._split.unit
                font.pixelSize: Kirigami.Units.gridUnit * 0.50
                font.bold: true
                leftPadding: 2
                anchors.baseline: compactNumLabel.baseline
            }
        }
    }

    component DetailColumn : ColumnLayout {
        property string label: ""
        property string value: ""
        Layout.fillWidth: true
        spacing: 1

        PlasmaComponents3.Label {
            text: parent.label
            font.pixelSize: Kirigami.Units.gridUnit * 0.52
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.60
        }
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 0
            readonly property var _split: {
                let v = parent.value;
                let m = v.match(/^(-?\d+(?:\.\d+)?)\s*(.+)$/);
                return m ? { num: m[1], unit: m[2] } : { num: v, unit: "" };
            }
            readonly property string _unitType: {
                let u = _split.unit;
                if (u === "°C" || u === "°F") return "degree";
                if (u === "%") return "percent";
                return "speed";
            }
            PlasmaComponents3.Label {
                id: detailNumLabel
                text: parent._split.num
                font.pixelSize: Kirigami.Units.gridUnit * 0.72
                font.bold: true
            }
            PlasmaComponents3.Label {
                visible: parent._unitType === "degree"
                text: parent._split.unit
                font.pixelSize: Kirigami.Units.gridUnit * 0.48
                font.bold: true
                leftPadding: 2
                anchors.verticalCenter: detailNumLabel.verticalCenter
                anchors.verticalCenterOffset: -Kirigami.Units.gridUnit * 0.10
            }
            PlasmaComponents3.Label {
                visible: parent._unitType === "percent"
                text: parent._split.unit
                font.pixelSize: Kirigami.Units.gridUnit * 0.50
                font.bold: true
                leftPadding: 3
                anchors.verticalCenter: detailNumLabel.verticalCenter
                anchors.verticalCenterOffset: Kirigami.Units.gridUnit * 0.06
            }
            PlasmaComponents3.Label {
                visible: parent._unitType === "speed"
                text: parent._split.unit
                font.pixelSize: Kirigami.Units.gridUnit * 0.53
                font.bold: true
                leftPadding: 2
                anchors.baseline: detailNumLabel.baseline
            }
        }
    }
}
