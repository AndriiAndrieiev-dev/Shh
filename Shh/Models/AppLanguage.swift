// Copyright (c) 2026 Andrii Andrieiev
// Licensed under the Apache License, Version 2.0. See LICENSE for details.

//
//  AppLanguage.swift
//  Shh…
//
//  In-app UI language, independent of the macOS system language.
//

import Foundation

enum AppLanguage: String, Codable, CaseIterable, Sendable, Identifiable {
    case en
    case uk

    var id: String { rawValue }

    /// Name shown in the language picker, written in that language itself.
    var displayName: String {
        switch self {
        case .en: return "English"
        case .uk: return "Українська"
        }
    }
}