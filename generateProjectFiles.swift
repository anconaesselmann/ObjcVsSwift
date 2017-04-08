#!/usr/bin/swift

// ./generateProjectFiles.swift --swift 50 --objc 50 --instances 10 --parameters 100 --output_directory "/ObjcVsSwift" --swift_single_file

import Foundation
import GameKit    // For shuffeling instance creation data

// MARK: - Setting default values
var numberOfSwiftClasses      = 100
var numberOfObjectiveCClasses = 100
var numberOfInstances         = 5
var numberOfClassParameters   = 5
var useSwiftJsonProtocol      = false
var swiftClassesInSingleFile  = false
var outputDirectory           = ""

// MARK: - Reading from command line

enum OptionType {
    case swiftClassNumber
    case objcClassNumber
    case instanceNumber
    case parameterNumber
    case jsonProtocolSwift
    case swiftSingleFile
    case outputDirectory

    init?(value: String) {
        switch value {
        case "--swift":      self = .swiftClassNumber
        case "--objc":       self = .objcClassNumber
        case "--instances":  self = .instanceNumber
        case "--parameters": self = .parameterNumber
        case "--swift_json_protocol": self = .jsonProtocolSwift
        case "--swift_single_file":   self = .swiftSingleFile
        case "--output_directory":    self = .outputDirectory // doesnt currently work with ~/
        default: return nil
        }
    }
}

struct Option {
    let type: OptionType
    var values: [String] = []

    init(type: OptionType) {
        self.type = type
    }
}

func int(from array: [String], at index: Int) -> Int? {
    guard index < array.count else { return nil }
    return Int(array[index])
}

var currentOption: Option?

var options: [Option] = []

for argumentIndex in 1..<CommandLine.arguments.count {
    let value = CommandLine.arguments[argumentIndex]
    if value.characters.first! == "-" {
        if let type = OptionType(value: value) {
            if let prevOption = currentOption {
                options.append(prevOption)
            }
            currentOption = Option(type: type)
        } else {
            print("Incorrect option \(value)")
            exit(1)
        }
    } else {
        currentOption?.values.append(value)
    }
}

if let prevOption = currentOption {
    options.append(prevOption)
}

for option in options {
    switch option.type {
    case .swiftClassNumber:
        numberOfSwiftClasses      = int(from: option.values, at: 0) ?? numberOfSwiftClasses
        print("Number of swift classes to be generated: \(numberOfSwiftClasses)")
    case .objcClassNumber:
        numberOfObjectiveCClasses = int(from: option.values, at: 0) ?? numberOfObjectiveCClasses
        print("Number of objective-c classes to be generated: \(numberOfObjectiveCClasses)")
    case .instanceNumber:
        numberOfInstances         = int(from: option.values, at: 0) ?? numberOfInstances
        print("Number of instances to be generated: \(numberOfInstances)")
    case .parameterNumber:
        numberOfClassParameters   = int(from: option.values, at: 0) ?? numberOfClassParameters
        print("Number of parameters to be generated: \(numberOfClassParameters)")
    case .jsonProtocolSwift:
        useSwiftJsonProtocol = true
        print("Using swift json protocol")
    case .swiftSingleFile:
        swiftClassesInSingleFile = true
        print("Using single file for swift")
    case .outputDirectory:
        outputDirectory = option.values.first!
        if outputDirectory.characters.last! != "/" {
            outputDirectory += "/"
        }
        print("Using output directory \(outputDirectory)")
    }
}

// MARK: - Functions

// Currently only string is generated
enum ParameterType: String {
    case string = "String"
    case int    = "Int"
    case double = "Double"
    case date   = "Date"
    case image  = "UIImage"
}

func classAndDatamodel(numberParameters: Int, name: String) ->
    (swiftClassDefinition:String, datamodel: [String: Any], objectiveCHeader: String, objectiveCImplementation: String)
{

    var parameterTypes = [ParameterType]()
    let jsonProtocol   = useSwiftJsonProtocol
        ? "JsonInstantiable"
        : "ObjectiveCJsonInstantiable"

    // Swift class
    var swiftClassDefinition = "class \(name): \(jsonProtocol) {\n"

    for _ in 0..<numberParameters {
        parameterTypes.append(getRandomParameterType())
    }

    for (parameterIndex, parameterType) in parameterTypes.enumerated() {
        swiftClassDefinition += getSwiftParameterDefinition(type: parameterType, name: "parameter\(parameterIndex)")
    }

    swiftClassDefinition += getFromJsonDictInit(parameterTypes: parameterTypes)
    swiftClassDefinition += "}\n"

    // Objective-c header
    let jsonProtocolImprtStatement = useSwiftJsonProtocol ? "?????" : "ObjectiveCJsonInstantiable"
    var objectiveCHeader = "#import \"\(jsonProtocolImprtStatement).h\"\n@interface \(name) : NSObject<\(jsonProtocol)/*, NSCoding*/>\n"
    for (parameterIndex, parameterType) in parameterTypes.enumerated() {
        objectiveCHeader += getObjectiveCParameterDefinition(type: parameterType, name: "parameter\(parameterIndex)")
    }
    objectiveCHeader += "@end\n"

    // Objective-c implementation
    var objectiveCImplementation = "#import \"\(name).h\"\n@implementation \(name)\n- (id)initWithJsonDict:(NSDictionary *)jsonDict {\n\tself = [self init];\n\tif (self) {\n"
    for (parameterIndex, parameterType) in parameterTypes.enumerated() {
        objectiveCImplementation += getObjectiveCParameterInitialization(type: parameterType, name: "parameter\(parameterIndex)")
    }
    objectiveCImplementation += "\t}\n\treturn self;\n}\n@end\n"


    // Data model
    var datamodel  = [String: Any]()
    var parameters = [String: Any]()

    for (parameterIndex, parameterType) in parameterTypes.enumerated() {
        parameters["parameter\(parameterIndex)"] = parameterType.rawValue
    }

    datamodel["className"] = name
    datamodel["parameters"] = parameters

    return (swiftClassDefinition, datamodel, objectiveCHeader, objectiveCImplementation)
}

func getSwiftParameterDefinition(type: ParameterType, name: String) -> String {
    return "\tvar \(name): \(type.rawValue)\n"
}

func getObjectiveCParameterDefinition(type: ParameterType, name: String) -> String {
    let objectiveCType: String

    switch type {
    case .string:
        objectiveCType = "NS" + type.rawValue
    default:
        objectiveCType = type.rawValue
    }

    return "@property (nonatomic, copy) \(objectiveCType) *\(name);\n"
}

func getObjectiveCParameterInitialization(type: ParameterType, name: String) -> String {
    return "\t\tif (jsonDict[@\"\(name)\"]) {\n\t\t\tself.\(name) = jsonDict[@\"\(name)\"];\n\t\t}\n"
}

func getInitializer(parameterTypes: [ParameterType]) -> String {
    var initString = "\trequired init("
    var parameterIndexStrings: [String] = []

    for (parameterIndex, parameterType) in parameterTypes.enumerated() {
        parameterIndexStrings.append("parameter\(parameterIndex): \(parameterType.rawValue)")
    }

    initString += parameterIndexStrings.joined(separator: ", ")
    initString += ") {\n"

    var parameterAssignmentStrings: [String] = []

    for (parameterIndex, _) in parameterTypes.enumerated() {
        parameterAssignmentStrings.append("\t\tself.parameter\(parameterIndex) = parameter\(parameterIndex)")
    }

    initString += parameterAssignmentStrings.joined(separator: "\n") + "\n"
    initString += "\t}\n"

    return initString
}

func getFromJsonDictInit(parameterTypes: [ParameterType]) -> String {
    var initString = "\trequired init!(jsonDict: [AnyHashable : Any]!) {\n"

    var parameterAssignmentStrings: [String] = []

    for (parameterIndex, parameterType) in parameterTypes.enumerated() {
        parameterAssignmentStrings.append("\t\tparameter\(parameterIndex) = jsonDict[\"parameter\(parameterIndex)\"] as! \(parameterType.rawValue)")
    }

    initString += parameterAssignmentStrings.joined(separator: "\n") + "\n"
    initString += "\t}\n"

    return initString
}

// Stub
func getRandomParameterType() -> ParameterType {
    return .string
}

func generateProjectClassesAndDataModels(numberSwiftClasses: Int, numberObjectiveCClasses: Int) ->
    (swiftClasses: [String], datamodels: [[String: Any]], objectiveCHeaders: [String], objectiveCImplementations: [String], objectiveCBridgingHeader: String)
{
    var swiftClasses:              [String] = []
    var objectiveCHeaders:         [String] = []
    var objectiveCImplementations: [String] = []
    var datamodels:                [[String: Any]] = []

    print("Generating Swift classes")
    for i in 0..<numberSwiftClasses {
        let classAndData = classAndDatamodel(numberParameters: numberOfClassParameters, name: "Class\(i)")
        swiftClasses.append(classAndData.swiftClassDefinition)
        datamodels.append(classAndData.datamodel)
    }

    print("Generating Objective-c classes")
    var objectiveCBridgingHeader = "#import \"ObjectiveCJsonInstantiable.h\"\n"

    for i in numberSwiftClasses..<(numberSwiftClasses + numberObjectiveCClasses) {
        let className = "Class\(i)"
        let classAndData = classAndDatamodel(numberParameters: numberOfClassParameters, name: className)
        objectiveCHeaders.append(classAndData.objectiveCHeader)
        objectiveCImplementations.append(classAndData.objectiveCImplementation)
        datamodels.append(classAndData.datamodel)
        objectiveCBridgingHeader += "#import \"\(className).h\"\n"
    }

    return (swiftClasses, datamodels, objectiveCHeaders, objectiveCImplementations, objectiveCBridgingHeader)
}

func generateJson(dataModels: [[String: Any]], numberOfInstances: Int) -> [[String: Any]] {
    var jsonDicts: [[String: Any]] = []

    print("Generating json representation for instances")
    for dataModel in dataModels {
        for _ in 0..<numberOfInstances {
            var instanceJsonDict = [String: Any]()
            instanceJsonDict["className"] = dataModel["className"] as! String

            var propertiesJsonDict = [String: Any]()
            for (propertyName, propertyTypeString) in dataModel["parameters"] as? [String: String] ?? [:] {
                let value = getValue(type: propertyTypeString)
                propertiesJsonDict[propertyName] = value
            }
            instanceJsonDict["parameters"] = propertiesJsonDict
            jsonDicts.append(instanceJsonDict)
        }
    }

    return GKRandomSource.sharedRandom().arrayByShufflingObjects(in: jsonDicts) as! [[String : Any]]
}

func getValue(type: String) -> Any? {
    switch type {
    case "String":
        return "A random string"
    default:
        return nil
    }
}

// MARK: - Script execution


let classedAndDataModels = generateProjectClassesAndDataModels(numberSwiftClasses: numberOfSwiftClasses, numberObjectiveCClasses: numberOfObjectiveCClasses)
let jsonDicts            = generateJson(dataModels: classedAndDataModels.datamodels, numberOfInstances: numberOfInstances)

let jsonData             = try! JSONSerialization.data(withJSONObject: jsonDicts, options: .prettyPrinted)
let dataModelsData       = try! JSONSerialization.data(withJSONObject: classedAndDataModels.datamodels, options: .prettyPrinted)
let bridgingHeaderData   = classedAndDataModels.objectiveCBridgingHeader.data(using: String.Encoding.utf8)


// MARK: - Creating folder structure

try FileManager.default.createDirectory(atPath: outputDirectory + "output/classes",       withIntermediateDirectories: true, attributes: nil)
try FileManager.default.createDirectory(atPath: outputDirectory + "output/classes/swift", withIntermediateDirectories: true, attributes: nil)
try FileManager.default.createDirectory(atPath: outputDirectory + "output/classes/objc",  withIntermediateDirectories: true, attributes: nil)

// MARK: - Saving to file

print("Saving data models")
FileManager.default.createFile(atPath: outputDirectory + "output/datamodels.json", contents: dataModelsData, attributes: nil)

print("Saving json representation for instances")
FileManager.default.createFile(atPath: outputDirectory + "output/instances.json", contents: jsonData, attributes: nil)

print("Saving Bridgin-Header")
FileManager.default.createFile(atPath: outputDirectory + "output/SwiftObjc-Bridging-Header.h", contents: bridgingHeaderData, attributes: nil)

print("Saving swift classes")
if swiftClassesInSingleFile {
    print("Saving to single file")
    var singleFile = ""
    for swiftClass in classedAndDataModels.swiftClasses {
        singleFile += swiftClass
    }
    let singleFileData = singleFile.data(using: String.Encoding.utf8)
    FileManager.default.createFile(atPath: outputDirectory + "output/classes/swift/allSwiftFiles.swift", contents: singleFileData, attributes: nil)
} else {
    print("Saving to individual files")
    for (index, swiftClass) in classedAndDataModels.swiftClasses.enumerated() {
        let classData = swiftClass.data(using: String.Encoding.utf8)
        FileManager.default.createFile(atPath: outputDirectory + "output/classes/swift/\(classedAndDataModels.datamodels[index]["className"] as! String).swift", contents: classData, attributes: nil)
    }
}

print("Saving objective-c headers")
for (index, objectiveCHeader) in classedAndDataModels.objectiveCHeaders.enumerated() {
    let headerData = objectiveCHeader.data(using: String.Encoding.utf8)
    FileManager.default.createFile(atPath: outputDirectory + "output/classes/objc/\(classedAndDataModels.datamodels[index + classedAndDataModels.swiftClasses.count]["className"] as! String).h", contents: headerData, attributes: nil)
}

print("Saving objective-c implementations")
for (index, objectiveCImplementation) in classedAndDataModels.objectiveCImplementations.enumerated() {
    let implementationData = objectiveCImplementation.data(using: String.Encoding.utf8)
    FileManager.default.createFile(atPath: outputDirectory + "output/classes/objc/\(classedAndDataModels.datamodels[index + classedAndDataModels.swiftClasses.count]["className"] as! String).m", contents: implementationData, attributes: nil)
}
