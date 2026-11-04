local nav = require("util.herdr-nav")

return {
  {
    "herdr-nav",
    virtual = true,
    cond = nav.enabled(),
    keys = {
      { "<C-h>", function() nav.move("left") end, desc = "Navigate left" },
      { "<C-j>", function() nav.move("down") end, desc = "Navigate down" },
      { "<C-k>", function() nav.move("up") end, desc = "Navigate up" },
      { "<C-l>", function() nav.move("right") end, desc = "Navigate right" },
      { "<C-M-h>", function() nav.resize("left") end, desc = "Resize left" },
      { "<C-M-j>", function() nav.resize("down") end, desc = "Resize down" },
      { "<C-M-k>", function() nav.resize("up") end, desc = "Resize up" },
      { "<C-M-l>", function() nav.resize("right") end, desc = "Resize right" },
    },
  },
}
