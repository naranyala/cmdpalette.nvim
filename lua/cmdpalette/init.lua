local M = {}

M.config = {
  win = {
    height = 0.3,
    width = 0.8,
    border = "rounded",
  },
  sign = {
    text = ":",
  },
  buf = {
    filetype = "vim",
    syntax = "vim",
  },
}

local palette, buf

local function create_buf(list)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.cmd.bdelete()
  end
  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "cmdpalette")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", M.config.buf.filetype)
  vim.api.nvim_buf_set_option(buf, "syntax", M.config.buf.syntax)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)

  vim.api.nvim_buf_set_lines(buf, 1, -1, false, list)
end

local function create_win()
  local width = vim.api.nvim_get_option "columns"
  local height = vim.api.nvim_get_option "lines"

  local win_height = math.ceil(height * M.config.win.height)
  local win_width = math.ceil(width * M.config.win.width)
  local row = math.ceil((height - win_height) / 2 - 1)
  local col = math.ceil((width - win_width) / 2)

  local opts = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    border = M.config.win.border,
  }
  palette = vim.api.nvim_open_win(buf, true, opts)

  vim.api.nvim_win_set_option(palette, "cursorline", true)
end

function M.execute_cmd()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.fn.getline(cursor[1])
  vim.api.nvim_win_close(0, false)
  local ok, err = pcall(vim.cmd, line)
  if not ok then
    vim.api.nvim_notify(err, vim.log.levels.ERROR, {})
    return
  end
  vim.fn.histadd("cmd", line)
end

local function buf_keymap()
  local opts = { nowait = true, noremap = true, silent = true }
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<Cmd>quit<CR>", opts)
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<Cmd>quit<CR>", opts)
  vim.api.nvim_buf_set_keymap(buf, "i", "<CR>", "<Esc><Cmd>lua require'cmdpalette'.execute_cmd()<CR>", opts)
end

local function set_sign(len)
  vim.opt_local.signcolumn = "yes"
  vim.fn.sign_define("CmdPaletteSign", { text = M.config.sign.text, texthl = "CmdPaletteSign" })
  for i = 1, len do
    vim.fn.sign_place(0, "", "CmdPaletteSign", buf, { lnum = i })
  end
end

function M.open()
  local n = vim.fn.histnr "cmd"
  local cmd_list = {}
  for i = 1, n do
    cmd_list[i] = vim.fn.histget("cmd", i)
  end
  cmd_list = vim.fn.reverse(cmd_list)

  create_buf(cmd_list)
  create_win()
  buf_keymap()
  set_sign(#cmd_list)

  vim.opt_local.number = false

  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.cmd "startinsert"
end

function M.setup(conf)
  M.config = vim.tbl_deep_extend("force", M.config, conf or {})

  vim.api.nvim_set_hl(0, "CmdpaletteSign", { default = true, link = "NonText" })

  local cmdpalette = vim.api.nvim_create_augroup("cmdpalette", {})
  vim.api.nvim_create_autocmd("BufEnter", {
    group = cmdpalette,
    pattern = "cmdpalette",
    callback = function()
      local old_undolevels = vim.api.nvim_buf_get_option(0, "undolevels")
      vim.api.nvim_buf_set_option(0, "undolevels", -1)
      vim.cmd [[silent g/^qa\?!\?$/d_]]
      vim.cmd [[silent g/^wq\?a\?!\?$/d_]]
      vim.cmd [[silent 2,$g/^$/d_]]
      vim.api.nvim_buf_set_option(0, "undolevels", old_undolevels)
    end,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    group = cmdpalette,
    pattern = "cmdpalette",
    callback = function()
      vim.api.nvim_win_close(palette, false)
    end,
  })
end

return M