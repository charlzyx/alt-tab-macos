import Cocoa

class ApplicationLauncher {
    static var isActive = false
    static var searchQuery = ""
    static var selectedIndex = 0
    static var filteredApplications = [InstalledApplications.InstalledApplication]()

    static func initialize() {
        InstalledApplications.initialize()
    }

    static func show() {
        isActive = true
        searchQuery = ""
        selectedIndex = 0
        refreshFilteredApplications()
        AppLauncherPanel.shared.show()
    }

    static func hide() {
        isActive = false
        AppLauncherPanel.shared.orderOut(nil)
    }

    static func toggle() {
        if isActive {
            hide()
        } else {
            show()
        }
    }

    static func updateSearchQuery(_ query: String) {
        searchQuery = query
        selectedIndex = 0
        refreshFilteredApplications()
        AppLauncherPanel.shared.updateContent()
    }

    static func refreshFilteredApplications() {
        if searchQuery.isEmpty {
            filteredApplications = InstalledApplications.getAllApplications()
        } else {
            filteredApplications = InstalledApplications.searchApplications(searchQuery)
        }
    }

    static func selectNext() {
        if filteredApplications.isEmpty { return }
        selectedIndex = (selectedIndex + 1) % filteredApplications.count
        AppLauncherPanel.shared.updateSelection()
    }

    static func selectPrevious() {
        if filteredApplications.isEmpty { return }
        selectedIndex = (selectedIndex - 1 + filteredApplications.count) % filteredApplications.count
        AppLauncherPanel.shared.updateSelection()
    }

    static func selectUp() {
        guard let gridColumns = AppLauncherPanel.shared.gridColumns, gridColumns > 0 else { return }
        if selectedIndex >= gridColumns {
            selectedIndex -= gridColumns
        }
        AppLauncherPanel.shared.updateSelection()
    }

    static func selectDown() {
        guard let gridColumns = AppLauncherPanel.shared.gridColumns, gridColumns > 0 else { return }
        if selectedIndex + gridColumns < filteredApplications.count {
            selectedIndex += gridColumns
        }
    }

    static func selectLeft() {
        if selectedIndex > 0 {
            selectedIndex -= 1
            AppLauncherPanel.shared.updateSelection()
        }
    }

    static func selectRight() {
        if selectedIndex < filteredApplications.count - 1 {
            selectedIndex += 1
            AppLauncherPanel.shared.updateSelection()
        }
    }

    static func launchSelected() {
        if !filteredApplications.isEmpty && selectedIndex < filteredApplications.count {
            let app = filteredApplications[selectedIndex]
            if InstalledApplications.launchApplication(app) {
                hide()
            }
        }
    }

    static func launch(_ app: InstalledApplications.InstalledApplication) {
        if InstalledApplications.launchApplication(app) {
            hide()
        }
    }

    static func refresh() {
        InstalledApplications.refresh {
            DispatchQueue.main.async {
                refreshFilteredApplications()
                AppLauncherPanel.shared.updateContent()
            }
        }
    }
}
