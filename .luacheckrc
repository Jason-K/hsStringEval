std = "luajit"

unused_args = false

files = files or {}

files["src/**/*.lua"] = {
    read_globals = {
        "hs",
        table = {
            fields = { "unpack" },
        },
    },
    ignore = {
        "611", -- allow empty blocks used in stubs
    }
}

files["test/**/*.lua"] = {
    read_globals = {
        "hs",
        "describe",
        "it",
        "before_each",
        "after_each",
        "assert",
        package = {
            fields = { "searchers" },
        },
    },
}
