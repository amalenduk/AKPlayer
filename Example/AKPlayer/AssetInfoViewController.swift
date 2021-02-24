//
//  AssetInfoViewController.swift
//  AKPlayer_Example
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
import AKPlayer
import UIKit

class AssetInfoViewController: UIViewController {

    // MARK: - Outlates

    @IBOutlet weak private var tableView: UITableView!

    // MARK: - Variables

    var assetInfo: AKMediaMetadata?
    var dict: [[String: Any]]?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Asset info"
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        dict = getValues()
        tableView.reloadData()

        let button = UIBarButtonItem(title: "Dismiss", style: .plain, target: self, action: #selector(dismissButtonAction(_ :)))
        navigationItem.leftBarButtonItem = button
    }

    // MARK: - Additional Helpers

    func getValues() -> [[String: Any?]] {
        guard let info = assetInfo  else { return [] }

        let mirror = Mirror(reflecting: info)

        var retValue = [[String:Any]]()
        for (_, attr) in mirror.children.enumerated() {
            if let propertyName = attr.label {
                retValue.append([propertyName: attr.value])
            }
        }
        return retValue
    }

    // MARK: - User Interaction

    @objc func dismissButtonAction(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - UITableViewDelegate

extension AssetInfoViewController: UITableViewDelegate {

}

// MARK: - UITableViewDataSource

extension AssetInfoViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dict?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = UITableViewCell.init(style: .subtitle, reuseIdentifier: "cell")
        cell.textLabel?.text = dict?[indexPath.row].keys.first?.camelCaseToWords()

        if let artWork = dict?[indexPath.row].values.first as? Data {
            cell.imageView?.image = UIImage(data: artWork)
        }else {
            cell.detailTextLabel?.text = String(describing: dict?[indexPath.row].values.first ?? "")
        }
        return cell
    }
}

extension String {
    func camelCaseToWords() -> String {
        return unicodeScalars.reduce("") {
            if NSCharacterSet.uppercaseLetters.hasMember(inPlane: UInt8(uint_least16_t($1.value))) {
                return ($0 + " " + String($1))
            }else {
                return ($0 + String($1))
            }
        }
    }
}
