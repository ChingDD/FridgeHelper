//
//  TagTableViewController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/2.
//

import UIKit

class TagTableViewController: UITableViewController {
    
    var tags:[String]?{
        didSet{
            TagController.shared.saveTags(tags: tags)
            //當tag都刪光了，就把路徑移除
            if tags == []{
                let url = URL.documentsDirectory.appending(path: "tags")
                try?FileManager.default.removeItem(at: url)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tags = TagController.shared.fetchTags()
        //print(tags)
        title = "標籤管理"
    }

    //MARK: - Target Action
    
    @IBAction func addTag(_ sender: UIBarButtonItem) {
        
        let alertController = UIAlertController(title: "標籤", message: "新增標籤", preferredStyle: .alert)
        alertController.addTextField {textField in
            textField.placeholder = "標籤名稱(不能為空白)"
        }
        
        let OkAction = UIAlertAction(title: "確認", style: .default){_ in
            if let tag = alertController.textFields?.first?.text,
               alertController.textFields?.first?.text?.isEmpty == false {
                print("tag有append")
                if self.tags == nil{
                    self.tags = [tag]
                }else{
                    self.tags?.append(tag)
                    //print(self.tags)
                }
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
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tags?.count ?? 1
    }

    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tagCell = tableView.dequeueReusableCell(withIdentifier: "TagTableViewCell", for: indexPath)
        let noTagCell = tableView.dequeueReusableCell(withIdentifier: "NoTagTableViewCell", for: indexPath)
        if tags != nil{
            tagCell.imageView?.image = UIImage(systemName: "tag.circle")
            tagCell.imageView?.tintColor = UIColor(named: "Color3")
            tagCell.textLabel?.text = tags![indexPath.row]
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
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            tags?.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
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
