local M = {}
local timers = {}
local timer_file = vim.fn.stdpath('data') .. '/timers.json'

local function save_timers()
    local file = io.open(timer_file, 'w')
    file:write(vim.fn.json_encode(timers))
    file:close()
end

local function load_timers()
    local file, err = io.open(timer_file, 'r')
    if not file then return end
    local content = file:read('*all')
    timers = vim.fn.json_decode(content)
    file:close()
end

local function format_time(seconds)
    local hours = math.floor(seconds / 3600)
    seconds = seconds % 3600
    local minutes = math.floor(seconds / 60)
    seconds = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

function M.start_timer(tag)
    load_timers()
    if timers[tag] then
        if timers[tag].status == 'running' then
            print('Timer already running for tag:', tag)
            return
        else
            -- Continue where it left off
            timers[tag].start = os.time() - timers[tag].elapsed
            timers[tag].status = 'running'
            print('Resumed timer for tag:', tag)
        end
    else
        -- Start a new timer
        timers[tag] = { start = os.time(), elapsed = 0, status = 'running' }
        print('Started new timer for tag:', tag)
    end
    save_timers()
end

function M.stop_timer(tag)
    load_timers()
    if not timers[tag] or timers[tag].status == 'stopped' then
        print('No running timer for tag:', tag)
        return
    end
    local timer = timers[tag]
    timer.elapsed = os.time() - timer.start
    timer.status = 'stopped'
    save_timers()
    print(string.format('Stopped timer for tag: %s, elapsed time: %s', tag, format_time(timer.elapsed)))
end

function M.delete_timer(tag)
    load_timers()
    if not timers[tag] then
        print('No timer found for tag:', tag)
        return
    end
    timers[tag] = nil
    save_timers()
    print('Deleted timer for tag:', tag)
end

function M.get_latest_running_timer()
    load_timers()
    local latest_timer = nil
    for tag, timer in pairs(timers) do
        if timer.status == 'running' then
            if not latest_timer or timer.start > latest_timer.start then
                latest_timer = { tag = tag, elapsed = os.time() - timer.start + timer.elapsed }
            end
        end
    end
    if latest_timer then
        return string.format(' %s: %s', latest_timer.tag, format_time(latest_timer.elapsed))
    else
        return ''
    end
end

function M.current()
    return M.get_latest_running_timer()
end

function M.show_timers_popup()
    load_timers()
    local items = {}
    for tag, timer in pairs(timers) do
        local elapsed_time = timer.elapsed
        if timer.status == 'running' then
            elapsed_time = os.time() - timer.start + timer.elapsed
        end
        table.insert(items, {
            text = string.format('%s: %s (%s)', tag, format_time(elapsed_time), timer.status),
            tag = tag
        })
    end
    if #items == 0 then
        print('No timers running')
        return
    end
    vim.ui.select(items, {prompt = 'Timers:', format_item = function(item) return item.text end}, function(choice)
        if choice then
            print('Selected timer:', choice.tag)
        end
    end)
end

-- nvim commands prefix Timey

vim.api.nvim_create_user_command('TimeyStart', function(opts)
    M.start_timer(opts.args)
end, { nargs = 1 })

vim.api.nvim_create_user_command('TimeyStop', function(opts)
    M.stop_timer(opts.args)
end, { nargs = 1 })

vim.api.nvim_create_user_command('TimeyShow', function()
    M.show_timers_popup()
end, {})

vim.api.nvim_create_user_command('TimeyDelete', function(opts)
    M.delete_timer(opts.args)
end, { nargs = 1 })

load_timers()

return M
