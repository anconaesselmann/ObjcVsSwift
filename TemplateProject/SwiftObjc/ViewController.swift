//  Created by Axel Ancona Esselmann on 4/5/17.
//  Copyright © 2017 Vida. All rights reserved.
//

import UIKit

protocol JsonInstantiable {
    init!(jsonDict: [AnyHashable : Any]!)
}

class ViewController: UIViewController {

    var swiftJsonInstatiableInstances: [JsonInstantiable] = []
    var objcJsonInstatiableInstances:  [ObjectiveCJsonInstantiable] = []

    func timeElapsedInSecondsWhenRunningCode(operation:()->()) -> Double {
        let startTime = CFAbsoluteTimeGetCurrent()
        operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        return Double(timeElapsed)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let asset = NSDataAsset(name: "instances", bundle: Bundle.main)
        let instanceDicts = try! JSONSerialization.jsonObject(with: asset!.data, options: JSONSerialization.ReadingOptions.allowFragments) as! [[String: Any]]

        let executionTime = timeElapsedInSecondsWhenRunningCode {
            for instanceDict in instanceDicts {
                let className  = instanceDict["className"]  as! String
                let parameters = instanceDict["parameters"] as! [String: Any]

                if
                    let type = className.classType as? ObjectiveCJsonInstantiable.Type,
                    let instance = type.init(jsonDict: parameters)
                {
                    objcJsonInstatiableInstances.append(instance)
                } else if
                    let type = className.classType as? JsonInstantiable.Type,
                    let instance = type.init(jsonDict: parameters)
                {
                    swiftJsonInstatiableInstances.append(instance)
                } else {
                    print("Class \(className) could not be instantiated")
                }
            }
        }
        print("Number of instances created: \(swiftJsonInstatiableInstances.count + objcJsonInstatiableInstances.count)\n Execution time in seconds: \(executionTime)")
    }
}
