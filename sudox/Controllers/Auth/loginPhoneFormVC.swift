//
//  loginPhoneFormVC.swift
//  Sudox-ios
//
//  Created by Иван Лобанов on 12/02/2020.
//  Copyright © 2020 Sudox. All rights reserved.
//

import Foundation
import UIKit
import EasyPeasy
import PhoneNumberKit
import Starscream
import SwiftKeychainWrapper
import MessagePacker

class loginPhoneFormVC: UIViewController {
    
    lazy var sk = Network.shared
    
    var descriptionLabel = UILabel()
    var phoneNumberTextField = PhoneNumberTextField()
    let imageIcon = UIImageView(image: UIImage(systemName: "phone"))
    let debagButton = NativeButton()
    override func viewDidLoad() {
        
        super.viewDidLoad()
        hideKeyboardWhenTappedAround()
        addView()
        addDescriptionLabel()
        addImageIcon()
        addPhoneNumberTextField()
        addDebugButton()
        // подписываемся на делегат
        sk.websocket?.delegate = self
        
    }
    private func addDebugButton() {
        if IsDebagDevice == false {return}
        let button = debagButton
        view.addSubview(button)
        button.easy.layout([Top(64).to(phoneNumberTextField), Left(24).to(view.safeAreaLayoutGuide, .left), Right(24).to(view.safeAreaLayoutGuide, .right), Height(36)])
        button.setTitle("Login")
        button.addTarget(self, action: #selector(loginButtonPressed), for: .touchUpInside)
    }
    @objc func loginButtonPressed() {
        UserDefaults.standard.set(true, forKey: "LOGGED_IN")
        UIApplication.shared.windows.first?.rootViewController = SplashViewController()
        self.navigationController?.popToRootViewController(animated: true)
    }
    private func addView() {
        self.view.backgroundColor = UIColor.systemBackground
        self.title = loginPhoneFormTitle
        
        self.navigationController?.view.tintColor = .globalGreen
        
        self.navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: nextTitle, style: .plain, target: self, action: #selector(rightNavBarItemTapped))
        navigationItem.rightBarButtonItem?.isEnabled = false
        navigationItem.rightBarButtonItem?.tintColor = getColor().labelColor
        
    }
    func addDescriptionLabel() {
        self.view.addSubview(descriptionLabel)
        descriptionLabel.text = loginPhoneFormDescription
        descriptionLabel.easy.layout([Right(16),Top(15).to(view.safeAreaLayoutGuide, .top),Height(44)])
        descriptionLabel.setUpDescriptionLabel()
        descriptionLabel.isEnabled = false
    }
    func addImageIcon() {
        self.view.addSubview(imageIcon)
        //imageIcon.tintColor = .black
        imageIcon.easy.layout([Left(16).to(view.safeAreaLayoutGuide, .left),Right(16).to(descriptionLabel),Top(25).to(view.safeAreaLayoutGuide, .top),Height(24), Width(24)])
        
    }
    func addPhoneNumberTextField() {
        view.addSubview(phoneNumberTextField)
        
        self.phoneNumberTextField.becomeFirstResponder()
        self.phoneNumberTextField.withPrefix = true
        self.phoneNumberTextField.withFlag = true
        self.phoneNumberTextField.withExamplePlaceholder = true
        self.phoneNumberTextField.easy.layout([Left(16),Right(16),Top(40).to(descriptionLabel), Height(50)])
        // регулирование расстояние кнопки с регионом от края
        self.phoneNumberTextField.flagButton.contentEdgeInsets.left = 20
        // макс длина номера
        self.phoneNumberTextField.maxDigits = 15
        // phone auto-fill
        self.phoneNumberTextField.textContentType = .telephoneNumber
        self.phoneNumberTextField.autocorrectionType = .yes
        
        self.phoneNumberTextField.withDefaultPickerUI = true
        
        // закругление родительского view у поля ввода
        // добавление серых рамок
        self.phoneNumberTextField.layer.cornerRadius = 5
        self.phoneNumberTextField.clipsToBounds = true
        self.phoneNumberTextField.layer.borderColor = UIColor.grayBorder.cgColor
        self.phoneNumberTextField.layer.borderWidth = 1.0
        self.phoneNumberTextField.addTarget(self, action: #selector(phoneNumberCorrection), for: .editingChanged)
    }
    
    /// функция, срабатывающая при нажатии кнопки далее
    @objc func rightNavBarItemTapped() {
        
        // если телефон введен правильно
        if (phoneNumberTextField.isValidNumber)
        {
            let rawNumber = self.phoneNumberTextField.text!.filter { (char) -> Bool in return char.isNumber }
            
            //MsgPack упаковка для последующей отправк data (массив байтов) на сервер
            let dict = createMethod(method_name: "auth.create", data: createData(user_phone: rawNumber))
            let data = try! MessagePackEncoder().encode(dict)

            // отправляем телефон на сервер.
            sk.send(data)

        }
        else{ print("Error in telephone")}
    }
    
    func performActionAfterSuccessEvent(ansObj: createAnswer) -> Void
    {
        if (ansObj.data!.user_exists) // пользователь по этому телефону зарегистрирован
        {
            // пробрасываем на авторизацию
        }
        else //пользователя не существует. Регистрируем
        {
            // сохраняем auth_id
            sk.auth_id = ansObj.data!.auth_id
            
            // пробрасываем дальше по регистрации
            let vc = smsPhoneFormVC()
            vc.modalPresentationStyle = .overFullScreen
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    // подкрашивание и активация кнопки 'next' в nav bar'e при корректном вводе телефона
    @objc func phoneNumberCorrection() {
        if (phoneNumberTextField.isValidNumber) {
            navigationItem.rightBarButtonItem?.tintColor = .globalGreen
            navigationItem.rightBarButtonItem?.isEnabled = true
        }
        else {
            navigationItem.rightBarButtonItem?.isEnabled = false
        }
        
    }
    
    
    public func RestoreSession()
    {
        // must check if there is any need to restore session
        //getting 'retrievedToken' - registration token
        if let retrievedToken: String = KeychainWrapper.standard.string(forKey: "registrationToken")
        {
            print("registrationToken найдено в базе")
            if let retrievedTokenDate: NSDate = KeychainWrapper.standard.object(forKey: "registrationTokenExpiryDate") as? NSDate
            {
                print("registrationTokenExpiryDate найдено в базе")
                let now =  NSDate.now as NSDate;
                
                if (now.isExpired(dateToCompare: (retrievedTokenDate), expirationTime: TimeInterval(5.0 * 60.0)))
                {
                    print("ключ expired. невозможно восстановить сессию")
                    // expired, should have deleted key from keychain
                    
                }
                else
                {
                    // not expired, can reactivate session
                    /*
                     if (sk.restoreRegSession(retrievedToken))
                     {
                     print("READY TO LOAD VIEW AFTER RESTORATION")
                     }
                     else
                     {
                     print("restoration failed")
                     }
                     */
                }
            }
        }
    }
}

extension loginPhoneFormVC: WebSocketDelegate{
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        print(event)
        switch event {
        case .connected(let headers):
            sk.isConnected = true
            print("websocket is connected: \(headers)")
            //RestoreSession()
            
        case .disconnected(let reason, let code):
            sk.isConnected = false
            print("websocket is disconnected: \(reason) with code: \(code)")
        case .text(let string):
            print("Received text: \(string)")
        case .binary(let data):
            print("Received data: \([UInt8](data))")
            do {
                let decoded = try MessagePackDecoder().decode(createAnswer.self, from: data)
                
                switch decoded.method_result {
                case 0: // OK
                    performActionAfterSuccessEvent(ansObj: decoded)
                    break
                case 1: // SERVICE_UNAVAILABLE
                    handleCreateMethodError(1, message: "SERVICE_UNAVAILABLE")
                    break
                case 2: // ACCESS_DENIED
                    handleCreateMethodError(2, message: "ACCESS_DENIED")
                    break
                case 3: // FORMAT_INVALID
                    handleCreateMethodError(3, message: "FORMAT_INVALID")
                    break
                case 102: // AUTH_EXISTS
                    handleCreateMethodError(102, message: "AUTH_EXISTS")
                    break
                case 107: // USER_PHONE_BANNED
                    handleCreateMethodError(107, message: "USER_PHONE_BANNED")
                    break
                default: // UNEXPECTED ERROR
                    handleCreateMethodError(-1, message: "UNEXPECTED_ERROR")
                    break
                }
            }
            catch {
                // error. невозможно прочитать ответ на валидность телефона телефон
            }
        case .ping(_):
            break
        case .pong(_):
            break
        case .viablityChanged(_):
            break
        case .reconnectSuggested(_):
            break
        case .cancelled:
            sk.isConnected = false
        case .error(let error):
            sk.isConnected = false
            handleError(error)
            
        }
    }
    
    func handleError(_ error: Error?) {
        if let e = error as? WSError {
            print("websocket[Login_PHONE_FORM] encountered an error: \(e.message)")
        } else if let e = error {
            print("websocket[Login_PHONE_FORM] encountered an error: \(e.localizedDescription)")
        } else {
            print("websocket[Login_PHONE_FORM] encountered an error")
        }
    }
    
    func handleCreateMethodError(_ error: Int, message: String)
    {
        
        let alert = UIAlertController(title: "Error: " + String(error), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion:{
           alert.view.superview?.isUserInteractionEnabled = true
           alert.view.superview?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dismissOnTapOutside)))
        })
    }
    
    @objc func dismissOnTapOutside(){
       self.dismiss(animated: true, completion: nil)
    }
}
