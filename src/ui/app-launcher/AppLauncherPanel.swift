import Cocoa

class AppLauncherPanel: NSPanel {
    static var shared: AppLauncherPanel!

    var searchField = NSSearchField(frame: .zero)
    var scrollView: ScrollView!
    var contentView: EffectView!
    var appsView: AppLauncherView!

    var gridColumns: Int?

    convenience init() {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
            styleMask: [.borderless, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        delegate = self
        isFloatingPanel = true
        animationBehavior = .none
        hidesOnDeactivate = true
        titleVisibility = .hidden
        backgroundColor = .clear
        level = .popUpMenu
        collectionBehavior = .canJoinAllSpaces
        setAccessibilitySubrole(.unknown)
        setAccessibilityLabel(App.name)

        contentView = makeAppropriateEffectView()
        self.contentView.wantsLayer = true

        initializeSearchField()
        initializeScrollView()

        appsView = AppLauncherView()
        scrollView.documentView = appsView

        contentView.addSubview(searchField)
        contentView.addSubview(scrollView)

        Self.shared = self
    }

    private func initializeSearchField() {
        searchField.placeholderString = NSLocalizedString("Search applications", comment: "Application launcher search field placeholder")
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = true
        searchField.bezelStyle = .roundedBezel
        if #available(macOS 13.0, *) {
            searchField.controlSize = .large
        } else {
            searchField.controlSize = .regular
        }
        searchField.usesSingleLineMode = true
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        NotificationCenter.default.addObserver(forName: NSControl.textDidChangeNotification, object: searchField, queue: .main) { [weak self] _ in
            self?.updateSearch()
        }
    }

    private func initializeScrollView() {
        scrollView = ScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.verticalScrollElasticity = .none
        scrollView.scrollerStyle = .overlay
        scrollView.scrollerKnobStyle = .light
        scrollView.horizontalScrollElasticity = .none
        scrollView.usesPredominantAxisScrolling = true
    }

    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        updateSearch()
    }

    private func updateSearch() {
        ApplicationLauncher.updateSearchQuery(searchField.stringValue)
    }

    func show() {
        NSScreen.updatePreferred()

        let screen = NSScreen.preferred
        let screenRect = screen.visibleFrame

        let width = min(800, screenRect.width - 100)
        let height = min(500, screenRect.height - 100)

        let originX = NSMidX(screenRect) - width / 2
        let originY = NSMidY(screenRect) - height / 2

        setFrame(NSRect(x: originX, y: originY, width: width, height: height), display: true)

        updateAppearance()
        alphaValue = 1
        makeKeyAndOrderFront(nil)
        makeFirstResponder(searchField)

        updateContent()
    }

    func updateAppearance() {
        hasShadow = Appearance.enablePanelShadow
        appearance = NSAppearance(named: Appearance.currentTheme == .dark ? .vibrantDark : .vibrantLight)
    }

    func updateContent() {
        appsView.updateItemsAndLayout()
        updateLayout()
    }

    func updateSelection() {
        appsView.highlightSelected()
    }

    private func updateLayout() {
        let searchBarHeight = searchField.fittingSize.height
        let searchBottomPadding = CGFloat(10)
        let searchReservedHeight = searchBarHeight + searchBottomPadding

        let minSearchWidth = min(frame.width - Appearance.windowPadding * 2, 320)
        let searchWidth = max(minSearchWidth, appsView.thumbnailsWidth)

        searchField.frame = NSRect(
            x: (frame.width - searchWidth) / 2,
            y: frame.height - searchReservedHeight - Appearance.windowPadding,
            width: searchWidth,
            height: searchBarHeight
        )

        scrollView.frame = NSRect(
            x: Appearance.windowPadding,
            y: Appearance.windowPadding,
            width: frame.width - Appearance.windowPadding * 2,
            height: frame.height - searchReservedHeight - Appearance.windowPadding * 2
        )

        scrollView.contentView.frame = scrollView.bounds
    }

    override func cancelOperation(_ sender: Any?) {
        ApplicationLauncher.hide()
    }

    func hide() {
        alphaValue = 0
        orderOut(nil)
    }
}

extension AppLauncherPanel: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        DispatchQueue.main.async {
            if ApplicationLauncher.isActive {
                AppLauncherPanel.shared.makeKeyAndOrderFront(nil)
            }
            MainMenu.toggle(true)
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        DispatchQueue.main.async {
            MainMenu.toggle(false)
        }
    }
}
