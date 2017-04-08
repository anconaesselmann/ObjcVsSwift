//  Created by Axel Ancona Esselmann on 10/23/16.
//  Copyright © 2016 Vida. All rights reserved.
//

import UIKit

extension Bundle {
    static var moduleName: String {
        let bundleKey = kCFBundleNameKey as String
        return self.application.infoDictionary![bundleKey] as! String
    }
    static var application: Bundle {
        return Bundle.main
    }
}

extension String {
    var className: String {
        return "\(Bundle.moduleName).\(self)"
    }
    var classType: Any.Type? {
        if let type = NSClassFromString(self.className) {
            // Swift-class-names have the bundle name prepended
            return type
        } else {
            // Objective-C-class-names don't have the bundle name prepended
            return NSClassFromString(self)
        }
    }
}
