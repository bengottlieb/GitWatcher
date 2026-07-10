//
//  StatusItemIcon.swift
//  GitWatcher
//

import AppKit

/// Builds the menu-bar icon, overlaying a white-on-red count badge when
/// repositories need attention.
enum StatusItemIcon {
	private static let symbolName = "arrow.triangle.2.circlepath"

	static func image(badgeCount: Int, appearance: NSAppearance?) -> NSImage {
		guard let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: "GitWatcher") else {
			return NSImage()
		}
		guard badgeCount > 0 else {
			base.isTemplate = true
			return base
		}
		return composite(base: tinted(base, for: appearance), count: badgeCount)
	}

	private static func tinted(_ base: NSImage, for appearance: NSAppearance?) -> NSImage {
		let config = NSImage.SymbolConfiguration(paletteColors: [labelColor(for: appearance)])
		let image = base.withSymbolConfiguration(config) ?? base
		image.isTemplate = false
		return image
	}

	private static func labelColor(for appearance: NSAppearance?) -> NSColor {
		guard let appearance else { return .labelColor }
		var resolved = NSColor.labelColor
		appearance.performAsCurrentDrawingAppearance {
			resolved = NSColor.labelColor.usingColorSpace(.deviceRGB) ?? .labelColor
		}
		return resolved
	}

	private static func composite(base: NSImage, count: Int) -> NSImage {
		let size = base.size
		let result = NSImage(size: size)
		result.lockFocus()
		base.draw(in: NSRect(origin: .zero, size: size))
		drawBadge(count: count, in: size)
		result.unlockFocus()
		result.isTemplate = false
		return result
	}

	private static func drawBadge(count: Int, in size: NSSize) {
		let text = count > 99 ? "99+" : "\(count)"
		let diameter = size.height * 0.72
		let attrs: [NSAttributedString.Key: Any] = [
			.font: NSFont.systemFont(ofSize: diameter * 0.682, weight: .bold),
			.foregroundColor: NSColor.white
		]
		let textSize = (text as NSString).size(withAttributes: attrs)
		let width = max(diameter, textSize.width + diameter * 0.45)
		let badge = NSRect(x: size.width - width, y: size.height - diameter, width: width, height: diameter)
		NSColor.systemRed.setFill()
		NSBezierPath(roundedRect: badge, xRadius: diameter / 2, yRadius: diameter / 2).fill()
		let textRect = NSRect(
			x: badge.midX - textSize.width / 2,
			y: badge.midY - textSize.height / 2,
			width: textSize.width,
			height: textSize.height
		)
		(text as NSString).draw(in: textRect, withAttributes: attrs)
	}
}
