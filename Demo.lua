local ffi = require 'ffi'
local sensors_analytics = require "sensors_analytics"

local SA_FFI_OK = sensors_analytics.FFI_OK
local error = error
local strlen = string.len

local consumer_res, consumer = sensors_analytics.sa_init_logging_consumer("demo.out")
if consumer_res ~= SA_FFI_OK then
    print("Failed to initialize the consumer.")
    return
end

local sa_res, sa = sensors_analytics.sa_init(consumer)
if sa_res ~= SA_FFI_OK then
    print("Failed to initialize the SDK.")
    return
end

--[[
注意：Demo 中使用了断言是为了调试方便，实际使用过程中可以根据需要进行异常处理
]]--

local properties

--[[ 
公共属性
]]--
do
    properties = sensors_analytics.sa_init_properties()
    if nil == properties then
        return error("Failed to initialize the properties.")
    end

    assert(SA_FFI_OK == sensors_analytics.sa_add_string("super_propertie_A", "AAA", strlen("AAA"), properties))
    assert(SA_FFI_OK == sensors_analytics.sa_add_string("super_propertie_B", "BBB", strlen("BBB"), properties))
    assert(SA_FFI_OK == sensors_analytics.sa_register_super_properties(properties, sa))
    assert(SA_FFI_OK == sensors_analytics.sa_unregister_super_properties("super_propertie_A", sa))
    assert(SA_FFI_OK == sensors_analytics.sa_clear_super_properties(sa))

    sensors_analytics.sa_free_properties(properties)
end

--[[
在这个 Demo 中，我们以一个典型的电商产品为例，描述一个用户从匿名访问网站，到下单购买商品，再到申请售后服务，
这样一个整个环节，使用 Sensors Analytics（以下简称 SA）的产品，应该如何记录日志。

特别需要注意的是，这个 Demo 只是描述 SA 的数据记录能力，并不是说使用者要完全照搬这些 Event 和 Property
的设计，使用者还是需要结合自己产品的实际需要，来做相应的设计和规划
]]--

-- 1. 用户匿名访问网站.
local cookie_id = "ABCDEF123456789"   -- 用户未登录时，可以使用产品自己生成的cookieId来标注用户.

--[[
1.1 访问首页

前面有$开头的property字段，是SA提供给用户的预置字段
对于预置字段，已经确定好了字段类型和字段的显示名.
]]--
do
    properties = sensors_analytics.sa_init_properties()
    if nil == properties then
        return error("Failed to initialize the properties.")
    end

    -- 通过请求中的UA，可以解析出用户使用设备的操作系统是 iOS 的.
    assert(SA_FFI_OK == sensors_analytics.sa_add_string("$os", "iOS", strlen("iOS"), properties))
    -- 操作系统的具体版本.
    assert(SA_FFI_OK == sensors_analytics.sa_add_string("$os_version", "10.0.0", strlen("10.0.0"), properties))
    -- 请求中能够拿到用户的 IP，则把这个传递给 SA，SA 会自动根据这个解析省份、城市.
    assert(SA_FFI_OK == sensors_analytics.sa_add_string("$ip", "123.123.123.123", strlen("123.123.123.123"), properties))
    -- 是否首次访问.
    assert(SA_FFI_OK == sensors_analytics.sa_add_bool("is_first_time", false, properties))
    -- 记录访问首页事件.
    assert(SA_FFI_OK == sensors_analytics.sa_track(cookie_id, "ViewHomePage", properties, sa))

    sensors_analytics.sa_free_properties(properties)
end

--[[
1.2 记录用户首次登陆时间.
]]--
do
    properties = sensors_analytics.sa_init_properties()
    if nil == properties then
        return error("Failed to initialize the properties.")
    end

    -- 用户首次使用时间.
    assert(SA_FFI_OK == sensors_analytics.sa_add_date("first_time", os.time(), 0, properties))
    -- 记录用户属性.
    assert(SA_FFI_OK == sensors_analytics.sa_profile_set_once(cookie_id, properties, sa))

    sensors_analytics.sa_free_properties(properties)
end

--[[
1.3 搜索商品.
]]--
do
    properties = sensors_analytics.sa_init_properties()
    if nil == properties then
        return error("Failed to initialize the properties.")
    end

    -- 通过请求中的 UA，可以解析出用户使用设备的操作系统是 iOS 的.
    assert(SA_FFI_OK == sensors_analytics.sa_add_string("$os", "iOS", strlen("iOS"), properties))
    -- 操作系统的具体版本.
    assert(SA_FFI_OK == sensors_analytics.sa_add_string("$os_version", "10.0.0", strlen("10.0.0"), properties))
    -- 请求中能够拿到用户的 IP，则把这个传递给 SA，SA 会自动根据这个解析省份、城市.
    assert(SA_FFI_OK == sensors_analytics.sa_add_string("$ip", "123.123.123.123", strlen("123.123.123.123"), properties))
    -- 搜索引擎引流过来时使用的关键词.
    assert(SA_FFI_OK == sensors_analytics.sa_add_string("key_word", "XX手机", 8, properties))
    -- 记录搜索商品事件.
    assert(SA_FFI_OK == sensors_analytics.sa_track(cookie_id, "SearchProduct", properties, sa))

    sensors_analytics.sa_free_properties(properties)
end

--[[
1.4 浏览商品.
]]--
do
    properties = sensors_analytics.sa_init_properties()
    if nil == properties then
        return error("Failed to initialize the properties.")
    end

    -- 通过请求中的 UA，可以解析出用户使用设备的操作系统是 iOS 的.
    assert(SA_FFI_OK == sensors_analytics.sa_add_string("$os", "iOS", strlen("iOS"), properties))
    -- 操作系统的具体版本.
    assert(SA_FFI_OK == sensors_analytics.sa_add_string("$os_version", "10.0.0", strlen("10.0.0"), properties))
    -- 请求中能够拿到用户的 IP，则把这个传递给 SA，SA 会自动根据这个解析省份、城市.
    assert(SA_FFI_OK == sensors_analytics.sa_add_string("$ip", "123.123.123.123", strlen("123.123.123.123"), properties))
    -- 商品名称.
    assert(SA_FFI_OK == sensors_analytics.sa_add_string("product_name", "XX手机", 8, properties))
    -- 商品 Tag.
    assert(SA_FFI_OK == sensors_analytics.sa_append_list("product_tag", "大屏", 6, properties))
    assert(SA_FFI_OK == sensors_analytics.sa_append_list("product_tag", "双卡双待", 12, properties))
    -- 商品价格.
    assert(SA_FFI_OK == sensors_analytics.sa_add_int("product_price", 5888, properties))
    -- 记录浏览商品事件.
    assert(SA_FFI_OK == sensors_analytics.sa_track(cookie_id, "ViewProduct", properties, sa))

    sensors_analytics.sa_free_properties(properties)
end

-- 2. 用户注册，注册后的注册 ID.
local login_id = "123456"

-- 2.1 通过，track_signup，把匿名ID和注册ID关联起来.
do
    properties = sensors_analytics.sa_init_properties()
    if nil == properties then
        return error("Failed to initialize the properties.")
    end

    -- 用户的注册渠道.
    assert(SA_FFI_OK == sensors_analytics.sa_add_string("register", "Baidu", 5, properties))
    -- 关联注册用户与匿名用户.
    assert(SA_FFI_OK == sensors_analytics.sa_track_signup(login_id, cookie_id, properties, sa))

    sensors_analytics.sa_free_properties(properties)
end

-- 2.2 用户注册时，填充了一些个人信息，可以用Profile接口记录下来.
do
    properties = sensors_analytics.sa_init_properties()
    if nil == properties then
        return error("Failed to initialize the properties.")
    end

    -- 用户的注册渠道.
    assert(SA_FFI_OK == sensors_analytics.sa_add_string("register", "Baidu", 5, properties))
    -- 用户注册日期.
    assert(SA_FFI_OK == sensors_analytics.sa_add_date("$signup_time", os.time(), 0, properties))
    -- 用户是否购买过商品.
    assert(SA_FFI_OK == sensors_analytics.sa_add_bool("is_vip", false, properties))
    -- 设置用户属性.
    assert(SA_FFI_OK == sensors_analytics.sa_profile_set(login_id, properties, sa))

    sensors_analytics.sa_free_properties(properties)
end

-- 3. 用户提交订单.

-- 3.1 记录用户提交订单事件.
do
    properties = sensors_analytics.sa_init_properties()
    if nil == properties then
        return error("Failed to initialize the properties.")
    end

    -- 通过请求中的 UA，可以解析出用户使用设备的操作系统是 iOS 的.
    assert(SA_FFI_OK == sensors_analytics.sa_add_string("$os", "iOS", strlen("iOS"), properties))
    -- 操作系统的具体版本.
    assert(SA_FFI_OK == sensors_analytics.sa_add_string("$os_version", "10.0.0", strlen("10.0.0"), properties))
    -- 请求中能够拿到用户的 IP，则把这个传递给 SA，SA 会自动根据这个解析省份、城市.
    assert(SA_FFI_OK == sensors_analytics.sa_add_string("$ip", "123.123.123.123", strlen("123.123.123.123"), properties))
    -- 商品名称.
    assert(SA_FFI_OK == sensors_analytics.sa_add_string("product_name", "XX手机", 8, properties))
    -- 商品价格.
    assert(SA_FFI_OK == sensors_analytics.sa_add_int("product_price", 5888, properties))
    -- 商品折扣.
    assert(SA_FFI_OK == sensors_analytics.sa_add_number("product_discount", 0.8, properties))
    -- 记录购买商品事件.
    assert(SA_FFI_OK == sensors_analytics.sa_track(cookie_id, "SubmitOrder", properties, sa))

    sensors_analytics.sa_free_properties(properties)
end

-- 3.2 在用户属性中记录用户支付金额.
do
    properties = sensors_analytics.sa_init_properties()
    if nil == properties then
        return error("Failed to initialize the properties.")
    end

    -- 累加用户支付金额.
    assert(SA_FFI_OK == sensors_analytics.sa_add_int("pay", 5888, properties))
    -- 记录搜索商品事件.
    assert(SA_FFI_OK == sensors_analytics.sa_profile_increment(login_id, properties, sa))

    sensors_analytics.sa_free_properties(properties)
end

-- 3.3 在用户属性中增加用户头衔.
do
    properties = sensors_analytics.sa_init_properties()
    if nil == properties then
        return error("Failed to initialize the properties.")
    end

    -- 用户获得头衔.
    assert(SA_FFI_OK == sensors_analytics.sa_append_list("title", "VIP", 3, properties))
    -- 添加用户属性.
    assert(SA_FFI_OK == sensors_analytics.sa_profile_append(login_id, properties, sa))

    sensors_analytics.sa_free_properties(properties)
end

-- 4. 其他.

-- 4.1 删除用户某个属性.
do
    assert(SA_FFI_OK == sensors_analytics.sa_profile_unset(login_id, "title", sa))
end

-- 4.2 删除某个用户的所有属性.
do
    assert(SA_FFI_OK == sensors_analytics.sa_profile_delete(login_id, sa))
end

sensors_analytics.sa_flush(sa)
sensors_analytics.sa_free(sa)

