//  Created by Axel Ancona Esselmann on 4/9/17.
//  Copyright © 2017 Vida. All rights reserved.
//

import UIKit

extension String {
    var className: String {
        let key = kCFBundleNameKey as String
        let moduleName = Bundle.main.infoDictionary![key] as!String
        return "\(moduleName).\(self)"
    }
    
    var classType: Any.Type? {
        if let type = NSClassFromString(self.className) { return type }
        else { return NSClassFromString(self) }
    }
}
