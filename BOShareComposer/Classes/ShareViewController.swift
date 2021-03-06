//
//  ShareViewController.swift
//  BOShareComposer
//
//  Created by Bruno Oliveira on 19/07/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import SnapKit
import WebKit

public extension BOShareViewController {
  public static func presentShareViewController(from viewController: UIViewController,
                                                     shareContent: ShareContent,
                                                     options: ShareOptions = ShareOptions(),
                                                     completion: ((Bool, ShareContent?) -> ())) {

    viewController.navigationController?.modalPresentationStyle = .OverCurrentContext
    viewController.modalPresentationStyle = .OverCurrentContext
    let shareViewController = BOShareViewController()
    shareViewController.completion = completion
    shareViewController.options = options
    shareViewController.shareContent = shareContent
    viewController.presentViewController(shareViewController, animated: false, completion: nil)
  }
}

public class BOShareViewController: UIViewController {

  private var metadataImageViewSize = CGSize(width: 70, height: 70)

  private var shareContent: ShareContent? {
    willSet(value) {
      if let currentValue = shareContent, newValue = value
        where newValue.link == currentValue.link {
        return
      }
      guard let newValue = value else {
        return
      }
      loadMetadata(newValue)
    }
    didSet {
      guard let shareContent = shareContent else {
        return
      }
      popupBody.text = shareContent.text

      if shareContent.link == nil {
        showMetadata = false
      }
    }
  }

  private var options: ShareOptions? {
    didSet {
      guard let options = options else {
        return
      }
      dismissButton.tintColor = options.tintColor
      dismissButton.setTitle(options.dismissText, forState: .Normal)
      confirmButton.tintColor = options.tintColor
      confirmButton.setTitle(options.confirmText, forState: .Normal)
      popupTitle.text = options.title
      popupBody.resignFirstResponder()
      popupBody.keyboardAppearance = options.keyboardAppearance
      popupBody.becomeFirstResponder()
      showMetadata = options.showMetadata
    }
  }

  private var showMetadata = true {
    didSet {
      guard !metadataImageView.constraints.isEmpty else {
        return
      }
      let size = showMetadata ? metadataImageViewSize : CGSize.zero
      metadataImageView.snp.updateConstraints { make in
        make.height.equalTo(size.height)
        make.width.equalTo(size.width)
      }
      UIView.animateWithDuration(0.5) {
        self.metadataImageView.layoutIfNeeded()
      }
    }
  }

  private var completion: ((Bool, ShareContent?) -> ())?

  lazy var dismissButton: UIButton = {
    let button = UIButton(type: UIButtonType.System)
    button.addTarget(self, action: #selector(cancelAction), forControlEvents: .TouchUpInside)
    return button
  }()

  lazy var confirmButton: UIButton = {
    let button = UIButton(type: UIButtonType.System)
    button.addTarget(self, action: #selector(sendAction), forControlEvents: .TouchUpInside)
    return button
  }()

  lazy var popupTitle: UILabel = {
    let label = UILabel()
    return label
  }()

  lazy var titleDivider: UIView = {
    let view = UIView()
    view.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.3)
    return view
  }()

  lazy var popupBody: UITextView = {
    let textField = UITextView()
    textField.editable = true
    textField.backgroundColor = UIColor.clearColor()
    textField.scrollEnabled = true
    textField.font = UIFont.systemFontOfSize(18)
    textField.becomeFirstResponder()
    return textField
  }()

  lazy var metadataImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .ScaleAspectFill
    imageView.clipsToBounds = true
    imageView.backgroundColor = UIColor.whiteColor()
    return imageView
  }()

  lazy var backgroundView: UIView = {
    let view = UIView()
    view.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.7)
    return view
  }()

  lazy var containerView: UIVisualEffectView = {
    let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .ExtraLight))
    visualEffectView.layer.cornerRadius = 8
    visualEffectView.clipsToBounds = true
    visualEffectView.alpha = 0
    return visualEffectView
  }()

  var metadataWebView = WKWebView()

  override public func viewDidLoad() {
    super.viewDidLoad()
    setupViews()
  }

  public override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    showView()
  }

  public override func viewWillDisappear(animated: Bool) {
    super.viewWillDisappear(animated)
    hideView()
  }

  func cancelAction() {
    shareContent?.text = popupBody.text
    completion?(false, shareContent)
    hideView { _ in
      self.dismissViewControllerAnimated(false, completion: nil)
    }
  }

  func sendAction() {
    shareContent?.text = popupBody.text
    completion?(true, shareContent)
    hideView { _ in
      self.dismissViewControllerAnimated(false, completion: nil)
    }
  }
}

extension BOShareViewController: WKNavigationDelegate {
  public func webView(webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                      withError error: NSError) {
    print("failed navigation")
  }

  public func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
    let dispatchTime: dispatch_time_t =
      dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC)))

    dispatch_after(dispatchTime, dispatch_get_main_queue(), {
      self.snapWebView(webView)
    })
  }


}

extension BOShareViewController {

  private func loadMetadata(shareContent: ShareContent) {
    guard let link = shareContent.link where self.showMetadata else {
      print("No link found / metadata disabled")
      return
    }

    OpenGraph.fetchMetadata(link, completion: { [weak self] (response) in
      guard let response = response, imageURL = response.imageURL else {
        self?.loadWebView(link)
        return
      }
      self?.metadataImageView.setImage(withUrl: imageURL)
      })
  }

  private func loadWebView(url: NSURL) {
    metadataWebView.navigationDelegate = self
    metadataWebView.loadRequest(NSURLRequest(URL: url))
  }

  private func snapWebView(webView: WKWebView) {
    metadataImageView.fadeSetImage(webView.screenshot)
  }

  private func showView() {
    UIView.animateWithDuration(0.5) {
      self.containerView.alpha = 1
    }
  }

  private func hideView(completion: ((Bool)->())? = nil) {
    popupBody.resignFirstResponder()
    UIView.animateWithDuration(0.5) {
      self.backgroundView.alpha = 0
    }

    UIView.animateWithDuration(0.5,
                               animations: {
                                self.containerView.alpha = 0
      },
                               completion: completion)
  }

  private func setupViews() {
    view.backgroundColor = UIColor.whiteColor()
    view.addSubview(backgroundView)
    backgroundView.snp.makeConstraints { make in
      make.edges.equalTo(self.view)
    }

    view.addSubview(containerView)

    containerView.snp.makeConstraints { make in
      make.top.equalTo(backgroundView).inset(60)
      make.left.equalTo(backgroundView).inset(16)
      make.right.equalTo(backgroundView).inset(16)
    }

    let contentView = containerView.contentView
    contentView.addSubview(dismissButton)
    dismissButton.snp.makeConstraints { make in
      make.top.equalTo(contentView).inset(4)
      make.left.equalTo(contentView).inset(8)
    }

    contentView.addSubview(confirmButton)
    confirmButton.snp.makeConstraints { make in
      make.top.equalTo(contentView).inset(4)
      make.right.equalTo(contentView).inset(8)
    }

    contentView.addSubview(titleDivider)
    titleDivider.snp.makeConstraints { make in
      make.top.equalTo(dismissButton.snp.bottom)
      make.left.equalTo(contentView)
      make.right.equalTo(contentView)
      make.height.equalTo(1)
    }

    contentView.addSubview(popupTitle)
    popupTitle.snp.makeConstraints { make in
      make.top.equalTo(contentView)
      make.bottom.equalTo(titleDivider.snp.top)
      make.centerX.equalTo(contentView)
      make.left.equalTo(dismissButton.snp.right).priorityLow()
      make.right.equalTo(confirmButton.snp.left).priorityLow()
    }

    let dummyContentView = UIView()
    contentView.addSubview(dummyContentView)
    dummyContentView.snp.makeConstraints { make in
      make.top.equalTo(titleDivider.snp.bottom)
      make.left.equalTo(contentView).inset(8)
      make.right.equalTo(contentView).inset(8)
      make.bottom.equalTo(contentView).inset(8)
      make.height.equalTo(140)
    }

    dummyContentView.addSubview(metadataImageView)
    metadataImageView.snp.makeConstraints { make in
      make.right.equalTo(dummyContentView)
      make.height.equalTo(showMetadata ? metadataImageViewSize.height : 0)
      make.width.equalTo(showMetadata ? metadataImageViewSize.width : 0)
      make.centerY.equalTo(dummyContentView)
    }

    dummyContentView.addSubview(popupBody)
    popupBody.snp.makeConstraints { make in
      make.top.equalTo(dummyContentView)
      make.left.equalTo(dummyContentView)
      make.right.equalTo(metadataImageView.snp.left)
      make.bottom.equalTo(dummyContentView)
    }

    view.addSubview(metadataWebView)
    metadataWebView.snp.makeConstraints { make in
      make.top.equalTo(view.snp.bottom)
      make.left.equalTo(view.snp.right)
      make.height.equalTo(view.snp.width)
      make.width.equalTo(view.snp.width)
    }
  }
}