//
//  ExpiredViewController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/16.
//

import UIKit

class ExpiredViewController: UIViewController {

    @IBOutlet weak var expiredTableView: UITableView!
    
    
    var savedItems:[Item]?
    var expiredItems:[Item]?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        expiredTableView.dataSource = self
        print("viewDidLoad")
        title = "即將過期的食品！"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("viewWillAppear")

        savedItems = Item.fetchItems()
        
        expiredItems = savedItems?.filter({
          print($0.expiryDate.timeIntervalSinceNow)
          return $0.expiryDate.timeIntervalSinceNow <= 259200
        })
        
        //如果過濾完結果是空字串，就設回nil
        if let expiredItems{
            if expiredItems.isEmpty{
                self.expiredItems = nil
            }
        }
       
        expiredTableView.reloadData()
    }

    override func viewDidLayoutSubviews() {
        self.view.frame = CGRect(x: 50, y: 70, width: 300 , height: 500)
    }
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension ExpiredViewController:UITableViewDataSource{
    func numberOfSections(in tableView: UITableView) -> Int {
        return expiredItems?.count ?? 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print("跑cellForRow")
        
        if let item = expiredItems?[indexPath.section]{
            let cell = tableView.dequeueReusableCell(withIdentifier: "ExpiredTableViewCell", for: indexPath) as! ExpiredTableViewCell
            //設定cell上的元件資訊
            cell.amountsLabel.text = "\(item.number)"
            //設定過期標籤
            if item.expiryDate.timeIntervalSinceNow > -(60*60*24){
                cell.expiredDateLabel.text = dateController.share.setDateFormate(item.expiryDate)
                cell.expiredDateLabel.textColor = UIColor(named: "Color6")
            }else{
                let expiredDay = Int((-item.expiryDate.timeIntervalSinceNow)/(60*60*24))
                cell.expiredDateLabel.text = "物品已經過期\(expiredDay)天"
                cell.expiredDateLabel.textColor = UIColor.red
            }
            //設定備註
            cell.memoLabel.text = item.memo
            //設定名字
            cell.nameLabel.text = item.name
            //設定圖片內容及高度
            cell.itemImageView.image = Item.loadImage(item)
            if let _ = expiredItems?[indexPath.section].memo{
                cell.itemImageView.frame.origin.y = 35
            }else{
                cell.itemImageView.frame.origin.y = 13
            }
            //設定label sizeToFit
            for aView in cell.contentView.subviews{
                if aView is UILabel{
                    let label = aView as! UILabel
                    label.sizeToFit()
                }
            }
            
            return cell
            
        }else{
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "NoExpiredTableViewCell", for: indexPath)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        if let _ = expiredItems?[indexPath.section].memo{
            return 165
        }else{
            return 120
        }
        
    }
}
