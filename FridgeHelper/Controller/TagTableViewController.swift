//
//  TagTableViewController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/2.
//

import UIKit

class TagTableViewController: UITableViewController{
    let defaultTags = ["蔬菜","水果","肉類","魚類"]
    var tags:[String]?{
        didSet{
            print("抓資料前\(String(describing: tags))")
            TagController.shared.saveTags(tags: tags)
            print("抓資料後\(String(describing: tags))")

//            //當tag都刪光了，就把路徑移除
//            if let tags, tags.isEmpty {
//                let url = URL.documentsDirectory.appending(path: "tags")
//                try?FileManager.default.removeItem(at: url)
//            }
        }
    }
    //優化標籤，一開始會預設肉類魚類蔬菜水果供選擇
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "標籤管理"
        
        if let savedtags = TagController.shared.fetchTags(){
            //當userDefault有資料，就會以抓到的資料為主
            tags = savedtags
        }else{
            //如果使用者是自己把標籤刪光光，使標籤變空陣列，則表示他不想要預設標籤，所以就不要存defaultTag進去tags
            //如果使用者沒有儲存標籤(一開始啟動app)，則一開始會顯示預設的，並儲存到userDefault裡
            tags = defaultTags
                
        }
        //print(tags)
    }

    //MARK: - Target Action
    
    @IBAction func addTag(_ sender: UIBarButtonItem) {
        
        let alertController = UIAlertController(title: "標籤", message: "新增標籤", preferredStyle: .alert)
        alertController.addTextField {textField in
            textField.placeholder = "標籤名稱(不能為空白)"
            textField.delegate = self
        }
        
        
        let OkAction = UIAlertAction(title: "確認", style: .default){_ in
            if let tag = alertController.textFields?.first?.text,
               alertController.textFields?.first?.text?.isEmpty == false {
                print("tag有append")
                self.tags?.append(tag)
                self.tableView.reloadData()
            }
            
        }
        
        
        let cancelAction = UIAlertAction(title: "取消", style: .destructive)
        alertController.addAction(OkAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true)
    }
    
    
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        print("跑numberOfSections")
        return 1
    }

    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("跑numberOfRowsInSection")
        if let tags, !tags.isEmpty{
            return tags.count
        }else{
            return 1
        }
    }

    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print("跑cellForRowAt")
        let tagCell = tableView.dequeueReusableCell(withIdentifier: "TagTableViewCell", for: indexPath)
        let noTagCell = tableView.dequeueReusableCell(withIdentifier: "NoTagTableViewCell", for: indexPath)
        if let tags, !tags.isEmpty{
            tagCell.imageView?.image = UIImage(systemName: "tag.circle")
            tagCell.imageView?.tintColor = UIColor(named: "Color3")
            tagCell.textLabel?.text = tags[indexPath.row]
            return tagCell
        }else{
            noTagCell.textLabel?.text = "尚未建立標籤"
            return noTagCell
        }


    }
    

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    
    // Override to support editing the table view.
    //MARK: - 刪到底會報錯
    /*
     Thread 1: "Invalid update: invalid number of rows in section 0. The number of rows contained in an existing section after the update (1) must be equal to the number of rows contained in that section before the update (1), plus or minus the number of rows inserted or deleted from that section (0 inserted, 1 deleted) and plus or minus the number of rows moved into or out of that section (0 moved in, 0 moved out).
     指的應該是說update後的row數量要符合update前做的新增修改後的數量
     */
     
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            tags?.remove(at: indexPath.row)
            print("刪完後的tags：\(String(describing: tags))")
            if tags!.isEmpty{
                tableView.reloadData()
            }else{
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
        }
        
    }
    

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

extension TagTableViewController:UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.contains(" "){
            return false
        }else{
            return true
        }
    }
}
