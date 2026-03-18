import Cocoa

class AppLauncherKeyboardHandler {
    static var isActive = false
    static var registeredHotKeyRef: EventHotKeyRef?
    static let signature = "altt".utf16.reduce(0) { ($0 << 8) + OSType($1) }
    static let hotKeyId = EventHotKeyID(signature: signature, id: UInt32(100)) // 使用新的 ID 来避免与现有快捷键冲突

    static func initialize() {
        ApplicationLauncher.initialize()
        registerHotKey()
        addLocalMonitor()
    }

    private static func registerHotKey() {
        guard let shortcut = Preferences.appLauncherShortcut else { return }
        guard shortcut.keyCode != .none else { return }

        let key = shortcut.carbonKeyCode
        let mods = shortcut.carbonModifierFlags
        let options = UInt32(kEventHotKeyNoOptions)
        var hotKeyRef: EventHotKeyRef?

        let result = RegisterEventHotKey(
            key,
            mods,
            hotKeyId,
            GetEventDispatcherTarget(),
            options,
            &hotKeyRef
        )

        if result == noErr {
            registeredHotKeyRef = hotKeyRef
            Logger.debug { "Successfully registered AppLauncher hotkey: \(shortcut)" }
        } else {
            Logger.warning { "Failed to register AppLauncher hotkey: \(result)" }
        }
    }

    static func unregisterHotKey() {
        if let hotKeyRef = registeredHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            registeredHotKeyRef = nil
        }
    }

    static func updateHotKey() {
        unregisterHotKey()
        registerHotKey()
    }

    private static func addLocalMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { (event: NSEvent) in
            return handleLocalKeyDown(event)
        }

        NSEvent.addLocalMonitorForEvents(matching: [.keyUp]) { (event: NSEvent) in
            return handleLocalKeyUp(event)
        }
    }

    @discardableResult
    private static func handleLocalKeyDown(_ event: NSEvent) -> NSEvent? {
        guard isActive else { return event }

        let keyCode = event.keyCode
        let characters = event.charactersIgnoringModifiers ?? ""

        switch keyCode {
        case UInt16(kVK_Escape):
            ApplicationLauncher.hide()
            return nil
        case UInt16(kVK_Return), UInt16(kVK_Tab):
            ApplicationLauncher.launchSelected()
            return nil
        case UInt16(kVK_DownArrow):
            ApplicationLauncher.selectNext()
            return nil
        case UInt16(kVK_UpArrow):
            ApplicationLauncher.selectPrevious()
            return nil
        case UInt16(kVK_RightArrow):
            ApplicationLauncher.selectRight()
            return nil
        case UInt16(kVK_LeftArrow):
            ApplicationLauncher.selectLeft()
            return nil
        case UInt16(kVK_Delete), UInt16(kVK_ForwardDelete):
            // 处理删除键，清空搜索或退出
            if let searchField = AppLauncherPanel.shared.searchField, searchField.stringValue.isEmpty {
                ApplicationLauncher.hide()
            } else {
                searchField.stringValue = String(searchField.stringValue.dropLast())
                ApplicationLauncher.updateSearchQuery(searchField.stringValue)
            }
            return nil
        default:
            // 让其他按键事件传递到搜索框
            break
        }

        return event
    }

    @discardableResult
    private static func handleLocalKeyUp(_ event: NSEvent) -> NSEvent? {
        return event
    }

    static func handleHotKeyPressed() {
        Logger.debug { "AppLauncher hotkey pressed" }
        ApplicationLauncher.toggle()
    }

    static func setActive(_ active: Bool) {
        isActive = active
        Logger.debug { "AppLauncher keyboard handler \(active ? "activated" : "deactivated")" }
    }

    static func applyPreferences() {
        updateHotKey()
    }
}

extension KeyboardEvents {
    // 扩展 KeyboardEvents 以在键盘事件系统中集成 AppLauncher
    static func handleAppLauncherHotKey(_ event: EventRef?) {
        var id = EventHotKeyID()
        GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)

        if id.id == AppLauncherKeyboardHandler.hotKeyId.id {
            AppLauncherKeyboardHandler.handleHotKeyPressed()
        }
    }
}

extension AppLauncherPanel {
    // 在显示时设置键盘处理为活动状态
    override func orderFront(_ sender: Any?) {
        super.orderFront(sender)
        AppLauncherKeyboardHandler.setActive(true)
    }

    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
        AppLauncherKeyboardHandler.setActive(false)
    }
}
