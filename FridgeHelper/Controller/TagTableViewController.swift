//
//  TagTableViewController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/2.
//

import UIKit

class TagTableViewController: UITableViewController{
    var tagViewModel = TagViewModel()
    
    //優化標籤，一開始會預設肉類魚類蔬菜水果供選擇
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "標籤管理"
        
        //MARK: - Bind
        tagViewModel.tagsObservor.bind { tags in
            switch self.tagViewModel.tagModifyStatus {
            case .deletItem(index: let index):
                //若刪完tag後tag list還有資料，則用deleteSections
                if let tags, !tags.isEmpty {
                    self.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .fade)
                } else {
                    //如果tag都刪光了，就用reloadData
                    self.tableView.reloadData()
                }
            default :
                self.tableView.reloadData()
            }
            self.tagViewModel.resetTagModifyStatus()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        //fetch tags
        tagViewModel.fetchedTags()
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
                var newTags: [String] = []
                if let tags = self.tagViewModel.tagsObservor.value {
                    newTags = tags
                }
                newTags.append(tag)
                self.tagViewModel.tagModifyStatus = .addItem
                self.tagViewModel.updateTags(tags: newTags)
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
        if let tags = tagViewModel.tagsObservor.value, !tags.isEmpty {
            return tags.count
        }else{
            return 1
        }
    }

    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tagCell = tableView.dequeueReusableCell(withIdentifier: "TagTableViewCell", for: indexPath)
        let noTagCell = tableView.dequeueReusableCell(withIdentifier: "NoTagTableViewCell", for: indexPath)
        //如果userDefaul有存tags，而且不是nil，就return tagCell
        if let tags = tagViewModel.tagsObservor.value, !tags.isEmpty {
            tagCell.imageView?.image = UIImage(systemName: "tag.circle")
            tagCell.imageView?.tintColor = UIColor(named: "Color3")
            tagCell.textLabel?.text = tags[indexPath.row]
            return tagCell
            
        } else {
            //如果是空陣列，就return noTagCell
            //基本上這邊不會nil，因為使用者剛安裝App時就會把default給存進去，後來就算再刪光光，也會是空陣列，而不是nil
            //因為不是nil，所以可以防止fetchedTags時偵測到tags是nil，而把default tag存到userDefault
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
            var newTags = tagViewModel.tagsObservor.value
            newTags?.remove(at: indexPath.row)
            if newTags!.isEmpty{
                self.tagViewModel.updateTags(tags: [])
            }else{
                self.tagViewModel.tagModifyStatus = .deletItem(index: indexPath.section)
                self.tagViewModel.updateTags(tags: newTags)
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
