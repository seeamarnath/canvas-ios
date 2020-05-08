//
// This file is part of Canvas.
// Copyright (C) 2020-present  Instructure, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import UIKit
import Core

class CreateAccountViewController: UIViewController, ErrorViewController {
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var name: CreateAccountRow!
    @IBOutlet weak var email: CreateAccountRow!
    @IBOutlet weak var password: CreateAccountRow!
    @IBOutlet weak var createAccountButton: DynamicButton!
    @IBOutlet weak var termsAndConditionsLabel: DynamicLabel!
    @IBOutlet weak var alreadyHaveAccountLabel: DynamicLabel!
    var keyboardSpace: NSLayoutConstraint = NSLayoutConstraint()
    var keyboard: KeyboardTransitioning?
    var selectedTextField: UITextField?
    var baseURL: URL?
    var accountID: String = ""
    var pairingCode: String = ""

    static func create(baseURL: URL, accountID: String, pairingCode: String) -> CreateAccountViewController {
        let vc = loadFromStoryboard()
        vc.baseURL = baseURL
        vc.accountID = accountID
        vc.pairingCode = pairingCode
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.keyboardDismissMode = .onDrag

        name.labelName.text = NSLocalizedString("Full name", comment: "")
        name.textField.placeholder = NSLocalizedString("Full name...", comment: "")
        name.errorLabel.text = nil
        name.textField.delegate = self

        email.textField.keyboardType = .emailAddress
        email.labelName.text = NSLocalizedString("Email address", comment: "")
        email.textField.placeholder = NSLocalizedString("Email...", comment: "")
        email.errorLabel.text = nil
        email.textField.delegate = self

        password.textField.isSecureTextEntry = true
        password.labelName.text = NSLocalizedString("Password", comment: "")
        password.textField.placeholder = NSLocalizedString("Password...", comment: "")
        password.textField.delegate = self
        password.errorLabel.text = nil

        createAccountButton.layer.cornerRadius = 4

        createAccountButton.setTitle(NSLocalizedString("Create Account", comment: ""), for: .normal)
        termsAndConditionsLabel.text = NSLocalizedString("By tapping ‘Create Account’, you agree to the Terms of Service and acknowledge the Privacy Policy.", comment: "")
        alreadyHaveAccountLabel.text = NSLocalizedString("Already have an account? Sign In", comment: "")

        stackView.setCustomSpacing(4, after: password)
        stackView.setCustomSpacing(16, after: termsAndConditionsLabel)
        stackView.setCustomSpacing(16, after: createAccountButton)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        keyboard = KeyboardTransitioning(view: view, space: keyboardSpace, callback: { [weak self] keyboardFrame in
            self?.keyboardDidChangeState(keyboardFrame: keyboardFrame)
        })
    }

    @IBAction func actionSignIn(_ sender: Any) {
        print("\(#function)")
    }

    @IBAction func actionCreateAccount(_ sender: Any) {
        guard let baseURL = baseURL else { return }
        guard let fullname = name.textField.text, fullname.count > 2 else { rowInvalidShowError(row: name); return }
        guard let userEmail = email.textField.text, !userEmail.isEmpty else { rowInvalidShowError(row: email); return }
        guard let userPassword = password.textField.text, !userPassword.isEmpty else { rowInvalidShowError(row: password); return }

        let request = PostAccountUserRequest(
            baseURL: baseURL,
            accountID: accountID,
            pairingCode: pairingCode,
            name: fullname,
            email: userEmail,
            password: userPassword
        )
        AppEnvironment.shared.api.makeRequest(request) { [weak self] (_, _, error) in
            if let _ = error {
                //  TODO: - handle errors
                self?.showError(NSError.instructureError(NSLocalizedString("An error occurred", comment: "")))
                return
            }
            self?.dismissCreateAccount()
        }
    }

    func rowInvalidShowError(row: CreateAccountRow) {
        let rows = [name, email, password]
        rows.forEach {
            $0?.textField.layer.borderWidth = 1
            $0?.textField.layer.cornerRadius = 4
            $0?.textField.layer.borderColor = UIColor.named(.borderMedium).cgColor
            $0?.errorLabel.text = nil
        }

        row.textField.layer.borderColor = UIColor.named(.borderDanger).cgColor

        switch row {
        case name: return
            row.errorLabel.text = NSLocalizedString("Please enter full name", comment: "")
        case email: return
            row.errorLabel.text = NSLocalizedString("Please enter an email address", comment: "")
        case password: return
            row.errorLabel.text = NSLocalizedString("Password is required", comment: "")
        default: return
        }
    }

    func dismissCreateAccount() {
        AppEnvironment.shared.router.dismiss(self)
    }

    func keyboardDidChangeState(keyboardFrame: CGRect) {
        scrollView.scrollToView(view: selectedTextField, keyboardRect: keyboardFrame)
    }
}

extension CreateAccountViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        selectedTextField = textField
    }
}

class CreateAccountRow: UIView {
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var errorLabel: CustomLabel!
    @IBOutlet weak var labelName: UILabel!

    override init(frame: CGRect) {
        super.init(frame: frame)
        loadFromXib()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadFromXib()
    }

    class CustomLabel: UILabel {
        override var text: String? {
            didSet {
                isHidden = text?.isEmpty == true
            }
        }
    }
}
