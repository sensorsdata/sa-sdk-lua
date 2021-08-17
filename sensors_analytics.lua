
local ffi = require "ffi"
local debug = require "debug"

--[[
ffi.load() 会根据 C 链接库的地址开始寻找，这里使用的是相对路径。
如果找不到可通过如下方式进行解决：
1. 增加 C 链接库目录
    1.1 vim /etc/ld.so.conf # 增加 .so 链接库目录
    1.2 ldconfig # 保存后执行 ldconfig
2. 将 ffi.load() 中的参数指定为 .so 的绝对路径
]]--
local sa_c = ffi.load('./libSensorsAnalyticsC.so')

local ffi_new = ffi.new
local debug_getinfo = debug.getinfo
local debug_traceback = debug.traceback
local str_sub = string.sub
local tostring = tostring
local type = type
local pcall = pcall
local xpcall = xpcall
local pairs = pairs
local print = print

local new_tab
do
    local ok
    ok, new_tab = pcall(require, "table.new") -- 需要 luajit-2.1.0-beta3
    if not ok then
        new_tab = function(narr, nrec) return {} end
    end
end

local clear_tab
do
    local ok
    ok, clear_tab = pcall(require, "table.clear") -- 需要 luajit-2.1.0-beta3
    if not ok then
        clear_tab = function (tab)
                    for k, _ in pairs(tab) do
                        tab[k] = nil
                    end
                end
    end
end

--========================================================================
--
--              Miscellaneous Utility Functions
--
--========================================================================

local function check_param(param, expect_type)
    if type(param) ~= expect_type then
        print(debug_traceback("【SA Error】: parameter <" .. tostring(param) .. "> do not match the expected type <" .. tostring(expect_type) .. ">"))
        return false
    else
        return true
    end
end

local function debug_info()
    local path = debug_getinfo(3, "S").source
    -- 移除 path 中的 @ 符号
    local file_name
    if path ~= nil and #path > 1 then
        file_name = str_sub(path, 2, -1)
    end
    
    -- 如果是从文件直接调用，则返回调用链中最近的一个函数
    local function_name = debug_getinfo(3, "n").name
    if function_name == nil then
        function_name = debug_getinfo(2, "n").name
    end
    
    local line_index = debug_getinfo(3, "l").currentline
    if line_index == nil then
        line_index = 0
    end
    
    return file_name, function_name, line_index
end

local function error_handler(err)
    print(debug_traceback("【SA Error】: " .. tostring(err)))
end

--========================================================================
--
--              Implementation of "export" functions
--
--========================================================================

-- 定义一个 table，封装 C SDK 相关接口
local _M = new_tab(0, 16)

_M.version = "0.0.1"
_M.new_tab = new_tab
_M.clear_tab = clear_tab

_M.FFI_OK = 0
_M.FFI_RESULT_ERROR = 1
_M.FFI_INVALID_PARAMETER_ERROR = 2

ffi.cdef[[
typedef enum {
  SA_FALSE,
  SA_TRUE
} SABool;

// 定义 Consumer 的操作.
typedef int (*sa_consumer_send)(void* this_, const char* event, unsigned long length);
typedef int (*sa_consumer_flush)(void* this_);
typedef int (*sa_consumer_close)(void* this_);

struct SAConsumerOp {
  sa_consumer_send send;
  sa_consumer_flush flush;
  sa_consumer_close close;
};

struct SAConsumer {
  struct SAConsumerOp op;
  // Consumer 私有数据.
  void* this_;
};

// LoggingConsumer 用于将事件以日志文件的形式记录在本地磁盘中.
typedef struct SAConsumer SALoggingConsumer;

// 初始化 Logging Consumer
//
// @param file_name<in>    日志文件名，例如: /data/logs/http.log
// @param consumer<out>    SALoggingConsumer 实例
//
// @return SA_OK 初始化成功，否则初始化失败.
int sa_init_logging_consumer(const char* file_name, SALoggingConsumer** consumer);
]]
function _M.sa_init_logging_consumer(file_name)
    local check_pass = check_param(file_name, "string")
    if not check_pass then
        return FFI_INVALID_PARAMETER_ERROR, nil
    end
    
    if #file_name == 0 then
        print(debug_traceback("【SA Error】: the length of file name is 0"))
        return FFI_INVALID_PARAMETER_ERROR, nil
    end
  
    local consumer_array = ffi_new("SALoggingConsumer *[1]")
    local ok, res = xpcall(sa_c.sa_init_logging_consumer, error_handler, file_name, consumer_array)
    if ok then
        return res, consumer_array[0]
    else
        return FFI_RESULT_ERROR, nil
    end
end

ffi.cdef[[
// SensorsAnalytics 对象.
typedef struct SensorsAnalytics SensorsAnalytics;

// 初始化 Sensors Analytics 对象
//
// @param consumer<in>         日志数据的“消费”方式
// @param sa<out>              初始化的 Sensors Analytics 实例
//
// @return SA_OK 初始化成功，否则初始化失败.
int sa_init(struct SAConsumer* consumer, struct SensorsAnalytics** sa);
]]
function _M.sa_init(consumer)
    local check_pass = check_param(consumer, "cdata")
    if not check_pass then
        return FFI_INVALID_PARAMETER_ERROR, nil
    end
  
    local sa_array = ffi_new("SensorsAnalytics *[1]")
    local ok, res = xpcall(sa_c.sa_init, error_handler, consumer, sa_array)
    if ok then
        return res, sa_array[0]
    else
        return FFI_RESULT_ERROR, nil
    end
end

ffi.cdef[[
// 释放 Sensors Analytics 对象
//
// @param sa<in/out>           释放的 Sensors Analytics 实例.
void sa_free(struct SensorsAnalytics* sa);
]]
function _M.sa_free(sa)
    local check_pass = check_param(sa, "cdata")
    if not check_pass then
        return
    end
    
    xpcall(sa_c.sa_free, error_handler, sa)
end

ffi.cdef[[
// 同步 Sensors Analytics 的状态，将发送 Consumer 的缓存中所有数据
//
// @param sa<in/out>           同步的 Sensors Analytics 实例.
void sa_flush(struct SensorsAnalytics* sa);
]]
function _M.sa_flush(sa)
    local check_pass = check_param(sa, "cdata")
    if not check_pass then
        return
    end
    
    xpcall(sa_c.sa_flush, error_handler, sa)
end

ffi.cdef[[
// 事件属性或用户属性.
typedef struct SANode SAProperties;

// 初始化事件属性或用户属性对象
//
// @return SAProperties 对象，NULL表示初始化失败.
SAProperties* sa_init_properties(void);
]]
function _M.sa_init_properties()
    local ok, res = xpcall(sa_c.sa_init_properties, error_handler)
    if ok then
        return res
    else
        return nil
    end
end

ffi.cdef[[
// 释放事件属性或用户属性对象
//
// @param properties<out>   被释放的 SAProperties 对象.
void sa_free_properties(SAProperties* properties);
]]
function _M.sa_free_properties(properties)
    local check_pass = check_param(properties, "cdata")
    if not check_pass then
        return
    end
    
    xpcall(sa_c.sa_free_properties, error_handler, properties)
end

ffi.cdef[[
// 向事件属性或用户属性添加 Bool 类型的属性
//
// @param key<in>           属性名称
// @param bool_<in>         SABool 对象，属性值
// @param properties<out>   SAProperties 对象
//
// @return SA_OK 添加成功，否则失败.
int sa_add_bool(const char* key, SABool bool_, SAProperties* properties);
]]
function _M.sa_add_bool(key, value, properties)
    local check_pass = check_param(key, "string") and check_param(value, "boolean") and check_param(properties, "cdata")
    if not check_pass then
        return FFI_INVALID_PARAMETER_ERROR
    end
  
    local sa_value = value and 1 or 0
    local ok, res = xpcall(sa_c.sa_add_bool, error_handler, key, sa_value, properties)
    if ok then
        return res
    else
        return FFI_RESULT_ERROR
    end
end

ffi.cdef[[
// 向事件属性或用户属性添加 Number 类型的属性
//
// @param key<in>           属性名称
// @param number_<in>       属性值
// @param properties<out>   SAProperties 对象
//
// @return SA_OK 添加成功，否则失败.
int sa_add_number(const char* key, double number_, SAProperties* properties);
]]
function _M.sa_add_number(key, value, properties)
    local check_pass = check_param(key, "string") and check_param(value, "number") and check_param(properties, "cdata")
    if not check_pass then
        return FFI_INVALID_PARAMETER_ERROR
    end
    
    local ok, res = xpcall(sa_c.sa_add_number, error_handler, key, value, properties)
    if ok then
        return res
    else
        return FFI_RESULT_ERROR
    end
end

ffi.cdef[[
// 向事件属性或用户属性添加 long integer 类型的属性
//
// @param key<in>           属性名称
// @param number_<in>       属性值
// @param properties<out>   SAProperties 对象
//
// @return SA_OK 添加成功，否则失败.
int sa_add_int(const char* key, long long int_, SAProperties* properties);
]]
function _M.sa_add_int(key, value, properties)
    local check_pass = check_param(key, "string") and check_param(value, "number") and check_param(properties, "cdata")
    if not check_pass then
        return FFI_INVALID_PARAMETER_ERROR
    end
    
    local ok, res = xpcall(sa_c.sa_add_int, error_handler, key, value, properties)
    if ok then
        return res
    else
        return FFI_RESULT_ERROR
    end
end

ffi.cdef[[
// 向事件属性或用户属性添加 Date 类型的属性
//
// @param key<in>           属性名称
// @param seconds<in>       时间戳，单位为秒
// @param microseconds<in>  时间戳中毫秒部分
// @param properties<out>   SAProperties 对象
//
// @return SA_OK 添加成功，否则失败.
int sa_add_date(const char* key, long senconds, int microseconds, SAProperties* properties);
        
]]
function _M.sa_add_date(key, seconds, microseconds, properties)  
    local check_pass = check_param(key, "string") and check_param(seconds, "number") and check_param(microseconds, "number") and check_param(properties, "cdata")
    if not check_pass then
        return FFI_INVALID_PARAMETER_ERROR
    end
    
    if seconds < 0 or microseconds < 0 then
        print(debug_traceback("【SA Error】: seconds or microseconds is less than 0"))
        return FFI_INVALID_PARAMETER_ERROR
    end
    
    local ok, res = xpcall(sa_c.sa_add_date, error_handler, key, seconds, microseconds, properties)
    if ok then
        return res
    else
        return FFI_RESULT_ERROR
    end
end


ffi.cdef[[
// 向事件属性或用户属性添加 String 类型的属性
//
// @param key<in>           属性名称
// @param string_<in>       字符串的句柄
// @param length<in>        字符串长度
// @param properties<out>   SAProperties 对象
//
// @return SA_OK 添加成功，否则失败.
int sa_add_string(
        const char* key,
        const char* string_,
        unsigned int length,
        SAProperties* properties);
]]
-- 注意：这里的参数 length 最终会传递到 C SDK 中，因此需要按照 C 字符串取长度（尤其是带有 \0 的字符）
function _M.sa_add_string(key, string, length, properties)
    local check_pass = check_param(key, "string") and check_param(string, "string") and check_param(length, "number") and check_param(properties, "cdata")
    if not check_pass then
        return FFI_INVALID_PARAMETER_ERROR
    end
    
    if length < 0 then
        print(debug_traceback("【SA Error】: the length of string is less than 0"))
        return FFI_INVALID_PARAMETER_ERROR
    end
    
    local ok, res = xpcall(sa_c.sa_add_string, error_handler, key, string, length, properties)
    if ok then
        return res
    else
        return FFI_RESULT_ERROR
    end
end

ffi.cdef[[
// 向事件属性或用户属性的 List 类型的属性中插入新对象，对象必须是 String 类型的
//
// @param key<in>           属性名称
// @param string_<in>       字符串的句柄
// @param length<in>        字符串长度
// @param properties<out>   SAProperties 对象
//
// @return SA_OK 添加成功，否则失败.
int sa_append_list(
        const char* key,
        const char* string_,
        unsigned int length,
        SAProperties* properties);
]]
function _M.sa_append_list(key, string, length, properties)
    local check_pass = check_param(key, "string") and check_param(string, "string") and check_param(length, "number") and check_param(properties, "cdata")
    if not check_pass then
        return FFI_INVALID_PARAMETER_ERROR
    end
    
    if length < 0 then
        print(debug_traceback("【SA Error】: the length of string is less than 0"))
        return FFI_INVALID_PARAMETER_ERROR
    end
    
    local ok, res = xpcall(sa_c.sa_append_list, error_handler, key, string, length, properties)
    if ok then
        return res
    else
        return FFI_RESULT_ERROR
    end
end

ffi.cdef[[
// 设置事件的一些公共属性，当 track 的 properties 和 super properties 有相同的 key 时，将采用 track 的.
int sa_register_super_properties(const SAProperties* properties, struct SensorsAnalytics* sa);
]]
function _M.sa_register_super_properties(properties, sa)
    local check_pass = check_param(properties, "cdata") and check_param(sa, "cdata")
    if not check_pass then
        return FFI_INVALID_PARAMETER_ERROR
    end
    
    local ok, res = xpcall(sa_c.sa_register_super_properties, error_handler, properties, sa)
    if ok then
        return res
    else
        return FFI_RESULT_ERROR
    end
end

ffi.cdef[[
// 删除事件的一个公共属性.
int sa_unregister_super_properties(const char* key, struct SensorsAnalytics* sa);
]]
function _M.sa_unregister_super_properties(key, sa)
    local check_pass = check_param(key, "string") and check_param(sa, "cdata")
    if not check_pass then
        return FFI_INVALID_PARAMETER_ERROR
    end
    
    local ok, res = xpcall(sa_c.sa_unregister_super_properties, error_handler, key, sa)
    if ok then
        return res
    else
        return FFI_RESULT_ERROR
    end
end

ffi.cdef[[
// 删除事件的所有公共属性.
int sa_clear_super_properties(struct SensorsAnalytics* sa);
]]
function _M.sa_clear_super_properties(sa)
    local check_pass = check_param(sa, "cdata")
    if not check_pass then
        return FFI_INVALID_PARAMETER_ERROR
    end
    
    local ok, res = xpcall(sa_c.sa_clear_super_properties, error_handler, sa)
    if ok then
        return res
    else
        return FFI_RESULT_ERROR
    end
end

ffi.cdef[[
// 跟踪一个用户的行为
//
// @param distinct_id<in>      用户ID
// @param event<in>            事件名称
// @param properties<in>       事件属性，SAProperties 对象，NULL 表示无事件属性
// @param sa<in/out>           SensorsAnalytics 实例
//
// @return SA_OK 追踪成功，否则追踪失败.
int _sa_track(
        const char* distinct_id,
        const char* event,
        const SAProperties* properties,
        const char* __file__,
        const char* __function__,
        unsigned long __line__,
        struct SensorsAnalytics* sa);
]]
function _M.sa_track(distinct_id, event, properties, sa)
    if properties ~= nil then
        local check_properties_pass = check_param(properties, "cdata")
        if not check_properties_pass then
            return FFI_INVALID_PARAMETER_ERROR
        end
    end
    
    local check_pass = check_param(distinct_id, "string") and check_param(event, "string") and check_param(sa, "cdata")
    if not check_pass then
        return FFI_INVALID_PARAMETER_ERROR
    end
  
    local file_name, function_name, line_index = debug_info()
    
    local ok, res = xpcall(sa_c._sa_track, error_handler, distinct_id, event, properties, file_name, function_name, line_index, sa)
    if ok then
        return res
    else
        return FFI_RESULT_ERROR
    end
end

ffi.cdef[[
// 关联匿名用户和注册用户，这个接口是一个较为复杂的功能，请在使用前先阅读相关说明:
//
//   http://www.sensorsdata.cn/manual/track_signup.html
//
// 并在必要时联系我们的技术支持人员。
//
// @param distinct_id<in>       用户的注册 ID
// @param origin_id<in>         被关联的用户匿名 ID
// @param properties<in>        事件属性，NULL 表示无事件属性
// @param sa<in/out>            SensorsAnalytics 对象
//
// @return SA_OK 追踪关联事件成功，否则失败.
int _sa_track_signup(
        const char* distinct_id,
        const char* origin_id,
        const SAProperties* properties,
        const char* __file__,
        const char* __function__,
        unsigned long __line__,
        struct SensorsAnalytics* sa);
]]
function _M.sa_track_signup(distinct_id, origin_id, properties, sa)
    if properties ~= nil then
        local check_properties_pass = check_param(properties, "cdata")
        if not check_properties_pass then
            return FFI_INVALID_PARAMETER_ERROR
        end
    end
    
    local check_pass = check_param(distinct_id, "string") and check_param(origin_id, "string") and check_param(sa, "cdata")
    if not check_pass then
        return FFI_INVALID_PARAMETER_ERROR
    end
  
    local file_name, function_name, line_index = debug_info()
    
    local ok, res = xpcall(sa_c._sa_track_signup, error_handler, distinct_id, origin_id, properties, file_name, function_name, line_index, sa)
    if ok then
        return res
    else
        return FFI_RESULT_ERROR
    end
end

ffi.cdef[[
// 设置用户属性，如果某个属性已经在该用户的属性中存在，则覆盖原有属性
//
// @param distinct_id<in>       用户 ID
// @param properties<in>        用户属性
// @param sa<in/out>            SensorsAnalytics 对象
//
// @return SA_OK 设置成功，否则失败.
int _sa_profile_set(
        const char* distinct_id,
        const SAProperties* properties,
        const char* __file__,
        const char* __function__,
        unsigned long __line__,
        struct SensorsAnalytics* sa);
]]
function _M.sa_profile_set(distinct_id, properties, sa)
    local check_pass = check_param(distinct_id, "string") and check_param(properties, "cdata") and check_param(sa, "cdata")
    if not check_pass then
        return FFI_INVALID_PARAMETER_ERROR
    end
  
    local file_name, function_name, line_index = debug_info()
    
    local ok, res = xpcall(sa_c._sa_profile_set, error_handler, distinct_id, properties, file_name, function_name, line_index, sa)
    if ok then
        return res
    else
        return FFI_RESULT_ERROR
    end
end

ffi.cdef[[
// 设置用户属性，如果某个属性已经在该用户的属性中存在，则不设置该属性
//
// @param distinct_id<in>       用户 ID
// @param properties<in>        用户属性
// @param sa<in/out>            SensorsAnalytics 对象
//
// @return SA_OK 设置成功，否则失败.
int _sa_profile_set_once(
        const char* distinct_id,
        const SAProperties* properties,
        const char* __file__,
        const char* __function__,
        unsigned long __line__,
        struct SensorsAnalytics* sa);
]]
function _M.sa_profile_set_once(distinct_id, properties, sa)
    local check_pass = check_param(distinct_id, "string") and check_param(properties, "cdata") and check_param(sa, "cdata")
    if not check_pass then
        return FFI_INVALID_PARAMETER_ERROR
    end
  
    local file_name, function_name, line_index = debug_info()
    
    local ok, res = xpcall(sa_c._sa_profile_set_once, error_handler, distinct_id, properties, file_name, function_name, line_index, sa)
    if ok then
        return res
    else
        return FFI_RESULT_ERROR
    end
end

ffi.cdef[[
// 增加或减少用户属性中的 Number 类型属性的值
//
// @param distinct_id<in>       用户 ID
// @param properties<in>        用户属性，必须为 Number 类型的属性
// @param sa<in/out>            SensorsAnalytics 对象
//
// @return SA_OK 设置成功，否则失败.
int _sa_profile_increment(
        const char* distinct_id,
        const SAProperties* properties,
        const char* __file__,
        const char* __function__,
        unsigned long __line__,
        struct SensorsAnalytics* sa);
]]
function _M.sa_profile_increment(distinct_id, properties, sa)
    local check_pass = check_param(distinct_id, "string") and check_param(properties, "cdata") and check_param(sa, "cdata")
    if not check_pass then
        return FFI_INVALID_PARAMETER_ERROR
    end
  
    local file_name, function_name, line_index = debug_info()
    
    local ok, res = xpcall(sa_c._sa_profile_increment, error_handler, distinct_id, properties, file_name, function_name, line_index, sa)
    if ok then
        return res
    else
        return FFI_RESULT_ERROR
    end
end

ffi.cdef[[
// 向用户属性中的 List 属性增加新元素
//
// @param distinct_id<in>       用户 ID
// @param properties<in>        用户属性，必须为 List 类型的属性
// @param sa<in/out>            SensorsAnalytics 对象
//
// @return SA_OK 设置成功，否则失败.
int _sa_profile_append(
        const char* distinct_id,
        const SAProperties* properties,
        const char* __file__,
        const char* __function__,
        unsigned long __line__,
        struct SensorsAnalytics* sa);
]]
function _M.sa_profile_append(distinct_id, properties, sa)
    local check_pass = check_param(distinct_id, "string") and check_param(properties, "cdata") and check_param(sa, "cdata")
    if not check_pass then
        return FFI_INVALID_PARAMETER_ERROR
    end
  
    local file_name, function_name, line_index = debug_info()
    
    local ok, res = xpcall(sa_c._sa_profile_append, error_handler, distinct_id, properties, file_name, function_name, line_index, sa)
    if ok then
        return res
    else
        return FFI_RESULT_ERROR
    end
end

ffi.cdef[[
// 删除某用户的一个属性
//
// @param distinct_id<in>       用户 ID
// @param key<in>               用户属性名称
// @param sa<in/out>            SensorsAnalytics 对象
//
// @return SA_OK 设置成功，否则失败.
int _sa_profile_unset(
        const char* distinct_id,
        const char* key,
        const char* __file__,
        const char* __function__,
        unsigned long __line__,
        struct SensorsAnalytics* sa);
]]
function _M.sa_profile_unset(distinct_id, key, sa)
    local check_pass = check_param(distinct_id, "string") and check_param(key, "string") and check_param(sa, "cdata")
    if not check_pass then
        return FFI_INVALID_PARAMETER_ERROR
    end
  
    local file_name, function_name, line_index = debug_info()
    
    local ok, res = xpcall(sa_c._sa_profile_unset, error_handler, distinct_id, key, file_name, function_name, line_index, sa)
    if ok then
        return res
    else
        return FFI_RESULT_ERROR
    end
end

ffi.cdef[[
// 删除某用户所有属性
//
// @param distinct_id<in>       用户 ID
// @param sa<in/out>            SensorsAnalytics 对象
//
// @return SA_OK 设置成功，否则失败.
int _sa_profile_delete(
        const char* distinct_id,
        const char* __file__,
        const char* __function__,
        unsigned long __line__,
        struct SensorsAnalytics* sa);
]]
function _M.sa_profile_delete(distinct_id, sa)
    local check_pass = check_param(distinct_id, "string") and check_param(sa, "cdata")
    if not check_pass then
        return FFI_INVALID_PARAMETER_ERROR
    end
  
    local file_name, function_name, line_index = debug_info()
    
    local ok, res = xpcall(sa_c._sa_profile_delete, error_handler, distinct_id, file_name, function_name, line_index, sa)
    if ok then
        return res
    else
        return FFI_RESULT_ERROR
    end
end


return _M
