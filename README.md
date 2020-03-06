Symbolicate
========

![License MIT](https://img.shields.io/github/license/SomeRandomiOSDev/Symbolicate)
![Swift](https://github.com/SomeRandomiOSDev/Symbolicate/workflows/Swift/badge.svg)

**Symbolicate** is a command line utility for symbolicating logs using DWARF/dSYM files 

Installation
--------

### Using [Mint](https://github.com/yonaskolb/Mint)

```bash
mint install SomeRandomiOSDev/Symbolicate
symbolicate <options>
```

### Using [Swiftbrew](https://github.com/swiftbrew/Swiftbrew)

```bash
swift brew install SomeRandomiOSDev/Symbolicate
symbolicate <options>
```

### Using [Swift Package Manager](https://swift.org/package-manager/)

```bash
git clone "https://github.com/SomeRandomiOSDev/Symbolicate.git"
cd Symbolicate
./symbolicate <options>
```

Use Case
--------

If you choose not to upload your applications' dSYM files along with your application to App Store Connect the crash logs that you receive for your application won't be symbolicated. Even when uploading, the symbolification process (at least from what I've observed) doesn't properly symbolicate the crash logs 100% of the time. This makes things particularly difficult to track down the source of the issue. 

This utility simplifies the process of manually symbolicating the crash logs in any case where the crash logs weren't properly symbolicated. Using this utility can convert a log like this:

```
Thread 0 Crashed:: Dispatch queue: com.apple.main-thread
0   symbolicate             0x000000010d6b46ef 0x10d63c000 + 493295
1   symbolicate             0x000000010d641548 0x10d63c000 + 21832
2   symbolicate             0x000000010d641e5d 0x10d63c000 + 24157
3   symbolicate             0x000000010d6416d0 0x10d63c000 + 22224
4   symbolicate             0x000000010d66fedd 0x10d63c000 + 212701
5   symbolicate             0x000000010d6702c6 0x10d63c000 + 213702
...
```

into:

```
Thread 0 Crashed:: Dispatch queue: com.apple.main-thread
0   symbolicate             0x0000000109a146ef closure #1 in variable initialization expression of static Main.logArgument + 239
1   symbolicate             0x00000001099a1548 Argument.parse(_:) + 504
2   symbolicate             0x00000001099a1e5d protocol witness for ArgumentDescriptor.parse(_:) in conformance Argument<A> + 13
3   symbolicate             0x00000001099a16d0 protocol witness for ArgumentDescriptor.parse(_:) in conformance Argument<A> + 16
4   symbolicate             0x00000001099cfedd closure #1 in command<A, B, C, D, E>(_:_:_:_:_:_:) + 1405
5   symbolicate             0x00000001099d02c6 partial apply for closure #1 in command<A, B, C, D, E>(_:_:_:_:_:_:) + 86
...
```

Usage
--------

```bash
./symbolicate [--verbose, -v] [--arch] [--output] log dysm...
```

* `log`: the path to the log file to symbolicate.
* `dysm`: one or more dSYM files to use for symbolicating the log.

* `--verbose` or `-v`: Enable verbose logging.
* `--arch`: (Optional) The architecture of the dSYM to use for symbolicating the log. If not provided, this defaults to `arm64`.
* `--output`: The file to write the symbolicated log to. If not provided, the symbolicated log is written back to the input file.

Contributing
--------

If you have need for a specific feature or you encounter a bug, please open an issue. If you extend the functionality of **Symbolicate** yourself or you feel like fixing a bug yourself, make your changes in a fork and submit a pull request.

TODO
--------

* Dynamically determine architecture based on the log file

Author
--------

Joseph Newton, somerandomiosdev@gmail.com

License
--------

**Symbolicate** is available under the MIT license. See the `LICENSE` file for more info.
