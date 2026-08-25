//
//  ItemFormViewController.swift
//  FridgeHelper
//
//  新增／編輯食材表單（取代舊 EditViewController）
//

import UIKit
import Combine
import AVFoundation

final class ItemFormViewController: UIViewController {

    /// 回傳被容量擋下的原因；nil 代表已受理，表單才會關閉
    var onSave: ((Item) -> ItemCapacityRejection?)?

    private let editViewModel: EditViewModel
    private let locations: StringListViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI

    private let photoCard = CardView(background: Theme.surface)
    private let photoImageView = UIImageView()
    private let photoPlaceholder = UIStackView()
    private let nameTextField = UITextField()
    private let quantityStepper = QuantityStepper()
    private lazy var unitChips = ChipGroupControl(options: EditViewModel.units, selected: editViewModel.unit)
    private let dateField = MenuFieldControl(value: "選擇到期日")
    private let datePicker = UIDatePicker()
    private let locationField = MenuFieldControl(value: "")
    private let tagField = MenuFieldControl(value: "未選擇")
    private let memoTextView = UITextView()
    private let saveButton = UIButton(configuration: .filled())

    init(editViewModel: EditViewModel, locations: StringListViewModel) {
        self.editViewModel = editViewModel
        self.locations = locations
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        title = editViewModel.isEditing ? "編輯食材" : "新增食材"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "取消", primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })

        setupForm()
        populate()
        setupBindings()
    }

    // MARK: - Setup

    private func setupForm() {
        // 照片卡
        photoImageView.contentMode = .scaleAspectFill
        photoImageView.translatesAutoresizingMaskIntoConstraints = false

        let cameraIcon = UIImageView(image: UIImage(systemName: "camera.fill"))
        cameraIcon.tintColor = .white
        cameraIcon.contentMode = .center
        cameraIcon.backgroundColor = Theme.primary
        cameraIcon.layer.cornerRadius = 24
        cameraIcon.clipsToBounds = true
        cameraIcon.translatesAutoresizingMaskIntoConstraints = false
        cameraIcon.widthAnchor.constraint(equalToConstant: 48).isActive = true
        cameraIcon.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let photoHint = UILabel()
        photoHint.text = "新增食材照片"
        photoHint.font = Theme.font(15, .bold)
        photoHint.textColor = Theme.textPrimary

        photoPlaceholder.axis = .vertical
        photoPlaceholder.alignment = .center
        photoPlaceholder.spacing = 10
        photoPlaceholder.addArrangedSubview(cameraIcon)
        photoPlaceholder.addArrangedSubview(photoHint)
        photoPlaceholder.translatesAutoresizingMaskIntoConstraints = false

        photoCard.contentView.addSubview(photoImageView)
        photoCard.contentView.addSubview(photoPlaceholder)
        photoCard.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(photoTapped)))

        // 名稱
        nameTextField.placeholder = "例如：有機菠菜"
        nameTextField.font = Theme.font(16)
        nameTextField.backgroundColor = Theme.surface
        nameTextField.layer.cornerRadius = Theme.cornerButton
        nameTextField.setLeftPadding(14)
        nameTextField.heightAnchor.constraint(equalToConstant: 48).isActive = true
        nameTextField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)

        // 數量與單位
        quantityStepper.minimumValue = 1
        quantityStepper.onChange = { [weak self] value in self?.editViewModel.quantity = value }
        unitChips.onSelect = { [weak self] unit in self?.editViewModel.unit = unit }

        // 到期日：點欄位展開 inline 日曆
        dateField.showsMenuAsPrimaryAction = false
        dateField.addTarget(self, action: #selector(dateFieldTapped), for: .touchUpInside)
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.locale = Locale(identifier: "zh-TW")
        datePicker.minimumDate = Date(timeIntervalSinceNow: -2592000)
        datePicker.isHidden = true
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)

        // 儲存位置
        locationField.menu = buildLocationMenu()

        // 標籤
        tagField.menu = buildTagMenu()

        // 備註
        memoTextView.font = Theme.font(15)
        memoTextView.backgroundColor = Theme.surface
        memoTextView.layer.cornerRadius = Theme.cornerButton
        memoTextView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        memoTextView.heightAnchor.constraint(equalToConstant: 100).isActive = true

        let quantityRow = UIStackView(arrangedSubviews: [
            FormFieldView(title: "數量", field: quantityStepper),
            FormFieldView(title: "單位", field: unitChips),
        ])
        quantityRow.axis = .vertical
        quantityRow.spacing = Theme.spacing

        let dateStack = UIStackView(arrangedSubviews: [dateField, datePicker])
        dateStack.axis = .vertical
        dateStack.spacing = 8

        let formStack = UIStackView(arrangedSubviews: [
            photoCard,
            FormFieldView(title: "名稱", field: nameTextField),
            quantityRow,
            FormFieldView(title: "到期日", field: dateStack),
            FormFieldView(title: "儲存位置", field: locationField),
            FormFieldView(title: "標籤", field: tagField),
            FormFieldView(title: "備註", field: memoTextView),
        ])
        formStack.axis = .vertical
        formStack.spacing = Theme.spacing + 4
        formStack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(formStack)
        view.addSubview(scrollView)

        // 底部固定按鈕列
        var cancelConfig = UIButton.Configuration.filled()
        cancelConfig.baseBackgroundColor = Theme.surface
        cancelConfig.baseForegroundColor = Theme.textPrimary
        cancelConfig.attributedTitle = AttributedString("取消", attributes: AttributeContainer([.font: Theme.font(17, .bold)]))
        cancelConfig.background.cornerRadius = Theme.cornerButton
        cancelConfig.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        let cancelButton = UIButton(configuration: cancelConfig)
        cancelButton.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)

        saveButton.configuration?.baseBackgroundColor = Theme.primary
        saveButton.configuration?.baseForegroundColor = .white
        saveButton.configuration?.attributedTitle = AttributedString("儲存", attributes: AttributeContainer([.font: Theme.font(17, .bold)]))
        saveButton.configuration?.background.cornerRadius = Theme.cornerButton
        saveButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        let bottomBar = UIStackView(arrangedSubviews: [cancelButton, saveButton])
        bottomBar.spacing = 12
        bottomBar.distribution = .fillEqually
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -8),

            formStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Theme.spacing),
            formStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Theme.spacing),
            formStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Theme.spacing),
            formStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Theme.spacing),
            formStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -Theme.spacing * 2),

            photoCard.heightAnchor.constraint(equalToConstant: 160),
            photoImageView.topAnchor.constraint(equalTo: photoCard.contentView.topAnchor),
            photoImageView.bottomAnchor.constraint(equalTo: photoCard.contentView.bottomAnchor),
            photoImageView.leadingAnchor.constraint(equalTo: photoCard.contentView.leadingAnchor),
            photoImageView.trailingAnchor.constraint(equalTo: photoCard.contentView.trailingAnchor),
            photoPlaceholder.centerXAnchor.constraint(equalTo: photoCard.contentView.centerXAnchor),
            photoPlaceholder.centerYAnchor.constraint(equalTo: photoCard.contentView.centerYAnchor),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.spacing),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.spacing),
            bottomBar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -12),
        ])
    }

    private func populate() {
        nameTextField.text = editViewModel.name
        quantityStepper.value = editViewModel.quantity
        quantityStepper.unit = ""
        unitChips.selectedOption = editViewModel.unit
        if editViewModel.isExpiryDateSet {
            dateField.setValue(dateController.shared.setDateFormate(editViewModel.expiryDate))
            datePicker.date = editViewModel.expiryDate
        }
        locationField.setValue(editViewModel.storeLocation)
        tagField.setValue(editViewModel.selectedTag ?? "未選擇")
        memoTextView.text = editViewModel.memo
        if let image = editViewModel.selectedImage {
            photoImageView.image = image
            photoPlaceholder.isHidden = true
        }
    }

    private func setupBindings() {
        editViewModel.$isFormValid
            .receive(on: RunLoop.main)
            .sink { [weak self] isValid in self?.saveButton.isEnabled = isValid }
            .store(in: &cancellables)
    }

    // MARK: - Menus

    private func buildLocationMenu() -> UIMenu {
        // 編輯中 item 的位置若已被刪除、不在清單內，仍照常顯示於欄位上
        let actions = locations.values.map { location in
            UIAction(title: location, state: editViewModel.storeLocation == location ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.editViewModel.storeLocation = location
                self.locationField.setValue(location)
                self.locationField.menu = self.buildLocationMenu()
            }
        }
        return UIMenu(options: .singleSelection, children: actions)
    }

    private func buildTagMenu() -> UIMenu {
        let actions = editViewModel.availableTags.enumerated().map { index, tag in
            let isSelected = index == 0 ? editViewModel.selectedTag == nil : editViewModel.selectedTag == tag
            return UIAction(title: tag, state: isSelected ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.editViewModel.selectedTag = index == 0 ? nil : tag
                self.tagField.setValue(tag)
                self.tagField.menu = self.buildTagMenu()
            }
        }
        return UIMenu(options: .singleSelection, children: actions)
    }

    // MARK: - Actions

    @objc private func nameChanged() {
        editViewModel.name = nameTextField.text ?? ""
    }

    @objc private func dateFieldTapped() {
        view.endEditing(true)
        // 打開日曆即代表確認日期（預設今天），再選其他日期會覆寫
        if !editViewModel.isExpiryDateSet {
            editViewModel.expiryDate = datePicker.date
            editViewModel.isExpiryDateSet = true
            dateField.setValue(dateController.shared.setDateFormate(datePicker.date))
        }
        UIView.animate(withDuration: 0.25) {
            self.datePicker.isHidden.toggle()
        }
    }

    @objc private func dateChanged() {
        editViewModel.expiryDate = datePicker.date
        editViewModel.isExpiryDateSet = true
        dateField.setValue(dateController.shared.setDateFormate(datePicker.date))
    }

    @objc private func saveTapped() {
        editViewModel.name = nameTextField.text ?? ""
        editViewModel.memo = memoTextView.text ?? ""
        editViewModel.selectedImage = photoPlaceholder.isHidden ? photoImageView.image : nil

        guard let item = editViewModel.buildItem() else {
            let alert = UIAlertController(title: "資訊有誤", message: "名稱、到期日要填寫", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "確定", style: .default))
            present(alert, animated: true)
            return
        }
        // 表單開著的期間其他裝置可能已把冰箱填滿，儲存前再檢查一次
        if let rejection = onSave.flatMap({ $0(item) }) {
            // 不關閉表單，使用者刪掉食材後可以直接再存一次
            let alert = UIAlertController(title: rejection.alertTitle, message: rejection.alertMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "確定", style: .default))
            present(alert, animated: true)
            return
        }
        dismiss(animated: true)
    }

    // MARK: - Photo

    @objc private func photoTapped() {
        view.endEditing(true)
        let sheet = UIAlertController(title: "選擇照片", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "拍照", style: .default) { [weak self] _ in
            self?.checkCameraAuthorization { granted in
                guard granted else { return }
                self?.presentImagePicker(source: .camera)
            }
        })
        sheet.addAction(UIAlertAction(title: "相簿", style: .default) { [weak self] _ in
            self?.presentImagePicker(source: .photoLibrary)
        })
        if photoPlaceholder.isHidden {
            sheet.addAction(UIAlertAction(title: "移除照片", style: .destructive) { [weak self] _ in
                self?.photoImageView.image = nil
                self?.photoPlaceholder.isHidden = false
                self?.editViewModel.selectedImage = nil
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(sheet, animated: true)
    }

    private func presentImagePicker(source: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(source) else { return }
        let picker = UIImagePickerController()
        picker.sourceType = source
        picker.delegate = self
        present(picker, animated: true)
    }

    private func checkCameraAuthorization(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        case .authorized:
            completion(true)
        default:
            completion(false)
        }
    }
}

// MARK: - UIImagePickerControllerDelegate

extension ItemFormViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        photoImageView.image = image
        photoPlaceholder.isHidden = true
        editViewModel.selectedImage = image
    }
}

private extension UITextField {
    func setLeftPadding(_ padding: CGFloat) {
        leftView = UIView(frame: CGRect(x: 0, y: 0, width: padding, height: 1))
        leftViewMode = .always
    }
}
