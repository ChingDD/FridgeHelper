//
//  ExpiredTableViewCell.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/15.
//

import UIKit

class ExpiredTableViewCell: UITableViewCell {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var amountsLabel: UILabel!
    @IBOutlet weak var expiredDateLabel: UILabel!
    @IBOutlet weak var memoLabel: UILabel!
    @IBOutlet weak var itemImageView: UIImageView!
    @IBOutlet weak var memoTitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()

    }



    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
