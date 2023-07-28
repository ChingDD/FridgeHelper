//
//  ExpiredTableViewController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/15.
//

import UIKit

class ExpiredTableViewController: UITableViewController {

    var savedItems:[Item]?
    var expiredItems:[Item]?
    var desiredWidth:CGFloat!
    var desiredHeight:CGFloat!
    var offSetX:CGFloat!
    var offSetY:CGFloat!
    var isViewDissapear:Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewDidLoad")
        title = "即將過期的食品！"
       

        
        
    }

    
    @IBAction func backToMain(_ sender: Any) {
        dismiss(animated: true)
    }
    
    
    
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("viewWillAppear")
        
        //判斷畫面有無消失，沒消失的話就不會再更新畫面的呈現
        if isViewDissapear == true{
            desiredWidth = view.frame.size.width*0.8
            desiredHeight = view.frame.size.height*0.75
            offSetX = view.frame.size.width - view.frame.size.width*0.8
            offSetY = view.frame.size.height - view.frame.size.height*0.75
            
            view.frame.size.width = desiredWidth
            view.frame.size.height = desiredHeight
            view.frame.origin.x = offSetX/2
            view.frame.origin.y = offSetY/2
            view.layer.cornerRadius = 20
            view.clipsToBounds = true
            isViewDissapear = false
        }
       
        //更新顯示的物品
        savedItems = Item.fetchItems()
        expiredItems = savedItems?.filter({
            //259200為三天前的秒數，表示過期日小於三天會提醒
           $0.expiryDate.timeIntervalSinceNow <= 259200
        })
        //如果過濾完結果是空字串，表示沒篩到，就設回nil
        if let expiredItems{
            if expiredItems.isEmpty{
                self.expiredItems = nil
            }
        }
       
        
        tableView.reloadData()
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        //當畫面確定消失，就更改布林判斷值
        isViewDissapear = true
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return expiredItems?.count ?? 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 1
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print("跑cellForRow")
        
        if let item = expiredItems?[indexPath.section]{
            print("expiredItem:\(item)")
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
            if item.memo != nil{
                cell.memoLabel.isHidden = false
                cell.memoTitleLabel.isHidden = false
                cell.memoLabel.text = item.memo
            }else{
                cell.memoLabel.isHidden = true
                cell.memoTitleLabel.isHidden = true
            }
            //設定名字
            cell.nameLabel.text = item.name
            //設定圖片內容及高度
            if let imageData = item.image, let image = UIImage(data: imageData){
                cell.itemImageView.image = image
            }else{
                cell.itemImageView.image = nil
            }
            cell.itemImageView.contentMode = .scaleAspectFill

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
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        print("heightForRowAt")
        if let _ = expiredItems?[indexPath.section]{
            return UITableView.automaticDimension
        }else{
            print("heightForRowAt:\(tableView.frame.height)")
            return tableView.frame.height
        }
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
