// Copyright (c) 2026 Andrii Andrieiev
// Licensed under the Apache License, Version 2.0. See LICENSE for details.

//
//  ScreenCorner.swift
//  Shh…
//
//  Which corner of the main display the persistent mic indicator anchors to.
//

import Foundation

enum ScreenCorner: String, Codable, CaseIterable, Sendable, Identifiable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topLeft:     return "Top Left"
        case .topRight:    return "Top Right"
        case .bottomLeft:  return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }
}