//
//  IntroViewController.swift
//  VerIDSample
//
//  Created by Jakub Dolejs on 08/02/2018.
//  Copyright © 2018 Applied Recognition, Inc. All rights reserved.
//

import UIKit
import VerIDUI
import VerIDCore

class IntroViewController: UIPageViewController, UIPageViewControllerDataSource, SessionDelegate, QRCodeScanViewControllerDelegate {
    
    lazy var introViewControllers: [UIViewController] = {
        guard let storyboard = self.storyboard else {
            return []
        }
        var controllers: [UIViewController] = [
            storyboard.instantiateViewController(withIdentifier: "introPage1"),
            storyboard.instantiateViewController(withIdentifier: "introPage2"),
            storyboard.instantiateViewController(withIdentifier: "introPage3")
        ]
        return controllers
    }()
    
    var environment: VerID?
    
    var showRegisterButton = true

    override func viewDidLoad() {
        super.viewDidLoad()
        self.dataSource = self
        if !showRegisterButton {
            self.navigationItem.rightBarButtonItem = nil
            self.navigationItem.leftBarButtonItem = nil
        }
        if (UIApplication.shared.delegate as! AppDelegate).registrationDownloading == nil {
            // Hide import button if app delegate cannot handle face template imports
            self.navigationItem.leftBarButtonItem = nil
        }
        if let initialController = self.introViewControllers.first {
            self.setViewControllers([initialController], direction: .forward, animated: false, completion: nil)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let codeScanViewController = segue.destination as? QRCodeScanViewController {
            codeScanViewController.delegate = self
        } else if let importViewController = segue.destination as? RegistrationImportViewController, let registrationData = sender as? RegistrationData, let image = registrationData.profilePicture {
            importViewController.image = UIImage(cgImage: image)
            importViewController.environment = self.environment
            importViewController.faceTemplates = registrationData.faceTemplates
        }
    }
    
    // MARK: - QR code scan delegate
    
    func qrCodeScanViewController(_ viewController: QRCodeScanViewController, didScanQRCode value: String) {
        self.dismiss(animated: true, completion: nil)
        guard let url = URL(string: value) else {
            self.showImportError()
            return
        }
        let alert = UIAlertController(title: "Downloading", message: nil, preferredStyle: .alert)
        self.present(alert, animated: true) {
            (UIApplication.shared.delegate as? AppDelegate)?.registrationDownloading?.downloadRegistration(url) { registrationData in
                self.dismiss(animated: true) {
                    if registrationData != nil {
                        self.performSegue(withIdentifier: "import", sender: registrationData)
                    } else {
                        self.showImportError()
                    }
                }
            }
        }
    }
    
    // MARK: -
    
    func showImportError() {
        let alert = UIAlertController(title: "Error", message: "Failed to download registration", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func register(_ sender: Any) {
        guard let environment = self.environment else {
            return
        }
        let settings = RegistrationSessionSettings(userId: VerIDUser.defaultUserId, livenessDetection: .regular, showResult: true)
        settings.appendIfUserExists = false
        let session = Session(environment: environment, settings: settings)
        session.delegate = self
        session.start()
    }
    
    @IBAction func importCancelled(_ segue: UIStoryboardSegue) {
        if let codeScanViewController = segue.source as? QRCodeScanViewController {
            codeScanViewController.delegate = nil
        }
        do {
            if segue.source is RegistrationImportViewController, let storyboard = self.storyboard, let environment = self.environment, try environment.userManagement.users().contains(VerIDUser.defaultUserId) {
                guard let mainViewController = storyboard.instantiateViewController(withIdentifier: "start") as? MainViewController else {
                    return
                }
                mainViewController.environment = self.environment
                self.navigationController?.setViewControllers([mainViewController], animated: false)
            }
        } catch {
            
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let index = self.introViewControllers.index(of: viewController), index > 0 else {
            return nil
        }
        return self.introViewControllers[index - 1]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let index = self.introViewControllers.index(of: viewController), index + 1 < self.introViewControllers.count else {
            return nil
        }
        return self.introViewControllers[index + 1]
    }
    
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return self.introViewControllers.count
    }
    
    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        return 0
    }

    func session(_ session: Session, didFinishWithResult result: SessionResult) {
        if let storyboard = self.storyboard {
            if let from = result.imageURLs(withBearing: .straight).first, let to = (UIApplication.shared.delegate as? AppDelegate)?.profilePictureURL {
                try? FileManager.default.removeItem(at: to)
                try? FileManager.default.copyItem(at: from, to: to)
            }
            guard let viewController = storyboard.instantiateViewController(withIdentifier: "start") as? MainViewController else {
                return
            }
            viewController.environment = self.environment
            self.navigationController?.setViewControllers([viewController], animated: false)
        }
    }
    
    func session(_ session: Session, didFailWithError error: Error) {
        
    }
    
    func sessionWasCanceled(_ session: Session) {
        
    }
}