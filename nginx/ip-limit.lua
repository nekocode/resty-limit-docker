local pool = ngx.shared["ip_limit_store"]

-- 读取配置
local pool_max_size = ngx.var._pool_max_size
if pool_max_size then
  pool_max_size = tonumber(pool_max_size)
end

-- 获取客户端真实 ip
-- macOS 下会无法获取真实 ip: https://forums.docker.com/t/getting-real-ip-inside-container/17337/5
local function get_client_ip()
  local header = ngx.req.get_headers()["x-forwarded-for"]
  local real_ip = '0.0.0.0'
  if not header then
    real_ip = ngx.var.remote_addr or real_ip
  else
    if type(header) == "table" then
      real_ip = header[1]
    else
      real_ip = header
    end
  end
  return real_ip
end

-- 计算 table 的大小
local function len_table(table)
  local i = 0
  for k in pairs(table) do
    i = i + 1
  end
  return i
end

-- 添加进 ip 池
local function add_ip(ip)
  -- 判断是否已在 ip 池内
  local count = pool:get(ip)
  if count then
    if count > 0 then
      pool:set(ip, count + 1)
      return true
    else
      pool:delete(ip)
    end
  end

  -- 检查 ip 池大小
  local all_keys = pool:get_keys(0)
  local pool_size = len_table(all_keys)
  if pool_size < pool_max_size then
    pool:set(ip, 1)
    return true
  end

  return false
end

-- 从 ip 池中移除
local function remove_ip(ip)
  -- 判断是否已在 ip 池内
  local count = pool:get(ip)
  if count then
    if count > 1 then
      pool:set(ip, count - 1)
    elseif count == 1 then
      pool:delete(ip)
    end
  end
end

---------------
-- 以下为导出对象
---------------

local _M = {}

-- 连接进来时
function _M.incoming()
  -- pool_max_size 未设置不进行限制
  -- 对于内部重定向或子请求，不进行限制。因为这些并不是真正对外的请求。
  if (not pool_max_size) or ngx.req.is_internal() then
    return true, nil
  end

  local ip = get_client_ip()
  local success = add_ip(ip)
  if success then
    -- 放到 header 里，方便后面进行 remove
    ngx.req.set_header('--incoming-ip', ip)
  end

  return success, ip
end

-- 连接退出时
function _M.leaving()
  if (not pool_max_size) or ngx.req.is_internal() then
    return
  end

  local ip = ngx.req.get_headers()['--incoming-ip']
  if not ip then
    return
  end
  remove_ip(ip)
end

return _M
