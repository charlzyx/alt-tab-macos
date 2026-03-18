# 功能规划：Alt+Space 应用启动器
# 创建日期：2026-03-18
# 更新日期：2026-03-18
# 状态：开发中

## 概述

为 AltTab for macOS 添加一个新功能：使用 `Alt+Space` 快捷键呼出应用启动器，以网格形式展示所有已安装应用，并支持英文、中文、拼音搜索。

## 核心功能

### 1. 快捷键支持
- 新增快捷键：`Alt+Space`（可在设置中自定义）
- 呼出应用启动器面板

### 2. 应用列表展示
- **网格布局**：以应用图标 + 名称的网格形式展示
- **所有已安装应用**：不仅限于运行中的应用
- **快速启动**：点击或回车启动选中的应用

### 3. 搜索功能
- **英文搜索**：匹配应用名称（含副标题）
- **中文搜索**：匹配应用中文名称
- **拼音搜索**：支持拼音首字母和全拼搜索
- **实时搜索**：输入时立即过滤结果
- **模糊匹配**：使用 Smith-Waterman 算法

### 4. 用户界面
- **简洁设计**：与现有 AltTab 风格一致
- **响应式布局**：根据应用数量自动调整大小
- **支持触摸板**：支持缩放、滚动
- **键盘导航**：支持方向键、Tab 键导航

## 实现方案

### 1. 架构设计

#### 新增文件
```
/src/
├── logic/
│   ├── InstalledApplications.swift    # 已安装应用列表获取
│   ├── ApplicationLauncher.swift     # 应用启动器逻辑
│   └── search/
│       └── PinyinSearch.swift        # 拼音搜索实现
├── ui/
│   └── app-launcher/
│       ├── AppLauncherPanel.swift    # 启动器主面板
│       ├── AppLauncherView.swift     # 应用网格视图
│       └── AppTileView.swift         # 单个应用瓷砖视图
└── ui/settings-window/tabs/controls/
    └── AppLauncherControls.swift     # 启动器设置 UI
```

#### 修改文件
```
/src/ui/settings-window/tabs/controls/ControlsTab.swift
/src/ui/settings-window/tabs/controls/ControlsTabConstants.swift
/src/logic/events/KeyboardEvents.swift
/src/logic/ATShortcut.swift
/src/ui/App.swift
/resources/l10n/zh-CN.lproj/Localizable.strings
```

### 2. 核心模块实现

#### 2.1 InstalledApplications.swift
- 功能：获取系统已安装的应用列表
- 使用 `LSApplicationWorkspace` 和 `NSWorkspace` 枚举应用
- 过滤系统应用、不可见应用
- 缓存机制：避免重复扫描
- 异步加载：后台线程扫描

#### 2.2 PinyinSearch.swift
- 功能：提供拼音转换和搜索
- 中文 → 拼音转换
- 拼音首字母提取
- 拼音搜索算法
- 支持多音字处理（简单支持）

#### 2.3 AppLauncher.swift
- 功能：启动器核心逻辑
- 应用列表管理
- 搜索查询处理
- 应用启动
- 与主应用的交互

#### 2.4 UI 组件
- **AppLauncherPanel**：主窗口，浮动面板
- **AppLauncherView**：网格布局管理
- **AppTileView**：单个应用视图（图标+名称）

#### 2.5 搜索功能
- 继承现有 Search.swift 的 Smith-Waterman 算法
- 扩展支持中文和拼音搜索
- 调整搜索权重：应用名称 > 拼音 > 其他

### 3. 集成到现有系统

#### 3.1 快捷键系统集成
- 在 `ControlsTab` 中添加新的快捷键设置
- 在 `ATShortcut` 中定义新的快捷键类型
- 在 `KeyboardEvents` 中添加监听

#### 3.2 设置界面
- 在 Controls 标签页添加 "应用启动器" 部分
- 可自定义快捷键
- 可配置是否显示系统应用

#### 3.3 应用启动
- 使用 `NSWorkspace.shared.openApplication(at:)` 启动应用
- 支持应用别名（通过 Info.plist 配置）

### 4. 本地化

#### 中文本地化
```strings
/* 应用启动器 */
"App Launcher" = "应用启动器";
"Alt+Space shortcut to launch apps" = "使用 Alt+Space 快捷键启动应用";
"Show system applications" = "显示系统应用";
"Search installed applications" = "搜索已安装的应用";
"Launch application" = "启动应用";
"No matching applications" = "没有匹配的应用";
```

#### 英文本地化
```strings
"App Launcher" = "App Launcher";
"Alt+Space shortcut to launch apps" = "Use Alt+Space shortcut to launch apps";
"Show system applications" = "Show system applications";
"Search installed applications" = "Search installed applications";
"Launch application" = "Launch application";
"No matching applications" = "No matching applications";
```

### 5. GitHub Actions

#### 5.1 现有流程
- 运行在 macOS 15 + Xcode 26.0.1
- 包括测试、构建、打包、公证、发布

#### 5.2 新增检查
- 添加 SwiftLint 检查（如果有）
- 检查新增文件的语法
- 确保没有破坏现有功能

#### 5.3 构建策略
- 保持现有版本号管理
- 确保与现有功能兼容

## 风险评估

### 1. 性能风险
- 应用扫描：首次启动可能需要几秒
- 解决方案：异步扫描 + 缓存机制

### 2. 兼容性风险
- 不同 macOS 版本的 API 差异
- 解决方案：使用 availability 检查

### 3. 搜索质量
- 中文分词和拼音转换
- 解决方案：使用成熟的开源库

### 4. 应用列表完整性
- 系统限制可能导致某些应用无法被扫描
- 解决方案：提供手动添加功能

## 开发阶段

### 阶段 1：基础架构
- 完成 InstalledApplications.swift
- 完成 PinyinSearch.swift
- 完成 ApplicationLauncher.swift

### 阶段 2：UI 实现
- 完成 AppLauncherPanel.swift
- 完成 AppLauncherView.swift
- 完成 AppTileView.swift

### 阶段 3：集成
- 集成到 KeyboardEvents.swift
- 集成到 ControlsTab.swift
- 添加快捷键设置

### 阶段 4：本地化
- 添加中文本地化
- 添加英文和其他语言本地化

### 阶段 5：测试
- 单元测试
- 集成测试
- 性能测试

## 后续优化

### 版本 1.1
- 支持拖拽应用到启动器
- 支持自定义应用分类

### 版本 1.2
- 应用使用频率排序
- 最近使用应用优先

### 版本 1.3
- 支持插件/扩展
- 支持主题自定义

## 参考

- [macOS Application Launcher Patterns](https://developer.apple.com/design/human-interface-guidelines/macos/menus-and-popovers/searchfields/)
- [Chinese Text Handling](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/OSXHIGuidelines/TextInput.html)
- [Search Best Practices](https://developer.apple.com/design/human-interface-guidelines/macos/menus-and-popovers/searchfields/)
