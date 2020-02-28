#!/usr/bin/swift

// MARK: - Imports

import Foundation
import Commander

// MARK: - URLConversionError

struct URLConversionError: Error, CustomStringConvertible {

    private var source: String

    init(source: String) {
        self.source = source
    }

    var localizedDescription: String { "Invalid URL: \"\(source)\"" }
    var description: String { localizedDescription }
}

// MARK: - URL Extension

extension URL: ArgumentConvertible {

    public init(parser: ArgumentParser) throws {
        let string = try String(parser: parser)

        if string.contains(":") {
            guard let url = URL(string: string) else { throw URLConversionError(source: string) }
            self = url
        } else {
            self = URL(fileURLWithPath: (string.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) as NSString).standardizingPath)
        }
    }
}

// MARK: - Main Defintion

class Main {

    // MARK: Private Constants

    private static let symbolicatedLineRegex = try! NSRegularExpression(pattern: "^([0-9]+)([ \t]+)([^ \t]+)([ \t]+)(0x[0-9a-fA-F]+)([ \t]+)(0x[0-9a-fA-F]+)([ \t]+\\+[ \t]+[0-9]+)$?", options: .anchorsMatchLines)

    private static let verboseFlag = Flag("verbose", flag: "v", description: "Verbose logging.")
    private static let archOption = Option<String>("arch", default: "arm64", description: "The architecture to symbolicate. If not provided, this defaults to `arm64`")
    private static let outputOption = Option<URL?>("output", default: nil, description: "The fully qualified path of a file to write the symbolicated log to. This script needs read-write access to the file. The file is overwritten if it already exists. If this option is not provided, the input log is overwritten with the symbolicated log.")
    private static let logArgument = Argument<URL>("log", description: "The full path of the crash log to symbolicate. This script needs read access and also read-write access if the `--output` flag isn't provided.")
    private static let dsymArgument = Argument<[URL]?>("dsym", description: "One or more dSYM files to add the list of dSYMs to use when symbolicating the log. If one or more of these arguments is a folder, the folder is iterated non-recursively and all encountered dSYM files are added to the list.")

    // MARK: Private Properties

    private static var verbose: Bool = false

    // MARK: Main

    static func main() {
        let main = command(verboseFlag, archOption, outputOption, logArgument, dsymArgument) { verbose, arch, _output, log, dsyms in
            self.verbose = verbose
            var isDirectory: ObjCBool = false

            let output = _output ?? log
            var dSYMFiles = dsyms ?? []

            // Validate all inputs
            guard FileManager.default.fileExists(atPath: log.path, isDirectory: &isDirectory) else {
                abort(message: "Input file doesn't exist: \(log.path)")
            }
            guard !isDirectory.boolValue else {
                abort(message: "Input file is a directory: \(log.path)")
            }

            let outputFolder = output.deletingLastPathComponent()
            guard FileManager.default.fileExists(atPath: outputFolder.path, isDirectory: &isDirectory) else {
                abort(message: "Output folder doesn't exist: \(outputFolder.path)")
            }
            guard isDirectory.boolValue else {
                abort(message: "Output folder isn't a directory: \(outputFolder.path)")
            }

            // First parse out all dSYMs that don't exist and flatten folders into individual
            // dSYM files
            var i = 0
            while i < dSYMFiles.count {
                let dsym = dSYMFiles[i]
                guard FileManager.default.fileExists(atPath: dsym.path, isDirectory: &isDirectory) else {
                    verboseLog("Skipping dSYM(s) as it doesn't exist as the given path: \(dsym.path)")
                    dSYMFiles.remove(at: i)
                    continue
                }

                if isDirectory.boolValue && dsym.pathExtension.compare("dSYM", options: .caseInsensitive) != .orderedSame {
                    let dsyms = try? FileManager.default.contentsOfDirectory(at: dsym, includingPropertiesForKeys: nil, options: []).filter { $0.pathExtension.compare("dSYM", options: .caseInsensitive) == .orderedSame }

                    dSYMFiles.remove(at: i)

                    if let dsyms = dsyms, !dsyms.isEmpty {
                        dSYMFiles.insert(contentsOf: dsyms, at: i)
                        i += dsyms.count
                    }
                } else {
                    i += 1
                }
            }

            // Resolve all dSYM packages to DWARF binaries, remove those that don't have
            // exactly one binary, and filter out duplicates. If the input file doesn't have
            // the dSYM extension, assume that the user passed in the full path to the DWARF
            // file.
            i = 0
            while i < dSYMFiles.count {
                let dsym = dSYMFiles[i]
                guard dsym.pathExtension.compare("dSYM", options: .caseInsensitive) == .orderedSame else {
                    // Assume that this is a DWARF file
                    i += 1
                    continue
                }

                let dwarfFolder = dsym.appendingPathComponent("Contents").appendingPathComponent("Resources").appendingPathComponent("DWARF")

                guard let binaries = try? FileManager.default.contentsOfDirectory(at: dwarfFolder, includingPropertiesForKeys: nil, options: []), binaries.count == 1 else {
                    print("Skipping dSYM as there was expected to be exactly DWARF binary: \(dwarfFolder.path)")
                    dSYMFiles.remove(at: i)
                    continue
                }

                if i > 0 && dSYMFiles[0 ..< i].contains(binaries[0]) {
                    dSYMFiles.remove(at: i)
                    continue // duplicate
                }

                dSYMFiles[i] = binaries[0]
                i += 1
            }

            verboseLog("Processing input file: \(log.path)")
            verboseLog("Output: \(output.path)")
            verboseLog("Architecture: \(arch)")
            verboseLog("dSYMs: [\n    \(dSYMFiles.map { $0.path }.joined(separator: ",\n    "))\n]")

            var lines: [String] = []
            do {
                lines = try String(contentsOf: log).components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            } catch {
                abort(message: "Error while reading input file: \(error.localizedDescription)")
            }

            // Process lines
            for i in 0 ..< lines.count {
                let line = lines[i]
                if let match = symbolicatedLineRegex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.count)) {
                    guard let libraryRange = Range(match.range(at: 3), in: line),
                          let libraryAddressRange = Range(match.range(at: 7), in: line),
                          let callAddressRange = Range(match.range(at: 5), in: line) else {
                        continue
                    }

                    let library = String(line[libraryRange])
                    let libraryAddress = String(line[libraryAddressRange])
                    let callAddress = String(line[callAddressRange])

                    guard let dsym = dSYMFiles.first(where: { $0.lastPathComponent == library }) else {
                        // No dSYM to symbolicate this line
                        continue
                    }

                    guard let symbol = self.atos("-arch", arch, "-o", dsym.path, "-l", libraryAddress, callAddress)?.trimmingCharacters(in: .whitespacesAndNewlines), !symbol.isEmpty else {
                        continue
                    }

                    lines[i] = symbolicatedLineRegex.replacementString(for: match, in: line, offset: 0, template: "$1$2$3$4$5$6\(symbol)")
                }
            }

            do {
                try Data(lines.joined(separator: "\n").utf8).write(to: output, options: .atomic)
            } catch {
                abort(message: "Error while writing to the output: \(error.localizedDescription)")
            }
        }

        main.run()
    }

    // MARK: Private Methods

    private static func atos(_ args: String...) -> String? {
        let task = Process()
        let pipe = Pipe()
        let output = pipe.fileHandleForReading
        defer { output.closeFile() }

        // Configure (Ctrl + C) to send an event below
        signal(SIGINT, SIG_IGN)

        // Setup and run a DispatchSource to catch a (Ctrl + C) signal and call an event
        // handler
        let queue = DispatchQueue(label: "")
        let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: queue)
        sigint.setEventHandler {
            // If the user presses Ctrl + C then stop the task and exit
            task.interrupt()
            print("\n")
            exit(0)
        }
        sigint.resume()

        // Setup a new task to run `atos` for symbolicating a crash log
        task.launchPath = "/usr/bin/atos"
        task.arguments = args
        task.standardOutput = pipe

        task.launch()

        // Check if the task is still running on a 0.1 second interval. This ensures that
        // the ibtool task can print to the console and that Ctrl + C correctly aborts the
        // program
        while task.isRunning { Thread.sleep(forTimeInterval: 0.1) }
        guard task.terminationStatus == 0 else { exit(task.terminationStatus) }

        let outputData = output.readDataToEndOfFile()
        return String(data: outputData, encoding: .utf8)
    }

    private static func standardizingPath(_ path: String) -> URL {
        return URL(fileURLWithPath: (path.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) as NSString).standardizingPath)
    }

    private static func abort(message: String, help: Bool = false) -> Never {
        print(message)
        exit(EXIT_FAILURE)
    }

    private static func verboseLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        guard verbose else { return }
        print(items.map { String(describing: $0) }.joined(separator: separator), terminator: terminator)
    }
}

Main.main()
