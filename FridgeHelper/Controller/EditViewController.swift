//
//  EditViewController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/2.
//

import UIKit

class EditViewController: UIViewController {

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var numberTextField: UITextField!
    @IBOutlet weak var expiryDateTextField: UITextField!
    @IBOutlet weak var memoTextField: UITextField!
    @IBOutlet weak var tagTextField: UITextField!
    @IBOutlet weak var itemImageView: UIImageView!
    @IBOutlet weak var storeConditionSegmentControl: UISegmentedControl!
    
    var item:Item?
    var image:UIImage?
    var tags:[String]? = ["未選擇"]
    var selectedTagIndex:Int = 0
    var pickView = UIPickerView()
    var datePicker = UIDatePicker()
    var isCellSelected = false
    var currentObjectButtonY = 0.0
    //var item:Item!   會報nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //設定監聽鍵盤事件
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(showKeyboard), name: UIResponder.keyboardWillShowNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(hideKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
        //將delegate設成自己
//        for aView in view.subviews{
//            print(view.subviews)
//            if aView is UITextField{
//                let textField = aView as! UITextField
//                textField.delegate = self
//            }
//        }
        view.subviews[1].subviews.forEach {
            
            for aView in $0.subviews{
                if aView is UITextField{
                let textField = aView as! UITextField
                textField.delegate = self
    
                }
            }
        }
        
        pickView.delegate = self
        
        //更新UI介面
        updateUI()
        let fetchTags = TagController.shared.fetchTags()
        if let fetchTags{
            tags = tags! + fetchTags
        }
        itemImageView.layer.borderWidth = 5
        itemImageView.layer.borderColor = UIColor(named: "Color")?.cgColor
    }
    
    //MARK: - 自定義function
    @objc func showKeyboard(_ notification:Notification){
        //print(notification.userInfo!.keys)
        print("鍵盤要叫出來了")

        let keyboardFrame = notification.userInfo?[AnyHashable("UIKeyboardBoundsUserInfoKey")] as! CGRect
        print("keyboardFrame:\(keyboardFrame)")
        let deviceMaxY = UIScreen.main.bounds.maxY
        //該機種鍵盤以上的可見區域(固定值)
        //原本是用view的MaxY扣，但是會有bug，因為按最後一個textField後view會上升，此時的maxY會改變，本來會比maxY小的物件會變成位置比他們大，所以就會誤判而造成view上升
        let currentVisibleButtonY = deviceMaxY - keyboardFrame.height
        
        if currentObjectButtonY > currentVisibleButtonY{
            let offSetY = currentObjectButtonY-currentVisibleButtonY
            UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.2, delay: 0) {
                self.view.frame.origin.y = -offSetY
            }
        }else{
            //當點選最後一個造成view上升後，如果點選前面的物件，因為位置較小，所以不會造成view改變，此時就會使view維持在上升的狀態，可能會出現鍵盤與畫面間的黑洞
            view.frame.origin.y = 0
        }
    }
    
    @objc func hideKeyboard(_ notification:Notification){
        UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.2, delay: 0) {
            self.view.frame.origin.y = 0
        }
    }
    
    
    func updateUI(){
        //如果第二頁的item有接收第一頁傳來的資料，就把他讀出來並傳到元件上
        if let item{
            nameTextField.text = item.name
            numberTextField.text = "\(item.number)"
            
            //日期變成字串
            expiryDateTextField.text = dateController.share.setDateFormate(item.expiryDate)
            memoTextField.text = item.memo
            tagTextField.text = item.tag
            storeConditionSegmentControl.selectedSegmentIndex = item.storeCondition
            //讀取照片
            let image = Item.loadImage(item)
            itemImageView.image = image
        }
    }
    //MARK: - 更新TabBarBtn
    func setTagToolBarBtn()->UIToolbar {
        let toolBar = UIToolbar()
        //不打的話按鈕會看不到，因為沒有被字撐出大小來
        toolBar.sizeToFit()
        //done Btn
        let doneBtn = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(tapTagDoneBtn))
        //Cancel Btn
        let cancelBtn = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(tapCancelBtn))
        //可以把space右邊的btn撐到最右邊
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolBar.setItems([cancelBtn,space,doneBtn], animated: true)
        return toolBar
    }
    
    func setDateToolBarBtn()->UIToolbar {
        let toolBar = UIToolbar()
        //不打的話按鈕會看不到，因為沒有被字撐出大小來
        toolBar.sizeToFit()
        //done Btn
        let doneBtn = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(tapDateDoneBtn))
        //Cancel Btn
        let cancelBtn = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(tapCancelBtn))
        //可以把space右邊的btn撐到最右邊
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolBar.setItems([cancelBtn,space,doneBtn], animated: true)
        return toolBar
    }
    
    //Done 按鍵設定
    @objc func tapTagDoneBtn(){
        tagTextField.text = selectedTagIndex == 0 ? "" : tags?[selectedTagIndex]
        tagTextField.resignFirstResponder()
   }
    
    @objc func tapDateDoneBtn(){
        expiryDateTextField.text = dateController.share.setDateFormate(datePicker.date)
        expiryDateTextField.resignFirstResponder()
   }
    
    @objc func tapCancelBtn(){
        expiryDateTextField.resignFirstResponder()
        tagTextField.resignFirstResponder()
   }
    
    func checkName(url:String){
        let filemanager = FileManager()
        if filemanager.fileExists(atPath: url){
            let controller = UIAlertController(title: "物品名已存在", message: "請取其他名字", preferredStyle: .alert)
            let action = UIAlertAction(title: "確定", style: .default)
            controller.addAction(action)
            present(controller, animated: true)
        }
    }
    
    //MARK: - Target Action
    //確認送出按鈕
    @IBAction func done(_ sender: UIBarButtonItem) {
        //以下這一大段也可以寫在prepare
        print(nameTextField.text!.isEmpty)
        print(numberTextField.text!.isEmpty)
        print(expiryDateTextField.text!.isEmpty)

        guard nameTextField.text!.isEmpty==false && numberTextField.text!.isEmpty==false && expiryDateTextField.text!.isEmpty==false else{
            let alert = UIAlertController(title: "資訊有誤", message: "名稱、數量、到期日要選擇", preferredStyle: .alert)
            let alertAction = UIAlertAction(title: "確定", style: .default)
            alert.addAction(alertAction)
            present(alert, animated: true)
            return
        }
        
        if isCellSelected == false{
            let filemanager = FileManager()
            let url = URL.documentsDirectory.appending(path: (nameTextField.text!)).path()
            guard !filemanager.fileExists(atPath: url.removingPercentEncoding!) else {
                let controller = UIAlertController(title: "物品名已存在", message: "請取其他名字", preferredStyle: .alert)
                let action = UIAlertAction(title: "確定", style: .default)
                controller.addAction(action)
                present(controller, animated: true)
                return
            }
        }
        
        
        
        let name = nameTextField.text!
        let number = Int(numberTextField.text!)!
        let expiryDate = datePicker.date
        let memo = !memoTextField.text!.isEmpty == true ? memoTextField.text : nil
        let tag = !tagTextField.text!.isEmpty == true ? tagTextField.text : nil
        let storeConditionIndex = storeConditionSegmentControl.selectedSegmentIndex
        item = Item(name: name, number: number, expiryDate: expiryDate, storeCondition: storeConditionIndex, memo: memo, tag: tag)
        //print("編輯頁item的名字：\(item?.name)")
        if let image, let item{
            Item.saveImage(item, image: image)
        }
        
        
        
        //執行segue回到上一頁
        performSegue(withIdentifier: "unwindToMain", sender: nil)
        
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
    }
    
    //按return退鍵盤
    @IBAction func returnKeyboard(_ sender: Any) {
    }
    //按空白退鍵盤
    @IBAction func tabScreen(_ sender: Any) {
        view.endEditing(true)
    }
    
    
    @IBAction func choosePhoto(_ sender: UIButton) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let takePhotoAction = UIAlertAction(title: "拍照", style: .default){_ in
            //如果沒有前置鏡頭，就return
            guard UIImagePickerController.isCameraDeviceAvailable(.rear) else {
                let alertController = UIAlertController(title: "相機鏡頭", message: "無偵測到相機鏡頭", preferredStyle: .alert)
                let alertAction = UIAlertAction(title: "確定", style: .default)
                alertController.addAction(alertAction)
                self.present(alertController, animated: true)
                return
            }
            let controller = UIImagePickerController()
            controller.delegate = self
            controller.sourceType = .camera
            self.present(controller, animated: true)

        }
        
        let fromLiberaryAction = UIAlertAction(title: "相簿", style: .default){_ in
            let controller = UIImagePickerController()
            controller.delegate = self
            controller.sourceType = .photoLibrary
            self.present(controller, animated: true)
            
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .default){_ in
            self.dismiss(animated: true)
        }
        
        alert.addAction(takePhotoAction)
        alert.addAction(fromLiberaryAction)
        alert.addAction(cancelAction)
        self.present(alert, animated: true)
    }
    
    

}
//MARK: - UIImagePickerControllerDelegate
extension EditViewController:UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    //自帶cancel按鈕
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let image = info[.originalImage] as! UIImage
        itemImageView.image = image
        self.image = image
        dismiss(animated: true)
    }
}



//MARK: - UITextFieldDelegate
extension EditViewController:UITextFieldDelegate{
    
    //這個func被點擊會呼叫，輸入字後還會再被呼叫一次
    func textFieldDidBeginEditing(_ textField: UITextField) {
        
        print("textFieldDidBeginEditing")
        
        //將元件座標相對位置轉成View
        let convertedPoint = textField.convert(textField.frame.origin, to: view)
        currentObjectButtonY = convertedPoint.y + textField.frame.height
        print("元件的位置：\(currentObjectButtonY)")
        //如果textField是下列的情況，則替換鍵盤內容
        if textField.tag == 3{
            textField.inputView = pickView
            textField.inputAccessoryView = setTagToolBarBtn()
        }else if textField.tag == 2{
            datePicker = dateController.share.createDatePicker()
            textField.inputView = datePicker
            textField.inputAccessoryView = setDateToolBarBtn()
        }else if textField.tag == 1{
            textField.keyboardType = .numberPad
        }
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
    
    
    
}
//MARK: - UIPickerViewDataSource & UIPickerViewDelegate
extension EditViewController:UIPickerViewDataSource{
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return tags?.count ?? 1
    }
}

extension EditViewController:UIPickerViewDelegate{
   
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return tags?[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedTagIndex = row
    }
}


