const std = @import("std");
const testing = std.testing;

pub const Tree = struct {
    root: ?*Node,

    pub fn init(allocator: std.mem.Allocator) !Tree {
        const rootNode = try allocator.create(Node);
        try rootNode.init(allocator, null, "Root node");
        return .{ .root = rootNode };
    }

    pub fn deinit(self: *Tree, allocator: std.mem.Allocator) void {
        if (self.root) |root| {
            root.deinit(allocator);
            allocator.destroy(root);
        }
    }
};

const Node = struct {
    parent: ?*Node,
    nodes: std.ArrayList(*Node),
    tag: []const u8,

    pub fn init(
        self: *Node,
        allocator: std.mem.Allocator,
        parent: ?*Node,
        tag: []const u8,
    ) !void {
        self.parent = parent;
        self.tag = tag;
        self.nodes = std.ArrayList(*Node).init(allocator);
    }

    pub fn deinit(self: *Node, allocator: std.mem.Allocator) void {
        for (self.nodes.items) |child| {
            child.deinit(allocator);
            allocator.destroy(child);
        }
        self.nodes.deinit();
    }

    pub fn push(self: *Node, node: *Node) !void {
        try self.nodes.append(node);
    }
};

fn recurse(node: *Node, visited: *std.ArrayList(*Node)) !void {
    try visited.append(node);
    std.debug.print("Tag: {s}\n", .{node.tag});
    for (node.nodes.items) |child| {
        try recurse(child, visited);
    }
}

fn walk(tree: *Tree, allocator: std.mem.Allocator) !void {
    var walked = std.ArrayList(*Node).init(allocator);
    defer walked.deinit();

    if (tree.root) |root| {
        try recurse(root, &walked);
    }
}

test "Create unary tree and walk over it" {
    const allocator = std.testing.allocator;

    std.debug.print("\n", .{});

    var tree = try Tree.init(allocator);
    defer tree.deinit(allocator);

    const node1 = try allocator.create(Node);
    try node1.init(allocator, tree.root, "Node 1");
    try tree.root.?.push(node1);

    const node2 = try allocator.create(Node);
    try node2.init(allocator, node1, "Node 2");
    try node1.push(node2);

    try walk(&tree, allocator);

    try testing.expect(true);
}

test "Create binary tree and walk over it" {
    const allocator = std.testing.allocator;

    std.debug.print("\n", .{});

    var tree = try Tree.init(allocator);
    defer tree.deinit(allocator);

    const rootNode = tree.root.?;

    const leftNode = try allocator.create(Node);
    try leftNode.init(allocator, rootNode, "Left Node");
    try rootNode.push(leftNode);

    const rightNode = try allocator.create(Node);
    try rightNode.init(allocator, rootNode, "Right Node");
    try rootNode.push(rightNode);

    const leftLeftNode = try allocator.create(Node);
    try leftLeftNode.init(allocator, leftNode, "Left Left Node");
    try leftNode.push(leftLeftNode);

    const leftRightNode = try allocator.create(Node);
    try leftRightNode.init(allocator, leftNode, "Left Right Node");
    try leftNode.push(leftRightNode);

    const rightLeftNode = try allocator.create(Node);
    try rightLeftNode.init(allocator, rightNode, "Right Left Node");
    try rightNode.push(rightLeftNode);

    const rightRightNode = try allocator.create(Node);
    try rightRightNode.init(allocator, rightNode, "Right Right Node");
    try rightNode.push(rightRightNode);

    try walk(&tree, allocator);

    try testing.expect(true);
}
