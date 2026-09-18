//
//   AKMediaMetadata.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKMediaMetadata

/// A model representing metadata extracted from media assets using common metadata identifiers.
public struct AKMediaMetadata: Equatable, Sendable {
    // MARK: - Properties

    public var accessibilityDescription: String?
    public var albumName: String?
    public var artist: String?
    public var artwork: Data?
    public var author: String?
    public var contributor: String?
    public var copyrights: String?
    public var creationDate: String?
    public var creator: String?
    public var description: String?
    public var format: String?
    public var language: String?
    public var lastModifiedDate: String?
    public var location: String?
    public var make: String?
    public var model: String?
    public var publisher: String?
    public var relation: String?
    public var software: String?
    public var source: String?
    public var title: String?
    public var type: String?

    // MARK: - Initialization

    public init(
        accessibilityDescription: String? = nil,
        albumName: String? = nil,
        artist: String? = nil,
        artwork: Data? = nil,
        author: String? = nil,
        contributor: String? = nil,
        copyrights: String? = nil,
        creationDate: String? = nil,
        creator: String? = nil,
        description: String? = nil,
        format: String? = nil,
        language: String? = nil,
        lastModifiedDate: String? = nil,
        location: String? = nil,
        make: String? = nil,
        model: String? = nil,
        publisher: String? = nil,
        relation: String? = nil,
        software: String? = nil,
        source: String? = nil,
        title: String? = nil,
        type: String? = nil
    ) {
        self.accessibilityDescription = accessibilityDescription
        self.albumName = albumName
        self.artist = artist
        self.artwork = artwork
        self.author = author
        self.contributor = contributor
        self.copyrights = copyrights
        self.creationDate = creationDate
        self.creator = creator
        self.description = description
        self.format = format
        self.language = language
        self.lastModifiedDate = lastModifiedDate
        self.location = location
        self.make = make
        self.model = model
        self.publisher = publisher
        self.relation = relation
        self.software = software
        self.source = source
        self.title = title
        self.type = type
    }
}
