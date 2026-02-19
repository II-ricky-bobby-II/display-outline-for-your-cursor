import AppKit
import Carbon

final class PreferencesWindowController: NSWindowController {
  private var settings: AppSettings
  private var isUpdatingUI = false
  private let onSettingsChanged: (AppSettings) -> Void

  private let hotKeyPopup = NSPopUpButton(frame: .zero, pullsDown: false)
  private let commandCheckbox = NSButton(checkboxWithTitle: "Command", target: nil, action: nil)
  private let optionCheckbox = NSButton(checkboxWithTitle: "Option", target: nil, action: nil)
  private let controlCheckbox = NSButton(checkboxWithTitle: "Control", target: nil, action: nil)
  private let shiftCheckbox = NSButton(checkboxWithTitle: "Shift", target: nil, action: nil)

  private let thicknessSlider = NSSlider(value: 4, minValue: 1, maxValue: 12, target: nil, action: nil)
  private let thicknessValueLabel = NSTextField(labelWithString: "4")

  private let outlineColorWell = NSColorWell(frame: .zero)

  private let spotlightSlider = NSSlider(value: 120, minValue: 60, maxValue: 280, target: nil, action: nil)
  private let spotlightValueLabel = NSTextField(labelWithString: "120")

  private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
  private let launchAtLoginHelpLabel = NSTextField(labelWithString: "Requires the app to be installed in /Applications.")

  init(settings: AppSettings, onSettingsChanged: @escaping (AppSettings) -> Void) {
    self.settings = settings
    self.onSettingsChanged = onSettingsChanged

    let contentRect = NSRect(x: 0, y: 0, width: 520, height: 340)
    let window = NSWindow(
      contentRect: contentRect,
      styleMask: [.titled, .closable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Cursor Outline Preferences"
    window.isReleasedWhenClosed = false
    window.center()

    super.init(window: window)

    configureControls()
    buildUI()
    applySettingsToUI()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func update(settings: AppSettings) {
    self.settings = settings
    applySettingsToUI()
  }

  private func configureControls() {
    for option in HotKeyConfig.supportedKeys {
      hotKeyPopup.addItem(withTitle: option.title)
      hotKeyPopup.lastItem?.representedObject = NSNumber(value: option.keyCode)
    }

    hotKeyPopup.target = self
    hotKeyPopup.action = #selector(hotKeyChanged(_:))

    for checkbox in [commandCheckbox, optionCheckbox, controlCheckbox, shiftCheckbox] {
      checkbox.target = self
      checkbox.action = #selector(modifierChanged(_:))
      checkbox.setButtonType(.switch)
    }

    thicknessSlider.target = self
    thicknessSlider.action = #selector(thicknessChanged(_:))

    outlineColorWell.target = self
    outlineColorWell.action = #selector(colorChanged(_:))

    spotlightSlider.target = self
    spotlightSlider.action = #selector(spotlightChanged(_:))

    launchAtLoginCheckbox.target = self
    launchAtLoginCheckbox.action = #selector(launchAtLoginChanged(_:))

    launchAtLoginHelpLabel.textColor = .secondaryLabelColor
    launchAtLoginHelpLabel.lineBreakMode = .byWordWrapping
    launchAtLoginHelpLabel.maximumNumberOfLines = 2

    thicknessValueLabel.alignment = .right
    spotlightValueLabel.alignment = .right
  }

  private func buildUI() {
    guard let contentView = window?.contentView else { return }

    let stack = NSStackView()
    stack.orientation = .vertical
    stack.spacing = 14
    stack.translatesAutoresizingMaskIntoConstraints = false

    contentView.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
      stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
      stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20),
    ])

    stack.addArrangedSubview(makeSectionTitle("Hotkey"))
    stack.addArrangedSubview(makeHotKeyRow())
    stack.addArrangedSubview(makeModifierRow())

    stack.addArrangedSubview(makeSeparator())

    stack.addArrangedSubview(makeSectionTitle("Outline"))
    stack.addArrangedSubview(makeSliderRow(label: "Thickness", slider: thicknessSlider, valueLabel: thicknessValueLabel))
    stack.addArrangedSubview(makeColorRow())

    stack.addArrangedSubview(makeSeparator())

    stack.addArrangedSubview(makeSectionTitle("Spotlight"))
    stack.addArrangedSubview(makeSliderRow(label: "Radius", slider: spotlightSlider, valueLabel: spotlightValueLabel))

    stack.addArrangedSubview(makeSeparator())

    stack.addArrangedSubview(launchAtLoginCheckbox)
    stack.addArrangedSubview(launchAtLoginHelpLabel)
  }

  private func makeSectionTitle(_ text: String) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .boldSystemFont(ofSize: 13)
    return label
  }

  private func makeHotKeyRow() -> NSView {
    let container = NSStackView(views: [NSTextField(labelWithString: "Key"), hotKeyPopup])
    container.orientation = .horizontal
    container.alignment = .centerY
    container.spacing = 12
    hotKeyPopup.widthAnchor.constraint(equalToConstant: 120).isActive = true
    return container
  }

  private func makeModifierRow() -> NSView {
    let modifierStack = NSStackView(views: [controlCheckbox, optionCheckbox, commandCheckbox, shiftCheckbox])
    modifierStack.orientation = .horizontal
    modifierStack.alignment = .centerY
    modifierStack.spacing = 12
    return modifierStack
  }

  private func makeSliderRow(label: String, slider: NSSlider, valueLabel: NSTextField) -> NSView {
    let title = NSTextField(labelWithString: label)
    title.setContentHuggingPriority(.required, for: .horizontal)

    valueLabel.widthAnchor.constraint(equalToConstant: 42).isActive = true

    let row = NSStackView(views: [title, slider, valueLabel])
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 12
    return row
  }

  private func makeColorRow() -> NSView {
    let row = NSStackView(views: [NSTextField(labelWithString: "Color"), outlineColorWell])
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 12
    return row
  }

  private func makeSeparator() -> NSView {
    let separator = NSBox()
    separator.boxType = .separator
    return separator
  }

  private func applySettingsToUI() {
    isUpdatingUI = true
    defer { isUpdatingUI = false }

    if let selected = hotKeyPopup.itemArray.first(where: {
      ($0.representedObject as? NSNumber)?.uint32Value == settings.hotKey.keyCode
    }) {
      hotKeyPopup.select(selected)
    }

    controlCheckbox.state = settings.hotKey.modifiers & UInt32(controlKey) != 0 ? .on : .off
    optionCheckbox.state = settings.hotKey.modifiers & UInt32(optionKey) != 0 ? .on : .off
    commandCheckbox.state = settings.hotKey.modifiers & UInt32(cmdKey) != 0 ? .on : .off
    shiftCheckbox.state = settings.hotKey.modifiers & UInt32(shiftKey) != 0 ? .on : .off

    thicknessSlider.doubleValue = settings.outlineThickness
    thicknessValueLabel.stringValue = String(format: "%.1f", settings.outlineThickness)

    outlineColorWell.color = settings.outlineColor.nsColor

    spotlightSlider.doubleValue = settings.spotlightRadius
    spotlightValueLabel.stringValue = String(Int(settings.spotlightRadius.rounded()))

    launchAtLoginCheckbox.state = settings.launchAtLogin ? .on : .off
  }

  private func publishSettings() {
    guard !isUpdatingUI else { return }
    onSettingsChanged(settings.sanitized)
  }

  @objc private func hotKeyChanged(_ sender: NSPopUpButton) {
    guard let keyCode = (sender.selectedItem?.representedObject as? NSNumber)?.uint32Value else { return }
    settings.hotKey.keyCode = keyCode
    publishSettings()
  }

  @objc private func modifierChanged(_ sender: NSButton) {
    var modifiers: UInt32 = 0
    if controlCheckbox.state == .on { modifiers |= UInt32(controlKey) }
    if optionCheckbox.state == .on { modifiers |= UInt32(optionKey) }
    if commandCheckbox.state == .on { modifiers |= UInt32(cmdKey) }
    if shiftCheckbox.state == .on { modifiers |= UInt32(shiftKey) }

    settings.hotKey.modifiers = modifiers
    publishSettings()
  }

  @objc private func thicknessChanged(_ sender: NSSlider) {
    settings.outlineThickness = sender.doubleValue
    thicknessValueLabel.stringValue = String(format: "%.1f", settings.outlineThickness)
    publishSettings()
  }

  @objc private func colorChanged(_ sender: NSColorWell) {
    settings.outlineColor = AppColor(from: sender.color)
    publishSettings()
  }

  @objc private func spotlightChanged(_ sender: NSSlider) {
    settings.spotlightRadius = sender.doubleValue
    spotlightValueLabel.stringValue = String(Int(settings.spotlightRadius.rounded()))
    publishSettings()
  }

  @objc private func launchAtLoginChanged(_ sender: NSButton) {
    settings.launchAtLogin = sender.state == .on
    publishSettings()
  }
}
