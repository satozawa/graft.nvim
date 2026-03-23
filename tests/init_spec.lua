local helpers = require("tests.helpers")

describe("graft.setup", function()
  local graft = require("graft")

  before_each(function()
    -- Reset module state
    package.loaded["graft"] = nil
    package.loaded["graft.textobjects"] = nil
    package.loaded["graft.motions"] = nil
    package.loaded["graft.operations"] = nil
    package.loaded["graft.paste"] = nil
    graft = require("graft")
  end)

  it("creates FileType autocmd", function()
    graft.setup()
    local autocmds = vim.api.nvim_get_autocmds({
      group = "graft",
      event = "FileType",
    })
    assert.is_true(#autocmds > 0)
  end)

  it("sets shiftwidth on markdown buffer by default", function()
    graft.setup()
    local buf = helpers.create_md_buf({ "- test" })
    helpers.set_buf(buf)
    -- Trigger FileType autocmd
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_exec_autocmds("FileType", { buffer = buf })
    assert.are.equal(2, vim.bo[buf].shiftwidth)
    helpers.cleanup(buf)
  end)

  it("respects set_shiftwidth = false", function()
    graft.setup({ set_shiftwidth = false })
    local buf = helpers.create_md_buf({ "- test" })
    helpers.set_buf(buf)
    vim.bo[buf].shiftwidth = 4
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_exec_autocmds("FileType", { buffer = buf })
    assert.are.equal(4, vim.bo[buf].shiftwidth)
    helpers.cleanup(buf)
  end)

  it("registers Plug mappings", function()
    graft.setup()
    local maps = vim.api.nvim_get_keymap("n")
    local found_up = false
    local found_down = false
    for _, map in ipairs(maps) do
      if map.lhs == "<Plug>(graft-move-up)" then
        found_up = true
      end
      if map.lhs == "<Plug>(graft-move-down)" then
        found_down = true
      end
    end
    assert.is_true(found_up, "<Plug>(graft-move-up) should be registered")
    assert.is_true(found_down, "<Plug>(graft-move-down) should be registered")
  end)
end)
