//
//  SelfieCollectionViewController.swift
//  Selfie
//
//  Created by Behera, Subhransu on 29/8/14.
//  Copyright (c) 2014 subhb.org. All rights reserved.
//

import UIKit

let reuseIdentifier = "SelfieCollectionViewCell"

class SelfieCollectionViewController: UICollectionViewController {
  var shouldFetchNewData = true
  var dataArray = [SelfieImage]()
  let httpHelper = HTTPHelper()
  
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(true)
    
    println("in viewDidAppear")
    
    // check if user is signed in
    let defaults = NSUserDefaults.standardUserDefaults()
    
    // if user is not signed in display controller to sign in or sign up
    if defaults.objectForKey("userLoggedIn") == nil {
      let loginController: ViewController = self.storyboard?.instantiateViewControllerWithIdentifier("ViewController") as! ViewController
      self.navigationController?.presentViewController(loginController, animated: true, completion: nil)
    } else {
      // check if API token has expired
      let dateFormatter = NSDateFormatter()
      dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
      let userTokenExpiryDate : NSString? = KeychainAccess.passwordForAccount("Auth_Token_Expiry",
        service: "KeyChainService")
      
      
      let dateFromString : NSDate? = dateFormatter.dateFromString(userTokenExpiryDate! as String)

      let now = NSDate()
      
      let comparision = now.compare(dateFromString!)
      
      // check if should fetch new data
      if shouldFetchNewData {
        shouldFetchNewData = false
        self.setNavigationItems()
        loadSelfieData()
      }
      
      // logout and ask user to sign in again if token is expired
      if comparision != NSComparisonResult.OrderedAscending {
        self.logoutBtnTapped()
      }
      
    }
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  func setNavigationItems() {
    var logOutBtn = UIBarButtonItem(title: "logout", style: UIBarButtonItemStyle.Plain, target: self, action: Selector("logoutBtnTapped"))
    self.navigationItem.leftBarButtonItem = logOutBtn
    
    var navCameraBtn = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Camera, target: self, action: Selector("cameraBtnTapped"))
    self.navigationItem.rightBarButtonItem = navCameraBtn
  }
  
  // 1. Clears the NSUserDefaults flag
  func clearLoggedinFlagInUserDefaults() {
    let defaults = NSUserDefaults.standardUserDefaults()
    defaults.removeObjectForKey("userLoggedIn")
    defaults.synchronize()
  }
  
  // 2. Removes the data array
  // Removes the data array and reloads the collection view. This is to make sure that when a new user signs in they don’t see any cached data.
  func clearDataArrayAndReloadCollectionView() {
    self.dataArray.removeAll(keepCapacity: true)
    self.collectionView?.reloadData()
  }
  
  // 3. Clears API Auth token from Keychain
  func clearAPITokensFromKeyChain () {
    
    // clear API Auth token
    if let userToken = KeychainAccess.passwordForAccount("Auth_Token", service: "KeyChainService") {
      KeychainAccess.deletePasswordForAccount(userToken, account: "Auth_Token", service: "KeyChainService")
    }
    
    // clear API Auth Expity
    if let userTokenExPiryDate = KeychainAccess.passwordForAccount("Auth_Token_Expiry", service: "KeyChainService") {
      KeychainAccess.deletePasswordForAccount(userTokenExPiryDate, account: "Auth_Token_Expiry", service: "KeyChainService")
    }
  }
  
  func logoutBtnTapped() {
    clearLoggedinFlagInUserDefaults()
    clearDataArrayAndReloadCollectionView()
    clearAPITokensFromKeyChain()
    
    // set flag to desplay Sign in view
    shouldFetchNewData = true
    self.viewDidAppear(true)
  }
  
  func cameraBtnTapped() {
    displayCameraControl()
  }
  
  func loadSelfieData () {
    
    // Create HTTP request and set request Body
    let httpRequest = httpHelper.buildRequest("get_photos", method: "GET", authType: HTTPRequestAuthType.HTTPTokenAuth)
    
    // Send HTTP to load existing selfie
    httpHelper.sendRequest(httpRequest, completion: {
      (data: NSData!, error:NSError!) in
      
      // Display error
      if error != nil {
        let errorMessage = self.httpHelper.getErrorMessage(error) as String!
        let errorAlert = UIAlertView(title: "Error", message: errorMessage, delegate: nil, cancelButtonTitle: "OK")
        errorAlert.show()
        
        return
      }
      
      var error: NSError?
      let jsonDataArray = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(0), error: &error) as! NSArray!
      
      // load the collection view with existing selfies
      if jsonDataArray != nil {
        
        for imageDataDict in jsonDataArray {
          var selfieImgObj = SelfieImage()
          
          selfieImgObj.imageTitle = imageDataDict.valueForKey("title") as! String
          selfieImgObj.imageId = imageDataDict.valueForKey("random_id") as! String
          selfieImgObj.imageThumbnailURL = imageDataDict.valueForKey("image_url") as! String
          
          self.dataArray.append(selfieImgObj)
        }
        
        self.collectionView?.reloadData()
      }
    
    
    })
  }
  
  func removeObject<T:Equatable>(inout arr:Array<T>, object:T) -> T? {
    
    if let indexOfObject = find(arr, object) {
      return arr.removeAtIndex(indexOfObject)
    }
    
    return nil
  }
  
  override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
    return 1
  }
    
  override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return self.dataArray.count
  }
  
  override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
    
    let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as! SelfieCollectionViewCell
    
    
    // Configure the cell
    // rowIndex displays the most recent selfie on top and puts the older ones below.
    var rowIndex = self.dataArray.count - (indexPath.row + 1)
    var selfieRowObj = self.dataArray[rowIndex] as SelfieImage
    
    cell.backgroundColor = UIColor.blackColor()
    cell.selfieTitle.text = selfieRowObj.imageTitle
    
    var imgURL: NSURL = NSURL(string: selfieRowObj.imageThumbnailURL)!
    
    // Download an NSData representation of the image at the URL
    let request: NSURLRequest = NSURLRequest(URL: imgURL)
    NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue(), completionHandler: {
      (response: NSURLResponse!, data: NSData!, error: NSError!) -> Void in
      
      if error == nil {
        var image = UIImage(data: data)
        
        dispatch_async(dispatch_get_main_queue(), {
          cell.selfieImgView.image = image
        })
      } else {
        println("Error: \(error.localizedDescription)")
      }
    
    
    })
    
    return cell
  }
  
  // MARK: UICollectionViewDelegate
  
  override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
    
    // fetch the Selfie Image Object
    var rowIndex = self.dataArray.count - (indexPath.row + 1)
    var selfieRowObj = self.dataArray[rowIndex] as SelfieImage
    
    pushDetailsViewControllerWithSelfieObject(selfieRowObj)
  }
}

// Camera Extension

extension SelfieCollectionViewController : UINavigationControllerDelegate, UIImagePickerControllerDelegate {
  func displayCameraControl() {
    var imagePickerController = UIImagePickerController()
    imagePickerController.delegate = self
    imagePickerController.allowsEditing = true
    
    if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera) {
      imagePickerController.sourceType = UIImagePickerControllerSourceType.Camera
      
      if UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.Front) {
        imagePickerController.cameraDevice = UIImagePickerControllerCameraDevice.Front
      } else {
        imagePickerController.cameraDevice = UIImagePickerControllerCameraDevice.Rear
      }
    } else {
      imagePickerController.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
    }
    
    self.presentViewController(imagePickerController, animated: true, completion: nil)
  }
  
  // imagePickerController(_:didFinishPickingMediaWithInfo:) gets called when the user selects an image
  func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject: AnyObject]) {
    
    var image: UIImage!
    
    // fetch the selected image
    if picker.allowsEditing {
      image = info[UIImagePickerControllerEditedImage] as! UIImage
    } else {
      image = info[UIImagePickerControllerOriginalImage] as! UIImage
    }
    
    
    // dissmiss the image picker controller window
    self.dismissViewControllerAnimated(true, completion: nil)
    
    presentComposeViewControllerWithImage(image)
  }
}

// Compose Selfie Extension

extension SelfieCollectionViewController : SelfieComposeDelegate {
  func presentComposeViewControllerWithImage(image:UIImage!) {
    
    // instantiate compose view controller to capture a caption
    let composeVC: ComposeViewController = self.storyboard?.instantiateViewControllerWithIdentifier("ComposeViewController") as! ComposeViewController
    composeVC.composeDelegate = self
    composeVC.thumbImg = image
    
    // set the navigation controller of compose view controller
    let composeNavVc = UINavigationController(rootViewController: composeVC)
    
    // TODO: self.navigationController????
    // present compose view controller
    self.navigationController?.presentViewController(composeNavVc, animated: true, completion: nil)
    
    
    
  }
  
  func reloadCollectionViewWithSelfie(selfieImgObject: SelfieImage) {
    self.dataArray.append(selfieImgObject)
    self.collectionView?.reloadData()
  }
}

// Selfie Details Extension

extension SelfieCollectionViewController : SelfieEditDelegate {
  func pushDetailsViewControllerWithSelfieObject(selfieRowObj:SelfieImage!) {
    
    // instantiate detail view controller
    let detailVC = self.storyboard?.instantiateViewControllerWithIdentifier("DetailViewController") as!
    DetailViewController
    
    detailVC.editDelegate = self
    detailVC.selfieCustomObj = selfieRowObj
    
    // push detail view controller to the navigation stack
    self.navigationController?.pushViewController(detailVC, animated: true)
  }
  
  func deleteSelfieObjectFromList(selfieImgObject: SelfieImage) {
    
    if contains(self.dataArray, selfieImgObject) {
      removeObject(&self.dataArray, object: selfieImgObject)
      self.collectionView?.reloadData()
    }
    
  }
}
