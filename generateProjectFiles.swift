#!/usr/bin/swift

// ./main.swift --swift 50 --objc 50 --instances 10 --parameters 100 --output_directory "/ObjcVsSwift" --swift_single_file

import Foundation
import GameKit    // For shuffeling instance creation data

// MARK: - Setting default values
var numberOfSwiftClasses      = 100
var numberOfObjectiveCClasses = 100
var numberOfInstances         = 5
var numberOfClassParameters   = 5
var useSwiftJsonProtocol      = false
var swiftClassesInSingleFile  = false
var verbose                   = false
var outputDirectory           = ""
var instancesDirectory: String?

// MARK: - Reading from command line

enum OptionType {
    case swiftClassNumber
    case objcClassNumber
    case instanceNumber
    case parameterNumber
    case jsonProtocolSwift
    case swiftSingleFile
    case outputDirectory
    case verbose
    case instancesDirectory

    init?(value: String) {
        switch value {
        case "--swift":      self = .swiftClassNumber
        case "--objc":       self = .objcClassNumber
        case "--instances":  self = .instanceNumber
        case "--parameters": self = .parameterNumber
        case "--swift_json_protocol": self = .jsonProtocolSwift
        case "--swift_single_file":   self = .swiftSingleFile
        case "--output_directory":    self = .outputDirectory // doesnt currently work with ~/
        case "--verbose":             self = .verbose
        case "--instances_directory": self = .instancesDirectory
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
            exit(-1)
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
    case .verbose:
        verbose = true
        print("Verbose output")
    case .instancesDirectory:
        instancesDirectory = option.values.first!
        print("Using instances directory \(instancesDirectory!)")
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


// MARK: - Files and directories

let templateDir        = URL(fileURLWithPath: "TemplateProject")
let targetDir          = URL(fileURLWithPath: outputDirectory + "SwiftObjc")

let datamodelsUrl      = targetDir.appendingPathComponent("datamodels.json")

let sharedInstancesDir = instancesDirectory != nil ? URL(fileURLWithPath: instancesDirectory!) : nil
let instancesUrl       = targetDir.appendingPathComponent("SwiftObjc/Assets.xcassets/instances.dataset/instances.json")

let bridgingHeaderUrl  = targetDir.appendingPathComponent("SwiftObjc/SwiftObjc-Bridging-Header.h")

let swiftClassFilesDir = targetDir.appendingPathComponent("SwiftObjc/swift")
let objcClassFilesDir  = targetDir.appendingPathComponent("SwiftObjc/objc")

let singleSwiftFileUrl = swiftClassFilesDir.appendingPathComponent("allSwiftFiles.swift")

let xcodeProjectUrl    = targetDir.appendingPathComponent("SwiftObjc.xcodeproj/project.pbxproj")
let tempXcodeProjectUrl    = targetDir.appendingPathComponent("SwiftObjc.xcodeproj/_project.pbxproj")


// MARK: - Script execution

let classedAndDataModels = generateProjectClassesAndDataModels(numberSwiftClasses: numberOfSwiftClasses, numberObjectiveCClasses: numberOfObjectiveCClasses)
let jsonDicts            = generateJson(dataModels: classedAndDataModels.datamodels, numberOfInstances: numberOfInstances)

let jsonData             = try! JSONSerialization.data(withJSONObject: jsonDicts, options: .prettyPrinted)
let dataModelsData       = try! JSONSerialization.data(withJSONObject: classedAndDataModels.datamodels, options: .prettyPrinted)
let bridgingHeaderData   = classedAndDataModels.objectiveCBridgingHeader.data(using: String.Encoding.utf8)

// MARK: - Creating folder structure

if outputDirectory.characters.count > 0 && !FileManager.default.fileExists(atPath: outputDirectory) {
    try FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true, attributes: nil)
}

// MARK: - Saving to file

print("Copying Xcode project template")
try? FileManager.default.copyItem(at: templateDir, to: targetDir)

print("Writing \(datamodelsUrl.relativePath)")
FileManager.default.createFile(atPath: datamodelsUrl.relativePath, contents: dataModelsData, attributes: nil)

print("Writing \(bridgingHeaderUrl.relativePath)")
FileManager.default.createFile(atPath: bridgingHeaderUrl.relativePath, contents: bridgingHeaderData, attributes: nil)

if let url = sharedInstancesDir {
    let sharedInstancesUrl = url.appendingPathComponent("instances.json")
    if !FileManager.default.fileExists(atPath: sharedInstancesUrl.relativePath) {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        print("Writing \(sharedInstancesUrl.relativePath)")
        FileManager.default.createFile(atPath: sharedInstancesUrl.relativePath, contents: jsonData, attributes: nil)
    }
    print("Writing \(instancesUrl.relativePath)")
    try FileManager.default.copyItem(at: sharedInstancesUrl, to: instancesUrl)
} else {
    print("Writing \(instancesUrl.relativePath)")
    FileManager.default.createFile(atPath: instancesUrl.relativePath, contents: jsonData, attributes: nil)
}




var swiftClassNames = [String]()
var objcHeaderNames = [String]()
var objcImplementationNames = [String]()

print("Writing swift classes")
if swiftClassesInSingleFile {
    print("Writing single file")
    var singleFile = ""
    for swiftClass in classedAndDataModels.swiftClasses {
        singleFile += swiftClass
    }
    let singleFileData = singleFile.data(using: String.Encoding.utf8)
    FileManager.default.createFile(atPath: singleSwiftFileUrl.relativePath, contents: singleFileData, attributes: nil)
    swiftClassNames.append("allSwiftFiles.swift")
} else {
    print("Writing individual swift files")
    for (index, swiftClass) in classedAndDataModels.swiftClasses.enumerated() {
        let classData = swiftClass.data(using: String.Encoding.utf8)
        let className = (classedAndDataModels.datamodels[index]["className"] as! String) + ".swift"
        let fileName = swiftClassFilesDir.appendingPathComponent(className).relativePath
        if verbose { print("Writing file `\(fileName)`") }
        FileManager.default.createFile(atPath: fileName, contents: classData, attributes: nil)
        swiftClassNames.append(className)
    }
}

print("Writing objective-c header files")
for (index, objectiveCHeader) in classedAndDataModels.objectiveCHeaders.enumerated() {
    let headerData = objectiveCHeader.data(using: String.Encoding.utf8)
    let className = (classedAndDataModels.datamodels[index + classedAndDataModels.swiftClasses.count]["className"] as! String) + ".h"
    let fileName = objcClassFilesDir.appendingPathComponent(className).relativePath
    if verbose { print("Writing file `\(fileName)`") }
    FileManager.default.createFile(atPath: fileName, contents: headerData, attributes: nil)
    objcHeaderNames.append(className)
}

print("Writing objective-c implementation files")
for (index, objectiveCImplementation) in classedAndDataModels.objectiveCImplementations.enumerated() {
    let implementationData = objectiveCImplementation.data(using: String.Encoding.utf8)
    let className = (classedAndDataModels.datamodels[index + classedAndDataModels.swiftClasses.count]["className"] as! String) + ".m"
    let fileName = objcClassFilesDir.appendingPathComponent(className).relativePath
    if verbose { print("Writing file `\(fileName)`") }
    FileManager.default.createFile(atPath: fileName, contents: implementationData, attributes: nil)
    objcImplementationNames.append(className)
}

print("Adding source files to Xcode project")

// MARK: - Adding source files to Xcode project
class XcodeEntry {
    let name: String
    var id: String
    var id2: String

    init(name: String) {
        self.name = name
        id = XcodeEntry.generateId()
        id2 = XcodeEntry.generateId()
    }

    private static func generateId() -> String {
        let uuid = UUID().uuidString
        let index1 = uuid.index(uuid.startIndex, offsetBy: 8)
        let index2 = uuid.index(index1, offsetBy: 1)
        let index3 = uuid.index(index2, offsetBy: 4)
        let index4 = uuid.index(index1, offsetBy: 16)
        let range = index2..<index3
        return uuid.substring(to: index1) + uuid.substring(with: range) + uuid.substring(from: index4)
    }
}

class XcodeFolder {
    let entry: XcodeEntry
    var elements: [XcodeEntry]

    init(name: String, elements: [String]) {
        self.elements = elements.flatMap({XcodeEntry(name: $0)})
        entry = XcodeEntry(name: name)
    }
}

let folders: [XcodeFolder] = [XcodeFolder(name: "objc", elements: objcHeaderNames + objcImplementationNames), XcodeFolder(name: "swift", elements: swiftClassNames)]

let projectName = "SwiftObjc"

let encoding: String.Encoding = .utf8

guard
    let xcodeProjectFileHandle     = try? FileHandle(forReadingFrom: xcodeProjectUrl),
    FileManager.default.createFile(atPath: tempXcodeProjectUrl.relativePath, contents: nil, attributes: nil),
    let tempXcodeProjectFileHandle = try? FileHandle(forWritingTo: tempXcodeProjectUrl),
    let delimData  = "\n".data(using: encoding) else {
        exit(-1)
}
var chunkSize = 4096
var buffer = Data(capacity: chunkSize)
var atEof = false

func readLine() -> String? {
    while !atEof {
        if let range = buffer.range(of: delimData) {
            let line = String(data: buffer.subdata(in: 0..<range.lowerBound), encoding: encoding)
            buffer.removeSubrange(0..<range.upperBound)
            return line
        }
        let tmpData = xcodeProjectFileHandle.readData(ofLength: chunkSize)
        if tmpData.count > 0 {
            buffer.append(tmpData)
        } else {
            atEof = true
            if buffer.count > 0 {
                let line = String(data: buffer as Data, encoding: encoding)
                buffer.count = 0
                return line
            }
        }
    }
    return nil
}


enum XcodeSection {
    case pbxGroup
    case pbxSourcesBuildPhase

    case none
}

var xcodeSection: XcodeSection = .none

var matchingConditions = 0

func getFolderEntry(for xCodeEntry: XcodeEntry) -> String {
    return "\t\t\t\t\(xCodeEntry.id) /* \(xCodeEntry.name) */,\n"
}

func getChildEntry(_ xCodeEntry: XcodeEntry) -> String {
    return "\t\t\t\t\(xCodeEntry.id2) /* \(xCodeEntry.name) */,"
}

func getFolderDefinition(for xCodeEntry: XcodeFolder) -> String {
    let children = xCodeEntry.elements.flatMap({getChildEntry($0)}).joined(separator: "\n")
    return "\t\t\(xCodeEntry.entry.id) /* \(xCodeEntry.entry.name) */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\(children)\n\t\t\t);\n\t\t\tpath = \(xCodeEntry.entry.name);\n\t\t\tsourceTree = \"<group>\";\n\t\t};\n"
}

func getPbxBuildFileEntry(for xCodeEntry: XcodeEntry) -> String? {
    guard !xCodeEntry.name.hasSuffix(".h") else {
        return nil
    }
    return "\t\t\(xCodeEntry.id) /* \(xCodeEntry.name) in Sources */ = {isa = PBXBuildFile; fileRef = \(xCodeEntry.id2) /* \(xCodeEntry.name) */; };\n"
}

func getPbxFileReferenceEnry(for xCodeEntry: XcodeEntry) -> String {
    let fileType: String
    if xCodeEntry.name.hasSuffix(".swift") {
        fileType = "sourcecode.swift"
    } else if xCodeEntry.name.hasSuffix(".h") {
        fileType = "sourcecode.c.h"
    } else if xCodeEntry.name.hasSuffix(".m") {
        fileType = "sourcecode.c.objc"
    } else {
        print("Error, wrong file type")
        fileType = ""
    }
    return "\t\t\(xCodeEntry.id2) /* \(xCodeEntry.name) */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = \(fileType); path = \(xCodeEntry.name); sourceTree = \"<group>\"; };\n"
}

func getPbxSourcesBuildPhase(for xCodeEntry: XcodeEntry) -> String? {
    guard !xCodeEntry.name.hasSuffix(".h") else {
        return nil
    }
    return "\t\t\t\t\(xCodeEntry.id) /* \(xCodeEntry.name) in Sources */,\n"
}

while let line = readLine() {
    defer {
        tempXcodeProjectFileHandle.write((line + "\n").data(using: encoding)!)
    }

    switch line {
    case "/* End PBXBuildFile section */":
        for folder in folders {
            for element in folder.elements {
                if let pbxBuildFileEntry = getPbxBuildFileEntry(for: element) {
                    tempXcodeProjectFileHandle.write((pbxBuildFileEntry).data(using: encoding)!)
                }
            }
        }
    case "/* End PBXFileReference section */":
        for folder in folders {
            for element in folder.elements {
                let pbxFileReferenceEnry = getPbxFileReferenceEnry(for: element)
                tempXcodeProjectFileHandle.write((pbxFileReferenceEnry).data(using: encoding)!)
            }
        }
    case "/* Begin PBXGroup section */":
        xcodeSection = .pbxGroup
    case "/* End PBXGroup section */":
        for folder in folders {
            let folderDefinition = getFolderDefinition(for: folder)
            tempXcodeProjectFileHandle.write((folderDefinition).data(using: encoding)!)
        }
        xcodeSection = .none
    case "/* Begin PBXSourcesBuildPhase section */":
        xcodeSection = .pbxSourcesBuildPhase

    default: ()
    }


    switch xcodeSection {
    case .pbxGroup:
        if line.hasSuffix("/* \(projectName) */ = {") {
            matchingConditions += 1
        } else if matchingConditions > 0 && line.hasSuffix("children = (") {
            matchingConditions += 1
        } else if matchingConditions == 2 {
            for folder in folders {
                let folderEntry = getFolderEntry(for: folder.entry)
                tempXcodeProjectFileHandle.write((folderEntry).data(using: encoding)!)
            }
            matchingConditions = 0
        }
    case .pbxSourcesBuildPhase:
        if line.hasSuffix("files = (") {
            matchingConditions += 1
        } else if matchingConditions > 0 {
            for folder in folders {
                for element in folder.elements {
                    if let sourceBuildPhase = getPbxSourcesBuildPhase(for: element) {
                        tempXcodeProjectFileHandle.write((sourceBuildPhase).data(using: encoding)!)
                    }
                }

            }
            matchingConditions = 0
            xcodeSection = .none
        }
    default: ()
    }
}

tempXcodeProjectFileHandle.closeFile()
tempXcodeProjectFileHandle.closeFile()

do {
    try FileManager.default.removeItem(at: xcodeProjectUrl)
    let _ = try FileManager.default.replaceItemAt(xcodeProjectUrl, withItemAt: tempXcodeProjectUrl, backupItemName: nil, options: [])
} catch {
    print("Xcode project file could not be modified")
}
