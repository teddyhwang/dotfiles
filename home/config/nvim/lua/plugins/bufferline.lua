return {
  {
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        close_command = function(n)
          require("snacks").bufdelete(n)
        end,
        right_mouse_command = function(n)
          require("snacks").bufdelete(n)
        end,
      },
    },
  },
}
