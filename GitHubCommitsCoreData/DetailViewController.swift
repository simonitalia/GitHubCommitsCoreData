//
//  DetailViewController.swift
//  GitHubCommitsCoreData
//
//  Created by Simon Italia on 5/19/19.
//  Copyright © 2019 Magical Tomato. All rights reserved.
//

import UIKit

class DetailViewController: UIViewController {
    
    @IBOutlet weak var detailLabel: UILabel!

    var detailItem: Commit?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let detailItem = self.detailItem {
            detailLabel.text = detailItem.message
            
        }
        
        

        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
