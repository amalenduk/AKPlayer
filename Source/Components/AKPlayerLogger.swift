//
//  AKPlayerLogger.swift
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

import Foundation

final public class AKPlayerLoggerInputParam {
    public var domains: [AKPlayerLoggerDomain]?
}

final public class AKPlayerLogger {
    
    // MARK: - Properties
    
    static let shared = AKPlayerLogger()
    public static let setup = AKPlayerLoggerInputParam()
    
    private var domains: [AKPlayerLoggerDomain] = []
    private let formatter = DateFormatter()
    private let dateFormat = "hh:mm:ssSSS"
    
    // MARK: - Init
    
    private init() {
        guard let domains = AKPlayerLogger.setup.domains
            else { assertionFailure("Should provide configuration to logger"); return }
        
        self.domains = domains
        setupDateFormatter()
    }
    
    private func setupDateFormatter() {
        formatter.dateFormat = dateFormat
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
    }
    
    private func sourceFileName(filePath: String) -> String {
        let components = filePath.components(separatedBy: "/")
        return components.isEmpty ? "" : components.last ?? ""
    }
    
    func log(message: String,
             domain: AKPlayerLoggerDomain,
             fileName: String = #file,
             line: Int = #line,
             funcName: String = #function) {
        
        guard domains.contains(domain) else { return }
        print("\(formatter.string(from: Date())) \(domain.description)[\(sourceFileName(filePath: fileName))]:\(line) :: \(message)")
    }
}
