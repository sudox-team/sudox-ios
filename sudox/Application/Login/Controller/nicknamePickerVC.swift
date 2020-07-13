//
//  nicknamePickerVC.swift
//  Sudox-ios
//
//  Created by Никита Казанцев on 14.02.2020.
//  Copyright © 2020 Sudox. All rights reserved.
//

import Foundation
import UIKit
import EasyPeasy
import Starscream
import MessagePacker
import Sodium
import SwiftKeychainWrapper

class nicknamePickerVC: UIViewController {
    
    // объект глобального сокета
    lazy var sk = Network.shared
    
    var descriptionLabel = UILabel()
    var nicknameTextField = UITextField()
    var nameTextField = UITextField()
    let imageIcon = UIImageView(image: UIImage(systemName: "person.crop.circle"))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addView()
        addDescriptionLabel()
        addImageIcon()
        addNicknameTextField()
        addNameTextField()
        // подписываемся уже на новый делегат
        sk.websocket?.delegate = self 
    }
    
    func addView () {
        self.view.backgroundColor = UIColor.systemBackground
        self.title = nicknamePickerTitle
        self.navigationItem.hidesBackButton = true
        self.navigationController?.navigationBar.prefersLargeTitles = true
        
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: nextTitle, style: .plain, target: self, action: #selector(rightNavBarItemTapped))
        //       navigationItem.rightBarButtonItem?.isEnabled = false
        navigationItem.rightBarButtonItem?.tintColor = getColor().labelColor
        
    }
    
    /// добавляет label с поясняющим описанием на экран
    /// ```
    /// addDescriptionLabel()
    /// ```
    /// - Returns: Void
    func addDescriptionLabel () {
        
        self.view.addSubview(descriptionLabel)
        descriptionLabel.text = nicknamePickerDescription
        descriptionLabel.easy.layout([Right(16),Top(15).to(view.safeAreaLayoutGuide, .top),Height(44)])
        descriptionLabel.setUpDescriptionLabel()
        descriptionLabel.isEnabled = false
        
    }
    
    /// добавляет контекстную мини-иконку
    /// ```
    /// addImageIcon()
    /// ```
    /// - Returns: Void
    func addImageIcon () {
        self.view.addSubview(imageIcon)
        //imageIcon.tintColor = .black
        imageIcon.easy.layout([Left(15).to(view.safeAreaLayoutGuide, .left),Right(16).to(descriptionLabel),Top(25).to(view.safeAreaLayoutGuide, .top),Height(24), Width(24)])
        
    }
    
    /// добавляет форму ввода никнейма пользователя
    /// ```
    /// addNicknameTextField()
    /// ```
    /// - Warning: использует nicknameTextField. Нет проверок
    /// - Returns: Void
    func addNicknameTextField () {
        view.addSubview(nicknameTextField)
        
        self.nicknameTextField.becomeFirstResponder()
        
        self.nicknameTextField.easy.layout([Left(16),Right(16),Top(40).to(descriptionLabel), Height(50)])
        self.nicknameTextField.setLeftPaddingPoints(20)
        self.nicknameTextField.setRightPaddingPoints(20)
        
        self.nicknameTextField.textContentType = .nickname
        self.nicknameTextField.autocorrectionType = .yes
        self.nicknameTextField.placeholder = "Nickname"
        // закругление родительского view у поля ввода
        // добавление серых рамок
        
        self.nicknameTextField.layer.cornerRadius = 5
        self.nicknameTextField.clipsToBounds = true
        self.nicknameTextField.layer.borderColor = UIColor.grayBorder.cgColor
        self.nicknameTextField.layer.borderWidth = 1.0
        
        //self.nicknameTextField.addTarget(self, action: #selector(CheckAvailability), for: .editingDidEnd)
    }
    
    /// добавляет форму ввода имени пользователя
    /// ```
    /// addNameTextField()
    /// ```
    /// - Warning: использует nicknameTextField. Нет проверок
    /// - Returns: Void
    func addNameTextField () {
        view.addSubview(nameTextField)
        
        self.nameTextField.becomeFirstResponder()
        
        self.nameTextField.easy.layout([Left(16),Right(16),Top(16).to(nicknameTextField), Height(50)])
        self.nameTextField.setLeftPaddingPoints(20)
        self.nameTextField.setRightPaddingPoints(20)
        
        self.nameTextField.textContentType = .nickname
        self.nameTextField.autocorrectionType = .yes
        self.nameTextField.placeholder = "Name & surname"
        // закругление родительского view у поля ввода
        // добавление серых рамок
        self.nameTextField.layer.cornerRadius = 5
        self.nameTextField.clipsToBounds = true
        self.nameTextField.layer.borderColor = UIColor.grayBorder.cgColor
        self.nameTextField.layer.borderWidth = 1.0
        
        //self.nameTextField.addTarget(self, action: #selector(CheckAvailability), for: .editingDidEnd)
    }
    
    

    /// При нажатии на кнопку верхнего бара отправляем никнейм и прочее на сервер
    ///
    /// ```
    /// rightNavBarItemTapped()
    /// ```
    ///
    /// - Warning: user_key - массив рандомных байтов длины 32 (crypto_aead_xchacha20poly1305_ietf_KEYBYTES) используя. Требуется сохранить его в локальную базу данных.
    /// - Warning: user_key_hash - хэш user_key по BLAKE2b
    /// - Warning: user_name - ^([A-zА-я]{1,20}\s?){2}$
    /// - Warning: user_nickname - ^[0-9A-z.:_\-()]{1,30}$
    /// 
    /// ```
    /// UIBarButtonItem(title: nextTitle, style: .plain, target: self, action: #selector(rightNavBarItemTapped))
    /// ```
    /// - Returns: Void
    @objc func rightNavBarItemTapped(){
        
        if ((nicknameTextField.text ?? "").matches("^[0-9A-z.:_\\-()]{1,30}$") && (nameTextField.text ?? "").matches("^([A-zА-я]{1,20}\\s?){2}$")) {
            // массив рандомных байтов длины 32. Требуется сохранить его в локальную базу данных.
        let userKey = Sodium().secretBox.key() //.crypto_aead_xchacha20poly1305_ietf_KEYBYTES
        
        // сохраняем hex представление ключа в бд
        KeychainWrapper.standard.set(Sodium().utils.bin2hex(userKey)!, forKey: "userKey")
        
        //хэш user_key по BLAKE2b
        let secretKeyHash = Sodium().genericHash.hash(message: userKey)!
        let data_key = Data(secretKeyHash)

        let secretkeyutf = data_key.hexEncodedString()
        
        let dict = signUpMethod(method_name: "auth.signUp", data: signUpData(auth_id: sk.auth_id, user_name:nameTextField.text ?? "", user_nickname: nicknameTextField.text ?? "", user_key_hash: secretkeyutf))
        
        
        let data = try! MessagePackEncoder().encode(dict)
        
        sk.send(data)
        }
        else
        {
            showAlertMessage(errorCode: 3)
        }
    }
    
    
    /// При положительном ответе сервера вызываем эту функцию
    ///
    /// ```
    /// performActionAfterSuccessEvent()
    /// ```
    ///
    /// - Warning: на вход принимает signUpAnswer и не использует его
    ///
    /// ```
    /// performActionAfterSuccessEvent(ansObj: decoded)
    /// ```
    /// - Returns: Void
    func performActionAfterSuccessEvent(data: signUpAnswer) -> Void {
        
        UserDefaults.standard.set(true, forKey: "LOGGED_IN")
        
        UIApplication.shared.windows.first?.rootViewController = SplashViewController()
        self.navigationController?.popToRootViewController(animated: true)
        
    }
    
    @objc func CheckAvailability(){
        //
    }
    
}

extension nicknamePickerVC: WebSocketDelegate{
    
    /// Функция, срабатывающая на event ответа с сервера на смс код подтверждения
    ///
    /// - 0: OK
    /// - 1: SERVICE_UNAVAILABLE
    /// - 2: ACCESS_DENIED
    /// - 3: FORMAT_INVALID
    /// - 101: AUTH_NOT_FOUND
    /// - 104: AUTH_TYPE_INVALID
    /// - 105: AUTH_CODE_INVALID
    /// - default: UNEXPECTED_ERROR
    /// - Warning: В теории может сработать на рандомный ответ. Необходима проверка на правильность полученного. Сейчас обычный do catch
    ///
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        print(event)
        switch event {
        case .connected(let headers):
            
            print("websocket3 is connected: \(headers)")
        case .disconnected(let reason, let code):
            print("websocket3 is disconnected: \(reason) with code: \(code)")
        case .text(let string):
            print("Received3 text: \(string)")
        case .binary(let data):
            print("Received SMSFORM data: \([UInt8](data))")
            do {
                let decoded = try MessagePackDecoder().decode(signUpAnswer.self, from: data)
                print(decoded)
                
                switch decoded.method_result {
                case 0: // OK
                    performActionAfterSuccessEvent(data: decoded)
                    break
                case 1: // SERVICE_UNAVAILABLE
                    showAlertMessage(errorCode: 1)
                    break
                case 2: // ACCESS_DENIED
                    showAlertMessage(errorCode: 2)
                    break
                case 3: // FORMAT_INVALID
                    showAlertMessage(errorCode: 3)
                    break
                case 101: // AUTH_NOT_FOUND
                    showAlertMessage(errorCode: 101)
                    break
                case 104: // AUTH_TYPE_INVALID
                    showAlertMessage(errorCode: 104)
                    break
                case 105: // AUTH_CODE_INVALID
                    showAlertMessage(errorCode: 105)
                    break
                default: // UNEXPECTED ERROR
                    showAlertMessage(errorCode: decoded.method_result)
                    break
                }
            }
            catch {}
        case .ping(_):
            break
        case .pong(_):
            break
        case .viablityChanged(_):
            break
        case .reconnectSuggested(_):
            break
        case .cancelled:
            break
        case .error(let error):
            handleError(error)
        }
    }
    
    /// Функция, пишущая ошибки в консоль на запрос-ответы с сервером
    func handleError(_ error: Error?) {
        if let e = error as? WSError {
            print("websocket[NICKNAME_PICKER_VC] encountered an error: \(e.message)")
        } else if let e = error {
            print("websocket[NICKNAME_PICKER_VC] encountered an error: \(e.localizedDescription)")
        } else {
            print("websocket[NICKNAME_PICKER_VC] encountered an error")
        }
    }
    

}