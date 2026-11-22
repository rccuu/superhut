/**
 * 功能描述：服务端访问辅助类
 * <pre>
 *     1、配置dkyw.config.*(dkyw为前缀)
 *     使用：[${remote}]  (remote对应配置文件dkyw.remote属性)
 *     新增：配置文件增加属性dkyw.a，DkywProperties增加对应属性a
 *     js增加[${a}]
 *     2、封装了ajax的方法
 *     调用方式：
 *     dkyw.request.post
 *     dkyw.request.postSync
 *     dkyw.request.get
 *     dkyw.request.getSync
 * </pre>
 * @author:zhaokuiqiang
 */
;!function (win) {
    var zIndex = 2017;//在默认的1987基础上增加30
    "use strict";
    $.ajaxSetup({
        statusCode: {
            401: function () {
                var serveletContext = $("meta[name='_ctx']").attr("content");
                if (typeof (serveletContext) == 'undefined') {
                    serveletContext = "";
                }
                window.location.href = serveletContext + "/login";
            }
        }
    });
    var Dkyw = function () {
        return {
            config: {
                remote: '[${remote}]',
                business: "business",
                _ajaxOption: {
                    url: null,
                    type: 'post',
                    data: {},
                    dataType: 'json',
                    contentType: "application/json",
                    beforeSend: function (request) {
                        request.setRequestHeader("x-requested-with", "XMLHttpRequest");
                    },
                    crossDomain: true,
                    xhrFields: {
                        withCredentials: true
                    },
                    success: function (response) {
                    },
                    error: function (response) {
                    }
                }
            },
            request: {
                page: function (url, data, success, error) {
                    $.ajax({
                        url: url,
                        type: 'post',
                        data: data,
                        dataType: 'html',
                        async: false,
                        beforeSend: function (request) {
                            request.setRequestHeader("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8");
                        },
                        crossDomain: true,
                        xhrFields: {
                            withCredentials: true
                        },
                        success: success,
                        error: function (e, s, stack) {
                            console.log(e);
                            console.log(s);
                            console.log(stack);
                            if (error && dkyw.tool.isFunction(error)) {
                                error(e, s, stack);
                            }
                        }
                    });
                },
                /**
                 * 功能描述：post异步调用
                 * @author:zhaokuiqiang
                 * @returns {*}
                 */
                post: function (url, data, success, error) {
                    dkyw.assert.hasText(url, "url为空");
                    this.ajax({url: url, async: true, data: data, type: "post", success: success, error: error});
                },
                /**
                 * 功能描述：post同步调用
                 * @author:zhaokuiqiang
                 * @returns {*}
                 */
                postSync: function (url, data, success, error) {
                    dkyw.assert.hasText(url, "url为空");
                    return this.ajax({
                        url: url,
                        async: false,
                        data: data,
                        type: "post",
                        success: success,
                        error: error
                    });
                },
                /**
                 * 功能描述：get异步调用
                 * @author:zhaokuiqiang
                 * @returns {*}
                 */
                get: function (url, data, success, error) {
                    dkyw.assert.hasText(url, "url为空");
                    this.ajax({url: url, async: true, data: data, type: "get", success: success, error: error});
                },
                /**
                 * 功能描述：get同步调用
                 * @author:zhaokuiqiang
                 * @returns {*}
                 */
                getSync: function (url, data, success, error) {
                    dkyw.assert.hasText(url, "url为空");
                    this.ajax({url: url, async: false, data: data, type: "get", success: success, error: error});
                },
                /**
                 * 功能描述：
                 * @author:zhaokuiqiang
                 * @returns {*}
                 */
                ajax: function (options) {
                    dkyw.assert.hasText(options.url, "url为空");
                    if (options.type != "get" && options.type != "post") {
                        throw new Error("请求类型错误" + options.type);
                    }
                    dkyw.tool.wrapperSuccess(options);
                    dkyw.tool.wrapperError(options);
                    dkyw.tool.wrapperUrl(options);
                    var opt = $.extend({}, dkyw.config._ajaxOption, options);
                    if (options.type === "post") {
                        opt.data = JSON.stringify(opt.data);
                    }
                    return $.ajax(opt);
                }
            },
            form: {
                options: {
                    elements: ["input", "checkbox", "select", "radio"]
                },
                /**
                 * 功能描述：遍历获取所有的值
                 * 元素必须设置name属性
                 * @param target 目标
                 * @param elements 待遍历的类型，默认["input", "checkbox", "select", "radio"]
                 * @returns {any[]}
                 */
                values: function (target, elements) {
                    var opt = $.extend({}, dkyw.form.options, elements);
                    var result = "{";
                    for (var i = 0; i < opt.elements.length; i++) {
                        var type = opt.elements[i];
                        var e;
                        if (target) {
                            e = $(target).find(type);
                        } else {
                            e = $(type);
                        }
                        e.each(function (index, o) {
                            var name = o.name;
                            var value = o.value;
                            if (name) {
                                if (result.length > 1) {
                                    result += ",";
                                }
                                result += '"' + name + '":"' + value + '"';
                            }
                        });
                    }
                    result += "}";
                    return eval("(" + result + ")");
                },
                applyValues: function (values) {
                    for (var v in values) {
                        $("[name=" + v + "]").val(values[v]);
                    }
                }
            },
            dialog: {
                error: function (message, ok, cancel) {
                    var defaultOpt = {
                        content: '<i class="icon error"></i><span class="text">' + message + '</span>',
                        ok: function () {
                            if (ok && dkyw.tool.isFunction(ok)) {
                                ok();
                            }
                        },
                        cancel: cancel
                    };
                    zIndex += 20;
                    this.message($.extend({}, defaultOpt, {zIndex: zIndex}));
                },
                success: function (message, ok, cancel) {
                    var defaultOpt = {
                        content: '<i class="icon succeed"></i><span class="text">' + message + '</span>',
                        ok: function () {
                            if (ok && dkyw.tool.isFunction(ok)) {
                                ok();
                            }
                        },
                        cancel: cancel
                    };
                    zIndex += 20;
                    this.message($.extend({}, defaultOpt, {zIndex: zIndex}));
                },
                warn: function (message, ok, cancel) {
                    var defaultOpt = {
                        content: '<i class="icon warn"></i><span class="text">' + message + '</span>',
                        ok: function () {
                            if (ok && dkyw.tool.isFunction(ok)) {
                                ok();
                            }
                        },
                        cancel: cancel
                    };
                    zIndex += 20;
                    this.message($.extend({}, defaultOpt, {zIndex: zIndex}));
                },
                message: function (options) {
                    var title = queryI18n("public.alert");
                    var okValue = queryI18n("btn.ok");
                    var cancelValue = queryI18n("btn.cancel");
                    var defaultOpt = {
                        title: title,
                        className: "g-dialog g-tip-dialog",
                        width: 400,
                        height: "auto",
                        padding: "0 0",
                        content: '<span class="text"></span>',
                        lock: true,
                        okVal: okValue,
                        cancelVal: cancelValue,
                        zIndex: 1987,
                        init: function () {
                            this._reset();
                        }
                    };
                    var opt = $.extend({}, defaultOpt, options);
                    art.dialog(opt);
                },
                html: function (options) {
                    var okValue = queryI18n("btn.ok");
                    var cancelValue = queryI18n("btn.cancel");
                    var defaultOpt = {
                        className: "g-dialog g-big-dialog",
                        width: 800,
                        height: "auto",
                        padding: "0 0",
                        title: '',
                        lock: true,
                        okVal: okValue,
                        cancelVal: cancelValue,
                        init: function () {
                        }
                    };
                    if (options.pageUrl) {
                        var init_bak = options.init;
                        options.init = function () {
                            var thisDialog = this;
                            dkyw.request.page(options.pageUrl, {}, function (response) {
                                thisDialog.content(response);
                            });
                            this._reset();
                            if (init_bak) {
                                init_bak();
                            }
                        }
                    }
                    var opt = $.extend({}, defaultOpt, options);
                    return art.dialog(opt);
                },
                open: function (options) {
                    var okValue = queryI18n("btn.ok");
                    var cancelValue = queryI18n("btn.cancel");
                    var defaultOpt = {
                        width: 600,
                        height: 'auto',
                        lock: true,
                        className: "g-dialog g-middle-dialog g-open-dialog",
                        init: function () {
                            this._reset();
                        },
                        okVal: okValue,
                        cancelVal: cancelValue,
                        autoValidate: true
                    };
                    var opt = $.extend({}, defaultOpt, options);
                    var chiledIframe;
                    if (opt.autoValidate) {
                        var bak = opt.ok;
                        if (bak) {
                            opt.ok = function () {
                                if ($(chiledIframe.iframe).contents().find("form").validationEngine('validate')) {
                                    return bak();
                                } else {
                                    return false;
                                }
                            }
                        }
                    }
                    //
                    chiledIframe = art.dialog.open(dkyw.tool.wrapperUrl({url: opt.pageUrl}), opt);
                    $(chiledIframe.iframe).attr("singleSelect", options.singleCheck);
                    return chiledIframe;
                }
            },
            tool: {
                /**
                 * 功能描述：包装url
                 * ip:port/url
                 * @author:zhaokuiqiang
                 * @param opt
                 * @returns {*}
                 */
                wrapperUrl: function (opt) {
                    function extracted(url) {
                        var reg = new RegExp("^" + "/");
                        if (!reg.test(url)) {
                            url = "/" + url;
                        }
                        if (typeof (window.urlProxy) != 'undefined') {
                            url = window.urlProxy + url;
                        }
                        var path = $("meta[name='_ctx']").attr("content");
                        if (typeof (path) != 'undefined') {
                            url = path + url;
                        }
                        //针对wechat-ui拼接
                        var openid = $("#openid").val();
                        if (!isEmpty(openid) && url.indexOf("openid=" == -1)) {
                            if (url.indexOf("?") != -1) {
                                url = url + "&openid=" + openid;
                            } else {
                                url = url + "?openid=" + openid;
                            }
                        }
                        return url;
                    }

                    if (opt.url) {
                        return opt.url = extracted(opt.url);
                    } else if (opt.pageUrl) {
                        return opt.pageUrl = extracted(opt.pageUrl);
                    }
                    throw new Error("url为空");
                },
                /**
                 * 功能描述：包装success
                 * 默认的成功方法处理
                 * @author:zhaokuiqiang
                 * @param opt
                 * @returns {*}
                 */
                wrapperSuccess: function (opt) {
                    var tempFunction = opt.success;
                    if (this.isFunction(tempFunction)) {
                        opt.success = function (response) {
                            dkyw.tool.parseError(response);
                            tempFunction(response);
                        }
                    } else {
                        opt.success = function (response) {
                            dkyw.tool.parseError(response);
                        }
                    }
                },
                /**
                 * 功能描述：包装error
                 * 默认的异常方法处理
                 * @author:zhaokuiqiang
                 * @param opt
                 * @returns {*}
                 */
                wrapperError: function (opt) {
                    var tempFunction = opt.error;
                    if (this.isFunction(tempFunction)) {
                        opt.error = function (XMLHttpRequest, textStatus, errorThrown) {
                            dkyw.tool.parseError(XMLHttpRequest);
                            tempFunction(XMLHttpRequest);
                        }
                    } else {
                        //status = 500
                        opt.error = function (XMLHttpRequest, textStatus, errorThrown) {
                            dkyw.tool.parseError(XMLHttpRequest);
                        }
                    }
                },
                /**
                 * 功能描述：异常转换
                 * 404、500、超时等
                 * @author:zhaokuiqiang
                 * @param opt
                 * @returns {*}
                 */
                parseError: function (response) {

                },
                isFunction: function (f) {
                    if (f && typeof (f) == "function") {
                        return true;
                    }
                    return false;
                },
                /**
                 * 格式化字符串
                 * @author：zhaokuiqang
                 * @param text 源字符串
                 * @param pattern 占位符
                 * @param arg 参数
                 * @returns {*}
                 */
                format: function (text, pattern, arg) {
                    if (!arg || !pattern) {
                        return text;
                    }
                    var t = "";
                    if (!arg) {
                        return text;
                    }
                    var patlength = pattern.length;
                    var args = arg.split("|");
                    var i = 0;
                    while (true) {
                        var index = text.indexOf(pattern);
                        if (index == -1) {
                            break;
                        }
                        t += text.substring(0, index);
                        t += args[i++];
                        text = text.substring(index + patlength);
                    }
                    t += text;
                    return t;
                }
            },
            assert: {
                notNull: function (o, message) {
                    if (o) {
                    } else {
                        throw Error(message);
                    }
                }
                ,
                hasText: function (o, message) {
                    this.notNull(o, message);
                    if (typeof (o) == "string" && o != "") {
                    } else {
                        throw new Error(message);
                    }
                }
            }
        }
            ;
    }
    win.dkyw = new Dkyw();
}(window)