// Copyright (c) 2026 Andrii Andrieiev
// Licensed under the Apache License, Version 2.0. See LICENSE for details.

//
//  HUDPosition.swift
//  Shh…
//
//  Layout configuration for the floating HUD overlay. Split into independent
//  horizontal and vertical axes so any 3×3 combination is reachable, plus a
//  three-step size variant.
//

import Foundation
import CoreGraphics

enum HUDHorizontalAlignment: String, Codable, CaseIterable, Sendable, Identifiable {
    case left
    case center
    case right

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left:   return "Left"
        case .center: return "Center"
        case .right:  return "Right"
        }
    }

    var iconName: String {
        switch self {
        case .left:   return "arrow.left.to.line.compact"
        case .center: return "arrow.left.and.right"
        case .right:  return "arrow.right.to.line.compact"
        }
    }
}

enum HUDVerticalAlignment: String, Codable, CaseIterable, Sendable, Identifiable {
    case top
    case center
    case bottom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .top:    return "Top"
        case .center: return "Center"
        case .bottom: return "Bottom"
        }
    }

    var iconName: String {
        switch self {
        case .top:    return "arrow.up.to.line.compact"
        case .center: return "arrow.up.and.down"
        case .bottom: return "arrow.down.to.line.compact"
        }
    }
}

enum HUDSize: String, Codable, CaseIterable, Sendable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small:  return "Small"
        case .medium: return "Medium"
        case .large:  return "Large"
        }
    }

    /// Outer panel dimension (square).
    var dimension: CGFloat {
        switch self {
        case .small:  return 160
        case .medium: return 220
        case .large:  return 280
        }
    }

    /// Diameter of the inner material circle behind the mic icon.
    var circleSize: CGFloat {
        switch self {
        case .small:  return 78
        case .medium: return 110
        case .large:  return 142
        }
    }

    /// Mic SF Symbol font size.
    var iconFontSize: CGFloat {
        switch self {
        case .small:  return 36
        case .medium: return 52
        case .large:  return 68
        }
    }
}