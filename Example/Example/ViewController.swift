//
//  ViewController.swift
//  Example
//
//  Created by Matheus Gois on 05/07/23.
//

import UIKit
import ImageLoader

class ViewController: UIViewController {

    @IBOutlet var imageContentView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.loadImage()
    }

    private func loadImage() {
        imageContentView._setImage(with: .init(string: "https://picsum.photos/200/300"))
    }
}
