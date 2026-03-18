import Cocoa

class AppLauncherView: FlippedView {
    var recycledViews = [AppTileView]()
    var filteredApplications = [InstalledApplications.InstalledApplication]()
    var thumbnailsWidth = CGFloat(0.0)
    var thumbnailsHeight = CGFloat(0.0)

    private let interCellPadding = CGFloat(16)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupRecycledViews()
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupRecycledViews() {
        for _ in 0..<20 {
            let view = AppTileView()
            view.mouseUpCallback = { [weak self] in
                self?.handleTileClick(view)
            }
            recycledViews.append(view)
        }
    }

    func updateItemsAndLayout() {
        filteredApplications = ApplicationLauncher.filteredApplications

        let widthMax = AppLauncherPanel.shared.frame.width - Appearance.windowPadding * 2
        let heightMax = AppLauncherPanel.shared.frame.height - 100

        let (newThumbnailsWidth, newThumbnailsHeight) = layoutItems(widthMax, heightMax)

        thumbnailsWidth = newThumbnailsWidth
        thumbnailsHeight = newThumbnailsHeight

        frame = NSRect(x: 0, y: 0, width: thumbnailsWidth, height: thumbnailsHeight)
    }

    private func layoutItems(_ widthMax: CGFloat, _ heightMax: CGFloat) -> (CGFloat, CGFloat) {
        let tileSize = tileSizeForGrid()
        let columns = Int(floor(widthMax / (tileSize.width + interCellPadding)))

        AppLauncherPanel.shared.gridColumns = columns

        var currentX = CGFloat(0)
        var currentY = CGFloat(0)
        var maxX = CGFloat(0)
        var maxY = CGFloat(0)

        for (index, app) in filteredApplications.enumerated() {
            var view: AppTileView
            if index < recycledViews.count {
                view = recycledViews[index]
            } else {
                view = AppTileView()
                view.mouseUpCallback = { [weak self] in
                    self?.handleTileClick(view)
                }
                recycledViews.append(view)
            }

            if index > 0 && index % columns == 0 {
                currentX = 0
                currentY += tileSize.height + interCellPadding
            }

            view.frame = NSRect(
                x: currentX,
                y: currentY,
                width: tileSize.width,
                height: tileSize.height
            )

            view.updateWithApp(app)
            addSubview(view)

            currentX += tileSize.width + interCellPadding
            maxX = max(maxX, currentX)
            maxY = max(maxY, currentY + tileSize.height)
        }

        for i in filteredApplications.count..<recycledViews.count {
            let view = recycledViews[i]
            view.removeFromSuperview()
            view.updateWithApp(nil)
        }

        return (maxX, maxY)
    }

    private func tileSizeForGrid() -> CGSize {
        let appearanceSize = Preferences.appearanceSize
        switch appearanceSize {
        case .small:
            return CGSize(width: 64, height: 80)
        case .medium:
            return CGSize(width: 80, height: 100)
        case .large:
            return CGSize(width: 96, height: 120)
        case .auto:
            return CGSize(width: 80, height: 100)
        }
    }

    func highlightSelected() {
        for (index, view) in recycledViews.enumerated() {
            view.isSelected = index == ApplicationLauncher.selectedIndex
        }
    }

    private func handleTileClick(_ view: AppTileView) {
        if let index = recycledViews.firstIndex(of: view) {
            if index < filteredApplications.count {
                ApplicationLauncher.selectedIndex = index
                highlightSelected()
                ApplicationLauncher.launchSelected()
            }
        }
    }
}

class AppTileView: FlippedView {
    var appIcon = LightImageLayer()
    var label = NSTextField(labelWithString: "")
    var isSelected = false

    var mouseUpCallback: (() -> Void)!

    convenience init() {
        self.init(frame: .zero)
        setupView()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        layer!.masksToBounds = false
        setupIcon()
        setupLabel()
    }

    private func setupIcon() {
        appIcon.applyShadow(TileView.makeAppIconShadow(Appearance.imagesShadowColor))
        layer!.addSublayer(appIcon)
    }

    private func setupLabel() {
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = NSColor.textColor
        label.isEditable = false
        label.isSelectable = false
        addSubview(label)
    }

    func updateWithApp(_ app: InstalledApplications.InstalledApplication?) {
        if let app = app {
            let iconSize = iconSize()
            appIcon.updateContents(.cgImage(app.icon), iconSize)

            label.stringValue = app.localizedName
            label.toolTip = app.localizedName
        } else {
            appIcon.updateContents(nil, iconSize())
            label.stringValue = ""
            label.toolTip = nil
        }

        updatePositions()
        applyHighlight()
    }

    private func iconSize() -> CGSize {
        switch Preferences.appearanceSize {
        case .small:
            return CGSize(width: 48, height: 48)
        case .medium:
            return CGSize(width: 64, height: 64)
        case .large:
            return CGSize(width: 80, height: 80)
        case .auto:
            return CGSize(width: 64, height: 64)
        }
    }

    private func updatePositions() {
        let iconSize = self.iconSize()
        let labelHeight = label.fittingSize.height

        appIcon.frame = NSRect(
            x: (frame.width - iconSize.width) / 2,
            y: frame.height - iconSize.height - labelHeight - 8,
            width: iconSize.width,
            height: iconSize.height
        )

        label.frame = NSRect(
            x: 0,
            y: 0,
            width: frame.width,
            height: labelHeight
        )
    }

    private func applyHighlight() {
        layer!.backgroundColor = isSelected ? NSColor.selectedControlColor.cgColor : NSColor.clear.cgColor
        layer!.cornerRadius = 8
    }

    override func mouseUp(with event: NSEvent) {
        mouseUpCallback()
    }

    override func mouseEntered(with event: NSEvent) {
        layer!.backgroundColor = NSColor.selectedTextBackgroundColor.withAlphaComponent(0.2).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        applyHighlight()
    }

    override func isAccessibilityElement() -> Bool { true }
}
