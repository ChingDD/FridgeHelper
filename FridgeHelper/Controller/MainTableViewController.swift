//
//  MainTableViewController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/2.
//

import UIKit

class MainTableViewController: UITableViewController {
    //為什麼IBOulet會有weak? 因為這些元件都是view的subView，所以他們被存在subView的array裡，已經有連結指向他們。所以這邊可以使用weak。
    @IBOutlet weak var storeConditionSegmentControl: UISegmentedControl!
    
    @IBOutlet weak var tagFilterBtn: UIButton!
    
    @IBOutlet weak var sortItemBtn: UIButton!
        
    @IBOutlet weak var tableHeaderView: UIView!
    
    @IBOutlet weak var expiredAmounts: UILabel!
    
    
    //物品
    var showedItems:[Item]?
    
    var savedItems:[Item]?{
        didSet{
            if let savedItems{
                Item.saveItems(savedItems)
                print("savedItems已更新")
            }else{
                let url = URL.documentsDirectory.appending(path: "items")
                let fileManager = FileManager.default
                do{
                    try fileManager.removeItem(at: url)
                }catch{
                    print("items移除失敗")
                }
            }
        }
    }
    
    
    var expiredItems:[Item]?

    //接收第二頁傳過來的item
    var item:Item?
    //儲存的tag
    var tags:[String]?
    //標籤篩選器
    var isTagSelectorOn:Bool = false{
        didSet{
            print("isTagSelectorOn：\(isTagSelectorOn)")
        }
    }
    //目前選到得tag
    var currentTag:String?
    //目前cell被選到的狀態
    var isCellSelected = false{
        didSet{
            print("isCellSelected：\(isCellSelected)")
        }
    }
    //目前篩選器的選擇
    var currentSelector = SortMethod.取消
    
    //搜尋列
    var searchingItems:[Item]?
    var keyword = ""
    
    //MARK: - viewController life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        //生成搜尋列
        let searchController = UISearchController()
        navigationItem.searchController = searchController
        searchController.searchResultsUpdater = self
        
        //讀取存在Document資料夾的items
        let url = URL.documentsDirectory.appending(path: "items")
        print("url:\(url)")
        if let itemData = try? Data(contentsOf: url){
            
            savedItems = try! JSONDecoder().decode([Item].self, from: itemData)
            showedItems = savedItems
            
        }else{
            print("目前無items的儲存檔案")
        }
        
        //改變segmentControl UI
        storeConditionSegmentControl.setTitleTextAttributes([NSAttributedString.Key.foregroundColor:UIColor(named: "Color6")!], for: .selected)
        storeConditionSegmentControl.setTitleTextAttributes([NSAttributedString.Key.foregroundColor:UIColor(named: "Color7")!], for: .normal)
        //篩選按鈕加入menu
        sortItemBtn.menu = setSortMethodMenu()
        sortItemBtn.showsMenuAsPrimaryAction = true
        //導航列的title
        title = "FridgeHelper"
        //將過期數量的label設成isHidden
        expiredAmounts.isHidden = true
    }

    override func viewWillAppear(_ animated: Bool) {
        //讀取存在Document資料夾的tags
        tags = TagController.shared.fetchTags()
        //加入Menu
        let menu = setTagPopUpMenu(tags: tags)
        tagFilterBtn.menu = menu
        //更新勾選狀態
        TagController.shared.updateClickUI(tagFilterBtn, currentTag: currentTag)
        //點了btn才會有反應
        tagFilterBtn.showsMenuAsPrimaryAction = true
        //取消cell被選擇的狀態
        isCellSelected = false
        
        //抓出有過期的物品
        expiredItems = savedItems?.filter({
          $0.expiryDate.timeIntervalSinceNow <= 259200
        })
        
        //如果過濾完結果是空字串，就設回nil，否則就顯示警示Label個數
        if let expiredItems{
            if expiredItems.isEmpty{
                expiredAmounts.isHidden = true
                self.expiredItems = nil
            }else{
                expiredAmounts.isHidden = false
                expiredAmounts.text = "\(expiredItems.count)"
            }
        }

        
    }
    
    //MARK: - 自定義function
    
    
    func searchKeywords(_ inputText:String)->[Item]?{
        if !inputText.isEmpty{
            let result = showedItems?.filter({ $0.name.contains(inputText) })
            return result
        }else{
            return showedItems
        }
    }
    
    func selectedTagItems()->[Item]?{
        
        if isTagSelectorOn{
            let selectedTagItems = showedItems?.filter({ $0.tag == currentTag})
            return selectedTagItems
        }else{
            return showedItems
        }
    }
    
    func selectShowedItem(){
        switch storeConditionSegmentControl.selectedSegmentIndex{
        case 0:
            showedItems = savedItems
            showedItems = currentSelector.sortShowedItems(showedItems)
            showedItems = searchKeywords(keyword)
            showedItems = selectedTagItems()
        case 1:
            showedItems = savedItems?.filter { $0.storeCondition==0 }
            showedItems = currentSelector.sortShowedItems(showedItems)
            showedItems = searchKeywords(keyword)
            showedItems = selectedTagItems()
        case 2:
            showedItems = savedItems?.filter { $0.storeCondition==1 }
            showedItems = currentSelector.sortShowedItems(showedItems)
            showedItems = searchKeywords(keyword)
            showedItems = selectedTagItems()
        case 3:
            showedItems = savedItems?.filter { $0.storeCondition==2 }
            showedItems = currentSelector.sortShowedItems(showedItems)
            showedItems = searchKeywords(keyword)
            showedItems = selectedTagItems()
        default:
            break
        }
    }
    
    
    
    //建立標籤按鈕
    func setTagPopUpMenu(tags:[String]?)->UIMenu{
        //如果tags是nil，則顯示尚未建立標籤的UIAction
        guard let tags else {
            let noTagBtn = UIAction(title: "尚未建立標籤") { _ in
                print("尚未建立標籤")
            }
            let menu = UIMenu(title: "標籤篩選器", options: .displayInline, children: [noTagBtn])
            return menu
        }
        
        //定義一個變數tagBtns裝UIAction陣列
        //用map將[String]變成[UIAction]
        var tagBtns = tags.map { tag in
            //建立UIAction
            let tagBtn = UIAction(title: tag) {[self] _ in
                //選擇按鈕後可以就目前的segment做篩選
                isTagSelectorOn = true
                currentTag = tag
                print("currentTag:\(String(describing: currentTag))")
                selectShowedItem()
                tableView.reloadData()
            }
            return tagBtn
        }
        //取消標籤按鈕
        let cancelAction = UIAction(title: "取消標籤選擇",state: .on) {[self] _ in
            print( "取消標籤")
            isTagSelectorOn = false
            currentTag = nil
            selectShowedItem()
            tableView.reloadData()
        }
        
        //將tagBtns加入取消鈕
        tagBtns.insert(cancelAction, at: 0)
        //將 [UIAction]加入menu
        let menu = UIMenu(title: "標籤篩選器", options: .singleSelection, children: tagBtns)
        return menu
    }
    
    //建立篩選按鈕
    func setSortMethodMenu()->UIMenu{
        let cancelBtn = UIAction(title: "取消", state: .on) {[self]_ in
            //因為selectShowedItem()會判斷currentSelector狀況，所以要先改currentSelector狀態，才能reloadData
            currentSelector = SortMethod.取消
            selectShowedItem()
            tableView.reloadData()
        }
        let sortBtn1 =  UIAction(title: SortMethod.時間排序遠到近.rawValue) {[self]_ in
            currentSelector = SortMethod.時間排序遠到近
            selectShowedItem()
            tableView.reloadData()
        }
        let sortBtn2 =  UIAction(title: SortMethod.時間排序近到遠.rawValue) {[self]_ in
            currentSelector = SortMethod.時間排序近到遠
            selectShowedItem()
            tableView.reloadData()
        }
        let sortBtn3 =  UIAction(title: SortMethod.剩餘數量多到少.rawValue) {[self]_ in
            currentSelector = SortMethod.剩餘數量多到少
            selectShowedItem()
            tableView.reloadData()
        }
        let sortBtn4 =  UIAction(title: SortMethod.剩餘數量少到多.rawValue) {[self]_ in
            currentSelector = SortMethod.剩餘數量少到多
            selectShowedItem()
            tableView.reloadData()
        }
        let menu = UIMenu(title: "分類", options: .singleSelection, children: [cancelBtn,sortBtn1,sortBtn2,sortBtn3,sortBtn4])
        return menu
    }
    
    
    
    //測試OK
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("跑prepare")
        //修改資料時，會走這邊把選到的item傳下一頁顯示
        if isCellSelected{
            guard let index = tableView.indexPathForSelectedRow?.section, let controller = segue.destination as? EditViewController else {return}
            print("跑到prepare裡的indexPathForSelectedRow")
            controller.item = showedItems?[index]
        }
    }
    
    
    
    
    //MARK: - Target Action
    //測試OK
    @IBAction func unwindToMain(_ unwindSegue: UIStoryboardSegue) {
        print("unwindToMain")
        let controller = unwindSegue.source as! EditViewController
        //若是新增時，是點選新增紐，則這頁的tableViewCell不會被點選，所以indexPathForSelectedRow會是nil，那就會走第一段
        //tableView.indexPathForSelectedRow?.section == nil
        if isCellSelected == false{
            print("進入新增區段")
            //如果已有建立的物品，就更改儲存總物品的內容
            print("已建立物品")
            if savedItems?.isEmpty == false{
                savedItems?.insert(controller.item!, at: 0)
                print("savedItems:\(String(describing: savedItems))")
                print("showedItems:\(String(describing: showedItems))")
                //即時更新在不同儲存條件下的物品
                selectShowedItem()
                
            }else{
                //如果還沒建立物品
                print("未建立物品")
                savedItems = [controller.item!]
                //即時更新在不同儲存條件下的物品
                selectShowedItem()
                print("savedItems:\(String(describing: savedItems))")
                print("showedItems:\(String(describing: showedItems))")
            }
            tableView.reloadData()
            
        }else{
            print("進入修改區段")
            //要是修改，表示是點cell到下一頁，則indexPathForSelectedRow會呈現點選狀態，就不是nil，因此會跑這段
            let index = tableView.indexPathForSelectedRow!.section
            
            //利用index找到showedItems的裡的物品，在尚未更新showedItems前先把該物品讀出來，然後藉由name比對savedItems來得到該物品在savedItems裡的indexPath
            //得到後移除savedItems裡的該物品，再把剛剛傳過來的新物品插入
            
            
            if let savedItems{

                if let chosenItemIndex = savedItems.firstIndex(where:{ $0.name == showedItems?[index].name && $0.expiryDate == showedItems?[index].expiryDate }){

                    self.savedItems?.remove(at: chosenItemIndex)
                    self.savedItems?.insert(controller.item!, at: chosenItemIndex)

                }

            }
            
            /*
             要是物品有相同名字，這段程式碼會篩不到正確的物品
            if let savedItems, let chosenItemIndex = savedItems.firstIndex(where:{ $0.name == showedItems?[index].name }){

                self.savedItems?.remove(at: chosenItemIndex)
                self.savedItems?.insert(controller.item!, at: chosenItemIndex)

            }
             */
            
            
            //更改完savedItems後再更改showedItems的資訊
            //showedItems?[index] = controller.item! -> bug：要是更換儲存條件，還是會出現仍在原儲存條件的table上
            selectShowedItem()
            tableView.reloadData()
            /*更新表格
             如果是更新原cell上面的數量或資訊，可以用reloadRows
             如果是更新item的儲存條件，導致cell不存在當前頁面，則使用reloadRows會報錯，因為reloadRows是重整當前存在的頁面
             如果是上述情況，則可使用deleteSections，因為cell不存在當前頁面，所以表格可以以刪除方式刪掉該cell
             但如果只是單純更新原cell上面的數量或資訊，deleteSections又會出錯
             所以最好的方法是reloadData
             
             tableView.reloadRows(at: [IndexPath(row: 0, section: index)], with: .automatic)
             tableView.deleteSections(IndexSet(integer: index), with: .fade)
             */
            
        }
    }
    
   
    //測試OK
    
    //MARK: - 確認在幹嘛
    @IBAction func chooseStoreCondition(_ sender: UISegmentedControl) {
        //當savedItems為nil，則其他的選項都會顯示為登入物品；若savedItems不為空，但其他選項剛好沒有，則其他的選項會呈現空白
        selectShowedItem()
        tableView.reloadData()
    }

    @IBAction func changeAmount(_ sender: UIButton) {
        
        let point = sender.convert(CGPoint.zero, to: tableView)
        
        guard let indexPath = tableView.indexPathForRow(at: point) else {return}
        
        var number = showedItems![indexPath.section].number
        
        switch sender.tag{
        case 0:
             number += 1
        case 1:
            if number == 0{
                number = 0
            }else{
                number -= 1
            }
        default:break
        }
        
    
        //回改item數量的Label
        let cell = tableView.cellForRow(at: indexPath) as! ItemTableViewCell
        cell.numberLabel.text = "\(number)"
        
        
        //回改item的數量
        if let chosenItemIndex = savedItems?.firstIndex(where:{ $0.name == showedItems?[indexPath.section].name && $0.expiryDate == showedItems?[indexPath.section].expiryDate }){

            self.showedItems?[indexPath.section].number = number
            self.savedItems?[chosenItemIndex].number = number

        }
        
        tableView.reloadRows(at: [indexPath], with: .none)
    }
    
    
    
    
    
    
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
      
            let number = showedItems?.count ?? 1
            print("showedItems的Section:\(number)")
            return number
     
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    
    //測試OK
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        /*
         不能在全域變數就把兩個cell做出來，如下，否則開啟app時會出現error
         let noItemcell = tableView.dequeueReusableCell(withIdentifier: "NoItemTableViewCell", for: indexPath)
         let itemcell = tableView.dequeueReusableCell(withIdentifier: "ItemTableViewCell", for: indexPath) as! ItemTableViewCell
         <error>:
         Thread 1: "Attempted to dequeue multiple cells for the same index path, which is not allowed. If you really need to dequeue more cells than the table view is requesting, use the -dequeueReusableCellWithIdentifier: method (without an index path). Cell identifier: ItemTableViewCell, index path: <NSIndexPath: 0x9b86a3611d9e14b6> {length = 2, path = 0 - 0}"
         */
        
        var itemcell:ItemTableViewCell
        
        
        if let showedItems{
            itemcell = tableView.dequeueReusableCell(withIdentifier: "ItemTableViewCell", for: indexPath) as! ItemTableViewCell
            let showedItem = showedItems[indexPath.section]
            //日期設定
            let itemExpiredDate = showedItem.expiryDate
            itemcell.dateTextField.text = dateController.share.setDateFormate(itemExpiredDate)
            itemcell.dateTextField.sizeToFit()
            //item名字
            itemcell.itemNameLabel.text = showedItem.name
            //sizeToFit要寫在後面才有用
            itemcell.itemNameLabel.sizeToFit()
            //item數量
            itemcell.numberLabel.text = "\(showedItem.number)"
            //備註
            if let memo = showedItem.memo{
                itemcell.memoLabel.text = memo
                itemcell.memoLabel.sizeToFit()
                itemcell.memoLabel.isHidden = false
                itemcell.memoTitleLabel.isHidden = false
            }else{
                itemcell.memoLabel.isHidden = true
                itemcell.memoTitleLabel.isHidden = true
            }
            
            //沒有照片的cell，image裡面存nil，因爲有存東西，所以不會被reuse的cell圖片蓋掉
            if let imageData = showedItem.image{
                itemcell.itemImageView.image = UIImage(data: imageData)
            }else{
                itemcell.itemImageView.image = nil
            }
            itemcell.itemImageView.contentMode = .scaleAspectFill
            
            return itemcell
            
        }else{
            let noItemcell = tableView.dequeueReusableCell(withIdentifier: "NoItemTableViewCell", for: indexPath)
            
            return noItemcell
        }
    }

 
    
    
    //MARK: - Table View Delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("didSelectRowAt")

        //不能用以下程式碼把選到的東東西放入item變數，因為會先跑prepare，才跑到這邊，所以會來不及準備要傳過去的item
//        print("跑didSelectRowAt")
//        print(indexPath.section)
//        print(items)
//        item = items[indexPath.section]
//        print(item)
    }

    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        //cell被點選狀態變成true
        //寫這邊不寫在didSelectRowAt的原因：因為didSelectRowAt最後才跑，這樣的話isCellSelected來不及變true，就會先被prepare讀到false
        /*
         willSelectRowAt
         isCellSelected：true
         跑prepare
         跑到prepare裡的indexPathForSelectedRow
         didSelectRowAt

         */
        print("willSelectRowAt")
        isCellSelected = true
        return indexPath
    }
    

    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        //準備刪除按鈕
        //.normal會讓按鈕的顏色是灰色
        let buttonDelete = UIContextualAction(style: .normal, title: "刪除") {
            [unowned self]
            action, view, complete
            in

            //刪除資料後，把刪除的資料儲存
            let removedItem = showedItems!.remove(at: indexPath.section)
            
            //  如果items已經空了，就reloadData就好，不然用deleteSection的話會報錯
            if showedItems!.isEmpty{
                showedItems = nil
                tableView.reloadData()
                
            }else{
                //移除表格
                //寫deleteRows會報錯，因為我的表格是一個物品代表一個section，此時item減少，section也會減少，但這個func刪掉row後原本的section仍在，故當他偵測到items減少，section數量卻沒變時會報錯
                //tableView.deleteRows(at: [indexPath], with: .fade) -> 會報錯
                tableView.deleteSections(IndexSet(integer: indexPath.section), with: .fade)
            }
        
            //回改原儲存資料
            if let chosenItemIndex = savedItems?.firstIndex(where:{ $0.name == removedItem.name && $0.expiryDate == removedItem.expiryDate }){

                self.savedItems?.remove(at: chosenItemIndex)
                //刪到光後會變空陣列，不是nil，所以可以大膽強制拆封
                if self.savedItems!.isEmpty {self.savedItems = nil}
            }
            
            
       
            
            //若刪除的資料是過期的物品，則要更新過期物品的label數量
            //step1. 先看expiredItems裡是否有移除的物品，有的話就篩出來
            if let removedExpiredItemIndex = expiredItems?.firstIndex(where: { $0.name == removedItem.name && $0.expiryDate == removedItem.expiryDate }){
                
                //step2. 若有篩到，就刪除過期物品裡的東西
                expiredItems?.remove(at: removedExpiredItemIndex)
                //step3. 刪完後，可能是空陣列或還有東西，所以要考慮兩種可能
                if let expiredItems{
                    //空陣列會進來這段
                    if expiredItems.isEmpty{
                        self.expiredItems = nil
                        expiredAmounts.isHidden = true
                    }else{
                        //真的有篩到東西
                        expiredAmounts.text = "\(expiredItems.count)"
                    }
                }

                
            }
        }
        
        
        //更改按鈕背景色
        buttonDelete.backgroundColor = .red
        //設定右側按鈕組合
        let config = UISwipeActionsConfiguration(actions: [buttonDelete])
        //滑到底觸發第一顆按鈕(最右邊)的功能
        config.performsFirstActionWithFullSwipe = false
        //回傳按鈕組合
        return config
        
        
    }

//    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
//        let view = UIView.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 0))
//        view.backgroundColor = .white
//        return view
//    }
//
//    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
//       return 0
//    }
    
    
//    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
//        return 0
//    }
//
//
//    override func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
//        return 0
//    }
//
//    override func tableView(_ tableView: UITableView, estimatedHeightForFooterInSection section: Int) -> CGFloat {
//        return 0
//    }
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

//MARK: protocol
extension MainTableViewController:UISearchResultsUpdating{
    func updateSearchResults(for searchController: UISearchController) {
        if let searchText = searchController.searchBar.text{
            keyword = searchText
            selectShowedItem()
            tableView.reloadData()
        }
    }
    
    
}



/*
 bug:
 ✅ 1.其他溫度的品項增加數量，不會改到對應的物品 -> 本來只有改到savedItems，但也要同時更改showedItems的數量
 ✅ 2.換儲存條件會無法顯示 -> 前面寫了一個guard let擋住了
 ✅ 3.刪除失敗 -> 因為本來刪掉物品後showedItems會didSet然後reloadData，之後才deleteSection，此時row已經因為reloadData而變少了，故deleteSection時會發生數量不對
 ✅ 4.點選cell進入到edit頁面。返回上一頁後如果點選標籤，會報錯，說標籤頁面的型別無法轉型成編輯頁面的型別 -> 已用Optional Binding檢驗是否為正確轉型的controller型別，不是的話就不會轉型
 ✅ 5.點選表格會進入修改畫面，回到上一頁後按下新增，仍然會變成修改畫面 -> 自定義一個變數isCellSelected，點選cell時他變true，返回時他會變false，
    點選表格後程式跑的順序：
    點選cell(此時馬上將isCellSelected變true)；若點選新增紐，則isCellSelected維持false ->
    prepare(確認isCellSelected狀態，決定要修改還是新增) ->
    下一頁按done ->
    下一頁的prepare ->
    unwindSegue(根據isCellSelected決定要新增還是修改) ->
    ViewWillAppear(將isCellSelected變回false)
 
 ✅ 6.篩選器可以作用，換segment後篩選器會恢復原狀 -> 使用enum定義func，並新增一個變數儲存目前使用的方法，以辨識需不需要做篩選
 ✅ 7.照片無法呈現中文檔名 -> 用url.removeAddpercentage解碼
 ✅ 8.標籤選擇後如果到編輯頁，再回到上一頁時，最自動勾選取消標籤的按鈕 -> 再tagController新增function可以自動更新打勾，並作用在viewWillApear裡
 ✅ 9.tag已選取狀態，按下tag後不會立即更新table -> 在按鈕的功能裡面定義reloadData
 ✅ 10.搜尋後，若找到cell，在按下起她segment後都會出現 -> 因為當初把顯示的item分成showedItems與searchingItems兩類，當tableView因為isSearching為true時會抓searchingItems的資料，但是按下segment後更新的function是以showedItems為主，所以不會更新到searchingItems的資料，因此我把所有顯示的變動都改在showedItems上，不額外區分searchingItems。
     此外也定義一個更新搜尋的function，並作用在按下segment後更新的function裡，這樣子就可以把搜尋的結果都更新在showedItems。
 ✅ 11. cell點了以後會呈現空白的 -> 我在cellDidSelected的function寫下isCellSelected = true，但是在跑這邊之前會先跑prepare，所以prepare會偵測false，故使用willSelectRowAt
 12. 客製化出現的畫面時，cell比例不對
 ✅ 13.headerView跟cell黏再一起 -> 再cell裡額外新增一個view來裝物件，這個view可以小一點，再藉由顏色設定就可以製造出cell跟headerView有空隙的感覺
 ✅ 14. 刪掉過期物品後，如果本來在過期物品按鈕上有紅字，他不會消失 -> 在刪除的func裡設定，當expired裡的物品為nil時，改變按鈕的UI
 15. 我在過期頁面輸入以下程式碼：view.frame.origin.y = view.frame.origin.y + 50
，結果執行後會無限跑viewDidLayoutSubViews
 
 16. 彈出鍵盤時畫面要上移，但無法取得元件的真實位置，因為他們被包在stackView裡面 -> 利用座標轉換將textField的座標從自身轉換為View。textField.convert(textField.frame.origin, to: view)
 
 目標：
 ✅ 1.寫UIAction的功能，能夠同時篩選tag以及在不同segment切換也能顯示
 ✅ 2.建好searchBar元件，但尚未建構功能
 ✅ 3.到期提醒
 4. autoLayout
 ✅ 5. 限定只有直式
 
 改善：
 選擇showedItems那邊可以再簡化，不用落落長
 篩選目前是以名字篩選，要是使用者輸入兩筆一樣名字的物品會出錯
 */
