# ObjcVsSwift
An experiment investigating the effects of having a large number of randomly generated swift and/or objective-c files on build and execution time.


## Options:

| Command                             | Description  |
| ----------------------------------- | -------------|
| `--swift <integer>`                 | Number of swift classes to be generated.           |
| `--objc <integer>`                  | Number of objective c classes to be generated.     |
| `--instances <integer>`             | Number of times each class should be instantiated. |
| `--parameters <integer>`            | Number of properties each auto-generated class should have. |
| `--swift_json_protocol`             | Uses a common swift protocol instead of an objective-c protocol for swift classes. |
| `--swift_single_file`               | Instead of creating a new file for each swift class, this setting will write all swift classes into one file. |
| `--output_directory <directory>`    | A directory for the auto-generated project. Make sure to change this between runs, since running the script on an existing project is not supported. |
| `--verbose`                         | Prints all files that are being written. |
| `--instances_directory <directory>` | Instance creation is randomly shuffled. To be able to create instances in the same order between different projects, provide a directory where a common instance creation file is stored. |
