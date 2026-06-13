import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "ai-monitor"

    property var providers: []
    property bool loading: false
    property string errorText: ""
    property int refreshIntervalMs: 60000
    property int pendingRequests: 0
    property string lastUpdatedText: "Never"
    property string selectedProvider: "claude"
    property var providerOrder: ["codex", "claude"]

    readonly property string instanceId: "aiMonitor-" + Math.floor(Math.random() * 1e9)

    readonly property color cardColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    readonly property color mutedColor: Theme.surfaceVariantText

    readonly property int highestUsedPercent: {
        let maxUsed = 0;
        for (let i = 0; i < providers.length; i++) {
            const used = providers[i]?.usage?.primary?.usedPercent ?? 0;
            maxUsed = Math.max(maxUsed, used);
        }
        return maxUsed;
    }

    readonly property color statusColor: {
        if (errorText !== "")
            return Theme.error;
        if (highestUsedPercent >= 90)
            return Theme.error;
        if (highestUsedPercent >= 70)
            return Theme.warning;
        return Theme.primary;
    }

    Timer {
        interval: root.refreshIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    function refresh() {
        loading = true;
        errorText = "";
        pendingRequests = providerOrder.length;
        for (let i = 0; i < providerOrder.length; i++)
            fetchProvider(providerOrder[i]);
    }

    function fetchProvider(provider) {
        const cmd = "codexbar usage --provider " + provider + " --source cli --format json --pretty --no-color";
        Proc.runCommand(
            root.instanceId + "." + provider,
            ["zsh", "-lc", cmd],
            (stdout, exitCode) => handleProviderResult(provider, stdout, exitCode),
            0,
            120000
        );
    }

    function handleProviderResult(provider, stdout, exitCode) {
        let item = {
            provider: provider,
            source: "codexbar",
            error: { message: "codexbar exited with code " + exitCode }
        };

        if (exitCode === 0) {
            try {
                const start = stdout.indexOf("[");
                const end = stdout.lastIndexOf("]");
                const jsonText = start >= 0 && end >= start ? stdout.slice(start, end + 1) : stdout;
                const parsed = JSON.parse(jsonText);
                if (Array.isArray(parsed) && parsed.length > 0)
                    item = parsed[0];
            } catch (e) {
                item.error = { message: "Failed to parse codexbar JSON" };
            }
        }

        upsertProvider(item);
        pendingRequests = Math.max(0, pendingRequests - 1);
        if (pendingRequests === 0) {
            loading = false;
            lastUpdatedText = "just now";
            updateErrorText();
        }
    }

    function upsertProvider(item) {
        const next = providers.slice();
        const idx = next.findIndex(p => p.provider === item.provider);
        if (idx >= 0)
            next[idx] = item;
        else
            next.push(item);
        providers = next.sort((a, b) => providerIndex(a.provider) - providerIndex(b.provider));
    }

    function providerIndex(provider) {
        const idx = providerOrder.indexOf(provider);
        return idx >= 0 ? idx : 99;
    }

    function updateErrorText() {
        const failed = providers.filter(p => p.error);
        errorText = failed.length > 0 ? failed.map(p => providerLabel(p.provider)).join(", ") + " failed" : "";
    }

    function providerData(provider) {
        for (let i = 0; i < providers.length; i++) {
            if (providers[i].provider === provider)
                return providers[i];
        }
        return {
            provider: provider,
            source: "codexbar",
            error: loading ? null : { message: "Waiting for data" }
        };
    }

    function selectedData() {
        return providerData(selectedProvider);
    }

    function selectProvider(provider) {
        selectedProvider = provider;
    }

    function providerLabel(provider) {
        if (provider === "codex")
            return "Codex";
        if (provider === "claude")
            return "Claude";
        return provider ? provider.charAt(0).toUpperCase() + provider.slice(1) : "AI";
    }

    function providerPlan(item) {
        const provider = item?.provider || selectedProvider;
        const raw = String(item?.usage?.identity?.loginMethod || item?.usage?.loginMethod || item?.loginMethod || "").trim();
        const lower = raw.toLowerCase();

        if (provider === "claude") {
            if (lower.includes("max"))
                return "Max";
            if (lower.includes("team"))
                return "Team";
            if (lower.includes("pro"))
                return "Pro";
            return "Pro";
        }

        if (lower === "plus")
            return "Plus";
        if (lower === "pro")
            return "Pro";
        if (lower === "team")
            return "Team";
        if (lower === "free")
            return "Free";
        return raw || "CLI";
    }

    function providerIcon(provider) {
        const pluginPath = pluginService?.getPluginPath(pluginId) || ".";
        if (provider === "codex")
            return "file://" + pluginPath + "/assets/openai.svg";
        if (provider === "claude")
            return "file://" + pluginPath + "/assets/anthropic.svg";
        return "";
    }

    function providerIconColor(provider) {
        // Mirror the label color in the same card so the icon tints with the text.
        return root.selectedProvider === provider ? Theme.primaryText : Theme.surfaceVariantText;
    }

    function compactProviderText(item) {
        const usage = item?.usage;
        if (!usage || !usage.primary)
            return providerLabel(item?.provider || "") + " ?";
        return providerLabel(item.provider) + " " + usage.primary.usedPercent + "%";
    }

    function resetText(window, provider) {
        if (!window)
            return "";
        if (window.resetsAt)
            return formatResetAt(window.resetsAt);
        if (window.resetDescription)
            return formatResetDescription(window.resetDescription, provider);
        return "";
    }

    function formatResetAt(value) {
        const date = new Date(value);
        if (isNaN(date.getTime()))
            return "";

        const now = new Date();
        const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
        const resetDay = new Date(date.getFullYear(), date.getMonth(), date.getDate());

        let dayLabel = "";
        if (resetDay.getTime() === new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime())
            dayLabel = "Today";
        else if (resetDay.getTime() === tomorrow.getTime())
            dayLabel = "Tomorrow";
        else
            dayLabel = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][date.getMonth()] + " " + date.getDate();

        let hours = date.getHours();
        const minutes = String(date.getMinutes()).padStart(2, "0");
        const suffix = hours >= 12 ? "PM" : "AM";
        hours = hours % 12;
        if (hours === 0)
            hours = 12;

        return dayLabel + " at " + hours + ":" + minutes + " " + suffix;
    }

    function formatResetDescription(description, provider) {
        let text = String(description || "");
        if (text === "")
            return "";

        text = text.replace(/\((America\/[^)]+)\)/, " ($1)");
        text = text.replace(/Resets(?=[A-Za-z0-9])/, "Resets ");
        text = text.replace(/([a-z])([A-Z][a-z]{2}\d)/, "$1 $2");
        text = text.replace(/([a-zA-Z])(\d{1,2}:\d{2})/, "$1 $2");
        text = text.replace(/(\d{1,2}:\d{2})(am|pm)/i, "$1 $2");
        text = text.replace(/(Jun|Jul|Aug|Sep|Oct|Nov|Dec|Jan|Feb|Mar|Apr|May)(\d{1,2})/, "$1 $2");
        text = text.replace(/,(\d{1,2}:\d{2})/, ", $1");
        text = text.replace(/Resets today/i, "Resets today");
        if (provider === "claude") {
            text = text.replace(/^Resets\s*/i, "");
            text = text.replace(/\s*\([^)]*\)\s*$/, "");
        }
        text = text.replace(/,\s*/, " at ");
        text = text.replace(/\b(am|pm)\b/i, function (match) {
            return match.toUpperCase();
        });

        return text;
    }

    function extraUsageText(item) {
        const remaining = item?.credits?.remaining;
        if (remaining === undefined || remaining === null)
            return "Credits remaining: --";
        return "Credits remaining: " + remaining;
    }

    function usageDashboardUrl() {
        if (selectedProvider === "claude")
            return "https://claude.ai/settings/usage";
        return "https://chatgpt.com/codex/settings/usage";
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            DankIcon {
                name: "smart_toy"
                size: root.iconSize
                color: root.statusColor
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.loading && root.providers.length === 0 ? "AI ..." : root.providers.map(p => root.compactProviderText(p)).join(" ")
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                color: Theme.widgetTextColor || Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: "smart_toy"
                size: root.iconSize
                color: root.statusColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.highestUsedPercent > 0 ? root.highestUsedPercent + "%" : "AI"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.widgetTextColor || Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    component ProviderTab: Item {
        id: tab

        property string provider: ""
        property bool selected: root.selectedProvider === provider
        property var data: root.providerData(provider)

        width: 120
        height: 42

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: tab.selected ? Theme.primary : root.cardColor
            border.width: tabMouse.containsMouse && !tab.selected ? Theme.layerOutlineWidth : 0
            border.color: Theme.outlineLight
        }

        DankSVGIcon {
            id: tabIcon
            width: 18
            height: 18
            size: 18
            source: root.providerIcon(tab.provider)
            colorOverride: root.providerIconColor(tab.provider)
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            id: tabLabel
            text: root.providerLabel(tab.provider)
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold
            color: tab.selected ? Theme.primaryText : Theme.surfaceText
            anchors.left: tabIcon.right
            anchors.leftMargin: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: tab.data?.usage?.primary ? tab.data.usage.primary.usedPercent + "%" : ""
            font.pixelSize: Theme.fontSizeSmall
            color: tab.selected ? Theme.primaryText : Theme.surfaceVariantText
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
        }

        MouseArea {
            id: tabMouse
            anchors.fill: parent
            z: 20
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.selectProvider(tab.provider)
        }
    }

    component ProgressTrack: Rectangle {
        id: track

        property int value: 0
        property color fillColor: value >= 90 ? Theme.error : (value >= 70 ? Theme.warning : Theme.primary)
        property color trackColor: Theme.withAlpha(Theme.surfaceVariantText, 0.16)

        width: parent.width
        height: 10
        radius: height / 2
        color: track.trackColor

        Rectangle {
            height: parent.height
            width: track.value > 0 ? Math.max(parent.height, parent.width * Math.min(100, Math.max(0, track.value)) / 100) : 0
            radius: parent.radius
            color: track.fillColor
        }
    }

    component UsageSection: Column {
        id: section

        property string title: ""
        property var windowData: null
        property string footer: ""
        readonly property int usedPercent: Math.min(100, Math.max(0, windowData?.usedPercent ?? 0))

        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: section.title
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        ProgressTrack {
            value: section.usedPercent
        }

        Row {
            width: parent.width

            StyledText {
                text: section.usedPercent + "% used"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                width: parent.width * 0.4
            }

            StyledText {
                text: root.resetText(section.windowData, root.selectedProvider)
                font.pixelSize: Theme.fontSizeMedium
                color: root.mutedColor
                width: parent.width * 0.6
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }

        StyledText {
            width: parent.width
            text: section.footer
            visible: section.footer !== ""
            font.pixelSize: Theme.fontSizeSmall
            color: root.mutedColor
            elide: Text.ElideRight
        }
    }

    component MetricPill: Rectangle {
        id: pill

        property string label: ""
        property color pillColor: Theme.primary

        width: metricText.implicitWidth + Theme.spacingM * 2
        height: 24
        radius: 12
        color: Theme.withAlpha(pillColor, 0.14)

        StyledText {
            id: metricText
            anchors.centerIn: parent
            text: pill.label
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold
            color: pill.pillColor
        }
    }

    component Divider: Rectangle {
        width: parent.width
        height: 1
        color: Theme.withAlpha(Theme.surfaceVariantText, 0.16)
    }

    component ActionRow: Rectangle {
        id: action

        property string iconName: ""
        property string label: ""
        property var callback: null

        width: parent.width
        height: 38
        radius: Theme.cornerRadius
        color: actionMouse.containsMouse ? root.cardColor : "transparent"

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.spacingS
            spacing: Theme.spacingM

            DankIcon {
                name: action.iconName
                size: Theme.iconSizeSmall
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: action.label
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (action.callback)
                    action.callback();
            }
        }
    }

    popoutContent: Component {
        Rectangle {
            id: panel

            // Ride on the DankPopout framework surface + its single border
            // (like the built-in Processes popout) instead of stacking our own
            // opaque dark panel and border on top, which read as a heavier frame.
            width: root.popoutWidth
            implicitHeight: content.implicitHeight + Theme.spacingS * 2
            radius: Theme.cornerRadius
            color: "transparent"
            clip: true

            Column {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingL

                Rectangle {
                    width: parent.width
                    height: 72
                    radius: Theme.cornerRadius
                    color: root.cardColor

                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        spacing: Theme.spacingS

                        Rectangle {
                            width: (parent.width - Theme.spacingS) / 2
                            height: parent.height
                            radius: Theme.cornerRadius
                            color: root.selectedProvider === "codex" ? Theme.primary : "transparent"

                            Column {
                                anchors.centerIn: parent
                                spacing: 3

                                DankSVGIcon {
                                    width: 22
                                    height: 22
                                    size: 22
                                    source: root.providerIcon("codex")
                                    colorOverride: root.providerIconColor("codex")
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: "Codex"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: root.selectedProvider === "codex" ? Font.Bold : Font.Medium
                                    color: root.selectedProvider === "codex" ? Theme.primaryText : Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                ProgressTrack {
                                    width: 72
                                    height: 5
                                    value: root.providerData("codex")?.usage?.primary?.usedPercent ?? 0
                                    fillColor: root.providerData("codex")?.error ? Theme.error : root.providerIconColor("codex")
                                    trackColor: Theme.withAlpha(root.providerIconColor("codex"), 0.25)
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectProvider("codex")
                            }
                        }

                        Rectangle {
                            width: (parent.width - Theme.spacingS) / 2
                            height: parent.height
                            radius: Theme.cornerRadius
                            color: root.selectedProvider === "claude" ? Theme.primary : "transparent"

                            Column {
                                anchors.centerIn: parent
                                spacing: 3

                                DankSVGIcon {
                                    width: 22
                                    height: 22
                                    size: 22
                                    source: root.providerIcon("claude")
                                    colorOverride: root.providerIconColor("claude")
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: "Claude"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: root.selectedProvider === "claude" ? Font.Bold : Font.Medium
                                    color: root.selectedProvider === "claude" ? Theme.primaryText : Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                ProgressTrack {
                                    width: 72
                                    height: 5
                                    value: root.providerData("claude")?.usage?.primary?.usedPercent ?? 0
                                    fillColor: root.providerData("claude")?.error ? Theme.error : root.providerIconColor("claude")
                                    trackColor: Theme.withAlpha(root.providerIconColor("claude"), 0.25)
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectProvider("claude")
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 78
                    radius: Theme.cornerRadius
                    color: root.cardColor

                    Item {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL

                        Column {
                            anchors.left: parent.left
                            anchors.right: statusPills.left
                            anchors.rightMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            StyledText {
                                text: root.providerLabel(root.selectedProvider)
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: root.loading ? "Updating..." : "Updated " + root.lastUpdatedText
                                font.pixelSize: Theme.fontSizeSmall
                                color: root.mutedColor
                            }
                        }

                        Row {
                            id: statusPills
                            spacing: Theme.spacingS
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            MetricPill {
                                label: root.providerPlan(root.selectedData())
                                pillColor: Theme.primary
                            }
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    text: root.selectedData()?.error?.message || ""
                    visible: text !== ""
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.error
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    implicitHeight: usageColumn.implicitHeight + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: root.cardColor

                    Column {
                        id: usageColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingL
                        spacing: Theme.spacingL

                        UsageSection {
                            title: "Session"
                            windowData: root.selectedData()?.usage?.primary
                        }

                        UsageSection {
                            title: "Weekly"
                            windowData: root.selectedData()?.usage?.secondary
                        }

                        UsageSection {
                            title: root.selectedProvider === "claude" ? "Sonnet" : "Model"
                            windowData: root.selectedData()?.usage?.tertiary || { usedPercent: 0 }
                            visible: root.selectedProvider === "claude" || !!root.selectedData()?.usage?.tertiary
                        }

                        Divider {}

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Extra usage"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            ProgressTrack {
                                value: 0
                                fillColor: Theme.primary
                            }

                            Row {
                                width: parent.width

                                StyledText {
                                    text: root.extraUsageText(root.selectedData())
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    width: parent.width * 0.75
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    text: "0% used"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: root.mutedColor
                                    width: parent.width * 0.25
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    ActionRow {
                        iconName: "refresh"
                        label: root.loading ? "Refreshing..." : "Refresh"
                        callback: () => root.refresh()
                    }

                    ActionRow {
                        iconName: "bar_chart"
                        label: "Usage Dashboard"
                        callback: () => Quickshell.execDetached(["xdg-open", root.usageDashboardUrl()])
                    }
                }
            }
        }
    }

    popoutWidth: 640
    popoutHeight: 640
}
