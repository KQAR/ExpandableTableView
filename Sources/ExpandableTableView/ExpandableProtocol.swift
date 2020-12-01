//
//  File.swift
//  
//
//  Created by 金瑞 on 2020/12/1.
//

import UIKit

public protocol ExpandableTableViewHeaderCell: class {
    func changeState(_ state: ExpandableState, cellReuseStatus cellReuse: Bool)
}

public protocol ExpandableTableViewDataSource: UITableViewDataSource {
    func tableView(_ tableView: ExpandableTableView, canExpandSection section: Int) -> Bool
    func tableView(_ tableView: ExpandableTableView, expandableCellForSection section: Int) -> UITableViewCell
}

public protocol ExpandableTableViewDelegate: UITableViewDelegate {
    func tableView(_ tableView: ExpandableTableView, expandableState state: ExpandableState, changeForSection section: Int)
}
