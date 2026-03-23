-- Ordered list auto-renumbering.
-- Called after any structural mutation (move, paste, delete).
-- Supports per-sibling-group renumbering (mixed ordered/unordered lists)
-- and digit-count indent adjustment (9→10 marker width changes).

local tree = require("graft.tree")

local M = {}

--- Adjust indentation of descendant lines when marker width changes.
--- Only adjusts lines BELOW the marker line itself (children/descendants).
--- @param item TSNode The list_item whose marker changed width
--- @param old_width integer Previous marker text width (e.g., 3 for "9. ")
--- @param new_width integer New marker text width (e.g., 4 for "10. ")
--- @param bufnr integer
local function adjust_descendant_indent(item, old_width, new_width, bufnr)
  local delta = new_width - old_width
  if delta == 0 then
    return
  end

  local start_row, end_row = tree.get_subtree_range(item)
  -- Only adjust lines after the marker line (descendants, not the item itself)
  local desc_start = start_row + 1
  if desc_start > end_row then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, desc_start, end_row + 1, false)
  local padding = delta > 0 and string.rep(" ", delta) or nil
  for i, line in ipairs(lines) do
    if line:match("%S") then
      if delta > 0 then
        lines[i] = padding .. line
      else
        -- Remove up to |delta| leading spaces
        local ws = line:match("^(%s*)")
        local remove = math.min(-delta, #ws)
        lines[i] = line:sub(remove + 1)
      end
    end
  end
  vim.api.nvim_buf_set_lines(bufnr, desc_start, end_row + 1, false, lines)
end

--- Renumber a single consecutive run of ordered items.
--- Processes last-to-first to preserve positions during marker replacement.
--- Adjusts descendant indentation when marker width changes.
--- @param run table[] Array of {item, marker} entries
--- @param delimiter string "." or ")"
--- @param bufnr integer
local function renumber_run(run, delimiter, bufnr)
  for i = #run, 1, -1 do
    local entry = run[i]
    local marker = entry.marker
    local sr, sc, er, ec = marker:range()
    local new_text = tostring(i) .. delimiter .. " "
    local old_text = vim.api.nvim_buf_get_text(bufnr, sr, sc, er, ec, {})[1]
    if new_text ~= old_text then
      -- Adjust descendant indent BEFORE changing the marker, while positions are valid
      adjust_descendant_indent(entry.item, #old_text, #new_text, bufnr)
      -- Now replace the marker text
      -- Re-fetch range after possible indent adjustment (marker line itself is unchanged)
      vim.api.nvim_buf_set_text(bufnr, sr, sc, er, ec, { new_text })
    end
  end
end

--- Renumber all ordered list items in the parent list of the given node.
--- @param node TSNode Any list_item in the affected list
--- @param bufnr? integer
function M.renumber_parent_list(node, bufnr)
  bufnr = bufnr or 0
  local parent = tree.parent_list(node)
  if not parent then
    return
  end
  M.renumber_list(parent, bufnr)
end

--- Renumber all ordered list items in a list node.
--- Handles mixed ordered/unordered lists by renumbering consecutive
--- runs of ordered items independently. Unordered items break runs.
--- @param list_node TSNode A list node
--- @param bufnr? integer
function M.renumber_list(list_node, bufnr)
  bufnr = bufnr or 0

  -- Collect runs of consecutive ordered items
  local runs = {}
  local current_run = {}
  local current_marker_type = nil

  for i = 0, list_node:named_child_count() - 1 do
    local child = list_node:named_child(i)
    if child:type() == tree.LIST_ITEM then
      local marker = tree.get_marker(child)
      if marker and tree.ORDERED_MARKERS[marker:type()] then
        if not current_marker_type then
          current_marker_type = marker:type()
        end
        current_run[#current_run + 1] = { item = child, marker = marker }
      else
        -- Unordered item: flush current run if non-empty
        if #current_run > 0 then
          runs[#runs + 1] = { items = current_run, marker_type = current_marker_type }
          current_run = {}
          current_marker_type = nil
        end
      end
    end
  end
  -- Flush final run
  if #current_run > 0 then
    runs[#runs + 1] = { items = current_run, marker_type = current_marker_type }
  end

  if #runs == 0 then
    return
  end

  -- Process runs from last to first (bottom-up) to preserve positions
  for i = #runs, 1, -1 do
    local run = runs[i]
    local delimiter = run.marker_type == "list_marker_dot" and "." or ")"
    renumber_run(run.items, delimiter, bufnr)
  end
end

return M
