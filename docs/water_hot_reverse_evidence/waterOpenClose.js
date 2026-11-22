$(function () {
    getWaterOpenClose();
})


/**用水记录**/
function getWaterOpenClose() {
    var openid = $("#openid").val();
    var usertype = $("#usertype").val();
    dkyw.request.post("/bathroom/selectCloseDeviceValve", {
        "openid": openid
    }, function (data) {
        if (data != null && data != "") {
            var htmlstr = "";
            var list = data.data;
            if (list.length > 0) {
                htmlstr += ' <ul class="booking-list">';
                for (var i = 0; i < list.length; i++) {
                    var id ="'"+list[i].id+"'";
                    htmlstr += ' <li>';
                    htmlstr += ' <div class="booking-w"> <div class="booking-top"> <p class="fl"><img    <img src="/images/water/icon-device.png">  设备号</p>  <p class="fr c3"> ' + list[i].poscode + '</p> ';
                    htmlstr += '  </div>  <div class="booking-mid"> <span class="fl">  <p>开始使用时间:</p><p class="c0"><img src="/images/water/icon-wait.png">' + list[i].begintime + '</p>  </span> </div>';
                    htmlstr += '  <div class="details-bottom"> <span class="fl"> <p class="c0"><img src="/images/water/icon-tips.png">温馨提示</p>\n' +
                                ' <p class="c2">请及时关闭水阀，以防浪费</p> <p class="c2"></p> </span><p class="delete clk" onclick="submitOpenClose('+ list[i].poscode+ ','+id+')">' +
                                '  去关阀</p>  </div>  </div>';
                    htmlstr += '</li>';
                }
                htmlstr += '</ul>';
                $("#usewater-nodata").hide();
                $("#recordlist").append(htmlstr);//向前台展示数据
            }
        }
    });

}

function submitOpenClose(poscode,appid) {
    var openid = $("#openid").val();
    window.location.href = "/waterpage/waterUsingPage?openid="+ openid + "&poscode=" +  poscode+ "&openappid=" +  appid;

}
