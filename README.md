# mkdatauri

A simple command-line tool to create `data:` URIs from files or standard input.

## Features

* Read from a file or standard input.
* Set custom MIME types and character sets.
* Encode with base 64 or percent encoding.
* Option to suppress the trailing newline.

## Installation

To build the project, run the following command:

```sh
zig build --release=small
```

Or:

```sh
zig build --release=fast
```

Resulting executable will be in `zig-out/bin/mkdatauri`.

## License

This project is licensed under the [2-Clause BSD License](LICENSE).
