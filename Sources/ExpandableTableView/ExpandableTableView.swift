
import UIKit

open class ExpandableTableView: UITableView {
    
    fileprivate weak var expandableDataSource: ExpandableTableViewDataSource?
    fileprivate weak var expandableDelegate: ExpandableTableViewDelegate?
    
    public fileprivate(set) var expandedSections: [Int: Bool] = [:]
    
    open var expandingAnimation: UITableView.RowAnimation = ExpandableDefault.expandingAnimation
    open var collapsingAnimation: UITableView.RowAnimation = ExpandableDefault.collapsingAnimation
    
    public override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open override var dataSource: UITableViewDataSource? {
        get { return super.dataSource }
        set(dataSource) {
            guard let dataSource = dataSource else { return }
            expandableDataSource = dataSource as? ExpandableTableViewDataSource
            super.dataSource = self
        }
    }
    
    open override var delegate: UITableViewDelegate? {
        get { return super.delegate }
        set(delegate) {
            guard let delegate = delegate else { return }
            expandableDelegate = delegate as? ExpandableTableViewDelegate
            super.delegate = self
        }
    }
}

extension ExpandableTableView {
    public func expand(_ section: Int) {
        animate(with: .expand, forSection: section)
    }
    
    public func collapse(_ section: Int) {
        animate(with: .collapse, forSection: section)
    }
    
    private func animate(with type: ExpandableType, forSection section: Int) {
        guard canExpand(section) else { return }
        
        let sectionIsExpanded = didExpand(section)
        
        //If section is visible and action type is expand, OR, If section is not visible and action type is collapse, return.
        if ((type == .expand) && (sectionIsExpanded)) || ((type == .collapse) && (!sectionIsExpanded)) { return }
        
        assign(section, asExpanded: (type == .expand))
        startAnimating(self, with: type, forSection: section)
    }
    
    private func startAnimating(_ tableView: ExpandableTableView, with type: ExpandableType, forSection section: Int) {
    
        let headerCell = (self.cellForRow(at: IndexPath(row: 0, section: section)))
        let headerCellConformant = headerCell as? ExpandableTableViewHeaderCell
        
        CATransaction.begin()
        headerCell?.isUserInteractionEnabled = false
        
        //Inform the delegates here.
        headerCellConformant?.changeState((type == .expand ? .willExpand : .willCollapse), cellReuseStatus: false)
        expandableDelegate?.tableView(tableView, expandableState: (type == .expand ? .willExpand : .willCollapse), changeForSection: section)

        CATransaction.setCompletionBlock {
            //Inform the delegates here.
            headerCellConformant?.changeState((type == .expand ? .didExpand : .didCollapse), cellReuseStatus: false)
            
            self.expandableDelegate?.tableView(tableView, expandableState: (type == .expand ? .didExpand : .didCollapse), changeForSection: section)
            headerCell?.isUserInteractionEnabled = true
        }
        
        self.beginUpdates()
        
        //Don't insert or delete anything if section has only 1 cell.
        if let sectionRowCount = expandableDataSource?.tableView(tableView, numberOfRowsInSection: section), sectionRowCount > 1 {
            
            var indexesToProcess: [IndexPath] = []
            
            //Start from 1, because 0 is the header cell.
            for row in 1..<sectionRowCount {
                indexesToProcess.append(IndexPath(row: row, section: section))
            }
            
            //Expand means inserting rows, collapse means deleting rows.
            if type == .expand {
                self.insertRows(at: indexesToProcess, with: expandingAnimation)
            }else if type == .collapse {
                self.deleteRows(at: indexesToProcess, with: collapsingAnimation)
            }
        }
        self.endUpdates()
        
        CATransaction.commit()
    }
}

// MARK: - UITableViewDataSource

extension ExpandableTableView: UITableViewDataSource {
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let numberOfRows = expandableDataSource?.tableView(self, numberOfRowsInSection: section) ?? 0
        
        guard canExpand(section) else { return numberOfRows }
        guard numberOfRows != 0 else { return 0 }
        
        return didExpand(section) ? numberOfRows : 1
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard canExpand(indexPath.section), indexPath.row == 0 else {
            return expandableDataSource!.tableView(tableView, cellForRowAt: indexPath)
        }
        
        let headerCell = expandableDataSource!.tableView(self, expandableCellForSection: indexPath.section)
        
        guard let headerCellConformant = headerCell as? ExpandableTableViewHeaderCell else {
            return headerCell
        }
        
        DispatchQueue.main.async {
            if self.didExpand(indexPath.section) {
                headerCellConformant.changeState(.willExpand, cellReuseStatus: true)
                headerCellConformant.changeState(.didExpand, cellReuseStatus: true)
            }else {
                headerCellConformant.changeState(.willCollapse, cellReuseStatus: true)
                headerCellConformant.changeState(.didCollapse, cellReuseStatus: true)
            }
        }
        return headerCell
    }
}

// MARK: - UITableViewDelegate

extension ExpandableTableView: UITableViewDelegate {
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        expandableDelegate?.tableView?(tableView, didSelectRowAt: indexPath)
        
        guard canExpand(indexPath.section), indexPath.row == 0 else { return }
        didExpand(indexPath.section) ? collapse(indexPath.section) : expand(indexPath.section)
    }
}

//MARK: Helper Methods

extension ExpandableTableView {
    fileprivate func canExpand(_ section: Int) -> Bool {
        //If canExpandSections delegate method is not implemented, it defaults to true.
        return expandableDataSource?.tableView(self, canExpandSection: section) ?? ExpandableDefault.expandableStatus
    }
    
    fileprivate func didExpand(_ section: Int) -> Bool {
        return expandedSections[section] ?? false
    }
    
    fileprivate func assign(_ section: Int, asExpanded: Bool) {
        expandedSections[section] = asExpanded
    }
}

//MARK: Protocol Helper

extension ExpandableTableView {
    fileprivate func verifyProtocol(_ aProtocol: Protocol, contains aSelector: Selector) -> Bool {
        return protocol_getMethodDescription(aProtocol, aSelector, true, true).name != nil || protocol_getMethodDescription(aProtocol, aSelector, false, true).name != nil
    }
    
    override open func responds(to aSelector: Selector!) -> Bool {
        if verifyProtocol(UITableViewDataSource.self, contains: aSelector) {
            return (super.responds(to: aSelector)) || (expandableDataSource?.responds(to: aSelector) ?? false)
            
        }else if verifyProtocol(UITableViewDelegate.self, contains: aSelector) {
            return (super.responds(to: aSelector)) || (expandableDataSource?.responds(to: aSelector) ?? false)
        }
        return super.responds(to: aSelector)
    }
    
    override open func forwardingTarget(for aSelector: Selector!) -> Any? {
        if verifyProtocol(UITableViewDataSource.self, contains: aSelector) {
            return expandableDataSource
            
        }else if verifyProtocol(UITableViewDelegate.self, contains: aSelector) {
            return expandableDelegate
        }
        return super.forwardingTarget(for: aSelector)
    }
}

