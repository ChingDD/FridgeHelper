//
//  EditViewController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/2.
//

import UIKit
import AVFoundation
import Combine

class EditViewController: UIViewController {

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var numberTextField: UITextField!
    @IBOutlet weak var expiryDateTextField: UITextField!
    @IBOutlet weak var memoTextField: UITextField!
    @IBOutlet weak var tagTextField: UITextField!
    @IBOutlet weak var itemImageView: UIImageView!
    @IBOutlet weak var storeConditionSegmentControl: UISegmentedControl!
    @IBOutlet weak var doneBtn: UIBarButtonItem!

    var editViewModel: EditViewModel!

    private var selectedTagIndex: Int = 0
    private var pickView = UIPickerView()
    private var datePicker = UIDatePicker()
    private var currentObjectButtonY = 0.0
    private var cancellables = Set<AnyCancellable>()

    // Expose the built item for unwindToMain
    var builtItem: Item?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Temporary guard: allow standalone launch without injection (new item mode)
        if editViewModel == nil {
            editViewModel = EditViewModel(availableTags: [])
        }

        setupKeyboardObservers()
        setupTextFieldDelegates()
        pickView.delegate = self
        populateUI()
        setupBindings()

        itemImageView.layer.borderWidth = 5
        itemImageView.layer.borderColor = UIColor(named: "Color")?.cgColor
        itemImageView.contentMode = .scaleAspectFill
    }

    // MARK: - Setup

    private func setupKeyboardObservers() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(showKeyboard), name: UIResponder.keyboardWillShowNotification, object: nil)
        nc.addObserver(self, selector: #selector(hideKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func setupTextFieldDelegates() {
        view.subviews[1].subviews.forEach {
            for aView in $0.subviews {
                if let textField = aView as? UITextField {
                    textField.delegate = self
                }
            }
        }
    }

    private func populateUI() {
        nameTextField.text = editViewModel.name
        numberTextField.text = editViewModel.quantity.isEmpty ? "" : editViewModel.quantity
        expiryDateTextField.text = editViewModel.isExpiryDateSet
            ? dateController.shared.setDateFormate(editViewModel.expiryDate)
            : ""
        memoTextField.text = editViewModel.memo
        tagTextField.text = editViewModel.selectedTag
        storeConditionSegmentControl.selectedSegmentIndex = editViewModel.storeConditionIndex
        if let image = editViewModel.selectedImage {
            itemImageView.image = image
        }
        // Pre-select correct tag row in picker
        if let tag = editViewModel.selectedTag,
           let index = editViewModel.availableTags.firstIndex(of: tag) {
            selectedTagIndex = index
        }
    }

    private func setupBindings() {
        editViewModel.$isFormValid
            .receive(on: RunLoop.main)
            .sink { [weak self] isValid in
                self?.doneBtn.isEnabled = isValid
            }
            .store(in: &cancellables)
    }

    // MARK: - Keyboard Handling

    @objc func showKeyboard(_ notification: Notification) {
        let keyboardFrame = notification.userInfo?[AnyHashable("UIKeyboardBoundsUserInfoKey")] as! CGRect
        let deviceMaxY = UIScreen.main.bounds.maxY
        let currentVisibleButtonY = deviceMaxY - keyboardFrame.height
        if currentObjectButtonY > currentVisibleButtonY {
            let offSetY = currentObjectButtonY - currentVisibleButtonY
            UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.2, delay: 0) {
                self.view.frame.origin.y = -offSetY
            }
        } else {
            view.frame.origin.y = 0
        }
    }

    @objc func hideKeyboard(_ notification: Notification) {
        UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.2, delay: 0) {
            self.view.frame.origin.y = 0
        }
    }

    // MARK: - Toolbar Buttons

    func setTagToolBarBtn() -> UIToolbar {
        let toolBar = UIToolbar()
        toolBar.sizeToFit()
        let doneBtn = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(tapTagDoneBtn))
        let cancelBtn = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(tapCancelBtn))
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolBar.setItems([cancelBtn, space, doneBtn], animated: true)
        return toolBar
    }

    func setDateToolBarBtn() -> UIToolbar {
        let toolBar = UIToolbar()
        toolBar.sizeToFit()
        let doneBtn = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(tapDateDoneBtn))
        let cancelBtn = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(tapCancelBtn))
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolBar.setItems([cancelBtn, space, doneBtn], animated: true)
        return toolBar
    }

    @objc func tapTagDoneBtn() {
        let tag = selectedTagIndex == 0 ? nil : editViewModel.availableTags[selectedTagIndex]
        editViewModel.selectedTag = tag
        tagTextField.text = tag
        tagTextField.resignFirstResponder()
    }

    @objc func tapDateDoneBtn() {
        editViewModel.expiryDate = datePicker.date
        editViewModel.isExpiryDateSet = true
        expiryDateTextField.text = dateController.shared.setDateFormate(datePicker.date)
        expiryDateTextField.resignFirstResponder()
    }

    @objc func tapCancelBtn() {
        expiryDateTextField.resignFirstResponder()
        tagTextField.resignFirstResponder()
    }

    private func checkCameraAuthorization(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        case .authorized:
            completion(true)
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    // MARK: - Target Actions

    @IBAction func done(_ sender: UIBarButtonItem) {
        // Sync text fields to editViewModel before building
        editViewModel.name = nameTextField.text ?? ""
        editViewModel.quantity = numberTextField.text ?? ""
        editViewModel.memo = memoTextField.text ?? ""
        editViewModel.storeConditionIndex = storeConditionSegmentControl.selectedSegmentIndex
        editViewModel.selectedImage = itemImageView.image

        guard let item = editViewModel.buildItem() else {
            let alert = UIAlertController(title: "資訊有誤", message: "名稱、數量要填寫", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "確定", style: .default))
            present(alert, animated: true)
            return
        }

        builtItem = item
        performSegue(withIdentifier: "unwindToMain", sender: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {}

    @IBAction func returnKeyboard(_ sender: Any) {}

    @IBAction func tabScreen(_ sender: Any) {
        view.endEditing(true)
    }

    @IBAction func choosePhoto(_ sender: UIButton) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.popoverPresentationController?.sourceView = sender

        let takePhotoAction = UIAlertAction(title: "拍照", style: .default) { _ in
            guard UIImagePickerController.isCameraDeviceAvailable(.rear) else {
                let alertController = UIAlertController(title: "相機鏡頭", message: "無偵測到相機鏡頭", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "確定", style: .default))
                self.present(alertController, animated: true)
                return
            }
            self.checkCameraAuthorization { isAuthorized in
                guard isAuthorized else {
                    let alertController = UIAlertController(title: "相機權限", message: "請在設置中開啟相機權限", preferredStyle: .alert)
                    let settingsAction = UIAlertAction(title: "設置", style: .default) { _ in
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    alertController.addAction(settingsAction)
                    alertController.addAction(UIAlertAction(title: "取消", style: .default) { _ in self.dismiss(animated: true) })
                    self.present(alertController, animated: true)
                    return
                }
                let controller = UIImagePickerController()
                controller.delegate = self
                controller.sourceType = .camera
                self.present(controller, animated: true)
            }
        }

        let fromLibraryAction = UIAlertAction(title: "相簿", style: .default) { _ in
            let controller = UIImagePickerController()
            controller.delegate = self
            controller.sourceType = .photoLibrary
            self.present(controller, animated: true)
        }

        let cancelAction = UIAlertAction(title: "取消", style: .cancel) { _ in
            self.dismiss(animated: true)
        }

        alert.addAction(takePhotoAction)
        alert.addAction(fromLibraryAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }
}

// MARK: - UIImagePickerControllerDelegate
extension EditViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = info[.originalImage] as! UIImage
        itemImageView.image = image
        editViewModel.selectedImage = image
        dismiss(animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension EditViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        printInfo("textFieldDidBeginEditing")
        let convertedPoint = textField.convert(textField.frame.origin, to: view)
        currentObjectButtonY = convertedPoint.y + textField.frame.height

        if textField.tag == 3 {
            textField.inputView = pickView
            textField.inputAccessoryView = setTagToolBarBtn()
        } else if textField.tag == 2 {
            datePicker = dateController.shared.createDatePicker()
            datePicker.date = editViewModel.expiryDate
            datePicker.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 400)
            textField.inputView = datePicker
            textField.inputAccessoryView = setDateToolBarBtn()
        } else if textField.tag == 1 {
            textField.keyboardType = .numberPad
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
}

// MARK: - UIPickerViewDataSource & UIPickerViewDelegate
extension EditViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return editViewModel.availableTags.count
    }
}

extension EditViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return editViewModel.availableTags[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedTagIndex = row
    }
}
