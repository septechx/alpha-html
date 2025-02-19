# α-html

## Installing

First run:

```sh
zig fetch --save git+https://github.com/septechx/alpha-html#0.1.1
```

Then add this to your `build.zig` before `b.installArtifact(exe)`:

```zig
const @"alpha-html" = b.dependency("alpha-html", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("alpha-html", @"alpha-html".module("alpha-html"));

```
