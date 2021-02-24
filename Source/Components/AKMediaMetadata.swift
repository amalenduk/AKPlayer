//
//  AKMediaMetadata.swift
//  AKPlayer
//
//  Copyright (c) 2020 Amalendu Kar
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

// https://developer.apple.com/documentation/avfoundation/avmetadataidentifier
import AVFoundation

public struct AKMediaMetadata {

    // MARK: - Properties

    public private(set) var accessibilityDescription: String?
    public private(set) var albumName: String?
    public private(set) var artist: String?
    public private(set) var artwork: Data?
    public private(set) var author: String?
    public private(set) var contributor: String?
    public private(set) var copyrights: String?
    public private(set) var creationDate: String?
    public private(set) var creator: String?
    public private(set) var description: String?
    public private(set) var format: String?
    public private(set) var language: String?
    public private(set) var lastModifiedDate: String?
    public private(set) var location: String?
    public private(set) var make: String?
    public private(set) var model: String?
    public private(set) var publisher: String?
    public private(set) var relation: String?
    public private(set) var software: String?
    public private(set) var source: String?
    public private(set) var subject: String?
    public private(set) var title: String?
    public private(set) var type: String?

    public private(set) var commonMetadata: [AVMetadataItem]?

    // MARK: - Init

    init(with commonMetadata: [AVMetadataItem]) {
        if #available(iOS 14.0, *) {
            accessibilityDescription = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierAccessibilityDescription).first?.value as? String
        }
        albumName = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierAlbumName).first?.value as? String
        artist = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierArtist).first?.value as? String
        artwork = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierArtwork).first?.value as? Data
        author = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierAuthor).first?.value as? String
        contributor = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierContributor).first?.value as? String
        copyrights = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierCopyrights).first?.value as? String
        creationDate = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierCreationDate).first?.value as? String
        creator = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierCreator).first?.value as? String
        description = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierDescription).first?.value as? String
        format = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierFormat).first?.value as? String
        language = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierLanguage).first?.value as? String
        lastModifiedDate = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierLastModifiedDate).first?.value as? String
        location = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierLocation).first?.value as? String
        make = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierMake).first?.value as? String
        model = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierModel).first?.value as? String
        publisher = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierPublisher).first?.value as? String
        relation = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierRelation).first?.value as? String
        software = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierSoftware).first?.value as? String
        source = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierSource).first?.value as? String
        subject = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierSubject).first?.value as? String
        title = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierTitle).first?.value as? String
        type = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierType).first?.value as? String
    }
}
